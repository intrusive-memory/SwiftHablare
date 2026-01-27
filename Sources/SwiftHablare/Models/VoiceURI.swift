//
//  VoiceURI.swift
//  SwiftHablare
//
//  Voice URI for portable voice references
//  Format: <providerId>://<voiceId>?lang=<languageCode>
//

import Foundation
import SwiftCompartido

/// Voice URI for portable voice references across voice providers
///
/// Format: `<providerId>://<voiceId>?lang=<languageCode>`
///
/// ## Examples
///
/// ```swift
/// // Create from components
/// let uri = VoiceURI(
///     providerId: "apple",
///     voiceId: "com.apple.voice.compact.en-US.Samantha",
///     languageCode: "en"
/// )
/// // => "apple://com.apple.voice.compact.en-US.Samantha?lang=en"
///
/// // ElevenLabs voice
/// let uri2 = VoiceURI(
///     providerId: "elevenlabs",
///     voiceId: "21m00Tcm4TlvDq8ikWAM",
///     languageCode: "en"
/// )
/// // => "elevenlabs://21m00Tcm4TlvDq8ikWAM?lang=en"
///
/// // Parse from string
/// let uri3 = VoiceURI(uriString: "apple://voice-id?lang=es")
/// ```
///
/// ## Usage with GenerationService
///
/// ```swift
/// // Resolve URI to Voice
/// let voice = try await uri.resolve(using: service)
///
/// // Check if voice is available
/// let isAvailable = await uri.isAvailable(using: service)
/// ```
public struct VoiceURI: Codable, Hashable, Sendable {

    /// Voice provider identifier (lowercase, e.g., "apple", "elevenlabs")
    public let providerId: String

    /// Voice identifier (case-sensitive, provider-specific)
    public let voiceId: String

    /// Language code (optional, e.g., "en", "es", "fr")
    public let languageCode: String?

    // MARK: - Initialization

    /// Create a VoiceURI from components
    ///
    /// - Parameters:
    ///   - providerId: Provider identifier (will be lowercased)
    ///   - voiceId: Voice identifier (case-sensitive)
    ///   - languageCode: Language code (optional)
    public init(providerId: String, voiceId: String, languageCode: String? = nil) {
        self.providerId = providerId.lowercased()  // Normalize provider ID to lowercase
        self.voiceId = voiceId  // Keep voice ID case-sensitive
        self.languageCode = languageCode
    }

    /// Create a VoiceURI from a Voice model
    ///
    /// - Parameters:
    ///   - voice: Voice model from a provider
    ///   - languageCode: Language code (optional, defaults to voice's language)
    public init(from voice: Voice, languageCode: String? = nil) {
        self.providerId = voice.providerId
        self.voiceId = voice.id
        self.languageCode = languageCode ?? voice.language
    }

    /// Parse a VoiceURI from a string
    ///
    /// Parses URIs in the format: `<providerId>://<voiceId>?lang=<languageCode>`
    ///
    /// ## Examples
    ///
    /// ```swift
    /// let uri1 = VoiceURI(uriString: "apple://voice-id?lang=en")
    /// let uri2 = VoiceURI(uriString: "elevenlabs://21m00Tcm4TlvDq8ikWAM")
    /// ```
    ///
    /// - Parameter uriString: URI string to parse
    /// - Returns: Parsed VoiceURI, or nil if invalid
    public init?(uriString: String) {
        guard let url = URL(string: uriString),
              let scheme = url.scheme,
              !scheme.isEmpty,
              let host = url.host,
              !host.isEmpty else {
            return nil
        }

        self.providerId = scheme.lowercased()
        self.voiceId = host

        // Parse query parameters for language code
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems,
           let langItem = queryItems.first(where: { $0.name == "lang" }),
           let langValue = langItem.value {
            self.languageCode = langValue
        } else {
            self.languageCode = nil
        }
    }

    // MARK: - Default Voice

    /// Create a default voice URI
    ///
    /// Creates a URI pointing to the system's default voice provider and voice.
    /// Uses Apple provider with system language as default.
    ///
    /// - Returns: Default VoiceURI for system voice
    public static func defaultVoice() -> VoiceURI {
        return VoiceURI(
            providerId: "apple",
            voiceId: "com.apple.voice.compact.\(LanguageCodeResolver.systemLanguageCode)-US.Default",
            languageCode: LanguageCodeResolver.systemLanguageCode
        )
    }

    /// Check if this URI represents the default voice
    ///
    /// - Returns: True if this is a default voice URI
    public var isDefaultVoice: Bool {
        return providerId == "apple" && voiceId.hasSuffix(".Default")
    }

    // MARK: - String Conversion

    /// Convert to URI string
    ///
    /// Generates the canonical URI string representation using URLComponents
    /// for proper percent-encoding of special characters.
    ///
    /// ## Format
    ///
    /// - Without language: `<providerId>://<voiceId>`
    /// - With language: `<providerId>://<voiceId>?lang=<languageCode>`
    ///
    /// - Returns: URI string with properly encoded components
    public var uriString: String {
        var components = URLComponents()
        components.scheme = providerId
        components.host = voiceId

        if let lang = languageCode {
            components.queryItems = [URLQueryItem(name: "lang", value: lang)]
        }

        return components.string ?? "\(providerId)://\(voiceId)"
    }

    /// CustomStringConvertible conformance
    public var description: String {
        return uriString
    }

    // MARK: - Voice Resolution

    /// Resolve this URI to a Voice using GenerationService
    ///
    /// Fetches voices from the provider and finds the matching voice.
    /// Falls back to default voice if the specified voice is not found.
    ///
    /// ## Fallback Behavior
    ///
    /// If the voice is not found:
    /// 1. Returns the first available voice from the same provider
    /// 2. If provider has no voices, throws error
    ///
    /// - Parameters:
    ///   - service: GenerationService to use for fetching voices
    ///   - languageCode: Optional language code override
    /// - Returns: Resolved Voice
    /// - Throws: VoiceProviderError if provider is not configured or has no voices
    public func resolve(using service: GenerationService, languageCode: String? = nil) async throws -> Voice {
        let finalLanguageCode = self.languageCode ?? languageCode ?? LanguageCodeResolver.systemLanguageCode
        let voices = try await service.fetchVoices(from: providerId, languageCode: finalLanguageCode)

        // Try to find exact match
        if let voice = voices.first(where: { $0.id == voiceId }) {
            return voice
        }

        // Fallback: Return first available voice from provider
        guard let fallbackVoice = voices.first else {
            throw VoiceProviderError.invalidRequest("No voices available for provider \(providerId)")
        }

        #if DEBUG
        print("⚠️ Voice \(voiceId) not found in provider \(providerId), falling back to \(fallbackVoice.name)")
        #endif

        return fallbackVoice
    }

    /// Check if this voice is available
    ///
    /// Queries the provider to check if the voice ID exists.
    ///
    /// - Parameter service: GenerationService to use
    /// - Returns: True if voice is available
    public func isAvailable(using service: GenerationService) async -> Bool {
        await service.isVoiceAvailable(voiceId, from: providerId)
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case providerId
        case voiceId
        case languageCode
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.providerId = try container.decode(String.self, forKey: .providerId).lowercased()
        self.voiceId = try container.decode(String.self, forKey: .voiceId)
        self.languageCode = try container.decodeIfPresent(String.self, forKey: .languageCode)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(providerId, forKey: .providerId)
        try container.encode(voiceId, forKey: .voiceId)
        try container.encodeIfPresent(languageCode, forKey: .languageCode)
    }
}
