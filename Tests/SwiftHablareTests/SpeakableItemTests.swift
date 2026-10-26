//
//  SpeakableItemTests.swift
//  SwiftHablareTests
//
//  Tests for SpeakableItem protocol and implementations
//

import Foundation
import Testing

@testable import SwiftHablare
@testable import SwiftHablareTesting

// MARK: - Test Fixtures

struct SpeakableItemTestFixtures {
  let registry: PluginRegistry
  let voice: VoiceReference

  static func create() async -> Self? {
    SpeakableItemTestFixtures(
      registry: TestFixtures.makeFakeRegistry(), voice: TestFixtures.fakeVoice)
  }
}

// MARK: - SimpleMessage Tests

@Suite("SimpleMessage Tests")
struct SimpleMessageTests {
  var fixtures: SpeakableItemTestFixtures?

  init() async {
    fixtures = await SpeakableItemTestFixtures.create()
  }

  @Test("Conformance to SpeakableItem")
  func conformance() {
    guard let fixtures = fixtures else {
      Issue.record("Fake registry unavailable.")
      return
    }
    let message = SimpleMessage(
      content: "Hello, world!",
      voice: fixtures.voice
    )

    #expect(message.textToSpeak == "Hello, world!")
    #expect(message.voice == fixtures.voice)
    #expect(message.languageCode == systemLanguageCode())
  }

  @Test("Speech generation")
  func speak() async throws {
    guard let fixtures = fixtures else {
      Issue.record("Fake registry unavailable.")
      return
    }
    let message = SimpleMessage(
      content: "Testing speech generation",
      voice: fixtures.voice
    )

    let audioData = try await message.speak(using: fixtures.registry)
    #expect(audioData.data.count > 0)
  }

  @Test("Duration of generated audio")
  func generatedDuration() async throws {
    guard let fixtures = fixtures else {
      Issue.record("Fake registry unavailable.")
      return
    }
    let message = SimpleMessage(
      content: "This is a test message",
      voice: fixtures.voice
    )

    let audio = try await message.speak(using: fixtures.registry)
    #expect(audio.duration > 0)
    #expect(audio.format == FakeAudio.format)
  }

  @Test("Voice availability check")
  func isVoiceAvailable() async throws {
    guard let fixtures = fixtures else {
      Issue.record("Fake registry unavailable.")
      return
    }
    let message = SimpleMessage(content: "Test", voice: fixtures.voice)

    #expect(await message.isVoiceAvailable(in: fixtures.registry))

    let unknown = SimpleMessage(
      content: "Test", voice: .catalog(pluginId: "no-such-plugin", voiceId: "x"))
    #expect(await unknown.isVoiceAvailable(in: fixtures.registry) == false)
  }
}

// MARK: - CharacterDialogue Tests

@Suite("CharacterDialogue Tests")
struct CharacterDialogueTests {
  var fixtures: SpeakableItemTestFixtures?

  init() async {
    fixtures = await SpeakableItemTestFixtures.create()
  }

  @Test("Dialogue with character name")
  func withCharacterName() {
    guard let fixtures = fixtures else {
      Issue.record("Fake registry unavailable.")
      return
    }
    let dialogue = CharacterDialogue(
      characterName: "Alice",
      dialogue: "Hello!",
      voice: fixtures.voice,
      includeCharacterName: true
    )

    #expect(dialogue.textToSpeak == "Alice: Hello!")
  }

  @Test("Dialogue without character name")
  func withoutCharacterName() {
    guard let fixtures = fixtures else {
      Issue.record("Fake registry unavailable.")
      return
    }
    let dialogue = CharacterDialogue(
      characterName: "Alice",
      dialogue: "Hello!",
      voice: fixtures.voice,
      includeCharacterName: false
    )

    #expect(dialogue.textToSpeak == "Hello!")
  }

  @Test("Dialogue speech generation")
  func speak() async throws {
    guard let fixtures = fixtures else {
      Issue.record("Fake registry unavailable.")
      return
    }
    let dialogue = CharacterDialogue(
      characterName: "Bob",
      dialogue: "Testing dialogue speech",
      voice: fixtures.voice
    )

    let audioData = try await dialogue.speak(using: fixtures.registry)
    #expect(audioData.data.count > 0)
  }
}

// MARK: - Article Tests

@Suite("Article Tests")
struct ArticleTests {
  var fixtures: SpeakableItemTestFixtures?

  init() async {
    fixtures = await SpeakableItemTestFixtures.create()
  }

