//
//  SpeakableItem.swift
//  SwiftHablare
//
//  Protocol for any type that can be converted to speech
//

import Foundation

// MARK: - Language Code Utilities

/// Get the system's current language code
///
/// Returns the user's preferred language code (e.g., "en", "es", "fr").
/// Falls back to "en" if the language code cannot be determined.
public func systemLanguageCode() -> String {
    return LanguageCodeResolver.systemLanguageCode
}

/// A protocol that defines the requirements for any type that can be spoken.
///
/// Conforming types must provide a voice provider, voice ID, and text to speak.
/// This allows any object in your application to become speakable by implementing
/// these three simple requirements.
///
/// ## Example Usage
///
/// ```swift
/// struct Message: SpeakableItem {
///     let sender: String
///     let content: String
///     let voiceProvider: VoiceProvider
///     let voiceId: String
///
///     var textToSpeak: String {
///         "\(sender) says: \(content)"
///     }
/// }
///
/// // Generate audio
/// let message = Message(
///     sender: "Alice",
///     content: "Hello, world!",
///     voiceProvider: AppleVoiceProvider(),
///     voiceId: "com.apple.voice.enhanced.en-US.Samantha"
/// )
///
/// let audioData = try await message.speak()
/// ```
///
/// ## Design Philosophy
///
/// SwiftHablaré follows a protocol-oriented approach where any type can become
/// speakable by conforming to `SpeakableItem`. This allows:
///
/// - **Flexibility**: Any struct, class, or enum can be spoken
/// - **Reusability**: Voice configuration travels with the object
/// - **Testability**: Easy to create mock speakable items
/// - **Composability**: Combine with other protocols as needed
///
/// ## Thread Safety
///
/// The `speak()` method is async and thread-safe. It uses the underlying
/// voice provider's concurrency model (typically actor-based) to ensure
/// safe concurrent access.
///
public protocol SpeakableItem {
    /// The voice provider to use for speech synthesis
    ///
    /// This can be any implementation of `VoiceProvider`, such as:
    /// - `AppleVoiceProvider` for iOS TTS
    /// - `ElevenLabsVoiceProvider` for ElevenLabs API
    /// - Custom providers you implement
    var voiceProvider: VoiceProvider { get }

    /// The voice ID to use for speech synthesis
    ///
    /// This must be a valid voice ID for the specified provider:
    /// - For Apple: Use identifiers from `AVSpeechSynthesisVoice`
    /// - For ElevenLabs: Use voice IDs from their API
    ///
    /// ## Example
    /// ```swift
    /// // Apple voice
    /// voiceId = "com.apple.voice.enhanced.en-US.Samantha"
    ///
    /// // ElevenLabs voice
    /// voiceId = "21m00Tcm4TlvDq8ikWAM"
    /// ```
    var voiceId: String { get }

    /// The text that should be spoken
    ///
    /// This can be computed based on the object's properties, allowing
    /// you to compose speech from multiple fields or apply formatting.
    ///
    /// ## Example
    /// ```swift
    /// struct Article: SpeakableItem {
    ///     let title: String
    ///     let author: String
    ///     let content: String
    ///
    ///     var textToSpeak: String {
    ///         "\(title), by \(author). \(content)"
    ///     }
    /// }
    /// ```
    var textToSpeak: String { get }

    /// The language code for speech synthesis
    ///
    /// This is the ISO 639-1 language code (e.g., "en", "es", "fr") used
    /// for voice selection and generation. Defaults to the system's current
    /// language if not explicitly provided.
    ///
    /// ## Example
    /// ```swift
    /// // Use system language (default)
    /// var languageCode: String { systemLanguageCode() }
    ///
    /// // Use specific language
    /// var languageCode: String { "es" }
    /// ```
    var languageCode: String { get }
}

// MARK: - Default Implementation

extension SpeakableItem {
    /// Default language code returns the system's current language
    public var languageCode: String {
        systemLanguageCode()
    }
}

// MARK: - Convenience Methods

extension SpeakableItem {
    /// Generate audio for this speakable item
    ///
    /// This is a convenience method that calls the voice provider's
    /// `generateAudio` method with the item's voice ID and text.
    ///
    /// - Returns: Audio data in the format specified by the voice provider
    ///   (AIFF for Apple, MP3 for ElevenLabs, etc.)
    /// - Throws: `VoiceProviderError` if audio generation fails
    ///
    /// ## Example
    /// ```swift
    /// let item = MyItem(...)
    /// let audioData = try await item.speak()
    /// // Play or save audioData
    /// ```
    ///
    /// ## Thread Safety
    /// This method is async and thread-safe. Multiple items can be spoken
    /// concurrently without data races.
    public func speak() async throws -> Data {
        try await voiceProvider.generateAudio(text: textToSpeak, voiceId: voiceId, languageCode: languageCode)
    }

    /// Estimate the duration of the generated speech
    ///
    /// This provides an approximate duration in seconds for the speech
    /// that would be generated. Useful for UI progress indicators or
    /// scheduling.
    ///
    /// - Returns: Estimated duration in seconds
    ///
    /// ## Note
    /// This is an estimate based on text length and speech rate.
    /// Actual duration may vary slightly.
    public func estimateDuration() async -> TimeInterval {
        await voiceProvider.estimateDuration(text: textToSpeak, voiceId: voiceId)
    }

    /// Check if the specified voice is available
    ///
    /// - Returns: `true` if the voice is available, `false` otherwise
    ///
    /// ## Example
    /// ```swift
    /// if await item.isVoiceAvailable() {
    ///     let audio = try await item.speak()
    /// } else {
    ///     print("Voice not available")
    /// }
    /// ```
    public func isVoiceAvailable() async -> Bool {
        await voiceProvider.isVoiceAvailable(voiceId: voiceId)
    }
}

// MARK: - Batch Operations

extension Collection where Element: SpeakableItem {
    /// Speak all items in the collection sequentially
    ///
    /// This generates audio for each item in order, returning an array
    /// of audio data in the same order as the items.
    ///
    /// - Returns: Array of audio data for each item
    /// - Throws: `VoiceProviderError` if any generation fails
    ///
    /// ## Example
    /// ```swift
    /// let messages: [Message] = [...]
    /// let audioFiles = try await messages.speakAll()
    /// // Play each audio file in sequence
    /// ```
    ///
    /// ## Performance Note
    /// Items are spoken sequentially. For parallel generation, use
    /// `TaskGroup` or similar concurrency patterns.
    public func speakAll() async throws -> [Data] {
        var results: [Data] = []
        for item in self {
            let audio = try await item.speak()
            results.append(audio)
        }
        return results
    }

    /// Estimate total duration for all items
    ///
    /// - Returns: Total estimated duration in seconds
    public func estimateTotalDuration() async -> TimeInterval {
        var total: TimeInterval = 0
        for item in self {
            total += await item.estimateDuration()
        }
        return total
    }
}
