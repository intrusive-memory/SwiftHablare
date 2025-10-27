# SwiftHablaré - Claude Code Development Guide

This document provides guidance for AI assistants (particularly Claude Code) working on the SwiftHablaré project.

## Project Overview

**SwiftHablaré** is a Swift voice generation library for iOS and Mac Catalyst applications. It provides a simple, unified API for text-to-speech generation using multiple voice providers (Apple TTS and ElevenLabs), with automatic voice caching, secure API key management, and optional SwiftUI components for audio generation.

**Key Focus**: Voice generation library with optional UI components. Includes core generation services, SwiftUI pickers and buttons, voice caching, but no audio playback, no screenplay processing beyond generation. SwiftHablaré is a **generation library** with helpful UI components, not a complete application framework.

## Version Information

- **Current Version**: 2.3.0
- **Swift Version**: 6.0+
- **Minimum Deployments**: iOS 26.0, macCatalyst 26.0
- **macOS Support**: ❌ **NOT SUPPORTED** - iOS and Catalyst only
- **Total Tests**: 164+ passing
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
│   ├── SpeakableItem.swift          # Protocol for speakable objects
│   └── SpeakableGroup.swift         # ✨ Protocol for grouped speakable items
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
├── UI/
│   ├── ProviderPickerView.swift     # SwiftUI provider picker
│   ├── VoicePickerView.swift        # SwiftUI voice picker
│   ├── GenerateAudioButton.swift    # ✨ Individual element audio generation button
│   └── GenerateGroupButton.swift    # ✨ Batch generation button for groups
└── Examples/
    ├── SpeakableItemExamples.swift  # Example implementations
    ├── SpeakableGroupExamples.swift # ✨ Example group implementations
    └── SpeakableItemListExample.swift # ✨ Complete batch generation example
```

### UI Components

SwiftHablaré provides simple SwiftUI components for voice selection and audio generation:

**ProviderPickerView**:
- Displays all registered providers from GenerationService
- Shows provider display name and configuration status
- Binds to selected provider ID (String?)

**VoicePickerView**:
- Displays voices from a specific provider
- Shows voice name, language, gender, and locality
- Handles loading states and errors
- Binds to selected voice ID (String?)

**GenerateAudioButton** (v2.3.0):
- Individual element audio generation with progress tracking
- Automatically checks for existing audio in SwiftData
- Shows "Generate" or "Play" based on audio availability
- Displays progress bar and cancellation support
- Race condition fix: Prevents duplicate generation during async checks

**GenerateGroupButton** (v2.3.0):
- Batch generation for grouped speakable items
- Smart audio detection: Shows "Generate All (N items)" or "Regenerate All (N items)"
- Skips items with existing audio by default (efficient)
- Progress tracking as "X/Y items (Z%)"
- Cancellation support with partial result preservation
- Uses SpeakableItemList internally for sequential processing

These are simple, focused UI components that integrate directly with GenerationService and SwiftData. Applications can use these as-is or build their own custom UI.

**Not Included**:
- ❌ Audio players (apps handle playback)
- ❌ Recording interfaces
- ❌ Complex voice management UIs
- ❌ Per-item progress in group generation (items track their own progress)

Applications are responsible for audio playback and more complex UI workflows.

### Data Persistence

SwiftHablaré integrates with **TypedDataStorage** from SwiftCompartido for generated audio persistence:
- ✅ Uses `TypedDataStorage` from SwiftCompartido for generated audio
- ✅ `GenerationService.generateList()` automatically creates TypedDataStorage records
- ✅ `GenerationResult.toTypedDataStorage()` converts generation results to SwiftData

SwiftHablaré provides one SwiftData model:
- `VoiceCacheModel` - For caching fetched voices to improve performance

SwiftHablaré does NOT provide:
- ❌ Audio file storage (apps handle file I/O)
- ❌ Persistence coordinators
- ❌ Custom SwiftData models beyond VoiceCacheModel

### What's Included vs Not Included

**SwiftHablaré includes:**
- ✅ `SpeakableItem` protocol for protocol-oriented TTS
- ✅ `SpeakableGroup` protocol for batch audio generation (v2.3.0)
- ✅ Voice provider integration (Apple TTS, ElevenLabs)
- ✅ Provider registry and management
- ✅ Thread-safe audio generation
- ✅ Voice caching with SwiftData
- ✅ TypedDataStorage integration for generated audio
- ✅ Simple UI pickers (provider & voice selection)
- ✅ Audio generation buttons (individual & batch) (v2.3.0)

**SwiftHablaré does NOT include:**
- ❌ Screenplay processing or screenplay-specific models
- ❌ Background task management
- ❌ Character-to-voice mapping
- ❌ Audio playback functionality
- ❌ Complex UI workflows beyond generation

## Voice Providers

### AppleVoiceProvider

**Platform-Specific Behavior:**
```swift
#if targetEnvironment(simulator)
// iOS Simulator: Placeholder AIFF audio (silent) for test compatibility
// Real TTS not available on simulator due to AVSpeechSynthesizer.write() limitation
#else
// Physical iOS/Catalyst devices: Real speech synthesis using AVSpeechSynthesizer.write()
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
- 4 integration tests (skipped on iOS Simulator, run on physical devices)

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
    let service = GenerationService(modelContext: modelContext)
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

