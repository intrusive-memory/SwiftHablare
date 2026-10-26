//
//  TestFixtures.swift
//  SwiftHablareTests
//
//  Concurrency-safe test fixture helpers for SwiftData testing
//

import Foundation
import SwiftCompartido
import SwiftData
import SwiftHablare
import SwiftHablareTesting

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

  // MARK: - Fake Plugin Registry

  /// The voice every speakable factory uses by default: a catalog voice of `FakeSynthesizerPlugin`.
  nonisolated public static let fakeVoice: VoiceReference = .catalog(
    pluginId: FakeSynthesizerPlugin.id, voiceId: "fake-voice")

  /// A registry holding only `FakeSynthesizerPlugin`, with no environment and no stored keys.
  ///
  /// Each call returns a fresh registry with its own `UserDefaults` suite, so tests never
  /// share plugin instances or enablement.
  nonisolated public static func makeFakeRegistry() -> PluginRegistry {
    let suite = "swifthablare.tests.fakeRegistry.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return PluginRegistry(
      userDefaults: defaults, environment: [:], fallbackKeys: [],
      plugins: [FakeSynthesizerPlugin.self])
  }

  // MARK: - SpeakableItem Factories

  /// Create a simple message for testing
  ///
  /// - Parameters:
  ///   - content: The message content
  ///   - voice: The voice (defaults to ``fakeVoice``)
  /// - Returns: A SimpleMessage instance
  public static func makeSimpleMessage(
    content: String = "Test message",
    voice: VoiceReference = TestFixtures.fakeVoice
  ) -> SimpleMessage {
    SimpleMessage(content: content, voice: voice)
  }

  /// Create character dialogue for testing
  ///
  /// - Parameters:
  ///   - characterName: The character name
  ///   - dialogue: The dialogue text
  ///   - voice: The voice (defaults to ``fakeVoice``)
  ///   - includeCharacterName: Whether to include character name in speech
  /// - Returns: A CharacterDialogue instance
  public static func makeCharacterDialogue(
    characterName: String = "Test Character",
    dialogue: String = "Test dialogue",
    voice: VoiceReference = TestFixtures.fakeVoice,
    includeCharacterName: Bool = true
  ) -> CharacterDialogue {
    CharacterDialogue(
      characterName: characterName,
      dialogue: dialogue,
      voice: voice,
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
    for item: any SpeakableItem,
    in context: ModelContext,
    audioData: Data? = nil
  ) -> TypedDataStorage {
    let data = audioData ?? makeMockAudioData()
    var providerId = "unknown"
    if case .catalog(let pluginId, _) = item.voice { providerId = pluginId }

    let record = TypedDataStorage(
      providerId: providerId,
      requestorID: "test-audio",
      mimeType: "audio/mock",
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
  ///   - voice: Voice (defaults to ``fakeVoice``)
  /// - Returns: A SpeakableItemList with test items
  public static func makeSpeakableItemList(
    name: String = "Test List",
    itemCount: Int = 3,
    voice: VoiceReference = TestFixtures.fakeVoice
  ) -> SpeakableItemList {
    let items: [any SpeakableItem] = (0..<itemCount).map { index in
      makeSimpleMessage(content: "Test message \(index + 1)", voice: voice)
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
  ///   - voice: Voice (defaults to ``fakeVoice``)
  ///   - includeMeta: Include metadata in speech
  /// - Returns: An Article instance
  public static func makeArticle(
    title: String = "Test Article",
    author: String = "Test Author",
    content: String = "Test content",
    voice: VoiceReference = TestFixtures.fakeVoice,
    includeMeta: Bool = true
  ) -> Article {
    Article(
      title: title,
      author: author,
      content: content,
      voice: voice,
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
