//
//  SpeakableItemTests.swift
//  SwiftHablareTests
//
//  Tests for SpeakableItem protocol and implementations
//

import XCTest
@testable import SwiftHablare

final class SpeakableItemTests: XCTestCase {
    var provider: AppleVoiceProvider!
    var voiceId: String!

    override func setUp() async throws {
        try await super.setUp()
        provider = AppleVoiceProvider()
        let voices = try await provider.fetchVoices()
        voiceId = voices.first?.id ?? "com.apple.voice.compact.en-US.Samantha"
    }

    override func tearDown() async throws {
        provider = nil
        voiceId = nil
        try await super.tearDown()
    }

    // MARK: - SimpleMessage Tests

    func testSimpleMessageConformance() {
        let message = SimpleMessage(
            content: "Hello, world!",
            voiceProvider: provider,
            voiceId: voiceId
        )

        XCTAssertEqual(message.textToSpeak, "Hello, world!")
        XCTAssertEqual(message.voiceId, voiceId)
        XCTAssertNotNil(message.voiceProvider)
    }

    func testSimpleMessageSpeak() async throws {
        let message = SimpleMessage(
            content: "Testing speech generation",
            voiceProvider: provider,
            voiceId: voiceId
        )

        let audioData = try await message.speak()
        XCTAssertGreaterThan(audioData.count, 0, "Audio data should not be empty")
    }

    func testSimpleMessageEstimateDuration() async throws {
        let message = SimpleMessage(
            content: "This is a test message",
            voiceProvider: provider,
            voiceId: voiceId
        )

        let duration = await message.estimateDuration()
        XCTAssertGreaterThan(duration, 0, "Duration should be positive")
    }

    func testSimpleMessageIsVoiceAvailable() async throws {
        let message = SimpleMessage(
            content: "Test",
            voiceProvider: provider,
            voiceId: voiceId
        )

        let available = await message.isVoiceAvailable()
        XCTAssertTrue(available, "Voice should be available")
    }

    // MARK: - CharacterDialogue Tests

    func testCharacterDialogueWithCharacterName() {
        let dialogue = CharacterDialogue(
            characterName: "Alice",
            dialogue: "Hello!",
            voiceProvider: provider,
            voiceId: voiceId,
            includeCharacterName: true
        )

        XCTAssertEqual(dialogue.textToSpeak, "Alice: Hello!")
    }

    func testCharacterDialogueWithoutCharacterName() {
        let dialogue = CharacterDialogue(
            characterName: "Alice",
            dialogue: "Hello!",
            voiceProvider: provider,
            voiceId: voiceId,
            includeCharacterName: false
        )

        XCTAssertEqual(dialogue.textToSpeak, "Hello!")
    }

    func testCharacterDialogueSpeak() async throws {
        let dialogue = CharacterDialogue(
            characterName: "Bob",
            dialogue: "Testing dialogue speech",
            voiceProvider: provider,
            voiceId: voiceId
        )

        let audioData = try await dialogue.speak()
        XCTAssertGreaterThan(audioData.count, 0)
    }

    // MARK: - Article Tests

    func testArticleWithMeta() {
        let article = Article(
            title: "Breaking News",
            author: "Jane Doe",
            content: "This is the article content.",
            voiceProvider: provider,
            voiceId: voiceId,
            includeMeta: true
        )

        XCTAssertEqual(article.textToSpeak, "Breaking News, by Jane Doe. This is the article content.")
    }

    func testArticleWithoutMeta() {
        let article = Article(
            title: "Breaking News",
            author: "Jane Doe",
            content: "This is the article content.",
            voiceProvider: provider,
            voiceId: voiceId,
            includeMeta: false
        )

        XCTAssertEqual(article.textToSpeak, "This is the article content.")
    }

    func testArticleSpeak() async throws {
        let article = Article(
            title: "Test Article",
            author: "Test Author",
            content: "Test content",
            voiceProvider: provider,
            voiceId: voiceId
        )

        let audioData = try await article.speak()
        XCTAssertGreaterThan(audioData.count, 0)
    }

    // MARK: - Notification Tests

    func testNotificationWithTimestamp() {
        let timestamp = Date(timeIntervalSince1970: 1609459200) // 2021-01-01 00:00:00 UTC
        let notification = Notification(
            title: "New Message",
            message: "You have mail",
            timestamp: timestamp,
            voiceProvider: provider,
            voiceId: voiceId,
            includeTimestamp: true
        )

        XCTAssertTrue(notification.textToSpeak.contains("New Message"))
        XCTAssertTrue(notification.textToSpeak.contains("You have mail"))
        // Timestamp format varies by locale, so just check it's included
        XCTAssertTrue(notification.textToSpeak.contains(" at "))
    }

