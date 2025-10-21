import Foundation
import SwiftData

/// Model for AI-generated text content.
@Model
public final class GeneratedText {
    @Attribute(.unique) public var id: UUID
    public var providerId: String
    public var prompt: String
    public var generatedAt: Date
    public var modifiedAt: Date

    /// The generated text content.
    public var content: String

    /// Character count.
    public var characterCount: Int

    /// Word count (approximate).
    public var wordCount: Int

    /// Language code (e.g., "en", "es").
    public var languageCode: String?

    /// Model identifier.
    public var modelIdentifier: String?

    /// Token count.
    public var tokenCount: Int?

    /// Estimated cost.
    public var estimatedCost: Double?

    public init(
        id: UUID = UUID(),
        providerId: String,
        prompt: String,
        content: String,
        languageCode: String? = nil,
        modelIdentifier: String? = nil
    ) {
        self.id = id
        self.providerId = providerId
        self.prompt = prompt
        self.content = content
        self.generatedAt = Date()
        self.modifiedAt = Date()
        self.languageCode = languageCode
        self.modelIdentifier = modelIdentifier

        // Calculate counts
        self.characterCount = content.count
        self.wordCount = content.split(separator: " ").count
    }
}
