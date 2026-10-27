//
//  SpeakableGroupTests.swift
//  SwiftHablareTests
//
//  Tests for the SpeakableGroup protocol
//

import Foundation
import SwiftCompartido
import SwiftData
import Testing

@testable import SwiftHablare

/// Tests for SpeakableGroup protocol and group generation functionality
@Suite("SpeakableGroup Tests")
@MainActor
struct SpeakableGroupTests {

  // MARK: - Test Fixtures

  /// Create an in-memory model container for testing
  func makeTestContainer() throws -> ModelContainer {
    let schema = Schema([
      TypedDataStorage.self
    ])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(for: schema, configurations: [config])
  }

  /// Create a test group with specified items
  func makeTestGroup(itemCount: Int = 3) -> TestGroup {
    let items = (1...itemCount).map { index in
      SimpleMessage(
        content: "Message \(index)",
        voice: .catalog(pluginId: "apple", voiceId: "test-voice-id")
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
    var providerId = "asset"
    var voiceId = ""
    if case .catalog(let pluginId, let catalogVoiceId) = item.voice {
      providerId = pluginId
      voiceId = catalogVoiceId
    }
    let record = TypedDataStorage(
      id: UUID(),
      providerId: providerId,
      requestorID: "\(providerId).audio.tts",
      mimeType: "audio/x-aiff",
      binaryValue: audioData,
      prompt: item.textToSpeak,
      durationSeconds: 5.0,
      voiceID: voiceId,
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
    let pluginId = "apple"
    let lines = [
      DialogueLine(characterName: "Alice", text: "Hello!", voiceId: "voice-1"),
      DialogueLine(characterName: "Bob", text: "Hi there!", voiceId: "voice-2"),
    ]
    let chapter = Chapter(
      number: 1,
      title: "The Beginning",
      dialogueLines: lines,
      pluginId: pluginId
    )

    #expect(chapter.groupName == "Chapter 1: The Beginning")
    #expect(chapter.groupDescription == "2 dialogue lines")
    #expect(chapter.getGroupedElements().count == 2)
  }

  @Test("Scene example implements SpeakableGroup correctly")
  func testSceneExample() {
    let pluginId = "apple"
    let interactions = [
      Interaction(characterName: "Waiter", line: "Welcome!", voiceId: "voice-1"),
      Interaction(characterName: "Customer", line: "One coffee, please.", voiceId: "voice-2"),
    ]
    let scene = Scene(
      number: 5,
      location: "Coffee Shop",
      interactions: interactions,
      pluginId: pluginId,
      includeSceneHeading: false
    )

    #expect(scene.groupName == "Scene 5 - Coffee Shop")
    #expect(scene.groupDescription == "2 interactions at Coffee Shop")
    #expect(scene.getGroupedElements().count == 2)
  }

  @Test("Scene with heading includes extra element")
  func testSceneWithHeading() {
    let pluginId = "apple"
    let interactions = [
      Interaction(characterName: "Actor", line: "Line", voiceId: "voice-1")
    ]
    let scene = Scene(
      number: 1,
      location: "Stage",
      interactions: interactions,
      pluginId: pluginId,
      includeSceneHeading: true
    )

    // Should have scene heading + 1 interaction = 2 elements
    #expect(scene.getGroupedElements().count == 2)
  }

  @Test("MessagePlaylist example implements SpeakableGroup correctly")
  func testMessagePlaylistExample() {
    let pluginId = "apple"
    let messages = [
      PlaylistMessage(sender: "Alice", content: "Hello!", priority: .high),
      PlaylistMessage(sender: "Bob", content: "Hi!", priority: .normal),
    ]
    let playlist = MessagePlaylist(
      name: "Morning Messages",
      messages: messages,
      pluginId: pluginId,
      defaultVoiceId: "voice-1"
    )

    #expect(playlist.groupName == "Morning Messages")
    #expect(playlist.groupDescription == "2 messages (1 high priority)")
    #expect(playlist.getGroupedElements().count == 2)
  }

  @Test("ArticleSections example implements SpeakableGroup correctly")
  func testArticleSectionsExample() {
    let pluginId = "apple"
    let sections = [
      ArticleSection(heading: "Intro", content: "This is the intro"),
      ArticleSection(heading: "Body", content: "This is the body"),
    ]
    let article = ArticleSections(
      title: "My Article",
      author: "Jane Doe",
      sections: sections,
      pluginId: pluginId,
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
    let pluginId = "apple"
    let list = ShoppingList(
      name: "Grocery Run",
      items: ["Milk", "Eggs", "Bread"],
      pluginId: pluginId,
      voiceId: "voice-1",
      includeNumbers: true
    )

    #expect(list.groupName == "Grocery Run")
    #expect(list.groupDescription == "3 items")
    #expect(list.getGroupedElements().count == 3)
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

  @Test("Group generation completes through the plugin registry")
  func testGroupGenerationEndToEnd() async throws {
    let container = try makeTestContainer()
    let context = ModelContext(container)
    let service = GenerationService(registry: TestFixtures.makeFakeRegistry())

    let items = (1...2).map { index in
      SimpleMessage(content: "Message \(index)", voice: TestFixtures.fakeVoice)
    }
    let group = TestGroup(name: "Test Group", items: items)

    // Generate audio for the group
    let list = SpeakableItemList(name: group.groupName, items: group.getGroupedElements())
    let records = try await service.generateList(list, to: context)

    // Verify records were created
    #expect(records.count == 2)
    #expect(records.map(\.prompt) == ["Message 1", "Message 2"])
    #expect(!(records[0].binaryValue?.isEmpty ?? true))
    #expect(!(records[1].binaryValue?.isEmpty ?? true))
    #expect(records.allSatisfy { $0.mimeType == AudioFormat.pcm24kMono16.mimeType })
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
