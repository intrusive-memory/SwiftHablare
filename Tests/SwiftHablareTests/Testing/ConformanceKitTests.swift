import Foundation
import Testing

@testable import SwiftHablare
@testable import SwiftHablareTesting

// MARK: - Deliberately broken plugins

private struct LeakError: Error, CustomStringConvertible {
  let key: String
  var description: String { "request rejected for key \(key)" }
}

private struct PlainError: Error {}

/// Forwards to a real fake and lets a test bend one behaviour.
private final class BentSynthesizer: VoiceSynthesizer, @unchecked Sendable {
  let inner = FakeVoiceSynthesizer()
  let transform: @Sendable (GeneratedAudio) -> GeneratedAudio
  let onEmpty: (@Sendable () throws -> Void)?
  let honoursCancellation: Bool

  init(
    transform: @escaping @Sendable (GeneratedAudio) -> GeneratedAudio = { $0 },
    onEmpty: (@Sendable () throws -> Void)? = nil,
    honoursCancellation: Bool = true
  ) {
    self.transform = transform
    self.onEmpty = onEmpty
    self.honoursCancellation = honoursCancellation
  }

  var capabilities: SynthesisCapabilities { inner.capabilities }
  var limits: SynthesisLimits { inner.limits }
  var nativeFormats: [AudioFormat] { inner.nativeFormats }
  var maxConcurrentRequests: Int { 1 }
  func readiness(for voice: VoiceReference) async -> VoiceReadiness {
    await inner.readiness(for: voice)
  }
  func prepare(_ voice: VoiceReference) async throws { try await inner.prepare(voice) }
  func release(_ voice: VoiceReference) async { await inner.release(voice) }
  func cacheKey(for request: SpeechRequest) -> String? { inner.cacheKey(for: request) }

  func synthesize(_ request: SpeechRequest) async throws -> GeneratedAudio {
    if request.text.isEmpty { try onEmpty?() }
    if honoursCancellation && Task.isCancelled { throw HablareError.cancelled }
    if !honoursCancellation {
      // Run detached so the wrapped fake cannot see the caller's cancellation.
      let inner = self.inner
      return transform(try await Task.detached { try await inner.synthesize(request) }.value)
    }
    return transform(try await inner.synthesize(request))
  }
}

private struct LyingFormatPlugin: HablarePlugin {
  static let id = "lying"
  static let displayName = "Lying"
  static let kind = PluginKind.local
  let box: BentSynthesizer
  init(context: PluginContext) async throws {
    box = BentSynthesizer(transform: { audio in
      var audio = audio
      audio.format = AudioFormat(container: .wav, sampleRate: 22_050, channels: 1, bitDepth: 16)
      return audio
    })
  }
  var synthesizer: (any VoiceSynthesizer)? { box }
  func status() async -> PluginStatus { .ready }
}

/// Reports `.pcm` while the bytes carry a RIFF header: the original fake's mismatch.
private struct PcmWithHeaderPlugin: HablarePlugin {
  static let id = "pcm-with-header"
  static let displayName = "PCM with header"
  static let kind = PluginKind.local
  let box: BentSynthesizer
  init(context: PluginContext) async throws {
    box = BentSynthesizer(transform: { audio in
      var audio = audio
      audio.format = .pcm24kMono16
      return audio
    })
  }
  var synthesizer: (any VoiceSynthesizer)? { box }
  func status() async -> PluginStatus { .ready }
}

private struct UncategorisedErrorPlugin: HablarePlugin {
  static let id = "uncategorised"
  static let displayName = "Uncategorised"
  static let kind = PluginKind.local
  let box = BentSynthesizer(onEmpty: { throw PlainError() })
  init(context: PluginContext) async throws {}
  var synthesizer: (any VoiceSynthesizer)? { box }
  func status() async -> PluginStatus { .ready }
}

private struct IgnoresCancellationPlugin: HablarePlugin {
  static let id = "ignores-cancel"
  static let displayName = "Ignores cancel"
  static let kind = PluginKind.local
  let box = BentSynthesizer(honoursCancellation: false)
  init(context: PluginContext) async throws {}
  var synthesizer: (any VoiceSynthesizer)? { box }
  func status() async -> PluginStatus { .ready }
}

private let plantedKey = "sk-PLANTED-0123456789-secret"

