//
//  VoiceGenerationService.swift
//  SwiftHablare
//
//  Thread-safe service for voice generation
//

import Foundation
import SwiftData

/// Thread-safe service for generating voice audio.
///
/// This actor ensures thread-safe voice generation with proper concurrency:
/// - Generation happens on background threads
/// - Results are Sendable and can be passed to main thread
/// - SwiftData storage happens on @MainActor
///
/// ## Thread Safety Architecture
///
/// ```
/// Background Thread           Main Thread (@MainActor)
/// ─────────────────           ────────────────────────
/// 1. generate(request)
///    ├─> Call provider API
///    ├─> Process audio
///    └─> Create result (Sendable)
///                            2. toTypedDataStorage()
///                               ├─> Create model
///                               ├─> Insert to context
///                               └─> Save
/// ```
///
/// ## Example Usage
///
/// ```swift
/// let service = VoiceGenerationService(
///     voiceProvider: elevenlabsProvider
/// )
///
/// // Background generation
/// let request = VoiceGenerationRequest(
///     text: "Hello, world!",
///     voiceId: "voice123",
///     providerId: "elevenlabs",
///     requestorId: "elevenlabs.audio.tts"
/// )
///
/// let result = try await service.generate(request)
///
/// // Main thread storage
/// await MainActor.run {
///     let record = result.toTypedDataStorage()
///     modelContext.insert(record)
///     try? modelContext.save()
/// }
/// ```
public actor VoiceGenerationService {

    // MARK: - Dependencies

    /// Voice provider for generation
    private let voiceProvider: VoiceProvider

    /// Storage area for file-based audio
    private let storageArea: StorageAreaReference?

    // MARK: - State

    /// Active generation tasks
    private var activeTasks: [UUID: Task<VoiceGenerationResult, Error>] = [:]

    // MARK: - Initialization

    /// Creates a voice generation service
    ///
    /// - Parameters:
    ///   - voiceProvider: Provider to use for voice generation
    ///   - storageArea: Storage area for file-based audio (optional)
    public init(
        voiceProvider: VoiceProvider,
        storageArea: StorageAreaReference? = nil
    ) {
        self.voiceProvider = voiceProvider
        self.storageArea = storageArea
    }

    // MARK: - Generation

    /// Generates voice audio from a request.
    ///
    /// **Thread Safety**: This method runs on a background thread.
    /// The returned result is Sendable and can be safely passed to the main thread.
    ///
    /// - Parameter request: Voice generation request
    /// - Returns: Generation result (Sendable)
    /// - Throws: Voice generation errors
    public func generate(_ request: VoiceGenerationRequest) async throws -> VoiceGenerationResult {
        // Validate MIME type
        try MimeTypeHelper.validate(request.mimeType)

        // Create generation task
        let task = Task<VoiceGenerationResult, Error> {
            // Generate audio on background thread
            let voice = Voice(
                id: request.voiceId,
                name: request.voiceName ?? request.voiceId,
                description: nil,
                providerId: request.providerId
            )

            // Call provider (this may take several seconds)
            let audioData = try await voiceProvider.generateAudio(
                text: request.text,
                voiceId: request.voiceId
            )

            // Create file reference if needed
            // NOTE: File storage implementation would go here
            // For now, we keep audio in memory to focus on thread safety
            var fileReference: TypedDataFileReference? = nil
            var storedData: Data? = audioData

            // TODO: Implement file storage when needed
            // if request.useFileStorage, let storage = storageArea {
            //     let fileName = "\(request.id.uuidString).audio"
            //     let fileRef = TypedDataFileReference(...)
            //     // Write to storage area
            //     fileReference = fileRef
            //     storedData = nil
            // }

            // Extract audio metadata (simplified - would use actual audio analysis)
            let durationSeconds = estimateDuration(audioData, mimeType: request.mimeType)
            let sampleRate = extractSampleRate(audioData, mimeType: request.mimeType)

            // Create Sendable result
            return VoiceGenerationResult(
                requestId: request.id,
                audioData: storedData,
                mimeType: request.mimeType,
                durationSeconds: durationSeconds,
                sampleRate: sampleRate,
                bitRate: nil,
                channels: 1,  // Default to mono
                voiceId: request.voiceId,
                voiceName: request.voiceName,
                modelIdentifier: request.modelIdentifier,
                providerId: request.providerId,
                requestorId: request.requestorId,
                originalText: request.text,
                fileReference: fileReference,
                estimatedCost: estimateCost(request.text, provider: request.providerId),
                metadata: request.metadata
            )
        }

        // Track task
        activeTasks[request.id] = task

        defer {
            activeTasks.removeValue(forKey: request.id)
        }

        return try await task.value
    }

    /// Cancels a generation request
    ///
    /// - Parameter requestId: Request ID to cancel
    public func cancel(_ requestId: UUID) {
        activeTasks[requestId]?.cancel()
        activeTasks.removeValue(forKey: requestId)
    }

    /// Cancels all active generation requests
    public func cancelAll() {
        for task in activeTasks.values {
            task.cancel()
        }
        activeTasks.removeAll()
    }

    /// Number of active generation tasks
    public var activeCount: Int {
        activeTasks.count
    }

    // MARK: - Helper Methods

    /// Calculates checksum for data
    private func calculateChecksum(_ data: Data) -> String {
        // Simple hash - in production, use proper checksum algorithm
        return String(data.hashValue)
    }

    /// Estimates audio duration from data
    private func estimateDuration(_ data: Data, mimeType: String) -> Double? {
        // Simplified estimation - would use actual audio parsing
        // MP3: ~1 second per 16KB at 128kbps
        let bytesPerSecond = 16_000.0
        return Double(data.count) / bytesPerSecond
    }

    /// Extracts sample rate from audio data
    private func extractSampleRate(_ data: Data, mimeType: String) -> Int? {
        // Simplified - would parse audio header
        return 44100  // Common default
    }

    /// Estimates cost based on text length and provider
    private func estimateCost(_ text: String, provider: String) -> Double {
        let characterCount = Double(text.count)

        switch provider.lowercased() {
        case "elevenlabs":
            // ElevenLabs pricing: ~$0.30 per 1000 characters
            return (characterCount / 1000.0) * 0.30
        case "openai":
            // OpenAI TTS pricing: ~$0.015 per 1000 characters
            return (characterCount / 1000.0) * 0.015
        default:
            return 0.0
        }
    }
}

// MARK: - Convenience Methods

extension VoiceGenerationService {

    /// Generates voice audio and saves to SwiftData
    ///
    /// This is a convenience method that:
    /// 1. Generates audio on background thread
    /// 2. Converts result to TypedDataStorage on main thread
    /// 3. Saves to provided model context
    ///
    /// - Parameters:
    ///   - request: Voice generation request
    ///   - modelContext: SwiftData model context (must be on main thread)
    /// - Returns: Generated TypedDataStorage record
    /// - Throws: Generation or save errors
    @MainActor
    public func generateAndSave(
        _ request: VoiceGenerationRequest,
        to modelContext: ModelContext
    ) async throws -> TypedDataStorage {
        // Generate on background thread
        let result = try await generate(request)

        // Convert and save on main thread
        let record = result.toTypedDataStorage()
        modelContext.insert(record)
        try modelContext.save()

        return record
    }
}
