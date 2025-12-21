//
//  SpeakableItemListTests.swift
//  SwiftHablareTests
//
//  Comprehensive tests for SpeakableItemList and GenerationService.generateList()
//

import Testing
import SwiftData
import SwiftCompartido
@testable import SwiftHablare

@Suite("SpeakableItemList Tests")
@MainActor
struct SpeakableItemListTests {

    // MARK: - SpeakableItemList Creation Tests

    @Test("List creation with items")
    func testListCreation() async throws {
        let container = try TestFixtures.makeTestContainer()
        let context = ModelContext(container)
        let provider = TestFixtures.makeAppleProvider()
        let voiceId = try await TestFixtures.getAvailableAppleVoiceId()

        let items: [any SpeakableItem] = [
            TestFixtures.makeSimpleMessage(content: "Hello", provider: provider, voiceId: voiceId),
            TestFixtures.makeSimpleMessage(content: "World", provider: provider, voiceId: voiceId)
        ]

        let list = SpeakableItemList(name: "Test List", items: items)

        #expect(list.name == "Test List")
        #expect(list.totalCount == 2)
        #expect(list.currentIndex == 0)
        #expect(!list.isProcessing)
        #expect(!list.isCancelled)
        #expect(list.error == nil)
        #expect(list.progress == 0.0)
        #expect(!list.isComplete)
        #expect(!list.hasFailed)
    }

    @Test("Empty list creation")
    func testEmptyList() {
        let list = SpeakableItemList(name: "Empty", items: [])

        #expect(list.totalCount == 0)
        #expect(list.progress == 0.0)
        #expect(list.isComplete)  // Empty list is complete by definition
    }

    @Test("List item access")
    func testListItemAccess() async throws {
        let provider = TestFixtures.makeAppleProvider()
        let voiceId = try await TestFixtures.getAvailableAppleVoiceId()

        let items: [any SpeakableItem] = [
            TestFixtures.makeSimpleMessage(content: "First", provider: provider, voiceId: voiceId),
            TestFixtures.makeSimpleMessage(content: "Second", provider: provider, voiceId: voiceId)
        ]

        let list = SpeakableItemList(name: "Test", items: items)

        let firstItem = list.item(at: 0)
        #expect(firstItem != nil)
        #expect(firstItem?.textToSpeak == "First")

        let secondItem = list.item(at: 1)
        #expect(secondItem != nil)
        #expect(secondItem?.textToSpeak == "Second")

        let invalidItem = list.item(at: 5)
        #expect(invalidItem == nil)
    }

    @Test("List all items access")
    func testListAllItems() async throws {
        let provider = TestFixtures.makeAppleProvider()
        let voiceId = try await TestFixtures.getAvailableAppleVoiceId()

        let items: [any SpeakableItem] = [
            TestFixtures.makeSimpleMessage(content: "A", provider: provider, voiceId: voiceId),
            TestFixtures.makeSimpleMessage(content: "B", provider: provider, voiceId: voiceId)
        ]

        let list = SpeakableItemList(name: "Test", items: items)
        let allItems = list.allItems()

        #expect(allItems.count == 2)
    }

    // MARK: - Progress Tracking Tests

    @Test("Progress tracking through items")
    func testProgressTracking() async throws {
        let provider = TestFixtures.makeAppleProvider()
        let voiceId = try await TestFixtures.getAvailableAppleVoiceId()

        let list = SpeakableItemList(name: "Test", items: [
            TestFixtures.makeSimpleMessage(content: "1", provider: provider, voiceId: voiceId),
            TestFixtures.makeSimpleMessage(content: "2", provider: provider, voiceId: voiceId),
            TestFixtures.makeSimpleMessage(content: "3", provider: provider, voiceId: voiceId),
            TestFixtures.makeSimpleMessage(content: "4", provider: provider, voiceId: voiceId)
        ])

        #expect(list.progress == 0.0)

        list.advanceProgress()
        #expect(list.currentIndex == 1)
        #expect(list.progress == 0.25)

        list.advanceProgress()
        #expect(list.currentIndex == 2)
        #expect(list.progress == 0.5)

        list.advanceProgress()
        #expect(list.currentIndex == 3)
        #expect(list.progress == 0.75)

        list.advanceProgress()
        #expect(list.currentIndex == 4)
        #expect(list.progress == 1.0)
    }

    @Test("Progress with custom message")
    func testProgressWithCustomMessage() async throws {
        let provider = TestFixtures.makeAppleProvider()
        let voiceId = try await TestFixtures.getAvailableAppleVoiceId()

        let list = SpeakableItemList(name: "Test", items: [
            TestFixtures.makeSimpleMessage(content: "Hello", provider: provider, voiceId: voiceId)
        ])

        list.advanceProgress(message: "Custom status")
        #expect(list.statusMessage == "Custom status")
    }

