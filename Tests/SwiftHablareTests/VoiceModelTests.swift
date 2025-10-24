//
//  VoiceModelTests.swift
//  SwiftHablareTests
//
//  Comprehensive tests for Voice model
//

import XCTest
@testable import SwiftHablare

final class VoiceModelTests: XCTestCase {

    // MARK: - Initialization Tests

    func testVoiceInitializationWithAllParameters() {
        let voice = Voice(
            id: "voice123",
            name: "Rachel",
            description: "A friendly voice",
            providerId: "elevenlabs",
            language: "en",
            locality: "US",
            gender: "female"
        )

        XCTAssertEqual(voice.id, "voice123")
        XCTAssertEqual(voice.name, "Rachel")
        XCTAssertEqual(voice.description, "A friendly voice")
        XCTAssertEqual(voice.providerId, "elevenlabs")
        XCTAssertEqual(voice.language, "en")
        XCTAssertEqual(voice.locality, "US")
        XCTAssertEqual(voice.gender, "female")
    }

    func testVoiceInitializationWithMinimalParameters() {
        let voice = Voice(
            id: "voice123",
            name: "Rachel",
            description: nil
        )

        XCTAssertEqual(voice.id, "voice123")
        XCTAssertEqual(voice.name, "Rachel")
        XCTAssertNil(voice.description)
        XCTAssertEqual(voice.providerId, "elevenlabs", "Default provider should be elevenlabs")
        XCTAssertNil(voice.language)
        XCTAssertNil(voice.locality)
        XCTAssertNil(voice.gender)
    }

    func testVoiceInitializationWithCustomProvider() {
        let voice = Voice(
            id: "voice123",
            name: "Samantha",
            description: "Apple voice",
            providerId: "apple"
        )

        XCTAssertEqual(voice.providerId, "apple")
    }

    // MARK: - Identifiable Protocol Tests

    func testVoiceConformsToIdentifiable() {
        let voice = Voice(id: "voice123", name: "Test", description: nil)

        // Identifiable protocol provides id property
        XCTAssertEqual(voice.id, "voice123")
    }

    func testVoicesWithSameIdAreEqual() {
        let voice1 = Voice(id: "voice123", name: "Rachel", description: nil)
        let voice2 = Voice(id: "voice123", name: "Different Name", description: nil)

        // For Identifiable, id is the unique identifier
        XCTAssertEqual(voice1.id, voice2.id)
    }

    func testVoicesWithDifferentIdsAreNotEqual() {
        let voice1 = Voice(id: "voice1", name: "Rachel", description: nil)
        let voice2 = Voice(id: "voice2", name: "Rachel", description: nil)

        XCTAssertNotEqual(voice1.id, voice2.id)
    }

    // MARK: - Codable Tests

