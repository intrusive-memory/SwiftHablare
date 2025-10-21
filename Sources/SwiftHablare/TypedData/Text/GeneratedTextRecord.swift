//
//  GeneratedTextRecord.swift
//  SwiftHablare
//
//  Phase 6B: SwiftData model for generated text
//

import Foundation
import SwiftData

/// SwiftData model for storing generated text with file reference support.
///
/// **DEPRECATED**: Use `TypedDataStorage` with `mimeType: "text/plain"` instead.
///
/// This type alias provides backward compatibility. New code should use TypedDataStorage directly:
/// ```swift
/// let record = TypedDataStorage(
///     providerId: "openai",
///     requestorID: "openai.text.gpt4",
///     mimeType: "text/plain",
///     textValue: generatedText,
///     prompt: "Generate text"
/// )
/// ```
@available(macOS 15.0, iOS 17.0, *)
@available(*, deprecated, message: "Use TypedDataStorage with mimeType: 'text/plain' instead")
@Model
public final class GeneratedTextRecord {

    // MARK: - Identity

    /// Unique identifier (matches request ID)
    @Attribute(.unique) public var id: UUID

    /// Provider that generated this text
    public var providerId: String

    /// Specific requestor that generated this text
    public var requestorID: String

    // MARK: - Content

    /// The generated text content (if stored in-memory)
    ///
    /// For small text (<50KB), this contains the actual text.
    /// For large text (>=50KB), this is nil and text is in file.
    public var text: String?

    /// Word count
    public var wordCount: Int

    /// Character count
    public var characterCount: Int

    /// Language code (e.g., "en", "es")
    public var languageCode: String?

    // MARK: - Generation Metadata

    /// Model identifier that generated this text
    public var modelIdentifier: String?

    /// Total token count
    public var tokenCount: Int?

    /// Completion tokens used
    public var completionTokens: Int?

    /// Prompt tokens used
    public var promptTokens: Int?

    /// The prompt used to generate this text
    public var prompt: String

    // MARK: - File Reference

    /// Reference to file if text is stored externally
    ///
    /// When text is large, it's written to a .guion bundle file
    /// and this property stores the reference for retrieval.
    @Attribute(.transformable(by: "TypedDataFileReferenceTransformer"))
    public var fileReference: TypedDataFileReference?

    // MARK: - Timestamps

    /// When this text was generated
    public var generatedAt: Date

    /// When this record was last modified
    public var modifiedAt: Date

    // MARK: - Estimated Cost

    /// Estimated cost in USD (if available)
    public var estimatedCost: Double?

    // MARK: - Initialization

    /// Creates a generated text record
    ///
    /// - Parameters:
    ///   - id: Unique identifier (typically the request ID)
    ///   - providerId: Provider identifier
    ///   - requestorID: Specific requestor identifier
    ///   - text: Generated text (nil if stored in file)
    ///   - wordCount: Number of words
    ///   - characterCount: Number of characters
    ///   - languageCode: Language code (optional)
    ///   - modelIdentifier: Model identifier (optional)
    ///   - tokenCount: Total token count (optional)
    ///   - completionTokens: Completion tokens (optional)
    ///   - promptTokens: Prompt tokens (optional)
    ///   - prompt: The generation prompt
    ///   - fileReference: File reference (optional)
    ///   - estimatedCost: Estimated cost (optional)
    public init(
        id: UUID = UUID(),
        providerId: String,
        requestorID: String,
        text: String?,
        wordCount: Int,
        characterCount: Int,
        languageCode: String? = nil,
        modelIdentifier: String? = nil,
        tokenCount: Int? = nil,
        completionTokens: Int? = nil,
        promptTokens: Int? = nil,
        prompt: String = "",
        fileReference: TypedDataFileReference? = nil,
        estimatedCost: Double? = nil
    ) {
        self.id = id
        self.providerId = providerId
        self.requestorID = requestorID
        self.text = text
        self.wordCount = wordCount
        self.characterCount = characterCount
        self.languageCode = languageCode
        self.modelIdentifier = modelIdentifier
        self.tokenCount = tokenCount
        self.completionTokens = completionTokens
        self.promptTokens = promptTokens
        self.prompt = prompt
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
    ///   - data: Generated text data
    ///   - prompt: The generation prompt
    ///   - fileReference: Optional file reference
    ///   - estimatedCost: Optional cost estimate
    public convenience init(
        id: UUID = UUID(),
        providerId: String,
        requestorID: String,
        data: GeneratedTextData,
        prompt: String,
        fileReference: TypedDataFileReference? = nil,
        estimatedCost: Double? = nil
    ) {
        // If file reference exists, don't store text in-memory
        let text = fileReference == nil ? data.text : nil

        self.init(
            id: id,
            providerId: providerId,
            requestorID: requestorID,
            text: text,
            wordCount: data.wordCount,
            characterCount: data.characterCount,
            languageCode: data.languageCode,
            modelIdentifier: data.model,
            tokenCount: data.tokenCount,
            completionTokens: data.completionTokens,
            promptTokens: data.promptTokens,
            prompt: prompt,
            fileReference: fileReference,
            estimatedCost: estimatedCost
        )
    }

    // MARK: - Helper Methods

    /// Updates the modification timestamp
    public func touch() {
        self.modifiedAt = Date()
    }

    /// Returns the text content, loading from file if necessary
    ///
    /// - Parameter storageArea: Storage area for file loading
    /// - Returns: The text content
    /// - Throws: File errors if text is in file and cannot be loaded
    public func getText(from storageArea: StorageAreaReference? = nil) throws -> String {
        // If text is in memory, return it
        if let text = text {
            return text
        }

        // If we have a file reference, load from file
        guard let fileRef = fileReference else {
            throw TypedDataError.fileOperationFailed(
                operation: "load text",
                reason: "No text content and no file reference"
            )
        }

        // Load from file
        guard let storage = storageArea else {
            throw TypedDataError.fileOperationFailed(
                operation: "load text",
                reason: "File reference exists but no storage area provided"
            )
        }

        let data = try fileRef.readData(from: storage)
        guard let textContent = String(data: data, encoding: .utf8) else {
            throw TypedDataError.typeConversionFailed(
                fromType: "Data",
                toType: "String",
                reason: "Invalid UTF-8 encoding"
            )
        }

        return textContent
    }

    /// Whether this record stores text in a file
    public var isFileStored: Bool {
        fileReference != nil
    }
}

// MARK: - CustomStringConvertible

@available(macOS 15.0, iOS 17.0, *)
extension GeneratedTextRecord: CustomStringConvertible {
    public var description: String {
        let storage = isFileStored ? "file" : "memory"
        return "GeneratedTextRecord(id: \(id), provider: \(providerId), \(wordCount) words, storage: \(storage))"
    }
}
