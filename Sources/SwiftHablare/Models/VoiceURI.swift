//
//  VoiceURI.swift
//  SwiftHablare
//
//  Voice URI for portable voice references
//  Format: hablare://<providerId>/<voiceId>?lang=<languageCode>
//

import Foundation

/// Voice URI for portable voice references across voice providers
///
/// Format: `hablare://<providerId>/<voiceId>?lang=<languageCode>`
///
/// ## Examples
///
/// ```swift
/// // Apple voice with language
/// let uri1 = VoiceURI(
///     providerId: "apple",
///     voiceId: "com.apple.voice.compact.en-US.Samantha",
///     languageCode: "en"
/// )
/// // => "hablare://apple/com.apple.voice.compact.en-US.Samantha?lang=en"
///
/// // ElevenLabs voice
/// let uri2 = VoiceURI(
///     providerId: "elevenlabs",
///     voiceId: "21m00Tcm4TlvDq8ikWAM",
///     languageCode: "en"
/// )
/// // => "hablare://elevenlabs/21m00Tcm4TlvDq8ikWAM?lang=en"
///
/// // Parse from string
/// let uri3 = VoiceURI(uriString: "hablare://apple/voice-id?lang=es")
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
    /// Parses URIs in the format: `hablare://providerId/voiceId?lang=languageCode`
    ///
    /// ## Examples
    ///
    /// ```swift
    /// let uri1 = VoiceURI(uriString: "hablare://apple/voice-id?lang=en")
    /// let uri2 = VoiceURI(uriString: "hablare://elevenlabs/21m00Tcm4TlvDq8ikWAM")
    /// ```
    ///
    /// - Parameter uriString: URI string to parse
    /// - Returns: Parsed VoiceURI, or nil if invalid
    public init?(uriString: String) {
        guard let url = URL(string: uriString),
              url.scheme == "hablare",
              let host = url.host,
              !url.path.isEmpty else {
            return nil
        }

        self.providerId = host.lowercased()
        let extractedVoiceId = String(url.path.dropFirst())  // Remove leading "/"

        // Voice ID must not be empty
        guard !extractedVoiceId.isEmpty else {
            return nil
        }

        self.voiceId = extractedVoiceId

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
        return providerId == "apple" && voiceId.contains(".Default")
    }

    // MARK: - String Conversion

    /// Convert to URI string
    ///
    /// Generates the canonical URI string representation.
    ///
    /// ## Format
    ///
    /// - Without language: `hablare://providerId/voiceId`
    /// - With language: `hablare://providerId/voiceId?lang=languageCode`
    ///
    /// - Returns: URI string
    public var uriString: String {
        var uri = "hablare://\(providerId)/\(voiceId)"
        if let lang = languageCode {
            uri += "?lang=\(lang)"
        }
        return uri
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

// MARK: - CastListPage

/// Cast list page for screenplay character-to-voice mappings
///
/// Follows SwiftCompartido's page pattern (similar to TitlePageData).
/// Used for export/import of character voice assignments.
///
/// ## JSON Export (for custom-pages.json)
///
/// ```json
/// {
///   "castList": {
///     "ALICE": "hablare://apple/com.apple.voice.compact.en-US.Samantha?lang=en",
///     "BOB": "hablare://elevenlabs/21m00Tcm4TlvDq8ikWAM?lang=en"
///   }
/// }
/// ```
///
/// ## YAML Export (for Markdown front matter)
///
/// ```yaml
/// castList:
///   ALICE: hablare://apple/com.apple.voice.compact.en-US.Samantha?lang=en
///   BOB: hablare://elevenlabs/21m00Tcm4TlvDq8ikWAM?lang=en
/// ```
///
/// ## Usage
///
/// ```swift
/// // Create cast list
/// let castList = CastListPage(entries: [
///     "ALICE": VoiceURI(providerId: "apple", voiceId: "voice1", languageCode: "en"),
///     "BOB": VoiceURI(providerId: "elevenlabs", voiceId: "voice2", languageCode: "en")
/// ])
///
/// // Export to JSON
/// let jsonData = try castList.toJSON()
///
/// // Export to YAML
/// let yamlString = castList.toYAML()
///
/// // Import from JSON
/// let imported = try CastListPage.fromJSON(jsonData)
/// ```
public struct CastListPage: Codable, Sendable {

    /// Character name to voice URI mapping
    ///
    /// Key: Character name (e.g., "ALICE", "BOB")
    /// Value: Voice URI string (e.g., "hablare://apple/voice-id?lang=en")
    public let castList: [String: String]

    // MARK: - Initialization

    /// Create a cast list page from URI strings
    ///
    /// - Parameter castList: Dictionary mapping character names to voice URI strings
    public init(castList: [String: String]) {
        self.castList = castList
    }

    /// Create a cast list page from VoiceURI objects
    ///
    /// - Parameter entries: Dictionary mapping character names to VoiceURI objects
    public init(entries: [String: VoiceURI]) {
        self.castList = entries.mapValues { $0.uriString }
    }

    /// Create an empty cast list
    public init() {
        self.castList = [:]
    }

    // MARK: - Access

    /// Get voice URI for a character
    ///
    /// Returns the default voice URI if character not found.
    ///
    /// - Parameter characterName: Character name to look up
    /// - Returns: VoiceURI for the character, or default voice if not found
    public func voiceURI(for characterName: String) -> VoiceURI {
        guard let uriString = castList[characterName],
              let uri = VoiceURI(uriString: uriString) else {
            return VoiceURI.defaultVoice()
        }
        return uri
    }

    /// Get all character names
    ///
    /// - Returns: Array of character names
    public var characterNames: [String] {
        return Array(castList.keys).sorted()
    }

    /// Check if a character has a voice assignment
    ///
    /// - Parameter characterName: Character name to check
    /// - Returns: True if character has voice assignment
    public func hasVoice(for characterName: String) -> Bool {
        return castList[characterName] != nil
    }

    // MARK: - Mutation

    /// Create a new cast list with an added character-voice mapping
    ///
    /// - Parameters:
    ///   - characterName: Character name
    ///   - voiceURI: Voice URI
    /// - Returns: New CastListPage with the added entry
    public func adding(characterName: String, voiceURI: VoiceURI) -> CastListPage {
        var newCastList = castList
        newCastList[characterName] = voiceURI.uriString
        return CastListPage(castList: newCastList)
    }

    /// Create a new cast list with a removed character
    ///
    /// - Parameter characterName: Character name to remove
    /// - Returns: New CastListPage without the character
    public func removing(characterName: String) -> CastListPage {
        var newCastList = castList
        newCastList.removeValue(forKey: characterName)
        return CastListPage(castList: newCastList)
    }

    // MARK: - JSON Serialization

    /// Export to JSON data
    ///
    /// Produces formatted JSON suitable for custom-pages.json export.
    ///
    /// - Returns: JSON data
    /// - Throws: EncodingError if serialization fails
    public func toJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    /// Import from JSON data
    ///
    /// - Parameter data: JSON data to parse
    /// - Returns: Parsed CastListPage
    /// - Throws: DecodingError if parsing fails
    public static func fromJSON(_ data: Data) throws -> CastListPage {
        let decoder = JSONDecoder()
        return try decoder.decode(CastListPage.self, from: data)
    }

    // MARK: - YAML Serialization

    /// Export to YAML string
    ///
    /// Produces YAML suitable for Markdown front matter.
    ///
    /// ## Format
    ///
    /// ```yaml
    /// castList:
    ///   ALICE: hablare://apple/voice-id?lang=en
    ///   BOB: hablare://elevenlabs/voice-id?lang=en
    /// ```
    ///
    /// - Returns: YAML string
    public func toYAML() -> String {
        var yaml = "castList:\n"

        // Sort character names for consistent output
        let sortedNames = characterNames

        for characterName in sortedNames {
            if let uriString = castList[characterName] {
                yaml += "  \(characterName): \(uriString)\n"
            }
        }

        return yaml
    }

    /// Import from YAML string
    ///
    /// Parses YAML in the format:
    ///
    /// ```yaml
    /// castList:
    ///   CHARACTER_NAME: hablare://provider/voiceId?lang=code
    /// ```
    ///
    /// - Parameter yaml: YAML string to parse
    /// - Returns: Parsed CastListPage, or nil if parsing fails
    public static func fromYAML(_ yaml: String) -> CastListPage? {
        var castList: [String: String] = [:]

        // Simple YAML parser for castList format
        let lines = yaml.split(separator: "\n")
        var inCastList = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed == "castList:" {
                inCastList = true
                continue
            }

            if inCastList {
                // Parse line: "  CHARACTER_NAME: hablare://..."
                if trimmed.hasPrefix("---") || trimmed.hasPrefix("...") {
                    // End of YAML document
                    break
                }

                if !trimmed.contains(":") {
                    continue
                }

                let parts = trimmed.split(separator: ":", maxSplits: 1)
                if parts.count == 2 {
                    let characterName = parts[0].trimmingCharacters(in: .whitespaces)
                    let uriString = parts[1].trimmingCharacters(in: .whitespaces)

                    // Validate it's a hablare:// URI
                    if uriString.hasPrefix("hablare://") {
                        castList[characterName] = uriString
                    }
                }
            }
        }

        return CastListPage(castList: castList)
    }

    // MARK: - Validation

    /// Validate all voice URIs can be parsed
    ///
    /// - Returns: Dictionary of character names to validation results (true = valid, false = invalid)
    public func validate() -> [String: Bool] {
        var results: [String: Bool] = [:]

        for (characterName, uriString) in castList {
            results[characterName] = VoiceURI(uriString: uriString) != nil
        }

        return results
    }

    /// Validate all voices are available using GenerationService
    ///
    /// Checks if each voice URI can be resolved to an actual voice.
    ///
    /// - Parameter service: GenerationService to use for validation
    /// - Returns: Dictionary of character names to availability (true = available, false = unavailable)
    public func validateAvailability(using service: GenerationService) async -> [String: Bool] {
        var results: [String: Bool] = [:]

        for characterName in characterNames {
            let uri = voiceURI(for: characterName)
            results[characterName] = await uri.isAvailable(using: service)
        }

        return results
    }
}
