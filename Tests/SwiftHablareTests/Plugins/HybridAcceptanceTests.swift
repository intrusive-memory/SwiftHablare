import Foundation
import Testing

@testable import SwiftHablare
@testable import SwiftHablareTesting

/// The spec's acceptance test for R11, plus the composite's status, pairing and readiness rules.
private typealias FakeHybrid = CompositePlugin<FakeDesignerPlugin, FakeSynthesizerPlugin>

/// A designer that needs a key, like Google's: `.needsCredential` until one is stored.
private final class KeyedDesignerPlugin: HablarePlugin, @unchecked Sendable {
  static let id = "keyed-designer"
  static let displayName = "Keyed Designer"
  static let kind = PluginKind.cloud
  static let credentials = [
    CredentialRequirement(
      primaryEnvironmentVariable: "FAKE_DESIGN_API_KEY", keychainAccount: "keyed-designer",
      displayName: "Fake design API key")
  ]

  let context: PluginContext
  let fakeDesigner = FakeVoiceDesigner()

  init(context: PluginContext) async throws { self.context = context }

  var designer: (any VoiceDesigner)? { fakeDesigner }

  func status() async -> PluginStatus {
    PluginStatus.evaluate(credentials: Self.credentials, keys: context.keys, models: [])
  }
}

/// A synthesizer that consumes only Qwen3 embeddings, so a Google designer cannot pair with it.
private final class NarrowSynthPlugin: HablarePlugin, @unchecked Sendable {
  static let id = "narrow-synth"
  static let displayName = "Narrow Synthesizer"
  static let kind = PluginKind.local

  struct Synth: VoiceSynthesizer {
    var capabilities: SynthesisCapabilities { [] }
    var limits: SynthesisLimits { .unlimited }
    var nativeFormats: [AudioFormat] { [.pcm24kMono16] }
    var maxConcurrentRequests: Int { 1 }
    var consumedSources: [VoiceSourcePattern] {
      [VoiceSourcePattern(engine: "qwen3-tts", kind: .embedding)]
    }
    func readiness(for voice: VoiceReference) async -> VoiceReadiness { .ready(source: nil) }
    func prepare(_ voice: VoiceReference) async throws {}
    func release(_ voice: VoiceReference) async {}
    func synthesize(_ request: SpeechRequest) async throws -> GeneratedAudio {
      throw HablareError.cancelled
    }
  }

  init(context: PluginContext) async throws {}

  var synthesizer: (any VoiceSynthesizer)? { Synth() }

  func status() async -> PluginStatus { .ready }
}

@Suite("Hybrid composition (R11)", .serialized)
struct HybridAcceptanceTests {
  static let googleSamplePath = "embeddings/google/gemini-3.8-flash-tts/sample-audio.wav"

  /// A registry with an empty key store: no environment, no Keychain.
  private func makeRegistry() -> (PluginRegistry, () -> Void) {
    let (defaults, cleanup) = makeTestUserDefaults(
      suiteName: "HybridAcceptanceTests.\(UUID().uuidString)")
    let registry = PluginRegistry(
      userDefaults: defaults, environment: [:], fallbackKeys: [InMemoryAPIKeyStore()])
    return (registry, cleanup)
  }

  private func fakeHybrid(in registry: PluginRegistry) async throws -> FakeHybrid {
    await registry.register(FakeDesignerPlugin.self)
    await registry.register(FakeSynthesizerPlugin.self)
    try await registry.register(composite: FakeHybrid.self)
    return try #require(try await registry.plugin(id: FakeHybrid.id) as? FakeHybrid)
  }

