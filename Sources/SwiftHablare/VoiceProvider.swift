//
//  VoiceProvider.swift
//  SwiftHablare
//
//  Protocol defining voice provider capabilities
//

import Foundation

/// Protocol defining voice provider capabilities
public protocol VoiceProvider: Sendable {
    /// Unique identifier for the provider
    var providerId: String { get }

    /// Display name for the provider
    var displayName: String { get }

    /// Whether this provider requires an API key
    var requiresAPIKey: Bool { get }

    /// Check if the provider is properly configured
    func isConfigured() -> Bool

    /// Fetch available voices from the provider
    func fetchVoices() async throws -> [Voice]

    /// Generate audio data from text using a specific voice
    func generateAudio(text: String, voiceId: String) async throws -> Data

    /// Estimate the duration (in seconds) of audio that would be generated from the given text
    func estimateDuration(text: String, voiceId: String) async -> TimeInterval

    /// Check if a specific voice is available for this provider
    /// - Parameter voiceId: The voice identifier to check
    /// - Returns: True if the voice is available, false otherwise
    func isVoiceAvailable(voiceId: String) async -> Bool
}

/// Voice provider types
///
/// - Note: This enum is deprecated for extensibility. New providers should be registered
///   dynamically using `VoiceProviderManager.registerProvider(_:)` without modifying this enum.
///   The enum is kept for backward compatibility with existing code.
@available(*, deprecated, message: "Use dynamic provider registration instead. Register providers using VoiceProviderManager.registerProvider(_:)")
public enum VoiceProviderType: String, CaseIterable, Codable, Sendable {
    case elevenlabs = "elevenlabs"
    case apple = "apple"

    public var displayName: String {
        switch self {
        case .elevenlabs:
            return "ElevenLabs"
        case .apple:
            return "Apple Text-to-Speech"
        }
    }
}

/// Represents metadata about a registered voice provider
public struct VoiceProviderInfo: Identifiable, Sendable {
    public let id: String
    public let displayName: String
    public let requiresAPIKey: Bool
    public let isConfigured: Bool

    public init(id: String, displayName: String, requiresAPIKey: Bool, isConfigured: Bool) {
        self.id = id
        self.displayName = displayName
        self.requiresAPIKey = requiresAPIKey
        self.isConfigured = isConfigured
    }

    /// Create provider info from a VoiceProvider instance
    public init(from provider: VoiceProvider) {
        self.id = provider.providerId
        self.displayName = provider.displayName
        self.requiresAPIKey = provider.requiresAPIKey
        self.isConfigured = provider.isConfigured()
    }
}

/// Voice provider errors
public enum VoiceProviderError: LocalizedError, Sendable {
    case notConfigured
    case networkError(String)
    case invalidResponse
    case unsupportedProvider
    case notSupported
    case invalidRequest(String)

    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Voice provider is not configured. Please check your settings."
        case .networkError(let message):
            return "Network error: \(message)"
        case .invalidResponse:
            return "Invalid response from voice provider"
        case .unsupportedProvider:
            return "Unsupported voice provider"
        case .notSupported:
            return "Audio generation is not supported on this platform"
        case .invalidRequest(let message):
            return "Invalid request: \(message)"
        }
    }
}
