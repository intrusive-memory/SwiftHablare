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
        do {
            _ = try getAPIKey()
            return true
        } catch {
            return false
        }
    }

    public func fetchVoices() async throws -> [Voice] {
        guard let apiKey = try? getAPIKey() else {
            throw VoiceProviderError.notConfigured
        }

        let languageCode = Locale.current.language.languageCode?.identifier ?? "en"
        let url = URL(string: "https://api.elevenlabs.io/v1/voices?language=\(languageCode)")!
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw VoiceProviderError.networkError("HTTP error")
        }

        let decoder = JSONDecoder()
        let voicesResponse = try decoder.decode(VoicesResponse.self, from: data)

        // Add provider ID to each voice
        return voicesResponse.voices.map { elevenLabsVoice in
            Voice(
                id: elevenLabsVoice.id,
                name: elevenLabsVoice.name,
                description: elevenLabsVoice.description,
                providerId: providerId,
                language: elevenLabsVoice.language,
                locality: elevenLabsVoice.locality,
                gender: elevenLabsVoice.gender
            )
        }
    }

    public func generateAudio(text: String, voiceId: String) async throws -> Data {
        guard let apiKey = try? getAPIKey() else {
            throw VoiceProviderError.notConfigured
        }

        // Validate text is not empty
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw VoiceProviderError.invalidRequest("Text cannot be empty")
        }

        let url = URL(string: "https://api.elevenlabs.io/v1/text-to-speech/\(voiceId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "text": text,
            "model_id": "eleven_monolingual_v1",
            "voice_settings": [
                "stability": 0.5,
                "similarity_boost": 0.5
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw VoiceProviderError.networkError("Invalid response from server")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            // Try to parse error message from response
            var errorMessage = "HTTP \(httpResponse.statusCode)"
            if let errorJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = errorJSON["detail"] as? [String: Any],
               let message = detail["message"] as? String {
                errorMessage += ": \(message)"
            } else if let errorJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let message = errorJSON["message"] as? String {
                errorMessage += ": \(message)"
            } else if let errorString = String(data: data, encoding: .utf8) {
                errorMessage += ": \(errorString)"
            }

            throw VoiceProviderError.networkError(errorMessage)
        }

        return data
    }

    public func estimateDuration(text: String, voiceId: String) async -> TimeInterval {
        // ElevenLabs doesn't provide a duration estimation API
        // We'll estimate based on character count and typical speech rate

        // Average professional narration: ~150-160 words per minute
        // Average word length: ~5 characters
        // So approximately 750-800 characters per minute, or ~13 characters per second

        let characterCount = Double(text.count)
        let baseCharsPerSecond = 13.0

        // Account for stability settings - higher stability = slightly slower
        // Our current settings use 0.5 stability which is neutral
        let stabilityFactor = 1.0

        let adjustedCharsPerSecond = baseCharsPerSecond * stabilityFactor
        let estimatedSeconds = characterCount / adjustedCharsPerSecond

        // Add buffer for punctuation pauses and natural speech rhythm
        return max(1.0, estimatedSeconds * 1.15)
    }

    public func isVoiceAvailable(voiceId: String) async -> Bool {
        // Check if API key is configured
        guard let apiKey = try? getAPIKey() else {
            return false
        }

        // Make a lightweight API call to check if voice exists
        let url = URL(string: "https://api.elevenlabs.io/v1/voices/\(voiceId)")!
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                return (200...299).contains(httpResponse.statusCode)
            }

            return false
        } catch {
            return false
        }
    }
}

// MARK: - API Response Types

public struct VoicesResponse: Codable {
    public let voices: [ElevenLabsVoice]
}

public struct ElevenLabsVoice: Codable {
    public let voice_id: String
    public let name: String
    public let description: String?
    public let labels: VoiceLabels?
    public let verified_languages: [VerifiedLanguage]?

    public struct VoiceLabels: Codable {
        public let accent: String?
        public let description: String?
        public let age: String?
        public let gender: String?
        public let use_case: String?
    }

    public struct VerifiedLanguage: Codable {
        public let language: String?
        public let model_id: String?
        public let accent: String?
        public let locale: String?
        public let preview_url: String?
    }

    public var id: String { voice_id }

    public var language: String? {
        // Get system language code
        let systemLanguageCode = Locale.current.language.languageCode?.identifier ?? "en"

        // Find matching verified language
        if let verifiedLanguages = verified_languages {
            for verifiedLang in verifiedLanguages {
                if let locale = verifiedLang.locale {
                    let parts = locale.split(whereSeparator: { $0 == "-" || $0 == "_" })
                    if let languageCode = parts.first.map(String.init), languageCode == systemLanguageCode {
                        return languageCode
                    }
                }
            }
        }

        // Fall back to first verified language or accent
        if let locale = verified_languages?.first?.locale {
            let parts = locale.split(whereSeparator: { $0 == "-" || $0 == "_" })
            return parts.first.map(String.init) ?? locale
        }
        return verified_languages?.first?.language ?? labels?.accent
    }

    public var locality: String? {
        // Get system language code
        let systemLanguageCode = Locale.current.language.languageCode?.identifier ?? "en"

        // Find matching verified language and return its locality
        if let verifiedLanguages = verified_languages {
            for verifiedLang in verifiedLanguages {
                if let locale = verifiedLang.locale {
                    let parts = locale.split(whereSeparator: { $0 == "-" || $0 == "_" })
                    if let languageCode = parts.first.map(String.init), languageCode == systemLanguageCode {
                        return parts.count > 1 ? String(parts[1]) : nil
                    }
                }
            }
        }

        // Fall back to first verified language locality
        if let locale = verified_languages?.first?.locale {
            let parts = locale.split(whereSeparator: { $0 == "-" || $0 == "_" })
            return parts.count > 1 ? String(parts[1]) : nil
        }
        return nil
    }

    public var gender: String? {
        return labels?.gender?.lowercased()
    }
}