  /// Copies `Fixtures/voices/<name>` into a fresh temp directory; tests write only the copy.
  private func tempCopy(of fixture: String) throws -> (url: URL, directory: URL) {
    let source = try VoiceAssetTests.fixture(fixture)
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("HybridAcceptanceTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let copy = directory.appendingPathComponent(fixture)
    try FileManager.default.copyItem(at: source, to: copy)
    return (copy, directory)
  }

  private func line(_ voice: URL, seed: UInt64 = 1) -> SpeechRequest {
    SpeechRequest(text: "Every line renders on device.", voice: .asset(voice), seed: seed)
  }

  /// design → save into a temp `.vox` → readiness names the source → synthesize.
  private func designAndSave(
    _ hybrid: FakeHybrid, into url: URL
  ) async throws {
    let designer = try #require(hybrid.designer)
    let candidates = try await designer.design(
      VoiceDesignRequest(
        description: "A dry, unhurried baritone with a faint rasp.",
        sampleText: "I have been here before."))
    let chosen = try #require(candidates.first)
    var asset = try VoiceAsset(contentsOf: url)
    try await designer.save(chosen, into: &asset)
    try asset.write(to: url)
  }

  // MARK: Acceptance

  @Test("Design, save into TOBY, then render from the Google sample")
  func acceptance() async throws {
    let (registry, cleanup) = makeRegistry()
    defer { cleanup() }
    let hybrid = try await fakeHybrid(in: registry)
    #expect(FakeHybrid.kind == .hybrid)
    let (url, directory) = try tempCopy(of: "TOBY.vox")
    defer { try? FileManager.default.removeItem(at: directory) }

    try await designAndSave(hybrid, into: url)

    let synthesizer = try #require(hybrid.synthesizer)
    let readiness = await synthesizer.readiness(for: .asset(url))
    #expect(readiness.source?.engine == "google")
    #expect(readiness.source?.kind == .referenceAudio)
    #expect(readiness.source?.path == Self.googleSamplePath)

    let audio = try await synthesizer.synthesize(line(url))
    #expect(audio.sourceUsed?.engine == "google")
    #expect(audio.sourceUsed == readiness.source)
  }

  @Test("An untouched TOBY renders from its qwen3-tts source")
  func untouchedTobyUsesQwen() async throws {
    let (registry, cleanup) = makeRegistry()
    defer { cleanup() }
    let hybrid = try await fakeHybrid(in: registry)
    let (url, directory) = try tempCopy(of: "TOBY.vox")
    defer { try? FileManager.default.removeItem(at: directory) }

    let synthesizer = try #require(hybrid.synthesizer)
    let readiness = await synthesizer.readiness(for: .asset(url))
    #expect(readiness.source?.engine == "qwen3-tts")
    let audio = try await synthesizer.synthesize(line(url))
    #expect(audio.sourceUsed?.engine == "qwen3-tts")
    #expect(audio.sourceUsed == readiness.source)
  }

  @Test("Rendering never calls the designer")
  func renderingNeverDesigns() async throws {
    let (registry, cleanup) = makeRegistry()
    defer { cleanup() }
    let hybrid = try await fakeHybrid(in: registry)
    let (url, directory) = try tempCopy(of: "TOBY.vox")
    defer { try? FileManager.default.removeItem(at: directory) }
    try await designAndSave(hybrid, into: url)

    let fakeDesigner = try #require(hybrid.designerPlugin).fakeDesigner
    let designs = fakeDesigner.designCallCount
    let saves = fakeDesigner.saveCallCount
    #expect(designs == 1)
    #expect(saves == 1)

    let synthesizer = try #require(hybrid.synthesizer)
    for seed in 1...3 {
      let audio = try await synthesizer.synthesize(line(url, seed: UInt64(seed)))
      #expect(audio.sourceUsed?.engine == "google")
    }
    #expect(fakeDesigner.designCallCount == designs)
    #expect(fakeDesigner.saveCallCount == saves)
    #expect(fakeDesigner.deleteCallCount == 0)
    #expect(try #require(hybrid.synthesizerPlugin).fakeSynthesizer.synthesizeCallCount == 3)
  }

  // MARK: Pairing

  @Test("A designer whose sources the synthesizer does not consume cannot be registered")
  func invalidPairingThrows() async throws {
    typealias Mismatched = CompositePlugin<FakeDesignerPlugin, NarrowSynthPlugin>
    let (registry, cleanup) = makeRegistry()
    defer { cleanup() }
    await registry.register(FakeDesignerPlugin.self)
    await registry.register(NarrowSynthPlugin.self)

    do {
      try await registry.register(composite: Mismatched.self)
      Issue.record("expected invalidRequest")
    } catch HablareError.invalidRequest {
    }
    #expect(await !registry.isRegistered(Mismatched.id))

    // Registering it unchecked does not help: resolving it validates again.
    await registry.register(Mismatched.self)
    await #expect(throws: HablareError.self) { try await registry.plugin(id: Mismatched.id) }
  }

  // MARK: Status and credentials

  @Test("Empty key store and a .vox with the Google sample: synthesis is ready")
  func sampleNeedsNoDesignKey() async throws {
    typealias Keyed = CompositePlugin<KeyedDesignerPlugin, FakeSynthesizerPlugin>
    let (registry, cleanup) = makeRegistry()
    defer { cleanup() }
    await registry.register(KeyedDesignerPlugin.self)
    await registry.register(FakeSynthesizerPlugin.self)
    try await registry.register(composite: Keyed.self)
    let hybrid = try #require(try await registry.plugin(id: Keyed.id) as? Keyed)
    let (url, directory) = try tempCopy(of: "CLARK.vox")
    defer { try? FileManager.default.removeItem(at: directory) }

    // The union still declares the design key, and the designer really lacks it.
    #expect(Keyed.credentials.map(\.primaryEnvironmentVariable) == ["FAKE_DESIGN_API_KEY"])
    #expect(await hybrid.designStatus() == .needsCredential(envVar: "FAKE_DESIGN_API_KEY"))

    let readiness = await hybrid.synthesizer?.readiness(for: .asset(url))
    #expect(readiness?.source?.engine == "google")
    #expect(await hybrid.synthesisStatus() == .ready)
    #expect(await hybrid.status() == .ready)
    #expect(await hybrid.status(for: .asset(url)) == .ready)
  }

  @Test("A .vox with nothing to render from needs design, and so the design key")
  func emptyVoxNeedsDesignKey() async throws {
    typealias Keyed = CompositePlugin<KeyedDesignerPlugin, FakeSynthesizerPlugin>
    let (registry, cleanup) = makeRegistry()
    defer { cleanup() }
    await registry.register(KeyedDesignerPlugin.self)
    await registry.register(FakeSynthesizerPlugin.self)
    try await registry.register(composite: Keyed.self)
    let hybrid = try #require(try await registry.plugin(id: Keyed.id) as? Keyed)

    let missing = FileManager.default.temporaryDirectory
      .appendingPathComponent("HybridAcceptanceTests-missing-\(UUID().uuidString).vox")
    #expect(
      await hybrid.status(for: .asset(missing))
        == .needsCredential(envVar: "FAKE_DESIGN_API_KEY"))
  }

