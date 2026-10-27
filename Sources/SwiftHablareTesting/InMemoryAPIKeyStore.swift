//
//  InMemoryAPIKeyStore.swift
//  SwiftHablareTesting
//

import Foundation
import SwiftHablare

/// A lock-guarded dictionary store for tests, previews, and UI-test launches.
public final class InMemoryAPIKeyStore: APIKeyStoring, CustomStringConvertible, @unchecked Sendable
{
  private let lock = NSLock()
  private var keys: [String: String]

  public init(keys: [String: String] = [:]) {
    self.keys = keys
  }

  public func apiKey(for pluginId: String) -> String? {
    lock.withLock { keys[pluginId] }
  }

  public func keySource(for pluginId: String) -> String? {
    apiKey(for: pluginId) == nil ? nil : "memory"
  }

  public func setAPIKey(_ key: String, for pluginId: String) throws {
    lock.withLock { keys[pluginId] = key }
  }

  public func removeAPIKey(for pluginId: String) throws {
    _ = lock.withLock { keys.removeValue(forKey: pluginId) }
  }

  /// Key-free: lists plugin ids only.
  public var description: String {
    "InMemoryAPIKeyStore(plugins: \(lock.withLock { keys.keys.sorted() }))"
  }
}
