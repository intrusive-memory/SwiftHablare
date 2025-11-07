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

    // Engine boundary adapter for platform-specific implementations
    private let engine: AppleTTSEngineBoundary
    private let configuration = AppleTTSConfiguration()

    public init() {
        #if os(iOS) || targetEnvironment(macCatalyst)
        self.engine = AppleTTSEngineBoundary(underlying: AVSpeechTTSEngine())
        #elseif os(macOS)
        self.engine = AppleTTSEngineBoundary(underlying: NSSpeechTTSEngine())
        #else
        fatalError("Unsupported platform for Apple TTS")
        #endif
    }

    public func isConfigured() -> Bool {
        // Apple TTS is always available on supported platforms
        return engine.canGenerate(with: configuration)
    }

    public func fetchVoices(languageCode: String) async throws -> [Voice] {
        return try await engine.fetchVoices(languageCode: languageCode, configuration: configuration)
    }

    public func generateAudio(text: String, voiceId: String, languageCode: String) async throws -> Data {
        let request = engine.makeRequest(text: text, voiceId: voiceId, languageCode: languageCode)
        let output = try await engine.generateAudio(request: request, configuration: configuration)
        return output.audioData
    }

    public func estimateDuration(text: String, voiceId: String) async -> TimeInterval {
        let request = engine.makeRequest(text: text, voiceId: voiceId, languageCode: Locale.current.language.languageCode?.identifier ?? "en")
        return engine.estimateDuration(request: request, configuration: configuration)
    }

    public func isVoiceAvailable(voiceId: String) async -> Bool {
        return await engine.isVoiceAvailable(voiceId: voiceId, configuration: configuration)
    }
}