## SpeakableGroup Protocol - Batch Audio Generation (v2.3.0)

### Overview

The `SpeakableGroup` protocol enables **grouped audio generation** where collections of `SpeakableItem` objects can be processed together with a single "Generate All" action. This is perfect for generating audio for chapters, scenes, playlists, or any logical grouping of speakable content.

### Protocol Definition

```swift
public protocol SpeakableGroup {
    var groupName: String { get }
    func getGroupedElements() -> [any SpeakableItem]
    var groupDescription: String? { get }
}

extension SpeakableGroup {
    public var groupDescription: String? { nil }
    public var itemCount: Int {
        getGroupedElements().count
    }
}
```

### Design Philosophy

**Protocol-Oriented Design:**
- ✅ Any type can become a speakable group
- ✅ Flexible grouping logic in `getGroupedElements()`
- ✅ Supports recursive expansion (groups within groups)
- ✅ Easy to test and mock
- ✅ Composable with SpeakableItem

**Key Benefits:**
1. **One-Tap Generation**: Generate audio for entire collections
2. **Smart Detection**: Automatically detects which items need generation
3. **Progress Tracking**: Shows "X/Y items (Z%)" during generation
4. **Efficient**: Skips items with existing audio by default
5. **Recursive**: Groups can contain other groups

### Basic Usage

```swift
// Create a group type
struct Chapter: SpeakableGroup {
    let number: Int
    let title: String
    let dialogueLines: [DialogueLine]
    let provider: VoiceProvider

    var groupName: String {
        "Chapter \(number): \(title)"
    }

    var groupDescription: String? {
        "\(dialogueLines.count) dialogue lines"
    }

    func getGroupedElements() -> [any SpeakableItem] {
        return dialogueLines.map { line in
            CharacterDialogue(
                characterName: line.characterName,
                dialogue: line.text,
                voiceProvider: provider,
                voiceId: line.voiceId,
                includeCharacterName: true
            )
        }
    }
}

// Use with GenerateGroupButton
GenerateGroupButton(
    group: chapter,
    service: generationService,
    modelContext: modelContext
)
```

### Recursive Group Expansion

Groups can contain other groups, which are automatically expanded:

```swift
struct Screenplay: SpeakableGroup {
    let acts: [Act]

    func getGroupedElements() -> [any SpeakableItem] {
        var items: [any SpeakableItem] = []

        for act in acts {
            // Acts are groups themselves - recursively expand
            items.append(contentsOf: act.getGroupedElements())
        }

        return items
    }
}

struct Act: SpeakableGroup {
    let scenes: [Scene]

    func getGroupedElements() -> [any SpeakableItem] {
        var items: [any SpeakableItem] = []

        for scene in scenes {
            // Scenes are groups - recursively expand
            items.append(contentsOf: scene.getGroupedElements())
        }

        return items
    }
}
```

### Example Implementations

SwiftHablaré includes 5 example implementations in `Sources/SwiftHablare/Examples/SpeakableGroupExamples.swift`:

#### 1. Chapter (Books with dialogue)
```swift
public struct Chapter: SpeakableGroup {
    public let number: Int
    public let title: String
    public let dialogueLines: [DialogueLine]
    public let provider: VoiceProvider

    public var groupName: String {
        "Chapter \(number): \(title)"
    }

    public var groupDescription: String? {
        "\(dialogueLines.count) dialogue lines"
    }
}
```

#### 2. Scene (Theatrical scripts)
```swift
public struct Scene: SpeakableGroup {
    public let number: Int
    public let location: String
    public let interactions: [Interaction]
    public let provider: VoiceProvider
    public let includeSceneHeading: Bool

    public var groupName: String {
        "Scene \(number) - \(location)"
    }

    public var groupDescription: String? {
        "\(interactions.count) interactions at \(location)"
    }
}
```

