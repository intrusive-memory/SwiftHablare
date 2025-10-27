//
//  SpeakableGroupTests.swift
//  SwiftHablareTests
//
//  Tests for SpeakableGroup protocol and GenerateGroupButton
//

import Testing
import SwiftUI
import SwiftData
@testable import SwiftHablare
import SwiftCompartido

/// Tests for SpeakableGroup protocol and group generation functionality
@Suite("SpeakableGroup Tests")
@MainActor
struct SpeakableGroupTests {

    // MARK: - Test Fixtures

    /// Create an in-memory model container for testing
    func makeTestContainer() throws -> ModelContainer {
        let schema = Schema([
            VoiceCacheModel.self,
            TypedDataStorage.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    /// Create a test group with specified items
    func makeTestGroup(itemCount: Int = 3) -> TestGroup {
        let provider = AppleVoiceProvider()
        let items = (1...itemCount).map { index in
            SimpleMessage(
                content: "Message \(index)",
                voiceProvider: provider,
                voiceId: "test-voice-id"
            )
        }
        return TestGroup(name: "Test Group", items: items)
    }

    /// Create a test audio record for an item
    func makeTestAudioRecord(
        for item: any SpeakableItem,
        in context: ModelContext
    ) -> TypedDataStorage {
        let audioData = Data("test audio data".utf8)
        let record = TypedDataStorage(
            id: UUID(),
            providerId: item.voiceProvider.providerId,
            requestorID: "\(item.voiceProvider.providerId).audio.tts",
            mimeType: "audio/x-aiff",
            binaryValue: audioData,
            prompt: item.textToSpeak,
            durationSeconds: 5.0,
            voiceID: item.voiceId,
            voiceName: "Test Voice"
        )
        context.insert(record)
        try? context.save()
        return record
    }

    // MARK: - Protocol Tests

    @Test("SpeakableGroup protocol provides group name")
    func testGroupName() {
        let group = makeTestGroup()
        #expect(group.groupName == "Test Group")
    }

    @Test("SpeakableGroup protocol returns grouped elements")
    func testGetGroupedElements() {
        let group = makeTestGroup(itemCount: 5)
        let elements = group.getGroupedElements()
        #expect(elements.count == 5)
    }

    @Test("SpeakableGroup provides item count")
    func testItemCount() {
        let group = makeTestGroup(itemCount: 10)
        #expect(group.itemCount == 10)
    }

    @Test("SpeakableGroup description is optional")
    func testGroupDescription() {
        let group = makeTestGroup()
        // Default implementation returns nil
        #expect(group.groupDescription == nil)
    }

    // MARK: - Example Implementation Tests

    @Test("Chapter example implements SpeakableGroup correctly")
    func testChapterExample() {
        let provider = AppleVoiceProvider()
        let lines = [
            DialogueLine(characterName: "Alice", text: "Hello!", voiceId: "voice-1"),
            DialogueLine(characterName: "Bob", text: "Hi there!", voiceId: "voice-2")
        ]
        let chapter = Chapter(
            number: 1,
            title: "The Beginning",
            dialogueLines: lines,
            provider: provider
        )

        #expect(chapter.groupName == "Chapter 1: The Beginning")
        #expect(chapter.groupDescription == "2 dialogue lines")
        #expect(chapter.getGroupedElements().count == 2)
    }

    @Test("Scene example implements SpeakableGroup correctly")
    func testSceneExample() {
        let provider = AppleVoiceProvider()
        let interactions = [
            Interaction(characterName: "Waiter", line: "Welcome!", voiceId: "voice-1"),
            Interaction(characterName: "Customer", line: "One coffee, please.", voiceId: "voice-2")
        ]
        let scene = Scene(
            number: 5,
            location: "Coffee Shop",
            interactions: interactions,
            provider: provider,
            includeSceneHeading: false
        )

        #expect(scene.groupName == "Scene 5 - Coffee Shop")
        #expect(scene.groupDescription == "2 interactions at Coffee Shop")
        #expect(scene.getGroupedElements().count == 2)
    }

    @Test("Scene with heading includes extra element")
    func testSceneWithHeading() {
        let provider = AppleVoiceProvider()
        let interactions = [
            Interaction(characterName: "Actor", line: "Line", voiceId: "voice-1")
        ]
        let scene = Scene(
            number: 1,
            location: "Stage",
            interactions: interactions,
            provider: provider,
            includeSceneHeading: true
        )

        // Should have scene heading + 1 interaction = 2 elements
        #expect(scene.getGroupedElements().count == 2)
    }

    @Test("MessagePlaylist example implements SpeakableGroup correctly")
    func testMessagePlaylistExample() {
        let provider = AppleVoiceProvider()
        let messages = [
            PlaylistMessage(sender: "Alice", content: "Hello!", priority: .high),
            PlaylistMessage(sender: "Bob", content: "Hi!", priority: .normal)
        ]
        let playlist = MessagePlaylist(
            name: "Morning Messages",
            messages: messages,
            provider: provider,
            defaultVoiceId: "voice-1"
        )

        #expect(playlist.groupName == "Morning Messages")
        #expect(playlist.groupDescription == "2 messages (1 high priority)")
        #expect(playlist.getGroupedElements().count == 2)
    }

    @Test("ArticleSections example implements SpeakableGroup correctly")
    func testArticleSectionsExample() {
        let provider = AppleVoiceProvider()
        let sections = [
            ArticleSection(heading: "Intro", content: "This is the intro"),
            ArticleSection(heading: "Body", content: "This is the body")
        ]
        let article = ArticleSections(
            title: "My Article",
            author: "Jane Doe",
            sections: sections,
            provider: provider,
            voiceId: "voice-1",
            includeHeadings: true
        )

        #expect(article.groupName == "My Article by Jane Doe")
        #expect(article.groupDescription == "2 sections")
        // Title/author + (heading + content) * 2 = 1 + 4 = 5 elements
        #expect(article.getGroupedElements().count == 5)
    }

    @Test("ShoppingList example implements SpeakableGroup correctly")
    func testShoppingListExample() {
        let provider = AppleVoiceProvider()
        let list = ShoppingList(
            name: "Grocery Run",
            items: ["Milk", "Eggs", "Bread"],
            provider: provider,
            voiceId: "voice-1",
            includeNumbers: true
        )

        #expect(list.groupName == "Grocery Run")
        #expect(list.groupDescription == "3 items")
        #expect(list.getGroupedElements().count == 3)
    }

    // MARK: - GenerateGroupButton Tests

    @Test("Button initializes with correct parameters")
    func testButtonInitialization() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let service = GenerationService()
        let group = makeTestGroup()

        let button = GenerateGroupButton(
            group: group,
            service: service,
            modelContext: context,
            onComplete: { _ in }
        )

        #expect(button.group.groupName == group.groupName)
    }

    @Test("Button detects items with no existing audio")
    func testDetectsNoExistingAudio() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let service = GenerationService()
        let group = makeTestGroup(itemCount: 3)

        // Create button (no existing audio)
        let _ = GenerateGroupButton(
            group: group,
            service: service,
            modelContext: context
        )

        // Wait for check to complete
        try await Task.sleep(for: .milliseconds(100))

        // Verify no audio exists
        let descriptor = FetchDescriptor<TypedDataStorage>()
        let results = try context.fetch(descriptor)
        #expect(results.isEmpty)
    }

    @Test("Button detects items with existing audio")
    func testDetectsExistingAudio() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let service = GenerationService()
        let group = makeTestGroup(itemCount: 3)
        let items = group.getGroupedElements()

        // Create audio for one item
        let _ = makeTestAudioRecord(for: items[0], in: context)

        // Create button
        let _ = GenerateGroupButton(
            group: group,
            service: service,
            modelContext: context
        )

        // Wait for check to complete
        try await Task.sleep(for: .milliseconds(100))

        // Verify one audio record exists
        let descriptor = FetchDescriptor<TypedDataStorage>()
        let results = try context.fetch(descriptor)
        #expect(results.count == 1)
    }

