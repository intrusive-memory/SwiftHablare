import Foundation
import Testing

@testable import SwiftHablare
@testable import SwiftHablareTesting

@Suite("Fake plugins", .serialized)
struct FakePluginTests {
  private func context(keys: [String: String] = [:]) -> PluginContext {
    PluginContext(keys: InMemoryAPIKeyStore(keys: keys), registry: PluginRegistry())
  }

  private func request(_ text: String = "Hello there, world.", seed: UInt64? = 7) -> SpeechRequest {
    SpeechRequest(
      text: text, voice: .catalog(pluginId: "fake-synth", voiceId: "a"), seed: seed)
  }

  // MARK: Synthesizer

  @Test("Same request twice gives identical bytes; a different seed differs")
  func deterministic() async throws {
    let plugin = try await FakeSynthesizerPlugin(context: context())
    let synth = try #require(plugin.synthesizer)
    let first = try await synth.synthesize(request())
    let second = try await synth.synthesize(request())
    let other = try await synth.synthesize(request(seed: 8))
    #expect(first.data == second.data)
    #expect(first.data != other.data)
    #expect(first.format == FakeAudio.format)
    #expect(first.format.container == .wav)
  }

  @Test("Output carries a valid WAV header")
  func wavHeader() async throws {
    let plugin = try await FakeSynthesizerPlugin(context: context())
    let audio = try await #require(plugin.synthesizer).synthesize(request("Fourteen chars"))
    let data = audio.data
    #expect(data.prefix(4) == Data("RIFF".utf8))
    #expect(data.subdata(in: 8..<12) == Data("WAVE".utf8))
    #expect(data.subdata(in: 36..<40) == Data("data".utf8))
    let rate = data.subdata(in: 24..<28).withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
    #expect(UInt32(littleEndian: rate) == 24_000)
    let size = data.subdata(in: 40..<44).withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
    #expect(Int(UInt32(littleEndian: size)) == data.count - 44)
    #expect(abs(audio.duration - 1) < 0.01)
  }

  @Test("Source preference is google reference audio, qwen3-tts, then any")
  func sourcePreference() async throws {
    let plugin = try await FakeSynthesizerPlugin(context: context())
    let sources = try #require(plugin.synthesizer).consumedSources
    #expect(sources.map(\.engine) == ["google", "qwen3-tts", nil])
    #expect(sources[0].kind == .referenceAudio)
    #expect(plugin.synthesizer?.capabilities.contains(.seed) == true)
    #expect(FakeSynthesizerPlugin.kind == .local)
  }

  @Test("Init counter counts instances created inside its scope only")
  func initCounter() async throws {
    let counter = FakeInitCounter()
    let ctx = context()
    try await FakeSynthesizerPlugin.withInitCounter(counter) {
      _ = try await FakeSynthesizerPlugin(context: ctx)
      _ = try await FakeSynthesizerPlugin(context: ctx)
    }
    // Outside the scope (as in every other suite) nothing is counted.
    _ = try await FakeSynthesizerPlugin(context: ctx)
    #expect(counter.count == 2)
  }

  @Test("failNextCall throws once, then recovers")
  func failNext() async throws {
    let plugin = try await FakeSynthesizerPlugin(context: context())
    plugin.failNextCall(with: .rateLimited(retryAfter: 2))
    let synth = try #require(plugin.synthesizer)
    await #expect(throws: HablareError.self) { try await synth.synthesize(request()) }
    _ = try await synth.synthesize(request())
    #expect(plugin.fakeSynthesizer.synthesizeCallCount == 2)
  }

  @Test("Chosen readiness is reported and becomes sourceUsed")
  func readiness() async throws {
    let plugin = try await FakeSynthesizerPlugin(context: context())
    let voice = VoiceReference.catalog(pluginId: "fake-synth", voiceId: "a")
    #expect(await plugin.fakeSynthesizer.readiness(for: voice) == .ready(source: nil))
    let source = VoiceSource(engine: "qwen3-tts", model: "1.7b", kind: .embedding)
    plugin.setReadiness(.needsPreparation(source: source))
    #expect(await plugin.fakeSynthesizer.readiness(for: voice) == .needsPreparation(source: source))
    let audio = try await plugin.fakeSynthesizer.synthesize(request())
    #expect(audio.sourceUsed == source)
    plugin.setReadiness(.unsupported(reason: "no"))
    #expect(await plugin.fakeSynthesizer.readiness(for: voice) == .unsupported(reason: "no"))
  }

