//
//  VoiceModelTests.swift
//  SwiftHablareTests
//
//  Comprehensive tests for Voice model
//

import Testing
import Foundation
@testable import SwiftHablare

@Suite("Voice Model Tests")
struct VoiceModelTests {

    // MARK: - Initialization Tests

    @Test("Voice initialization with all parameters")
    func initializationWithAllParameters() {
        let voice = Voice(
            id: "voice123",
            name: "Rachel",
            description: "A friendly voice",
            providerId: "elevenlabs",
            language: "en",
            locality: "US",
            gender: "female"
        )

        #expect(voice.id == "voice123")
        #expect(voice.name == "Rachel")
        #expect(voice.description == "A friendly voice")
        #expect(voice.providerId == "elevenlabs")
        #expect(voice.language == "en")
        #expect(voice.locality == "US")
        #expect(voice.gender == "female")
    }

    @Test("Voice initialization with minimal parameters")
    func initializationWithMinimalParameters() {
        let voice = Voice(
            id: "voice123",
            name: "Rachel",
            description: nil
        )

        #expect(voice.id == "voice123")
        #expect(voice.name == "Rachel")
        #expect(voice.description == nil)
        #expect(voice.providerId == "elevenlabs")
        #expect(voice.language == nil)
        #expect(voice.locality == nil)
        #expect(voice.gender == nil)
    }

    @Test("Voice initialization with custom provider")
    func initializationWithCustomProvider() {
        let voice = Voice(
            id: "voice123",
            name: "Samantha",
            description: "Apple voice",
            providerId: "apple"
        )

        #expect(voice.providerId == "apple")
    }

    // MARK: - Identifiable Protocol Tests

    @Test("Voice conforms to Identifiable")
    func conformsToIdentifiable() {
        let voice = Voice(id: "voice123", name: "Test", description: nil)

        // Identifiable protocol provides id property
        #expect(voice.id == "voice123")
    }

    @Test("Voices with same id have same identifier")
    func voicesWithSameIdAreEqual() {
        let voice1 = Voice(id: "voice123", name: "Rachel", description: nil)
        let voice2 = Voice(id: "voice123", name: "Different Name", description: nil)

        // For Identifiable, id is the unique identifier
        #expect(voice1.id == voice2.id)
    }

    @Test("Voices with different ids have different identifiers")
    func voicesWithDifferentIdsAreNotEqual() {
        let voice1 = Voice(id: "voice1", name: "Rachel", description: nil)
        let voice2 = Voice(id: "voice2", name: "Rachel", description: nil)

        #expect(voice1.id != voice2.id)
    }

    // MARK: - Codable Tests

    @Test("Voice encoding with all properties")
    func encodingWithAllProperties() throws {
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
        #expect(json.contains("\"voice_id\":\"voice123\""))
        #expect(json.contains("\"name\":\"Rachel\""))
        #expect(json.contains("\"description\":\"A friendly voice\""))
        #expect(json.contains("\"language\":\"en\""))
        #expect(json.contains("\"locality\":\"US\""))
        #expect(json.contains("\"gender\":\"female\""))
    }

    @Test("Voice decoding with all properties")
    func decodingWithAllProperties() throws {
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

        #expect(voice.id == "voice123")
        #expect(voice.name == "Rachel")
        #expect(voice.description == "A friendly voice")
        #expect(voice.providerId == "elevenlabs")
        #expect(voice.language == "en")
        #expect(voice.locality == "US")
        #expect(voice.gender == "female")
    }

