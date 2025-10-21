import Foundation
import SwiftData

/// Model for AI-generated image content.
@Model
public final class GeneratedImage {
    @Attribute(.unique) public var id: UUID
    public var providerId: String
    public var prompt: String
    public var generatedAt: Date
    public var modifiedAt: Date

    /// The image data.
    public var imageData: Data

    /// Image format (e.g., "png", "jpg", "webp").
    public var imageFormat: String

    /// Width in pixels.
    public var width: Int?

    /// Height in pixels.
    public var height: Int?

    /// File size in bytes.
    public var fileSize: Int

    /// Model identifier.
    public var modelIdentifier: String?

    /// Estimated cost.
    public var estimatedCost: Double?

    public init(
        id: UUID = UUID(),
        providerId: String,
        prompt: String,
        imageData: Data,
        imageFormat: String,
        width: Int? = nil,
        height: Int? = nil
    ) {
        self.id = id
        self.providerId = providerId
        self.prompt = prompt
        self.imageData = imageData
        self.imageFormat = imageFormat
        self.width = width
        self.height = height
        self.fileSize = imageData.count
        self.generatedAt = Date()
        self.modifiedAt = Date()
    }
}