  @Test("Concurrent synthesis keeps counters exact")
  func concurrent() async throws {
    let plugin = try await FakeSynthesizerPlugin(context: context())
    let synth = plugin.fakeSynthesizer
    try await withThrowingTaskGroup(of: Void.self) { group in
      for index in 0..<50 {
        group.addTask { _ = try await synth.synthesize(self.request(seed: UInt64(index))) }
      }
      try await group.waitForAll()
    }
    #expect(synth.synthesizeCallCount == 50)
    #expect(synth.receivedRequests.count == 50)
  }

  // MARK: Designer

  @Test("save writes a google reference audio and server handle")
  func designerSave() async throws {
    let plugin = try await FakeDesignerPlugin(context: context())
    let designer = try #require(plugin.designer)
    let candidates = try await designer.design(
      VoiceDesignRequest(description: "A warm baritone", sampleText: "Hi"))
    #expect(candidates.count == 2)
    #expect(candidates[0].preview.data == FakeVoiceDesigner.previewWAV)
    #expect(plugin.fakeDesigner.lastPromptSent == candidates[0].promptSent)
    #expect(candidates[0].promptSent.contains("A warm baritone"))

    var asset = VoiceAsset(name: "TEST", description: "A test voice asset")
    try await designer.save(candidates[0], into: &asset)
    let sources = asset.sources
    #expect(sources.contains { $0.engine == "google" && $0.kind == .referenceAudio })
    #expect(sources.contains { $0.engine == "google" && $0.kind == .serverHandle })
    let fields = try #require(asset.extensionFields(forEngine: "google"))
    #expect(fields["voice_id"] as? String == "voice_fake_0")
    #expect(fields["model_id"] as? String == "gemini-3.8-flash-tts")
    #expect(plugin.fakeDesigner.designCallCount == 1)
    #expect(plugin.fakeDesigner.saveCallCount == 1)
    #expect(
      designer.producedSources.map(\.kind) == [.referenceAudio, .serverHandle])
  }

  @Test("Designer failNextCall throws once")
  func designerFail() async throws {
    let plugin = try await FakeDesignerPlugin(context: context())
    plugin.failNextCall(with: .safetyBlocked(reason: "no"))
    let designer = try #require(plugin.designer)
    let design = VoiceDesignRequest(description: "x", sampleText: "y")
    await #expect(throws: HablareError.self) { try await designer.design(design) }
    #expect(try await designer.design(design).count == 2)
    try await designer.delete(.catalog(pluginId: "fake-designer", voiceId: "v"))
    #expect(plugin.fakeDesigner.deleteCallCount == 1)
  }

  // MARK: Cloud

  @Test("Cloud status follows the key store")
  func cloudStatus() async throws {
    let keys = InMemoryAPIKeyStore()
    let plugin = try await FakeCloudPlugin(
      context: PluginContext(keys: keys, registry: PluginRegistry()))
    #expect(await plugin.status() == .needsCredential(envVar: "FAKE_CLOUD_API_KEY"))
    try keys.setAPIKey("secret", for: "fake-cloud")
    #expect(await plugin.status() == .ready)
    #expect(FakeCloudPlugin.kind == .cloud)
    #expect(FakeCloudPlugin.credentials.count == 1)
  }

  @Test("Cloud synthesis without a key throws missingCredential; with one it works")
  func cloudSynthesis() async throws {
    let keys = InMemoryAPIKeyStore()
    let plugin = try await FakeCloudPlugin(
      context: PluginContext(keys: keys, registry: PluginRegistry()))
    let synth = try #require(plugin.synthesizer)
    do {
      _ = try await synth.synthesize(request())
      Issue.record("expected missingCredential")
    } catch HablareError.missingCredential {
    }
    try keys.setAPIKey("secret", for: "fake-cloud")
    _ = try await synth.synthesize(request())
    #expect(plugin.fakeSynthesizer.synthesizeCallCount == 2)
  }
}
