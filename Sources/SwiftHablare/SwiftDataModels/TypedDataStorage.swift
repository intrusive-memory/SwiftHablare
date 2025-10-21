//
//  TypedDataStorage.swift
//  SwiftHablare
//
//  Unified SwiftData model for storing typed AI-generated content
//

import Foundation
import SwiftData

/// Unified SwiftData model for storing AI-generated content of any type.
///
/// This model consolidates text, audio, image, video, and embedding storage
/// into a single model that uses MIME types to determine storage strategy.
///
/// ## Storage Strategy
///
/// Content is stored based on MIME type:
/// - **Text MIME types** (`text/*`, `application/json`, etc.) → `textValue`
/// - **Binary MIME types** (`audio/*`, `video/*`, `image/*`, etc.) → `binaryValue`
///
/// Large content can be stored in external files referenced by `fileReference`.
///
/// ## Metadata Storage
///
/// Type-specific metadata is stored as JSON in the `metadata` field:
/// - **Text**: wordCount, characterCount, languageCode, tokenCount
/// - **Audio**: durationSeconds, sampleRate, bitRate, channels, voiceID
/// - **Image**: width, height, format
/// - **Embedding**: dimensions, inputText
///
/// ## Example Usage
///
/// ```swift
/// // Store text content
/// let textRecord = TypedDataStorage(
///     providerId: "openai",
///     requestorID: "openai.text.gpt4",
///     mimeType: "text/plain",
///     textValue: "Generated text content",
///     prompt: "Write a story"
/// )
///
/// // Store audio content
/// let audioRecord = TypedDataStorage(
///     providerId: "elevenlabs",
///     requestorID: "elevenlabs.audio.tts",
///     mimeType: "audio/mpeg",
///     binaryValue: audioData,
///     prompt: "Speak this text"
/// )
/// ```
@available(macOS 15.0, iOS 17.0, *)
@Model
public final class TypedDataStorage {

    // MARK: - Identity

    /// Unique identifier (matches request ID)
    @Attribute(.unique) public var id: UUID

    /// Provider that generated this content
    public var providerId: String

    /// Specific requestor that generated this content
    public var requestorID: String

    // MARK: - MIME Type

    /// MIME type of the stored content
    ///
    /// Determines which storage field contains the actual content:
    /// - Text MIME types (text/*, application/json, etc.) use `textValue`
    /// - Binary MIME types (audio/*, video/*, image/*, etc.) use `binaryValue`
    public var mimeType: String

    // MARK: - Content Storage

    /// Text content (for text MIME types)
    ///
    /// Used for:
    /// - text/* types (plain, html, css, etc.)
    /// - application/json, application/xml, etc.
    ///
    /// Set to nil if content is stored in `fileReference`.
    public var textValue: String?

    /// Binary content (for binary MIME types)
    ///
    /// Used for:
    /// - audio/* types (mpeg, wav, etc.)
    /// - video/* types (mp4, webm, etc.)
    /// - image/* types (png, jpeg, etc.)
    /// - Embedding vectors
    ///
    /// Set to nil if content is stored in `fileReference`.
    public var binaryValue: Data?

    // MARK: - File Reference

    /// Reference to file if content is stored externally
    ///
    /// For large content, data is written to an external file
    /// and this property stores the reference for retrieval.
    @Attribute(.transformable(by: "TypedDataFileReferenceTransformer"))
    public var fileReference: TypedDataFileReference?

    // MARK: - Generation Metadata

    /// The prompt used to generate this content
    public var prompt: String

    /// Model identifier that generated this content
    public var modelIdentifier: String?

    /// Type-specific metadata as JSON
    ///
    /// Store metadata specific to the content type:
    /// - **Text**: `{"wordCount": 150, "characterCount": 750, "languageCode": "en"}`
    /// - **Audio**: `{"duration": 10.5, "sampleRate": 44100, "voiceID": "voice123"}`
    /// - **Image**: `{"width": 1024, "height": 1024, "format": "png"}`
    /// - **Embedding**: `{"dimensions": 1536, "inputText": "sample text"}`
    public var metadata: Data?

    // MARK: - Timestamps

    /// When this content was generated
    public var generatedAt: Date

    /// When this record was last modified
    public var modifiedAt: Date

    // MARK: - Estimated Cost

    /// Estimated cost in USD (if available)
    public var estimatedCost: Double?

    // MARK: - Initialization

