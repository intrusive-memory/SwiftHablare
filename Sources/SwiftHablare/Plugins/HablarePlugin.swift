//
//  HablarePlugin.swift
//  SwiftHablare
//
//  The plugin contract (R1). Plugins are compile-time packages: the host links them and
//  registers their types with `PluginRegistry` at launch. No generics or associated types (D-1).
//

import Foundation

public enum PluginKind: String, Sendable, Hashable, Codable {
  case local
  case cloud
  case hybrid
}

/// What a plugin needs before it can do its work. Hosts render setup prompts from this.
public enum PluginStatus: Sendable, Hashable {
  case ready
  /// A key is missing; names the primary environment variable, never a key value.
  case needsCredential(envVar: String)
  /// These local models are not on disk (per SwiftAcervo).
  case needsModel([ModelDescriptor])
  case unavailable(reason: String)
}

/// Everything a plugin instance is built from.
public struct PluginContext: Sendable {
  public let keys: any APIKeyStoring
  /// Host-supplied, plugin-typed settings (e.g. VoxAlta model size), validated against the
  /// plugin schema's `perPlugin` keys.
  public let configuration: PluginConfiguration
  /// Lets a hybrid resolve its component plugins.
  public let registry: PluginRegistry

  public init(
    keys: any APIKeyStoring,
    configuration: PluginConfiguration = .empty,
    registry: PluginRegistry
  ) {
    self.keys = keys
    self.configuration = configuration
    self.registry = registry
  }
}

public protocol HablarePlugin: Sendable {
  /// "voxalta", "elevenlabs", "google", "chatterbox", "gemini-chatterbox".
  static var id: String { get }
  static var displayName: String { get }
  static var kind: PluginKind { get }
  /// Empty for local plugins. A hybrid declares the union of its components' requirements.
  /// Each requirement's ``CredentialRequirement/keychainAccount`` is the id its key is stored
  /// under in ``APIKeyStoring`` (a component plugin's id, for a hybrid).
  static var credentials: [CredentialRequirement] { get }
  static var models: [ModelDescriptor] { get }
  /// Per-voice and per-plugin settings (R5).
  static var settingsSchema: SettingsSchema { get }

  init(context: PluginContext) async throws

  var synthesizer: (any VoiceSynthesizer)? { get }
  var designer: (any VoiceDesigner)? { get }
  /// Reserved for 7.x; always `nil` in 7.0.
  var converter: (any VoiceConverter)? { get }

  func status() async -> PluginStatus
}

extension HablarePlugin {
  public static var credentials: [CredentialRequirement] { [] }
  public static var models: [ModelDescriptor] { [] }
  public static var settingsSchema: SettingsSchema { .empty }

  public var synthesizer: (any VoiceSynthesizer)? { nil }
  public var designer: (any VoiceDesigner)? { nil }
  public var converter: (any VoiceConverter)? { nil }

  /// The plugin's credential requirements keyed by the store id they resolve under, in the
  /// shape `EnvironmentAPIKeyStore(requirements:)` takes. The registry merges these into the
  /// environment store so it can resolve a registered plugin's variables.
  public static var credentialRequirementsByAccount: [String: CredentialRequirement] {
    Dictionary(
      credentials.map { ($0.keychainAccount, $0) }, uniquingKeysWith: { first, _ in first })
  }
}

extension PluginStatus {
  /// The common status computation: the first missing credential wins, then any local model
  /// that SwiftAcervo reports missing, otherwise `.ready`.
  ///
  /// A hybrid must not use this blindly with its full credential union: R6 requires synthesis
  /// from an existing sample to report `.ready` without the design key.
  public static func evaluate(
    credentials: [CredentialRequirement],
    keys: any APIKeyStoring,
    models: [ModelDescriptor],
    availability: LocalModelAvailability = LocalModelAvailability()
  ) -> PluginStatus {
    for requirement in credentials where keys.apiKey(for: requirement.keychainAccount) == nil {
      return .needsCredential(envVar: requirement.primaryEnvironmentVariable)
    }
    let missing = availability.missingModels(models)
    if !missing.isEmpty { return .needsModel(missing) }
    return .ready
  }
}
