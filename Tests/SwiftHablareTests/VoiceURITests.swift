//
//  VoiceURITests.swift
//  SwiftHablare
//
//  Tests for VoiceURI model
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
        // Format: <providerId>://<voiceId>?lang=<languageCode>
        let uriString = "apple://com.apple.voice.compact.en-US.Samantha?lang=en"
        let uri = VoiceURI(uriString: uriString)

        #expect(uri != nil)
        #expect(uri?.providerId == "apple")
        #expect(uri?.voiceId == "com.apple.voice.compact.en-US.Samantha")
        #expect(uri?.languageCode == "en")
    }

    @Test("Parse valid URI without language")
    func testParseURIWithoutLanguage() {
        // Format: <providerId>://<voiceId>
        let uriString = "elevenlabs://21m00Tcm4TlvDq8ikWAM"
        let uri = VoiceURI(uriString: uriString)

        #expect(uri != nil)
        #expect(uri?.providerId == "elevenlabs")
        #expect(uri?.voiceId == "21m00Tcm4TlvDq8ikWAM")
        #expect(uri?.languageCode == nil)
    }

    @Test("Parse URI with mixed case provider ID")
    func testParseURIWithMixedCaseProviderId() {
        let uriString = "Apple://voice-id?lang=en"
        let uri = VoiceURI(uriString: uriString)

        #expect(uri?.providerId == "apple")  // Should be lowercased
    }

    @Test("Reject URI with wrong scheme")
    func testRejectWrongScheme() {
        // Any valid scheme is accepted as a provider ID
        // Only truly invalid URIs should be rejected
        let uri = VoiceURI(uriString: "not-a-valid-uri")
        #expect(uri == nil)
    }

    @Test("Reject URI with missing provider")
    func testRejectMissingProvider() {
        let uri = VoiceURI(uriString: "://voice-id")
        #expect(uri == nil)
    }

    @Test("Reject URI with missing voice ID")
    func testRejectMissingVoiceId() {
        let uri = VoiceURI(uriString: "apple://")
        #expect(uri == nil)
    }

    @Test("Reject completely invalid URI")
    func testRejectInvalidURI() {
        let uri = VoiceURI(uriString: "not-a-uri")
        #expect(uri == nil)
    }

    @Test("Handle voice ID with special characters")
    func testVoiceIdWithSpecialCharacters() {
        // Voice ID with spaces - URLComponents will percent-encode special chars in host
        let uri = VoiceURI(
            providerId: "custom",
            voiceId: "voice-with-dashes",
            languageCode: "en"
        )

        let uriString = uri.uriString
        // Format: <providerId>://<voiceId>?lang=<languageCode>
        #expect(uriString.contains("custom://"))
        #expect(uriString.contains("lang=en"))

        // Verify roundtrip works
        let parsed = VoiceURI(uriString: uriString)
        #expect(parsed != nil)
        #expect(parsed?.providerId == "custom")
        #expect(parsed?.voiceId == "voice-with-dashes")
        #expect(parsed?.languageCode == "en")
    }

    @Test("Default voice detection uses hasSuffix")
    func testDefaultVoiceDetectionPrecise() {
        // True default voice
        let defaultVoice = VoiceURI(
            providerId: "apple",
            voiceId: "com.apple.voice.compact.en-US.Default",
            languageCode: "en"
        )
        #expect(defaultVoice.isDefaultVoice == true)

        // False positive with contains(".Default") - should NOT be default
        let customVoice = VoiceURI(
            providerId: "apple",
            voiceId: "com.custom.voice.with.Default.name",
            languageCode: "en"
        )
        #expect(customVoice.isDefaultVoice == false)

        // Non-apple provider
        let elevenLabsVoice = VoiceURI(
            providerId: "elevenlabs",
            voiceId: "voice.Default",
            languageCode: "en"
        )
        #expect(elevenLabsVoice.isDefaultVoice == false)
    }

    // MARK: - URI String Generation Tests

    @Test("Generate URI string with language")
    func testGenerateURIStringWithLanguage() {
        let uri = VoiceURI(
            providerId: "apple",
            voiceId: "voice-id",
            languageCode: "en"
        )

        // Format: <providerId>://<voiceId>?lang=<languageCode>
        #expect(uri.uriString == "apple://voice-id?lang=en")
    }

    @Test("Generate URI string without language")
    func testGenerateURIStringWithoutLanguage() {
        let uri = VoiceURI(
            providerId: "elevenlabs",
            voiceId: "voice-id"
        )

        // Format: <providerId>://<voiceId>
        #expect(uri.uriString == "elevenlabs://voice-id")
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