    func testNotificationWithoutTimestamp() {
        let notification = Notification(
            title: "Alert",
            message: "Something happened",
            voiceProvider: provider,
            voiceId: voiceId,
            includeTimestamp: false
        )

        XCTAssertEqual(notification.textToSpeak, "Alert. Something happened")
    }

    func testNotificationSpeak() async throws {
        let notification = Notification(
            title: "Test",
            message: "Test message",
            voiceProvider: provider,
            voiceId: voiceId
        )

        let audioData = try await notification.speak()
        XCTAssertGreaterThan(audioData.count, 0)
    }

    // MARK: - ListItem Tests

    func testListItemFormatting() {
        let item = ListItem(
            number: 5,
            content: "Mix ingredients",
            voiceProvider: provider,
            voiceId: voiceId
        )

        XCTAssertEqual(item.textToSpeak, "Step 5: Mix ingredients")
    }

    func testListItemSpeak() async throws {
        let item = ListItem(
            number: 1,
            content: "Test step",
            voiceProvider: provider,
            voiceId: voiceId
        )

        let audioData = try await item.speak()
        XCTAssertGreaterThan(audioData.count, 0)
    }

    // MARK: - Batch Operations Tests

    func testSpeakAll() async throws {
        let items: [SimpleMessage] = [
            SimpleMessage(content: "First", voiceProvider: provider, voiceId: voiceId),
            SimpleMessage(content: "Second", voiceProvider: provider, voiceId: voiceId),
            SimpleMessage(content: "Third", voiceProvider: provider, voiceId: voiceId)
        ]

        let audioFiles = try await items.speakAll()
        XCTAssertEqual(audioFiles.count, 3)
        for audio in audioFiles {
            XCTAssertGreaterThan(audio.count, 0)
        }
    }

    func testEstimateTotalDuration() async throws {
        let items: [SimpleMessage] = [
            SimpleMessage(content: "Short", voiceProvider: provider, voiceId: voiceId),
            SimpleMessage(content: "Medium length message", voiceProvider: provider, voiceId: voiceId),
            SimpleMessage(content: "A longer message with more words to speak", voiceProvider: provider, voiceId: voiceId)
        ]

        let totalDuration = await items.estimateTotalDuration()
        XCTAssertGreaterThan(totalDuration, 0)

        // Verify it's the sum of individual durations
        var expectedTotal: TimeInterval = 0
        for item in items {
            expectedTotal += await item.estimateDuration()
        }
        XCTAssertEqual(totalDuration, expectedTotal, accuracy: 0.01)
    }

    func testEmptyCollectionSpeakAll() async throws {
        let items: [SimpleMessage] = []
        let audioFiles = try await items.speakAll()
        XCTAssertTrue(audioFiles.isEmpty)
    }

    func testEmptyCollectionEstimateTotalDuration() async throws {
        let items: [SimpleMessage] = []
        let duration = await items.estimateTotalDuration()
        XCTAssertEqual(duration, 0)
    }

    // MARK: - Error Handling Tests

    func testSpeakWithInvalidVoiceId() async throws {
        let message = SimpleMessage(
            content: "Test",
            voiceProvider: provider,
            voiceId: "invalid-voice-id"
        )

        // Should still generate audio (Apple provider falls back to default voice)
        let audioData = try await message.speak()
        XCTAssertGreaterThan(audioData.count, 0)
    }

    func testSpeakWithEmptyText() async throws {
        let message = SimpleMessage(
            content: "",
            voiceProvider: provider,
            voiceId: voiceId
        )

        do {
            _ = try await message.speak()
            XCTFail("Should throw error for empty text")
        } catch {
            // Expected to throw
            XCTAssertTrue(error is VoiceProviderError)
        }
    }

    // MARK: - Custom Implementation Tests

    func testCustomSpeakableItem() async throws {
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
            voiceProvider: provider,
            voiceId: voiceId,
            prefix: "Hello",
            suffix: "World"
        )

        XCTAssertEqual(custom.textToSpeak, "Hello - World")
        let audioData = try await custom.speak()
        XCTAssertGreaterThan(audioData.count, 0)
    }
}
