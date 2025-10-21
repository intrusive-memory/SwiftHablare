import XCTest
import SwiftData
@testable import SwiftHablare

@MainActor
final class SpeakableAudioTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() async throws {
        container = try ModelContainer(
            for: SpeakableItem.self, SpeakableAudio.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = ModelContext(container)
    }

    func testSpeakableAudioCreation() throws {
        // GIVEN
        let hablareID = UUID()
        let audio = SpeakableAudio(
            hablareAudioID: hablareID,
            providerName: "ElevenLabs",
            voiceID: "voice-123",
            voiceName: "Emma",
            audioFormat: "mp3",
            characterCount: 100
        )

        // WHEN
        context.insert(audio)
        try context.save()

        // THEN
        XCTAssertNotNil(audio.id)
        XCTAssertEqual(audio.hablareAudioID, hablareID)
        XCTAssertEqual(audio.providerName, "ElevenLabs")
        XCTAssertEqual(audio.voiceID, "voice-123")
        XCTAssertTrue(audio.isActive)
    }

    func testSpeakableAudioRelationship() throws {
        // GIVEN
        let item = SpeakableItem(
            orderIndex: 0,
            screenplayID: "test-screenplay",
            sourceElementID: "s1",
            sourceElementType: "Dialogue",
            speakableText: "Test",
            ruleVersion: "1.0"
        )

        let audio = SpeakableAudio(
            hablareAudioID: UUID(),
            providerName: "Apple",
            voiceID: "Samantha",
            audioFormat: "aac",
            characterCount: 50
        )

        // WHEN
        item.audioVersions.append(audio)
        context.insert(item)
        context.insert(audio)
        try context.save()

        // THEN
        XCTAssertEqual(item.audioVersions.count, 1)
        XCTAssertEqual(item.audioVersions[0].id, audio.id)
        XCTAssertNotNil(audio.speakableItem)
        XCTAssertEqual(audio.speakableItem?.id, item.id)
    }

    func testMultipleAudioVersions() throws {
        // GIVEN
        let item = SpeakableItem(
            orderIndex: 0,
            screenplayID: "test-screenplay",
            sourceElementID: "s1",
            sourceElementType: "Dialogue",
            speakableText: "Test",
            ruleVersion: "1.0"
        )

        let audio1 = SpeakableAudio(hablareAudioID: UUID(), providerName: "ElevenLabs", voiceID: "v1", audioFormat: "mp3", characterCount: 50)
        let audio2 = SpeakableAudio(hablareAudioID: UUID(), providerName: "Apple", voiceID: "v2", audioFormat: "aac", characterCount: 50)

        // WHEN
        item.audioVersions.append(audio1)
        item.audioVersions.append(audio2)
        audio1.isActive = true
        audio2.isActive = false

        context.insert(item)
        try context.save()

        // THEN
        XCTAssertEqual(item.audioVersions.count, 2)
        let activeAudio = item.audioVersions.first { $0.isActive }
        XCTAssertNotNil(activeAudio)
        XCTAssertEqual(activeAudio?.providerName, "ElevenLabs")
    }

    func testCascadeDelete() throws {
        // GIVEN
        let item = SpeakableItem(orderIndex: 0, screenplayID: "test-screenplay", sourceElementID: "s1", sourceElementType: "Dialogue", speakableText: "Test", ruleVersion: "1.0")
        let audio = SpeakableAudio(hablareAudioID: UUID(), providerName: "Apple", voiceID: "v1", audioFormat: "aac", characterCount: 50)

        item.audioVersions.append(audio)
        context.insert(item)
        try context.save()

        let audioID = audio.id

        // WHEN - Delete item
        context.delete(item)
        try context.save()

        // THEN - Audio should be deleted too
        let descriptor = FetchDescriptor<SpeakableAudio>(
            predicate: #Predicate { $0.id == audioID }
        )
        let found = try context.fetch(descriptor)
        XCTAssertTrue(found.isEmpty)
    }
}
