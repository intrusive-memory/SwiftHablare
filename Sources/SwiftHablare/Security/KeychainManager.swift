//
//  KeychainManager.swift
//  SwiftHablare
//
//  Simple keychain manager for storing API keys
//

import Foundation
import Security

/// Simple keychain manager for storing API keys
public final class KeychainManager: @unchecked Sendable {

    // MARK: - Singleton

    public static let shared = KeychainManager()

    private init() {}

    // MARK: - Errors

    public enum KeychainError: LocalizedError {
        case notFound
        case saveFailed(OSStatus)
        case deleteFailed(OSStatus)
        case invalidData

        public var errorDescription: String? {
            switch self {
            case .notFound:
                return "API key not found in keychain"
            case .saveFailed(let status):
                return "Failed to save API key to keychain (status: \(status))"
            case .deleteFailed(let status):
                return "Failed to delete API key from keychain (status: \(status))"
            case .invalidData:
                return "Invalid data retrieved from keychain"
            }
        }
    }

    // MARK: - API Key Management

    /// Save an API key to the keychain
    ///
    /// - Parameters:
    ///   - key: The API key to save
    ///   - account: Account identifier (e.g., "elevenlabs-api-key")
    /// - Throws: KeychainError if save fails
    public func saveAPIKey(_ key: String, for account: String) throws {
        guard let data = key.data(using: .utf8) else {
            throw KeychainError.invalidData
        }

        // Delete existing key if present
        try? deleteAPIKey(for: account)

        // Add new key
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    /// Retrieve an API key from the keychain
    ///
    /// - Parameter account: Account identifier
    /// - Returns: The API key
    /// - Throws: KeychainError if not found or retrieval fails
    public func getAPIKey(for account: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            throw KeychainError.notFound
        }

        guard let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }

        return key
    }

    /// Delete an API key from the keychain
    ///
    /// - Parameter account: Account identifier
    /// - Throws: KeychainError if deletion fails
    public func deleteAPIKey(for account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }

    /// Check if an API key exists
    ///
    /// - Parameter account: Account identifier
    /// - Returns: True if key exists
    public func hasAPIKey(for account: String) -> Bool {
        return (try? getAPIKey(for: account)) != nil
    }
}
