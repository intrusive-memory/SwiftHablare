//
//  VoiceURITests.swift
//  SwiftHablare
//
//  Tests for VoiceURI and CastListPage
//

import Testing
import Foundation
@testable import SwiftHablare

@Suite("VoiceURI Tests")
struct VoiceURITests {

    // MARK: - Initialization Tests

    @Test("Create VoiceURI from components")
    func testInitFromComponents() {
        let uri = VoiceURI(
            providerId: "apple",
            voiceId: "com.apple.voice.compact.en-US.Samantha",
            languageCode: "en"
        )

        #expect(uri.providerId == "apple")
        #expect(uri.voiceId == "com.apple.voice.compact.en-US.Samantha")
        #expect(uri.languageCode == "en")
    }

    @Test("Provider ID is normalized to lowercase")
    func testProviderIdNormalization() {
        let uri = VoiceURI(
            providerId: "Apple",  // Mixed case
            voiceId: "voice-id",
            languageCode: "en"
        )

        #expect(uri.providerId == "apple")  // Should be lowercased
    }

    @Test("Voice ID is case-sensitive")
    func testVoiceIdCaseSensitive() {
        let uri = VoiceURI(
            providerId: "apple",
            voiceId: "Voice-ID-123",  // Mixed case
            languageCode: "en"
        )

        #expect(uri.voiceId == "Voice-ID-123")  // Case preserved
    }

    @Test("Create VoiceURI without language code")
    func testInitWithoutLanguageCode() {
        let uri = VoiceURI(
            providerId: "apple",
            voiceId: "voice-id"
        )

        #expect(uri.languageCode == nil)
    }

    @Test("Create VoiceURI from Voice model")
    func testInitFromVoice() {
        let voice = Voice(
            id: "voice-123",
            name: "Test Voice",
            description: "Test",
            providerId: "elevenlabs",
            language: "en-US"
        )

        let uri = VoiceURI(from: voice, languageCode: nil)

        #expect(uri.providerId == "elevenlabs")
        #expect(uri.voiceId == "voice-123")
        #expect(uri.languageCode == "en-US")  // From voice.language
    }

    @Test("Create VoiceURI from Voice with language override")
    func testInitFromVoiceWithLanguageOverride() {
        let voice = Voice(
            id: "voice-123",
            name: "Test Voice",
            description: "Test",
            providerId: "apple",
            language: "en-US"
        )

        let uri = VoiceURI(from: voice, languageCode: "es")

        #expect(uri.languageCode == "es")  // Override takes precedence
    }

    // MARK: - URI String Parsing Tests

    @Test("Parse valid URI with language")
    func testParseURIWithLanguage() {
        let uriString = "hablare://apple/com.apple.voice.compact.en-US.Samantha?lang=en"
        let uri = VoiceURI(uriString: uriString)

        #expect(uri != nil)
        #expect(uri?.providerId == "apple")
        #expect(uri?.voiceId == "com.apple.voice.compact.en-US.Samantha")
        #expect(uri?.languageCode == "en")
    }

    @Test("Parse valid URI without language")
    func testParseURIWithoutLanguage() {
        let uriString = "hablare://elevenlabs/21m00Tcm4TlvDq8ikWAM"
        let uri = VoiceURI(uriString: uriString)

        #expect(uri != nil)
        #expect(uri?.providerId == "elevenlabs")
        #expect(uri?.voiceId == "21m00Tcm4TlvDq8ikWAM")
        #expect(uri?.languageCode == nil)
    }

    @Test("Parse URI with mixed case provider ID")
    func testParseURIWithMixedCaseProviderId() {
        let uriString = "hablare://Apple/voice-id?lang=en"
        let uri = VoiceURI(uriString: uriString)

        #expect(uri?.providerId == "apple")  // Should be lowercased
    }

    @Test("Reject URI with wrong scheme")
    func testRejectWrongScheme() {
        let uri = VoiceURI(uriString: "http://apple/voice-id")
        #expect(uri == nil)
    }

    @Test("Reject URI with missing provider")
    func testRejectMissingProvider() {
        let uri = VoiceURI(uriString: "hablare:///voice-id")
        #expect(uri == nil)
    }

