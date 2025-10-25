# SwiftHablaré - Claude Code Development Guide

This document provides guidance for AI assistants (particularly Claude Code) working on the SwiftHablaré project.

## Project Overview

**SwiftHablaré** is a Swift voice generation library for iOS and Mac Catalyst applications. It provides a simple, unified API for text-to-speech generation using multiple voice providers (Apple TTS and ElevenLabs), with automatic voice caching and secure API key management.

**Key Focus**: Voice generation only - no UI components, no data persistence beyond voice caching, no screenplay processing. SwiftHablaré is a **generation library**, not an application framework.

## Version Information

- **Current Version**: 2.3.0
- **Swift Version**: 6.0+
- **Minimum Deployments**: iOS 26.0, macCatalyst 15.0
- **macOS Support**: Build/test compatibility only (placeholder audio for TTS)
- **Total Tests**: 109 passing (87 core + 22 SpeakableItem)
- **Test Coverage**: 96%+ on voice generation components
- **Swift Concurrency**: Full Swift 6 compliance

## Platform Support

### iOS and Catalyst Only

**SwiftHablaré is exclusively for iOS and Mac Catalyst platforms.**

Supported platforms:
- **iOS 26.0+** ✅ Full TTS support with real audio generation
- **macCatalyst 15.0+** ✅ Full TTS support with real audio generation

**IMPORTANT:** This library does NOT support macOS. All platform-specific code should ONLY use `#if targetEnvironment(simulator)` to detect iOS simulators. Never use `#if os(macOS)` guards in this codebase.

### Simulator Behavior

