//
//  GenerationServiceTests.swift
//  SwiftHablareTests
//
//  Comprehensive tests for GenerationService (actor-based audio generation)
//

import Testing
import SwiftData
import SwiftCompartido
import SwiftUI
@testable import SwiftHablare

@Suite("GenerationService Tests")
@MainActor
struct GenerationServiceTests {

    // MARK: - Initialization Tests

    @Test("Initialization with model context")
    func testInitializationWithModelContext() {
        let service = GenerationService()
        #expect(service != nil)
    }

    @Test("Initialization with custom cache lifetime")
    func testInitializationWithCustomCacheLifetime() {
        let service = GenerationService(cacheLifetime: 10.0)
        #expect(service != nil)
    }

    // MARK: - Audio Generation Tests with Apple Provider

    @Test("Generate audio with Apple provider")
    func testGenerateAudioWithAppleProvider() async throws {
        let container = try TestFixtures.makeTestContainer()
        let context = ModelContext(container)
        let service = GenerationService()

        let voices = try await service.fetchVoices(from: "apple", using: context)

        guard let firstVoice = voices.first else {
            Issue.record("No voices available")
            return
        }

        let result = try await service.generate(
            text: "Hello, this is a test.",
            providerId: "apple",
            voiceId: firstVoice.id,
            voiceName: firstVoice.name
        )

        #expect(!result.audioData.isEmpty)
        #expect(result.originalText == "Hello, this is a test.")
        #expect(result.voiceId == firstVoice.id)
        #expect(result.voiceName == firstVoice.name)
        #expect(result.providerId == "apple")
        #expect(result.estimatedDuration > 0)
    }

    @Test("Generate audio without voice name")
    func testGenerateAudioWithoutVoiceName() async throws {
        let container = try TestFixtures.makeTestContainer()
        let context = ModelContext(container)
        let service = GenerationService()

        let voices = try await service.fetchVoices(from: "apple", using: context)

        guard let firstVoice = voices.first else {
            Issue.record("No voices available")
            return
        }

        let result = try await service.generate(
            text: "Test without voice name",
            providerId: "apple",
            voiceId: firstVoice.id
        )

        #expect(!result.audioData.isEmpty)
        #expect(result.voiceName == nil)
    }

    @Test("Generate audio with custom MIME type")
    func testGenerateAudioWithCustomMimeType() async throws {
        let container = try TestFixtures.makeTestContainer()
        let context = ModelContext(container)
        let service = GenerationService()

        let voices = try await service.fetchVoices(from: "apple", using: context)

        guard let firstVoice = voices.first else {
            Issue.record("No voices available")
            return
        }

        let result = try await service.generate(
            text: "Test with custom MIME type",
            providerId: "apple",
            voiceId: firstVoice.id,
            mimeType: "audio/caf"
        )

        #expect(result.mimeType == "audio/caf")
    }

    @Test("Generate audio uses default MIME type")
    func testGenerateAudioUsesDefaultMimeType() async throws {
        let container = try TestFixtures.makeTestContainer()
        let context = ModelContext(container)
        let service = GenerationService()

        let voices = try await service.fetchVoices(from: "apple", using: context)

        guard let firstVoice = voices.first else {
            Issue.record("No voices available")
            return
        }

        let result = try await service.generate(
            text: "Test default MIME type",
            providerId: "apple",
            voiceId: firstVoice.id
        )

        #expect(result.mimeType == "audio/x-aiff")
    }

    // MARK: - GenerationResult Conversion Tests

    @Test("Convert result to TypedDataStorage")
    func testConvertResultToTypedDataStorage() async throws {
        let container = try TestFixtures.makeTestContainer()
        let context = ModelContext(container)
        let service = GenerationService()

        let voices = try await service.fetchVoices(from: "apple", using: context)

        guard let firstVoice = voices.first else {
            Issue.record("No voices available")
            return
        }

        let result = try await service.generate(
            text: "Test conversion",
            providerId: "apple",
            voiceId: firstVoice.id,
            voiceName: firstVoice.name
        )

        let storage = result.toTypedDataStorage()

        #expect(storage.id == result.requestId)
        #expect(storage.providerId == result.providerId)
        #expect(storage.requestorID == "\(result.providerId).audio.tts")
        #expect(storage.mimeType == result.mimeType)
        #expect(storage.binaryValue == result.audioData)
        #expect(storage.prompt == result.originalText)
        #expect(storage.durationSeconds == result.estimatedDuration)
        #expect(storage.voiceID == result.voiceId)
        #expect(storage.voiceName == result.voiceName)
    }