  @Test("Article with metadata")
  func withMeta() {
    guard let fixtures = fixtures else {
      Issue.record("Fake registry unavailable.")
      return
    }
    let article = Article(
      title: "Breaking News",
      author: "Jane Doe",
      content: "This is the article content.",
      voice: fixtures.voice,
      includeMeta: true
    )

    #expect(article.textToSpeak == "Breaking News, by Jane Doe. This is the article content.")
  }

  @Test("Article without metadata")
  func withoutMeta() {
    guard let fixtures = fixtures else {
      Issue.record("Fake registry unavailable.")
      return
    }
    let article = Article(
      title: "Breaking News",
      author: "Jane Doe",
      content: "This is the article content.",
      voice: fixtures.voice,
      includeMeta: false
    )

    #expect(article.textToSpeak == "This is the article content.")
  }

  @Test("Article speech generation")
  func speak() async throws {
    guard let fixtures = fixtures else {
      Issue.record("Fake registry unavailable.")
      return
    }
    let article = Article(
      title: "Test Article",
      author: "Test Author",
      content: "Test content",
      voice: fixtures.voice
    )

    let audioData = try await article.speak(using: fixtures.registry)
    #expect(audioData.data.count > 0)
  }
}

// MARK: - Notification Tests

@Suite("Notification Tests")
struct NotificationTests {
  var fixtures: SpeakableItemTestFixtures?

  init() async {
    fixtures = await SpeakableItemTestFixtures.create()
  }

  @Test("Notification with timestamp")
  func withTimestamp() {
    guard let fixtures = fixtures else {
      Issue.record("Fake registry unavailable.")
      return
    }
    let timestamp = Date(timeIntervalSince1970: 1_609_459_200)  // 2021-01-01 00:00:00 UTC
    let notification = Notification(
      title: "New Message",
      message: "You have mail",
      timestamp: timestamp,
      voice: fixtures.voice,
      includeTimestamp: true
    )

    #expect(notification.textToSpeak.contains("New Message"))
    #expect(notification.textToSpeak.contains("You have mail"))
    #expect(notification.textToSpeak.contains(" at "))
  }

  @Test("Notification without timestamp")
  func withoutTimestamp() {
    guard let fixtures = fixtures else {
      Issue.record("Fake registry unavailable.")
      return
    }
    let notification = Notification(
      title: "Alert",
      message: "Something happened",
      voice: fixtures.voice,
      includeTimestamp: false
    )

    #expect(notification.textToSpeak == "Alert. Something happened")
  }

  @Test("Notification speech generation")
  func speak() async throws {
    guard let fixtures = fixtures else {
      Issue.record("Fake registry unavailable.")
      return
    }
    let notification = Notification(
      title: "Test",
      message: "Test message",
      voice: fixtures.voice
    )

    let audioData = try await notification.speak(using: fixtures.registry)
    #expect(audioData.data.count > 0)
  }
}

// MARK: - ListItem Tests

@Suite("ListItem Tests")
struct ListItemTests {
  var fixtures: SpeakableItemTestFixtures?

  init() async {
    fixtures = await SpeakableItemTestFixtures.create()
  }

  @Test("List item formatting")
  func formatting() {
    guard let fixtures = fixtures else {
      Issue.record("Fake registry unavailable.")
      return
    }
    let item = ListItem(
      number: 5,
      content: "Mix ingredients",
      voice: fixtures.voice
    )

    #expect(item.textToSpeak == "Step 5: Mix ingredients")
  }

  @Test("List item speech generation")
  func speak() async throws {
    guard let fixtures = fixtures else {
      Issue.record("Fake registry unavailable.")
      return
    }
    let item = ListItem(
      number: 1,
      content: "Test step",
      voice: fixtures.voice
    )

    let audioData = try await item.speak(using: fixtures.registry)
    #expect(audioData.data.count > 0)
  }
}

// MARK: - Batch Operations Tests

@Suite("Batch Operations Tests")
struct BatchOperationsTests {
  var fixtures: SpeakableItemTestFixtures?

  init() async {
    fixtures = await SpeakableItemTestFixtures.create()
  }

  @Test("Speak all items")
  func speakAll() async throws {
    guard let fixtures = fixtures else {
      Issue.record("Fake registry unavailable.")
      return
    }
    let items: [SimpleMessage] = [
      SimpleMessage(content: "First", voice: fixtures.voice),
      SimpleMessage(content: "Second", voice: fixtures.voice),
      SimpleMessage(content: "Third", voice: fixtures.voice),
    ]

    let audioFiles = try await items.speakAll(using: fixtures.registry)
    #expect(audioFiles.count == 3)
    for audio in audioFiles {
      #expect(audio.data.count > 0)
    }
  }