private struct LeakyPlugin: HablarePlugin {
  static let id = "leaky"
  static let displayName = "Leaky"
  static let kind = PluginKind.cloud
  static let credentials = [
    CredentialRequirement(
      primaryEnvironmentVariable: "LEAKY_API_KEY", keychainAccount: "leaky",
      displayName: "Leaky key")
  ]
  let box: BentSynthesizer
  init(context: PluginContext) async throws {
    let key = context.keys.apiKey(for: "leaky") ?? ""
    box = BentSynthesizer(onEmpty: { throw HablareError.transient(underlying: LeakError(key: key)) }
    )
  }
  var synthesizer: (any VoiceSynthesizer)? { box }
  func status() async -> PluginStatus { .ready }
}

private struct StatusLeakPlugin: HablarePlugin {
  static let id = "status-leak"
  static let displayName = "Status leak"
  static let kind = PluginKind.cloud
  static let credentials = LeakyPlugin.credentials.map {
    CredentialRequirement(
      primaryEnvironmentVariable: $0.primaryEnvironmentVariable, keychainAccount: "status-leak",
      displayName: $0.displayName)
  }
  let key: String
  init(context: PluginContext) async throws { key = context.keys.apiKey(for: "status-leak") ?? "" }
  var synthesizer: (any VoiceSynthesizer)? { BentSynthesizer() }
  func status() async -> PluginStatus { .unavailable(reason: "rejected \(key)") }
}

private final class LeakyKeyStore: APIKeyStoring, @unchecked Sendable {
  let key: String
  init(key: String) { self.key = key }
  func apiKey(for pluginId: String) -> String? { key }
  func setAPIKey(_ key: String, for pluginId: String) throws {}
  func removeAPIKey(for pluginId: String) throws {}
  func keySource(for pluginId: String) -> String? { "env (\(key))" }
}

// MARK: - Tests

@Suite("Conformance kit")
struct ConformanceKitTests {
  private let voice = VoiceReference.catalog(pluginId: "any", voiceId: "a")

  private func context(keys: [String: String] = [:]) -> PluginContext {
    PluginContext(keys: InMemoryAPIKeyStore(keys: keys), registry: PluginRegistry())
  }

  private func assertClean(_ report: ConformanceReport) {
    #expect(report.passed, "\(report.summary)")
  }

  // MARK: The three fakes

  @Test("FakeSynthesizerPlugin passes the full kit")
  func synthesizer() async {
    let report = await ConformanceKit.run(
      FakeSynthesizerPlugin.self, context: context(), voice: voice)
    assertClean(report)
    #expect(report.passedChecks.map(\.check).contains(.roundTrip))
    #expect(report.passedChecks.map(\.check).contains(.cancellation))
    #expect(report.passedChecks.map(\.check).contains(.formatTruthfulness))
  }

  @Test("FakeCloudPlugin passes the full kit with a planted key")
  func cloud() async {
    let report = await ConformanceKit.run(
      FakeCloudPlugin.self, context: context(keys: ["fake-cloud": plantedKey]), voice: voice)
    assertClean(report)
    #expect(report.result(for: .secrecyStatus)?.outcome == .passed)
    #expect(report.result(for: .secrecyErrors)?.outcome == .passed)
  }

  @Test("FakeDesignerPlugin passes; synthesis checks are skipped (no synthesizer role)")
  func designer() async {
    let report = await ConformanceKit.run(
      FakeDesignerPlugin.self, context: context(), voice: voice)
    assertClean(report)
    #expect(report.result(for: .roundTrip)?.outcome == .skipped)
    #expect(report.result(for: .initialization)?.outcome == .passed)
  }

  @Test("The kit also checks a seedless synthesizer returns nil cache keys")
  func seedless() async {
    struct SeedlessPlugin: HablarePlugin {
      static let id = "seedless"
      static let displayName = "Seedless"
      static let kind = PluginKind.local
      init(context: PluginContext) async throws {}
      var synthesizer: (any VoiceSynthesizer)? {
        FakeVoiceSynthesizer(capabilities: [.onDevice])
      }
      func status() async -> PluginStatus { .ready }
    }
    let report = await ConformanceKit.run(SeedlessPlugin.self, context: context(), voice: voice)
    assertClean(report)
    #expect(report.result(for: .cacheKeyStability)?.message.contains("nil") == true)
  }

  // MARK: Hardware-free mode

