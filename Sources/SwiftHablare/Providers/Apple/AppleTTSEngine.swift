//
//  AppleTTSEngine.swift
//  SwiftHablare
//
//  Platform-agnostic TTS engine protocol for Apple platforms
//

import Foundation

/// Protocol defining the interface for Apple TTS engines
///
/// This protocol provides a unified interface for Apple's text-to-speech
/// functionality using `AVSpeechSynthesizer` on both iOS and macOS.
///
/// ## Platform Implementation
/// - **iOS & macOS**: `AVSpeechTTSEngine` - Uses `AVSpeechSynthesizer.write()`
///
/// ## Example Usage
/// ```swift
/// let engine = AVSpeechTTSEngine()
/// let audio = try await engine.generateAudio(text: "Hello", voiceId: "...")
/// ```
protocol AppleTTSEngine: Sendable {

    /// Generate audio data from text using specified voice
    ///
    /// - Parameters:
    ///   - text: The text to synthesize
    ///   - voiceId: Platform-specific voice identifier
    ///   - languageCode: The language code for generation (e.g., "en", "es", "fr")
    /// - Returns: Audio data in AIFF or AIFC format
    /// - Throws: `VoiceProviderError` if synthesis fails
    func generateAudio(text: String, voiceId: String, languageCode: String) async throws -> Data

    /// Generate audio with accurate duration measured from buffer frames
    ///
    /// - Parameters:
    ///   - text: The text to synthesize
    ///   - voiceId: Platform-specific voice identifier
    ///   - languageCode: The language code for generation (e.g., "en", "es", "fr")
    /// - Returns: Tuple of (audio data, duration in seconds)
    /// - Throws: `VoiceProviderError` if synthesis fails
    func generateAudioWithDuration(text: String, voiceId: String, languageCode: String) async throws -> (Data, TimeInterval)

    /// Get all available voices for this platform
    ///
    /// - Parameter languageCode: Language code to filter voices (e.g., "en", "es", "fr")
    /// - Returns: Array of Voice objects with platform-specific IDs, filtered by language
    /// - Throws: `VoiceProviderError` if voices cannot be fetched
    func fetchVoices(languageCode: String) async throws -> [Voice]

    /// Estimate the duration for synthesizing given text
    ///
    /// This is used for UI feedback and estimating file sizes before generation.
    ///
    /// - Parameters:
    ///   - text: The text that would be synthesized
    ///   - voiceId: The voice that would be used
    /// - Returns: Estimated duration in seconds
    func estimateDuration(text: String, voiceId: String) -> TimeInterval
}

// MARK: - Default Language Code Extensions

extension AppleTTSEngine {
    /// Fetch available voices using system language code as default
    func fetchVoices() async throws -> [Voice] {
        let languageCode = Locale.current.language.languageCode?.identifier ?? "en"
        return try await fetchVoices(languageCode: languageCode)
    }

    /// Generate audio using system language code as default
    func generateAudio(text: String, voiceId: String) async throws -> Data {
        let languageCode = Locale.current.language.languageCode?.identifier ?? "en"
        return try await generateAudio(text: text, voiceId: voiceId, languageCode: languageCode)
    }
}
