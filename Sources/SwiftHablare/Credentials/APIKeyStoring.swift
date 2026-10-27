//
//  APIKeyStoring.swift
//  SwiftHablare
//
//  Credential storage keyed by plugin id (R6). Pattern copied from
//  SwiftVinetas `CloudAPIKeyStoring` (v0.26.0); not imported.
//

import Foundation
import Security

/// Supplies per-plugin API keys.
///
/// Implementations must never write a key to disk in plaintext, and must never
/// include key material in an error, a log line, `description`, or
/// ``keySource(for:)``.
public protocol APIKeyStoring: Sendable {
  /// The stored key for `pluginId`, or `nil` when none is set.
  func apiKey(for pluginId: String) -> String?

  /// Stores (or replaces) the key for `pluginId`.
  func setAPIKey(_ key: String, for pluginId: String) throws

  /// Removes the key for `pluginId`. A no-op when none is stored.
  func removeAPIKey(for pluginId: String) throws

  /// A short, key-free description of where the key resolved from
  /// ("environment (GEMINI_API_KEY)", "keychain"), or `nil` when no key is set.
  func keySource(for pluginId: String) -> String?
}

extension APIKeyStoring {
  public func keySource(for pluginId: String) -> String? {
    apiKey(for: pluginId) == nil ? nil : "configured"
  }
}

/// Errors raised by the key stores. Never carries key material.
public enum CredentialStoreError: Error, Sendable, Equatable, CustomStringConvertible {
  /// A Security framework call failed with the given status.
  case keychain(OSStatus)
  /// The store cannot be written (environment variables, a chain with no writable member).
  case readOnly(String)

  public var description: String {
    switch self {
    case .keychain(let status):
      let detail = SecCopyErrorMessageString(status, nil) as String? ?? "OSStatus \(status)"
      return "Keychain error: \(detail)"
    case .readOnly(let store):
      return "The \(store) key store is read-only."
    }
  }
}

/// Everything a host needs to draw a credential field with no provider UI (R6).
/// The host writes the key through ``APIKeyStoring`` and never stores it itself.
public struct CredentialRequirement: Sendable, Hashable, Codable {
  public let primaryEnvironmentVariable: String
  public let aliases: [String]
  /// The Keychain account the key is stored under (the plugin id by convention).
  public let keychainAccount: String
  /// Human label, e.g. "ElevenLabs API key".
  public let displayName: String
  /// Field placeholder, e.g. "sk_…".
  public let placeholder: String
  /// Where to get a key.
  public let helpURL: URL?

  public init(
    primaryEnvironmentVariable: String,
    aliases: [String] = [],
    keychainAccount: String,
    displayName: String,
    placeholder: String = "",
    helpURL: URL? = nil
  ) {
    self.primaryEnvironmentVariable = primaryEnvironmentVariable
    self.aliases = aliases
    self.keychainAccount = keychainAccount
    self.displayName = displayName
    self.placeholder = placeholder
    self.helpURL = helpURL
  }

  /// Primary variable followed by aliases, in lookup order.
  public var environmentVariables: [String] { [primaryEnvironmentVariable] + aliases }

  public static let elevenLabs = CredentialRequirement(
    primaryEnvironmentVariable: "ELEVENLABS_API_KEY",
    keychainAccount: "elevenlabs",
    displayName: "ElevenLabs API key",
    placeholder: "sk_…",
    helpURL: URL(string: "https://elevenlabs.io/app/settings/api-keys")
  )

  /// Same variable names as Vinetas so one key serves both apps.
  public static let google = CredentialRequirement(
    primaryEnvironmentVariable: "GEMINI_API_KEY",
    aliases: ["GOOGLE_API_KEY"],
    keychainAccount: "google",
    displayName: "Gemini API key",
    placeholder: "AIza…",
    helpURL: URL(string: "https://aistudio.google.com/apikey")
  )

  /// Requirements for the built-in plugin ids, keyed by plugin id.
  public static let builtIn: [String: CredentialRequirement] = [
    "elevenlabs": .elevenLabs,
    "google": .google,
  ]
}
