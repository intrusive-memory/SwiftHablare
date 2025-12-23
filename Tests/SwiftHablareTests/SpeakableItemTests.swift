//
//  SpeakableItemTests.swift
//  SwiftHablareTests
//
//  Tests for SpeakableItem protocol and implementations
//

import Foundation
import Testing
@testable import SwiftHablare

// MARK: - Test Fixtures

struct SpeakableItemTestFixtures {
    let provider: AppleVoiceProvider
    let voiceId: String

    static func create() async -> Self? {
        let provider = AppleVoiceProvider()
        do {
            let voices = try await provider.fetchVoices()

            // Check if voices are available (GitHub Actions runners may not have TTS voices)
            guard let voiceId = voices.first?.id else {
                return nil
            }

            return SpeakableItemTestFixtures(provider: provider, voiceId: voiceId)
        } catch {
            return nil
        }
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
            Issue.record("No Apple TTS voices available. Skipping test.")
            return
        }
        let message = SimpleMessage(
            content: "Hello, world!",
            voiceProvider: fixtures.provider,
            voiceId: fixtures.voiceId
        )

        #expect(message.textToSpeak == "Hello, world!")
        #expect(message.voiceId == fixtures.voiceId)
        #expect(message.voiceProvider is AppleVoiceProvider)
    }

    @Test("Speech generation")
    func speak() async throws {
        guard let fixtures = fixtures else {
            Issue.record("No Apple TTS voices available. Skipping test.")
            return
        }
        let message = SimpleMessage(
            content: "Testing speech generation",
            voiceProvider: fixtures.provider,
            voiceId: fixtures.voiceId
        )

        let audioData = try await message.speak()
        #expect(audioData.count > 0)
    }

    @Test("Duration estimation")
    func estimateDuration() async throws {
        guard let fixtures = fixtures else {
            Issue.record("No Apple TTS voices available. Skipping test.")
            return
        }
        let message = SimpleMessage(
            content: "This is a test message",
            voiceProvider: fixtures.provider,
            voiceId: fixtures.voiceId
        )

        let duration = await message.estimateDuration()
        #expect(duration > 0)
    }

    @Test("Voice availability check")
    func isVoiceAvailable() async throws {
        // Skip on CI - TTS voices aren't available there
        if ProcessInfo.processInfo.environment.keys.contains("CI") {
            return
        }

        guard let fixtures = fixtures else {
            Issue.record("No Apple TTS voices available. Skipping test.")
            return
        }
        let message = SimpleMessage(
            content: "Test",
            voiceProvider: fixtures.provider,
            voiceId: fixtures.voiceId
        )

        let available = await message.isVoiceAvailable()

        // This test requires real TTS voices which aren't available on CI
        #expect(available, "Voice '\(fixtures.voiceId)' should be available")
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
            Issue.record("No Apple TTS voices available. Skipping test.")
            return
        }
        let dialogue = CharacterDialogue(
            characterName: "Alice",
            dialogue: "Hello!",
            voiceProvider: fixtures.provider,
            voiceId: fixtures.voiceId,
            includeCharacterName: true
        )

        #expect(dialogue.textToSpeak == "Alice: Hello!")
    }

    @Test("Dialogue without character name")
    func withoutCharacterName() {
        guard let fixtures = fixtures else {
            Issue.record("No Apple TTS voices available. Skipping test.")
            return
        }
        let dialogue = CharacterDialogue(
            characterName: "Alice",
            dialogue: "Hello!",
            voiceProvider: fixtures.provider,
            voiceId: fixtures.voiceId,
            includeCharacterName: false
        )

        #expect(dialogue.textToSpeak == "Hello!")
    }

    @Test("Dialogue speech generation")
    func speak() async throws {
        guard let fixtures = fixtures else {
            Issue.record("No Apple TTS voices available. Skipping test.")
            return
        }
        let dialogue = CharacterDialogue(
            characterName: "Bob",
            dialogue: "Testing dialogue speech",
            voiceProvider: fixtures.provider,
            voiceId: fixtures.voiceId
        )

        let audioData = try await dialogue.speak()
        #expect(audioData.count > 0)
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
            Issue.record("No Apple TTS voices available. Skipping test.")
            return
        }
        let article = Article(
            title: "Breaking News",
            author: "Jane Doe",
            content: "This is the article content.",
            voiceProvider: fixtures.provider,
            voiceId: fixtures.voiceId,
            includeMeta: true
        )

        #expect(article.textToSpeak == "Breaking News, by Jane Doe. This is the article content.")
    }

    @Test("Article without metadata")
    func withoutMeta() {
        guard let fixtures = fixtures else {
            Issue.record("No Apple TTS voices available. Skipping test.")
            return
        }
        let article = Article(
            title: "Breaking News",
            author: "Jane Doe",
            content: "This is the article content.",
            voiceProvider: fixtures.provider,
            voiceId: fixtures.voiceId,
            includeMeta: false
        )

        #expect(article.textToSpeak == "This is the article content.")
    }

    @Test("Article speech generation")
    func speak() async throws {
        guard let fixtures = fixtures else {
            Issue.record("No Apple TTS voices available. Skipping test.")
            return
        }
        let article = Article(
            title: "Test Article",
            author: "Test Author",
            content: "Test content",
            voiceProvider: fixtures.provider,
            voiceId: fixtures.voiceId
        )

        let audioData = try await article.speak()
        #expect(audioData.count > 0)
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
            Issue.record("No Apple TTS voices available. Skipping test.")
            return
        }
        let timestamp = Date(timeIntervalSince1970: 1609459200) // 2021-01-01 00:00:00 UTC
        let notification = Notification(
            title: "New Message",
            message: "You have mail",
            timestamp: timestamp,
            voiceProvider: fixtures.provider,
            voiceId: fixtures.voiceId,
            includeTimestamp: true
        )

        #expect(notification.textToSpeak.contains("New Message"))
        #expect(notification.textToSpeak.contains("You have mail"))
        #expect(notification.textToSpeak.contains(" at "))
    }

    @Test("Notification without timestamp")
    func withoutTimestamp() {
        guard let fixtures = fixtures else {
            Issue.record("No Apple TTS voices available. Skipping test.")
            return
        }
        let notification = Notification(
            title: "Alert",
            message: "Something happened",
            voiceProvider: fixtures.provider,
            voiceId: fixtures.voiceId,
            includeTimestamp: false
        )

        #expect(notification.textToSpeak == "Alert. Something happened")
    }

    @Test("Notification speech generation")
    func speak() async throws {
        guard let fixtures = fixtures else {
            Issue.record("No Apple TTS voices available. Skipping test.")
            return
        }
        let notification = Notification(
            title: "Test",
            message: "Test message",
            voiceProvider: fixtures.provider,
            voiceId: fixtures.voiceId
        )

        let audioData = try await notification.speak()
        #expect(audioData.count > 0)
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
            Issue.record("No Apple TTS voices available. Skipping test.")
            return
        }
        let item = ListItem(
            number: 5,
            content: "Mix ingredients",
            voiceProvider: fixtures.provider,
            voiceId: fixtures.voiceId
        )

        #expect(item.textToSpeak == "Step 5: Mix ingredients")
    }

    @Test("List item speech generation")
    func speak() async throws {
        guard let fixtures = fixtures else {
            Issue.record("No Apple TTS voices available. Skipping test.")
            return
        }
        let item = ListItem(
            number: 1,
            content: "Test step",
            voiceProvider: fixtures.provider,
            voiceId: fixtures.voiceId
        )

        let audioData = try await item.speak()
        #expect(audioData.count > 0)
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
            Issue.record("No Apple TTS voices available. Skipping test.")
            return
        }
        let items: [SimpleMessage] = [
            SimpleMessage(content: "First", voiceProvider: fixtures.provider, voiceId: fixtures.voiceId),
            SimpleMessage(content: "Second", voiceProvider: fixtures.provider, voiceId: fixtures.voiceId),
            SimpleMessage(content: "Third", voiceProvider: fixtures.provider, voiceId: fixtures.voiceId)
        ]

        let audioFiles = try await items.speakAll()
        #expect(audioFiles.count == 3)
        for audio in audioFiles {
            #expect(audio.count > 0)
        }
    }

    @Test("Estimate total duration")
    func estimateTotalDuration() async throws {
        guard let fixtures = fixtures else {
            Issue.record("No Apple TTS voices available. Skipping test.")
            return
        }
        let items: [SimpleMessage] = [
            SimpleMessage(content: "Short", voiceProvider: fixtures.provider, voiceId: fixtures.voiceId),
            SimpleMessage(content: "Medium length message", voiceProvider: fixtures.provider, voiceId: fixtures.voiceId),
            SimpleMessage(content: "A longer message with more words to speak", voiceProvider: fixtures.provider, voiceId: fixtures.voiceId)
        ]

        let totalDuration = await items.estimateTotalDuration()
        #expect(totalDuration > 0)

        // Verify it's the sum of individual durations
        var expectedTotal: TimeInterval = 0
        for item in items {
            expectedTotal += await item.estimateDuration()
        }
        #expect(abs(totalDuration - expectedTotal) < 0.01)
    }

    @Test("Empty collection speak all")
    func emptyCollectionSpeakAll() async throws {
        let items: [SimpleMessage] = []
        let audioFiles = try await items.speakAll()
        #expect(audioFiles.isEmpty)
    }

    @Test("Empty collection estimate total duration")
    func emptyCollectionEstimateTotalDuration() async throws {
        let items: [SimpleMessage] = []
        let duration = await items.estimateTotalDuration()
        #expect(duration == 0)
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
            Issue.record("No Apple TTS voices available. Skipping test.")
            return
        }
        let message = SimpleMessage(
            content: "Test",
            voiceProvider: fixtures.provider,
            voiceId: "invalid-voice-id"
        )

        #if os(macOS)
        // macOS: Should throw an error for invalid voice ID (no fallback)
        await #expect(throws: VoiceProviderError.self) {
            try await message.speak()
        }
        #else
        // iOS: AVSpeechSynthesisVoice may fall back to default voice for invalid IDs
        // Just verify that audio is generated (fallback behavior)
        let audioData = try await message.speak()
        #expect(audioData.count > 0)
        #endif
    }

    @Test("Speak with empty text throws error")
    func speakWithEmptyTextThrowsError() async throws {
        guard let fixtures = fixtures else {
            Issue.record("No Apple TTS voices available. Skipping test.")
            return
        }
        let message = SimpleMessage(
            content: "",
            voiceProvider: fixtures.provider,
            voiceId: fixtures.voiceId
        )

        await #expect(throws: VoiceProviderError.self) {
            try await message.speak()
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
            Issue.record("No Apple TTS voices available. Skipping test.")
            return
        }
        // Test a custom implementation
        struct CustomItem: SpeakableItem {
            let voiceProvider: VoiceProvider
            let voiceId: String
            let prefix: String
            let suffix: String

            var textToSpeak: String {
                "\(prefix) - \(suffix)"
            }
        }

        let custom = CustomItem(
            voiceProvider: fixtures.provider,
            voiceId: fixtures.voiceId,
            prefix: "Hello",
            suffix: "World"
        )

        #expect(custom.textToSpeak == "Hello - World")
        let audioData = try await custom.speak()
        #expect(audioData.count > 0)
    }
}
