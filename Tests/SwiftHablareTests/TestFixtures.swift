//
//  TestFixtures.swift
//  SwiftHablareTests
//
//  Concurrency-safe test fixture helpers for SwiftData testing
//

import Foundation
import SwiftData
import SwiftHablare
import SwiftCompartido

#if canImport(SwiftUI)
import SwiftUI
#endif

/// Test fixture helpers for SwiftHablare tests
///
/// Provides concurrency-safe utilities for creating test containers, contexts,
/// and mock data for SwiftHablare tests using both XCTest and Swift Testing frameworks.
///
/// ## Usage
///
/// ### XCTest Pattern
/// ```swift
/// @MainActor
/// class MyTests: XCTestCase {
///     var modelContext: ModelContext!
///     var modelContainer: ModelContainer!
///
///     override func setUp() async throws {
///         modelContainer = try TestFixtures.makeTestContainer()
///         modelContext = ModelContext(modelContainer)
///     }
/// }
/// ```
///
/// ### Swift Testing Pattern
/// ```swift
/// @Suite @MainActor
/// struct MyTests {
///     @Test func myTest() throws {
///         let container = try TestFixtures.makeTestContainer()
///         let context = ModelContext(container)
///         // ... test code
///     }
/// }
/// ```
@MainActor
public enum TestFixtures {

    // MARK: - Container & Context Creation

