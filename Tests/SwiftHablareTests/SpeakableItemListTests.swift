//
//  SpeakableItemListTests.swift
//  SwiftHablareTests
//
//  Comprehensive tests for SpeakableItemList and GenerationService.generateList()
//

import XCTest
import SwiftData
import SwiftCompartido
@testable import SwiftHablare

final class SpeakableItemListTests: XCTestCase {
    var provider: AppleVoiceProvider!
    var service: GenerationService!
    var voiceId: String!
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!

    @MainActor
    override func setUp() async throws {
        try await super.setUp()

        // Create provider and service
        provider = AppleVoiceProvider()
        service = GenerationService(voiceProvider: provider)

        // Get a voice
        let voices = try await provider.fetchVoices()
        voiceId = voices.first?.id ?? "com.apple.voice.compact.en-US.Samantha"

        // Create in-memory SwiftData container
        let schema = Schema([TypedDataStorage.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        modelContext = ModelContext(modelContainer)
    }

    @MainActor
    override func tearDown() async throws {
        provider = nil
        service = nil
        voiceId = nil
        modelContext = nil
        modelContainer = nil
        try await super.tearDown()
    }

    // MARK: - SpeakableItemList Creation Tests

    @MainActor
    func testListCreation() {
        let items: [any SpeakableItem] = [
            SimpleMessage(content: "Hello", voiceProvider: provider, voiceId: voiceId),
            SimpleMessage(content: "World", voiceProvider: provider, voiceId: voiceId)
        ]

        let list = SpeakableItemList(name: "Test List", items: items)

        XCTAssertEqual(list.name, "Test List")
        XCTAssertEqual(list.totalCount, 2)
        XCTAssertEqual(list.currentIndex, 0)
        XCTAssertFalse(list.isProcessing)
        XCTAssertFalse(list.isCancelled)
        XCTAssertNil(list.error)
        XCTAssertEqual(list.progress, 0.0)
        XCTAssertFalse(list.isComplete)
        XCTAssertFalse(list.hasFailed)
    }

    @MainActor
    func testEmptyList() {
        let list = SpeakableItemList(name: "Empty", items: [])

        XCTAssertEqual(list.totalCount, 0)
        XCTAssertEqual(list.progress, 0.0)
        XCTAssertTrue(list.isComplete)  // Empty list is complete by definition
    }

    @MainActor
    func testListItemAccess() {
        let items: [any SpeakableItem] = [
            SimpleMessage(content: "First", voiceProvider: provider, voiceId: voiceId),
            SimpleMessage(content: "Second", voiceProvider: provider, voiceId: voiceId)
        ]

        let list = SpeakableItemList(name: "Test", items: items)

        let firstItem = list.item(at: 0)
        XCTAssertNotNil(firstItem)
        XCTAssertEqual(firstItem?.textToSpeak, "First")

        let secondItem = list.item(at: 1)
        XCTAssertNotNil(secondItem)
        XCTAssertEqual(secondItem?.textToSpeak, "Second")

        let invalidItem = list.item(at: 5)
        XCTAssertNil(invalidItem)
    }

    @MainActor
    func testListAllItems() {
        let items: [any SpeakableItem] = [
            SimpleMessage(content: "A", voiceProvider: provider, voiceId: voiceId),
            SimpleMessage(content: "B", voiceProvider: provider, voiceId: voiceId)
        ]

        let list = SpeakableItemList(name: "Test", items: items)
        let allItems = list.allItems()

        XCTAssertEqual(allItems.count, 2)
    }

    // MARK: - Progress Tracking Tests

    @MainActor
    func testProgressTracking() {
        let list = SpeakableItemList(name: "Test", items: [
            SimpleMessage(content: "1", voiceProvider: provider, voiceId: voiceId),
            SimpleMessage(content: "2", voiceProvider: provider, voiceId: voiceId),
            SimpleMessage(content: "3", voiceProvider: provider, voiceId: voiceId),
            SimpleMessage(content: "4", voiceProvider: provider, voiceId: voiceId)
        ])

        XCTAssertEqual(list.progress, 0.0)

        list.advanceProgress()
        XCTAssertEqual(list.currentIndex, 1)
        XCTAssertEqual(list.progress, 0.25)

        list.advanceProgress()
        XCTAssertEqual(list.currentIndex, 2)
        XCTAssertEqual(list.progress, 0.5)

        list.advanceProgress()
        XCTAssertEqual(list.currentIndex, 3)
        XCTAssertEqual(list.progress, 0.75)

        list.advanceProgress()
        XCTAssertEqual(list.currentIndex, 4)
        XCTAssertEqual(list.progress, 1.0)
    }

    @MainActor
    func testProgressWithCustomMessage() {
        let list = SpeakableItemList(name: "Test", items: [
            SimpleMessage(content: "Hello", voiceProvider: provider, voiceId: voiceId)
        ])

        list.advanceProgress(message: "Custom status")
        XCTAssertEqual(list.statusMessage, "Custom status")
    }

    @MainActor
    func testProcessingState() {
        let list = SpeakableItemList(name: "Test", items: [
            SimpleMessage(content: "Hello", voiceProvider: provider, voiceId: voiceId)
        ])

        XCTAssertFalse(list.isProcessing)

        list.startProcessing()
        XCTAssertTrue(list.isProcessing)
        XCTAssertEqual(list.statusMessage, "Processing...")

        // Advance through the item
        list.advanceProgress()

        list.completeProcessing()
        XCTAssertFalse(list.isProcessing)
        XCTAssertEqual(list.statusMessage, "Complete")
        XCTAssertTrue(list.isComplete)
    }

    // MARK: - Cancellation Tests

    @MainActor
    func testCancellation() {
        let list = SpeakableItemList(name: "Test", items: [
            SimpleMessage(content: "Hello", voiceProvider: provider, voiceId: voiceId)
        ])

        XCTAssertFalse(list.isCancelled)

        list.cancel()
        XCTAssertTrue(list.isCancelled)
        XCTAssertEqual(list.statusMessage, "Cancelled")
    }

    @MainActor
    func testCancellationDuringGeneration() async throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Apple TTS integration test skipped on simulator")
        #endif

        let items: [any SpeakableItem] = [
            SimpleMessage(content: "First message", voiceProvider: provider, voiceId: voiceId),
            SimpleMessage(content: "Second message", voiceProvider: provider, voiceId: voiceId),
            SimpleMessage(content: "Third message", voiceProvider: provider, voiceId: voiceId)
        ]

        let list = SpeakableItemList(name: "Test", items: items)

        // Start generation
        Task {
            _ = try? await service.generateList(list, to: modelContext)
        }

        // Cancel after a short delay
        try await Task.sleep(for: .milliseconds(100))
        list.cancel()

        // Wait a bit for cancellation to process
        try await Task.sleep(for: .milliseconds(500))

        // Should have been cancelled
        XCTAssertTrue(list.isCancelled)
        XCTAssertFalse(list.isProcessing)
    }

    // MARK: - Reset Tests

    @MainActor
    func testReset() {
        let list = SpeakableItemList(name: "Test", items: [
            SimpleMessage(content: "Hello", voiceProvider: provider, voiceId: voiceId)
        ])

        // Simulate some progress
        list.startProcessing()
        list.advanceProgress()
        list.completeProcessing()

        XCTAssertEqual(list.currentIndex, 1)
        XCTAssertTrue(list.isComplete)

        // Reset
        list.reset()
        XCTAssertEqual(list.currentIndex, 0)
        XCTAssertFalse(list.isCancelled)
        XCTAssertNil(list.error)
        XCTAssertEqual(list.statusMessage, "Ready")
        XCTAssertFalse(list.isComplete)
    }

    @MainActor
    func testResetWhileProcessing() {
        let list = SpeakableItemList(name: "Test", items: [
            SimpleMessage(content: "Hello", voiceProvider: provider, voiceId: voiceId)
        ])

        list.startProcessing()
        XCTAssertTrue(list.isProcessing)

        // Reset should not work while processing
        list.reset()
        XCTAssertTrue(list.isProcessing)
        XCTAssertNotEqual(list.statusMessage, "Ready")
    }

    // MARK: - Error Handling Tests

    @MainActor
    func testErrorHandling() {
        let list = SpeakableItemList(name: "Test", items: [
            SimpleMessage(content: "Hello", voiceProvider: provider, voiceId: voiceId)
        ])

        let testError = VoiceProviderError.invalidRequest("Test error")
        list.failProcessing(with: testError)

        XCTAssertNotNil(list.error)
        XCTAssertTrue(list.hasFailed)
        XCTAssertFalse(list.isProcessing)
        XCTAssertTrue(list.statusMessage.contains("Failed"))
    }

    // MARK: - Integration Tests with GenerationService

    @MainActor
    func testGenerateListBasic() async throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Apple TTS integration test skipped on simulator")
        #endif

        let items: [any SpeakableItem] = [
            SimpleMessage(content: "Hello", voiceProvider: provider, voiceId: voiceId),
            SimpleMessage(content: "World", voiceProvider: provider, voiceId: voiceId)
        ]

        let list = SpeakableItemList(name: "Test", items: items)

        let records = try await service.generateList(list, to: modelContext)

        XCTAssertEqual(records.count, 2)
        XCTAssertTrue(list.isComplete)
        XCTAssertFalse(list.isProcessing)
        XCTAssertEqual(list.currentIndex, 2)
        XCTAssertEqual(list.progress, 1.0)
    }

