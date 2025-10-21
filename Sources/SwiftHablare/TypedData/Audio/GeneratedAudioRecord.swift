//
//  GeneratedAudioRecord.swift
//  SwiftHablare
//
//  Phase 6C: SwiftData model for generated audio
//

import Foundation
import SwiftData

/// SwiftData model for storing generated audio with file reference support.
///
/// **DEPRECATED**: Use `TypedDataStorage` with `mimeType: "audio/*"` instead.
///
/// This type alias provides backward compatibility. New code should use TypedDataStorage directly:
/// ```swift
/// let record = TypedDataStorage(
///     providerId: "elevenlabs",
///     requestorID: "elevenlabs.audio.tts",
///     mimeType: "audio/mpeg",
///     binaryValue: audioData,
///     prompt: "Speak this"
/// )
/// ```
@available(macOS 15.0, iOS 17.0, *)
@available(*, deprecated, message: "Use TypedDataStorage with mimeType: 'audio/*' instead")
@Model
public final class GeneratedAudioRecord {

    // MARK: - Identity

    /// Unique identifier (matches request ID)
    @Attribute(.unique) public var id: UUID

    /// Provider that generated this audio
    public var providerId: String

    /// Specific requestor that generated this audio
    public var requestorID: String

    // MARK: - Content

    /// The audio data (if stored in-memory, typically nil)
    ///
    /// For small audio (<1MB), this may contain the actual data.
    /// For typical audio (>=1MB), this is nil and audio is in file.
    public var audioData: Data?

    /// Audio format (e.g., "mp3", "wav", "m4a")
    public var format: String

    /// Duration in seconds
    public var durationSeconds: Double?

    /// Sample rate in Hz
    public var sampleRate: Int?

    /// Bit rate in bps
    public var bitRate: Int?

    /// Number of channels (1 = mono, 2 = stereo)
    public var channels: Int?

    // MARK: - Voice Information

    /// Voice ID used for generation
    public var voiceID: String

    /// Voice name (human-readable)
    public var voiceName: String

    /// The prompt/text used to generate this audio
    public var prompt: String

    // MARK: - Generation Metadata

    /// Model identifier that generated this audio
    public var modelIdentifier: String?

    // MARK: - File Reference

    /// Reference to file if audio is stored externally
    ///
    /// When audio is stored in a file, this property stores the reference.
    @Attribute(.transformable(by: "TypedDataFileReferenceTransformer"))
    public var fileReference: TypedDataFileReference?

    // MARK: - Timestamps

    /// When this audio was generated
    public var generatedAt: Date

    /// When this record was last modified
    public var modifiedAt: Date

    // MARK: - Estimated Cost

    /// Estimated cost in USD (if available)
    public var estimatedCost: Double?

    // MARK: - Initialization

    /// Creates a generated audio record
    ///
    /// - Parameters:
    ///   - id: Unique identifier (typically the request ID)
    ///   - providerId: Provider identifier
    ///   - requestorID: Specific requestor identifier
    ///   - audioData: Audio data (nil if stored in file)
    ///   - format: Audio format
    ///   - durationSeconds: Duration in seconds (optional)
    ///   - sampleRate: Sample rate (optional)
    ///   - bitRate: Bit rate (optional)
    ///   - channels: Number of channels (optional)
    ///   - voiceID: Voice ID used
    ///   - voiceName: Voice name
    ///   - prompt: The generation prompt
    ///   - modelIdentifier: Model identifier (optional)
    ///   - fileReference: File reference (optional)
    ///   - estimatedCost: Estimated cost (optional)
    public init(
        id: UUID = UUID(),
        providerId: String,
        requestorID: String,
        audioData: Data?,
        format: String,
        durationSeconds: Double? = nil,
        sampleRate: Int? = nil,
        bitRate: Int? = nil,
        channels: Int? = nil,
        voiceID: String,
        voiceName: String,
        prompt: String = "",
        modelIdentifier: String? = nil,
        fileReference: TypedDataFileReference? = nil,
        estimatedCost: Double? = nil
    ) {
        self.id = id
        self.providerId = providerId
        self.requestorID = requestorID
        self.audioData = audioData
        self.format = format
        self.durationSeconds = durationSeconds
        self.sampleRate = sampleRate
        self.bitRate = bitRate
        self.channels = channels
        self.voiceID = voiceID
        self.voiceName = voiceName
        self.prompt = prompt
        self.modelIdentifier = modelIdentifier
        self.fileReference = fileReference
        self.estimatedCost = estimatedCost
        self.generatedAt = Date()
        self.modifiedAt = Date()
    }

    // MARK: - Convenience Initializer from TypedData

    /// Creates a record from typed data
    ///
    /// - Parameters:
    ///   - id: Unique identifier
    ///   - providerId: Provider identifier
    ///   - requestorID: Requestor identifier
    ///   - data: Generated audio data
    ///   - prompt: The generation prompt
    ///   - fileReference: Optional file reference
    ///   - estimatedCost: Optional cost estimate
    public convenience init(
        id: UUID = UUID(),
        providerId: String,
        requestorID: String,
        data: GeneratedAudioData,
        prompt: String,
        fileReference: TypedDataFileReference? = nil,
        estimatedCost: Double? = nil
    ) {
        // If file reference exists, don't store audio data in-memory
        let audioData = fileReference == nil ? data.audioData : nil

        self.init(
            id: id,
            providerId: providerId,
            requestorID: requestorID,
            audioData: audioData,
            format: data.format.rawValue,
            durationSeconds: data.durationSeconds,
            sampleRate: data.sampleRate,
            bitRate: data.bitRate,
            channels: data.channels,
            voiceID: data.voiceID,
            voiceName: data.voiceName,
            prompt: prompt,
            modelIdentifier: data.model,
            fileReference: fileReference,
            estimatedCost: estimatedCost
        )
    }

    // MARK: - Helper Methods

    /// Updates the modification timestamp
    public func touch() {
        self.modifiedAt = Date()
    }

    /// Returns the audio data, loading from file if necessary
    ///
    /// - Parameter storageArea: Storage area for file loading
    /// - Returns: The audio data
    /// - Throws: File errors if audio is in file and cannot be loaded
    public func getAudioData(from storageArea: StorageAreaReference? = nil) throws -> Data {
        // If audio is in memory, return it
        if let audioData = audioData {
            return audioData
        }

        // If we have a file reference, load from file
        guard let fileRef = fileReference else {
            throw TypedDataError.fileOperationFailed(
                operation: "load audio",
                reason: "No audio data and no file reference"
            )
        }

        // Load from file
        guard let storage = storageArea else {
            throw TypedDataError.fileOperationFailed(
                operation: "load audio",
                reason: "File reference exists but no storage area provided"
            )
        }

        return try fileRef.readData(from: storage)
    }

    /// Whether this record stores audio in a file
    public var isFileStored: Bool {
        fileReference != nil
    }

    /// File size in bytes (if audio data present)
    public var fileSize: Int {
        audioData?.count ?? 0
    }
}

// MARK: - CustomStringConvertible

@available(macOS 15.0, iOS 17.0, *)
extension GeneratedAudioRecord: CustomStringConvertible {
    public var description: String {
        let storage = isFileStored ? "file" : "memory"
        let duration = durationSeconds.map { String(format: "%.1fs", $0) } ?? "unknown"
        return "GeneratedAudioRecord(id: \(id), voice: \(voiceName), duration: \(duration), storage: \(storage))"
    }
}