  @Test("status() names the missing component")
  func missingComponentNamed() async throws {
    let (registry, cleanup) = makeRegistry()
    defer { cleanup() }
    await registry.register(FakeSynthesizerPlugin.self)
    try await registry.register(composite: FakeHybrid.self)
    let hybrid = try #require(try await registry.plugin(id: FakeHybrid.id) as? FakeHybrid)

    guard case .unavailable(let reason) = await hybrid.status() else {
      Issue.record("expected .unavailable")
      return
    }
    #expect(reason.contains("fake-designer"))
    #expect(hybrid.designer == nil)
    #expect(hybrid.synthesizer != nil)
  }

  @Test("Static shape: hybrid kind, synthesizer models, union of credentials")
  func staticShape() {
    typealias Cloudy = CompositePlugin<KeyedDesignerPlugin, FakeCloudPlugin>
    #expect(FakeHybrid.id == "fake-designer+fake-synth")
    #expect(FakeHybrid.kind == .hybrid)
    #expect(FakeHybrid.credentials.isEmpty)
    #expect(FakeHybrid.models == FakeSynthesizerPlugin.models)
    #expect(
      Cloudy.credentials.map(\.primaryEnvironmentVariable)
        == ["FAKE_DESIGN_API_KEY", "FAKE_CLOUD_API_KEY"])
  }

  // MARK: Source selection (R3)

  @Test("A stale Google server handle is skipped; selection falls back to qwen3-tts")
  func staleHandleSkipped() async throws {
    let (registry, cleanup) = makeRegistry()
    defer { cleanup() }
    let hybrid = try await fakeHybrid(in: registry)
    let synthesizer = try #require(hybrid.synthesizer)
    let (url, directory) = try tempCopy(of: "TOBY.vox")
    defer { try? FileManager.default.removeItem(at: directory) }

    var asset = try VoiceAsset(contentsOf: url)
    try asset.setExtension(
      [
        "voice_id": "voice_old", "model_id": "gemini-3.8-flash-tts",
        "expire_time": "2001-01-01T00:00:00Z",
      ], forEngine: "google")
    try asset.write(to: url)
    let reopened = try VoiceAsset(contentsOf: url)
    #expect(
      reopened.sources.contains {
        guard $0.engine == "google", case .stale = $0.freshness else { return false }
        return true
      })

    let readiness = await synthesizer.readiness(for: .asset(url))
    #expect(readiness.source?.engine == "qwen3-tts")
    let audio = try await synthesizer.synthesize(line(url))
    #expect(audio.sourceUsed == readiness.source)
  }

  @Test("Selection follows the preference list and never picks a stale source")
  func preferenceOrder() throws {
    let prefs = [
      VoiceSourcePattern(engine: "google", kind: .referenceAudio),
      VoiceSourcePattern(engine: "qwen3-tts"),
      VoiceSourcePattern(),
    ]
    var asset = VoiceAsset(name: "Scratch", description: "A scratch voice for selection tests.")
    try asset.setExtension(
      ["voice_id": "voice_old", "expire_time": "2001-01-01T00:00:00Z"], forEngine: "google")
    #expect(asset.preferredSource(for: prefs) == nil)

    try asset.setExtension(
      ["voice_id": "voice_new", "expire_time": "2999-01-01T00:00:00Z"], forEngine: "google")
    #expect(asset.preferredSource(for: prefs)?.kind == .serverHandle)

    try asset.addEmbedding(Data([1, 2, 3]), engine: "qwen3-tts", model: "1.7b", modelSlug: "1.7b")
    #expect(asset.preferredSource(for: prefs)?.engine == "qwen3-tts")

    try asset.addSampleAudio(Data("RIFF".utf8), engine: "google", model: "gemini-3.8-flash-tts")
    let best = asset.preferredSource(for: prefs)
    #expect(best?.engine == "google")
    #expect(best?.kind == .referenceAudio)
  }

  @Test("TOBY prefers its qwen3 reference audio over its embeddings")
  func tobyPrefersReferenceAudio() throws {
    let asset = try VoiceAsset(contentsOf: VoiceAssetTests.fixture("TOBY.vox"))
    let source = asset.preferredSource(for: FakeVoiceSynthesizer().consumedSources)
    #expect(source?.engine == "qwen3-tts")
    #expect(source?.kind == .referenceAudio)
  }
}
