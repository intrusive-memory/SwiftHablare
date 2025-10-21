import Foundation
import SwiftData

/// Base model for AI-generated content with common metadata fields.
///
/// This model stores metadata about AI generation operations that is common
/// across all types of generated content (text, audio, images, etc.).
///
/// Specific content types should extend this base or create their own models
/// that include similar metadata fields.
///
/// ## Example
/// ```swift
/// @Model
/// final class GeneratedArticle: AIGeneratedContent {
///     var title: String = ""
///     var content: String = ""
///     var wordCount: Int = 0
///
///     init(title: String, content: String, providerId: String, prompt: String) {
///         self.title = title
///         self.content = content
///         self.wordCount = content.split(separator: " ").count
///         super.init(providerId: providerId, prompt: prompt)
///     }
/// }
/// ```

@Model
public class AIGeneratedContent {
    /// Unique identifier for this content.
    @Attribute(.unique) public var id: UUID

    /// ID of the provider that generated this content.
    public var providerId: String

    /// The prompt used to generate this content.
    public var prompt: String

    /// When this content was generated.
    public var generatedAt: Date

    /// When this record was last modified.
    public var modifiedAt: Date

    /// Model identifier used by the provider (e.g., "gpt-4", "claude-3-sonnet").
    public var modelIdentifier: String?

    /// Token count (if applicable and provided by the provider).
    public var tokenCount: Int?

    /// Estimated cost in USD (if available).
    public var estimatedCost: Double?

    /// Request parameters used for generation.
    public var requestParameters: Data?

    /// Additional metadata as JSON.
    public var metadata: Data?

    public init(
        id: UUID = UUID(),
        providerId: String,
        prompt: String,
        generatedAt: Date = Date(),
        modelIdentifier: String? = nil,
        tokenCount: Int? = nil,
        estimatedCost: Double? = nil,
        requestParameters: Data? = nil,
        metadata: Data? = nil
    ) {
        self.id = id
        self.providerId = providerId
        self.prompt = prompt
        self.generatedAt = generatedAt
        self.modifiedAt = generatedAt
        self.modelIdentifier = modelIdentifier
        self.tokenCount = tokenCount
        self.estimatedCost = estimatedCost
        self.requestParameters = requestParameters
        self.metadata = metadata
    }

    /// Updates the modification timestamp.
    public func touch() {
        self.modifiedAt = Date()
    }
}