    @Test("Voice decoding with minimal properties")
    func decodingWithMinimalProperties() throws {
        let json = """
        {
            "voice_id": "voice123",
            "name": "Rachel"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let voice = try decoder.decode(Voice.self, from: json)

        #expect(voice.id == "voice123")
        #expect(voice.name == "Rachel")
        #expect(voice.description == nil)
        #expect(voice.language == nil)
        #expect(voice.locality == nil)
        #expect(voice.gender == nil)
    }

    @Test("Voice encoding and decoding round trip")
    func encodingAndDecodingRoundTrip() throws {
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

        #expect(decodedVoice.id == originalVoice.id)
        #expect(decodedVoice.name == originalVoice.name)
        #expect(decodedVoice.description == originalVoice.description)
        #expect(decodedVoice.language == originalVoice.language)
        #expect(decodedVoice.locality == originalVoice.locality)
        #expect(decodedVoice.gender == originalVoice.gender)
    }

    @Test("Voice array encoding and decoding")
    func arrayEncoding() throws {
        let voices = [
            Voice(id: "voice1", name: "Rachel", description: "Voice 1"),
            Voice(id: "voice2", name: "Adam", description: "Voice 2"),
            Voice(id: "voice3", name: "Maria", description: "Voice 3")
        ]

        let encoder = JSONEncoder()
        let data = try encoder.encode(voices)

        let decoder = JSONDecoder()
        let decodedVoices = try decoder.decode([Voice].self, from: data)

        #expect(decodedVoices.count == 3)
        #expect(decodedVoices[0].id == "voice1")
        #expect(decodedVoices[1].id == "voice2")
        #expect(decodedVoices[2].id == "voice3")
    }

    // MARK: - Sendable Protocol Tests

    @Test("Voice is Sendable")
    func isSendable() {
        // Voice should be Sendable for thread-safe passing
        let voice = Voice(id: "voice123", name: "Test", description: nil)

        // This should compile without warnings
        Task {
            let _ = voice
        }
    }

    // MARK: - Coding Keys Tests

    @Test("Coding keys mapping from voice_id to id")
    func codingKeysMapping() throws {
        // Verify that voice_id is properly mapped to id
        let json = """
        {
            "voice_id": "test123",
            "name": "Test Voice"
        }
        """.data(using: .utf8)!

        let voice = try JSONDecoder().decode(Voice.self, from: json)

        #expect(voice.id == "test123")
    }

    @Test("Encoding uses voice_id key")
    func encodingUsesVoiceIdKey() throws {
        let voice = Voice(id: "test123", name: "Test Voice", description: nil)

        let data = try JSONEncoder().encode(voice)
        let json = String(data: data, encoding: .utf8)!

        #expect(json.contains("\"voice_id\""))
        #expect(!json.contains("\"id\""))
    }

    // MARK: - Edge Case Tests

    @Test("Voice with empty strings")
    func withEmptyStrings() {
        let voice = Voice(
            id: "",
            name: "",
            description: "",
            providerId: "",
            language: "",
            locality: "",
            gender: ""
        )

        #expect(voice.id == "")
        #expect(voice.name == "")
        #expect(voice.description == "")
        #expect(voice.providerId == "")
        #expect(voice.language == "")
        #expect(voice.locality == "")
        #expect(voice.gender == "")
    }

    @Test("Voice with very long strings")
    func withVeryLongStrings() {
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

        #expect(voice.id.count == 1000)
        #expect(voice.name.count == 1000)
        #expect(voice.description?.count == 1000)
    }

    @Test("Voice with special characters")
    func withSpecialCharacters() {
        let voice = Voice(
            id: "voice-123_test",
            name: "Rachel's Voice",
            description: "A \"friendly\" voice with special chars: @#$%",
            providerId: "provider.test",
            language: "en-US",
            locality: "US-CA",
            gender: "female/neutral"
        )

        #expect(voice.id == "voice-123_test")
        #expect(voice.name == "Rachel's Voice")
        #expect(voice.description?.contains("@#$%") == true)
    }

    @Test("Voice with Unicode characters")
    func withUnicodeCharacters() {
        let voice = Voice(
            id: "voice123",
            name: "María José 🎤",
            description: "Una voz amigable",
            providerId: "elevenlabs",
            language: "es",
            locality: "MX",
            gender: "female"
        )

        #expect(voice.name == "María José 🎤")
        #expect(voice.description == "Una voz amigable")
    }

    // MARK: - Property Mutation Tests

    @Test("Provider ID can be mutated")
    func providerIdCanBeMutated() {
        var voice = Voice(id: "voice123", name: "Test", description: nil)

        #expect(voice.providerId == "elevenlabs")

        voice.providerId = "apple"

        #expect(voice.providerId == "apple")
    }

    @Test("Language can be mutated")
    func languageCanBeMutated() {
        var voice = Voice(id: "voice123", name: "Test", description: nil)

        #expect(voice.language == nil)

        voice.language = "en"

        #expect(voice.language == "en")
    }

    @Test("Locality can be mutated")
    func localityCanBeMutated() {
        var voice = Voice(id: "voice123", name: "Test", description: nil)

        #expect(voice.locality == nil)

        voice.locality = "US"

        #expect(voice.locality == "US")
    }

    @Test("Gender can be mutated")
    func genderCanBeMutated() {
        var voice = Voice(id: "voice123", name: "Test", description: nil)

        #expect(voice.gender == nil)

        voice.gender = "female"

        #expect(voice.gender == "female")
    }

    // MARK: - Collection Operations Tests

    @Test("Filtering voices by gender")
    func filteringVoicesByGender() {
        let voices = [
            Voice(id: "v1", name: "Rachel", description: nil, gender: "female"),
            Voice(id: "v2", name: "Adam", description: nil, gender: "male"),
            Voice(id: "v3", name: "Maria", description: nil, gender: "female"),
            Voice(id: "v4", name: "Unknown", description: nil, gender: nil)
        ]

        let femaleVoices = voices.filter { $0.gender == "female" }

        #expect(femaleVoices.count == 2)
        #expect(femaleVoices.allSatisfy { $0.gender == "female" })
    }

    @Test("Filtering voices by language")
    func filteringVoicesByLanguage() {
        let voices = [
            Voice(id: "v1", name: "Rachel", description: nil, language: "en"),
            Voice(id: "v2", name: "Maria", description: nil, language: "es"),
            Voice(id: "v3", name: "Pierre", description: nil, language: "fr"),
            Voice(id: "v4", name: "John", description: nil, language: "en")
        ]

        let englishVoices = voices.filter { $0.language == "en" }

        #expect(englishVoices.count == 2)
    }

    @Test("Sorting voices by name")
    func sortingVoicesByName() {
        let voices = [
            Voice(id: "v1", name: "Zoe", description: nil),
            Voice(id: "v2", name: "Adam", description: nil),
            Voice(id: "v3", name: "Maria", description: nil)
        ]

        let sortedVoices = voices.sorted { $0.name < $1.name }

        #expect(sortedVoices[0].name == "Adam")
        #expect(sortedVoices[1].name == "Maria")
        #expect(sortedVoices[2].name == "Zoe")
    }

    @Test("Grouping voices by provider")
    func groupingVoicesByProvider() {
        let voices = [
            Voice(id: "v1", name: "Rachel", description: nil, providerId: "elevenlabs"),
            Voice(id: "v2", name: "Samantha", description: nil, providerId: "apple"),
            Voice(id: "v3", name: "Adam", description: nil, providerId: "elevenlabs"),
            Voice(id: "v4", name: "Alex", description: nil, providerId: "apple")
        ]

        let grouped = Dictionary(grouping: voices, by: { $0.providerId })

        #expect(grouped.keys.count == 2)
        #expect(grouped["elevenlabs"]?.count == 2)
        #expect(grouped["apple"]?.count == 2)
    }

    // MARK: - JSON Compatibility Tests

    @Test("Decoding ElevenLabs API response")
    func decodingElevenLabsAPIResponse() throws {
        // Simulate actual ElevenLabs API response format
        let json = """
        {
            "voice_id": "21m00Tcm4TlvDq8ikWAM",
            "name": "Rachel",
            "description": "A mature female voice with an American accent"
        }
        """.data(using: .utf8)!

        let voice = try JSONDecoder().decode(Voice.self, from: json)

        #expect(voice.id == "21m00Tcm4TlvDq8ikWAM")
        #expect(voice.name == "Rachel")
        #expect(voice.description != nil)
    }

    @Test("Decoding array of voices")
    func decodingArrayOfVoices() throws {
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

        #expect(voices.count == 2)
        #expect(voices[0].id == "voice1")
        #expect(voices[1].id == "voice2")
        #expect(voices[1].gender == "male")
    }
}
