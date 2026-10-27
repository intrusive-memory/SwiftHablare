//
//  EnvironmentAPIKeyStore.swift
//  SwiftHablare
//

import Foundation

/// Read-only store backed by environment variables: each plugin's
/// ``CredentialRequirement/primaryEnvironmentVariable``, then its ``CredentialRequirement/aliases``.
public struct EnvironmentAPIKeyStore: APIKeyStoring, CustomStringConvertible {
  private let environment: [String: String]
  private let requirements: [String: CredentialRequirement]

  public init(
    requirements: [String: CredentialRequirement] = CredentialRequirement.builtIn,
    environment: [String: String] = ProcessInfo.processInfo.environment
  ) {
    self.requirements = requirements
    self.environment = environment
  }

  /// The variable the key for `pluginId` resolved from, or `nil`.
  public func resolvedVariable(for pluginId: String) -> String? {
    guard let requirement = requirements[pluginId] else { return nil }
    for name in requirement.environmentVariables {
      if let value = environment[name]?.trimmingCharacters(in: .whitespacesAndNewlines),
        !value.isEmpty
      {
        return name
      }
    }
    return nil
  }

  public func apiKey(for pluginId: String) -> String? {
    guard let name = resolvedVariable(for: pluginId) else { return nil }
    return environment[name]?.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  public func keySource(for pluginId: String) -> String? {
    resolvedVariable(for: pluginId).map { "environment (\($0))" }
  }

  public func setAPIKey(_ key: String, for pluginId: String) throws {
    throw CredentialStoreError.readOnly("environment")
  }

  public func removeAPIKey(for pluginId: String) throws {
    throw CredentialStoreError.readOnly("environment")
  }

  /// Key-free: never prints the environment.
  public var description: String {
    "EnvironmentAPIKeyStore(plugins: \(requirements.keys.sorted()))"
  }
}
