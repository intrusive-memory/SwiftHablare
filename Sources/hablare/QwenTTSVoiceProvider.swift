//
//  QwenTTSVoiceProvider.swift
//  SwiftHablare
//
//  VoiceProvider implementation for Qwen3-TTS via MLX on Apple Silicon.
//

import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif
import QwenTTSEngine
import SwiftHablare

/// Voice provider for Qwen3-TTS local neural text-to-speech.
/// Runs entirely on-device using MLX on Apple Silicon.
public final class QwenTTSVoiceProvider: VoiceProvider, @unchecked Sendable {

    public let providerId = "qwen-tts"
    public let displayName = "Qwen TTS (Local)"
    public let requiresAPIKey = false
    public let mimeType = "audio/wav"

    private let engine = QwenTTSEngine()
    private var isLoaded = false

    public init() {}

    public func isConfigured() async -> Bool {
        await engine.isModelDownloaded()
    }

    public func fetchVoices(languageCode: String) async throws -> [Voice] {
        try await ensureLoaded()
        let qwenVoices = await engine.availableVoices()
        return qwenVoices.map { voice in
            Voice(
                id: voice.id,
                name: voice.name,
                description: "Qwen3-TTS voice",
                providerId: providerId,
                language: voice.language ?? languageCode
            )
        }
    }

    public func generateAudio(text: String, voiceId: String, languageCode: String) async throws -> Data {
        try await ensureLoaded()

        // Map language code to language name
        let language = mapLanguageCode(languageCode)

        return try await engine.generateToData(
            text: text,
            voice: voiceId.isEmpty ? nil : voiceId,
            language: language
        )
    }

    public func estimateDuration(text: String, voiceId: String) async -> TimeInterval {
        // Rough estimate: ~150 words per minute for TTS
        let wordCount = Double(text.split(separator: " ").count)
        return max(0.5, wordCount / 2.5)
    }

    public func isVoiceAvailable(voiceId: String) async -> Bool {
        guard await isConfigured() else { return false }
        try? await ensureLoaded()
        let voices = await engine.availableVoices()
        return voices.contains { $0.id == voiceId || $0.name.lowercased() == voiceId.lowercased() }
    }

    #if canImport(SwiftUI)
    @MainActor
    public func makeConfigurationView(onConfigured: @escaping (Bool) -> Void) -> AnyView {
        AnyView(
            Text("Qwen TTS runs locally. Use 'hablare download' to fetch model weights.")
                .padding()
        )
    }
    #endif

    // MARK: - Private

    private func ensureLoaded() async throws {
        guard !isLoaded else { return }
        try await engine.loadModel()
        isLoaded = true
    }

    private func mapLanguageCode(_ code: String) -> String {
        let prefix = String(code.prefix(2)).lowercased()
        switch prefix {
        case "en": return "english"
        case "zh": return "chinese"
        case "de": return "german"
        case "it": return "italian"
        case "pt": return "portuguese"
        case "es": return "spanish"
        case "ja": return "japanese"
        case "ko": return "korean"
        case "fr": return "french"
        case "ru": return "russian"
        default: return "english"
        }
    }
}
