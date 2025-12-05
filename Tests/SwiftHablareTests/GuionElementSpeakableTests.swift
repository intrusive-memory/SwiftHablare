//
//  GuionElementSpeakableTests.swift
//  SwiftHablare
//
//  Tests for GuionElement-based SpeakableItem implementations
//

import Testing
import SwiftCompartido
@testable import SwiftHablare

@Suite
struct GuionElementSpeakableTests {

    // MARK: - Test Properties

    let provider: AppleVoiceProvider
    let voiceId: String

    // MARK: - Initialization

    @MainActor
    init() async throws {
        provider = TestFixtures.makeAppleProvider()
        let voices = try await provider.fetchVoices()
        #expect(!voices.isEmpty)
        voiceId = voices.first!.id
    }

    // MARK: - GuionElementSpeakable Tests

    @Test
    func guionElementSpeakable_Action() async throws {
        let element = GuionElement(
            elementType: .action,
            elementText: "The sun rises over the mountains."
        )

        let speakable = GuionElementSpeakable(
            element: element,
            voiceProvider: provider,
            voiceId: voiceId
        )

        #expect(speakable.textToSpeak == "The sun rises over the mountains.")
        #expect(speakable.languageCode == "en")

        // Verify it can estimate duration
        let duration = await speakable.estimateDuration()
        #expect(duration > 0)
    }

    @Test
    func guionElementSpeakable_Dialogue() async throws {
        let element = GuionElement(
            elementType: .dialogue,
            elementText: "I can't believe we made it this far."
        )

        let speakable = GuionElementSpeakable(
            element: element,
            voiceProvider: provider,
            voiceId: voiceId
        )

        #expect(speakable.textToSpeak == "I can't believe we made it this far.")
    }

    @Test
    func guionElementSpeakable_SectionHeading() async throws {
        let element = GuionElement(
            elementType: .sectionHeading(level: 2),
            elementText: "Act One"
        )

        let speakable = GuionElementSpeakable(
            element: element,
            voiceProvider: provider,
            voiceId: voiceId
        )

        #expect(speakable.textToSpeak == "Act One")
    }

    @Test
    func guionElementSpeakable_SceneHeading() async throws {
        let element = GuionElement(
            elementType: .sceneHeading,
            elementText: "INT. COFFEE SHOP - DAY"
        )

        let speakable = GuionElementSpeakable(
            element: element,
            voiceProvider: provider,
            voiceId: voiceId
        )

        #expect(speakable.textToSpeak == "INT. COFFEE SHOP - DAY")
    }

    @Test
    func guionElementSpeakable_CustomLanguage() async throws {
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

        #expect(speakable.textToSpeak == "Hola, mundo!")
        #expect(speakable.languageCode == "es")
    }

    @Test
    func guionElementSpeakable_EmptyText() async throws {
        let element = GuionElement(
            elementType: .action,
            elementText: ""
        )

        let speakable = GuionElementSpeakable(
            element: element,
            voiceProvider: provider,
            voiceId: voiceId
        )

        #expect(speakable.textToSpeak == "")
        #expect(!element.isSpeakable)
    }

    // MARK: - DialoguePairSpeakable Tests

    @Test
    func dialoguePairSpeakable_WithoutCharacterName() async throws {
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

        #expect(speakable.textToSpeak == "We need to talk about yesterday.")
    }

    @Test
    func dialoguePairSpeakable_WithCharacterName() async throws {
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

        #expect(speakable.textToSpeak == "ALICE: I already told you everything.")
    }

    @Test
    func dialoguePairSpeakable_AudioGeneration() async throws {
        #if targetEnvironment(simulator)
        throw Skip( "Audio generation may be limited on simulator")
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
        #expect(audioData.count > 0)
    }

    // MARK: - SectionHeadingSpeakable Tests

    @Test
    func sectionHeadingSpeakable_WithoutAnnouncement() async throws {
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

        #expect(speakable.textToSpeak == "The Beginning")
    }

    @Test
    func sectionHeadingSpeakable_WithAnnouncement_Level1() async throws {
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

        #expect(speakable.textToSpeak == "Title: My Screenplay")
    }

    @Test
    func sectionHeadingSpeakable_WithAnnouncement_Level2() async throws {
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

        #expect(speakable.textToSpeak == "Act: Act Two")
    }

    @Test
    func sectionHeadingSpeakable_WithAnnouncement_Level3() async throws {
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

        #expect(speakable.textToSpeak == "Sequence: The Chase")
    }

    @Test
    func sectionHeadingSpeakable_NonHeadingElement() async throws {
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
        #expect(speakable.textToSpeak == "This is just action text.")
    }

