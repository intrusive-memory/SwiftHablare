//
//  ElevenLabsVoiceProvider.swift
//  SwiftHablare
//
//  ElevenLabs implementation of VoiceProvider
//

import Foundation

/// ElevenLabs implementation of VoiceProvider
public final class ElevenLabsVoiceProvider: VoiceProvider {
    public let providerId = "elevenlabs"
    public let displayName = "ElevenLabs"
    public let requiresAPIKey = true

    private let keychainManager = KeychainManager.shared
    private let apiKeyAccount = "elevenlabs-api-key"
    private let ephemeralAPIKey: String?
    private let engine = ElevenLabsEngine()

    /// Initialize with optional ephemeral API key (for testing)
    /// - Parameter apiKey: Optional API key to use instead of keychain (primarily for testing)
    public init(apiKey: String? = nil) {
        self.ephemeralAPIKey = apiKey
    }

    /// Get API key from ephemeral storage (test) or keychain (production)
    private func getAPIKey() throws -> String {
        if let ephemeralKey = ephemeralAPIKey {
            return ephemeralKey
        }
        return try keychainManager.getAPIKey(for: apiKeyAccount)
    }

    public func isConfigured() -> Bool {
        guard let apiKey = try? getAPIKey() else {
            return false
        }
        let configuration = ElevenLabsEngineConfiguration(apiKey: apiKey)
        return engine.canGenerate(with: configuration)
    }

    public func fetchVoices(languageCode: String) async throws -> [Voice] {
        let configuration = ElevenLabsEngineConfiguration(apiKey: try getAPIKey())
        return try await engine.fetchVoices(languageCode: languageCode, configuration: configuration)
    }

    public func generateAudio(text: String, voiceId: String, languageCode: String) async throws -> Data {
        let configuration = ElevenLabsEngineConfiguration(apiKey: try getAPIKey())
        let request = engine.makeRequest(text: text, voiceId: voiceId, languageCode: languageCode, options: [
            "model_id": "eleven_monolingual_v1",
            "stability": "0.5",
            "similarity_boost": "0.5"
        ])
        let output = try await engine.generateAudio(request: request, configuration: configuration)
        return output.audioData
    }

    public func estimateDuration(text: String, voiceId: String) async -> TimeInterval {
        let configuration = ElevenLabsEngineConfiguration(apiKey: (try? getAPIKey()) ?? "")
        let request = engine.makeRequest(text: text, voiceId: voiceId, languageCode: Locale.current.language.languageCode?.identifier ?? "en", options: [
            "stability": "0.5"
        ])
        return engine.estimateDuration(request: request, configuration: configuration)
    }

    public func isVoiceAvailable(voiceId: String) async -> Bool {
        guard let apiKey = try? getAPIKey() else {
            return false
        }
        let configuration = ElevenLabsEngineConfiguration(apiKey: apiKey)
        return await engine.isVoiceAvailable(voiceId: voiceId, configuration: configuration)
    }
}
