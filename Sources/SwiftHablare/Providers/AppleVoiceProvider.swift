//
//  AppleVoiceProvider.swift
//  SwiftHablare
//
//  Apple Text-to-Speech implementation of VoiceProvider
//

import Foundation

/// Apple Text-to-Speech implementation of VoiceProvider
///
/// **Platform Support:**
/// - **iOS 13+**: Full TTS support with real audio generation using `AVSpeechSynthesizer.write()`
/// - **macOS 10.13+**: Full TTS support with real audio generation using `NSSpeechSynthesizer`
///
/// **Audio Output:**
/// - **iOS**: AIFC format with actual synthesized speech (physical device), AIFF placeholder (simulator)
/// - **macOS**: AIFF format with actual synthesized speech
///
/// **Implementation:**
/// This provider delegates to platform-specific engines:
/// - iOS: `AVSpeechTTSEngine` (using AVSpeechSynthesizer)
/// - macOS: `NSSpeechTTSEngine` (using NSSpeechSynthesizer)
public final class AppleVoiceProvider: VoiceProvider {
    public let providerId = "apple"
    public let displayName = "Apple Text-to-Speech"
    public let requiresAPIKey = false

    // Platform-specific engine
    private let engine: AppleTTSEngine

    public init() {
        #if os(iOS) || targetEnvironment(macCatalyst)
        self.engine = AVSpeechTTSEngine()
        #elseif os(macOS)
        self.engine = NSSpeechTTSEngine()
        #else
        fatalError("Unsupported platform for Apple TTS")
        #endif
    }

    public func isConfigured() -> Bool {
        // Apple TTS is always available on supported platforms
        return true
    }

    public func fetchVoices(languageCode: String) async throws -> [Voice] {
        return try await engine.fetchVoices(languageCode: languageCode)
    }

    public func generateAudio(text: String, voiceId: String, languageCode: String) async throws -> Data {
        return try await engine.generateAudio(text: text, voiceId: voiceId, languageCode: languageCode)
    }

    public func estimateDuration(text: String, voiceId: String) async -> TimeInterval {
        return engine.estimateDuration(text: text, voiceId: voiceId)
    }

    public func isVoiceAvailable(voiceId: String) async -> Bool {
        // Check if the voice exists in the fetched voices
        do {
            let voices = try await fetchVoices()
            return voices.contains { $0.id == voiceId }
        } catch {
            return false
        }
    }
}