    /// Create an in-memory ModelContainer for testing
    ///
    /// This container is configured with the standard SwiftHablare schema:
    /// - TypedDataStorage (audio persistence from SwiftCompartido)
    ///
    /// - Returns: An in-memory ModelContainer for testing
    /// - Throws: If container creation fails
    public static func makeTestContainer() throws -> ModelContainer {
        let schema = Schema([
            TypedDataStorage.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    /// Create an in-memory ModelContext for testing
    ///
    /// Convenience method that creates both container and context in one call.
    ///
    /// - Returns: A ModelContext backed by an in-memory container
    /// - Throws: If container creation fails
    public static func makeTestContext() throws -> ModelContext {
        let container = try makeTestContainer()
        return ModelContext(container)
    }

    // MARK: - Mock Voice Providers

    /// Create a mock configured provider for testing
    ///
    /// Returns a simple mock provider that is always configured and has
    /// predictable voice data for testing.
    ///
    /// - Returns: A mock VoiceProvider instance
    public static func makeMockProvider() -> MockConfiguredProvider {
        return MockConfiguredProvider()
    }

    /// Create a mock unconfigured provider for testing
    ///
    /// Returns a mock provider that is never configured and always throws
    /// notConfigured errors. Use for testing configuration validation.
    ///
    /// - Returns: A mock unconfigured VoiceProvider instance
    public static func makeMockUnconfiguredProvider() -> MockUnconfiguredProvider {
        return MockUnconfiguredProvider()
    }

    /// Create a mock error provider for testing
    ///
    /// Returns a mock provider that always throws errors on voice fetching
    /// and audio generation. Use for testing error handling and recovery.
    ///
    /// - Returns: A mock error-throwing VoiceProvider instance
    public static func makeMockErrorProvider() -> MockErrorProvider {
        return MockErrorProvider()
    }

    /// Create an Apple voice provider for testing
    ///
    /// Note: This is a real provider, not a mock. Use in integration tests only.
    ///
    /// - Returns: An AppleVoiceProvider instance
    public static func makeAppleProvider() -> AppleVoiceProvider {
        return AppleVoiceProvider()
    }

    /// Get an available Apple TTS voice ID for testing
    ///
    /// Fetches available voices from AppleVoiceProvider and returns the first available voice ID.
    /// Throws a descriptive error if no voices are available (common on GitHub Actions runners).
    ///
    /// - Returns: A valid voice ID that can be used for testing
    /// - Throws: NoVoicesAvailableError if no voices are available
    public static func getAvailableAppleVoiceId() async throws -> String {
        let provider = makeAppleProvider()
        let voices = try await provider.fetchVoices()

        guard let voiceId = voices.first?.id else {
            struct NoVoicesAvailableError: Error, CustomStringConvertible {
                var description: String {
                    "No Apple TTS voices available. This is expected on GitHub Actions runners."
                }
            }
            throw NoVoicesAvailableError()
        }

        return voiceId
    }

    /// Create a custom mock provider with specific ID for testing
    ///
    /// Creates a configured mock provider with a custom provider ID.
    /// Useful for testing provider registry with multiple providers.
    ///
    /// - Parameter id: The provider ID (defaults to "custom-mock")
    /// - Returns: A configured mock VoiceProvider with the specified ID
    public static func makeConfiguredProvider(id: String = "custom-mock") -> VoiceProvider {
        return CustomMockProvider(providerId: id)
    }

    /// Create an unconfigured provider for testing (alias)
    ///
    /// Alias for makeMockUnconfiguredProvider(). Returns a mock provider that is
    /// never configured. Use for testing provider configuration validation.
    ///
    /// - Returns: A mock unconfigured VoiceProvider instance
    public static func makeUnconfiguredProvider() -> MockUnconfiguredProvider {
        return makeMockUnconfiguredProvider()
    }

    /// Create an error provider for testing (alias)
    ///
    /// Alias for makeMockErrorProvider(). Returns a mock provider that always
    /// throws errors. Use for testing error handling and recovery scenarios.
    ///
    /// - Returns: A mock error-throwing VoiceProvider instance
    public static func makeErrorProvider() -> MockErrorProvider {
        return makeMockErrorProvider()
    }

    // MARK: - SpeakableItem Factories

    /// Create a simple message for testing
    ///
    /// - Parameters:
    ///   - content: The message content
    ///   - provider: The voice provider (defaults to mock)
    ///   - voiceId: The voice ID (defaults to "test-voice-id")
    ///   - languageCode: The language code (defaults to "en")
    /// - Returns: A SimpleMessage instance
    public static func makeSimpleMessage(
        content: String = "Test message",
        provider: VoiceProvider? = nil,
        voiceId: String = "test-voice-id"
    ) -> SimpleMessage {
        let voiceProvider = provider ?? makeMockProvider()
        return SimpleMessage(
            content: content,
            voiceProvider: voiceProvider,
            voiceId: voiceId
        )
    }

    /// Create character dialogue for testing
    ///
    /// - Parameters:
    ///   - characterName: The character name
    ///   - dialogue: The dialogue text
    ///   - provider: The voice provider (defaults to mock)
    ///   - voiceId: The voice ID (defaults to "test-voice-id")
    ///   - includeCharacterName: Whether to include character name in speech
    ///   - languageCode: The language code (defaults to "en")
    /// - Returns: A CharacterDialogue instance
    public static func makeCharacterDialogue(
        characterName: String = "Test Character",
        dialogue: String = "Test dialogue",
        provider: VoiceProvider? = nil,
        voiceId: String = "test-voice-id",
        includeCharacterName: Bool = true
    ) -> CharacterDialogue {
        let voiceProvider = provider ?? makeMockProvider()
        return CharacterDialogue(
            characterName: characterName,
            dialogue: dialogue,
            voiceProvider: voiceProvider,
            voiceId: voiceId,
            includeCharacterName: includeCharacterName
        )
    }

    // MARK: - TypedDataStorage Factories

    /// Create a test audio record in SwiftData
    ///
    /// Creates a TypedDataStorage record representing generated audio data.
    ///
    /// - Parameters:
    ///   - item: The speakable item this audio is for
    ///   - context: The ModelContext to insert the record into
    ///   - audioData: Optional audio data (defaults to mock data)
    /// - Returns: A TypedDataStorage record
    public static func makeAudioRecord(
        for item: SpeakableItem,
        in context: ModelContext,
        audioData: Data? = nil
    ) -> TypedDataStorage {
        let data = audioData ?? makeMockAudioData()

        let record = TypedDataStorage(
            providerId: item.voiceProvider.providerId,
            requestorID: "test-audio",
            mimeType: item.voiceProvider.mimeType,
            binaryValue: data,
            prompt: item.textToSpeak
        )

        context.insert(record)
        return record
    }

    /// Create mock audio data for testing
    ///
    /// Generates a small amount of fake audio data for testing purposes.
    /// This is NOT real audio - just enough data to satisfy tests that check
    /// for non-empty audio data.
    ///
    /// - Returns: Mock audio data (16 bytes)
    public static func makeMockAudioData() -> Data {
        // Create 16 bytes of mock audio data
        return Data(repeating: 0xFF, count: 16)
    }

    // MARK: - Voice Factories

    /// Create a mock Voice instance for testing
    ///
    /// - Parameters:
    ///   - id: Voice ID (defaults to "test-voice-id")
    ///   - name: Voice name (defaults to "Test Voice")
    ///   - language: Language code (defaults to "en")
    ///   - providerId: Provider ID (defaults to "mock")
    /// - Returns: A Voice instance
    public static func makeMockVoice(
        id: String = "test-voice-id",
        name: String = "Test Voice",
        language: String = "en",
        providerId: String = "mock"
    ) -> Voice {
        return Voice(
            id: id,
            name: name,
            description: nil,
            providerId: providerId,
            language: language,
            locality: nil,
            gender: nil
        )
    }

    // MARK: - SpeakableItemList Factories

    /// Create a SpeakableItemList for testing
    ///
    /// - Parameters:
    ///   - name: List name (defaults to "Test List")
    ///   - itemCount: Number of items to include (defaults to 3)
    ///   - provider: Voice provider (defaults to mock)
    ///   - voiceId: Voice ID (defaults to "test-voice-id")
    /// - Returns: A SpeakableItemList with test items
    public static func makeSpeakableItemList(
        name: String = "Test List",
        itemCount: Int = 3,
        provider: VoiceProvider? = nil,
        voiceId: String = "test-voice-id"
    ) -> SpeakableItemList {
        let voiceProvider = provider ?? makeMockProvider()
        let items: [any SpeakableItem] = (0..<itemCount).map { index in
            makeSimpleMessage(
                content: "Test message \(index + 1)",
                provider: voiceProvider,
                voiceId: voiceId
            )
        }
        return SpeakableItemList(name: name, items: items)
    }

    // MARK: - Article Factory

    /// Create an article for testing
    ///
    /// - Parameters:
    ///   - title: Article title
    ///   - author: Article author
    ///   - content: Article content
    ///   - provider: Voice provider (defaults to mock)
    ///   - voiceId: Voice ID (defaults to "test-voice-id")
    ///   - includeMeta: Include metadata in speech
    ///   - languageCode: Language code (defaults to "en")
    /// - Returns: An Article instance
    public static func makeArticle(
        title: String = "Test Article",
        author: String = "Test Author",
        content: String = "Test content",
        provider: VoiceProvider? = nil,
        voiceId: String = "test-voice-id",
        includeMeta: Bool = true
    ) -> Article {
        let voiceProvider = provider ?? makeMockProvider()
        return Article(
            title: title,
            author: author,
            content: content,
            voiceProvider: voiceProvider,
            voiceId: voiceId,
            includeMeta: includeMeta
        )
    }

    // MARK: - UserDefaults Factories

    /// Create test UserDefaults for isolated testing
    ///
    /// Returns a tuple with a UserDefaults instance and a cleanup closure.
    /// Call the cleanup closure in test teardown to remove the test suite.
    ///
    /// - Parameter suiteName: Unique suite name for this test
    /// - Returns: Tuple of (UserDefaults, cleanup function)
    public static func makeTestUserDefaults(
        suiteName: String = "test-suite"
    ) -> (defaults: UserDefaults, cleanup: () -> Void) {
        let defaults = UserDefaults(suiteName: suiteName)!
        let cleanup = {
            defaults.removePersistentDomain(forName: suiteName)
        }
        return (defaults, cleanup)
    }

    /// Create a VoiceProviderRegistry for testing
    ///
    /// - Parameter suiteName: Unique suite name for isolated UserDefaults (unused in current implementation)
    /// - Returns: The shared VoiceProviderRegistry instance
    nonisolated public static func makeVoiceProviderRegistry(
        suiteName: String = "test-registry"
    ) -> VoiceProviderRegistry {
        // Use the shared instance - VoiceProviderRegistry initializer is internal
        return VoiceProviderRegistry.shared
    }

    // MARK: - Cleanup Utilities

    /// Clean up a ModelContext after testing
    ///
    /// Saves any pending changes and resets the context. Use this in tearDown
    /// methods to ensure clean state between tests.
    ///
    /// - Parameter context: The context to clean up
    /// - Throws: If save fails
    public static func cleanup(_ context: ModelContext) throws {
        try context.save()
    }
}

// MARK: - Mock Configured Provider

/// A mock voice provider that is always configured
///
/// Used for testing voice provider functionality without requiring
/// real API keys or network calls.
public final class MockConfiguredProvider: VoiceProvider, @unchecked Sendable {
    public let providerId = "mock"
    public let displayName = "Mock Provider"
    public let requiresAPIKey = false
    public let mimeType = "audio/mock"

    public init() {}

    public func isConfigured() async -> Bool {
        return true
    }

    public func fetchVoices(languageCode: String) async throws -> [Voice] {
        return [
            Voice(
                id: "mock-voice-1",
                name: "Mock Voice 1",
                description: nil,
                providerId: providerId,
                language: languageCode,
                locality: nil,
                gender: "neutral"
            ),
            Voice(
                id: "mock-voice-2",
                name: "Mock Voice 2",
                description: nil,
                providerId: providerId,
                language: languageCode,
                locality: nil,
                gender: "neutral"
            )
        ]
    }

    public func generateAudio(
        text: String,
        voiceId: String,
        languageCode: String
    ) async throws -> Data {
        // Return mock audio data (16 bytes)
        return Data(repeating: 0xFF, count: 16)
    }

    public func estimateDuration(text: String, voiceId: String) async -> TimeInterval {
        // Simple estimation: ~0.1 seconds per character
        return Double(text.count) * 0.1
    }

    public func isVoiceAvailable(voiceId: String) async -> Bool {
        return voiceId == "mock-voice-1" || voiceId == "mock-voice-2"
    }

    #if canImport(SwiftUI)
    @MainActor
    public func makeConfigurationView(onConfigured: @escaping (Bool) -> Void) -> AnyView {
        return AnyView(EmptyView())
    }
    #endif
}

// MARK: - Mock Unconfigured Provider

/// A mock voice provider that is never configured
///
/// Used for testing provider configuration checks and error handling.
public final class MockUnconfiguredProvider: VoiceProvider, @unchecked Sendable {
    public let providerId = "mock-unconfigured"
    public let displayName = "Mock Unconfigured Provider"
    public let requiresAPIKey = true
    public let mimeType = "audio/mock"

    public init() {}

    public func isConfigured() async -> Bool {
        return false
    }

    public func fetchVoices(languageCode: String) async throws -> [Voice] {
        throw VoiceProviderError.notConfigured
    }

    public func generateAudio(
        text: String,
        voiceId: String,
        languageCode: String
    ) async throws -> Data {
        throw VoiceProviderError.notConfigured
    }

    public func estimateDuration(text: String, voiceId: String) async -> TimeInterval {
        return 0
    }

    public func isVoiceAvailable(voiceId: String) async -> Bool {
        return false
    }

    #if canImport(SwiftUI)
    @MainActor
    public func makeConfigurationView(onConfigured: @escaping (Bool) -> Void) -> AnyView {
        return AnyView(EmptyView())
    }
    #endif
}

// MARK: - Mock Error Provider

/// A mock voice provider that always throws errors
///
/// Used for testing error handling and recovery scenarios.
public final class MockErrorProvider: VoiceProvider, @unchecked Sendable {
    public let providerId = "mock-error"
    public let displayName = "Mock Error Provider"
    public let requiresAPIKey = false
    public let mimeType = "audio/mock"

    public init() {}

    public func isConfigured() async -> Bool {
        return true
    }

    public func fetchVoices(languageCode: String) async throws -> [Voice] {
        throw VoiceProviderError.networkError("Mock network error")
    }

    public func generateAudio(
        text: String,
        voiceId: String,
        languageCode: String
    ) async throws -> Data {
        throw VoiceProviderError.invalidRequest("Mock generation error")
    }

    public func estimateDuration(text: String, voiceId: String) async -> TimeInterval {
        return 0
    }

    public func isVoiceAvailable(voiceId: String) async -> Bool {
        return false
    }

    #if canImport(SwiftUI)
    @MainActor
    public func makeConfigurationView(onConfigured: @escaping (Bool) -> Void) -> AnyView {
        return AnyView(EmptyView())
    }
    #endif
}

// MARK: - Custom Mock Provider

/// A custom mock provider with configurable provider ID
///
/// Used for testing provider registry with multiple custom providers
public final class CustomMockProvider: VoiceProvider, @unchecked Sendable {
    public let providerId: String
    public let displayName: String
    public let requiresAPIKey = false
    public let mimeType = "audio/mock"

    public init(providerId: String) {
        self.providerId = providerId
        self.displayName = "Custom Mock \(providerId)"
    }

    public func isConfigured() async -> Bool {
        return true
    }

    public func fetchVoices(languageCode: String) async throws -> [Voice] {
        return [
            Voice(
                id: "\(providerId)-voice-1",
                name: "\(displayName) Voice 1",
                description: nil,
                providerId: providerId,
                language: languageCode,
                locality: nil,
                gender: "neutral"
            )
        ]
    }

    public func generateAudio(
        text: String,
        voiceId: String,
        languageCode: String
    ) async throws -> Data {
        // Return mock audio data (16 bytes)
        return Data(repeating: 0xCC, count: 16)
    }

    public func estimateDuration(text: String, voiceId: String) async -> TimeInterval {
        return Double(text.count) * 0.1
    }

    public func isVoiceAvailable(voiceId: String) async -> Bool {
        return voiceId.hasPrefix(providerId)
    }

    #if canImport(SwiftUI)
    @MainActor
    public func makeConfigurationView(onConfigured: @escaping (Bool) -> Void) -> AnyView {
        return AnyView(EmptyView())
    }
    #endif
}

