//
//  ElevenLabsEngine.swift
//  SwiftHablare
//
//  Engine Boundary implementation for ElevenLabs text-to-speech.
//

import Foundation

struct ElevenLabsEngineConfiguration: Sendable {
    let apiKey: String
    let userAgent: String
}

struct ElevenLabsEngine: VoiceEngine {
    typealias Configuration = ElevenLabsEngineConfiguration

    var engineId: String { "elevenlabs.tts" }

    func canGenerate(with configuration: ElevenLabsEngineConfiguration) -> Bool {
        !configuration.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func fetchVoices(
        languageCode: String,
        configuration: ElevenLabsEngineConfiguration
    ) async throws -> [Voice] {
        guard canGenerate(with: configuration) else {
            throw VoiceProviderError.notConfigured
        }

        let url = URL(string: "https://api.elevenlabs.io/v1/voices?language=\(languageCode)")!
        var request = URLRequest(url: url)
        request.setValue(configuration.apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue(configuration.userAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw VoiceProviderError.networkError("HTTP error")
        }

        let decoder = JSONDecoder()
        let voicesResponse = try decoder.decode(VoicesResponse.self, from: data)

        return voicesResponse.voices.map { voice in
            Voice(
                id: voice.id,
                name: voice.name,
                description: voice.description,
                providerId: "elevenlabs",
                language: voice.language,
                locality: voice.locality,
                gender: voice.gender
            )
        }
    }

    func generateAudio(
        request: VoiceEngineRequest,
        configuration: ElevenLabsEngineConfiguration
    ) async throws -> VoiceEngineOutput {
        guard canGenerate(with: configuration) else {
            throw VoiceProviderError.notConfigured
        }

        guard !request.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw VoiceProviderError.invalidRequest("Text cannot be empty")
        }

        let url = URL(string: "https://api.elevenlabs.io/v1/text-to-speech/\(request.voiceId)")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(configuration.apiKey, forHTTPHeaderField: "xi-api-key")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(configuration.userAgent, forHTTPHeaderField: "User-Agent")

        let body: [String: Any] = [
            "text": request.text,
            "model_id": request.options["model_id"] ?? "eleven_monolingual_v1",
            "voice_settings": [
                "stability": Double(request.options["stability"] ?? "0.5") ?? 0.5,
                "similarity_boost": Double(request.options["similarity_boost"] ?? "0.5") ?? 0.5
            ]
        ]

        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw VoiceProviderError.networkError("Invalid response from server")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
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

        return VoiceEngineOutput(
            audioData: data,
            audioFormat: .mp3,
            fileExtension: "mp3",
            mimeType: "audio/mpeg",
            metadata: [
                "engineId": engineId,
                "voiceId": request.voiceId,
                "languageCode": request.languageCode
            ]
        )
    }

    func estimateDuration(
        request: VoiceEngineRequest,
        configuration: ElevenLabsEngineConfiguration
    ) -> TimeInterval {
        let characterCount = Double(request.text.count)
        let baseCharsPerSecond = 13.0
        let stabilityValue = Double(request.options["stability"] ?? "0.5") ?? 0.5
        let stabilityFactor = 1.0 + ((0.5 - stabilityValue) * 0.1)
        let adjustedCharsPerSecond = baseCharsPerSecond * stabilityFactor
        let estimatedSeconds = characterCount / max(adjustedCharsPerSecond, 1)
        return max(1.0, estimatedSeconds * 1.15)
    }

    func isVoiceAvailable(
        voiceId: String,
        configuration: ElevenLabsEngineConfiguration
    ) async -> Bool {
        guard canGenerate(with: configuration) else {
            return false
        }

        let url = URL(string: "https://api.elevenlabs.io/v1/voices/\(voiceId)")!
        var request = URLRequest(url: url)
        request.setValue(configuration.apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue(configuration.userAgent, forHTTPHeaderField: "User-Agent")

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

struct VoicesResponse: Codable {
    let voices: [ElevenLabsVoice]
}

struct ElevenLabsVoice: Codable {
    let voice_id: String
    let name: String
    let description: String?
    let labels: VoiceLabels?
    let verified_languages: [VerifiedLanguage]?

    struct VoiceLabels: Codable {
        let accent: String?
        let description: String?
        let age: String?
        let gender: String?
        let use_case: String?
    }

    struct VerifiedLanguage: Codable {
        let language: String?
        let model_id: String?
        let accent: String?
        let locale: String?
        let preview_url: String?
    }

    var id: String { voice_id }

    var language: String? {
        let systemLanguageCode = Locale.current.language.languageCode?.identifier ?? "en"

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

        if let locale = verified_languages?.first?.locale {
            let parts = locale.split(whereSeparator: { $0 == "-" || $0 == "_" })
            return parts.first.map(String.init) ?? locale
        }
        return verified_languages?.first?.language ?? labels?.accent
    }

    var locality: String? {
        let systemLanguageCode = Locale.current.language.languageCode?.identifier ?? "en"

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

        if let locale = verified_languages?.first?.locale {
            let parts = locale.split(whereSeparator: { $0 == "-" || $0 == "_" })
            return parts.count > 1 ? String(parts[1]) : nil
        }
        return nil
    }

    var gender: String? {
        labels?.gender?.lowercased()
    }
}
