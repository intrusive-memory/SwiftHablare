// VoiceCatalog.swift
// Load voices from talker config spk_id dict

import Foundation

/// Represents a Qwen TTS voice
public struct QwenTTSVoice: Sendable, Identifiable, Codable {
    public let id: String
    public let name: String
    public let speakerId: Int
    public let language: String?

    public init(id: String, name: String, speakerId: Int, language: String? = nil) {
        self.id = id
        self.name = name
        self.speakerId = speakerId
        self.language = language
    }
}

/// Catalog of available voices from the model config
public struct VoiceCatalog: Sendable {
    public let voices: [QwenTTSVoice]
    public let supportedLanguages: [String: Int]

    /// Build catalog from talker config
    public init(from config: TalkerConfig) {
        self.supportedLanguages = config.codecLanguageId

        var voices: [QwenTTSVoice] = []
        for (name, spkId) in config.spkId.sorted(by: { $0.key < $1.key }) {
            voices.append(QwenTTSVoice(
                id: name.lowercased().replacingOccurrences(of: " ", with: "-"),
                name: name,
                speakerId: spkId
            ))
        }
        self.voices = voices
    }

    /// Find a voice by name (case-insensitive)
    public func voice(named name: String) -> QwenTTSVoice? {
        voices.first { $0.name.lowercased() == name.lowercased() || $0.id == name.lowercased() }
    }

    /// Get language ID for a language name
    public func languageId(for language: String) -> Int? {
        supportedLanguages[language.lowercased()]
    }

    /// Default language ID (English)
    public var defaultLanguageId: Int {
        supportedLanguages["english"] ?? 2050
    }
}
