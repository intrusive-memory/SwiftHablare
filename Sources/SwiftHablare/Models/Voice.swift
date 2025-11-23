//
//  Voice.swift
//  SwiftHablare
//
//  Voice model representing a TTS voice
//

import Foundation

/// Voice model representing a text-to-speech voice
public struct Voice: Identifiable, Codable, Sendable {
    public let id: String
    public let name: String
    public let description: String?
    public var providerId: String
    public var language: String?
    public var locality: String?
    public var gender: String?
    public var quality: String? // For Apple voices: "default", "enhanced", "premium"

    enum CodingKeys: String, CodingKey {
        case id = "voice_id"
        case name
        case description
        case language
        case locality
        case gender
        case quality
    }

    public init(id: String, name: String, description: String?, providerId: String = "elevenlabs", language: String? = nil, locality: String? = nil, gender: String? = nil, quality: String? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.providerId = providerId
        self.language = language
        self.locality = locality
        self.gender = gender
        self.quality = quality
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
        self.language = try container.decodeIfPresent(String.self, forKey: .language)
        self.gender = try container.decodeIfPresent(String.self, forKey: .gender)
        self.locality = try container.decodeIfPresent(String.self, forKey: .locality)
        self.quality = try container.decodeIfPresent(String.self, forKey: .quality)
        self.providerId = "elevenlabs" // Default for decoded voices
    }
}