    // MARK: - Voice Fetching Tests

    @Test("Fetch voices from service")
    func testFetchVoicesFromService() async throws {
        let container = try TestFixtures.makeTestContainer()
        let context = ModelContext(container)
        let service = GenerationService()

        let voices = try await service.fetchVoices(from: "apple", using: context)

        #expect(!voices.isEmpty)

        for voice in voices {
            #expect(!voice.id.isEmpty)
            #expect(!voice.name.isEmpty)
        }
    }

    @Test("Check if voice is available")
    func testIsVoiceAvailable() async throws {
        let container = try TestFixtures.makeTestContainer()
        let context = ModelContext(container)
        let service = GenerationService()

        let voices = try await service.fetchVoices(from: "apple", using: context)

        guard let firstVoice = voices.first else {
            Issue.record("No voices available")
            return
        }

        let isAvailable = await service.isVoiceAvailable(firstVoice.id, from: "apple")
        #expect(isAvailable)
    }

    @Test("Check if invalid voice is available")
    func testIsVoiceAvailableWithInvalidVoice() async {
        let service = GenerationService()

        let isAvailable = await service.isVoiceAvailable("invalid-voice-id", from: "apple")
        #expect(!isAvailable)
    }

    // MARK: - Error Handling Tests

    @Test("Generate throws when provider not configured")
    func testGenerateThrowsWhenProviderNotConfigured() async {
        let service = GenerationService()

        let provider = TestFixtures.makeUnconfiguredProvider()
        await service.registerProvider(provider)

        do {
            _ = try await service.generate(
                text: "Test",
                providerId: "mock-unconfigured",
                voiceId: "voice123"
            )
            Issue.record("Should throw notConfigured error")
        } catch let error as VoiceProviderError {
            if case .notConfigured = error {
                // Expected error
            } else {
                Issue.record("Expected notConfigured error, got \(error)")
            }
        } catch {
            Issue.record("Expected VoiceProviderError.notConfigured, got \(error)")
        }
    }

    @Test("Fetch voices throws when provider not configured")
    func testFetchVoicesThrowsWhenProviderNotConfigured() async {
        let container = try! TestFixtures.makeTestContainer()
        let context = ModelContext(container)
        let service = GenerationService()

        let provider = TestFixtures.makeUnconfiguredProvider()
        await service.registerProvider(provider)

        do {
            _ = try await service.fetchVoices(from: "mock-unconfigured", using: context)
            Issue.record("Should throw notConfigured error")
        } catch let error as VoiceProviderError {
            if case .notConfigured = error {
                // Expected error
            } else {
                Issue.record("Expected notConfigured error, got \(error)")
            }
        } catch {
            Issue.record("Expected VoiceProviderError.notConfigured, got \(error)")
        }
    }

    // MARK: - Provider Registry Tests

    @Test("Default providers are registered")
    func testDefaultProvidersAreRegistered() async {
        let setup = makeTestUserDefaults(suiteName: "testDefaultProvidersAreRegistered")
        defer { setup.cleanup() }
        let registry = VoiceProviderRegistry(userDefaults: setup.defaults)
        let service = GenerationService(providerRegistry: registry)

        let providers = await service.registeredProviders()

        #expect(providers.count == 2)

        let providerIds = Set(providers.map { $0.providerId })
        #expect(providerIds.contains("apple"))
        #expect(providerIds.contains("elevenlabs"))
    }

    @Test("Apple provider is always configured")
    func testAppleProviderIsAlwaysConfigured() async {
        let service = GenerationService()

        guard let appleProvider = await service.provider(withId: "apple") else {
            Issue.record("Apple provider should be registered")
            return
        }

        #expect(appleProvider.isConfigured())
        #expect(appleProvider.displayName == "Apple Text-to-Speech")
        #expect(!appleProvider.requiresAPIKey)
    }

    @Test("ElevenLabs provider requires configuration")
    func testElevenLabsProviderRequiresConfiguration() async {
        let service = GenerationService()

        guard let elevenLabsProvider = await service.provider(withId: "elevenlabs") else {
            Issue.record("ElevenLabs provider should be registered")
            return
        }

        #expect(elevenLabsProvider.requiresAPIKey)
    }

