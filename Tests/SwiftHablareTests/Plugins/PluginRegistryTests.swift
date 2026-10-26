import Foundation
import Testing

@testable import SwiftHablare
@testable import SwiftHablareTesting

/// A local plugin with its own init counter, so these tests never share state with suites
/// that build `FakeSynthesizerPlugin` (whose counter is process-wide).
private final class CountingPlugin: HablarePlugin, @unchecked Sendable {
  static let id = "counting"
  static let displayName = "Counting"
  static let kind = PluginKind.local
  static let settingsSchema = SettingsSchema([
    SettingDefinition(
      key: "size", valueType: .choice, choices: ["0.6b", "1.7b"], scope: .perPlugin,
      label: "Model size")
  ])

  private static let count = Counter()
  static var initCount: Int { count.value }
  static func reset() { count.reset() }

  let context: PluginContext

  init(context: PluginContext) async throws {
    // Widen the reentrancy window so concurrent resolves overlap.
    try await Task.sleep(for: .milliseconds(30))
    Self.count.increment()
    self.context = context
  }

  func status() async -> PluginStatus { .ready }

  private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var n = 0
    var value: Int { lock.withLock { n } }
    func increment() { lock.withLock { n += 1 } }
    func reset() { lock.withLock { n = 0 } }
  }
}

private func config(_ size: String) -> PluginConfiguration {
  PluginConfiguration(settings: ["size": .choice(size)])
}

@Suite("PluginRegistry", .serialized)
struct PluginRegistryTests {
  private func makeRegistry(
    suite: String = "PluginRegistryTests.\(UUID().uuidString)",
    environment: [String: String] = [:]
  ) -> (PluginRegistry, UserDefaults, () -> Void) {
    let (defaults, cleanup) = makeTestUserDefaults(suiteName: suite)
    let registry = PluginRegistry(
      userDefaults: defaults, environment: environment, fallbackKeys: [InMemoryAPIKeyStore()])
    return (registry, defaults, cleanup)
  }

  @Test("Same plugin and configuration resolves to one instance")
  func cachedPerConfiguration() async throws {
    CountingPlugin.reset()
    let (registry, _, cleanup) = makeRegistry()
    defer { cleanup() }
    await registry.register(CountingPlugin.self)

    let first = try await registry.plugin(id: "counting", configuration: config("0.6b"))
    let second = try await registry.plugin(id: "counting", configuration: config("0.6b"))
    #expect(CountingPlugin.initCount == 1)
    #expect(first as AnyObject === second as AnyObject)

    let third = try await registry.plugin(id: "counting", configuration: config("1.7b"))
    #expect(CountingPlugin.initCount == 2)
    #expect(third as AnyObject !== first as AnyObject)
  }

  @Test("Concurrent resolves of one key initialise once")
  func concurrentResolvesInitOnce() async throws {
    CountingPlugin.reset()
    let (registry, _, cleanup) = makeRegistry()
    defer { cleanup() }
    await registry.register(CountingPlugin.self)

    let ids = try await withThrowingTaskGroup(of: ObjectIdentifier.self) { group in
      for _ in 0..<8 {
        group.addTask {
          let p = try await registry.plugin(id: "counting", configuration: config("0.6b"))
          return ObjectIdentifier(p as AnyObject)
        }
      }
      var all: [ObjectIdentifier] = []
      for try await id in group { all.append(id) }
      return all
    }
    #expect(CountingPlugin.initCount == 1)
    #expect(Set(ids).count == 1)
  }

  @Test("Fake synthesizer plugin resolves and reports ready")
  func registersFake() async throws {
    let (registry, _, cleanup) = makeRegistry()
    defer { cleanup() }
    await registry.register(FakeSynthesizerPlugin.self)
    await registry.register(FakeCloudPlugin.self)
    #expect(await registry.registeredPluginIds == ["fake-cloud", "fake-synth"])
    #expect(try await registry.status(of: "fake-synth") == .ready)
  }

