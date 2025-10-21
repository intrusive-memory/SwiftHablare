//
//  GeneratedImageRecord.swift
//  SwiftHablare
//
//  Phase 6D: SwiftData model for generated images
//

import Foundation
import SwiftData

/// SwiftData model for storing generated images with file reference support.
///
/// **DEPRECATED**: Use `TypedDataStorage` with `mimeType: "image/*"` instead.
///
/// This type alias provides backward compatibility. New code should use TypedDataStorage directly:
/// ```swift
/// let record = TypedDataStorage(
///     providerId: "openai",
///     requestorID: "openai.image.dalle3",
///     mimeType: "image/png",
///     binaryValue: imageData,
///     prompt: "Generate image"
/// )
/// ```
@available(macOS 15.0, iOS 17.0, *)
@available(*, deprecated, message: "Use TypedDataStorage with mimeType: 'image/*' instead")
@Model
public final class GeneratedImageRecord {

    // MARK: - Identity

    /// Unique identifier (matches request ID)
    @Attribute(.unique) public var id: UUID

    /// Provider that generated this image
    public var providerId: String

    /// Specific requestor that generated this image
    public var requestorID: String

    // MARK: - Content

    /// The image data (if stored in-memory, typically nil)
    ///
    /// For small images (<100KB), this may contain the actual data.
    /// For typical images (>=100KB), this is nil and image is in file.
    public var imageData: Data?

    /// Image format (e.g., "png", "jpeg", "webp")
    public var format: String

    /// Image width in pixels
    public var width: Int

    /// Image height in pixels
    public var height: Int

    /// The prompt used to generate this image
    public var prompt: String

    /// Revised prompt (if the model modified the original)
    ///
    /// Some models like DALL-E 3 may revise prompts for safety or quality.
    public var revisedPrompt: String?

    // MARK: - Generation Metadata

    /// Model identifier that generated this image
    public var modelIdentifier: String?

    // MARK: - File Reference

    /// Reference to file if image is stored externally
    ///
    /// When image is stored in a file, this property stores the reference.
    @Attribute(.transformable(by: "TypedDataFileReferenceTransformer"))
    public var fileReference: TypedDataFileReference?

    // MARK: - Timestamps

    /// When this image was generated
    public var generatedAt: Date

    /// When this record was last modified
    public var modifiedAt: Date

    // MARK: - Estimated Cost

    /// Estimated cost in USD (if available)
    public var estimatedCost: Double?

    // MARK: - Initialization

    /// Creates a generated image record
    ///
    /// - Parameters:
    ///   - id: Unique identifier (typically the request ID)
    ///   - providerId: Provider identifier
    ///   - requestorID: Specific requestor identifier
    ///   - imageData: Image data (nil if stored in file)
    ///   - format: Image format
    ///   - width: Image width in pixels
    ///   - height: Image height in pixels
    ///   - prompt: The generation prompt
    ///   - revisedPrompt: Revised prompt (optional)
    ///   - modelIdentifier: Model identifier (optional)
    ///   - fileReference: File reference (optional)
    ///   - estimatedCost: Estimated cost (optional)
    public init(
        id: UUID = UUID(),
        providerId: String,
        requestorID: String,
        imageData: Data?,
        format: String,
        width: Int,
        height: Int,
        prompt: String = "",
        revisedPrompt: String? = nil,
        modelIdentifier: String? = nil,
        fileReference: TypedDataFileReference? = nil,
        estimatedCost: Double? = nil
    ) {
        self.id = id
        self.providerId = providerId
        self.requestorID = requestorID
        self.imageData = imageData
        self.format = format
        self.width = width
        self.height = height
        self.prompt = prompt
        self.revisedPrompt = revisedPrompt
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
    ///   - data: Generated image data
    ///   - prompt: The generation prompt
    ///   - fileReference: Optional file reference
    ///   - estimatedCost: Optional cost estimate
    public convenience init(
        id: UUID = UUID(),
        providerId: String,
        requestorID: String,
        data: GeneratedImageData,
        prompt: String,
        fileReference: TypedDataFileReference? = nil,
        estimatedCost: Double? = nil
    ) {
        // If file reference exists, don't store image data in-memory
        let imageData = fileReference == nil ? data.imageData : nil

        self.init(
            id: id,
            providerId: providerId,
            requestorID: requestorID,
            imageData: imageData,
            format: data.format.rawValue,
            width: data.width,
            height: data.height,
            prompt: prompt,
            revisedPrompt: data.revisedPrompt,
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

    /// Returns the image data, loading from file if necessary
    ///
    /// - Parameter storageArea: Storage area for file loading
    /// - Returns: The image data
    /// - Throws: File errors if image is in file and cannot be loaded
    public func getImageData(from storageArea: StorageAreaReference? = nil) throws -> Data {
        // If image is in memory, return it
        if let imageData = imageData {
            return imageData
        }

        // If we have a file reference, load from file
        guard let fileRef = fileReference else {
            throw TypedDataError.fileOperationFailed(
                operation: "load image",
                reason: "No image data and no file reference"
            )
        }

        // Load from file
        guard let storage = storageArea else {
            throw TypedDataError.fileOperationFailed(
                operation: "load image",
                reason: "File reference exists but no storage area provided"
            )
        }

        return try fileRef.readData(from: storage)
    }

    /// Whether this record stores image in a file
    public var isFileStored: Bool {
        fileReference != nil
    }

    /// File size in bytes (if image data present)
    public var fileSize: Int {
        imageData?.count ?? 0
    }
}

// MARK: - CustomStringConvertible

@available(macOS 15.0, iOS 17.0, *)
extension GeneratedImageRecord: CustomStringConvertible {
    public var description: String {
        let storage = isFileStored ? "file" : "memory"
        return "GeneratedImageRecord(id: \(id), size: \(width)x\(height), storage: \(storage))"
    }
}