    @Test("Apple provider is usable by default")
    func testAppleProviderIsUsableByDefault() async throws {
        let container = try TestFixtures.makeTestContainer()
        let context = ModelContext(container)
        let service = GenerationService()

        let voices = try await service.fetchVoices(from: "apple", using: context)

        #expect(!voices.isEmpty)
        #expect(voices.allSatisfy { $0.providerId == "apple" })
    }

    @Test("Get provider by ID")
    func testGetProviderById() async {
        let service = GenerationService()

        let appleProvider = await service.provider(withId: "apple")
        #expect(appleProvider != nil)
        #expect(appleProvider?.providerId == "apple")

        let elevenLabsProvider = await service.provider(withId: "elevenlabs")
        #expect(elevenLabsProvider != nil)
        #expect(elevenLabsProvider?.providerId == "elevenlabs")
    }

    @Test("Get provider by ID returns nil for unknown")
    func testGetProviderByIdReturnsNilForUnknown() async {
        let service = GenerationService()

        let unknownProvider = await service.provider(withId: "unknown")
        #expect(unknownProvider == nil)
    }

    @Test("Check if provider is registered")
    func testIsProviderRegistered() async {
        let service = GenerationService()

        let isAppleRegistered = await service.isProviderRegistered("apple")
        #expect(isAppleRegistered)

        let isElevenLabsRegistered = await service.isProviderRegistered("elevenlabs")
        #expect(isElevenLabsRegistered)

        let isUnknownRegistered = await service.isProviderRegistered("unknown")
        #expect(!isUnknownRegistered)
    }

    @Test("Register custom provider")
    func testRegisterCustomProvider() async {
        let setup = makeTestUserDefaults(suiteName: "testRegisterCustomProvider")
        defer { setup.cleanup() }
        let registry = VoiceProviderRegistry(userDefaults: setup.defaults)
        let service = GenerationService(providerRegistry: registry)

        let customProvider = TestFixtures.makeUnconfiguredProvider()
        await service.registerProvider(customProvider)

        let isRegistered = await service.isProviderRegistered("mock-unconfigured")
        #expect(isRegistered)

        let retrievedProvider = await service.provider(withId: "mock-unconfigured")
        #expect(retrievedProvider != nil)
        #expect(retrievedProvider?.providerId == "mock-unconfigured")

        let allProviders = await service.registeredProviders()
        #expect(allProviders.count == 3)
    }

    @Test("Register provider replaces existing")
    func testRegisterProviderReplacesExisting() async {
        let setup = makeTestUserDefaults(suiteName: "testRegisterProviderReplacesExisting")
        defer { setup.cleanup() }
        let registry = VoiceProviderRegistry(userDefaults: setup.defaults)
        let service = GenerationService(providerRegistry: registry)

        let originalApple = await service.provider(withId: "apple")
        #expect(originalApple != nil)

        let newAppleProvider = AppleVoiceProvider()
        await service.registerProvider(newAppleProvider)

        let allProviders = await service.registeredProviders()
        #expect(allProviders.count == 2)

        let appleProviders = allProviders.filter { $0.providerId == "apple" }
        #expect(appleProviders.count == 1)
    }

    @Test("Registered providers includes all providers")
    func testRegisteredProvidersIncludesAllProviders() async {
        let setup = makeTestUserDefaults(suiteName: "testRegisteredProvidersIncludesAllProviders")
        defer { setup.cleanup() }
        let registry = VoiceProviderRegistry(userDefaults: setup.defaults)
        let service = GenerationService(providerRegistry: registry)

        let customProvider1 = TestFixtures.makeConfiguredProvider(id: "custom1")
        let customProvider2 = TestFixtures.makeConfiguredProvider(id: "custom2")

        await service.registerProvider(customProvider1)
        await service.registerProvider(customProvider2)

        let allProviders = await service.registeredProviders()
        #expect(allProviders.count == 4)

        let providerIds = Set(allProviders.map { $0.providerId })
        #expect(providerIds.contains("apple"))
        #expect(providerIds.contains("elevenlabs"))
        #expect(providerIds.contains("custom1"))
        #expect(providerIds.contains("custom2"))
    }

    // MARK: - Voice Fetching from Registry Tests

