//
//  CastListPageExtensionsTests.swift
//  SwiftHablare
//
//  Tests for CastListPage extensions with VoiceURI support
//

import Testing
import Foundation
import SwiftCompartido
@testable import SwiftHablare

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

    // MARK: - Import/Export Tests

    @Test("Export voice mappings to dictionary")
    func testExportVoiceMappings() {
        let uri1 = VoiceURI(providerId: "apple", voiceId: "voice-1", languageCode: "en")
        let uri2 = VoiceURI(providerId: "elevenlabs", voiceId: "voice-2", languageCode: "en")

        let castList = CastListPage.fromVoiceMapping(
            title: "Test",
            mapping: [
                "ALICE": uri1,
                "BOB": uri2
            ]
        )

        let exported = castList.exportVoiceMappings()

        #expect(exported.count == 2)
        #expect(exported["ALICE"]?.providerId == "apple")
        #expect(exported["ALICE"]?.voiceId == "voice-1")
        #expect(exported["BOB"]?.providerId == "elevenlabs")
        #expect(exported["BOB"]?.voiceId == "voice-2")
    }

    @Test("Import voice mappings from dictionary")
    func testImportVoiceMappings() {
        let mappings: [String: VoiceURI] = [
            "ALICE": VoiceURI(providerId: "apple", voiceId: "voice-1", languageCode: "en"),
            "BOB": VoiceURI(providerId: "elevenlabs", voiceId: "voice-2", languageCode: "en")
        ]

        let castList = CastListPage.importVoiceMappings(mappings, title: "Imported Cast")

        #expect(castList.title == "Imported Cast")
        #expect(castList.items.count == 2)

        let aliceURI = castList.voiceURI(for: "ALICE")
        let bobURI = castList.voiceURI(for: "BOB")

        #expect(aliceURI.providerId == "apple")
        #expect(aliceURI.voiceId == "voice-1")
        #expect(bobURI.providerId == "elevenlabs")
        #expect(bobURI.voiceId == "voice-2")
    }

    @Test("Export and import roundtrip")
    func testExportImportRoundtrip() {
        let original: [String: VoiceURI] = [
            "ALICE": VoiceURI(providerId: "apple", voiceId: "voice-1", languageCode: "en"),
            "BOB": VoiceURI(providerId: "elevenlabs", voiceId: "voice-2", languageCode: "en"),
            "CHARLIE": VoiceURI(providerId: "apple", voiceId: "voice-3", languageCode: "es")
        ]

        // Export
        let castList = CastListPage.importVoiceMappings(original)

        // Import
        let imported = castList.exportVoiceMappings()

        #expect(imported.count == original.count)
        #expect(imported["ALICE"]?.voiceId == original["ALICE"]?.voiceId)
        #expect(imported["BOB"]?.voiceId == original["BOB"]?.voiceId)
        #expect(imported["CHARLIE"]?.voiceId == original["CHARLIE"]?.voiceId)
    }

    @Test("Export to JSON file")
    func testExportToJSONFile() throws {
        let uri1 = VoiceURI(providerId: "apple", voiceId: "voice-1", languageCode: "en")
        let uri2 = VoiceURI(providerId: "elevenlabs", voiceId: "voice-2", languageCode: "en")

        let castList = CastListPage.fromVoiceMapping(
            title: "Voice Cast",
            mapping: [
                "ALICE": uri1,
                "BOB": uri2
            ]
        )

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test-cast-list.json")

        try castList.exportToJSON(url: tempURL)

        // Verify file was created
        #expect(FileManager.default.fileExists(atPath: tempURL.path))

        // Clean up
        try? FileManager.default.removeItem(at: tempURL)
    }

    @Test("Import from JSON file")
    func testImportFromJSONFile() throws {
        let uri1 = VoiceURI(providerId: "apple", voiceId: "voice-1", languageCode: "en")
        let uri2 = VoiceURI(providerId: "elevenlabs", voiceId: "voice-2", languageCode: "en")

        let original = CastListPage.fromVoiceMapping(
            title: "Voice Cast",
            mapping: [
                "ALICE": uri1,
                "BOB": uri2
            ]
        )

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test-cast-list-import.json")

        // Export
        try original.exportToJSON(url: tempURL)

        // Import
        let imported = try CastListPage.importFromJSON(url: tempURL)

        #expect(imported.title == original.title)
        #expect(imported.items.count == original.items.count)

        let aliceURI = imported.voiceURI(for: "ALICE")
        let bobURI = imported.voiceURI(for: "BOB")

        #expect(aliceURI.providerId == uri1.providerId)
        #expect(aliceURI.voiceId == uri1.voiceId)
        #expect(bobURI.providerId == uri2.providerId)
        #expect(bobURI.voiceId == uri2.voiceId)

        // Clean up
        try? FileManager.default.removeItem(at: tempURL)
    }

    @Test("File roundtrip preserves all data")
    func testFileRoundtrip() throws {
        let mappings: [String: VoiceURI] = [
            "ALICE": VoiceURI(providerId: "apple", voiceId: "voice-1", languageCode: "en"),
            "BOB": VoiceURI(providerId: "elevenlabs", voiceId: "voice-2", languageCode: "en"),
            "CHARLIE": VoiceURI(providerId: "apple", voiceId: "voice-3", languageCode: "es"),
            "DIANA": VoiceURI(providerId: "elevenlabs", voiceId: "voice-4", languageCode: "fr")
        ]

        let original = CastListPage.fromVoiceMapping(
            title: "Multi-Language Cast",
            mapping: mappings
        )

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test-roundtrip.json")

        // Export
        try original.exportToJSON(url: tempURL)

        // Import
        let imported = try CastListPage.importFromJSON(url: tempURL)

        // Export imported mappings
        let importedMappings = imported.exportVoiceMappings()

        #expect(importedMappings.count == mappings.count)
        for (character, uri) in mappings {
            #expect(importedMappings[character]?.providerId == uri.providerId)
            #expect(importedMappings[character]?.voiceId == uri.voiceId)
            #expect(importedMappings[character]?.languageCode == uri.languageCode)
        }

        // Clean up
        try? FileManager.default.removeItem(at: tempURL)
    }

    @Test("Get character roles")
    func testCharacterRoles() {
        let castList = CastListPage.fromVoiceMapping(
            title: "Test",
            mapping: [
                "CHARLIE": VoiceURI(providerId: "apple", voiceId: "voice-3", languageCode: "en"),
                "ALICE": VoiceURI(providerId: "apple", voiceId: "voice-1", languageCode: "en"),
                "BOB": VoiceURI(providerId: "elevenlabs", voiceId: "voice-2", languageCode: "en")
            ]
        )

        let roles = castList.characterRoles

        #expect(roles.count == 3)
        #expect(roles == ["ALICE", "BOB", "CHARLIE"])  // Should be sorted
    }

    @Test("Provider summary")
    func testProviderSummary() {
        let castList = CastListPage.fromVoiceMapping(
            title: "Test",
            mapping: [
                "ALICE": VoiceURI(providerId: "apple", voiceId: "voice-1", languageCode: "en"),
                "BOB": VoiceURI(providerId: "apple", voiceId: "voice-2", languageCode: "en"),
                "CHARLIE": VoiceURI(providerId: "apple", voiceId: "voice-3", languageCode: "en"),
                "DIANA": VoiceURI(providerId: "elevenlabs", voiceId: "voice-4", languageCode: "en"),
                "EVE": VoiceURI(providerId: "elevenlabs", voiceId: "voice-5", languageCode: "en")
            ]
        )

        let summary = castList.providerSummary()

        #expect(summary["apple"] == 3)
        #expect(summary["elevenlabs"] == 2)
    }

    @Test("Export handles empty cast list")
    func testExportEmptyCastList() {
        let castList = CastListPage(title: "Empty", position: 0)

        let mappings = castList.exportVoiceMappings()

        #expect(mappings.isEmpty)
    }

    @Test("Export ignores invalid URIs")
    func testExportIgnoresInvalidURIs() {
        var castList = CastListPage(title: "Test", position: 0)

        // Add valid URI
        castList.addMember(role: "ALICE", name: "hablare://apple/voice-1?lang=en")

        // Add invalid URI
        castList.addMember(role: "BOB", name: "invalid-uri")

        let mappings = castList.exportVoiceMappings()

        #expect(mappings.count == 1)  // Only ALICE should be exported
        #expect(mappings["ALICE"] != nil)
        #expect(mappings["BOB"] == nil)
    }
}
