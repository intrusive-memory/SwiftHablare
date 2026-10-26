//
//  KeychainAPIKeyStore.swift
//  SwiftHablare
//

import Foundation
import Security

/// Keychain-backed store. One generic-password item per plugin id under a single service.
///
/// With an ``accessGroup`` the items live in the data-protection keychain, the only
/// macOS keychain that honours `kSecAttrAccessGroup`. A process lacking the entitlement
/// for the group resolves no key (`errSecMissingEntitlement` is swallowed on read), so an
/// unsigned CLI falls through to the environment instead of failing.
public final class KeychainAPIKeyStore: APIKeyStoring, CustomStringConvertible {

  /// Shared by Escribir, Produciesta.app, `produciesta-queuectl` and the queue's LaunchAgents.
  public static let intrusiveMemoryVoices = KeychainAPIKeyStore(
    service: intrusiveMemoryVoicesService,
    accessGroup: intrusiveMemoryVoicesAccessGroup
  )
  public static let intrusiveMemoryVoicesService = "io.intrusive-memory.hablare.apiKeys"
  public static let intrusiveMemoryVoicesAccessGroup = "H3EJ6Y8VJ6.io.intrusive-memory.hablare"

  public let service: String
  public let accessGroup: String?

  public init(service: String, accessGroup: String? = nil) {
    self.service = service
    self.accessGroup = accessGroup
  }

  private func baseQuery(for pluginId: String) -> [String: Any] {
    var query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: pluginId,
    ]
    if let accessGroup {
      query[kSecAttrAccessGroup as String] = accessGroup
      query[kSecUseDataProtectionKeychain as String] = true
    }
    return query
  }

  public func apiKey(for pluginId: String) -> String? {
    var query = baseQuery(for: pluginId)
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    guard status == errSecSuccess, let data = item as? Data else { return nil }
    let key = String(decoding: data, as: UTF8.self)
    return key.isEmpty ? nil : key
  }

  public func keySource(for pluginId: String) -> String? {
    guard apiKey(for: pluginId) != nil else { return nil }
    return accessGroup == nil ? "keychain" : "shared keychain"
  }

  public func setAPIKey(_ key: String, for pluginId: String) throws {
    let data = Data(key.utf8)
    let query = baseQuery(for: pluginId)
    let updateStatus = SecItemUpdate(
      query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
    if updateStatus == errSecSuccess { return }
    guard updateStatus == errSecItemNotFound else {
      throw CredentialStoreError.keychain(updateStatus)
    }
    var insert = query
    insert[kSecValueData as String] = data
    insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    let addStatus = SecItemAdd(insert as CFDictionary, nil)
    guard addStatus == errSecSuccess else { throw CredentialStoreError.keychain(addStatus) }
  }

  public func removeAPIKey(for pluginId: String) throws {
    let status = SecItemDelete(baseQuery(for: pluginId) as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw CredentialStoreError.keychain(status)
    }
  }

  public var description: String {
    "KeychainAPIKeyStore(service: \(service), accessGroup: \(accessGroup ?? "none"))"
  }
}