    @Test("Fetch voices from specific provider")
    func testFetchVoicesFromSpecificProvider() async throws {
        let container = try TestFixtures.makeTestContainer()
        let context = ModelContext(container)
        let service = GenerationService()

        let appleVoices = try await service.fetchVoices(from: "apple", using: context)

        #expect(!appleVoices.isEmpty)
        #expect(appleVoices.allSatisfy { $0.providerId == "apple" })
    }

    @Test("Fetch voices from unknown provider throws")
    func testFetchVoicesFromUnknownProviderThrows() async {
        let container = try! TestFixtures.makeTestContainer()
        let context = ModelContext(container)
        let service = GenerationService()

        do {
            _ = try await service.fetchVoices(from: "unknown-provider", using: context)
            Issue.record("Should throw error for unknown provider")
        } catch let error as VoiceProviderError {
            if case .notConfigured = error {
                // Expected error
            } else {
                Issue.record("Expected notConfigured error, got \(error)")
            }
        } catch {
            Issue.record("Expected VoiceProviderError.notConfigured, got \(error)")
        }
    }

    @Test("Fetch voices from unconfigured provider throws")
    func testFetchVoicesFromUnconfiguredProviderThrows() async {
        let container = try! TestFixtures.makeTestContainer()
        let context = ModelContext(container)
        let service = GenerationService()

        let unconfiguredProvider = TestFixtures.makeUnconfiguredProvider()
        await service.registerProvider(unconfiguredProvider)

        do {
            _ = try await service.fetchVoices(from: "mock-unconfigured", using: context)
            Issue.record("Should throw error for unconfigured provider")
        } catch let error as VoiceProviderError {
            if case .notConfigured = error {
                // Expected error
            } else {
                Issue.record("Expected notConfigured error, got \(error)")
            }
        } catch {
            Issue.record("Expected VoiceProviderError.notConfigured, got \(error)")
        }
    }

    @Test("Fetch all voices")
    func testFetchAllVoices() async throws {
        let container = try TestFixtures.makeTestContainer()
        let context = ModelContext(container)
        let service = GenerationService()

        let customProvider = TestFixtures.makeConfiguredProvider(id: "custom1")
        await service.registerProvider(customProvider)

        let allVoices = try await service.fetchAllVoices(using: context)

        #expect(allVoices.count >= 1)

        if let appleVoices = allVoices["apple"] {
            #expect(!appleVoices.isEmpty)
            #expect(appleVoices.allSatisfy { $0.providerId == "apple" })
        }

        if let customVoices = allVoices["custom1"] {
            #expect(!customVoices.isEmpty)
            #expect(customVoices.allSatisfy { $0.providerId == "custom1" })
        }
    }

    @Test("Fetch all voices skips unconfigured providers")
    func testFetchAllVoicesSkipsUnconfiguredProviders() async throws {
        let container = try TestFixtures.makeTestContainer()
        let context = ModelContext(container)
        let service = GenerationService()

        let unconfiguredProvider = TestFixtures.makeUnconfiguredProvider()
        await service.registerProvider(unconfiguredProvider)

        let allVoices = try await service.fetchAllVoices(using: context)

        #expect(allVoices["mock-unconfigured"] == nil)
        #expect(allVoices["apple"] != nil)
    }

    @Test("Fetch all voices skips providers with errors")
    func testFetchAllVoicesSkipsProvidersWithErrors() async throws {
        let container = try TestFixtures.makeTestContainer()
        let context = ModelContext(container)
        let service = GenerationService()

        let errorProvider = TestFixtures.makeErrorProvider()
        await service.registerProvider(errorProvider)

        let allVoices = try await service.fetchAllVoices(using: context)

        #expect(allVoices["mock-error"] == nil)
        #expect(allVoices["apple"] != nil)
    }

    @Test("Fetch voices from multiple providers")
    func testFetchVoicesFromMultipleProviders() async throws {
        let container = try TestFixtures.makeTestContainer()
        let context = ModelContext(container)
        let service = GenerationService()

        let custom1 = TestFixtures.makeConfiguredProvider(id: "custom1")
        let custom2 = TestFixtures.makeConfiguredProvider(id: "custom2")

        await service.registerProvider(custom1)
        await service.registerProvider(custom2)

        let appleVoices = try await service.fetchVoices(from: "apple", using: context)
        let custom1Voices = try await service.fetchVoices(from: "custom1", using: context)
        let custom2Voices = try await service.fetchVoices(from: "custom2", using: context)

        #expect(!appleVoices.isEmpty)
        #expect(!custom1Voices.isEmpty)
        #expect(!custom2Voices.isEmpty)

        #expect(appleVoices.allSatisfy { $0.providerId == "apple" })
        #expect(custom1Voices.allSatisfy { $0.providerId == "custom1" })
        #expect(custom2Voices.allSatisfy { $0.providerId == "custom2" })
    }

