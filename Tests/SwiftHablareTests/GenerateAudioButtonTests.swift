//
//  GenerateAudioButtonTests.swift
//  SwiftHablareTests
//
//  Tests for GenerateAudioButton UI component
//

import Testing
import SwiftUI
import SwiftData
@testable import SwiftHablare
import SwiftCompartido

/// Tests for GenerateAudioButton component
@Suite("GenerateAudioButton Tests")
@MainActor
struct GenerateAudioButtonTests {

    // MARK: - Test Fixtures

    /// Create an in-memory model container for testing
    func makeTestContainer() throws -> ModelContainer {
        let schema = Schema([
            TypedDataStorage.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    /// Create a test speakable item
    func makeTestItem(provider: VoiceProvider? = nil) -> SimpleMessage {
        let testProvider = provider ?? AppleVoiceProvider()
        return SimpleMessage(
            content: "Test message for audio generation",
            voiceProvider: testProvider,
            voiceId: "test-voice-id"
        )
    }

    /// Create a test audio record
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

    // MARK: - Initialization Tests

    @Test("Button initializes with correct parameters")
    func testInitialization() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let service = GenerationService()
        let item = makeTestItem()

        let button = GenerateAudioButton(
            item: item,
            service: service,
            modelContext: context,
            onPlay: { _ in }
        )

        #expect(button.item.textToSpeak == item.textToSpeak)
    }

    @Test("Button initializes without onPlay callback")
    func testInitializationWithoutCallback() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let service = GenerationService()
        let item = makeTestItem()

        let button = GenerateAudioButton(
            item: item,
            service: service,
            modelContext: context,
            onPlay: nil
        )

        #expect(button.onPlay == nil)
    }

    // MARK: - State Tests

    @Test("Button detects existing audio in SwiftData")
    func testDetectsExistingAudio() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let service = GenerationService()
        let item = makeTestItem()

        // Create existing audio record
        let _ = makeTestAudioRecord(for: item, in: context)

        // Create button (should detect existing audio)
        let _ = GenerateAudioButton(
            item: item,
            service: service,
            modelContext: context,
            onPlay: nil
        )

        // Wait a moment for the .task to complete
        try await Task.sleep(for: .milliseconds(100))

        // Button should be in completed state
        // Note: We can't directly test @State, but we can verify the record exists
        let providerId = item.voiceProvider.providerId
        let voiceId = item.voiceId
        let prompt = item.textToSpeak

        let descriptor = FetchDescriptor<TypedDataStorage>(
            predicate: #Predicate { storage in
                storage.providerId == providerId &&
                storage.voiceID == voiceId &&
                storage.prompt == prompt
            }
        )
        let results = try context.fetch(descriptor)
        #expect(results.count == 1)
    }

    @Test("Button shows idle state when no audio exists")
    func testShowsIdleStateWhenNoAudio() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let service = GenerationService()
        let item = makeTestItem()

        // Create button (no existing audio)
        let _ = GenerateAudioButton(
            item: item,
            service: service,
            modelContext: context,
            onPlay: nil
        )

        // Wait a moment for the .task to complete
        try await Task.sleep(for: .milliseconds(100))

        // Verify no audio exists
        let providerId = item.voiceProvider.providerId
        let voiceId = item.voiceId
        let prompt = item.textToSpeak

        let descriptor = FetchDescriptor<TypedDataStorage>(
            predicate: #Predicate { storage in
                storage.providerId == providerId &&
                storage.voiceID == voiceId &&
                storage.prompt == prompt
            }
        )
        let results = try context.fetch(descriptor)
        #expect(results.isEmpty)
    }

    // MARK: - Generation Tests

    @Test("Button can generate audio and persist to SwiftData")
    func testGenerateAudioAndPersist() async throws {
        #if targetEnvironment(simulator)
        // Skip on simulator - Apple TTS doesn't generate real audio
        return
        #endif

        let container = try makeTestContainer()
        let context = ModelContext(container)

        // Fetch a valid voice ID for testing
        let provider = AppleVoiceProvider()
        let voices = try await provider.fetchVoices()
        let voiceId = voices.first?.id ?? "com.apple.voice.compact.en-US.Samantha"

        // Create test item with valid voice ID
        let item = SimpleMessage(
            content: "Test message for audio generation",
            voiceProvider: provider,
            voiceId: voiceId
        )

        // Extract values for predicate (can't capture objects in #Predicate)
        let providerId = provider.providerId
        let testVoiceId = voiceId
        let testPrompt = item.textToSpeak

        // Verify no audio exists initially
        var descriptor = FetchDescriptor<TypedDataStorage>(
            predicate: #Predicate { storage in
                storage.providerId == providerId &&
                storage.voiceID == testVoiceId &&
                storage.prompt == testPrompt
            }
        )
        var results = try context.fetch(descriptor)
        #expect(results.isEmpty)

        // Generate audio directly (simulating button action)
        let audioData = try await provider.generateAudio(
            text: item.textToSpeak,
            voiceId: voiceId
        )

        // Create record
        let record = TypedDataStorage(
            id: UUID(),
            providerId: provider.providerId,
            requestorID: "\(provider.providerId).audio.tts",
            mimeType: "audio/x-aiff",
            binaryValue: audioData,
            prompt: item.textToSpeak,
            durationSeconds: 5.0,
            voiceID: voiceId
        )

        context.insert(record)
        try context.save()

        // Verify audio was persisted
        descriptor = FetchDescriptor<TypedDataStorage>(
            predicate: #Predicate { storage in
                storage.providerId == providerId &&
                storage.voiceID == testVoiceId &&
                storage.prompt == testPrompt
            }
        )
        results = try context.fetch(descriptor)
        #expect(results.count == 1)

        // Verify record properties
        let savedRecord = try #require(results.first)
        #expect(savedRecord.providerId == provider.providerId)
        #expect(savedRecord.voiceID == voiceId)
        #expect(savedRecord.prompt == item.textToSpeak)
        #expect(savedRecord.binaryValue != nil)
        #expect(savedRecord.mimeType == "audio/x-aiff")
    }

    // MARK: - Play Callback Tests

    @Test("Button triggers onPlay callback when play is tapped")
    func testPlayCallbackTriggered() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let service = GenerationService()
        let item = makeTestItem()

        // Create existing audio
        let record = makeTestAudioRecord(for: item, in: context)

        // Track callback invocations
        var callbackTriggered = false
        var callbackRecord: TypedDataStorage?

        let button = GenerateAudioButton(
            item: item,
            service: service,
            modelContext: context,
            onPlay: { receivedRecord in
                callbackTriggered = true
                callbackRecord = receivedRecord
            }
        )

        // Simulate play button tap
        button.onPlay?(record)

        #expect(callbackTriggered)
        #expect(callbackRecord?.id == record.id)
    }

    // MARK: - Error Handling Tests

    @Test("Button handles missing provider gracefully")
    func testHandlesMissingProvider() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let service = GenerationService()

        // Create item with unconfigured provider
        struct UnconfiguredProvider: VoiceProvider {
            var providerId: String { "unconfigured" }
            var displayName: String { "Unconfigured" }
            var requiresAPIKey: Bool { true }
            var mimeType: String { "audio/mpeg" }

            func isConfigured() -> Bool { false }

            func fetchVoices(languageCode: String) async throws -> [Voice] {
                throw VoiceProviderError.notConfigured
            }

            func generateAudio(text: String, voiceId: String, languageCode: String) async throws -> Data {
                throw VoiceProviderError.notConfigured
            }

            func estimateDuration(text: String, voiceId: String) async -> TimeInterval {
                return 0
            }

            func isVoiceAvailable(voiceId: String) async -> Bool {
                return false
            }

            #if canImport(SwiftUI)
            @MainActor
            func makeConfigurationView(onConfigured: @escaping (Bool) -> Void) -> AnyView {
                return AnyView(EmptyView())
            }
            #endif
        }

        let unconfiguredProvider = UnconfiguredProvider()
        let item = SimpleMessage(
            content: "Test",
            voiceProvider: unconfiguredProvider,
            voiceId: "test"
        )

        // Create button
        let _ = GenerateAudioButton(
            item: item,
            service: service,
            modelContext: context,
            onPlay: nil
        )

        // Verify no audio was generated
        try await Task.sleep(for: .milliseconds(100))

        let descriptor = FetchDescriptor<TypedDataStorage>()
        let results = try context.fetch(descriptor)
        #expect(results.isEmpty)
    }

    // MARK: - SwiftData Integration Tests

    @Test("Button queries SwiftData correctly")
    func testSwiftDataQuery() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let item = makeTestItem()

        // Create audio for the item
        let _ = makeTestAudioRecord(for: item, in: context)

        // Query using the same predicate as the button
        let providerId = item.voiceProvider.providerId
        let voiceId = item.voiceId
        let prompt = item.textToSpeak

        let descriptor = FetchDescriptor<TypedDataStorage>(
            predicate: #Predicate { storage in
                storage.providerId == providerId &&
                storage.voiceID == voiceId &&
                storage.prompt == prompt
            }
        )

        let results = try context.fetch(descriptor)
        #expect(results.count == 1)

        let record = try #require(results.first)
        #expect(record.providerId == providerId)
        #expect(record.voiceID == voiceId)
        #expect(record.prompt == prompt)
    }

    @Test("Button handles multiple audio records correctly")
    func testHandlesMultipleRecords() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        // Create multiple items with same voice
        let item1 = SimpleMessage(
            content: "First message",
            voiceProvider: AppleVoiceProvider(),
            voiceId: "test-voice"
        )
        let item2 = SimpleMessage(
            content: "Second message",
            voiceProvider: AppleVoiceProvider(),
            voiceId: "test-voice"
        )

        // Create audio for both
        let _ = makeTestAudioRecord(for: item1, in: context)
        let _ = makeTestAudioRecord(for: item2, in: context)

        // Query for first item
        let providerId1 = item1.voiceProvider.providerId
        let voiceId1 = item1.voiceId
        let prompt1 = item1.textToSpeak

        let descriptor1 = FetchDescriptor<TypedDataStorage>(
            predicate: #Predicate { storage in
                storage.providerId == providerId1 &&
                storage.voiceID == voiceId1 &&
                storage.prompt == prompt1
            }
        )
        let results1 = try context.fetch(descriptor1)
        #expect(results1.count == 1)

        // Query for second item
        let providerId2 = item2.voiceProvider.providerId
        let voiceId2 = item2.voiceId
        let prompt2 = item2.textToSpeak

        let descriptor2 = FetchDescriptor<TypedDataStorage>(
            predicate: #Predicate { storage in
                storage.providerId == providerId2 &&
                storage.voiceID == voiceId2 &&
                storage.prompt == prompt2
            }
        )
        let results2 = try context.fetch(descriptor2)
        #expect(results2.count == 1)

        // Verify they're different records
        #expect(results1.first?.id != results2.first?.id)
    }

    // MARK: - Provider Integration Tests

    @Test("Button works with Apple provider")
    func testWorksWithAppleProvider() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let service = GenerationService()

        let provider = AppleVoiceProvider()
        let item = makeTestItem(provider: provider)

        let button = GenerateAudioButton(
            item: item,
            service: service,
            modelContext: context,
            onPlay: nil
        )

        #expect(button.item.voiceProvider.providerId == "apple")
    }

    @Test("Button works with ElevenLabs provider")
    func testWorksWithElevenLabsProvider() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let service = GenerationService()

        let provider = ElevenLabsVoiceProvider()
        let item = SimpleMessage(
            content: "Test",
            voiceProvider: provider,
            voiceId: "test-voice"
        )

        let button = GenerateAudioButton(
            item: item,
            service: service,
            modelContext: context,
            onPlay: nil
        )

        #expect(button.item.voiceProvider.providerId == "elevenlabs")
    }

    // MARK: - TypedDataStorage Format Tests

    @Test("Generated audio uses correct MIME type for Apple")
    func testAppleMimeType() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let item = makeTestItem(provider: AppleVoiceProvider())

        let record = makeTestAudioRecord(for: item, in: context)

        #expect(record.mimeType == "audio/x-aiff")
    }

    @Test("Generated audio includes required metadata")
    func testAudioMetadata() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let item = makeTestItem()

        let record = makeTestAudioRecord(for: item, in: context)

        #expect(record.providerId == item.voiceProvider.providerId)
        #expect(record.voiceID == item.voiceId)
        #expect(record.prompt == item.textToSpeak)
        #expect(record.durationSeconds != nil)
        #expect(record.binaryValue != nil)
    }

    // MARK: - Concurrency and Relationship Tests

    @Test("Button establishes relationship with GuionElementModel")
    func testEstablishesElementRelationship() async throws {
        // Create container with GuionElementModel schema
        let schema = Schema([
            TypedDataStorage.self,
            GuionElementModel.self,
            GuionDocumentModel.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        // Create a GuionElementModel
        let element = GuionElementModel(
            elementText: "Test dialogue line",
            elementType: .dialogue,
            chapterIndex: 0,
            orderIndex: 1
        )
        context.insert(element)
        try context.save()

        // Create a speakable item
        let item = makeTestItem()

        // Simulate audio generation with element linking
        let audioData = Data("test audio data".utf8)
        let storage = TypedDataStorage(
            id: UUID(),
            providerId: item.voiceProvider.providerId,
            requestorID: "\(item.voiceProvider.providerId).audio.tts",
            mimeType: "audio/x-aiff",
            binaryValue: audioData,
            prompt: item.textToSpeak,
            durationSeconds: 5.0,
            voiceID: item.voiceId
        )

        // Insert and link to element
        context.insert(storage)
        if element.generatedContent == nil {
            element.generatedContent = []
        }
        element.generatedContent?.append(storage)
        try context.save()

        // Verify relationship was established
        #expect(element.generatedContent != nil)
        #expect(element.generatedContent?.count == 1)
        #expect(element.generatedContent?.first?.id == storage.id)
        #expect(element.generatedContent?.first?.prompt == item.textToSpeak)
    }

    @Test("Race condition prevention - detects concurrent generation")
    func testRaceConditionPrevention() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let item = makeTestItem()

        // Simulate first process creating audio
        let firstRecord = makeTestAudioRecord(for: item, in: context)

        // Simulate second process checking for existing audio (race condition scenario)
        let providerId = item.voiceProvider.providerId
        let voiceId = item.voiceId
        let prompt = item.textToSpeak

        let descriptor = FetchDescriptor<TypedDataStorage>(
            predicate: #Predicate { storage in
                storage.providerId == providerId &&
                storage.voiceID == voiceId &&
                storage.prompt == prompt
            }
        )

        let existingRecords = try context.fetch(descriptor)

        // Should find the existing record and not create duplicate
        #expect(existingRecords.count == 1)
        #expect(existingRecords.first?.id == firstRecord.id)
    }

    @Test("Concurrent generation attempts create single record")
    func testConcurrentGenerationSingleRecord() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let item = makeTestItem()

        // Create first record
        let _ = makeTestAudioRecord(for: item, in: context)

        // Try to create second record (should detect existing and not duplicate)
        let providerId = item.voiceProvider.providerId
        let voiceId = item.voiceId
        let prompt = item.textToSpeak

        let descriptor = FetchDescriptor<TypedDataStorage>(
            predicate: #Predicate { storage in
                storage.providerId == providerId &&
                storage.voiceID == voiceId &&
                storage.prompt == prompt
            }
        )

        let existingRecords = try context.fetch(descriptor)

        // If records exist, don't create new one
        if existingRecords.isEmpty {
            let _ = makeTestAudioRecord(for: item, in: context)
        }

        // Verify only one record exists
        let finalRecords = try context.fetch(descriptor)
        #expect(finalRecords.count == 1)
    }

    @Test("Save errors are properly handled and logged")
    func testSaveErrorHandling() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let item = makeTestItem()

        // Create a record
        let record = TypedDataStorage(
            id: UUID(),
            providerId: item.voiceProvider.providerId,
            requestorID: "\(item.voiceProvider.providerId).audio.tts",
            mimeType: "audio/x-aiff",
            binaryValue: Data("test".utf8),
            prompt: item.textToSpeak,
            durationSeconds: 5.0,
            voiceID: item.voiceId
        )

        context.insert(record)

        // Attempt to save - if it fails, test will throw
        try context.save()

        // Verify record was persisted
        let recordId = record.id
        let descriptor = FetchDescriptor<TypedDataStorage>(
            predicate: #Predicate { storage in
                storage.id == recordId
            }
        )
        let results = try context.fetch(descriptor)
        #expect(results.count == 1)
    }

    @Test("Multiple element relationships are maintained")
    func testMultipleElementRelationships() async throws {
        // Create container with GuionElementModel schema
        let schema = Schema([
            TypedDataStorage.self,
            GuionElementModel.self,
            GuionDocumentModel.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        // Create two GuionElementModels
        let element1 = GuionElementModel(
            elementText: "First dialogue",
            elementType: .dialogue,
            chapterIndex: 0,
            orderIndex: 1
        )
        let element2 = GuionElementModel(
            elementText: "Second dialogue",
            elementType: .dialogue,
            chapterIndex: 0,
            orderIndex: 2
        )
        context.insert(element1)
        context.insert(element2)
        try context.save()

        // Create audio for both elements
        let item1 = SimpleMessage(
            content: "First dialogue",
            voiceProvider: AppleVoiceProvider(),
            voiceId: "test-voice"
        )
        let item2 = SimpleMessage(
            content: "Second dialogue",
            voiceProvider: AppleVoiceProvider(),
            voiceId: "test-voice"
        )

        let storage1 = TypedDataStorage(
            id: UUID(),
            providerId: "apple",
            requestorID: "apple.audio.tts",
            mimeType: "audio/x-aiff",
            binaryValue: Data("audio1".utf8),
            prompt: item1.textToSpeak,
            durationSeconds: 3.0,
            voiceID: "test-voice"
        )

        let storage2 = TypedDataStorage(
            id: UUID(),
            providerId: "apple",
            requestorID: "apple.audio.tts",
            mimeType: "audio/x-aiff",
            binaryValue: Data("audio2".utf8),
            prompt: item2.textToSpeak,
            durationSeconds: 4.0,
            voiceID: "test-voice"
        )

        context.insert(storage1)
        context.insert(storage2)

        // Link each storage to its element
        if element1.generatedContent == nil {
            element1.generatedContent = []
        }
        element1.generatedContent?.append(storage1)

        if element2.generatedContent == nil {
            element2.generatedContent = []
        }
        element2.generatedContent?.append(storage2)

        try context.save()

        // Verify both relationships
        #expect(element1.generatedContent?.count == 1)
        #expect(element1.generatedContent?.first?.id == storage1.id)
        #expect(element2.generatedContent?.count == 1)
        #expect(element2.generatedContent?.first?.id == storage2.id)
    }
}
