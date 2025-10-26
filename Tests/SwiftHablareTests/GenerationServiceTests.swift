//
//  GenerationServiceTests.swift
//  SwiftHablareTests
//
//  Comprehensive tests for GenerationService (actor-based audio generation)
//

import XCTest
import SwiftData
import SwiftCompartido
@testable import SwiftHablare

@MainActor
final class GenerationServiceTests: XCTestCase {

    var modelContainer: ModelContainer!
    var modelContext: ModelContext!

    override func setUp() async throws {
        try await super.setUp()

        // Create in-memory model container for testing
        let schema = Schema([VoiceCacheModel.self, TypedDataStorage.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        modelContext = ModelContext(modelContainer)
    }

    override func tearDown() async throws {
        modelContext = nil
        modelContainer = nil
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitializationWithModelContext() {
        let service = GenerationService(modelContext: modelContext)

        // Service should initialize successfully
        XCTAssertNotNil(service)
    }

    func testInitializationWithCustomCacheLifetime() {
        let service = GenerationService(modelContext: modelContext, cacheLifetime: 10.0)

        // Service should initialize with custom cache lifetime
        XCTAssertNotNil(service)
    }

    // MARK: - Audio Generation Tests with Apple Provider

    func testGenerateAudioWithAppleProvider() async throws {
        let service = GenerationService(modelContext: modelContext)

        // Fetch available voices
        let voices = try await service.fetchVoices(from: "apple")

        guard let firstVoice = voices.first else {
            XCTFail("No voices available")
            return
        }

        // Generate audio
        let result = try await service.generate(
            text: "Hello, this is a test.",
            providerId: "apple",
            voiceId: firstVoice.id,
            voiceName: firstVoice.name
        )

        // Verify result
        XCTAssertFalse(result.audioData.isEmpty, "Audio data should not be empty")
        XCTAssertEqual(result.originalText, "Hello, this is a test.")
        XCTAssertEqual(result.voiceId, firstVoice.id)
        XCTAssertEqual(result.voiceName, firstVoice.name)
        XCTAssertEqual(result.providerId, "apple")
        XCTAssertGreaterThan(result.estimatedDuration, 0)
    }

    func testGenerateAudioWithoutVoiceName() async throws {
        let service = GenerationService(modelContext: modelContext)

        let voices = try await service.fetchVoices(from: "apple")

        guard let firstVoice = voices.first else {
            XCTFail("No voices available")
            return
        }

        let result = try await service.generate(
            text: "Test without voice name",
            providerId: "apple",
            voiceId: firstVoice.id
        )

        XCTAssertFalse(result.audioData.isEmpty)
        XCTAssertNil(result.voiceName, "Voice name should be nil when not provided")
    }

    func testGenerateAudioWithCustomMimeType() async throws {
        let service = GenerationService(modelContext: modelContext)

        let voices = try await service.fetchVoices(from: "apple")

        guard let firstVoice = voices.first else {
            XCTFail("No voices available")
            return
        }

        let result = try await service.generate(
            text: "Test with custom MIME type",
            providerId: "apple",
            voiceId: firstVoice.id,
            mimeType: "audio/caf"
        )

        XCTAssertEqual(result.mimeType, "audio/caf", "Should use provided MIME type")
    }

    func testGenerateAudioUsesDefaultMimeType() async throws {
        let service = GenerationService(modelContext: modelContext)

        let voices = try await service.fetchVoices(from: "apple")

        guard let firstVoice = voices.first else {
            XCTFail("No voices available")
            return
        }

        let result = try await service.generate(
            text: "Test default MIME type",
            providerId: "apple",
            voiceId: firstVoice.id
        )

        XCTAssertEqual(result.mimeType, "audio/x-aiff", "Should use Apple's default MIME type")
    }

    // MARK: - GenerationResult Conversion Tests

    func testConvertResultToTypedDataStorage() async throws {
        let service = GenerationService(modelContext: modelContext)

        let voices = try await service.fetchVoices(from: "apple")

        guard let firstVoice = voices.first else {
            XCTFail("No voices available")
            return
        }

        let result = try await service.generate(
            text: "Test conversion",
            providerId: "apple",
            voiceId: firstVoice.id,
            voiceName: firstVoice.name
        )

        // Convert to TypedDataStorage (must be on MainActor)
        let storage = result.toTypedDataStorage()

        XCTAssertEqual(storage.id, result.requestId)
        XCTAssertEqual(storage.providerId, result.providerId)
        XCTAssertEqual(storage.requestorID, "\(result.providerId).audio.tts")
        XCTAssertEqual(storage.mimeType, result.mimeType)
        XCTAssertEqual(storage.binaryValue, result.audioData)
        XCTAssertEqual(storage.prompt, result.originalText)
        XCTAssertEqual(storage.durationSeconds, result.estimatedDuration)
        XCTAssertEqual(storage.voiceID, result.voiceId)
        XCTAssertEqual(storage.voiceName, result.voiceName)
    }

//     func testSaveResultToSwiftData() async throws {
//         
//         let service = GenerationService(voiceProvider: provider)
// 
//         let voices = try await provider.fetchVoices()
// 
//         guard let firstVoice = voices.first else {
//             XCTFail("No voices available")
//             return
//         }
// 
//         let result = try await service.generate(
//             text: "Test SwiftData save",
//             voiceId: firstVoice.id,
//             voiceName: firstVoice.name
//         )
// 
//         // Convert and save to SwiftData
//         let storage = result.toTypedDataStorage()
//         modelContext.insert(storage)
//         try modelContext.save()
// 
//         // Verify it was saved
//         let descriptor = FetchDescriptor<TypedDataStorage>()
//         let allRecords = try modelContext.fetch(descriptor)
// 
//         XCTAssertEqual(allRecords.count, 1)
//         XCTAssertEqual(allRecords[0].id, result.requestId)
//         XCTAssertEqual(allRecords[0].providerId, "apple")
//     }

    // MARK: - Voice Fetching Tests

    func testFetchVoicesFromService() async throws {
        let service = GenerationService(modelContext: modelContext)

        let voices = try await service.fetchVoices(from: "apple")

        XCTAssertFalse(voices.isEmpty, "Should return voices")

        for voice in voices {
            XCTAssertFalse(voice.id.isEmpty)
            XCTAssertFalse(voice.name.isEmpty)
        }
    }

    func testIsVoiceAvailable() async throws {
        let service = GenerationService(modelContext: modelContext)

        let voices = try await service.fetchVoices(from: "apple")

        guard let firstVoice = voices.first else {
            XCTFail("No voices available")
            return
        }

        let isAvailable = await service.isVoiceAvailable(firstVoice.id, from: "apple")
        XCTAssertTrue(isAvailable, "First voice should be available")
    }

    func testIsVoiceAvailableWithInvalidVoice() async {
        let service = GenerationService(modelContext: modelContext)

        let isAvailable = await service.isVoiceAvailable("invalid-voice-id", from: "apple")
        XCTAssertFalse(isAvailable, "Invalid voice should not be available")
    }

    // MARK: - Error Handling Tests

    func testGenerateThrowsWhenProviderNotConfigured() async {
        let service = GenerationService(modelContext: modelContext)

        // Create a mock provider that's not configured and register it
        let provider = MockUnconfiguredProvider()
        await service.registerProvider(provider)

        do {
            _ = try await service.generate(
                text: "Test",
                providerId: "mock-unconfigured",
                voiceId: "voice123"
            )
            XCTFail("Should throw notConfigured error")
        } catch let error as VoiceProviderError {
            if case .notConfigured = error {
                // Expected error
            } else {
                XCTFail("Expected notConfigured error, got \(error)")
            }
        } catch {
            XCTFail("Expected VoiceProviderError.notConfigured, got \(error)")
        }
    }

    func testFetchVoicesThrowsWhenProviderNotConfigured() async {
        let service = GenerationService(modelContext: modelContext)

        let provider = MockUnconfiguredProvider()
        await service.registerProvider(provider)

        do {
            _ = try await service.fetchVoices(from: "mock-unconfigured")
            XCTFail("Should throw notConfigured error")
        } catch let error as VoiceProviderError {
            if case .notConfigured = error {
                // Expected error
            } else {
                XCTFail("Expected notConfigured error, got \(error)")
            }
        } catch {
            XCTFail("Expected VoiceProviderError.notConfigured, got \(error)")
        }
    }

    // MARK: - Provider Registry Tests

    func testDefaultProvidersAreRegistered() async {
        let service = GenerationService(modelContext: modelContext)

        let providers = await service.registeredProviders()

        XCTAssertEqual(providers.count, 2, "Should have 2 default providers")

        let providerIds = Set(providers.map { $0.providerId })
        XCTAssertTrue(providerIds.contains("apple"), "Should include Apple provider")
        XCTAssertTrue(providerIds.contains("elevenlabs"), "Should include ElevenLabs provider")
    }

    func testGetProviderById() async {
        let service = GenerationService(modelContext: modelContext)

        let appleProvider = await service.provider(withId: "apple")
        XCTAssertNotNil(appleProvider, "Should find Apple provider")
        XCTAssertEqual(appleProvider?.providerId, "apple")

        let elevenLabsProvider = await service.provider(withId: "elevenlabs")
        XCTAssertNotNil(elevenLabsProvider, "Should find ElevenLabs provider")
        XCTAssertEqual(elevenLabsProvider?.providerId, "elevenlabs")
    }

    func testGetProviderByIdReturnsNilForUnknown() async {
        let service = GenerationService(modelContext: modelContext)

        let unknownProvider = await service.provider(withId: "unknown")
        XCTAssertNil(unknownProvider, "Should return nil for unknown provider")
    }

    func testIsProviderRegistered() async {
        let service = GenerationService(modelContext: modelContext)

        let isAppleRegistered = await service.isProviderRegistered("apple")
        XCTAssertTrue(isAppleRegistered, "Apple provider should be registered")

        let isElevenLabsRegistered = await service.isProviderRegistered("elevenlabs")
        XCTAssertTrue(isElevenLabsRegistered, "ElevenLabs provider should be registered")

        let isUnknownRegistered = await service.isProviderRegistered("unknown")
        XCTAssertFalse(isUnknownRegistered, "Unknown provider should not be registered")
    }

    func testRegisterCustomProvider() async {
        let service = GenerationService(modelContext: modelContext)

        // Create and register a custom provider
        let customProvider = MockUnconfiguredProvider()
        await service.registerProvider(customProvider)

        // Verify it's registered
        let isRegistered = await service.isProviderRegistered("mock-unconfigured")
        XCTAssertTrue(isRegistered, "Custom provider should be registered")

        // Verify it can be retrieved
        let retrievedProvider = await service.provider(withId: "mock-unconfigured")
        XCTAssertNotNil(retrievedProvider)
        XCTAssertEqual(retrievedProvider?.providerId, "mock-unconfigured")

        // Verify total count includes custom provider
        let allProviders = await service.registeredProviders()
        XCTAssertEqual(allProviders.count, 3, "Should have 3 providers (2 default + 1 custom)")
    }

    func testRegisterProviderReplacesExisting() async {
        let service = GenerationService(modelContext: modelContext)

        // Get original Apple provider
        let originalApple = await service.provider(withId: "apple")
        XCTAssertNotNil(originalApple)

        // Create a new Apple provider and register it
        let newAppleProvider = AppleVoiceProvider()
        await service.registerProvider(newAppleProvider)

        // Verify it's still registered (replaced, not duplicated)
        let allProviders = await service.registeredProviders()
        XCTAssertEqual(allProviders.count, 2, "Should still have 2 providers")

        let appleProviders = allProviders.filter { $0.providerId == "apple" }
        XCTAssertEqual(appleProviders.count, 1, "Should have exactly one Apple provider")
    }

    func testRegisteredProvidersIncludesAllProviders() async {
        let service = GenerationService(modelContext: modelContext)

        // Register additional providers
        let customProvider1 = MockConfiguredProvider(id: "custom1")
        let customProvider2 = MockConfiguredProvider(id: "custom2")

        await service.registerProvider(customProvider1)
        await service.registerProvider(customProvider2)

        let allProviders = await service.registeredProviders()
        XCTAssertEqual(allProviders.count, 4, "Should have 4 providers (2 default + 2 custom)")

        let providerIds = Set(allProviders.map { $0.providerId })
        XCTAssertTrue(providerIds.contains("apple"))
        XCTAssertTrue(providerIds.contains("elevenlabs"))
        XCTAssertTrue(providerIds.contains("custom1"))
        XCTAssertTrue(providerIds.contains("custom2"))
    }

    // MARK: - Voice Fetching from Registry Tests

    func testFetchVoicesFromSpecificProvider() async throws {
        let service = GenerationService(modelContext: modelContext)

        // Fetch voices from Apple provider by ID
        let appleVoices = try await service.fetchVoices(from: "apple")

        XCTAssertFalse(appleVoices.isEmpty, "Should fetch voices from Apple provider")
        XCTAssertTrue(appleVoices.allSatisfy { $0.providerId == "apple" })
    }

    func testFetchVoicesFromUnknownProviderThrows() async {
        let service = GenerationService(modelContext: modelContext)

        do {
            _ = try await service.fetchVoices(from: "unknown-provider")
            XCTFail("Should throw error for unknown provider")
        } catch let error as VoiceProviderError {
            if case .notConfigured = error {
                // Expected error
            } else {
                XCTFail("Expected notConfigured error, got \(error)")
            }
        } catch {
            XCTFail("Expected VoiceProviderError.notConfigured, got \(error)")
        }
    }

    func testFetchVoicesFromUnconfiguredProviderThrows() async {
        let service = GenerationService(modelContext: modelContext)

        // Register unconfigured provider
        let unconfiguredProvider = MockUnconfiguredProvider()
        await service.registerProvider(unconfiguredProvider)

        do {
            _ = try await service.fetchVoices(from: "mock-unconfigured")
            XCTFail("Should throw error for unconfigured provider")
        } catch let error as VoiceProviderError {
            if case .notConfigured = error {
                // Expected error
            } else {
                XCTFail("Expected notConfigured error, got \(error)")
            }
        } catch {
            XCTFail("Expected VoiceProviderError.notConfigured, got \(error)")
        }
    }

    func testFetchAllVoices() async throws {
        let service = GenerationService(modelContext: modelContext)

        // Register a custom configured provider
        let customProvider = MockConfiguredProvider(id: "custom1")
        await service.registerProvider(customProvider)

        // Fetch all voices
        let allVoices = try await service.fetchAllVoices()

        // Should have voices from Apple (always configured) and custom provider
        XCTAssertGreaterThanOrEqual(allVoices.count, 1, "Should have at least Apple voices")

        // Apple voices should be present
        if let appleVoices = allVoices["apple"] {
            XCTAssertFalse(appleVoices.isEmpty, "Apple provider should return voices")
            XCTAssertTrue(appleVoices.allSatisfy { $0.providerId == "apple" })
        }

        // Custom provider voices should be present
        if let customVoices = allVoices["custom1"] {
            XCTAssertFalse(customVoices.isEmpty, "Custom provider should return voices")
            XCTAssertTrue(customVoices.allSatisfy { $0.providerId == "custom1" })
        }
    }

    func testFetchAllVoicesSkipsUnconfiguredProviders() async throws {
        let service = GenerationService(modelContext: modelContext)

        // Register unconfigured provider
        let unconfiguredProvider = MockUnconfiguredProvider()
        await service.registerProvider(unconfiguredProvider)

        // Fetch all voices
        let allVoices = try await service.fetchAllVoices()

        // Should not include unconfigured provider
        XCTAssertNil(allVoices["mock-unconfigured"], "Should skip unconfigured providers")

        // Should still have Apple voices
        XCTAssertNotNil(allVoices["apple"], "Should include configured providers")
    }

    func testFetchAllVoicesSkipsProvidersWithErrors() async throws {
        let service = GenerationService(modelContext: modelContext)

        // Register provider that throws errors
        let errorProvider = MockErrorProvider()
        await service.registerProvider(errorProvider)

        // Fetch all voices
        let allVoices = try await service.fetchAllVoices()

        // Should not include error provider
        XCTAssertNil(allVoices["mock-error"], "Should skip providers that throw errors")

        // Should still have Apple voices
        XCTAssertNotNil(allVoices["apple"], "Should include working providers")
    }

    func testFetchVoicesFromMultipleProviders() async throws {
        let service = GenerationService(modelContext: modelContext)

        // Register custom providers
        let custom1 = MockConfiguredProvider(id: "custom1")
        let custom2 = MockConfiguredProvider(id: "custom2")

        await service.registerProvider(custom1)
        await service.registerProvider(custom2)

        // Fetch voices from each provider
        let appleVoices = try await service.fetchVoices(from: "apple")
        let custom1Voices = try await service.fetchVoices(from: "custom1")
        let custom2Voices = try await service.fetchVoices(from: "custom2")

        XCTAssertFalse(appleVoices.isEmpty)
        XCTAssertFalse(custom1Voices.isEmpty)
        XCTAssertFalse(custom2Voices.isEmpty)

        XCTAssertTrue(appleVoices.allSatisfy { $0.providerId == "apple" })
        XCTAssertTrue(custom1Voices.allSatisfy { $0.providerId == "custom1" })
        XCTAssertTrue(custom2Voices.allSatisfy { $0.providerId == "custom2" })
    }

    // MARK: - Voice Cache Tests (SwiftData)

    func testVoiceCachingBasic() async throws {
        // Use a short cache lifetime for testing
        let service = GenerationService(modelContext: modelContext, cacheLifetime: 10.0)

        // First call - should fetch from provider
        let hasCache1 = await service.hasValidCache(for: "apple")
        XCTAssertFalse(hasCache1)

        let voices1 = try await service.fetchVoices(from: "apple")
        XCTAssertFalse(voices1.isEmpty)

        // Second call - should return cached voices
        let hasCache2 = await service.hasValidCache(for: "apple")
        XCTAssertTrue(hasCache2)

        let voices2 = try await service.fetchVoices(from: "apple")
        XCTAssertEqual(voices1.count, voices2.count)

        // Cache should be valid
        let hasCache3 = await service.hasValidCache(for: "apple")
        XCTAssertTrue(hasCache3)

        // Verify voices were persisted to SwiftData
        let descriptor = VoiceCacheModel.fetchDescriptor(forProvider: "apple")
        let cachedModels = try modelContext.fetch(descriptor)
        XCTAssertEqual(cachedModels.count, voices1.count)
    }

    func testVoiceCacheExpiration() async throws {
        // Use very short cache lifetime for testing
        let service = GenerationService(modelContext: modelContext, cacheLifetime: 0.1)  // 100ms

        // Fetch voices
        let voices1 = try await service.fetchVoices(from: "apple")
        XCTAssertFalse(voices1.isEmpty)

        // Cache should be valid immediately
        let hasCache1 = await service.hasValidCache(for: "apple")
        XCTAssertTrue(hasCache1)

        // Wait for cache to expire
        try await Task.sleep(for: .milliseconds(150))

        // Cache should be expired
        let hasCache2 = await service.hasValidCache(for: "apple")
        XCTAssertFalse(hasCache2)

        // Fetch again - should refresh cache
        let voices2 = try await service.fetchVoices(from: "apple")
        XCTAssertFalse(voices2.isEmpty)

        // Cache should be valid again
        let hasCache3 = await service.hasValidCache(for: "apple")
        XCTAssertTrue(hasCache3)
    }

    func testRefreshVoices() async throws {
        let service = GenerationService(modelContext: modelContext)

        // Initial fetch
        let voices1 = try await service.fetchVoices(from: "apple")
        XCTAssertFalse(voices1.isEmpty)
        let hasCache1 = await service.hasValidCache(for: "apple")
        XCTAssertTrue(hasCache1)

        // Refresh voices
        let refreshedVoices = try await service.refreshVoices(from: "apple")
        XCTAssertFalse(refreshedVoices.isEmpty)

        // Cache should still be valid
        let hasCache2 = await service.hasValidCache(for: "apple")
        XCTAssertTrue(hasCache2)

        // Verify we can fetch from cache
        let voices2 = try await service.fetchVoices(from: "apple")
        XCTAssertEqual(voices2.count, refreshedVoices.count)
    }

    func testClearVoiceCache() async throws {
        let service = GenerationService(modelContext: modelContext)

        // Fetch voices to populate cache
        _ = try await service.fetchVoices(from: "apple")
        let hasCache1 = await service.hasValidCache(for: "apple")
        XCTAssertTrue(hasCache1)

        // Verify SwiftData has cached voices
        let beforeClear = try modelContext.fetch(VoiceCacheModel.fetchDescriptor(forProvider: "apple"))
        XCTAssertFalse(beforeClear.isEmpty)

        // Clear cache
        try await service.clearVoiceCache(for: "apple")

        // Cache should be invalid
        let hasCache2 = await service.hasValidCache(for: "apple")
        XCTAssertFalse(hasCache2)

        // Verify SwiftData cache was deleted
        let afterClear = try modelContext.fetch(VoiceCacheModel.fetchDescriptor(forProvider: "apple"))
        XCTAssertTrue(afterClear.isEmpty)

        // Next fetch should work
        let voices = try await service.fetchVoices(from: "apple")
        XCTAssertFalse(voices.isEmpty)
        let hasCache3 = await service.hasValidCache(for: "apple")
        XCTAssertTrue(hasCache3)
    }

    func testClearAllVoiceCaches() async throws {
        let service = GenerationService(modelContext: modelContext)

        // Fetch voices from multiple providers
        _ = try await service.fetchVoices(from: "apple")
        let hasCache1 = await service.hasValidCache(for: "apple")
        XCTAssertTrue(hasCache1)

        // Register and fetch from custom provider
        let customProvider = MockConfiguredProvider(id: "custom")
        await service.registerProvider(customProvider)
        _ = try await service.fetchVoices(from: "custom")
        let hasCache2 = await service.hasValidCache(for: "custom")
        XCTAssertTrue(hasCache2)

        // Verify both are in SwiftData
        let allBefore = try modelContext.fetch(FetchDescriptor<VoiceCacheModel>())
        XCTAssertGreaterThan(allBefore.count, 0)

        // Clear all caches
        try await service.clearAllVoiceCaches()

        // Both caches should be invalid
        let hasCache3 = await service.hasValidCache(for: "apple")
        XCTAssertFalse(hasCache3)
        let hasCache4 = await service.hasValidCache(for: "custom")
        XCTAssertFalse(hasCache4)

        // Verify all SwiftData cache was deleted
        let allAfter = try modelContext.fetch(FetchDescriptor<VoiceCacheModel>())
        XCTAssertTrue(allAfter.isEmpty)
    }

    func testCachePerProvider() async throws {
        let service = GenerationService(modelContext: modelContext, cacheLifetime: 10.0)

        // Register custom provider
        let customProvider = MockConfiguredProvider(id: "custom")
        await service.registerProvider(customProvider)

        // Fetch from both providers
        let appleVoices = try await service.fetchVoices(from: "apple")
        let customVoices = try await service.fetchVoices(from: "custom")

        // Both should be cached separately
        let hasCache1 = await service.hasValidCache(for: "apple")
        XCTAssertTrue(hasCache1)
        let hasCache2 = await service.hasValidCache(for: "custom")
        XCTAssertTrue(hasCache2)

        // Verify both are in SwiftData
        let appleCached = try modelContext.fetch(VoiceCacheModel.fetchDescriptor(forProvider: "apple"))
        let customCached = try modelContext.fetch(VoiceCacheModel.fetchDescriptor(forProvider: "custom"))
        XCTAssertEqual(appleCached.count, appleVoices.count)
        XCTAssertEqual(customCached.count, customVoices.count)

        // Clear one cache
        try await service.clearVoiceCache(for: "apple")

        // Only Apple cache should be invalid
        let hasCache3 = await service.hasValidCache(for: "apple")
        XCTAssertFalse(hasCache3)
        let hasCache4 = await service.hasValidCache(for: "custom")
        XCTAssertTrue(hasCache4)

        // Verify only Apple cache was deleted from SwiftData
        let appleAfterClear = try modelContext.fetch(VoiceCacheModel.fetchDescriptor(forProvider: "apple"))
        let customAfterClear = try modelContext.fetch(VoiceCacheModel.fetchDescriptor(forProvider: "custom"))
        XCTAssertTrue(appleAfterClear.isEmpty)
        XCTAssertFalse(customAfterClear.isEmpty)

        // Fetch from custom should still return cached data
        let cachedCustomVoices = try await service.fetchVoices(from: "custom")
        XCTAssertEqual(cachedCustomVoices.count, customVoices.count)
    }

    func testRefreshUnconfiguredProvider() async throws {
        let service = GenerationService(modelContext: modelContext)

        // Try to refresh non-existent provider
        do {
            _ = try await service.refreshVoices(from: "nonexistent")
            XCTFail("Should throw error for non-existent provider")
        } catch VoiceProviderError.notConfigured {
            // Expected
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func testCacheLifetimeDefault() async throws {
        let service = GenerationService(modelContext: modelContext)

        // Fetch voices
        let voices = try await service.fetchVoices(from: "apple")
        XCTAssertFalse(voices.isEmpty)

        // Cache should be valid (24 hours is way more than test time)
        let hasCache = await service.hasValidCache(for: "apple")
        XCTAssertTrue(hasCache)
    }

    // NOTE: testCachingWithoutModelContext removed as ModelContext is now required

    // MARK: - Concurrency Tests

    func testConcurrentAudioGeneration() async throws {
        let service = GenerationService(modelContext: modelContext)

        let voices = try await service.fetchVoices(from: "apple")

        guard let firstVoice = voices.first else {
            XCTFail("No voices available")
            return
        }

        // Generate multiple audio files concurrently
        await withThrowingTaskGroup(of: GenerationResult.self) { group in
            for i in 0..<3 {
                group.addTask {
                    try await service.generate(
                        text: "Concurrent test \(i)",
                        providerId: "apple",
                        voiceId: firstVoice.id
                    )
                }
            }

            var results: [GenerationResult] = []
            do {
                for try await result in group {
                    results.append(result)
                }

                XCTAssertEqual(results.count, 3, "Should generate 3 results")

                for result in results {
                    XCTAssertFalse(result.audioData.isEmpty)
                }
            } catch {
                XCTFail("Concurrent generation failed: \(error)")
            }
        }
    }

    func testActorIsolationEnsuresThreadSafety() async throws {
        let service = GenerationService(modelContext: modelContext)

        let voices = try await service.fetchVoices(from: "apple")

        guard let firstVoice = voices.first else {
            XCTFail("No voices available")
            return
        }

        // This test verifies that the actor isolation works correctly
        // by performing multiple concurrent operations
        async let result1 = service.generate(text: "Test 1", providerId: "apple", voiceId: firstVoice.id)
        async let result2 = service.generate(text: "Test 2", providerId: "apple", voiceId: firstVoice.id)
        async let voices1 = service.fetchVoices(from: "apple")
        async let available1 = service.isVoiceAvailable(firstVoice.id, from: "apple")

        let (r1, r2, v1, a1) = try await (result1, result2, voices1, available1)

        XCTAssertFalse(r1.audioData.isEmpty)
        XCTAssertFalse(r2.audioData.isEmpty)
        XCTAssertFalse(v1.isEmpty)
        XCTAssertTrue(a1)
    }

    // MARK: - Integration with SwiftData Tests

    // NOTE: This test is commented out due to TypedDataStorage import issues
    /* func testMultipleGenerationsAndSaves() async throws {
        
        let service = GenerationService(voiceProvider: provider)

        let voices = try await service.fetchVoices()

        guard let firstVoice = voices.first else {
            XCTFail("No voices available")
            return
        }

        let texts = ["Test 1", "Test 2", "Test 3"]

        for text in texts {
            let result = try await service.generate(
                text: text,
                voiceId: firstVoice.id
            )

            let storage = result.toTypedDataStorage()
            modelContext.insert(storage)
        }

        try modelContext.save()

        // Verify all were saved
        let descriptor = FetchDescriptor<TypedDataStorage>()
        let allRecords = try modelContext.fetch(descriptor)

        XCTAssertEqual(allRecords.count, 3, "Should have saved 3 records")

        for (index, record) in allRecords.enumerated() {
            XCTAssertEqual(record.prompt, texts[index])
            XCTAssertFalse(record.binaryValue?.isEmpty ?? true)
        }
    } */

    // MARK: - Performance Tests
    // Note: Commented out due to Swift 6 strict concurrency requirements and timeout issues

    /* func testGenerationPerformance() async throws {
        
        let service = GenerationService(voiceProvider: provider)

        let voices = try await service.fetchVoices()

        guard let firstVoice = voices.first else {
            XCTFail("No voices available")
            return
        }

        measure {
            let expectation = XCTestExpectation(description: "Generate audio")

            Task {
                _ = try await service.generate(
                    text: "Performance test",
                    voiceId: firstVoice.id
                )
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 10.0)
        }
    } */
}

// MARK: - Mock Providers

/// Mock provider that is not configured
final class MockUnconfiguredProvider: VoiceProvider, @unchecked Sendable {
    let providerId = "mock-unconfigured"
    let displayName = "Mock Unconfigured"
    let requiresAPIKey = true

    func isConfigured() -> Bool {
        return false
    }

    func fetchVoices() async throws -> [Voice] {
        throw VoiceProviderError.notConfigured
    }

    func generateAudio(text: String, voiceId: String) async throws -> Data {
        throw VoiceProviderError.notConfigured
    }

    func estimateDuration(text: String, voiceId: String) async -> TimeInterval {
        return 1.0
    }

    func isVoiceAvailable(voiceId: String) async -> Bool {
        return false
    }
}

/// Mock provider that is configured (for testing registry)
final class MockConfiguredProvider: VoiceProvider, @unchecked Sendable {
    let providerId: String
    let displayName: String
    let requiresAPIKey = false

    init(id: String) {
        self.providerId = id
        self.displayName = "Mock Provider \(id)"
    }

    func isConfigured() -> Bool {
        return true
    }

    func fetchVoices() async throws -> [Voice] {
        return [
            Voice(
                id: "\(providerId)-voice1",
                name: "Voice 1",
                description: "Mock voice for testing",
                providerId: providerId,
                language: "en",
                locality: "US",
                gender: "neutral"
            )
        ]
    }

    func generateAudio(text: String, voiceId: String) async throws -> Data {
        return Data("mock-audio-data".utf8)
    }

    func estimateDuration(text: String, voiceId: String) async -> TimeInterval {
        return 1.0
    }

    func isVoiceAvailable(voiceId: String) async -> Bool {
        return voiceId.hasPrefix(providerId)
    }
}

/// Mock provider that throws errors (for testing error handling)
final class MockErrorProvider: VoiceProvider, @unchecked Sendable {
    let providerId = "mock-error"
    let displayName = "Mock Error Provider"
    let requiresAPIKey = false

    func isConfigured() -> Bool {
        return true
    }

    func fetchVoices() async throws -> [Voice] {
        throw VoiceProviderError.invalidResponse
    }

    func generateAudio(text: String, voiceId: String) async throws -> Data {
        throw VoiceProviderError.invalidResponse
    }

    func estimateDuration(text: String, voiceId: String) async -> TimeInterval {
        return 1.0
    }

    func isVoiceAvailable(voiceId: String) async -> Bool {
        return false
    }
}