    // MARK: - Voice Cache Tests (SwiftData)

    @Test("Voice caching basic")
    func testVoiceCachingBasic() async throws {
        let container = try TestFixtures.makeTestContainer()
        let context = ModelContext(container)
        let service = GenerationService(cacheLifetime: 10.0)

        let hasCache1 = await service.hasValidCache(for: "apple", using: context)
        #expect(!hasCache1)

        let voices1 = try await service.fetchVoices(from: "apple", using: context)
        #expect(!voices1.isEmpty)

        let hasCache2 = await service.hasValidCache(for: "apple", using: context)
        #expect(hasCache2)

        let voices2 = try await service.fetchVoices(from: "apple", using: context)
        let difference = abs(voices1.count - voices2.count)
        #expect(difference <= 1)

        let hasCache3 = await service.hasValidCache(for: "apple", using: context)
        #expect(hasCache3)

        let descriptor = VoiceCacheModel.fetchDescriptor(forProvider: "apple")
        let cachedModels = try context.fetch(descriptor)
        let cacheDifference = abs(cachedModels.count - voices1.count)
        #expect(cacheDifference <= 1)
    }

    @Test("Voice cache expiration", .disabled("Skipped on simulator due to timing variations"))
    func testVoiceCacheExpiration() async throws {

        let container = try TestFixtures.makeTestContainer()
        let context = ModelContext(container)
        let service = GenerationService(cacheLifetime: 0.2)

        let voices1 = try await service.fetchVoices(from: "apple", using: context)
        #expect(!voices1.isEmpty)

        let hasCache1 = await service.hasValidCache(for: "apple", using: context)
        #expect(hasCache1)

        try await Task.sleep(for: .milliseconds(500))

        let hasCache2 = await service.hasValidCache(for: "apple", using: context)
        #expect(!hasCache2)

        let voices2 = try await service.fetchVoices(from: "apple", using: context)
        #expect(!voices2.isEmpty)

        let hasCache3 = await service.hasValidCache(for: "apple", using: context)
        #expect(hasCache3)
    }

    @Test("Refresh voices")
    func testRefreshVoices() async throws {
        let container = try TestFixtures.makeTestContainer()
        let context = ModelContext(container)
        let service = GenerationService()

        let voices1 = try await service.fetchVoices(from: "apple", using: context)
        #expect(!voices1.isEmpty)
        let hasCache1 = await service.hasValidCache(for: "apple", using: context)
        #expect(hasCache1)

        let refreshedVoices = try await service.refreshVoices(from: "apple", using: context)
        #expect(!refreshedVoices.isEmpty)

        let hasCache2 = await service.hasValidCache(for: "apple", using: context)
        #expect(hasCache2)

        let voices2 = try await service.fetchVoices(from: "apple", using: context)
        let refreshDifference = abs(voices2.count - refreshedVoices.count)
        #expect(refreshDifference <= 1)
    }

    @Test("Clear voice cache")
    func testClearVoiceCache() async throws {
        let container = try TestFixtures.makeTestContainer()
        let context = ModelContext(container)
        let service = GenerationService()

        _ = try await service.fetchVoices(from: "apple", using: context)
        let hasCache1 = await service.hasValidCache(for: "apple", using: context)
        #expect(hasCache1)

        let beforeClear = try context.fetch(VoiceCacheModel.fetchDescriptor(forProvider: "apple"))
        #expect(!beforeClear.isEmpty)

        try await service.clearVoiceCache(for: "apple", using: context)

        let hasCache2 = await service.hasValidCache(for: "apple", using: context)
        #expect(!hasCache2)

        let afterClear = try context.fetch(VoiceCacheModel.fetchDescriptor(forProvider: "apple"))
        #expect(afterClear.isEmpty)

        let voices = try await service.fetchVoices(from: "apple", using: context)
        #expect(!voices.isEmpty)
        let hasCache3 = await service.hasValidCache(for: "apple", using: context)
        #expect(hasCache3)
    }

