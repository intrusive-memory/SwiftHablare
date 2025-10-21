import Foundation
import SwiftData

/// Model for AI-generated structured data.
@Model
public final class GeneratedStructuredData {
    @Attribute(.unique) public var id: UUID
    public var providerId: String
    public var prompt: String
    public var generatedAt: Date
    public var modifiedAt: Date

    /// The structured data (JSON, CSV, XML, etc.).
    public var data: Data

    /// Data format (e.g., "json", "csv", "xml").
    public var dataFormat: String

    /// Schema version (if applicable).
    public var schemaVersion: String?

    /// Model identifier.
    public var modelIdentifier: String?

    /// Estimated cost.
    public var estimatedCost: Double?

    public init(
        id: UUID = UUID(),
        providerId: String,
        prompt: String,
        data: Data,
        dataFormat: String,
        schemaVersion: String? = nil
    ) {
        self.id = id
        self.providerId = providerId
        self.prompt = prompt
        self.data = data
        self.dataFormat = dataFormat
        self.schemaVersion = schemaVersion
        self.generatedAt = Date()
        self.modifiedAt = Date()
    }
}