- **Physical iOS/Catalyst devices**: Real TTS with `AVSpeechSynthesizer.write()`
- **iOS Simulator**: Placeholder audio for testing (AVSpeechSynthesizer.write() doesn't generate buffers on simulators)

Integration tests that require real audio are skipped on simulators using `#if targetEnvironment(simulator)`.

## Architecture

### Core Components

```
SwiftHablare/
├── VoiceProvider.swift              # Protocol for voice providers
├── Protocols/
│   └── SpeakableItem.swift          # Protocol for speakable objects
├── Models/
│   ├── Voice.swift                  # Voice model (id, name, language, etc.)
│   └── SpeakableItemList.swift      # ✨ Batch generation with progress
├── Providers/
│   ├── AppleVoiceProvider.swift     # Apple TTS implementation
│   └── ElevenLabsVoiceProvider.swift # ElevenLabs API implementation
├── Generation/
│   └── GenerationService.swift      # ✨ Actor-based service with provider registry
├── Security/
│   └── KeychainManager.swift        # Secure API key storage
├── SwiftDataModels/
│   └── VoiceCacheModel.swift        # Voice caching with SwiftData
└── Examples/
    ├── SpeakableItemExamples.swift  # Example implementations
    └── SpeakableItemListExample.swift # ✨ Complete batch generation example
```

### No UI Components

SwiftHablaré is a **generation library only**. There are NO UI components:
- ❌ No widgets
- ❌ No views
- ❌ No SwiftUI components
- ❌ No audio players
- ❌ No voice pickers

Consuming applications are responsible for building their own UI using SwiftHablaré's generation APIs.

### No Data Persistence (Beyond Voice Caching)

SwiftHablaré does NOT provide:
- ❌ TypedDataStorage
- ❌ SwiftData models for generated content
- ❌ Audio file storage
- ❌ Persistence coordinators

The only SwiftData model is `VoiceCacheModel` for caching fetched voices to improve performance.

### No Screenplay Processing

SwiftHablaré does NOT include:
- ❌ ScreenplaySpeech system
- ❌ BackgroundTask/BackgroundTaskManager
- ❌ SpeakableItem models
- ❌ Screenplay-to-speech processors

These were removed in version 2.0. SwiftHablaré is a focused voice generation library.

## Voice Providers

### AppleVoiceProvider

**Platform-Specific Behavior:**
```swift
#if os(macOS)
// Returns placeholder AIFF audio (silent) for test compatibility
// Real TTS not available on macOS due to AVSpeechSynthesizer.write() limitation
#else
// iOS/Catalyst: Real speech synthesis using AVSpeechSynthesizer.write()
// Captures audio buffers and writes to AIFF file
#endif
```

**Features:**
- Always configured (no API key required)
- Fetches voices from `AVSpeechSynthesisVoice`
- Filters voices by system language
- Estimates duration using text length heuristics
- Generates AIFF format audio

**Test Coverage:**
- 22 unit tests (100% coverage)
- 4 integration tests (skipped on macOS)

### ElevenLabsVoiceProvider

**Features:**
- Requires API key (stored in Keychain)
- Fetches voices from ElevenLabs API
- Generates MP3 format audio
- Supports ephemeral API keys for testing

**Test Coverage:**
- 30 unit tests (95%+ coverage)
- 5 integration tests (conditional - require API key)

## SpeakableItem Protocol

### Overview

The `SpeakableItem` protocol enables **protocol-oriented text-to-speech generation** where any type can become speakable by conforming to a simple 3-property protocol:

```swift
public protocol SpeakableItem {
    var voiceProvider: VoiceProvider { get }
    var voiceId: String { get }
    var textToSpeak: String { get }
}
```

### Design Philosophy

**Protocol-Oriented Design:**
- ✅ Any struct, class, or enum can become speakable
- ✅ Voice configuration travels with the object
- ✅ Composable with other protocols
- ✅ Easy to test with mock implementations
- ✅ Type-safe audio generation

**Key Benefits:**
1. **Flexibility**: Your domain models become speakable without inheritance
2. **Reusability**: Voice settings are encapsulated with content
3. **Testability**: Easy to create test fixtures
4. **Composability**: Works with Swift's Collection protocols

### Basic Usage

```swift
// Create a speakable type
struct Message: SpeakableItem {
    let voiceProvider: VoiceProvider
    let voiceId: String
    let sender: String
    let content: String

    var textToSpeak: String {
        "\(sender) says: \(content)"
    }
}

// Use it
let provider = AppleVoiceProvider()
let voices = try await provider.fetchVoices()

let message = Message(
    voiceProvider: provider,
    voiceId: voices.first!.id,
    sender: "Alice",
    content: "Hello, world!"
)

// Generate audio (convenience method from protocol extension)
let audioData = try await message.speak()
```

### Convenience Methods

The protocol provides default implementations for common operations:

```swift
extension SpeakableItem {
    // Generate audio for this item
    public func speak() async throws -> Data

    // Estimate duration in seconds
    public func estimateDuration() async -> TimeInterval

    // Check if voice is available
    public func isVoiceAvailable() async -> Bool
}
```

### Batch Operations

Collections of `SpeakableItem` get automatic batch processing:

```swift
extension Collection where Element: SpeakableItem {
    // Generate audio for all items sequentially
    public func speakAll() async throws -> [Data]

    // Estimate total duration for all items
    public func estimateTotalDuration() async -> TimeInterval
}
```

**Example:**
```swift
let messages: [Message] = [
    Message(voiceProvider: provider, voiceId: voiceId, sender: "Alice", content: "Hello"),
    Message(voiceProvider: provider, voiceId: voiceId, sender: "Bob", content: "Hi there"),
    Message(voiceProvider: provider, voiceId: voiceId, sender: "Charlie", content: "Good morning")
]

// Generate all at once
let audioFiles = try await messages.speakAll()
// Returns [Data, Data, Data]

// Estimate total time
let totalDuration = await messages.estimateTotalDuration()
// Returns TimeInterval (e.g., 8.5 seconds)
```

### Integration with SwiftCompartido (TypedDataStorage)

When using SwiftHablaré with SwiftCompartido for persistence, the typical flow is:

```
┌─────────────────────────────────────────────────────────────────┐
│                     SpeakableItem List                          │
│  [Message, Article, Notification, CharacterDialogue, ...]      │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         │ for item in items {
                         ↓
┌─────────────────────────────────────────────────────────────────┐
│                  SpeakableItem Protocol                         │
│                                                                 │
│  • voiceProvider: VoiceProvider                                 │
│  • voiceId: String                                              │
│  • textToSpeak: String                                          │
│                                                                 │
│  Extension methods:                                             │
│  • speak() -> Data                                              │
│  • estimateDuration() -> TimeInterval                           │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         │ let audioData = try await item.speak()
                         ↓
┌─────────────────────────────────────────────────────────────────┐
│                   Voice Provider                                │
│  (AppleVoiceProvider or ElevenLabsVoiceProvider)                │
│                                                                 │
│  generateAudio(text: String, voiceId: String) -> Data           │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         │ Returns audio Data (AIFF/MP3)
                         ↓
┌─────────────────────────────────────────────────────────────────┐
│               Application Layer (Your Code)                     │
│                                                                 │
│  • Receives audio Data from speak()                             │
│  • Creates TypedDataStorage record                              │
│  • Sets MIME type (audio/x-aiff or audio/mpeg)                  │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         │ modelContext.insert(record)
                         ↓
┌─────────────────────────────────────────────────────────────────┐
│            SwiftCompartido - TypedDataStorage                   │
│                                                                 │
│  • id: UUID                                                     │
│  • providerId: "apple" or "elevenlabs"                          │
│  • requestorID: "your-app.audio.tts"                            │
│  • mimeType: "audio/x-aiff" or "audio/mpeg"                     │
│  • binaryValue: Data (the audio)                                │
│  • prompt: String (original text)                               │
│  • metadata: JSON (voiceId, duration, etc.)                     │
│  • createdAt: Date                                              │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         │ modelContext.save()
                         ↓
┌─────────────────────────────────────────────────────────────────┐
│                      SwiftData Store                            │
│            (Persistent storage on device)                       │
└─────────────────────────────────────────────────────────────────┘
```

### Complete Example: SpeakableItem → TypedDataStorage

```swift
import SwiftHablare
import SwiftCompartido
import SwiftData

@MainActor
func generateAndPersistSpeech() async throws {
    // 1. Create your speakable items
    let provider = AppleVoiceProvider()
    let voices = try await provider.fetchVoices()
    let voiceId = voices.first!.id

    let items: [any SpeakableItem] = [
        SimpleMessage(content: "Hello, world!", voiceProvider: provider, voiceId: voiceId),
        Article(
            title: "Breaking News",
            author: "Jane Doe",
            content: "This is the article content.",
            voiceProvider: provider,
            voiceId: voiceId
        ),
        Notification(
            title: "Alert",
            message: "You have a new message",
            voiceProvider: provider,
            voiceId: voiceId
        )
    ]

    // 2. Generate audio and persist each one
    for item in items {
        // Generate audio using SpeakableItem protocol
        let audioData = try await item.speak()

        // Create TypedDataStorage record
        let record = TypedDataStorage(
            providerId: item.voiceProvider.providerId,
            requestorID: "my-app.audio.tts",
            mimeType: "audio/x-aiff",  // Apple uses AIFF format
            binaryValue: audioData,
            prompt: item.textToSpeak,
            metadata: try? JSONSerialization.data(withJSONObject: [
                "voiceId": item.voiceId,
                "estimatedDuration": await item.estimateDuration()
            ])
        )

        // Insert into SwiftData
        modelContext.insert(record)
    }

    // 3. Save all records
    try modelContext.save()

    print("Generated and persisted \(items.count) audio files")
}
```

### Example Implementations

SwiftHablaré includes 5 example implementations in `Sources/SwiftHablare/Examples/SpeakableItemExamples.swift`:

#### 1. SimpleMessage
```swift
public struct SimpleMessage: SpeakableItem {
    public let voiceProvider: VoiceProvider
    public let voiceId: String
    public let content: String

    public var textToSpeak: String { content }
}
```

#### 2. CharacterDialogue
```swift
public struct CharacterDialogue: SpeakableItem {
    public let characterName: String
    public let dialogue: String
    public let voiceProvider: VoiceProvider
    public let voiceId: String
    public let includeCharacterName: Bool

    public var textToSpeak: String {
        includeCharacterName ? "\(characterName): \(dialogue)" : dialogue
    }
}
```

#### 3. Article
```swift
public struct Article: SpeakableItem {
    public let title: String
    public let author: String
    public let content: String
    public let voiceProvider: VoiceProvider
    public let voiceId: String
    public let includeMeta: Bool

    public var textToSpeak: String {
        includeMeta ? "\(title), by \(author). \(content)" : content
    }
}
```

#### 4. Notification
```swift
public struct Notification: SpeakableItem {
    public let title: String
    public let message: String
    public let timestamp: Date
    public let voiceProvider: VoiceProvider
    public let voiceId: String
    public let includeTimestamp: Bool

    public var textToSpeak: String {
        if includeTimestamp {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "\(title) at \(formatter.string(from: timestamp)). \(message)"
        }
        return "\(title). \(message)"
    }
}
```

#### 5. ListItem
```swift
public struct ListItem: SpeakableItem {
    public let number: Int
    public let content: String
    public let voiceProvider: VoiceProvider
    public let voiceId: String

    public var textToSpeak: String {
        "Step \(number): \(content)"
    }
}
```

### Test Coverage

The SpeakableItem protocol has comprehensive test coverage:

- **22 tests** in `Tests/SwiftHablareTests/SpeakableItemTests.swift`
- **100% test coverage** on protocol implementation
- Tests cover:
  - Protocol conformance
  - Speech generation
  - Duration estimation
  - Voice availability checks
  - Batch operations (speakAll, estimateTotalDuration)
  - Error handling (empty text, invalid voice)
  - Custom implementations

### Thread Safety

All `SpeakableItem` methods are async and thread-safe:
- Uses underlying `VoiceProvider` concurrency model (actor-based)
- Safe to call from any async context
- Safe to use with structured concurrency (TaskGroup, async let)

```swift
// Safe concurrent generation
await withTaskGroup(of: Data.self) { group in
    for item in items {
        group.addTask {
            try await item.speak()
        }
    }
}
```

## SpeakableItemList - Batch Generation with Progress

### Overview

`SpeakableItemList` provides structured batch audio generation with progress tracking and automatic SwiftData persistence. It's designed for processing multiple speakable items sequentially with real-time UI updates.

### Features

- **Sequential Processing**: Items processed one by one in order
- **Progress Tracking**: Real-time observable progress (current index, percentage)
- **Actor-Based**: Background audio generation with main-thread persistence
- **Cancellation**: Graceful cancellation with partial result preservation
- **Error Handling**: Captures errors while saving completed items
- **SwiftData Integration**: Automatic persistence via TypedDataStorage
- **Observable**: SwiftUI-compatible with `@Observable` macro

### Basic Usage

```swift
@MainActor
func generateSpeechList() async throws {
    // 1. Create items
    let provider = AppleVoiceProvider()
    let voices = try await provider.fetchVoices()
    let voiceId = voices.first!.id

    let items: [any SpeakableItem] = [
        SimpleMessage(content: "Hello", voiceProvider: provider, voiceId: voiceId),
        SimpleMessage(content: "World", voiceProvider: provider, voiceId: voiceId)
    ]

    // 2. Create list
    let list = SpeakableItemList(name: "Greetings", items: items)

    // 3. Generate with progress tracking
    let service = GenerationService(voiceProvider: provider)
    let records = try await service.generateList(list, to: modelContext)

    // 4. Check results
    print("Generated \(records.count) audio files")
    print("Progress: \(list.progress * 100)%")
    print("Status: \(list.statusMessage)")
}
```

### Complete Flow Diagram

```
Application (@MainActor)
    ↓
Create SpeakableItemList
    ↓
GenerationService.generateList()
    ↓
┌─────────────────────────────────────┐
│ For each item:                      │
│   1. Check cancellation             │
│   2. Generate audio (background)    │
│   3. Create TypedDataStorage (main) │
│   4. Save to SwiftData (main)       │
│   5. Update progress (main)         │
└─────────────────────────────────────┘
    ↓
Return [TypedDataStorage]
```

See `Docs/SPEAKABLE_ITEM_LIST_FLOW.md` for detailed architecture diagrams.

### Progress Tracking

The list provides real-time observable properties:

```swift
let list = SpeakableItemList(name: "My List", items: items)

// Progress properties (Observable)
list.currentIndex          // 0, 1, 2, ... totalCount
list.totalCount            // Total number of items
list.progress              // 0.0 to 1.0
list.isProcessing          // true during generation
list.isComplete            // true when finished
list.isCancelled           // true if cancelled
list.hasFailed             // true if error occurred
list.statusMessage         // "Processing...", "Complete", etc.
```

### SwiftUI Integration

```swift
import SwiftUI

struct ProgressView: View {
    @Bindable var list: SpeakableItemList

    var body: some View {
        VStack {
            Text(list.name)
                .font(.headline)

            ProgressView(value: list.progress)

            Text("\(list.currentIndex) of \(list.totalCount)")
                .font(.caption)

            Text(list.statusMessage)
                .foregroundStyle(.secondary)

            if list.isProcessing {
                Button("Cancel", action: list.cancel)
            }
        }
    }
}
```

### Cancellation Support

```swift
// Start generation
Task {
    let records = try await service.generateList(list, to: modelContext)
    print("Generated \(records.count) items")
}

// Cancel from another task/button
list.cancel()

// Partial results are preserved in SwiftData
```

### Error Handling with Partial Results

```swift
do {
    let records = try await service.generateList(list, to: modelContext)
    print("✅ Success: \(records.count) items")
} catch {
    print("❌ Error: \(error)")
    print("Saved \(list.currentIndex) items before error")
    // Partial results are already in SwiftData
}
```

### Save Intervals

For large lists, adjust save frequency:

```swift
// Save every 10 items instead of every item
let records = try await service.generateList(
    list,
    to: modelContext,
    saveInterval: 10  // Default: 1
)
```

### Complete Example

See `Sources/SwiftHablare/Examples/SpeakableItemListExample.swift` for a complete SwiftUI example with:
- Observable ViewModel
- Progress UI
- Cancellation buttons
- Record display
- Error handling

## Key Patterns

### 1. Voice Generation

**Basic Usage:**
```swift
// Initialize provider
let provider = AppleVoiceProvider()
// OR
let provider = ElevenLabsVoiceProvider()

// Fetch available voices
let voices = try await provider.fetchVoices()

// Generate audio
let audioData = try await provider.generateAudio(
    text: "Hello, world!",
    voiceId: voices.first!.id
)
```

### 2. Thread-Safe Generation with GenerationService

**Recommended Pattern:**
```swift
// Create service (actor for thread safety)
let service = GenerationService(voiceProvider: provider)

// Generate audio (thread-safe)
let audioData = try await service.generate(
    text: "Hello, world!",
    voiceId: "voice-id",
    voiceName: "Voice Name"
)
```

**Benefits:**
- ✅ Actor-based synchronization (no data races)
- ✅ Swift 6 concurrency compliant
- ✅ Automatic thread management
- ✅ Clean separation of concerns

### 3. Voice Provider Registry

**Overview:**

The `GenerationService` maintains a registry of voice providers, making it easy to work with multiple providers in a single application. The registry automatically includes Apple and ElevenLabs providers and supports custom providers.

**Default Providers:**

```swift
// Create service - Apple and ElevenLabs are automatically registered
let service = GenerationService(voiceProvider: AppleVoiceProvider())

// Get all registered providers
let providers = await service.registeredProviders()
// Returns: [AppleVoiceProvider, ElevenLabsVoiceProvider]
```

**Working with Registry:**

```swift
// Get a specific provider by ID
if let appleProvider = await service.provider(withId: "apple") {
    let voices = try await appleProvider.fetchVoices()
}

// Check if provider is registered
let hasElevenLabs = await service.isProviderRegistered("elevenlabs")

// Register a custom provider
let customProvider = MyCustomVoiceProvider()
await service.registerProvider(customProvider)
```

**Fetching Voices from Providers:**

```swift
// Fetch voices from a specific provider by ID
let appleVoices = try await service.fetchVoices(from: "apple")
let elevenLabsVoices = try await service.fetchVoices(from: "elevenlabs")

// Fetch voices from all configured providers
let allVoices = try await service.fetchAllVoices()
// Returns: ["apple": [Voice], "elevenlabs": [Voice]]

// Iterate through all voices
for (providerId, voices) in allVoices {
    print("\(providerId): \(voices.count) voices available")
    for voice in voices {
        print("  - \(voice.name)")
    }
}
```

**Benefits:**
- ✅ Centralized provider management
- ✅ Easy switching between providers
- ✅ Automatic filtering of unconfigured providers
- ✅ Graceful error handling (skips failing providers)
- ✅ Support for custom voice providers

**Building UI with the Registry:**

Since SwiftHablaré is a generation library without UI components, consuming applications should build their own UI. Here's an example provider picker:

```swift
// In your app (NOT in SwiftHablaré library)
import SwiftUI
import SwiftHablare

struct ProviderPickerView: View {
    let service: GenerationService
    @State private var providers: [VoiceProvider] = []
    @State private var selectedProvider: VoiceProvider?

    var body: some View {
        List(providers, id: \.providerId) { provider in
            Button {
                selectedProvider = provider
            } label: {
                HStack {
                    VStack(alignment: .leading) {
                        Text(provider.displayName)
                            .font(.headline)
                        Text(provider.providerId)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if provider.providerId == selectedProvider?.providerId {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.blue)
                    }

                    if !provider.isConfigured() {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .help("Provider not configured")
                    }
                }
            }
        }
        .task {
            providers = await service.registeredProviders()
        }
        .navigationTitle("Voice Providers")
    }
}

struct VoicePickerView: View {
    let service: GenerationService
    let providerId: String
    @State private var voices: [Voice] = []
    @State private var selectedVoice: Voice?

    var body: some View {
        List(voices, id: \.id) { voice in
            Button {
                selectedVoice = voice
            } label: {
                HStack {
                    VStack(alignment: .leading) {
                        Text(voice.name)
                            .font(.headline)
                        HStack {
                            if let language = voice.language {
                                Text(language)
                                    .font(.caption)
                            }
                            if let gender = voice.gender {
                                Text("• \(gender)")
                                    .font(.caption)
                            }
                        }
                        .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if voice.id == selectedVoice?.id {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.blue)
                    }
                }
            }
        }
        .task {
            do {
                voices = try await service.fetchVoices(from: providerId)
            } catch {
                print("Error fetching voices: \(error)")
            }
        }
        .navigationTitle("Select Voice")
    }
}
```

### 4. API Key Management

**Storing API Keys:**
```swift
let keychain = KeychainManager()

// Store API key
try keychain.save(
    key: "elevenlabs-api-key",
    value: "your-api-key-here"
)

// Retrieve API key
let apiKey = try keychain.get(key: "elevenlabs-api-key")

// Delete API key
try keychain.delete(key: "elevenlabs-api-key")
```

**Security:**
- ✅ Uses system Keychain for secure storage
- ✅ Thread-safe operations
- ✅ Automatic cleanup on delete

### 5. Voice Caching

**SwiftData Model:**
```swift
@Model
public final class VoiceCacheModel {
    @Attribute(.unique) public var id: String
    public var name: String
    public var providerId: String
    public var language: String?
    public var locality: String?
    public var gender: String?
    public var cachedAt: Date
}
```

**Usage:**
```swift
// Voices are automatically cached when fetched
// Cache reduces API calls and improves performance
// Consuming apps should invalidate cache periodically
```

## Development Workflow

### For New Features

1. **Read Documentation**:
   - This file (CLAUDE.md)
   - README.md for API overview
   - Test files for usage examples

2. **Plan with Todos**:
   - Use TodoWrite tool for complex tasks
   - Break down into manageable steps
   - Track progress throughout implementation

3. **Write Tests First** (TDD approach):
   - Unit tests for core logic
   - Integration tests for end-to-end workflows
   - Aim for 95%+ coverage

4. **Implement Features**:
   - Follow existing patterns
   - Use actors for thread safety
   - Ensure Swift 6 concurrency compliance

5. **Verify Coverage**:
   - Run tests: `swift test --enable-code-coverage`
   - Check coverage: `xcrun llvm-cov report`
   - Aim for 95%+ on all new code

### For Bug Fixes

1. **Write Failing Test**: Create a test that reproduces the bug
2. **Fix the Bug**: Implement the fix
3. **Verify**: Ensure the test passes and existing tests still work
4. **Document**: Update comments and docs as needed

## Code Style

### Voice Provider Implementation

```swift
public final class MyVoiceProvider: VoiceProvider {
    public let providerId = "my-provider"
    public let displayName = "My Provider"
    public let requiresAPIKey = true

    public func isConfigured() -> Bool {
        // Check if API key exists
        return (try? keychain.get(key: "\(providerId)-api-key")) != nil
    }

    public func fetchVoices() async throws -> [Voice] {
        // Fetch voices from API
        // Return Voice models
    }

    public func generateAudio(text: String, voiceId: String) async throws -> Data {
        // Generate audio using API
        // Return audio data (MP3, AIFF, etc.)
    }

    public func estimateDuration(text: String, voiceId: String) async -> TimeInterval {
        // Estimate duration based on text length
        // Return estimated seconds
    }

    public func isVoiceAvailable(voiceId: String) async -> Bool {
        // Check if voice is available
        // Return true/false
    }
}
```

### Actor-Based Services

```swift
actor MyService {
    private let provider: VoiceProvider

    init(voiceProvider: VoiceProvider) {
        self.provider = voiceProvider
    }

    func process(_ request: MyRequest) async throws -> MyResult {
        // Actor ensures thread-safe operations
        // All state access is synchronized
        return MyResult()
    }
}
```

### Platform-Specific Code

**IMPORTANT: Never use `#if os(macOS)` guards in this codebase.**

This library is iOS and Catalyst ONLY. The only platform-specific guard allowed is for simulators:

```swift
#if targetEnvironment(simulator)
// iOS Simulator - placeholder/mock for testing
// Real TTS doesn't work on simulators
#else
// Physical iOS/Catalyst devices
// Real TTS functionality
#endif
```

**DO NOT** add macOS support or macOS-specific code paths. SwiftHablaré does not support macOS.

## Testing Strategy

### Unit Tests

**Coverage Targets:**
- Voice Providers: 95%+
- GenerationService: 95%+
- KeychainManager: 95%+
- Models: 100%

**Current Status:**
- 73 total tests passing
- 96%+ average coverage
- 0 test failures
- Swift 6 strict concurrency compliance

### Integration Tests

**Apple Voice Provider:**
```swift
func testEndToEndSpeechGeneration() async throws {
    #if os(macOS)
    throw XCTSkip("Apple TTS integration test skipped on macOS")
    #endif

    // Test on iOS/Catalyst only
    let provider = AppleVoiceProvider()
    let voices = try await provider.fetchVoices()
    let audioData = try await provider.generateAudio(text: "Test", voiceId: voices.first!.id)

    // Validate audio
    XCTAssertGreaterThan(audioData.count, 1024)
}
```

**ElevenLabs Voice Provider:**
```swift
func testEndToEndWithElevenLabs() async throws {
    guard let apiKey = ProcessInfo.processInfo.environment["ELEVENLABS_API_KEY"] else {
        throw XCTSkip("ELEVENLABS_API_KEY not set")
    }

    // Test with real API
    let provider = ElevenLabsVoiceProvider()
    // ... test implementation
}
```

### Performance Tests

```swift
func testVoiceFetchingPerformance() async throws {
    measure {
        let voices = try await provider.fetchVoices()
        XCTAssertFalse(voices.isEmpty)
    }
}
```

## Quality Gates

Before submitting a PR:

- ✅ All tests pass
- ✅ 95%+ test coverage on new code
- ✅ Swift 6 strict concurrency compliance
- ✅ No compiler warnings
- ✅ Documentation updated
- ✅ CHANGELOG.md updated
- ✅ Platform compatibility verified (iOS/Catalyst)

## Common Tasks

### Add a New Voice Provider

1. Create class conforming to `VoiceProvider`
2. Implement all required methods
3. Add API key support if needed
4. Write comprehensive tests (20+ test cases)
5. Update documentation

### Generate Audio

```swift
let provider = AppleVoiceProvider()
let voices = try await provider.fetchVoices()
let audioData = try await provider.generateAudio(
    text: "Hello, world!",
    voiceId: voices.first!.id
)
// Use audioData in your app
```

### Work with Provider Registry

```swift
// Create service with provider registry
let service = GenerationService(voiceProvider: AppleVoiceProvider())

// Get all available providers
let providers = await service.registeredProviders()

// Fetch voices from a specific provider
let appleVoices = try await service.fetchVoices(from: "apple")

// Fetch voices from all providers
let allVoices = try await service.fetchAllVoices()
for (providerId, voices) in allVoices {
    print("\(providerId): \(voices.count) voices")
}

// Register a custom provider
let customProvider = MyCustomVoiceProvider()
await service.registerProvider(customProvider)
```

### Cache Voices in SwiftData

```swift
@MainActor
func cacheVoices() async throws {
    let provider = AppleVoiceProvider()
    let voices = try await provider.fetchVoices()

    for voice in voices {
        let cache = VoiceCacheModel(
            id: voice.id,
            name: voice.name,
            providerId: voice.providerId,
            language: voice.language,
            locality: voice.locality,
            gender: voice.gender
        )
        modelContext.insert(cache)
    }
    try modelContext.save()
}
```

## Resources

### Documentation
- `README.md` - Project overview and API documentation
- `CHANGELOG.md` - Version history
- `Tests/README.md` - Test suite documentation
- `VOICE_PROVIDER_INTEGRATION_GUIDE.md` - Provider integration guide

### Testing
- `Tests/SwiftHablareTests/` - All test suites
  - `AppleVoiceProviderTests.swift` - Apple provider tests
  - `GenerationServiceTests.swift` - Service tests
  - `VoiceModelTests.swift` - Model tests
  - `Integration/` - End-to-end integration tests

### Examples
- `Examples/Hablare/` - Sample application (minimal reference)

## Library Scope and Philosophy

**SwiftHablaré is a focused voice generation library**:
- Takes text and voice ID as input
- Generates audio using the specified voice provider
- Returns audio data for the consuming application to use

**Out of Scope**:
- ❌ UI components (apps build their own)
- ❌ Data persistence (beyond voice caching)
- ❌ Audio playback (apps handle playback)
- ❌ Screenplay processing
- ❌ Background task management
- ❌ Character-to-voice mapping

**In Scope**:
- ✅ Voice provider integration (Apple TTS, ElevenLabs)
- ✅ Voice provider registry and management
- ✅ Voice fetching and caching
- ✅ Thread-safe audio generation
- ✅ API key management
- ✅ Platform compatibility (iOS, Catalyst)

---

**For Questions or Contributions**:
- GitHub Issues: https://github.com/intrusive-memory/SwiftHablare/issues
- GitHub Discussions: https://github.com/intrusive-memory/SwiftHablare/discussions