    @Test("Clear all voice caches")
    func testClearAllVoiceCaches() async throws {
        let container = try TestFixtures.makeTestContainer()
        let context = ModelContext(container)
        let service = GenerationService()

        _ = try await service.fetchVoices(from: "apple", using: context)
        let hasCache1 = await service.hasValidCache(for: "apple", using: context)
        #expect(hasCache1)

        let customProvider = TestFixtures.makeConfiguredProvider(id: "custom")
        await service.registerProvider(customProvider)
        _ = try await service.fetchVoices(from: "custom", using: context)
        let hasCache2 = await service.hasValidCache(for: "custom", using: context)
        #expect(hasCache2)

        let allBefore = try context.fetch(FetchDescriptor<VoiceCacheModel>())
        #expect(allBefore.count > 0)

        try await service.clearAllVoiceCaches(using: context)

        let hasCache3 = await service.hasValidCache(for: "apple", using: context)
        #expect(!hasCache3)
        let hasCache4 = await service.hasValidCache(for: "custom", using: context)
        #expect(!hasCache4)

        let allAfter = try context.fetch(FetchDescriptor<VoiceCacheModel>())
        #expect(allAfter.isEmpty)
    }

    @Test("Cache clearing restores autosave")
    func testCacheClearingRestoresAutosave() async throws {
        let container = try TestFixtures.makeTestContainer()
        let context = ModelContext(container)
        let service = GenerationService()

        _ = try await service.fetchVoices(from: "apple", using: context)
        let hasCache = await service.hasValidCache(for: "apple", using: context)
        #expect(hasCache)

        #expect(context.autosaveEnabled)

        try await service.clearVoiceCache(for: "apple", using: context)

        #expect(context.autosaveEnabled)

        _ = try await service.fetchVoices(from: "apple", using: context)
        try await service.clearAllVoiceCaches(using: context)

        #expect(context.autosaveEnabled)
    }

    @Test("Cache per provider")
    func testCachePerProvider() async throws {
        let container = try TestFixtures.makeTestContainer()
        let context = ModelContext(container)
        let service = GenerationService(cacheLifetime: 10.0)

        let customProvider = TestFixtures.makeConfiguredProvider(id: "custom")
        await service.registerProvider(customProvider)

        let appleVoices = try await service.fetchVoices(from: "apple", using: context)
        let customVoices = try await service.fetchVoices(from: "custom", using: context)

        let hasCache1 = await service.hasValidCache(for: "apple", using: context)
        #expect(hasCache1)
        let hasCache2 = await service.hasValidCache(for: "custom", using: context)
        #expect(hasCache2)

        let appleCached = try context.fetch(VoiceCacheModel.fetchDescriptor(forProvider: "apple"))
        let customCached = try context.fetch(VoiceCacheModel.fetchDescriptor(forProvider: "custom"))
        let appleDifference = abs(appleCached.count - appleVoices.count)
        #expect(appleDifference <= 1)
        let customDifference = abs(customCached.count - customVoices.count)
        #expect(customDifference <= 1)

        try await service.clearVoiceCache(for: "apple", using: context)

        let hasCache3 = await service.hasValidCache(for: "apple", using: context)
        #expect(!hasCache3)
        let hasCache4 = await service.hasValidCache(for: "custom", using: context)
        #expect(hasCache4)

        let appleAfterClear = try context.fetch(VoiceCacheModel.fetchDescriptor(forProvider: "apple"))
        let customAfterClear = try context.fetch(VoiceCacheModel.fetchDescriptor(forProvider: "custom"))
        #expect(appleAfterClear.isEmpty)
        #expect(!customAfterClear.isEmpty)

        let cachedCustomVoices = try await service.fetchVoices(from: "custom", using: context)
        let cachedDifference = abs(cachedCustomVoices.count - customVoices.count)
        #expect(cachedDifference <= 1)
    }

    @Test("Refresh unconfigured provider throws")
    func testRefreshUnconfiguredProvider() async throws {
        let container = try TestFixtures.makeTestContainer()
        let context = ModelContext(container)
        let service = GenerationService()

        do {
            _ = try await service.refreshVoices(from: "nonexistent", using: context)
            Issue.record("Should throw error for non-existent provider")
        } catch VoiceProviderError.notConfigured {
            // Expected
        } catch {
            Issue.record("Wrong error type: \(error)")
        }
    }

