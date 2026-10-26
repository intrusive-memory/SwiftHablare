import Foundation
import SwiftHablareTesting
import Testing

@testable import SwiftHablare

// MARK: - Minimal in-test plugin

private struct EchoSynthesizer: VoiceSynthesizer {
  var capabilities: SynthesisCapabilities { [.seed, .onDevice] }
  var limits: SynthesisLimits { SynthesisLimits(maxCharacters: 280) }
  var nativeFormats: [AudioFormat] { [.pcm24kMono16] }
  var maxConcurrentRequests: Int { 1 }

  func readiness(for voice: VoiceReference) async -> VoiceReadiness { .ready(source: nil) }
  func prepare(_ voice: VoiceReference) async throws {}
  func release(_ voice: VoiceReference) async {}

  func synthesize(_ request: SpeechRequest) async throws -> GeneratedAudio {
    if request.text.isEmpty { throw HablareError.invalidRequest(detail: "empty text") }
    return GeneratedAudio(
      data: Data(request.text.utf8), format: .pcm24kMono16, duration: 1,
      droppedInstruct: request.instruct != nil)
  }
}

private struct EchoPlugin: HablarePlugin {
  static let id = "echo"
  static let displayName = "Echo"
  static let kind = PluginKind.local
  static let models = [
    ModelDescriptor(
      id: "tiny", kind: .local, acervoModelId: "intrusive-memory/does-not-exist")
  ]

  let context: PluginContext
  init(context: PluginContext) async throws { self.context = context }

  var synthesizer: (any VoiceSynthesizer)? { EchoSynthesizer() }

  func status() async -> PluginStatus {
    PluginStatus.evaluate(
      credentials: Self.credentials, keys: context.keys, models: Self.models,
      availability: LocalModelAvailability(probe: { _ in false }))
  }
}

private struct KeyedPlugin: HablarePlugin {
  static let id = "keyed"
  static let displayName = "Keyed"
  static let kind = PluginKind.cloud
  static let credentials = [CredentialRequirement.google]

  let context: PluginContext
  init(context: PluginContext) async throws { self.context = context }

  func status() async -> PluginStatus {
    PluginStatus.evaluate(credentials: Self.credentials, keys: context.keys, models: Self.models)
  }
}

private final class ProgressRecorder: @unchecked Sendable {
  private let lock = NSLock()
  private var events: [SynthesisProgress] = []
  func record(_ event: SynthesisProgress) { lock.withLock { events.append(event) } }
  var recorded: [SynthesisProgress] { lock.withLock { events } }
}

private let voice = VoiceReference.catalog(pluginId: "echo", voiceId: "v")

// MARK: - Tests

@Suite("Plugin contract")
struct ContractTests {

  @Test("Default progress overload reports exactly started, finished")
  func defaultProgressOverload() async throws {
    let recorder = ProgressRecorder()
    let synth: any VoiceSynthesizer = EchoSynthesizer()
    let audio = try await synth.synthesize(
      SpeechRequest(text: "hello", voice: voice), progress: { recorder.record($0) })
    #expect(recorder.recorded == [.started, .finished])
    #expect(audio.data == Data("hello".utf8))
  }