    @Test("Reject URI with missing voice ID")
    func testRejectMissingVoiceId() {
        let uri = VoiceURI(uriString: "hablare://apple/")
        #expect(uri == nil)
    }

    @Test("Reject completely invalid URI")
    func testRejectInvalidURI() {
        let uri = VoiceURI(uriString: "not-a-uri")
        #expect(uri == nil)
    }

    // MARK: - URI String Generation Tests

    @Test("Generate URI string with language")
    func testGenerateURIStringWithLanguage() {
        let uri = VoiceURI(
            providerId: "apple",
            voiceId: "voice-id",
            languageCode: "en"
        )

        #expect(uri.uriString == "hablare://apple/voice-id?lang=en")
    }

    @Test("Generate URI string without language")
    func testGenerateURIStringWithoutLanguage() {
        let uri = VoiceURI(
            providerId: "elevenlabs",
            voiceId: "voice-id"
        )

        #expect(uri.uriString == "hablare://elevenlabs/voice-id")
    }

    @Test("URI string roundtrip")
    func testURIStringRoundtrip() {
        let original = VoiceURI(
            providerId: "apple",
            voiceId: "com.apple.voice.compact.en-US.Samantha",
            languageCode: "en"
        )

        let uriString = original.uriString
        let parsed = VoiceURI(uriString: uriString)

        #expect(parsed?.providerId == original.providerId)
        #expect(parsed?.voiceId == original.voiceId)
        #expect(parsed?.languageCode == original.languageCode)
    }

    // MARK: - Default Voice Tests

    @Test("Create default voice")
    func testDefaultVoice() {
        let defaultVoice = VoiceURI.defaultVoice()

        #expect(defaultVoice.providerId == "apple")
        #expect(defaultVoice.voiceId.contains(".Default"))
        #expect(defaultVoice.languageCode != nil)
    }

    @Test("Detect default voice")
    func testIsDefaultVoice() {
        let defaultVoice = VoiceURI.defaultVoice()
        #expect(defaultVoice.isDefaultVoice == true)

        let customVoice = VoiceURI(
            providerId: "apple",
            voiceId: "com.apple.voice.compact.en-US.Samantha",
            languageCode: "en"
        )
        #expect(customVoice.isDefaultVoice == false)
    }

    // MARK: - Codable Tests