#### 3. MessagePlaylist (Notifications with priority)
```swift
public struct MessagePlaylist: SpeakableGroup {
    public let name: String
    public let messages: [PlaylistMessage]
    public let provider: VoiceProvider
    public let defaultVoiceId: String

    public var groupDescription: String? {
        let highPriority = messages.filter { $0.priority == .high }.count
        return "\(messages.count) messages (\(highPriority) high priority)"
    }
}
```

#### 4. ArticleSections (Long-form content)
```swift
public struct ArticleSections: SpeakableGroup {
    public let title: String
    public let author: String
    public let sections: [ArticleSection]
    public let provider: VoiceProvider

    public var groupName: String {
        "\(title) by \(author)"
    }

    public var groupDescription: String? {
        "\(sections.count) sections"
    }
}
```

#### 5. ShoppingList (Enumerated tasks)
```swift
public struct ShoppingList: SpeakableGroup {
    public let name: String
    public let items: [String]
    public let provider: VoiceProvider
    public let voiceId: String
    public let includeNumbers: Bool

    public var groupDescription: String? {
        "\(items.count) items"
    }
}
```

### GenerateGroupButton UI Component

The `GenerateGroupButton` provides a complete UI for group generation:

**Features:**
- Automatically detects existing audio for all items
- Shows "Generate All (N items)" when some items need audio
- Shows "Regenerate All (N items)" when all items have audio
- Displays progress as "X/Y items (Z%)"
- Cancellation support
- Skips items with existing audio by default

**Usage:**
```swift
import SwiftUI
import SwiftHablare

struct MyView: View {
    let group: any SpeakableGroup
    let service: GenerationService
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        GenerateGroupButton(
            group: group,
            service: service,
            modelContext: modelContext,
            onComplete: { records in
                print("Generated \(records.count) audio files")
            }
        )
    }
}
```

### Test Coverage

The SpeakableGroup protocol has comprehensive test coverage:

- **18 tests** in `Tests/SwiftHablareTests/SpeakableGroupTests.swift`
- **100% test coverage** on protocol implementation
- Tests cover:
  - Protocol conformance
  - Group name and description
  - Element retrieval
  - All 5 example implementations
  - GenerateGroupButton functionality
  - Existing audio detection
  - Empty groups
  - Multiple audio records
  - Integration with GenerationService

### Thread Safety

All `SpeakableGroup` operations are thread-safe:
- `getGroupedElements()` is synchronous but safe to call from any context
- `GenerateGroupButton` uses `GenerationService` actor for background generation
- SwiftData saves happen on `@MainActor`
- Progress updates happen on main thread

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
let service = GenerationService(modelContext: modelContext)

// Generate audio (thread-safe)
let result = try await service.generate(
    text: "Hello, world!",
    providerId: "apple",  // Required: "apple" or "elevenlabs"
    voiceId: "voice-id",
    voiceName: "Voice Name"
)

// Result contains audio data and metadata
let audioData = result.audioData
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
let service = GenerationService(modelContext: modelContext)

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

**Using the Built-in UI Components:**

SwiftHablaré now includes simple SwiftUI pickers for provider and voice selection. See section "4. UI Components" below for usage examples and documentation.

### 4. UI Components

**ProviderPickerView**

Simple SwiftUI picker for selecting a voice provider:

```swift
import SwiftUI
import SwiftHablare

struct MyView: View {
    let service = GenerationService(modelContext: modelContext)
    @State private var selectedProviderId: String?

    var body: some View {
        Form {
            ProviderPickerView(
                service: service,
                selection: $selectedProviderId
            )
        }
    }
}
```

**VoicePickerView**

Simple SwiftUI picker for selecting a voice from a provider:

```swift
import SwiftUI
import SwiftHablare

struct MyView: View {
    let service = GenerationService(modelContext: modelContext)
    @State private var selectedVoiceId: String?

    var body: some View {
        Form {
            VoicePickerView(
                service: service,
                providerId: "apple",
                selection: $selectedVoiceId
            )
        }
    }
}
```

**Combined Example**

Using both pickers together:

```swift
import SwiftUI
import SwiftHablare

struct VoiceSelectionView: View {
    let service = GenerationService(modelContext: modelContext)

    @State private var selectedProviderId: String?
    @State private var selectedVoiceId: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Provider") {
                    ProviderPickerView(
                        service: service,
                        selection: $selectedProviderId
                    )
                }

                if let providerId = selectedProviderId {
                    Section("Voice") {
                        VoicePickerView(
                            service: service,
                            providerId: providerId,
                            selection: $selectedVoiceId
                        )
                    }
                }

                if selectedVoiceId != nil, selectedProviderId != nil {
                    Section("Generate") {
                        Button("Generate Speech") {
                            Task {
                                try await generateSpeech()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Voice Selection")
        }
    }

    func generateSpeech() async throws {
        guard let voiceId = selectedVoiceId,
              let providerId = selectedProviderId else { return }

        let result = try await service.generate(
            text: "Hello, world!",
            providerId: providerId,
            voiceId: voiceId,
            voiceName: "Selected Voice"
        )

        // Convert to TypedDataStorage and save
        let storage = result.toTypedDataStorage()
        modelContext.insert(storage)
        try modelContext.save()
    }
}
```

