//
//  VoiceCacheModel.swift
//  SwiftHablare
//
//  SwiftData model for caching voices from voice providers
//

import Foundation
import SwiftData

/// SwiftData model for caching voices from voice providers
///
/// This model stores voice information retrieved from providers (Apple TTS, ElevenLabs)
/// to avoid repeated API calls. Voices are cached per provider and can be refreshed
/// when the provider is initialized.
@Model
public final class VoiceCacheModel {

    // MARK: - Properties

    /// Unique identifier (composite: providerId + cacheLanguageCode + voiceId)
    @Attribute(.unique) public var id: String

    /// Provider identifier (e.g., "apple", "elevenlabs")
    public var providerId: String

    /// The language code that was requested when fetching these voices
    /// This is used as part of the cache key to ensure voices are cached per language request
    public var cacheLanguageCode: String

    /// Voice identifier from the provider
    public var voiceId: String

    /// Display name of the voice
    public var voiceName: String

    /// Optional description of the voice
    public var voiceDescription: String?

    /// Language code of the voice itself (e.g., "en", "es", "fr")
    /// This may be more specific than cacheLanguageCode (e.g., "en-US" vs "en")
    public var language: String?

    /// Locality/region code (e.g., "US", "GB", "MX")
    public var locality: String?

    /// Gender of the voice (e.g., "male", "female", "neutral")
    public var gender: String?

    /// When this voice was cached
    public var cachedAt: Date

    /// When this cache entry was last validated
    public var lastValidatedAt: Date?

    /// Whether this voice is currently available from the provider
    public var isAvailable: Bool

    // MARK: - Initialization

    /// Create a new voice cache entry
    ///
    /// - Parameters:
    ///   - providerId: Provider identifier
    ///   - cacheLanguageCode: The language code that was requested when fetching
    ///   - voiceId: Voice identifier
    ///   - voiceName: Display name
    ///   - voiceDescription: Optional description
    ///   - language: Language code of the voice itself
    ///   - locality: Locality code
    ///   - gender: Gender
    public init(
        providerId: String,
        cacheLanguageCode: String,
        voiceId: String,
        voiceName: String,
        voiceDescription: String? = nil,
        language: String? = nil,
        locality: String? = nil,
        gender: String? = nil
    ) {
        self.id = "\(providerId):\(cacheLanguageCode):\(voiceId)"
        self.providerId = providerId
        self.cacheLanguageCode = cacheLanguageCode
        self.voiceId = voiceId
        self.voiceName = voiceName
        self.voiceDescription = voiceDescription
        self.language = language
        self.locality = locality
        self.gender = gender
        self.cachedAt = Date()
        self.lastValidatedAt = Date()
        self.isAvailable = true
    }

    /// Create from a Voice struct
    ///
    /// - Parameters:
    ///   - voice: Voice instance from provider
    ///   - cacheLanguageCode: The language code that was requested when fetching
    public convenience init(from voice: Voice, cacheLanguageCode: String) {
        self.init(
            providerId: voice.providerId,
            cacheLanguageCode: cacheLanguageCode,
            voiceId: voice.id,
            voiceName: voice.name,
            voiceDescription: voice.description,
            language: voice.language,
            locality: voice.locality,
            gender: voice.gender
        )
    }

    // MARK: - Conversion

    /// Convert to Voice struct
    ///
    /// - Returns: Voice instance for use with providers
    public func toVoice() -> Voice {
        return Voice(
            id: voiceId,
            name: voiceName,
            description: voiceDescription,
            providerId: providerId,
            language: language,
            locality: locality,
            gender: gender
        )
    }

    /// Update cache timestamp
    public func markAsValidated() {
        lastValidatedAt = Date()
    }

    /// Mark voice as unavailable
    public func markAsUnavailable() {
        isAvailable = false
        lastValidatedAt = Date()
    }

    /// Check if cache is stale (older than specified interval)
    ///
    /// - Parameter interval: Time interval to consider stale (default: 24 hours)
    /// - Returns: True if cache should be refreshed
    public func isStale(after interval: TimeInterval = 86400) -> Bool {
        guard let lastValidated = lastValidatedAt else {
            return true
        }
        return Date().timeIntervalSince(lastValidated) > interval
    }
}

// MARK: - Query Helpers

extension VoiceCacheModel {

    /// Fetch all cached voices for a provider and language code
    ///
    /// - Parameters:
    ///   - providerId: Provider identifier
    ///   - languageCode: Language code that was requested
    /// - Returns: FetchDescriptor for the query
    public static func fetchDescriptor(forProvider providerId: String, languageCode: String) -> FetchDescriptor<VoiceCacheModel> {
        let predicate = #Predicate<VoiceCacheModel> { voice in
            voice.providerId == providerId && voice.cacheLanguageCode == languageCode && voice.isAvailable
        }
        return FetchDescriptor<VoiceCacheModel>(predicate: predicate)
    }

    /// Fetch all cached voices for a provider (all languages)
    ///
    /// - Parameter providerId: Provider identifier
    /// - Returns: FetchDescriptor for the query
    public static func fetchDescriptor(forProvider providerId: String) -> FetchDescriptor<VoiceCacheModel> {
        let predicate = #Predicate<VoiceCacheModel> { voice in
            voice.providerId == providerId && voice.isAvailable
        }
        return FetchDescriptor<VoiceCacheModel>(predicate: predicate)
    }

    /// Fetch a specific voice
    ///
    /// - Parameters:
    ///   - providerId: Provider identifier
    ///   - languageCode: Language code that was requested
    ///   - voiceId: Voice identifier
    /// - Returns: FetchDescriptor for the query
    public static func fetchDescriptor(providerId: String, languageCode: String, voiceId: String) -> FetchDescriptor<VoiceCacheModel> {
        let id = "\(providerId):\(languageCode):\(voiceId)"
        let predicate = #Predicate<VoiceCacheModel> { voice in
            voice.id == id
        }
        var descriptor = FetchDescriptor<VoiceCacheModel>(predicate: predicate)
        descriptor.fetchLimit = 1
        return descriptor
    }
}
