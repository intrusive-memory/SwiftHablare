//
//  GeneratedEmbeddingRecord.swift
//  SwiftHablare
//
//  Phase 6E: SwiftData persistence model for embeddings
//

import Foundation
import SwiftData

/// SwiftData persistence model for generated embeddings.
///
/// **DEPRECATED**: Use `TypedDataStorage` with custom embedding MIME type instead.
///
/// This type alias provides backward compatibility. New code should use TypedDataStorage directly:
/// ```swift
/// let record = TypedDataStorage(
///     providerId: "openai",
///     requestorID: "openai.embedding.text-embedding-3-small",
///     mimeType: "application/x-embedding-vector",  // Custom type for embeddings
///     binaryValue: embeddingData,
///     prompt: "Embed this text"
/// )
/// ```
///
/// **Note**: Embedding MIME type requires MimeTypeHelper update to support this custom type.
@available(macOS 15.0, iOS 17.0, *)
@available(*, deprecated, message: "Use TypedDataStorage with custom embedding MIME type instead")
@Model
public final class GeneratedEmbeddingRecord {

    // MARK: - Identity

    /// Unique identifier (matches request ID)
    @Attribute(.unique) public var id: UUID

    /// Provider that generated this embedding
    public var providerId: String

    /// Specific requestor that generated this embedding
    public var requestorID: String

    // MARK: - Stored Properties

    /// The embedding vector data (nil if file-stored)
    ///
    /// When nil, the embedding is stored in a file referenced by `fileReference`.
    public var embeddingData: Data?

    /// Number of dimensions in the embedding
    public var dimensions: Int

    /// The input text that was embedded
    ///
    /// Truncated to 1000 characters for storage efficiency.
    public var inputText: String?

    /// Token count of the input
    public var tokenCount: Int?

    /// Model identifier that generated the embedding
    public var modelIdentifier: String?

    /// Index in batch (if part of batch request)
    public var batchIndex: Int?

    /// The prompt used to generate this embedding
    public var prompt: String

    /// File reference for file-stored embeddings
    @Attribute(.transformable(by: "TypedDataFileReferenceTransformer"))
    public var fileReference: TypedDataFileReference?

    /// Estimated cost of generating this embedding (USD)
    public var estimatedCost: Double?

    // MARK: - Timestamps

    /// When this embedding was generated
    public var createdAt: Date

    /// When this record was last modified
    public var modifiedAt: Date

    // MARK: - Computed Properties

    /// Whether the embedding is stored in a file
    public var isFileStored: Bool {
        fileReference != nil
    }

    /// Size of the embedding data in bytes
    public var dataSize: Int {
        if let embeddingData = embeddingData {
            return embeddingData.count
        } else if let fileReference = fileReference {
            return Int(fileReference.fileSize)
        }
        return 0
    }

    // MARK: - Initialization

    /// Initialize with all properties
    ///
    /// - Parameters:
    ///   - id: Unique identifier (typically the request ID)
    ///   - providerId: Provider identifier
    ///   - requestorID: Specific requestor identifier
    ///   - embeddingData: Binary embedding data (nil if stored in file)
    ///   - dimensions: Number of dimensions
    ///   - inputText: The embedded text (optional)
    ///   - tokenCount: Token count (optional)
    ///   - modelIdentifier: Model identifier
    ///   - batchIndex: Index in batch (optional)
    ///   - fileReference: File reference (optional)
    ///   - estimatedCost: Estimated cost (optional)
    ///   - prompt: The generation prompt
    public init(
        id: UUID = UUID(),
        providerId: String,
        requestorID: String,
        embeddingData: Data?,
        dimensions: Int,
        inputText: String?,
        tokenCount: Int?,
        modelIdentifier: String,
        batchIndex: Int? = nil,
        fileReference: TypedDataFileReference? = nil,
        estimatedCost: Double? = nil,
        prompt: String = ""
    ) {
        self.id = id
        self.providerId = providerId
        self.requestorID = requestorID
        self.embeddingData = embeddingData
        self.dimensions = dimensions
        self.inputText = inputText
        self.tokenCount = tokenCount
        self.modelIdentifier = modelIdentifier
        self.batchIndex = batchIndex
        self.fileReference = fileReference
        self.estimatedCost = estimatedCost
        self.prompt = prompt
        self.createdAt = Date()
        self.modifiedAt = Date()
    }