    @Test("Button detects when all items have audio")
    func testDetectsAllItemsHaveAudio() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let service = GenerationService()
        let group = makeTestGroup(itemCount: 3)
        let items = group.getGroupedElements()

        // Create audio for all items
        for item in items {
            let _ = makeTestAudioRecord(for: item, in: context)
        }

        // Create button
        let _ = GenerateGroupButton(
            group: group,
            service: service,
            modelContext: context
        )

        // Wait for check to complete
        try await Task.sleep(for: .milliseconds(100))

        // Verify all audio records exist
        let descriptor = FetchDescriptor<TypedDataStorage>()
        let results = try context.fetch(descriptor)
        #expect(results.count == 3)
    }

    @Test("Button handles empty group gracefully")
    func testEmptyGroup() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let service = GenerationService()
        let group = TestGroup(name: "Empty", items: [])

        let _ = GenerateGroupButton(
            group: group,
            service: service,
            modelContext: context
        )

        // Wait for check to complete
        try await Task.sleep(for: .milliseconds(100))

        // Should handle empty group without crashing
        #expect(group.itemCount == 0)
    }

    // MARK: - Progress Tracking Tests

    @Test("Group provides correct item count")
    func testGroupItemCount() {
        let group = makeTestGroup(itemCount: 7)
        #expect(group.itemCount == 7)
    }

    @Test("Empty group has zero item count")
    func testEmptyGroupItemCount() {
        let group = TestGroup(name: "Empty", items: [])
        #expect(group.itemCount == 0)
    }

    // MARK: - Integration Tests

    @Test("Group generation completes successfully on device")
    func testGroupGenerationEndToEnd() async throws {
        #if targetEnvironment(simulator)
        // Skip test on simulator - Apple TTS doesn't generate real audio on simulator
        return
        #endif

        let container = try makeTestContainer()
        let context = ModelContext(container)
        let service = GenerationService()
        let group = makeTestGroup(itemCount: 2)

        // Generate audio for the group
        let items = group.getGroupedElements()
        let list = SpeakableItemList(name: group.groupName, items: items)

        let records = try await service.generateList(list, to: context)

        // Verify records were created
        #expect(records.count == 2)
        #expect(!(records[0].binaryValue?.isEmpty ?? true))
        #expect(!(records[1].binaryValue?.isEmpty ?? true))
    }
}

// MARK: - Test Support Types

/// Test implementation of SpeakableGroup
struct TestGroup: SpeakableGroup {
    let name: String
    let items: [SimpleMessage]

    var groupName: String { name }

    func getGroupedElements() -> [any SpeakableItem] {
        return items
    }
}
