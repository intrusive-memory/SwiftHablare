//
//  VoiceURITests.swift
//  SwiftHablare
//
//  Tests for VoiceURI and CastListPage extensions
//

import Testing
import Foundation
@testable import SwiftHablare
import SwiftCompartido

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

@Suite("CastListPage Extensions Tests")
struct CastListPageExtensionsTests {

    // MARK: - Creation Tests

    @Test("Create CastListPage from voice mapping")
    func testFromVoiceMapping() {
        let uri1 = VoiceURI(providerId: "apple", voiceId: "voice-1", languageCode: "en")
        let uri2 = VoiceURI(providerId: "elevenlabs", voiceId: "voice-2", languageCode: "en")

        let castList = CastListPage.fromVoiceMapping(
            title: "Voice Cast",
            mapping: [
                "ALICE": uri1,
                "BOB": uri2
            ]
        )

        #expect(castList.title == "Voice Cast")
        #expect(castList.items.count == 2)
        #expect(castList.items.contains(where: { $0.role == "ALICE" }))
        #expect(castList.items.contains(where: { $0.role == "BOB" }))
    }

    @Test("Get voice URI for character")
    func testGetVoiceURI() {
        let uri = VoiceURI(providerId: "apple", voiceId: "voice-1", languageCode: "en")
        let castList = CastListPage.fromVoiceMapping(
            title: "Test",
            mapping: ["ALICE": uri]
        )

        let retrievedURI = castList.voiceURI(for: "ALICE")

        #expect(retrievedURI.providerId == uri.providerId)
        #expect(retrievedURI.voiceId == uri.voiceId)
        #expect(retrievedURI.languageCode == uri.languageCode)
    }

    @Test("Get default voice for missing character")
    func testGetDefaultVoiceForMissingCharacter() {
        let castList = CastListPage(title: "Empty", position: 0)

        let uri = castList.voiceURI(for: "UNKNOWN")

        #expect(uri.isDefaultVoice == true)
    }

    @Test("Case-insensitive role lookup")
    func testCaseInsensitiveRoleLookup() {
        let uri = VoiceURI(providerId: "apple", voiceId: "voice-1", languageCode: "en")
        let castList = CastListPage.fromVoiceMapping(
            title: "Test",
            mapping: ["ALICE": uri]
        )

        let uri1 = castList.voiceURI(for: "ALICE")
        let uri2 = castList.voiceURI(for: "alice")
        let uri3 = castList.voiceURI(for: "Alice")

        #expect(uri1.voiceId == uri.voiceId)
        #expect(uri2.voiceId == uri.voiceId)
        #expect(uri3.voiceId == uri.voiceId)
    }

    // MARK: - Mutation Tests

    @Test("Add voice mapping")
    func testAddVoiceMapping() {
        var castList = CastListPage(title: "Test", position: 0)
        let uri = VoiceURI(providerId: "apple", voiceId: "voice-1", languageCode: "en")

        castList.addVoiceMapping(role: "ALICE", voiceURI: uri)

        #expect(castList.items.count == 1)
        #expect(castList.items.first?.role == "ALICE")
        #expect(castList.items.first?.name == uri.uriString)
    }

    @Test("Update voice mapping")
    func testUpdateVoiceMapping() {
        let uri1 = VoiceURI(providerId: "apple", voiceId: "voice-1", languageCode: "en")
        let uri2 = VoiceURI(providerId: "elevenlabs", voiceId: "voice-2", languageCode: "en")

        var castList = CastListPage.fromVoiceMapping(
            title: "Test",
            mapping: ["ALICE": uri1]
        )

        castList.updateVoiceMapping(role: "ALICE", voiceURI: uri2)

        let updatedURI = castList.voiceURI(for: "ALICE")
        #expect(updatedURI.providerId == "elevenlabs")
        #expect(updatedURI.voiceId == "voice-2")
    }

    // MARK: - Validation Tests

    @Test("Validate voice URIs are parseable")
    func testValidateVoiceURIs() {
        var castList = CastListPage(title: "Test", position: 0)

        // Add valid URI
        castList.addMember(role: "ALICE", name: "hablare://apple/voice-1?lang=en")

        // Add invalid URI
        castList.addMember(role: "BOB", name: "invalid-uri")

        let validation = castList.validateVoiceURIs()

        #expect(validation["ALICE"] == true)
        #expect(validation["BOB"] == false)
    }

    // MARK: - JSON Serialization Tests

    @Test("CastListPage with voice URIs serializes to JSON")
    func testJSONSerialization() throws {
        let uri1 = VoiceURI(providerId: "apple", voiceId: "voice-1", languageCode: "en")
        let uri2 = VoiceURI(providerId: "elevenlabs", voiceId: "voice-2", languageCode: "en")

        let castList = CastListPage.fromVoiceMapping(
            title: "Voice Cast",
            mapping: [
                "ALICE": uri1,
                "BOB": uri2
            ]
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        let data = try encoder.encode(castList)
        let json = String(data: data, encoding: .utf8)

        #expect(json != nil)
        // URIs might be URL-encoded in JSON, so check for both formats
        let containsApple = json?.contains("hablare://apple/voice-1?lang=en") == true ||
                          json?.contains("hablare:\\/\\/apple\\/voice-1?lang=en") == true ||
                          json?.contains("apple\\/voice-1") == true
        let containsElevenLabs = json?.contains("hablare://elevenlabs/voice-2?lang=en") == true ||
                                json?.contains("hablare:\\/\\/elevenlabs\\/voice-2?lang=en") == true ||
                                json?.contains("elevenlabs\\/voice-2") == true

        #expect(containsApple == true)
        #expect(containsElevenLabs == true)
        #expect(json?.contains("\"type\" : \"castList\"") == true)
    }

    @Test("JSON roundtrip preserves voice URIs")
    func testJSONRoundtrip() throws {
        let uri1 = VoiceURI(providerId: "apple", voiceId: "voice-1", languageCode: "en")
        let uri2 = VoiceURI(providerId: "elevenlabs", voiceId: "voice-2", languageCode: "en")

        let original = CastListPage.fromVoiceMapping(
            title: "Voice Cast",
            mapping: [
                "ALICE": uri1,
                "BOB": uri2
            ]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CastListPage.self, from: data)

        #expect(decoded.title == original.title)
        #expect(decoded.items.count == original.items.count)

        let decodedAliceURI = decoded.voiceURI(for: "ALICE")
        let decodedBobURI = decoded.voiceURI(for: "BOB")

        #expect(decodedAliceURI.providerId == uri1.providerId)
        #expect(decodedAliceURI.voiceId == uri1.voiceId)
        #expect(decodedBobURI.providerId == uri2.providerId)
        #expect(decodedBobURI.voiceId == uri2.voiceId)
    }
}
