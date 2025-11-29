//
//  CastListPage+VoiceURI.swift
//  SwiftHablare
//
//  Extensions for CastListPage to support voice URI mappings
//

import Foundation
import SwiftCompartido

// MARK: - CastListPage Extensions

extension CastListPage {

    /// Create a cast list from character-to-voice mappings
    ///
    /// Uses the `name` field to store voice URI strings.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let castList = CastListPage.fromVoiceMapping(
    ///     title: "Voice Cast",
    ///     mapping: [
    ///         "ALICE": VoiceURI(providerId: "apple", voiceId: "voice-1", languageCode: "en"),
    ///         "BOB": VoiceURI(providerId: "elevenlabs", voiceId: "voice-2", languageCode: "en")
    ///     ]
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - title: Title for the cast list page
    ///   - position: Position in custom pages (default: 0)
    ///   - printDots: Whether to print dots between role and name (default: true)
    ///   - mapping: Dictionary mapping character names to VoiceURI
    /// - Returns: CastListPage with voice URIs stored in the name field
    public static func fromVoiceMapping(
        title: String,
        position: Int = 0,
        printDots: Bool = true,
        mapping: [String: VoiceURI]
    ) -> CastListPage {
        let members = mapping.enumerated().map { index, entry in
            CastMember(
                role: entry.key,
                name: entry.value.uriString,  // Store URI in name field
                position: index
            )
        }

        return CastListPage(
            title: title,
            position: position,
            printDots: printDots,
            items: members
        )
    }

    /// Get voice URI for a character role
    ///
    /// Returns the default voice URI if character not found.
    ///
    /// - Parameter role: Character role to look up
    /// - Returns: VoiceURI for the character, or default voice if not found
    public func voiceURI(for role: String) -> VoiceURI {
        // Find cast member for this role (case-insensitive)
        guard let member = items.first(where: { $0.role.uppercased() == role.uppercased() }),
              let uri = VoiceURI(uriString: member.name) else {
            return VoiceURI.defaultVoice()
        }
        return uri
    }

    /// Add a character-to-voice mapping
    ///
    /// - Parameters:
    ///   - role: Character role
    ///   - voiceURI: Voice URI for this character
    public mutating func addVoiceMapping(role: String, voiceURI: VoiceURI) {
        addMember(role: role, name: voiceURI.uriString)
    }

    /// Update voice mapping for a character
    ///
    /// - Parameters:
    ///   - role: Character role to update
    ///   - voiceURI: New voice URI
    public mutating func updateVoiceMapping(role: String, voiceURI: VoiceURI) {
        guard let member = items.first(where: { $0.role.uppercased() == role.uppercased() }) else {
            return
        }
        updateMember(id: member.id, name: voiceURI.uriString)
    }

    /// Validate all voice URIs can be parsed
    ///
    /// - Returns: Dictionary of roles to validation results (true = valid, false = invalid)
    public func validateVoiceURIs() -> [String: Bool] {
        var results: [String: Bool] = [:]

        for member in items {
            results[member.role] = VoiceURI(uriString: member.name) != nil
        }

        return results
    }

    /// Validate all voices are available using GenerationService
    ///
    /// Checks if each voice URI can be resolved to an actual voice.
    ///
    /// - Parameter service: GenerationService to use for validation
    /// - Returns: Dictionary of roles to availability (true = available, false = unavailable)
    public func validateVoiceAvailability(using service: GenerationService) async -> [String: Bool] {
        var results: [String: Bool] = [:]

        for member in items {
            let uri = voiceURI(for: member.role)
            results[member.role] = await uri.isAvailable(using: service)
        }

        return results
    }

    // MARK: - Import/Export Helpers

    /// Export character-to-voice mappings as a dictionary
    ///
    /// Extracts all role→VoiceURI mappings from the cast list.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let castList = CastListPage.fromVoiceMapping(...)
    /// let mappings = castList.exportVoiceMappings()
    /// // ["ALICE": VoiceURI(...), "BOB": VoiceURI(...)]
    /// ```
    ///
    /// - Returns: Dictionary mapping character roles to VoiceURIs
    public func exportVoiceMappings() -> [String: VoiceURI] {
        var mappings: [String: VoiceURI] = [:]

        for member in items {
            if let uri = VoiceURI(uriString: member.name) {
                mappings[member.role] = uri
            }
        }

        return mappings
    }

    /// Import character-to-voice mappings from a dictionary
    ///
    /// Creates a new CastListPage from a dictionary of role→VoiceURI mappings.
    /// This is the inverse of `exportVoiceMappings()`.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let mappings: [String: VoiceURI] = [
    ///     "ALICE": VoiceURI(providerId: "apple", voiceId: "voice-1", languageCode: "en"),
    ///     "BOB": VoiceURI(providerId: "elevenlabs", voiceId: "voice-2", languageCode: "en")
    /// ]
    ///
    /// let castList = CastListPage.importVoiceMappings(mappings, title: "Voice Cast")
    /// ```
    ///
    /// - Parameters:
    ///   - mappings: Dictionary mapping character roles to VoiceURIs
    ///   - title: Title for the cast list page (default: "Voice Cast")
    ///   - position: Position in custom pages (default: 0)
    ///   - printDots: Whether to print dots between role and name (default: true)
    /// - Returns: CastListPage with voice mappings
    public static func importVoiceMappings(
        _ mappings: [String: VoiceURI],
        title: String = "Voice Cast",
        position: Int = 0,
        printDots: Bool = true
    ) -> CastListPage {
        return fromVoiceMapping(
            title: title,
            position: position,
            printDots: printDots,
            mapping: mappings
        )
    }

    /// Export to JSON file for custom-pages.json
    ///
    /// Encodes the cast list as JSON and writes to a file URL.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let castList = CastListPage.fromVoiceMapping(...)
    /// let url = URL(fileURLWithPath: "/path/to/custom-pages.json")
    /// try castList.exportToJSON(url: url)
    /// ```
    ///
    /// - Parameter url: File URL to write JSON to
    /// - Throws: EncodingError if encoding fails, or file system errors
    public func exportToJSON(url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: url)
    }

    /// Import from JSON file (custom-pages.json format)
    ///
    /// Decodes a CastListPage from a JSON file.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let url = URL(fileURLWithPath: "/path/to/custom-pages.json")
    /// let castList = try CastListPage.importFromJSON(url: url)
    ///
    /// // Use the imported mappings
    /// let aliceVoice = castList.voiceURI(for: "ALICE")
    /// ```
    ///
    /// - Parameter url: File URL to read JSON from
    /// - Returns: Decoded CastListPage
    /// - Throws: DecodingError if decoding fails, or file system errors
    public static func importFromJSON(url: URL) throws -> CastListPage {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode(CastListPage.self, from: data)
    }

    /// Get all character roles in the cast list
    ///
    /// - Returns: Array of character role names (sorted alphabetically)
    public var characterRoles: [String] {
        return items.map { $0.role }.sorted()
    }

    /// Get a summary of voice provider distribution
    ///
    /// Useful for understanding which providers are being used in the cast.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let summary = castList.providerSummary()
    /// // ["apple": 5, "elevenlabs": 3]
    /// ```
    ///
    /// - Returns: Dictionary mapping provider IDs to usage count
    public func providerSummary() -> [String: Int] {
        var summary: [String: Int] = [:]

        for member in items {
            if let uri = VoiceURI(uriString: member.name) {
                summary[uri.providerId, default: 0] += 1
            }
        }

        return summary
    }
}