  @Test("Hardware-free mode runs only checks that never synthesize and names the skipped ones")
  func hardwareFree() async {
    let report = await ConformanceKit.run(
      FakeSynthesizerPlugin.self, context: context(), voice: voice, mode: .hardwareFree)
    assertClean(report)
    let hardware = Set(ConformanceCheck.allCases.filter(\.needsHardware))
    #expect(
      hardware == [
        .roundTrip, .formatTruthfulness, .cancellation, .errorCategories, .secrecyErrors,
      ])
    let skipped = Set(report.skipped.map(\.check))
    #expect(hardware.isSubset(of: skipped))
    for check in hardware {
      #expect(report.result(for: check)?.message.contains("hardware-free mode") == true)
    }
    let ran = Set(report.passedChecks.map(\.check))
    #expect(ran == [.initialization, .cacheKeyStability])
    #expect(ran.isDisjoint(with: hardware))
  }

  @Test("Hardware-free mode never calls synthesize, prepare or release")
  func hardwareFreeTouchesNoEngine() async {
    struct SpyPlugin: HablarePlugin {
      static let id = "spy"
      static let displayName = "Spy"
      static let kind = PluginKind.local
      static let shared = FakeLocked<FakeVoiceSynthesizer>(FakeVoiceSynthesizer())
      init(context: PluginContext) async throws {}
      var synthesizer: (any VoiceSynthesizer)? { Self.shared.current }
      func status() async -> PluginStatus { .ready }
    }
    _ = await ConformanceKit.run(
      SpyPlugin.self, context: context(), voice: voice, mode: .hardwareFree)
    let spy = SpyPlugin.shared.current
    #expect(spy.synthesizeCallCount == 0)
    #expect(spy.prepareCallCount == 0)
    #expect(spy.releaseCallCount == 0)
  }

  // MARK: The kit catches broken plugins

  @Test("A format that lies about its sample rate is reported")
  func lyingFormat() async {
    let report = await ConformanceKit.run(LyingFormatPlugin.self, context: context(), voice: voice)
    #expect(!report.passed)
    let result = report.result(for: .formatTruthfulness)
    #expect(result?.outcome == .failed)
    #expect(result?.message.contains("22050") == true)
  }

  @Test("Labelling RIFF bytes as .pcm is reported")
  func pcmWithHeader() async {
    let report = await ConformanceKit.run(
      PcmWithHeaderPlugin.self, context: context(), voice: voice)
    #expect(report.result(for: .formatTruthfulness)?.outcome == .failed)
  }

  @Test("A non-HablareError is reported as uncategorised")
  func uncategorised() async {
    let report = await ConformanceKit.run(
      UncategorisedErrorPlugin.self, context: context(), voice: voice)
    #expect(report.result(for: .errorCategories)?.outcome == .failed)
  }

  @Test("A plugin that ignores cancellation is reported")
  func ignoresCancellation() async {
    let report = await ConformanceKit.run(
      IgnoresCancellationPlugin.self, context: context(), voice: voice)
    #expect(report.result(for: .cancellation)?.outcome == .failed)
  }

  @Test("A key leaked in a thrown error is reported, and the report does not repeat the key")
  func leakInError() async {
    let report = await ConformanceKit.run(
      LeakyPlugin.self, context: context(keys: ["leaky": plantedKey]), voice: voice)
    #expect(report.result(for: .secrecyErrors)?.outcome == .failed)
    #expect(!report.summary.contains(plantedKey))
  }

  @Test("A key leaked in status() is reported")
  func leakInStatus() async {
    let report = await ConformanceKit.run(
      StatusLeakPlugin.self, context: context(keys: ["status-leak": plantedKey]), voice: voice,
      mode: .hardwareFree)
    #expect(report.result(for: .secrecyStatus)?.outcome == .failed)
    #expect(!report.summary.contains(plantedKey))
  }

  @Test("A key leaked in keySource is reported")
  func leakInKeySource() async {
    let ctx = PluginContext(keys: LeakyKeyStore(key: plantedKey), registry: PluginRegistry())
    let report = await ConformanceKit.run(
      FakeCloudPlugin.self, context: ctx, voice: voice, mode: .hardwareFree)
    #expect(report.result(for: .secrecyStatus)?.outcome == .failed)
    #expect(!report.summary.contains(plantedKey))
  }

  @Test("A cloud plugin with no planted key fails the secrecy status check")
  func noPlantedKey() async {
    let report = await ConformanceKit.run(
      FakeCloudPlugin.self, context: context(), voice: voice, mode: .hardwareFree)
    #expect(report.result(for: .secrecyStatus)?.outcome == .failed)
  }
}