    @Test("Encode VoiceURI to JSON")
    func testEncodeToJSON() throws {
        let uri = VoiceURI(
            providerId: "apple",
            voiceId: "voice-id",
            languageCode: "en"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(uri)
        let json = String(data: data, encoding: .utf8)

        #expect(json != nil)
        #expect(json?.contains("\"providerId\":\"apple\"") == true)
        #expect(json?.contains("\"voiceId\":\"voice-id\"") == true)
        #expect(json?.contains("\"languageCode\":\"en\"") == true)
    }

    @Test("Decode VoiceURI from JSON")
    func testDecodeFromJSON() throws {
        let json = """
        {
            "providerId": "Apple",
            "voiceId": "voice-id",
            "languageCode": "en"
        }
        """

        let decoder = JSONDecoder()
        let uri = try decoder.decode(VoiceURI.self, from: json.data(using: .utf8)!)

        #expect(uri.providerId == "apple")  // Should be lowercased
        #expect(uri.voiceId == "voice-id")
        #expect(uri.languageCode == "en")
    }

    @Test("Decode VoiceURI without language code")
    func testDecodeWithoutLanguageCode() throws {
        let json = """
        {
            "providerId": "apple",
            "voiceId": "voice-id"
        }
        """

        let decoder = JSONDecoder()
        let uri = try decoder.decode(VoiceURI.self, from: json.data(using: .utf8)!)

        #expect(uri.languageCode == nil)
    }

    @Test("JSON roundtrip")
    func testJSONRoundtrip() throws {
        let original = VoiceURI(
            providerId: "elevenlabs",
            voiceId: "21m00Tcm4TlvDq8ikWAM",
            languageCode: "es"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(VoiceURI.self, from: data)

        #expect(decoded.providerId == original.providerId)
        #expect(decoded.voiceId == original.voiceId)
        #expect(decoded.languageCode == original.languageCode)
    }

    // MARK: - Hashable Tests

    @Test("VoiceURI is hashable")
    func testHashable() {
        let uri1 = VoiceURI(providerId: "apple", voiceId: "voice-1", languageCode: "en")
        let uri2 = VoiceURI(providerId: "apple", voiceId: "voice-1", languageCode: "en")
        let uri3 = VoiceURI(providerId: "apple", voiceId: "voice-2", languageCode: "en")

        #expect(uri1.hashValue == uri2.hashValue)
        #expect(uri1.hashValue != uri3.hashValue)
    }

    @Test("VoiceURI equality")
    func testEquality() {
        let uri1 = VoiceURI(providerId: "apple", voiceId: "voice-1", languageCode: "en")
        let uri2 = VoiceURI(providerId: "apple", voiceId: "voice-1", languageCode: "en")
        let uri3 = VoiceURI(providerId: "apple", voiceId: "voice-2", languageCode: "en")

        #expect(uri1 == uri2)
        #expect(uri1 != uri3)
    }

    @Test("VoiceURI can be used in Set")
    func testUseInSet() {
        let uri1 = VoiceURI(providerId: "apple", voiceId: "voice-1", languageCode: "en")
        let uri2 = VoiceURI(providerId: "apple", voiceId: "voice-1", languageCode: "en")
        let uri3 = VoiceURI(providerId: "apple", voiceId: "voice-2", languageCode: "en")

        let set: Set<VoiceURI> = [uri1, uri2, uri3]

        #expect(set.count == 2)  // uri1 and uri2 are equal
    }

    @Test("VoiceURI can be used as Dictionary key")
    func testUseAsDictionaryKey() {
        let uri1 = VoiceURI(providerId: "apple", voiceId: "voice-1", languageCode: "en")
        let uri2 = VoiceURI(providerId: "apple", voiceId: "voice-2", languageCode: "en")

        let dict: [VoiceURI: String] = [
            uri1: "Voice One",
            uri2: "Voice Two"
        ]

        #expect(dict[uri1] == "Voice One")
        #expect(dict[uri2] == "Voice Two")
    }
}

@Suite("CastListPage Tests")
struct CastListPageTests {

    // MARK: - Initialization Tests

    @Test("Create empty cast list")
    func testCreateEmptyCastList() {
        let castList = CastListPage()
        #expect(castList.castList.isEmpty)
        #expect(castList.characterNames.isEmpty)
    }

    @Test("Create cast list from URI strings")
    func testCreateFromURIStrings() {
        let castList = CastListPage(castList: [
            "ALICE": "hablare://apple/voice-1?lang=en",
            "BOB": "hablare://elevenlabs/voice-2?lang=en"
        ])

        #expect(castList.castList.count == 2)
        #expect(castList.castList["ALICE"] == "hablare://apple/voice-1?lang=en")
        #expect(castList.castList["BOB"] == "hablare://elevenlabs/voice-2?lang=en")
    }

    @Test("Create cast list from VoiceURI objects")
    func testCreateFromVoiceURIs() {
        let uri1 = VoiceURI(providerId: "apple", voiceId: "voice-1", languageCode: "en")
        let uri2 = VoiceURI(providerId: "elevenlabs", voiceId: "voice-2", languageCode: "en")

        let castList = CastListPage(entries: [
            "ALICE": uri1,
            "BOB": uri2
        ])

        #expect(castList.castList.count == 2)
        #expect(castList.castList["ALICE"] == uri1.uriString)
        #expect(castList.castList["BOB"] == uri2.uriString)
    }

    // MARK: - Access Tests

    @Test("Get voice URI for character")
    func testGetVoiceURI() {
        let uri = VoiceURI(providerId: "apple", voiceId: "voice-1", languageCode: "en")
        let castList = CastListPage(entries: ["ALICE": uri])

        let retrievedURI = castList.voiceURI(for: "ALICE")

        #expect(retrievedURI.providerId == uri.providerId)
        #expect(retrievedURI.voiceId == uri.voiceId)
        #expect(retrievedURI.languageCode == uri.languageCode)
    }

    @Test("Get default voice for missing character")
    func testGetDefaultVoiceForMissingCharacter() {
        let castList = CastListPage()

        let uri = castList.voiceURI(for: "UNKNOWN")

        #expect(uri.isDefaultVoice == true)
    }

    @Test("Get character names")
    func testGetCharacterNames() {
        let castList = CastListPage(castList: [
            "CHARLIE": "hablare://apple/voice-3?lang=en",
            "ALICE": "hablare://apple/voice-1?lang=en",
            "BOB": "hablare://elevenlabs/voice-2?lang=en"
        ])

        let names = castList.characterNames

        #expect(names.count == 3)
        #expect(names.sorted() == ["ALICE", "BOB", "CHARLIE"])  // Should be sorted
    }

    @Test("Check if character has voice")
    func testHasVoice() {
        let castList = CastListPage(castList: [
            "ALICE": "hablare://apple/voice-1?lang=en"
        ])

        #expect(castList.hasVoice(for: "ALICE") == true)
        #expect(castList.hasVoice(for: "BOB") == false)
    }

    // MARK: - Mutation Tests

    @Test("Add character to cast list")
    func testAddCharacter() {
        let original = CastListPage(castList: [
            "ALICE": "hablare://apple/voice-1?lang=en"
        ])

        let uri = VoiceURI(providerId: "elevenlabs", voiceId: "voice-2", languageCode: "en")
        let updated = original.adding(characterName: "BOB", voiceURI: uri)

        #expect(original.castList.count == 1)  // Original unchanged
        #expect(updated.castList.count == 2)  // New copy has 2 entries
        #expect(updated.hasVoice(for: "BOB") == true)
    }

    @Test("Remove character from cast list")
    func testRemoveCharacter() {
        let original = CastListPage(castList: [
            "ALICE": "hablare://apple/voice-1?lang=en",
            "BOB": "hablare://elevenlabs/voice-2?lang=en"
        ])

        let updated = original.removing(characterName: "BOB")

        #expect(original.castList.count == 2)  // Original unchanged
        #expect(updated.castList.count == 1)  // New copy has 1 entry
        #expect(updated.hasVoice(for: "ALICE") == true)
        #expect(updated.hasVoice(for: "BOB") == false)
    }

    // MARK: - JSON Serialization Tests

    @Test("Export to JSON")
    func testExportToJSON() throws {
        let castList = CastListPage(castList: [
            "ALICE": "hablare://apple/voice-1?lang=en",
            "BOB": "hablare://elevenlabs/voice-2?lang=en"
        ])

        let jsonData = try castList.toJSON()
        let json = String(data: jsonData, encoding: .utf8)

        #expect(json != nil)
        #expect(json?.contains("\"castList\"") == true)
        #expect(json?.contains("\"ALICE\"") == true)
        #expect(json?.contains("\"BOB\"") == true)
    }

    @Test("Import from JSON")
    func testImportFromJSON() throws {
        let json = """
        {
            "castList": {
                "ALICE": "hablare://apple/voice-1?lang=en",
                "BOB": "hablare://elevenlabs/voice-2?lang=en"
            }
        }
        """

        let castList = try CastListPage.fromJSON(json.data(using: .utf8)!)

        #expect(castList.castList.count == 2)
        #expect(castList.castList["ALICE"] == "hablare://apple/voice-1?lang=en")
        #expect(castList.castList["BOB"] == "hablare://elevenlabs/voice-2?lang=en")
    }

    @Test("JSON roundtrip")
    func testJSONRoundtrip() throws {
        let original = CastListPage(castList: [
            "ALICE": "hablare://apple/voice-1?lang=en",
            "BOB": "hablare://elevenlabs/voice-2?lang=en",
            "CHARLIE": "hablare://apple/voice-3?lang=es"
        ])

        let jsonData = try original.toJSON()
        let decoded = try CastListPage.fromJSON(jsonData)

        #expect(decoded.castList.count == original.castList.count)
        #expect(decoded.castList["ALICE"] == original.castList["ALICE"])
        #expect(decoded.castList["BOB"] == original.castList["BOB"])
        #expect(decoded.castList["CHARLIE"] == original.castList["CHARLIE"])
    }

    // MARK: - YAML Serialization Tests

    @Test("Export to YAML")
    func testExportToYAML() {
        let castList = CastListPage(castList: [
            "ALICE": "hablare://apple/voice-1?lang=en",
            "BOB": "hablare://elevenlabs/voice-2?lang=en"
        ])

        let yaml = castList.toYAML()

        #expect(yaml.contains("castList:"))
        #expect(yaml.contains("ALICE: hablare://apple/voice-1?lang=en"))
        #expect(yaml.contains("BOB: hablare://elevenlabs/voice-2?lang=en"))
    }

    @Test("YAML output is sorted by character name")
    func testYAMLSorted() {
        let castList = CastListPage(castList: [
            "CHARLIE": "hablare://apple/voice-3?lang=en",
            "ALICE": "hablare://apple/voice-1?lang=en",
            "BOB": "hablare://elevenlabs/voice-2?lang=en"
        ])

        let yaml = castList.toYAML()
        let lines = yaml.split(separator: "\n").map(String.init)

        // Characters should appear in sorted order
        let aliceIndex = lines.firstIndex { $0.contains("ALICE") }
        let bobIndex = lines.firstIndex { $0.contains("BOB") }
        let charlieIndex = lines.firstIndex { $0.contains("CHARLIE") }

        #expect(aliceIndex != nil)
        #expect(bobIndex != nil)
        #expect(charlieIndex != nil)
        #expect(aliceIndex! < bobIndex!)
        #expect(bobIndex! < charlieIndex!)
    }

    @Test("Import from YAML")
    func testImportFromYAML() {
        let yaml = """
        castList:
          ALICE: hablare://apple/voice-1?lang=en
          BOB: hablare://elevenlabs/voice-2?lang=en
        """

        let castList = CastListPage.fromYAML(yaml)

        #expect(castList != nil)
        #expect(castList?.castList.count == 2)
        #expect(castList?.castList["ALICE"] == "hablare://apple/voice-1?lang=en")
        #expect(castList?.castList["BOB"] == "hablare://elevenlabs/voice-2?lang=en")
    }

    @Test("Import from YAML with extra whitespace")
    func testImportFromYAMLWithWhitespace() {
        let yaml = """
        castList:
          ALICE:   hablare://apple/voice-1?lang=en
          BOB:hablare://elevenlabs/voice-2?lang=en
        """

        let castList = CastListPage.fromYAML(yaml)

        #expect(castList?.castList.count == 2)
    }

    @Test("Import from YAML ignores non-hablare URIs")
    func testImportFromYAMLIgnoresInvalidURIs() {
        let yaml = """
        castList:
          ALICE: hablare://apple/voice-1?lang=en
          BOB: http://example.com/voice
          CHARLIE: hablare://elevenlabs/voice-2?lang=en
        """

        let castList = CastListPage.fromYAML(yaml)

        #expect(castList?.castList.count == 2)  // BOB should be ignored
        #expect(castList?.hasVoice(for: "ALICE") == true)
        #expect(castList?.hasVoice(for: "BOB") == false)
        #expect(castList?.hasVoice(for: "CHARLIE") == true)
    }

    @Test("YAML roundtrip")
    func testYAMLRoundtrip() {
        let original = CastListPage(castList: [
            "ALICE": "hablare://apple/voice-1?lang=en",
            "BOB": "hablare://elevenlabs/voice-2?lang=en"
        ])

        let yaml = original.toYAML()
        let decoded = CastListPage.fromYAML(yaml)

        #expect(decoded?.castList.count == original.castList.count)
        #expect(decoded?.castList["ALICE"] == original.castList["ALICE"])
        #expect(decoded?.castList["BOB"] == original.castList["BOB"])
    }

    // MARK: - Validation Tests

    @Test("Validate all URIs are parseable")
    func testValidateURIs() {
        let castList = CastListPage(castList: [
            "ALICE": "hablare://apple/voice-1?lang=en",
            "BOB": "invalid-uri",
            "CHARLIE": "hablare://elevenlabs/voice-2?lang=en"
        ])

        let validation = castList.validate()

        #expect(validation["ALICE"] == true)
        #expect(validation["BOB"] == false)
        #expect(validation["CHARLIE"] == true)
    }

    @Test("Empty cast list validates successfully")
    func testValidateEmptyCastList() {
        let castList = CastListPage()
        let validation = castList.validate()

        #expect(validation.isEmpty)
    }
}