  @Test("Unknown id and invalid configuration throw invalidRequest")
  func errors() async throws {
    let (registry, _, cleanup) = makeRegistry()
    defer { cleanup() }
    await registry.register(CountingPlugin.self)

    await #expect(throws: HablareError.self) { try await registry.plugin(id: "nope") }
    do {
      _ = try await registry.plugin(id: "counting", configuration: config("9b"))
      Issue.record("expected invalidRequest")
    } catch let error as HablareError {
      guard case .invalidRequest = error else {
        Issue.record("wrong case: \(error)")
        return
      }
    }
    do {
      _ = try await registry.plugin(id: "ghost")
      Issue.record("expected invalidRequest")
    } catch let error as HablareError {
      guard case .invalidRequest = error else {
        Issue.record("wrong case: \(error)")
        return
      }
    }
  }

  @Test("Enablement persists across registries over the same defaults")
  func enablementPersists() async throws {
    let suite = "PluginRegistryTests.enable.\(UUID().uuidString)"
    let (first, defaults, cleanup) = makeRegistry(suite: suite)
    defer { cleanup() }
    await first.register(CountingPlugin.self)
    #expect(await first.isEnabled(pluginId: "counting"))

    await first.setEnabled(false, for: "counting")
    #expect(defaults.object(forKey: "voiceProvider.enabled.counting") as? Bool == false)

    let second = PluginRegistry(userDefaults: defaults, environment: [:], fallbackKeys: [])
    await second.register(CountingPlugin.self)
    #expect(await second.isEnabled(pluginId: "counting") == false)

    await second.setEnabled(true, for: "counting")
    #expect(await second.isEnabled(pluginId: "counting"))
    #expect(await second.isEnabled(pluginId: "unregistered") == false)
  }

  @Test("A registered plugin's env var resolves through the registry's keys")
  func registeredPluginEnvironmentResolves() async throws {
    let (registry, _, cleanup) = makeRegistry(environment: ["FAKE_CLOUD_API_KEY": "test-value"])
    defer { cleanup() }

    // Before registration the static built-in map does not know the plugin.
    #expect(await registry.keys.apiKey(for: "fake-cloud") == nil)

    await registry.register(FakeCloudPlugin.self)
    #expect(await registry.keys.apiKey(for: "fake-cloud") == "test-value")
    #expect(await registry.keys.keySource(for: "fake-cloud") == "environment (FAKE_CLOUD_API_KEY)")
    #expect(try await registry.status(of: "fake-cloud") == .ready)

    // Built-ins still resolve alongside.
    let (other, _, cleanup2) = makeRegistry(environment: ["GEMINI_API_KEY": "g"])
    defer { cleanup2() }
    #expect(await other.keys.apiKey(for: "google") == "g")
  }

  @Test("Without the env var the cloud plugin needs a credential")
  func missingKeyNeedsCredential() async throws {
    let (registry, _, cleanup) = makeRegistry()
    defer { cleanup() }
    await registry.register(FakeCloudPlugin.self)
    #expect(
      try await registry.status(of: "fake-cloud") == .needsCredential(envVar: "FAKE_CLOUD_API_KEY")
    )
  }

  @Test("Pairing: designer sources must be consumed by the synthesizer")
  func pairing() throws {
    let registry = PluginRegistry(userDefaults: .standard, environment: [:], fallbackKeys: [])
    let designer = FakeVoiceDesigner()
    let synth = FakeVoiceSynthesizer()
    try registry.validatePairing(designer: designer, synthesizer: synth)

    struct NarrowSynth: VoiceSynthesizer {
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
      func cacheKey(for request: SpeechRequest) -> String? { nil }
    }
    do {
      try registry.validatePairing(designer: designer, synthesizer: NarrowSynth())
      Issue.record("expected invalidRequest")
    } catch let error as HablareError {
      guard case .invalidRequest = error else {
        Issue.record("wrong case: \(error)")
        return
      }
    }
  }

  @Test("The default registry registers nothing yet")
  func defaultIsEmpty() async {
    #expect(await PluginRegistry.default.registeredPluginIds.isEmpty)
  }
}