    /// Creates a typed data storage record
    ///
    /// - Parameters:
    ///   - id: Unique identifier (typically the request ID)
    ///   - providerId: Provider identifier
    ///   - requestorID: Requestor identifier
    ///   - mimeType: MIME type of the content
    ///   - textValue: Text content (for text MIME types)
    ///   - binaryValue: Binary content (for binary MIME types)
    ///   - fileReference: File reference (optional)
    ///   - prompt: The generation prompt
    ///   - modelIdentifier: Model identifier (optional)
    ///   - metadata: Type-specific metadata as JSON (optional)
    ///   - estimatedCost: Estimated cost (optional)
    public init(
        id: UUID = UUID(),
        providerId: String,
        requestorID: String,
        mimeType: String,
        textValue: String? = nil,
        binaryValue: Data? = nil,
        fileReference: TypedDataFileReference? = nil,
        prompt: String = "",
        modelIdentifier: String? = nil,
        metadata: Data? = nil,
        estimatedCost: Double? = nil
    ) {
        self.id = id
        self.providerId = providerId
        self.requestorID = requestorID
        self.mimeType = mimeType
        self.textValue = textValue
        self.binaryValue = binaryValue
        self.fileReference = fileReference
        self.prompt = prompt
        self.modelIdentifier = modelIdentifier
        self.metadata = metadata
        self.estimatedCost = estimatedCost
        self.generatedAt = Date()
        self.modifiedAt = Date()
    }

    // MARK: - Helper Methods

    /// Updates the modification timestamp
    public func touch() {
        self.modifiedAt = Date()
    }

    /// Returns the content, loading from file if necessary
    ///
    /// - Parameter storageArea: Storage area for file loading
    /// - Returns: The content as Data
    /// - Throws: File errors if content is in file and cannot be loaded
    public func getContent(from storageArea: StorageAreaReference? = nil) throws -> Data {
        // Check if we have content in memory
        if let textValue = textValue {
            guard let data = textValue.data(using: .utf8) else {
                throw TypedDataError.typeConversionFailed(
                    fromType: "String",
                    toType: "Data",
                    reason: "Failed to encode text as UTF-8"
                )
            }
            return data
        }

        if let binaryValue = binaryValue {
            return binaryValue
        }

        // If we have a file reference, load from file
        guard let fileRef = fileReference else {
            throw TypedDataError.fileOperationFailed(
                operation: "load content",
                reason: "No content in memory and no file reference"
            )
        }

        guard let storage = storageArea else {
            throw TypedDataError.fileOperationFailed(
                operation: "load content",
                reason: "File reference exists but no storage area provided"
            )
        }

        return try fileRef.readData(from: storage)
    }

    /// Returns text content (for text MIME types)
    ///
    /// - Parameter storageArea: Storage area for file loading
    /// - Returns: The text content
    /// - Throws: Errors if not a text MIME type or content cannot be loaded
    public func getText(from storageArea: StorageAreaReference? = nil) throws -> String {
        guard MimeTypeHelper.isTextMimeType(mimeType) else {
            throw TypedDataError.typeConversionFailed(
                fromType: mimeType,
                toType: "text",
                reason: "MIME type \(mimeType) is not a text type"
            )
        }

        if let textValue = textValue {
            return textValue
        }

        // Load from file and decode
        let data = try getContent(from: storageArea)
        guard let text = String(data: data, encoding: .utf8) else {
            throw TypedDataError.typeConversionFailed(
                fromType: "Data",
                toType: "String",
                reason: "Invalid UTF-8 encoding"
            )
        }

        return text
    }

    /// Returns binary content (for binary MIME types)
    ///
    /// - Parameter storageArea: Storage area for file loading
    /// - Returns: The binary content
    /// - Throws: Errors if content cannot be loaded
    public func getBinary(from storageArea: StorageAreaReference? = nil) throws -> Data {
        if let binaryValue = binaryValue {
            return binaryValue
        }

        return try getContent(from: storageArea)
    }

    /// Decode type-specific metadata
    ///
    /// - Returns: Decoded metadata dictionary
    /// - Throws: Decoding errors
    public func decodeMetadata() throws -> [String: Any]? {
        guard let metadata = metadata else { return nil }

        let object = try JSONSerialization.jsonObject(with: metadata)
        return object as? [String: Any]
    }

    /// Encode and store type-specific metadata
    ///
    /// - Parameter dictionary: Metadata dictionary
    /// - Throws: Encoding errors
    public func encodeMetadata(_ dictionary: [String: Any]) throws {
        self.metadata = try JSONSerialization.data(withJSONObject: dictionary)
        touch()
    }

    /// Whether this record stores content in a file
    public var isFileStored: Bool {
        fileReference != nil
    }

    /// Whether this record contains text content
    public var isTextContent: Bool {
        MimeTypeHelper.isTextMimeType(mimeType)
    }

    /// Whether this record contains binary content
    public var isBinaryContent: Bool {
        MimeTypeHelper.isBinaryMimeType(mimeType)
    }

    /// Size of stored content in bytes
    public var contentSize: Int {
        if let textValue = textValue {
            return textValue.utf8.count
        }
        if let binaryValue = binaryValue {
            return binaryValue.count
        }
        if let fileRef = fileReference {
            return Int(fileRef.fileSize)
        }
        return 0
    }
}

// MARK: - CustomStringConvertible

@available(macOS 15.0, iOS 17.0, *)
extension TypedDataStorage: CustomStringConvertible {
    public var description: String {
        let storage = isFileStored ? "file" : "memory"
        let contentType = isTextContent ? "text" : "binary"
        let size = contentSize
        return "TypedDataStorage(id: \(id), type: \(mimeType), \(contentType), \(size) bytes, storage: \(storage))"
    }
}
