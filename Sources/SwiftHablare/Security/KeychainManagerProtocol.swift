//
//  KeychainManagerProtocol.swift
//  SwiftHablare
//
//  Protocol for keychain access to enable dependency injection and testing
//

import Foundation

/// Protocol for keychain operations
///
/// Allows providers to work with different keychain implementations:
/// - Production: KeychainManager (direct keychain access)
/// - Testing: MockKeychainManager (in-memory storage)
/// - Session-based: Custom implementations with caching and biometric auth
///
/// **Swift Concurrency**: All methods are async to support:
/// - Lazy loading with session caching
/// - Biometric authentication prompts
/// - Thread-safe actor-based implementations
public protocol KeychainManagerProtocol: Sendable {
    /// Save an API key to secure storage
    /// - Parameters:
    ///   - key: API key to save
    ///   - account: Account identifier (e.g., "elevenlabs-api-key")
    /// - Throws: Error if save fails
    func saveAPIKey(_ key: String, for account: String) async throws

    /// Retrieve an API key from secure storage
    /// - Parameter account: Account identifier
    /// - Returns: The API key
    /// - Throws: Error if not found or retrieval fails
    func getAPIKey(for account: String) async throws -> String

    /// Delete an API key from secure storage
    /// - Parameter account: Account identifier
    /// - Throws: Error if deletion fails
    func deleteAPIKey(for account: String) async throws

    /// Check if an API key exists in secure storage
    /// - Parameter account: Account identifier
    /// - Returns: True if key exists
    func hasAPIKey(for account: String) async -> Bool
}
