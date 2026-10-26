//
//  ChainedAPIKeyStore.swift
//  SwiftHablare
//

import Foundation

/// Resolves a key from the first member store that has one. Environment wins in ``default``.
///
/// Writes go to the first member that accepts them (read-only members are skipped);
/// removals apply to every writable member so a key cannot linger in a later store.
public struct ChainedAPIKeyStore: APIKeyStoring, CustomStringConvertible {
  public let stores: [any APIKeyStoring]

  public init(_ stores: [any APIKeyStoring]) {
    self.stores = stores
  }

  /// Environment variables first, then the shared Keychain group.
  public static var `default`: ChainedAPIKeyStore {
    ChainedAPIKeyStore([EnvironmentAPIKeyStore(), KeychainAPIKeyStore.intrusiveMemoryVoices])
  }

  public func apiKey(for pluginId: String) -> String? {
    for store in stores {
      if let key = store.apiKey(for: pluginId) { return key }
    }
    return nil
  }

  public func keySource(for pluginId: String) -> String? {
    for store in stores {
      if let source = store.keySource(for: pluginId) { return source }
    }
    return nil
  }

  public func setAPIKey(_ key: String, for pluginId: String) throws {
    for store in stores {
      do {
        try store.setAPIKey(key, for: pluginId)
        return
      } catch CredentialStoreError.readOnly {
        continue
      }
    }
    throw CredentialStoreError.readOnly("chain")
  }

  public func removeAPIKey(for pluginId: String) throws {
    var removedSomewhere = false
    for store in stores {
      do {
        try store.removeAPIKey(for: pluginId)
        removedSomewhere = true
      } catch CredentialStoreError.readOnly {
        continue
      }
    }
    if !removedSomewhere { throw CredentialStoreError.readOnly("chain") }
  }

  public var description: String {
    "ChainedAPIKeyStore([\(stores.map { String(describing: $0) }.joined(separator: ", "))])"
  }
}
