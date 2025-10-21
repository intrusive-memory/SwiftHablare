//
//  VoiceGenerationResult.swift
//  SwiftHablare
//
//  Sendable result for thread-safe voice generation
//

import Foundation

/// Thread-safe result from voice generation.
///
/// This struct is Sendable, allowing it to be safely passed from background
/// threads to the main thread for SwiftData storage.
///
/// ## Thread Safety
/// - Sendable: Can be passed across actor boundaries
/// - Immutable: All properties are let constants
/// - Value type: No shared mutable state
///
/// ## Example
/// ```swift
/// // Background thread generates audio
/// let result = try await generateAudio(request)
///
/// // Main thread saves to SwiftData
/// await MainActor.run {
///     let record = result.toTypedDataStorage()
///     modelContext.insert(record)
///     try? modelContext.save()
/// }
/// ```
public struct VoiceGenerationResult: Sendable {

    // MARK: - Identity

    /// Request ID this result corresponds to
    public let requestId: UUID

    // MARK: - Generated Content

    /// Generated audio data (nil if stored in file)
    public let audioData: Data?

    /// MIME type of generated audio
    public let mimeType: String

    // MARK: - Audio Metadata

    /// Duration in seconds
    public let durationSeconds: Double?

    /// Sample rate in Hz
    public let sampleRate: Int?

    /// Bit rate in bps
    public let bitRate: Int?

    /// Number of channels (1 = mono, 2 = stereo)
    public let channels: Int?

    // MARK: - Generation Metadata

    /// Voice ID used
    public let voiceId: String

    /// Voice name (human-readable)
    public let voiceName: String?

    /// Model identifier used
    public let modelIdentifier: String?

    /// Provider identifier
    public let providerId: String

    /// Requestor identifier
    public let requestorId: String

    /// Original text that was spoken
    public let originalText: String

    /// Character count of original text
    public let characterCount: Int

    // MARK: - File Reference

    /// File reference if audio is stored externally
    public let fileReference: TypedDataFileReference?

    // MARK: - Cost & Metadata

    /// Estimated cost in USD
    public let estimatedCost: Double?

    /// Additional metadata
    public let metadata: [String: String]

    // MARK: - Initialization

    /// Creates a voice generation result
    ///
    /// - Parameters:
    ///   - requestId: Request ID this result corresponds to
    ///   - audioData: Generated audio data (nil if in file)
    ///   - mimeType: MIME type of audio
    ///   - durationSeconds: Duration in seconds
    ///   - sampleRate: Sample rate in Hz
    ///   - bitRate: Bit rate in bps
    ///   - channels: Number of channels
    ///   - voiceId: Voice ID used
    ///   - voiceName: Voice name
    ///   - modelIdentifier: Model identifier
    ///   - providerId: Provider identifier
    ///   - requestorId: Requestor identifier
    ///   - originalText: Original text
    ///   - fileReference: File reference (optional)
    ///   - estimatedCost: Estimated cost (optional)
    ///   - metadata: Additional metadata
    public init(
        requestId: UUID,
        audioData: Data?,
        mimeType: String,
        durationSeconds: Double? = nil,
        sampleRate: Int? = nil,
        bitRate: Int? = nil,
        channels: Int? = nil,
        voiceId: String,
        voiceName: String? = nil,
        modelIdentifier: String? = nil,
        providerId: String,
        requestorId: String,
        originalText: String,
        fileReference: TypedDataFileReference? = nil,
        estimatedCost: Double? = nil,
        metadata: [String: String] = [:]
    ) {
        self.requestId = requestId
        self.audioData = audioData
        self.mimeType = mimeType
        self.durationSeconds = durationSeconds
        self.sampleRate = sampleRate
        self.bitRate = bitRate
        self.channels = channels
        self.voiceId = voiceId
        self.voiceName = voiceName
        self.modelIdentifier = modelIdentifier
        self.providerId = providerId
        self.requestorId = requestorId
        self.originalText = originalText
        self.characterCount = originalText.count
        self.fileReference = fileReference
        self.estimatedCost = estimatedCost
        self.metadata = metadata
    }

    // MARK: - Conversion to TypedDataStorage

    /// Converts this result to a TypedDataStorage record
    ///
    /// **Must be called on @MainActor** for SwiftData insertion.
    ///
    /// - Returns: TypedDataStorage record ready for insertion
    @MainActor
    public func toTypedDataStorage() -> TypedDataStorage {
        // Encode audio metadata as JSON
        var metadataDict: [String: Any] = [
            "voiceId": voiceId,
            "characterCount": characterCount
        ]

        if let voiceName = voiceName {
            metadataDict["voiceName"] = voiceName
        }
        if let durationSeconds = durationSeconds {
            metadataDict["durationSeconds"] = durationSeconds
        }
        if let sampleRate = sampleRate {
            metadataDict["sampleRate"] = sampleRate
        }
        if let bitRate = bitRate {
            metadataDict["bitRate"] = bitRate
        }
        if let channels = channels {
            metadataDict["channels"] = channels
        }

        // Add custom metadata
        for (key, value) in metadata {
            metadataDict[key] = value
        }

        let metadataJSON = try? JSONSerialization.data(withJSONObject: metadataDict)

        return TypedDataStorage(
            id: requestId,
            providerId: providerId,
            requestorID: requestorId,
            mimeType: mimeType,
            textValue: nil,  // Audio is binary
            binaryValue: audioData,
            fileReference: fileReference,
            prompt: originalText,
            modelIdentifier: modelIdentifier,
            metadata: metadataJSON,
            estimatedCost: estimatedCost
        )
    }
}

// MARK: - CustomStringConvertible

extension VoiceGenerationResult: CustomStringConvertible {
    public var description: String {
        let storage = fileReference != nil ? "file" : "memory"
        let duration = durationSeconds.map { String(format: "%.1fs", $0) } ?? "unknown"
        return "VoiceGenerationResult(id: \(requestId), duration: \(duration), storage: \(storage))"
    }
}