**Benefits:**
- ✅ Simple, focused UI components
- ✅ Fetch data directly from GenerationService
- ✅ Handle loading and error states
- ✅ SwiftUI bindings for easy integration
- ✅ Show provider configuration status

### 5. API Key Management

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

### 6. Voice Caching

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

### Test Organization

Tests are split into **fast** (unit) and **slow** (integration) categories:

**Fast Tests (Unit):**
- Run on every PR
- Complete in ~30 seconds
- Skip integration tests
- Run on iOS Simulator (iPhone 16 Pro)
- Test class names WITHOUT "Integration"

**Integration Tests (Long-Running):**
- Run weekly on Saturdays at 3 AM UTC
- Complete in ~2-5 minutes
- Include real API calls
- Run on iOS Simulator (iPhone 16 Pro)
- Test class names WITH "Integration"

**Platform Requirements:**
- ✅ Tests run on iOS Simulator ONLY
- ❌ Tests do NOT run on macOS (not supported)
- ✅ Mac Catalyst support (built for Catalyst, tested on simulator)

### Unit Tests

**Coverage Targets:**
- Voice Providers: 95%+
- GenerationService: 95%+
- KeychainManager: 95%+
- Models: 100%

**Current Status:**
- 109 total tests passing
- 96%+ average coverage
- 0 test failures
- Swift 6 strict concurrency compliance

### Integration Tests

**IMPORTANT:** Integration tests run on iOS Simulator. Use `#if targetEnvironment(simulator)` to skip tests that require real audio on simulator.

**Apple Voice Provider:**
```swift
func testEndToEndSpeechGeneration() async throws {
    #if targetEnvironment(simulator)
    throw XCTSkip("Apple TTS integration test skipped on simulator")
    #endif

    // Test on iOS/Catalyst devices only
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

### Running Tests

**Run all tests on iOS Simulator:**
```bash
xcodebuild test \
  -scheme SwiftHablare \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

**Run only unit tests (fast):**
```bash
xcodebuild test \
  -scheme SwiftHablare \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -skip-testing:SwiftHablareTests/AppleVoiceProviderIntegrationTests \
  -skip-testing:SwiftHablareTests/ElevenLabsVoiceProviderIntegrationTests
```

**Run only integration tests:**
```bash
xcodebuild test \
  -scheme SwiftHablare \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:SwiftHablareTests/AppleVoiceProviderIntegrationTests \
  -only-testing:SwiftHablareTests/ElevenLabsVoiceProviderIntegrationTests
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
let service = GenerationService(modelContext: modelContext)

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
- Takes text, provider ID, and voice ID as input
- Generates audio using the specified voice provider
- Returns audio data and metadata for the consuming application
- Integrates with TypedDataStorage for SwiftData persistence

**Out of Scope**:
- ❌ Audio playback (apps handle playback)
- ❌ Audio file I/O (apps handle file storage)
- ❌ Screenplay processing or domain-specific models
- ❌ Background task management
- ❌ Character-to-voice mapping
- ❌ Complex UI workflows

**In Scope**:
- ✅ Voice provider integration (Apple TTS, ElevenLabs)
- ✅ Voice provider registry and management
- ✅ Voice fetching and caching (VoiceCacheModel)
- ✅ Thread-safe audio generation (actor-based)
- ✅ API key management (Keychain)
- ✅ TypedDataStorage integration for generated audio
- ✅ SpeakableItem protocol for protocol-oriented TTS
- ✅ SpeakableGroup protocol for batch audio generation (v2.3.0)
- ✅ SpeakableItemList for batch generation with progress
- ✅ Platform compatibility (iOS 26+, Catalyst 26+)
- ✅ Simple UI pickers (provider & voice selection)
- ✅ Audio generation buttons (individual & batch) (v2.3.0)

---

**For Questions or Contributions**:
- GitHub Issues: https://github.com/intrusive-memory/SwiftHablare/issues
- GitHub Discussions: https://github.com/intrusive-memory/SwiftHablare/discussions
- add to memory: This project is an iOS and MacCatalyst project only. Any and all programming for macOS added now or in the path has no place in this project.
- add to memory: this library is iOS and MacCatalyst only. Do not compile or program for MacOS.
- add to memory: This library should be run on iOS 26 and MacCatalyst 26 only.