    @Test("Cache lifetime default")
    func testCacheLifetimeDefault() async throws {
        let container = try TestFixtures.makeTestContainer()
        let context = ModelContext(container)
        let service = GenerationService()

        let voices = try await service.fetchVoices(from: "apple", using: context)
        #expect(!voices.isEmpty)

        let hasCache = await service.hasValidCache(for: "apple", using: context)
        #expect(hasCache)
    }

    @Test("Cache language specific")
    func testCacheLanguageSpecific() async throws {
        let container = try TestFixtures.makeTestContainer()
        let context = ModelContext(container)
        let service = GenerationService()

        let enVoices = try await service.fetchVoices(from: "apple", using: context, languageCode: "en")
        #expect(!enVoices.isEmpty)

        let hasEnCache = await service.hasValidCache(for: "apple", languageCode: "en", using: context)
        #expect(hasEnCache)

        let hasEsCache1 = await service.hasValidCache(for: "apple", languageCode: "es", using: context)
        #expect(!hasEsCache1)

        let esVoices = try await service.fetchVoices(from: "apple", using: context, languageCode: "es")

        let hasEsCache2 = await service.hasValidCache(for: "apple", languageCode: "es", using: context)
        #expect(hasEsCache2)

        let hasEnCache2 = await service.hasValidCache(for: "apple", languageCode: "en", using: context)
        #expect(hasEnCache2)

        #expect(enVoices.count != 0)
        #expect(esVoices.count != 0)
    }

    @Test("Clear language specific cache")
    func testClearLanguageSpecificCache() async throws {
        let container = try TestFixtures.makeTestContainer()
        let context = ModelContext(container)
        let service = GenerationService()

        _ = try await service.fetchVoices(from: "apple", using: context, languageCode: "en")
        _ = try await service.fetchVoices(from: "apple", using: context, languageCode: "es")

        let hasEnCache1 = await service.hasValidCache(for: "apple", languageCode: "en", using: context)
        let hasEsCache1 = await service.hasValidCache(for: "apple", languageCode: "es", using: context)
        #expect(hasEnCache1)
        #expect(hasEsCache1)

        try await service.clearVoiceCache(for: "apple", languageCode: "en", using: context)

        let hasEnCache2 = await service.hasValidCache(for: "apple", languageCode: "en", using: context)
        let hasEsCache2 = await service.hasValidCache(for: "apple", languageCode: "es", using: context)
        #expect(!hasEnCache2)
        #expect(hasEsCache2)

        try await service.clearVoiceCache(for: "apple", using: context)

        let hasEnCache3 = await service.hasValidCache(for: "apple", languageCode: "en", using: context)
        let hasEsCache3 = await service.hasValidCache(for: "apple", languageCode: "es", using: context)
        #expect(!hasEnCache3)
        #expect(!hasEsCache3)
    }

    // MARK: - Concurrency Tests

    @Test("Concurrent audio generation")
    func testConcurrentAudioGeneration() async throws {
        let container = try TestFixtures.makeTestContainer()
        let context = ModelContext(container)
        let service = GenerationService()

        let voices = try await service.fetchVoices(from: "apple", using: context)

        guard let firstVoice = voices.first else {
            Issue.record("No voices available")
            return
        }

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

                #expect(results.count == 3)

                for result in results {
                    #expect(!result.audioData.isEmpty)
                }
            } catch {
                Issue.record("Concurrent generation failed: \(error)")
            }
        }
    }

    @Test("Actor isolation ensures thread safety")
    func testActorIsolationEnsuresThreadSafety() async throws {
        let container = try TestFixtures.makeTestContainer()
        let context = ModelContext(container)
        let service = GenerationService()

        let voices = try await service.fetchVoices(from: "apple", using: context)

        guard let firstVoice = voices.first else {
            Issue.record("No voices available")
            return
        }

        async let result1 = service.generate(text: "Test 1", providerId: "apple", voiceId: firstVoice.id)
        async let result2 = service.generate(text: "Test 2", providerId: "apple", voiceId: firstVoice.id)
        async let voices1 = service.fetchVoices(from: "apple")
        async let available1 = service.isVoiceAvailable(firstVoice.id, from: "apple")

        let (r1, r2, v1, a1) = try await (result1, result2, voices1, available1)

        #expect(!r1.audioData.isEmpty)
        #expect(!r2.audioData.isEmpty)
        #expect(!v1.isEmpty)
        #expect(a1)
    }
}