    @MainActor
    func testGenerateListPersistence() async throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Apple TTS integration test skipped on simulator")
        #endif

        let items: [any SpeakableItem] = [
            SimpleMessage(content: "Test message one", voiceProvider: provider, voiceId: voiceId),
            SimpleMessage(content: "Test message two", voiceProvider: provider, voiceId: voiceId)
        ]

        let list = SpeakableItemList(name: "Persistence Test", items: items)

        _ = try await service.generateList(list, to: modelContext)

        // Verify records were persisted
        let descriptor = FetchDescriptor<TypedDataStorage>()
        let savedRecords = try modelContext.fetch(descriptor)

        XCTAssertEqual(savedRecords.count, 2)

        // Verify content
        for (index, record) in savedRecords.enumerated() {
            XCTAssertEqual(record.providerId, "apple")
            XCTAssertEqual(record.mimeType, "audio/x-aiff")
            XCTAssertNotNil(record.binaryValue)
            XCTAssertFalse(record.binaryValue!.isEmpty)
            XCTAssertEqual(record.prompt, items[index].textToSpeak)
        }
    }

    @MainActor
    func testGenerateListWithDifferentTypes() async throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Apple TTS integration test skipped on simulator")
        #endif

        let items: [any SpeakableItem] = [
            SimpleMessage(content: "Hello", voiceProvider: provider, voiceId: voiceId),
            CharacterDialogue(
                characterName: "Alice",
                dialogue: "How are you?",
                voiceProvider: provider,
                voiceId: voiceId,
                includeCharacterName: true
            ),
            Article(
                title: "News",
                author: "Bob",
                content: "Breaking news today.",
                voiceProvider: provider,
                voiceId: voiceId,
                includeMeta: true
            )
        ]

        let list = SpeakableItemList(name: "Mixed Types", items: items)

        let records = try await service.generateList(list, to: modelContext)

        XCTAssertEqual(records.count, 3)
        XCTAssertEqual(records[0].prompt, "Hello")
        XCTAssertEqual(records[1].prompt, "Alice: How are you?")
        XCTAssertEqual(records[2].prompt, "News, by Bob. Breaking news today.")
    }

    @MainActor
    func testGenerateEmptyList() async throws {
        let list = SpeakableItemList(name: "Empty", items: [])

        let records = try await service.generateList(list, to: modelContext)

        XCTAssertEqual(records.count, 0)
        XCTAssertTrue(list.isComplete)
    }

    @MainActor
    func testGenerateListWithSaveInterval() async throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Apple TTS integration test skipped on simulator")
        #endif

        let items: [any SpeakableItem] = [
            SimpleMessage(content: "One", voiceProvider: provider, voiceId: voiceId),
            SimpleMessage(content: "Two", voiceProvider: provider, voiceId: voiceId),
            SimpleMessage(content: "Three", voiceProvider: provider, voiceId: voiceId),
            SimpleMessage(content: "Four", voiceProvider: provider, voiceId: voiceId)
        ]

        let list = SpeakableItemList(name: "Save Interval Test", items: items)

        // Save every 2 items
        let records = try await service.generateList(list, to: modelContext, saveInterval: 2)

        XCTAssertEqual(records.count, 4)

        // Verify all were persisted
        let descriptor = FetchDescriptor<TypedDataStorage>()
        let savedRecords = try modelContext.fetch(descriptor)
        XCTAssertEqual(savedRecords.count, 4)
    }

    // MARK: - List Properties Tests

    @MainActor
    func testListProperties() {
        let list = SpeakableItemList(name: "Test List", items: [
            SimpleMessage(content: "Hello", voiceProvider: provider, voiceId: voiceId)
        ])

        XCTAssertEqual(list.name, "Test List")
        XCTAssertEqual(list.totalCount, 1)
        XCTAssertEqual(list.currentIndex, 0)
    }

    // MARK: - Performance Tests

    @MainActor
    func testLargeListProgress() {
        // Create a large list
        var items: [any SpeakableItem] = []
        for i in 0..<100 {
            items.append(SimpleMessage(content: "Item \(i)", voiceProvider: provider, voiceId: voiceId))
        }

        let list = SpeakableItemList(name: "Large List", items: items)

        XCTAssertEqual(list.totalCount, 100)

        // Simulate progress through all items
        for i in 0..<100 {
            list.advanceProgress()
            let expectedProgress = Double(i + 1) / 100.0
            XCTAssertEqual(list.progress, expectedProgress, accuracy: 0.001)
        }

        XCTAssertEqual(list.progress, 1.0)
    }
}