  @Test("Default progress overload does not report finished when synthesis throws")
  func defaultProgressOverloadThrows() async {
    let recorder = ProgressRecorder()
    let synth = EchoSynthesizer()
    await #expect(throws: HablareError.self) {
      _ = try await synth.synthesize(
        SpeechRequest(text: "", voice: voice), progress: { recorder.record($0) })
    }
    #expect(recorder.recorded == [.started])
  }

  @Test("Missing Acervo model reports missing through SwiftAcervo, offline")
  func missingAcervoModel() {
    let descriptor = ModelDescriptor(
      id: "ghost", acervoModelId: "intrusive-memory/does-not-exist")
    let availability = LocalModelAvailability()
    #expect(availability.availability(of: descriptor) == .missing)
    #expect(availability.missingModels([descriptor]) == [descriptor])
  }

  @Test("A descriptor without an Acervo id is not managed")
  func notManagedModel() {
    let cloud = ModelDescriptor(id: "gemini-3.8-flash-tts", kind: .cloud)
    #expect(LocalModelAvailability().availability(of: cloud) == .notManaged)
    #expect(LocalModelAvailability().missingModels([cloud]).isEmpty)
  }

  @Test("The probe decides available versus missing")
  func probeSeam() {
    let present = ModelDescriptor(id: "a", acervoModelId: "org/present")
    let absent = ModelDescriptor(id: "b", acervoModelId: "org/absent")
    let availability = LocalModelAvailability(probe: { $0 == "org/present" })
    #expect(availability.availability(of: present) == .available)
    #expect(availability.missingModels([present, absent]) == [absent])
  }

  @Test("ModelDescriptor carries every R1 field plus the Acervo id")
  func modelDescriptorFields() {
    let model = ModelDescriptor(
      id: "1.7b", displayName: "Qwen3-TTS 1.7B", kind: .local, languages: ["en", "es"],
      capabilities: [.seed, .onDevice], approximateBytes: 3_400_000_000,
      minimumMemoryBytes: 6_000_000_000, acervoModelId: "mlx-community/Qwen3-TTS-1.7B")
    #expect(model.displayName == "Qwen3-TTS 1.7B")
    #expect(model.languages == ["en", "es"])
    #expect(model.capabilities.contains(.onDevice))
    #expect(model.approximateBytes == 3_400_000_000)
    #expect(model.minimumMemoryBytes == 6_000_000_000)
    #expect(model.acervoModelId == "mlx-community/Qwen3-TTS-1.7B")
    #expect(ModelDescriptor(id: "m").displayName == "m")
  }

  @Test("A plugin is built from a context and exposes its roles and status")
  func pluginFromContext() async throws {
    let context = PluginContext(keys: InMemoryAPIKeyStore(), registry: PluginRegistry())
    let plugin: any HablarePlugin = try await EchoPlugin(context: context)
    #expect(plugin.synthesizer != nil)
    #expect(plugin.designer == nil)
    #expect(plugin.converter == nil)
    #expect(EchoPlugin.credentials.isEmpty)
    #expect(EchoPlugin.settingsSchema == .empty)
    #expect(await plugin.status() == .needsModel(EchoPlugin.models))
  }

  @Test("Status needs a credential until the key is set, then is ready")
  func credentialStatus() async throws {
    let keys = InMemoryAPIKeyStore()
    let plugin = try await KeyedPlugin(
      context: PluginContext(keys: keys, registry: PluginRegistry()))
    #expect(await plugin.status() == .needsCredential(envVar: "GEMINI_API_KEY"))
    try keys.setAPIKey("planted", for: "google")
    #expect(await plugin.status() == .ready)
  }

  @Test("Credential requirements are exposed keyed by store account")
  func credentialRequirementsByAccount() {
    #expect(KeyedPlugin.credentialRequirementsByAccount == ["google": .google])
    #expect(EchoPlugin.credentialRequirementsByAccount.isEmpty)
    let env = EnvironmentAPIKeyStore(
      requirements: KeyedPlugin.credentialRequirementsByAccount,
      environment: ["GOOGLE_API_KEY": "x"])
    #expect(env.keySource(for: "google") == "environment (GOOGLE_API_KEY)")
  }

  @Test("Default cache key and cost estimate are nil")
  func defaults() {
    let synth = EchoSynthesizer()
    let request = SpeechRequest(text: "x", voice: voice, seed: 7)
    #expect(synth.cacheKey(for: request) == nil)
    #expect(synth.estimateCost(request) == nil)
    #expect(synth.consumedSources.isEmpty)
  }

  @Test("Capabilities are distinct option bits")
  func capabilities() {
    let all: [SynthesisCapabilities] = [.instruct, .streaming, .multiSpeaker, .seed, .onDevice]
    #expect(Set(all.map(\.rawValue)).count == all.count)
    let some: SynthesisCapabilities = [.seed, .onDevice]
    #expect(some.contains(.seed))
    #expect(!some.contains(.instruct))
  }

  @Test("Readiness exposes the source it will use")
  func readinessSource() {
    #expect(VoiceReadiness.ready(source: VoiceSource()).source == VoiceSource())
    #expect(VoiceReadiness.unsupported(reason: "no audio").source == nil)
  }

  @Test("Source patterns accept what they match; nil matches anything")
  func sourcePatterns() {
    let googleAudio = VoiceSourcePattern(engine: "google", kind: .referenceAudio)
    let anyAudio = VoiceSourcePattern(kind: .referenceAudio)
    #expect(anyAudio.accepts(googleAudio))
    #expect(googleAudio.accepts(googleAudio))
    #expect(!googleAudio.accepts(VoiceSourcePattern(engine: "qwen3-tts", kind: .referenceAudio)))
    #expect(!anyAudio.accepts(VoiceSourcePattern(engine: "google", kind: .serverHandle)))
    #expect(VoiceSourcePattern().accepts(googleAudio))
  }

  @Test("A voice candidate keeps the prompt actually sent")
  func voiceCandidate() {
    let request = VoiceDesignRequest(
      description: "A gravelly narrator", sampleText: "Once upon a time.", language: "en",
      gender: .male, age: .senior)
    let candidate = VoiceCandidate(
      preview: GeneratedAudio(data: Data([1, 2]), format: .pcm24kMono16, duration: 0.1),
      handle: .init(identifier: "voice_123"),
      promptSent: "Rewritten: a gravelly, older narrator")
    #expect(candidate.promptSent != request.description)
    #expect(candidate.handle.identifier == "voice_123")
    #expect(candidate.handle.payload == nil)
  }
}
