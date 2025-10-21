import Foundation
import SwiftData

/// Model for AI-generated audio content.
@Model
public final class GeneratedAudio {
    @Attribute(.unique) public var id: UUID
    public var providerId: String
    public var prompt: String
    public var generatedAt: Date
    public var modifiedAt: Date

    /// The audio data.
    public var audioData: Data

    /// Audio format (e.g., "mp3", "wav", "aac").
    public var audioFormat: String

    /// Duration in seconds.
    public var duration: TimeInterval?

    /// Sample rate in Hz.
    public var sampleRate: Int?

    /// Bit rate in bps.
    public var bitRate: Int?

    /// Number of channels (1 = mono, 2 = stereo).
    public var channels: Int?

    /// Voice ID used (for TTS).
    public var voiceId: String?

    /// Model identifier.
    public var modelIdentifier: String?

    /// Estimated cost.
    public var estimatedCost: Double?

    public init(
        id: UUID = UUID(),
        providerId: String,
        prompt: String,
        audioData: Data,
        audioFormat: String,
        duration: TimeInterval? = nil,
        sampleRate: Int? = nil,
        voiceId: String? = nil
    ) {
        self.id = id
        self.providerId = providerId
        self.prompt = prompt
        self.audioData = audioData
        self.audioFormat = audioFormat
        self.duration = duration
        self.sampleRate = sampleRate
        self.voiceId = voiceId
        self.generatedAt = Date()
        self.modifiedAt = Date()
    }
}
