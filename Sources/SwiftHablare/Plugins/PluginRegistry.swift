//
//  PluginRegistry.swift
//  SwiftHablare
//
//  Holds one plugin instance per (pluginId, configuration) (R1), the persisted enablement
//  of each plugin, and the key store plugins are built with.
//

import Foundation

public actor PluginRegistry {
  /// A resolved-instance cache key.
  private struct InstanceKey: Hashable {
    let pluginId: String
    let configuration: PluginConfiguration
  }

  private let userDefaults: UserDefaults
  private let environment: [String: String]
  private let fallbackKeys: [any APIKeyStoring]

  private var types: [String: any HablarePlugin.Type] = [:]
  private var instances: [InstanceKey: any HablarePlugin] = [:]
  private var inFlight: [InstanceKey: Task<any HablarePlugin, any Error>] = [:]

  /// The registry hosts use. Registers the built-in Apple plugin and nothing else.
  public static let `default` = PluginRegistry(plugins: [ApplePlugin.self])

  /// - Parameters:
  ///   - userDefaults: Where enablement persists (6.x key shape).
  ///   - environment: Variables the environment key store reads; inject one in tests.
  ///   - fallbackKeys: Consulted after the environment, in order. Defaults to the shared
  ///     Keychain, matching ``ChainedAPIKeyStore/default`` (environment wins).
  ///   - plugins: Plugin types registered from the start.
  public init(
    userDefaults: UserDefaults = .standard,
    environment: [String: String] = ProcessInfo.processInfo.environment,
    fallbackKeys: [any APIKeyStoring] = [KeychainAPIKeyStore.intrusiveMemoryVoices],
    plugins: [any HablarePlugin.Type] = []
  ) {
    self.userDefaults = userDefaults
    self.environment = environment
    self.fallbackKeys = fallbackKeys
    for type in plugins { types[type.id] = type }
  }

  // MARK: Registration

  /// Registers (or replaces) a plugin type. Instances already built stay cached.
  public func register(_ type: any HablarePlugin.Type) {
    types[type.id] = type
  }

  public var registeredPluginIds: [String] { types.keys.sorted() }

  public func isRegistered(_ pluginId: String) -> Bool { types[pluginId] != nil }

  /// The registered plugin type for `pluginId`, if any.
  public func pluginType(id pluginId: String) -> (any HablarePlugin.Type)? { types[pluginId] }

  // MARK: Keys

  /// The key store handed to plugins: the environment store aware of every registered
  /// plugin's credential requirements (merged over ``CredentialRequirement/builtIn``),
  /// then the fallback stores.
  public var keys: any APIKeyStoring { makeKeys() }

  private func makeKeys() -> any APIKeyStoring {
    var requirements = CredentialRequirement.builtIn
    for type in types.values {
      for (account, requirement) in type.credentialRequirementsByAccount {
        requirements[account] = requirement
      }
    }
    let env = EnvironmentAPIKeyStore(requirements: requirements, environment: environment)
    return ChainedAPIKeyStore([env] + fallbackKeys)
  }

  // MARK: Resolution

  /// The one instance for `(pluginId, configuration)`, built on first request.
  ///
  /// The configuration is validated against the plugin's `perPlugin` settings first; an
  /// invalid one throws `HablareError.invalidRequest`. Concurrent calls for the same key
  /// share a single `init`.
  public func plugin(
    id pluginId: String, configuration: PluginConfiguration = .empty
  ) async throws -> any HablarePlugin {
    guard let type = types[pluginId] else {
      throw HablareError.invalidRequest(detail: "no plugin registered with id '\(pluginId)'")
    }
    let validated = try configuration.validated(against: type.settingsSchema)
    let key = InstanceKey(pluginId: pluginId, configuration: validated)
    if let existing = instances[key] { return existing }
    if let task = inFlight[key] { return try await task.value }

    let context = PluginContext(keys: makeKeys(), configuration: validated, registry: self)
    let task = Task<any HablarePlugin, any Error> { try await type.init(context: context) }
    inFlight[key] = task
    defer { inFlight[key] = nil }
    let built = try await task.value
    instances[key] = built
    return built
  }

  public func status(
    of pluginId: String, configuration: PluginConfiguration = .empty
  ) async throws -> PluginStatus {
    try await plugin(id: pluginId, configuration: configuration).status()
  }

  // MARK: Enablement (6.x key shape: "voiceProvider.enabled.<id>")

  /// Plugins are enabled until a host turns them off. Unknown ids report `false`.
  public func isEnabled(pluginId: String) -> Bool {
    guard types[pluginId] != nil else { return false }
    return (userDefaults.object(forKey: Self.enabledKey(for: pluginId)) as? Bool) ?? true
  }

  /// Persists enablement for a registered plugin; unknown ids are ignored.
  public func setEnabled(_ isEnabled: Bool, for pluginId: String) {
    guard types[pluginId] != nil else { return }
    userDefaults.set(isEnabled, forKey: Self.enabledKey(for: pluginId))
  }

  private static func enabledKey(for pluginId: String) -> String {
    "voiceProvider.enabled.\(pluginId)"
  }

  // MARK: Pairing (R11)

  /// Checks a designer/synthesizer pairing: every source the designer produces must be
  /// accepted by at least one pattern the synthesizer consumes. Sortie 10's composite calls
  /// this at registration. Throws `HablareError.invalidRequest` naming the offending source.
  public nonisolated func validatePairing(
    designer: any VoiceDesigner, synthesizer: any VoiceSynthesizer
  ) throws {
    let consumed = synthesizer.consumedSources
    for produced in designer.producedSources
    where !consumed.contains(where: { $0.accepts(produced) }) {
      let engine = produced.engine ?? "any"
      let kind = produced.kind.map { String(describing: $0) } ?? "any"
      throw HablareError.invalidRequest(
        detail:
          "designer produces a '\(engine)' \(kind) source that the synthesizer does not consume")
    }
  }

  /// Resolves both plugins (default configuration) and validates the pairing.
  public func validatePairing(designerId: String, synthesizerId: String) async throws {
    let designerPlugin = try await plugin(id: designerId)
    let synthPlugin = try await plugin(id: synthesizerId)
    guard let designer = designerPlugin.designer else {
      throw HablareError.invalidRequest(detail: "plugin '\(designerId)' has no designer role")
    }
    guard let synthesizer = synthPlugin.synthesizer else {
      throw HablareError.invalidRequest(detail: "plugin '\(synthesizerId)' has no synthesizer role")
    }
    try validatePairing(designer: designer, synthesizer: synthesizer)
  }
}
