//
//  AudioFile.swift
//  SwiftHablare
//
//  SwiftData model for storing generated audio
//

import Foundation
import SwiftData

/// SwiftData model for storing generated audio files
@Model
public final class AudioFile {
    @Attribute(.unique) public var id: UUID
    public var text: String
    public var voiceId: String
    public var providerId: String
    public var audioData: Data
    public var audioFormat: String // e.g., "m4a", "mp3", "caf"
    public var duration: TimeInterval?
    public var sampleRate: Int? // Audio sample rate (e.g., 44100, 48000)
    public var bitRate: Int? // Audio bit rate in kbps
    public var channels: Int? // Number of audio channels (1 = mono, 2 = stereo)
    public var createdAt: Date
    public var modifiedAt: Date

    public init(
        id: UUID = UUID(),
        text: String,
        voiceId: String,
        providerId: String,
        audioData: Data,
        audioFormat: String,
        duration: TimeInterval? = nil,
        sampleRate: Int? = nil,
        bitRate: Int? = nil,
        channels: Int? = nil,
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.text = text
        self.voiceId = voiceId
        self.providerId = providerId
        self.audioData = audioData
        self.audioFormat = audioFormat
        self.duration = duration
        self.sampleRate = sampleRate
        self.bitRate = bitRate
        self.channels = channels
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}
