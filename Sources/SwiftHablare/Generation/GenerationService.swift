//
//  GenerationService.swift
//  SwiftHablare
//
//  Actor-based service for coordinating audio generation with safe concurrency
//

import Foundation
import SwiftData
import SwiftCompartido

/// Result of audio generation
public struct GenerationResult: Sendable {
    /// Generated audio data
    public let audioData: Data

    /// Original text that was spoken
    public let originalText: String

    /// Voice ID used for generation
    public let voiceId: String

    /// Voice name (if available)
    public let voiceName: String?

    /// Provider ID
    public let providerId: String

    /// MIME type of generated audio
    public let mimeType: String

    /// Estimated duration in seconds
    public let estimatedDuration: TimeInterval

    /// Request ID for tracking
    public let requestId: UUID

    public init(
        audioData: Data,
        originalText: String,
        voiceId: String,
        voiceName: String?,
        providerId: String,
        mimeType: String,
        estimatedDuration: TimeInterval,
        requestId: UUID = UUID()
    ) {
        self.audioData = audioData
        self.originalText = originalText
        self.voiceId = voiceId
        self.voiceName = voiceName
        self.providerId = providerId
        self.mimeType = mimeType
        self.estimatedDuration = estimatedDuration
        self.requestId = requestId
    }
}

/// Actor-based service for coordinating audio generation with safe concurrency
///
/// This service ensures thread-safe audio generation by:
/// 1. Generating audio on background thread (via actor isolation)
/// 2. Returning Sendable results to main thread
/// 3. Main thread saves to TypedDataStorage and links to GuionElementModel
///
/// ## Usage
///
/// ```swift
/// // Create service with voice provider
/// let service = GenerationService(voiceProvider: ElevenLabsVoiceProvider())
///
/// // Generate audio (happens on background thread)
/// let result = try await service.generate(
///     text: element.elementText,
///     voiceId: "voice123",
///     voiceName: "Rachel"
/// )
///
/// // Save to SwiftData (on main thread)
/// await MainActor.run {
///     let audioRecord = result.toTypedDataStorage()
///     element.generatedContent?.append(audioRecord)
///     modelContext.insert(audioRecord)
///     try? modelContext.save()
/// }
/// ```
public actor GenerationService {

    // MARK: - Properties

    /// Voice provider for generating audio
    private let voiceProvider: VoiceProvider

    /// Default MIME type for generated audio
    private let defaultMimeType: String

    // MARK: - Initialization

    /// Create a generation service
    ///
    /// - Parameters:
    ///   - voiceProvider: Voice provider (Apple TTS or ElevenLabs)
    ///   - defaultMimeType: Default MIME type (default: "audio/mpeg")
    public init(voiceProvider: VoiceProvider, defaultMimeType: String = "audio/mpeg") {
        self.voiceProvider = voiceProvider
        self.defaultMimeType = defaultMimeType
    }

    // MARK: - Generation

    /// Generate audio from text
    ///
    /// This method runs on a background thread (actor-isolated) and is non-blocking.
    /// The result is Sendable and can be safely transferred to the main thread.
    ///
    /// - Parameters:
    ///   - text: Text to convert to speech
    ///   - voiceId: Voice identifier from provider
    ///   - voiceName: Voice name for metadata (optional)
    ///   - mimeType: MIME type for audio (optional, uses default if not specified)
    /// - Returns: GenerationResult with audio data and metadata
    /// - Throws: VoiceProviderError if generation fails
    public func generate(
        text: String,
        voiceId: String,
        voiceName: String? = nil,
        mimeType: String? = nil
    ) async throws -> GenerationResult {
        // Ensure provider is configured
        guard voiceProvider.isConfigured() else {
            throw VoiceProviderError.notConfigured
        }

        // Estimate duration before generation
        let estimatedDuration = await voiceProvider.estimateDuration(text: text, voiceId: voiceId)

        // Generate audio (this happens on background thread via actor isolation)
        let audioData = try await voiceProvider.generateAudio(text: text, voiceId: voiceId)

        // Create result (Sendable, can be transferred to main thread)
        return GenerationResult(
            audioData: audioData,
            originalText: text,
            voiceId: voiceId,
            voiceName: voiceName,
            providerId: voiceProvider.providerId,
            mimeType: mimeType ?? defaultMimeType,
            estimatedDuration: estimatedDuration
        )
    }

    /// Generate audio for a GuionElementModel
    ///
    /// This is a convenience method that extracts text from the element
    /// and generates audio. The result must be saved to SwiftData on the main thread.
    ///
    /// - Parameters:
    ///   - element: GuionElementModel to generate audio for
    ///   - voiceId: Voice identifier from provider
    ///   - voiceName: Voice name for metadata (optional)
    ///   - mimeType: MIME type for audio (optional)
    /// - Returns: GenerationResult that can be converted to TypedDataStorage
    /// - Throws: VoiceProviderError if generation fails
    public func generate(
        forElement element: GuionElementModel,
        voiceId: String,
        voiceName: String? = nil,
        mimeType: String? = nil
    ) async throws -> GenerationResult {
        return try await generate(
            text: element.elementText,
            voiceId: voiceId,
            voiceName: voiceName,
            mimeType: mimeType
        )
    }

    /// Fetch available voices from the provider
    ///
    /// This method can be called to refresh the voice list and update the cache.
    ///
    /// - Returns: Array of available voices
    /// - Throws: VoiceProviderError if fetch fails
    public func fetchVoices() async throws -> [Voice] {
        guard voiceProvider.isConfigured() else {
            throw VoiceProviderError.notConfigured
        }

        return try await voiceProvider.fetchVoices()
    }

    /// Check if a voice is available
    ///
    /// - Parameter voiceId: Voice identifier to check
    /// - Returns: True if voice is available
    public func isVoiceAvailable(_ voiceId: String) async -> Bool {
        return await voiceProvider.isVoiceAvailable(voiceId: voiceId)
    }
}

// MARK: - GenerationResult Extensions

extension GenerationResult {

    /// Convert result to TypedDataStorage for SwiftData persistence
    ///
    /// This method creates a TypedDataStorage instance from SwiftCompartido
    /// that can be inserted into SwiftData and linked to GuionElementModel.
    ///
    /// **Must be called on @MainActor**
    ///
    /// - Returns: TypedDataStorage instance ready for SwiftData
    @MainActor
    public func toTypedDataStorage() -> TypedDataStorage {
        return TypedDataStorage(
            id: requestId,
            providerId: providerId,
            requestorID: "\(providerId).audio.tts",
            mimeType: mimeType,
            textValue: nil,  // Audio is binary
            binaryValue: audioData,
            prompt: originalText,
            durationSeconds: estimatedDuration,
            voiceID: voiceId,
            voiceName: voiceName
        )
    }
}