    /// Convenience initializer from GeneratedEmbeddingData
    ///
    /// - Parameters:
    ///   - id: Unique identifier
    ///   - providerId: Provider identifier
    ///   - requestorID: Requestor identifier
    ///   - data: Generated embedding data
    ///   - prompt: The generation prompt
    ///   - fileReference: Optional file reference
    ///   - estimatedCost: Optional cost estimate
    public convenience init(
        id: UUID = UUID(),
        providerId: String,
        requestorID: String,
        data: GeneratedEmbeddingData,
        prompt: String,
        fileReference: TypedDataFileReference? = nil,
        estimatedCost: Double? = nil
    ) {
        // If file reference exists, don't store embedding data in-memory
        let embeddingData: Data?
        if fileReference == nil, let embedding = data.embedding {
            // Store embedding as binary data
            embeddingData = embedding.withUnsafeBufferPointer { buffer in
                Data(buffer: buffer)
            }
        } else {
            embeddingData = nil
        }

        self.init(
            id: id,
            providerId: providerId,
            requestorID: requestorID,
            embeddingData: embeddingData,
            dimensions: data.dimensions,
            inputText: data.inputText,
            tokenCount: data.tokenCount,
            modelIdentifier: data.model,
            batchIndex: data.index,
            fileReference: fileReference,
            estimatedCost: estimatedCost,
            prompt: prompt
        )
    }

    // MARK: - Data Retrieval

    /// Get the embedding vector
    ///
    /// Loads from file if file-stored, otherwise returns in-memory data.
    ///
    /// - Parameter storageArea: Storage area for file loading (required if file-stored)
    /// - Returns: The embedding vector
    /// - Throws: TypedDataError if embedding cannot be retrieved
    public func getEmbedding(from storageArea: StorageAreaReference? = nil) throws -> [Float] {
        // If embedding is in memory, return it
        if let embeddingData = embeddingData {
            return embeddingData.withUnsafeBytes { buffer in
                Array(buffer.bindMemory(to: Float.self))
            }
        }

        // If we have a file reference, load from file
        guard let fileRef = fileReference else {
            throw TypedDataError.fileOperationFailed(
                operation: "get embedding",
                reason: "No embedding data or file reference available"
            )
        }

        // Load from file
        guard let storage = storageArea else {
            throw TypedDataError.fileOperationFailed(
                operation: "get embedding",
                reason: "File reference exists but no storage area provided"
            )
        }

        let data = try fileRef.readData(from: storage)
        return data.withUnsafeBytes { buffer in
            Array(buffer.bindMemory(to: Float.self))
        }
    }

    /// Update the modified timestamp
    public func touch() {
        self.modifiedAt = Date()
    }

    // MARK: - Description

    public var customDescription: String {
        var desc = "GeneratedEmbeddingRecord(id: \(id), provider: \(providerId), "
        desc += "dimensions: \(dimensions), "

        if let inputText = inputText {
            let preview = inputText.count > 50 ? String(inputText.prefix(50)) + "..." : inputText
            desc += "input: \"\(preview)\", "
        }

        if isFileStored {
            desc += "storage: file[\(ByteCountFormatter.string(fromByteCount: Int64(dataSize), countStyle: .file))]"
        } else {
            desc += "storage: memory[\(ByteCountFormatter.string(fromByteCount: Int64(dataSize), countStyle: .file))]"
        }

        desc += ")"
        return desc
    }
}
