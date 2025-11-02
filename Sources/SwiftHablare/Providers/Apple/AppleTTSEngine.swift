//
//  AppleTTSEngine.swift
//  SwiftHablare
//
//  Platform-agnostic TTS engine protocol for Apple platforms
//

import Foundation

/// Protocol defining the interface for platform-specific Apple TTS engines
///
/// This protocol abstracts the differences between iOS (`AVSpeechSynthesizer`)
/// and macOS (`NSSpeechSynthesizer`) TTS implementations.
///
/// ## Platform Implementations
/// - **iOS**: `AVSpeechTTSEngine` - Uses `AVSpeechSynthesizer.write()`
/// - **macOS**: `NSSpeechTTSEngine` - Uses `NSSpeechSynthesizer.startSpeaking(to:)`
///
/// ## Example Usage
/// ```swift
/// let engine: AppleTTSEngine
/// #if canImport(UIKit)
/// engine = AVSpeechTTSEngine()
/// #elseif canImport(AppKit)
/// engine = NSSpeechTTSEngine()
/// #endif
///
/// let audio = try await engine.generateAudio(text: "Hello", voiceId: "...")
/// ```
protocol AppleTTSEngine: Sendable {

    /// Generate audio data from text using specified voice
    ///
    /// - Parameters:
    ///   - text: The text to synthesize
    ///   - voiceId: Platform-specific voice identifier
    /// - Returns: Audio data in AIFF or AIFC format
    /// - Throws: `VoiceProviderError` if synthesis fails
    func generateAudio(text: String, voiceId: String) async throws -> Data

    /// Get all available voices for this platform
    ///
    /// - Returns: Array of Voice objects with platform-specific IDs
    /// - Throws: `VoiceProviderError` if voices cannot be fetched
    func fetchVoices() async throws -> [Voice]

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