    // MARK: - SceneSpeakable Tests

    @Test
    func sceneSpeakable_BasicScene() async throws {
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

        #expect(scene.groupName == "INT. BEDROOM - NIGHT")
        #expect(scene.groupDescription == "4 elements")

        let speakableItems = scene.getGroupedElements()
        #expect(speakableItems.count == 4)
    }

    @Test
    func sceneSpeakable_EmptyScene() async throws {
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

        #expect(scene.groupName == "EXT. PARK - DAY")
        #expect(scene.groupDescription == "0 elements")

        let speakableItems = scene.getGroupedElements()
        #expect(speakableItems.count == 0)
    }

    @Test
    func sceneSpeakable_VoiceMapping() async throws {
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
        #expect(speakableItems[1].voiceId == "dialogue-voice")  // Dialogue
        #expect(speakableItems[0].voiceId == "narrator-voice")  // Character
    }

    // MARK: - ChapterSpeakable Tests

    @Test
    func chapterSpeakable_WithHeading() async throws {
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

        #expect(chapter.groupName == "Chapter One: The Discovery")
        #expect(chapter.groupDescription!.contains("4 elements"))
        #expect(chapter.groupDescription!.contains("1 scenes"))
        #expect(chapter.groupDescription!.contains("1 dialogue"))
    }

    @Test
    func chapterSpeakable_WithoutHeading() async throws {
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

        #expect(chapter.groupName == "Chapter")
        #expect(chapter.groupDescription!.contains("3 elements"))
    }

    @Test
    func chapterSpeakable_MultipleScenes() async throws {
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

        #expect(chapter.groupName == "Act Two")
        #expect(chapter.groupDescription!.contains("7 elements"))
        #expect(chapter.groupDescription!.contains("3 scenes"))
        #expect(chapter.groupDescription!.contains("2 dialogue"))
    }

    // MARK: - MarkdownDocumentSpeakable Tests

    @Test
    func markdownDocumentSpeakable_BasicDocument() async throws {
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

        #expect(document.groupName == "article.md")
        #expect(document.groupDescription!.contains("6 elements"))
        #expect(document.groupDescription!.contains("3 headings"))
        #expect(document.groupDescription!.contains("3 paragraphs"))

        let speakableItems = document.getGroupedElements()
        #expect(speakableItems.count == 6)
    }

    @Test
    func markdownDocumentSpeakable_EmptyDocument() async throws {
        let document = MarkdownDocumentSpeakable(
            filename: "empty.md",
            elements: [],
            voiceProvider: provider,
            defaultVoiceId: voiceId
        )

        #expect(document.groupName == "empty.md")
        #expect(document.groupDescription!.contains("0 elements"))
        #expect(document.groupDescription!.contains("0 headings"))
        #expect(document.groupDescription!.contains("0 paragraphs"))

        let speakableItems = document.getGroupedElements()
        #expect(speakableItems.count == 0)
    }

    // MARK: - Helper Extension Tests

    @Test
    func guionElement_IsSpeakable() {
        let speakable = GuionElement(
            elementType: .action,
            elementText: "Some text"
        )
        #expect(speakable.isSpeakable)

        let empty = GuionElement(
            elementType: .action,
            elementText: ""
        )
        #expect(!empty.isSpeakable)

        let whitespace = GuionElement(
            elementType: .action,
            elementText: "   \n  "
        )
        #expect(!whitespace.isSpeakable)
    }

    @Test
    func guionElement_RecommendedVoiceType() {
        let dialogue = GuionElement(elementType: .dialogue, elementText: "Text")
        #expect(dialogue.recommendedVoiceType == .character)

        let character = GuionElement(elementType: .character, elementText: "JOHN")
        #expect(character.recommendedVoiceType == .character)

        let action = GuionElement(elementType: .action, elementText: "Action")
        #expect(action.recommendedVoiceType == .narrator)

        let sceneHeading = GuionElement(elementType: .sceneHeading, elementText: "INT. ROOM")
        #expect(sceneHeading.recommendedVoiceType == .narrator)

        let lyrics = GuionElement(elementType: .lyrics, elementText: "Song lyrics")
        #expect(lyrics.recommendedVoiceType == .character)
    }

    // MARK: - Integration Tests

    @Test
    func guionElementSpeakable_BatchGeneration() async throws {
        #if targetEnvironment(simulator)
        throw Skip( "Batch audio generation may be limited on simulator")
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
        #expect(audioFiles.count == 3)

        for audioData in audioFiles {
            #expect(audioData.count > 0)
        }
    }

    @Test
    func chapterSpeakable_DurationEstimation() async throws {
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

        #expect(totalDuration > 0)
    }
}