    func testVoiceEncodingWithAllProperties() throws {
        let voice = Voice(
            id: "voice123",
            name: "Rachel",
            description: "A friendly voice",
            providerId: "elevenlabs",
            language: "en",
            locality: "US",
            gender: "female"
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys

        let data = try encoder.encode(voice)
        let json = String(data: data, encoding: .utf8)!

        // Verify JSON contains expected fields (using voice_id instead of id)
        XCTAssertTrue(json.contains("\"voice_id\":\"voice123\""))
        XCTAssertTrue(json.contains("\"name\":\"Rachel\""))
        XCTAssertTrue(json.contains("\"description\":\"A friendly voice\""))
        XCTAssertTrue(json.contains("\"language\":\"en\""))
        XCTAssertTrue(json.contains("\"locality\":\"US\""))
        XCTAssertTrue(json.contains("\"gender\":\"female\""))
    }

    func testVoiceDecodingWithAllProperties() throws {
        let json = """
        {
            "voice_id": "voice123",
            "name": "Rachel",
            "description": "A friendly voice",
            "language": "en",
            "locality": "US",
            "gender": "female"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let voice = try decoder.decode(Voice.self, from: json)

        XCTAssertEqual(voice.id, "voice123")
        XCTAssertEqual(voice.name, "Rachel")
        XCTAssertEqual(voice.description, "A friendly voice")
        XCTAssertEqual(voice.providerId, "elevenlabs", "Decoded voices should default to elevenlabs")
        XCTAssertEqual(voice.language, "en")
        XCTAssertEqual(voice.locality, "US")
        XCTAssertEqual(voice.gender, "female")
    }

    func testVoiceDecodingWithMinimalProperties() throws {
        let json = """
        {
            "voice_id": "voice123",
            "name": "Rachel"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let voice = try decoder.decode(Voice.self, from: json)

        XCTAssertEqual(voice.id, "voice123")
        XCTAssertEqual(voice.name, "Rachel")
        XCTAssertNil(voice.description)
        XCTAssertNil(voice.language)
        XCTAssertNil(voice.locality)
        XCTAssertNil(voice.gender)
    }

    func testVoiceEncodingAndDecodingRoundTrip() throws {
        let originalVoice = Voice(
            id: "voice123",
            name: "Rachel",
            description: "A friendly voice",
            providerId: "elevenlabs",
            language: "en",
            locality: "US",
            gender: "female"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(originalVoice)

        let decoder = JSONDecoder()
        let decodedVoice = try decoder.decode(Voice.self, from: data)

        XCTAssertEqual(decodedVoice.id, originalVoice.id)
        XCTAssertEqual(decodedVoice.name, originalVoice.name)
        XCTAssertEqual(decodedVoice.description, originalVoice.description)
        XCTAssertEqual(decodedVoice.language, originalVoice.language)
        XCTAssertEqual(decodedVoice.locality, originalVoice.locality)
        XCTAssertEqual(decodedVoice.gender, originalVoice.gender)
    }

    func testVoiceArrayEncoding() throws {
        let voices = [
            Voice(id: "voice1", name: "Rachel", description: "Voice 1"),
            Voice(id: "voice2", name: "Adam", description: "Voice 2"),
            Voice(id: "voice3", name: "Maria", description: "Voice 3")
        ]

        let encoder = JSONEncoder()
        let data = try encoder.encode(voices)

        let decoder = JSONDecoder()
        let decodedVoices = try decoder.decode([Voice].self, from: data)

        XCTAssertEqual(decodedVoices.count, 3)
        XCTAssertEqual(decodedVoices[0].id, "voice1")
        XCTAssertEqual(decodedVoices[1].id, "voice2")
        XCTAssertEqual(decodedVoices[2].id, "voice3")
    }

    // MARK: - Sendable Protocol Tests

    func testVoiceIsSendable() {
        // Voice should be Sendable for thread-safe passing
        let voice = Voice(id: "voice123", name: "Test", description: nil)

        // This should compile without warnings
        Task {
            let _ = voice
        }
    }

    // MARK: - Coding Keys Tests

    func testCodingKeysMapping() throws {
        // Verify that voice_id is properly mapped to id
        let json = """
        {
            "voice_id": "test123",
            "name": "Test Voice"
        }
        """.data(using: .utf8)!

        let voice = try JSONDecoder().decode(Voice.self, from: json)

        XCTAssertEqual(voice.id, "test123")
    }

    func testEncodingUsesVoiceIdKey() throws {
        let voice = Voice(id: "test123", name: "Test Voice", description: nil)

        let data = try JSONEncoder().encode(voice)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("\"voice_id\""), "Should encode id as voice_id")
        XCTAssertFalse(json.contains("\"id\""), "Should not encode id as id")
    }

    // MARK: - Edge Case Tests

    func testVoiceWithEmptyStrings() {
        let voice = Voice(
            id: "",
            name: "",
            description: "",
            providerId: "",
            language: "",
            locality: "",
            gender: ""
        )

        XCTAssertEqual(voice.id, "")
        XCTAssertEqual(voice.name, "")
        XCTAssertEqual(voice.description, "")
        XCTAssertEqual(voice.providerId, "")
        XCTAssertEqual(voice.language, "")
        XCTAssertEqual(voice.locality, "")
        XCTAssertEqual(voice.gender, "")
    }

    func testVoiceWithVeryLongStrings() {
        let longString = String(repeating: "a", count: 1000)

        let voice = Voice(
            id: longString,
            name: longString,
            description: longString,
            providerId: longString,
            language: longString,
            locality: longString,
            gender: longString
        )

        XCTAssertEqual(voice.id.count, 1000)
        XCTAssertEqual(voice.name.count, 1000)
        XCTAssertEqual(voice.description?.count, 1000)
    }

    func testVoiceWithSpecialCharacters() {
        let voice = Voice(
            id: "voice-123_test",
            name: "Rachel's Voice",
            description: "A \"friendly\" voice with special chars: @#$%",
            providerId: "provider.test",
            language: "en-US",
            locality: "US-CA",
            gender: "female/neutral"
        )

        XCTAssertEqual(voice.id, "voice-123_test")
        XCTAssertEqual(voice.name, "Rachel's Voice")
        XCTAssertTrue(voice.description!.contains("@#$%"))
    }

    func testVoiceWithUnicodeCharacters() {
        let voice = Voice(
            id: "voice123",
            name: "María José 🎤",
            description: "Una voz amigable",
            providerId: "elevenlabs",
            language: "es",
            locality: "MX",
            gender: "female"
        )

        XCTAssertEqual(voice.name, "María José 🎤")
        XCTAssertEqual(voice.description, "Una voz amigable")
    }

    // MARK: - Property Mutation Tests

    func testProviderIdCanBeMutated() {
        var voice = Voice(id: "voice123", name: "Test", description: nil)

        XCTAssertEqual(voice.providerId, "elevenlabs")

        voice.providerId = "apple"

        XCTAssertEqual(voice.providerId, "apple")
    }

    func testLanguageCanBeMutated() {
        var voice = Voice(id: "voice123", name: "Test", description: nil)

        XCTAssertNil(voice.language)

        voice.language = "en"

        XCTAssertEqual(voice.language, "en")
    }

    func testLocalityCanBeMutated() {
        var voice = Voice(id: "voice123", name: "Test", description: nil)

        XCTAssertNil(voice.locality)

        voice.locality = "US"

        XCTAssertEqual(voice.locality, "US")
    }

    func testGenderCanBeMutated() {
        var voice = Voice(id: "voice123", name: "Test", description: nil)

        XCTAssertNil(voice.gender)

        voice.gender = "female"

        XCTAssertEqual(voice.gender, "female")
    }

    // MARK: - Collection Operations Tests

    func testFilteringVoicesByGender() {
        let voices = [
            Voice(id: "v1", name: "Rachel", description: nil, gender: "female"),
            Voice(id: "v2", name: "Adam", description: nil, gender: "male"),
            Voice(id: "v3", name: "Maria", description: nil, gender: "female"),
            Voice(id: "v4", name: "Unknown", description: nil, gender: nil)
        ]

        let femaleVoices = voices.filter { $0.gender == "female" }

        XCTAssertEqual(femaleVoices.count, 2)
        XCTAssertTrue(femaleVoices.allSatisfy { $0.gender == "female" })
    }

    func testFilteringVoicesByLanguage() {
        let voices = [
            Voice(id: "v1", name: "Rachel", description: nil, language: "en"),
            Voice(id: "v2", name: "Maria", description: nil, language: "es"),
            Voice(id: "v3", name: "Pierre", description: nil, language: "fr"),
            Voice(id: "v4", name: "John", description: nil, language: "en")
        ]

        let englishVoices = voices.filter { $0.language == "en" }

        XCTAssertEqual(englishVoices.count, 2)
    }

    func testSortingVoicesByName() {
        let voices = [
            Voice(id: "v1", name: "Zoe", description: nil),
            Voice(id: "v2", name: "Adam", description: nil),
            Voice(id: "v3", name: "Maria", description: nil)
        ]

        let sortedVoices = voices.sorted { $0.name < $1.name }

        XCTAssertEqual(sortedVoices[0].name, "Adam")
        XCTAssertEqual(sortedVoices[1].name, "Maria")
        XCTAssertEqual(sortedVoices[2].name, "Zoe")
    }

    func testGroupingVoicesByProvider() {
        let voices = [
            Voice(id: "v1", name: "Rachel", description: nil, providerId: "elevenlabs"),
            Voice(id: "v2", name: "Samantha", description: nil, providerId: "apple"),
            Voice(id: "v3", name: "Adam", description: nil, providerId: "elevenlabs"),
            Voice(id: "v4", name: "Alex", description: nil, providerId: "apple")
        ]

        let grouped = Dictionary(grouping: voices, by: { $0.providerId })

        XCTAssertEqual(grouped.keys.count, 2)
        XCTAssertEqual(grouped["elevenlabs"]?.count, 2)
        XCTAssertEqual(grouped["apple"]?.count, 2)
    }

    // MARK: - JSON Compatibility Tests

    func testDecodingElevenLabsAPIResponse() throws {
        // Simulate actual ElevenLabs API response format
        let json = """
        {
            "voice_id": "21m00Tcm4TlvDq8ikWAM",
            "name": "Rachel",
            "description": "A mature female voice with an American accent"
        }
        """.data(using: .utf8)!

        let voice = try JSONDecoder().decode(Voice.self, from: json)

        XCTAssertEqual(voice.id, "21m00Tcm4TlvDq8ikWAM")
        XCTAssertEqual(voice.name, "Rachel")
        XCTAssertNotNil(voice.description)
    }

    func testDecodingArrayOfVoices() throws {
        let json = """
        [
            {
                "voice_id": "voice1",
                "name": "Rachel"
            },
            {
                "voice_id": "voice2",
                "name": "Adam",
                "gender": "male"
            }
        ]
        """.data(using: .utf8)!

        let voices = try JSONDecoder().decode([Voice].self, from: json)

        XCTAssertEqual(voices.count, 2)
        XCTAssertEqual(voices[0].id, "voice1")
        XCTAssertEqual(voices[1].id, "voice2")
        XCTAssertEqual(voices[1].gender, "male")
    }
}