    @Test("Processing state transitions")
    func testProcessingState() async throws {
        let provider = TestFixtures.makeAppleProvider()
        let voiceId = try await TestFixtures.getAvailableAppleVoiceId()

        let list = SpeakableItemList(name: "Test", items: [
            TestFixtures.makeSimpleMessage(content: "Hello", provider: provider, voiceId: voiceId)
        ])

        #expect(!list.isProcessing)

        list.startProcessing()
        #expect(list.isProcessing)
        #expect(list.statusMessage == "Processing...")

        // Advance through the item
        list.advanceProgress()

        list.completeProcessing()
        #expect(!list.isProcessing)
        #expect(list.statusMessage == "Complete")
        #expect(list.isComplete)
    }

    // MARK: - Cancellation Tests

    @Test("Cancellation state change")
    func testCancellation() async throws {
        let provider = TestFixtures.makeAppleProvider()
        let voiceId = try await TestFixtures.getAvailableAppleVoiceId()

        let list = SpeakableItemList(name: "Test", items: [
            TestFixtures.makeSimpleMessage(content: "Hello", provider: provider, voiceId: voiceId)
        ])

        #expect(!list.isCancelled)

        list.cancel()
        #expect(list.isCancelled)
        #expect(list.statusMessage == "Cancelled")
    }

    // MARK: - Reset Tests

    @Test("Reset after completion")
    func testReset() async throws {
        let provider = TestFixtures.makeAppleProvider()
        let voiceId = try await TestFixtures.getAvailableAppleVoiceId()

        let list = SpeakableItemList(name: "Test", items: [
            TestFixtures.makeSimpleMessage(content: "Hello", provider: provider, voiceId: voiceId)
        ])

        // Simulate some progress
        list.startProcessing()
        list.advanceProgress()
        list.completeProcessing()

        #expect(list.currentIndex == 1)
        #expect(list.isComplete)

        // Reset
        list.reset()
        #expect(list.currentIndex == 0)
        #expect(!list.isCancelled)
        #expect(list.error == nil)
        #expect(list.statusMessage == "Ready")
        #expect(!list.isComplete)
    }

    @Test("Reset while processing should not reset")
    func testResetWhileProcessing() async throws {
        let provider = TestFixtures.makeAppleProvider()
        let voiceId = try await TestFixtures.getAvailableAppleVoiceId()

        let list = SpeakableItemList(name: "Test", items: [
            TestFixtures.makeSimpleMessage(content: "Hello", provider: provider, voiceId: voiceId)
        ])

        list.startProcessing()
        #expect(list.isProcessing)

        // Reset should not work while processing
        list.reset()
        #expect(list.isProcessing)
        #expect(list.statusMessage != "Ready")
    }

    // MARK: - Error Handling Tests

    @Test("Error handling state")
    func testErrorHandling() async throws {
        let provider = TestFixtures.makeAppleProvider()
        let voiceId = try await TestFixtures.getAvailableAppleVoiceId()

        let list = SpeakableItemList(name: "Test", items: [
            TestFixtures.makeSimpleMessage(content: "Hello", provider: provider, voiceId: voiceId)
        ])

        let testError = VoiceProviderError.invalidRequest("Test error")
        list.failProcessing(with: testError)

        #expect(list.error != nil)
        #expect(list.hasFailed)
        #expect(!list.isProcessing)
        #expect(list.statusMessage.contains("Failed"))
    }

    // MARK: - Integration Tests with GenerationService

    @Test("Generate empty list")
    func testGenerateEmptyList() async throws {
        let container = try TestFixtures.makeTestContainer()
        let context = ModelContext(container)
        let service = GenerationService()

        let list = SpeakableItemList(name: "Empty", items: [])

        let records = try await service.generateList(list, to: context)

        #expect(records.count == 0)
        #expect(list.isComplete)
    }

    // MARK: - List Properties Tests

    @Test("List properties")
    func testListProperties() async throws {
        let provider = TestFixtures.makeAppleProvider()
        let voiceId = try await TestFixtures.getAvailableAppleVoiceId()

        let list = SpeakableItemList(name: "Test List", items: [
            TestFixtures.makeSimpleMessage(content: "Hello", provider: provider, voiceId: voiceId)
        ])

        #expect(list.name == "Test List")
        #expect(list.totalCount == 1)
        #expect(list.currentIndex == 0)
    }

    // MARK: - Performance Tests

    @Test("Large list progress tracking")
    func testLargeListProgress() async throws {
        let provider = TestFixtures.makeAppleProvider()
        let voiceId = try await TestFixtures.getAvailableAppleVoiceId()

        // Create a large list
        var items: [any SpeakableItem] = []
        for i in 0..<100 {
            items.append(TestFixtures.makeSimpleMessage(content: "Item \(i)", provider: provider, voiceId: voiceId))
        }

        let list = SpeakableItemList(name: "Large List", items: items)

        #expect(list.totalCount == 100)

        // Simulate progress through all items
        for i in 0..<100 {
            list.advanceProgress()
            let expectedProgress = Double(i + 1) / 100.0
            let difference = abs(list.progress - expectedProgress)
            #expect(difference < 0.001)
        }

        #expect(list.progress == 1.0)
    }
}
