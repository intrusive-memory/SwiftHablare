import Foundation
import SwiftData

/// Model for AI-generated video content.
@Model
public final class GeneratedVideo {
    @Attribute(.unique) public var id: UUID
    public var providerId: String
    public var prompt: String
    public var generatedAt: Date
    public var modifiedAt: Date

    /// URL or path to the video file (videos typically too large for Data).
    public var videoURL: URL

    /// Video format (e.g., "mp4", "mov", "webm").
    public var videoFormat: String

    /// Duration in seconds.
    public var duration: TimeInterval?

    /// Width in pixels.
    public var width: Int?

    /// Height in pixels.
    public var height: Int?

    /// Frame rate (fps).
    public var frameRate: Double?

    /// File size in bytes.
    public var fileSize: Int64?

    /// Model identifier.
    public var modelIdentifier: String?

    /// Estimated cost.
    public var estimatedCost: Double?

    public init(
        id: UUID = UUID(),
        providerId: String,
        prompt: String,
        videoURL: URL,
        videoFormat: String,
        duration: TimeInterval? = nil
    ) {
        self.id = id
        self.providerId = providerId
        self.prompt = prompt
        self.videoURL = videoURL
        self.videoFormat = videoFormat
        self.duration = duration
        self.generatedAt = Date()
        self.modifiedAt = Date()
    }
}