  @Test("Total duration of generated audio")
  func estimateTotalDuration() async throws {
    guard let fixtures = fixtures else {
      Issue.record("Fake registry unavailable.")
      return
    }
    let items: [SimpleMessage] = [
      SimpleMessage(content: "Short", voice: fixtures.voice),
      SimpleMessage(content: "Medium length message", voice: fixtures.voice),
      SimpleMessage(content: "A longer message with more words to speak", voice: fixtures.voice),
    ]

    let audioFiles = try await items.speakAll(using: fixtures.registry)
    let totalDuration = audioFiles.reduce(0) { $0 + $1.duration }
    #expect(totalDuration > 0)

    // Verify it's the sum of individual durations
    var expectedTotal: TimeInterval = 0
    for item in items {
      expectedTotal += try await item.speak(using: fixtures.registry).duration
    }
    #expect(abs(totalDuration - expectedTotal) < 0.01)
  }

  @Test("Empty collection speak all")
  func emptyCollectionSpeakAll() async throws {
    let items: [SimpleMessage] = []
    let audioFiles = try await items.speakAll(using: TestFixtures.makeFakeRegistry())
    #expect(audioFiles.isEmpty)
  }

  @Test("Empty collection estimate total duration")
  func emptyCollectionEstimateTotalDuration() async throws {
    let items: [SimpleMessage] = []
    let registry = TestFixtures.makeFakeRegistry()
    let audioFiles = try await items.speakAll(using: registry)
    #expect(audioFiles.reduce(0) { $0 + $1.duration } == 0)
  }
}

// MARK: - Error Handling Tests

@Suite("Error Handling Tests")
struct ErrorHandlingTests {
  var fixtures: SpeakableItemTestFixtures?

  init() async {
    fixtures = await SpeakableItemTestFixtures.create()
  }

  @Test("Speak with invalid voice ID")
  func speakWithInvalidVoiceId() async throws {
    guard let fixtures = fixtures else {
      Issue.record("Fake registry unavailable.")
      return
    }
    // A catalog voice naming a plugin that is not registered cannot be resolved.
    let message = SimpleMessage(
      content: "Test",
      voice: .catalog(pluginId: "no-such-plugin", voiceId: "invalid-voice-id")
    )

    await #expect(throws: HablareError.self) {
      try await message.speak(using: fixtures.registry)
    }
  }

  @Test("Speak with an asset voice and no plugin id throws error")
  func speakAssetWithoutPluginIdThrowsError() async throws {
    guard let fixtures = fixtures else {
      Issue.record("Fake registry unavailable.")
      return
    }
    let message = SimpleMessage(
      content: "Test",
      voice: .asset(URL(fileURLWithPath: "/tmp/narrator.vox"))
    )

    await #expect(throws: HablareError.self) {
      try await message.speak(using: fixtures.registry)
    }

    // With the plugin named, the same item speaks.
    let audio = try await message.speak(
      using: fixtures.registry, pluginId: FakeSynthesizerPlugin.id)
    #expect(audio.data.count > 0)
  }

  @Test("Synthesizer failure propagates from speak")
  func synthesizerFailurePropagates() async throws {
    guard let fixtures = fixtures else {
      Issue.record("Fake registry unavailable.")
      return
    }
    let message = SimpleMessage(content: "", voice: fixtures.voice)
    let plugin = try await fixtures.registry.plugin(id: FakeSynthesizerPlugin.id)
    (plugin as? FakeSynthesizerPlugin)?.failNextCall(with: .invalidRequest(detail: "empty text"))

    await #expect(throws: HablareError.self) {
      try await message.speak(using: fixtures.registry)
    }
  }
}

// MARK: - Custom Implementation Tests

@Suite("Custom Implementation Tests")
struct CustomImplementationTests {
  var fixtures: SpeakableItemTestFixtures?

  init() async {
    fixtures = await SpeakableItemTestFixtures.create()
  }

  @Test("Custom speakable item")
  func customSpeakableItem() async throws {
    guard let fixtures = fixtures else {
      Issue.record("Fake registry unavailable.")
      return
    }
    // Test a custom implementation
    struct CustomItem: SpeakableItem {
      let voice: VoiceReference
      let prefix: String
      let suffix: String

      var textToSpeak: String {
        "\(prefix) - \(suffix)"
      }
    }

    let custom = CustomItem(
      voice: fixtures.voice,
      prefix: "Hello",
      suffix: "World"
    )

    #expect(custom.textToSpeak == "Hello - World")
    let audioData = try await custom.speak(using: fixtures.registry)
    #expect(audioData.data.count > 0)
  }
}
