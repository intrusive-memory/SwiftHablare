//
//  VoiceModel.swift
//  SwiftHablare
//
//  SwiftData model for caching voice information
//

import Foundation
import SwiftData

/// SwiftData model for caching voice information
@Model
public final class VoiceModel {
    @Attribute(.unique) public var voiceId: String
    public var name: String
    public var voiceDescription: String?
    public var providerId: String
    public var language: String?
    public var locality: String?
    public var gender: String?
    public var lastFetched: Date

    public init(
        voiceId: String,
        name: String,
        voiceDescription: String?,
        providerId: String,
        language: String? = nil,
        locality: String? = nil,
        gender: String? = nil,
        lastFetched: Date = Date()
    ) {
        self.voiceId = voiceId
        self.name = name
        self.voiceDescription = voiceDescription
        self.providerId = providerId
        self.language = language
        self.locality = locality
        self.gender = gender
        self.lastFetched = lastFetched
    }

    /// Convert Voice to VoiceModel
    public static func from(_ voice: Voice) -> VoiceModel {
        VoiceModel(
            voiceId: voice.id,
            name: voice.name,
            voiceDescription: voice.description,
            providerId: voice.providerId,
            language: voice.language,
            locality: voice.locality,
            gender: voice.gender
        )
    }

    /// Convert VoiceModel to Voice
    public func toVoice() -> Voice {
        Voice(
            id: voiceId,
            name: name,
            description: voiceDescription,
            providerId: providerId,
            language: language,
            locality: locality,
            gender: gender
        )
    }
}
