//
//  GuionElementSpeakableTests.swift
//  SwiftHablare
//
//  Tests for GuionElement-based SpeakableItem implementations
//

import XCTest
import SwiftCompartido
@testable import SwiftHablare

final class GuionElementSpeakableTests: XCTestCase {

    // MARK: - Test Properties

    var provider: AppleVoiceProvider!
    var voiceId: String!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        provider = AppleVoiceProvider()
        let voices = try await provider.fetchVoices()
        XCTAssertFalse(voices.isEmpty, "No voices available for testing")
        voiceId = voices.first!.id
    }

    // MARK: - GuionElementSpeakable Tests

    func testGuionElementSpeakable_Action() async throws {
        let element = GuionElement(
            elementType: .action,
            elementText: "The sun rises over the mountains."
        )

        let speakable = GuionElementSpeakable(
            element: element,
            voiceProvider: provider,
            voiceId: voiceId
        )

        XCTAssertEqual(speakable.textToSpeak, "The sun rises over the mountains.")
        XCTAssertEqual(speakable.languageCode, "en")

        // Verify it can estimate duration
        let duration = await speakable.estimateDuration()
        XCTAssertGreaterThan(duration, 0)
    }

    func testGuionElementSpeakable_Dialogue() async throws {
        let element = GuionElement(
            elementType: .dialogue,
            elementText: "I can't believe we made it this far."
        )

        let speakable = GuionElementSpeakable(
            element: element,
            voiceProvider: provider,
            voiceId: voiceId
        )

        XCTAssertEqual(speakable.textToSpeak, "I can't believe we made it this far.")
    }

    func testGuionElementSpeakable_SectionHeading() async throws {
        let element = GuionElement(
            elementType: .sectionHeading(level: 2),
            elementText: "Act One"
        )

        let speakable = GuionElementSpeakable(
            element: element,
            voiceProvider: provider,
            voiceId: voiceId
        )

        XCTAssertEqual(speakable.textToSpeak, "Act One")
    }

    func testGuionElementSpeakable_SceneHeading() async throws {
        let element = GuionElement(
            elementType: .sceneHeading,
            elementText: "INT. COFFEE SHOP - DAY"
        )

        let speakable = GuionElementSpeakable(
            element: element,
            voiceProvider: provider,
            voiceId: voiceId
        )

        XCTAssertEqual(speakable.textToSpeak, "INT. COFFEE SHOP - DAY")
    }

    func testGuionElementSpeakable_CustomLanguage() async throws {
        let element = GuionElement(
            elementType: .action,
            elementText: "Hola, mundo!"
        )

        let speakable = GuionElementSpeakable(
            element: element,
            voiceProvider: provider,
            voiceId: voiceId,
            languageCode: "es"
        )

        XCTAssertEqual(speakable.textToSpeak, "Hola, mundo!")
        XCTAssertEqual(speakable.languageCode, "es")
    }

    func testGuionElementSpeakable_EmptyText() async throws {
        let element = GuionElement(
            elementType: .action,
            elementText: ""
        )

        let speakable = GuionElementSpeakable(
            element: element,
            voiceProvider: provider,
            voiceId: voiceId
        )

        XCTAssertEqual(speakable.textToSpeak, "")
        XCTAssertFalse(element.isSpeakable)
    }

    // MARK: - DialoguePairSpeakable Tests

    func testDialoguePairSpeakable_WithoutCharacterName() async throws {
        let character = GuionElement(
            elementType: .character,
            elementText: "JOHN"
        )

        let dialogue = GuionElement(
            elementType: .dialogue,
            elementText: "We need to talk about yesterday."
        )

        let speakable = DialoguePairSpeakable(
            character: character,
            dialogue: dialogue,
            voiceProvider: provider,
            voiceId: voiceId,
            includeCharacterName: false
        )

        XCTAssertEqual(speakable.textToSpeak, "We need to talk about yesterday.")
    }

    func testDialoguePairSpeakable_WithCharacterName() async throws {
        let character = GuionElement(
            elementType: .character,
            elementText: "ALICE"
        )

        let dialogue = GuionElement(
            elementType: .dialogue,
            elementText: "I already told you everything."
        )

        let speakable = DialoguePairSpeakable(
            character: character,
            dialogue: dialogue,
            voiceProvider: provider,
            voiceId: voiceId,
            includeCharacterName: true
        )

        XCTAssertEqual(speakable.textToSpeak, "ALICE: I already told you everything.")
    }

    func testDialoguePairSpeakable_AudioGeneration() async throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Audio generation may be limited on simulator")
        #endif

        let character = GuionElement(
            elementType: .character,
            elementText: "NARRATOR"
        )

        let dialogue = GuionElement(
            elementType: .dialogue,
            elementText: "Test dialogue."
        )

        let speakable = DialoguePairSpeakable(
            character: character,
            dialogue: dialogue,
            voiceProvider: provider,
            voiceId: voiceId,
            includeCharacterName: false
        )

        let audioData = try await speakable.speak()
        XCTAssertGreaterThan(audioData.count, 0)
    }

    // MARK: - SectionHeadingSpeakable Tests

    func testSectionHeadingSpeakable_WithoutAnnouncement() async throws {
        let heading = GuionElement(
            elementType: .sectionHeading(level: 2),
            elementText: "The Beginning"
        )

        let speakable = SectionHeadingSpeakable(
            heading: heading,
            voiceProvider: provider,
            voiceId: voiceId,
            announceLevel: false
        )

        XCTAssertEqual(speakable.textToSpeak, "The Beginning")
    }

    func testSectionHeadingSpeakable_WithAnnouncement_Level1() async throws {
        let heading = GuionElement(
            elementType: .sectionHeading(level: 1),
            elementText: "My Screenplay"
        )

        let speakable = SectionHeadingSpeakable(
            heading: heading,
            voiceProvider: provider,
            voiceId: voiceId,
            announceLevel: true
        )

        XCTAssertEqual(speakable.textToSpeak, "Title: My Screenplay")
    }

    func testSectionHeadingSpeakable_WithAnnouncement_Level2() async throws {
        let heading = GuionElement(
            elementType: .sectionHeading(level: 2),
            elementText: "Act Two"
        )

        let speakable = SectionHeadingSpeakable(
            heading: heading,
            voiceProvider: provider,
            voiceId: voiceId,
            announceLevel: true
        )

        XCTAssertEqual(speakable.textToSpeak, "Act: Act Two")
    }

    func testSectionHeadingSpeakable_WithAnnouncement_Level3() async throws {
        let heading = GuionElement(
            elementType: .sectionHeading(level: 3),
            elementText: "The Chase"
        )

        let speakable = SectionHeadingSpeakable(
            heading: heading,
            voiceProvider: provider,
            voiceId: voiceId,
            announceLevel: true
        )

        XCTAssertEqual(speakable.textToSpeak, "Sequence: The Chase")
    }

    func testSectionHeadingSpeakable_NonHeadingElement() async throws {
        let action = GuionElement(
            elementType: .action,
            elementText: "This is just action text."
        )

        let speakable = SectionHeadingSpeakable(
            heading: action,
            voiceProvider: provider,
            voiceId: voiceId,
            announceLevel: true
        )

        // Should fall back to plain text
        XCTAssertEqual(speakable.textToSpeak, "This is just action text.")
    }

    // MARK: - SceneSpeakable Tests

    func testSceneSpeakable_BasicScene() async throws {
        let sceneHeading = GuionElement(
            elementType: .sceneHeading,
            elementText: "INT. BEDROOM - NIGHT"
        )

        let elements = [
            GuionElement(elementType: .action, elementText: "Alice enters the room."),
            GuionElement(elementType: .character, elementText: "ALICE"),
            GuionElement(elementType: .dialogue, elementText: "Hello?"),
            GuionElement(elementType: .action, elementText: "No response.")
        ]

        let scene = SceneSpeakable(
            sceneHeading: sceneHeading,
            elements: elements,
            voiceMapping: { _ in self.voiceId },
            voiceProvider: provider
        )

        XCTAssertEqual(scene.groupName, "INT. BEDROOM - NIGHT")
        XCTAssertEqual(scene.groupDescription, "4 elements")

        let speakableItems = scene.getGroupedElements()
        XCTAssertEqual(speakableItems.count, 4)
    }

    func testSceneSpeakable_EmptyScene() async throws {
        let sceneHeading = GuionElement(
            elementType: .sceneHeading,
            elementText: "EXT. PARK - DAY"
        )

        let scene = SceneSpeakable(
            sceneHeading: sceneHeading,
            elements: [],
            voiceMapping: { _ in self.voiceId },
            voiceProvider: provider
        )

        XCTAssertEqual(scene.groupName, "EXT. PARK - DAY")
        XCTAssertEqual(scene.groupDescription, "0 elements")

        let speakableItems = scene.getGroupedElements()
        XCTAssertEqual(speakableItems.count, 0)
    }

    func testSceneSpeakable_VoiceMapping() async throws {
        let sceneHeading = GuionElement(
            elementType: .sceneHeading,
            elementText: "INT. OFFICE - DAY"
        )

        let elements = [
            GuionElement(elementType: .character, elementText: "BOSS"),
            GuionElement(elementType: .dialogue, elementText: "You're late."),
            GuionElement(elementType: .character, elementText: "EMPLOYEE"),
            GuionElement(elementType: .dialogue, elementText: "Sorry.")
        ]

        // Map different voices based on element type
        let scene = SceneSpeakable(
            sceneHeading: sceneHeading,
            elements: elements,
            voiceMapping: { element in
                if case .dialogue = element.elementType {
                    return "dialogue-voice"
                }
                return "narrator-voice"
            },
            voiceProvider: provider
        )

        let speakableItems = scene.getGroupedElements() as! [GuionElementSpeakable]
        XCTAssertEqual(speakableItems[1].voiceId, "dialogue-voice")  // Dialogue
        XCTAssertEqual(speakableItems[0].voiceId, "narrator-voice")  // Character
    }

    // MARK: - ChapterSpeakable Tests

    func testChapterSpeakable_WithHeading() async throws {
        let heading = GuionElement(
            elementType: .sectionHeading(level: 2),
            elementText: "Chapter One: The Discovery"
        )

        let elements = [
            GuionElement(elementType: .sceneHeading, elementText: "INT. LAB - DAY"),
            GuionElement(elementType: .action, elementText: "Scientists work frantically."),
            GuionElement(elementType: .character, elementText: "DR. CHEN"),
            GuionElement(elementType: .dialogue, elementText: "We found something.")
        ]

        let chapter = ChapterSpeakable(
            chapterHeading: heading,
            elements: elements,
            voiceMapping: { _ in self.voiceId },
            voiceProvider: provider
        )

        XCTAssertEqual(chapter.groupName, "Chapter One: The Discovery")
        XCTAssertTrue(chapter.groupDescription!.contains("4 elements"))
        XCTAssertTrue(chapter.groupDescription!.contains("1 scenes"))
        XCTAssertTrue(chapter.groupDescription!.contains("1 dialogue"))
    }

    func testChapterSpeakable_WithoutHeading() async throws {
        let elements = [
            GuionElement(elementType: .action, elementText: "Opening scene."),
            GuionElement(elementType: .character, elementText: "NARRATOR"),
            GuionElement(elementType: .dialogue, elementText: "Let me tell you a story.")
        ]

        let chapter = ChapterSpeakable(
            chapterHeading: nil,
            elements: elements,
            voiceMapping: { _ in self.voiceId },
            voiceProvider: provider
        )

        XCTAssertEqual(chapter.groupName, "Chapter")
        XCTAssertTrue(chapter.groupDescription!.contains("3 elements"))
    }

    func testChapterSpeakable_MultipleScenes() async throws {
        let heading = GuionElement(
            elementType: .sectionHeading(level: 2),
            elementText: "Act Two"
        )

        let elements = [
            GuionElement(elementType: .sceneHeading, elementText: "INT. HOUSE - DAY"),
            GuionElement(elementType: .action, elementText: "Action 1"),
            GuionElement(elementType: .sceneHeading, elementText: "EXT. STREET - DAY"),
            GuionElement(elementType: .action, elementText: "Action 2"),
            GuionElement(elementType: .dialogue, elementText: "Line 1"),
            GuionElement(elementType: .sceneHeading, elementText: "INT. CAR - DAY"),
            GuionElement(elementType: .dialogue, elementText: "Line 2")
        ]

        let chapter = ChapterSpeakable(
            chapterHeading: heading,
            elements: elements,
            voiceMapping: { _ in self.voiceId },
            voiceProvider: provider
        )

        XCTAssertEqual(chapter.groupName, "Act Two")
        XCTAssertTrue(chapter.groupDescription!.contains("7 elements"))
        XCTAssertTrue(chapter.groupDescription!.contains("3 scenes"))
        XCTAssertTrue(chapter.groupDescription!.contains("2 dialogue"))
    }

    // MARK: - MarkdownDocumentSpeakable Tests

    func testMarkdownDocumentSpeakable_BasicDocument() async throws {
        let elements = [
            GuionElement(elementType: .sectionHeading(level: 1), elementText: "My Article"),
            GuionElement(elementType: .action, elementText: "Introduction paragraph."),
            GuionElement(elementType: .sectionHeading(level: 2), elementText: "Section One"),
            GuionElement(elementType: .action, elementText: "First section content."),
            GuionElement(elementType: .sectionHeading(level: 2), elementText: "Section Two"),
            GuionElement(elementType: .action, elementText: "Second section content.")
        ]

        let document = MarkdownDocumentSpeakable(
            filename: "article.md",
            elements: elements,
            voiceProvider: provider,
            defaultVoiceId: voiceId
        )

        XCTAssertEqual(document.groupName, "article.md")
        XCTAssertTrue(document.groupDescription!.contains("6 elements"))
        XCTAssertTrue(document.groupDescription!.contains("3 headings"))
        XCTAssertTrue(document.groupDescription!.contains("3 paragraphs"))

        let speakableItems = document.getGroupedElements()
        XCTAssertEqual(speakableItems.count, 6)
    }

    func testMarkdownDocumentSpeakable_EmptyDocument() async throws {
        let document = MarkdownDocumentSpeakable(
            filename: "empty.md",
            elements: [],
            voiceProvider: provider,
            defaultVoiceId: voiceId
        )

        XCTAssertEqual(document.groupName, "empty.md")
        XCTAssertTrue(document.groupDescription!.contains("0 elements"))
        XCTAssertTrue(document.groupDescription!.contains("0 headings"))
        XCTAssertTrue(document.groupDescription!.contains("0 paragraphs"))

        let speakableItems = document.getGroupedElements()
        XCTAssertEqual(speakableItems.count, 0)
    }

    // MARK: - Helper Extension Tests

    func testGuionElement_IsSpeakable() {
        let speakable = GuionElement(
            elementType: .action,
            elementText: "Some text"
        )
        XCTAssertTrue(speakable.isSpeakable)

        let empty = GuionElement(
            elementType: .action,
            elementText: ""
        )
        XCTAssertFalse(empty.isSpeakable)

        let whitespace = GuionElement(
            elementType: .action,
            elementText: "   \n  "
        )
        XCTAssertFalse(whitespace.isSpeakable)
    }

    func testGuionElement_RecommendedVoiceType() {
        let dialogue = GuionElement(elementType: .dialogue, elementText: "Text")
        XCTAssertEqual(dialogue.recommendedVoiceType, .character)

        let character = GuionElement(elementType: .character, elementText: "JOHN")
        XCTAssertEqual(character.recommendedVoiceType, .character)

        let action = GuionElement(elementType: .action, elementText: "Action")
        XCTAssertEqual(action.recommendedVoiceType, .narrator)

        let sceneHeading = GuionElement(elementType: .sceneHeading, elementText: "INT. ROOM")
        XCTAssertEqual(sceneHeading.recommendedVoiceType, .narrator)

        let lyrics = GuionElement(elementType: .lyrics, elementText: "Song lyrics")
        XCTAssertEqual(lyrics.recommendedVoiceType, .character)
    }

    // MARK: - Integration Tests

    func testGuionElementSpeakable_BatchGeneration() async throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Batch audio generation may be limited on simulator")
        #endif

        let elements = [
            GuionElement(elementType: .action, elementText: "First paragraph."),
            GuionElement(elementType: .action, elementText: "Second paragraph."),
            GuionElement(elementType: .action, elementText: "Third paragraph.")
        ]

        let speakableItems = elements.map { element in
            GuionElementSpeakable(
                element: element,
                voiceProvider: provider,
                voiceId: voiceId
            )
        }

        // Test batch generation using Collection extension
        let audioFiles = try await speakableItems.speakAll()
        XCTAssertEqual(audioFiles.count, 3)

        for audioData in audioFiles {
            XCTAssertGreaterThan(audioData.count, 0)
        }
    }

    func testChapterSpeakable_DurationEstimation() async throws {
        let heading = GuionElement(
            elementType: .sectionHeading(level: 2),
            elementText: "Chapter One"
        )

        let elements = [
            GuionElement(elementType: .action, elementText: "A short action."),
            GuionElement(elementType: .dialogue, elementText: "A short line.")
        ]

        let chapter = ChapterSpeakable(
            chapterHeading: heading,
            elements: elements,
            voiceMapping: { _ in self.voiceId },
            voiceProvider: provider
        )

        let speakableItems = chapter.getGroupedElements() as! [GuionElementSpeakable]
        let totalDuration = await speakableItems.estimateTotalDuration()

        XCTAssertGreaterThan(totalDuration, 0)
    }
}
