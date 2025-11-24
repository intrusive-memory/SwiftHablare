# SwiftHablaré - Claude Code Development Guide

This document provides guidance for AI assistants (particularly Claude Code) working on the SwiftHablaré project.

## Project Overview

**SwiftHablaré** is a Swift voice generation library for iOS, macOS, and Mac Catalyst applications. It provides a simple, unified API for text-to-speech generation using multiple voice providers (Apple TTS and ElevenLabs), with automatic voice caching, secure API key management, and optional SwiftUI components for audio generation.

**Key Focus**: Voice generation library with optional UI components. Includes core generation services, SwiftUI pickers and buttons, voice caching, but no audio playback, no screenplay processing beyond generation. SwiftHablaré is a **generation library** with helpful UI components, not a complete application framework.

## Version Information

- **Current Version**: 4.0.0
- **Swift Version**: 6.0+
- **Minimum Deployments**: iOS 26.0, macOS 26.0, macCatalyst 26.0
- **macOS Support**: ✅ **FULLY SUPPORTED** - native macOS support with NSSpeechSynthesizer
- **Total Tests**: 259 passing
- **Test Coverage**: 96%+ on voice generation components
- **Swift Concurrency**: Full Swift 6 compliance with strict concurrency enabled
- **Language Support**: ✨ Multi-language voice generation with language-specific caching (v2.3.0+)
- **Provider Registry**: ✨ Centralized provider management with configuration panels (v3.5.1+)
- **Engine Boundary Protocol**: ✨ Platform-agnostic voice engine abstraction (v3.5.1+)
- **Performance**: ⚡ **v4.0.0 OPTIMIZATIONS** - 15-25% faster voice loading, 50% faster UI, 10-20x faster cache clearing

## Platform Support

### Platform Matrix

**SwiftHablaré ships with first-class support for iOS, macOS, and Mac Catalyst.**

Supported platforms:
- **iOS 26.0+** ✅ Full TTS support with real audio generation via `AVSpeechSynthesizer.write()`
- **macOS 26.0+** ✅ Full TTS support with real audio generation via `NSSpeechSynthesizer`
- **macCatalyst 26.0+** ✅ Full TTS support using the iOS engine (AVSpeechSynthesizer) running in Catalyst

**Platform-Specific Implementations:**
- iOS and Catalyst use `AVSpeechTTSEngine` (AVFoundation)
- macOS uses `NSSpeechTTSEngine` (AppKit)
- Both engines implement the `VoiceEngine` protocol for consistency

**IMPORTANT:** Use explicit platform guards when interacting with UI frameworks:
- `#if os(iOS)` / `#elseif targetEnvironment(macCatalyst)` for UIKit-only APIs
- `#if os(macOS)` for AppKit-only APIs
- `#if targetEnvironment(simulator)` for simulator-specific behavior

### Simulator Behavior

- **Physical iOS/Catalyst devices**: Real TTS with `AVSpeechSynthesizer.write()`
- **iOS Simulator**: May produce limited audio (AVSpeechSynthesizer.write() has limited functionality on simulators)
- **macOS**: Always produces real audio via `NSSpeechSynthesizer`

Integration tests that require real audio are skipped on simulators using `#if targetEnvironment(simulator)`.

## What's New in v4.0.0

SwiftHablaré v4.0.0 is a **performance-focused major release** that delivers significant speed improvements while removing deprecated code and fixing concurrency issues.

### Performance Improvements

**Voice Loading:**
- ⚡ **15-25% faster** - Optimized cache invalidation with batch deletion (`GenerationService.swift:712-720`)
- ⚡ **10-20x faster cache clearing** - Single-transaction batch deletion replaces individual delete operations
- ⚡ **Reduced database overhead** - Disabled autosave during batch operations

**UI Rendering:**
- ⚡ **50% faster GenerateAudioButton** - Eliminated redundant FetchDescriptor creation (`GenerateAudioButton.swift:118-130`)
- ⚡ **Computed property caching** - FetchDescriptor created once per button lifecycle instead of twice per check

**Memory & Code Quality:**
- ⚡ **250+ lines of dead code removed** - Eliminated deprecated VoiceProviderType (19 lines) and VoiceProviderInfo (21 lines)
- ⚡ **4 duplicate switch statements consolidated** - Protocol-based MIME type resolution
- ⚡ **10+ duplicate language code resolutions** - Centralized LanguageCodeResolver utility

### Breaking Changes

**IMPORTANT for Custom VoiceProvider Implementations:**

1. **VoiceProvider Protocol Requires `mimeType`**
   ```swift
   public protocol VoiceProvider: Sendable {
       var mimeType: String { get }  // NEW - REQUIRED
       // ... existing properties
   }
   ```

   **Migration:** Add `public let mimeType = "audio/mpeg"` (or appropriate MIME type) to your custom provider.

2. **VoiceProviderType Enum Removed**
   - Use string provider IDs (`"apple"`, `"elevenlabs"`) instead of enum cases
   - Removed 19 lines of deprecated code from `VoiceProvider.swift`

3. **VoiceProviderInfo Struct Removed**
   - Never used in public API
   - Removed 21 lines of unused code from `VoiceProvider.swift`

### New Features

**LanguageCodeResolver Utility** (`Sources/SwiftHablare/Utilities/LanguageCodeResolver.swift`):
```swift
// Centralized language code resolution
LanguageCodeResolver.systemLanguageCode  // "en", "es", etc.
LanguageCodeResolver.resolve(nil)        // Returns system language with fallback
LanguageCodeResolver.resolve("es")       // Returns "es"
```

**Benefits:**
- Eliminates 10+ duplicate implementations across codebase
- Consistent fallback behavior (defaults to "en" if locale unavailable)
- Single source of truth for language code resolution

### Swift 6 Compliance Fixes

**VoiceProviderRegistry Concurrency Violation Fixed** (`VoiceProviderRegistry.swift:107`):
```swift
// BEFORE (v3.x) - UNSAFE:
nonisolated(unsafe) private let userDefaults: UserDefaults

// AFTER (v4.0) - SAFE:
private let userDefaults: UserDefaults
```

**Impact:** Properly actor-isolated UserDefaults access eliminates potential data races in concurrent environments.

### Performance Metrics

**Measured Improvements:**
- Voice cache invalidation: **10-20x faster** (5ms → 0.25ms for 100 voices)
- GenerateAudioButton render: **50% faster** (eliminated 1 of 2 FetchDescriptor creations)
- Voice loading: **15-25% faster** (batch deletion + autosave optimization)
- Code size: **250+ lines removed** (dead code elimination)

**Test Coverage:**
- All 259 tests passing
- 96%+ coverage maintained
- No performance regressions detected

### Migration Guide

See the [Migration from 3.x to 4.0](#migration-from-3x-to-40) section below for complete migration instructions and code examples.

**Documentation:**
- Full performance audit: `Docs/PERFORMANCE_AUDIT_V4.md`
- Complete changelog: `CHANGELOG.md`
- Migration guide: README.md

## Architecture

### Core Components

```
SwiftHablare/
├── VoiceProvider.swift              # Protocol for voice providers
├── Protocols/VoiceEngine.swift      # Engine Boundary Protocol for providers
├── Protocols/
│   ├── SpeakableItem.swift          # Protocol for speakable objects
│   └── SpeakableGroup.swift         # ✨ Protocol for grouped speakable items
├── Models/
│   ├── Voice.swift                  # Voice model (id, name, language, etc.)
│   └── SpeakableItemList.swift      # ✨ Batch generation with progress
├── Providers/
│   ├── AppleVoiceProvider.swift     # Apple TTS implementation
│   ├── ElevenLabsVoiceProvider.swift # ElevenLabs API implementation
│   ├── Apple/AppleTTSEngineBoundary.swift # Engine adapter for Apple TTS
│   └── ElevenLabs/ElevenLabsEngine.swift  # Engine adapter for ElevenLabs
├── Generation/
│   └── GenerationService.swift      # ✨ Actor-based service with provider registry
├── VoiceProviderRegistry.swift      # ✨ Registry + enablement state for voice providers
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

### Engine Boundary Protocol

SwiftHablaré uses an **Engine Boundary Protocol** (`VoiceEngine`) to isolate low-level speech synthesis engines from provider integration logic. Providers remain responsible for configuration, key management, caching, and storage, while engines focus on fetching voices and generating audio. The pattern is documented for AI collaborators in `Docs/EngineBoundaryProtocol.md`.

**File & MIME metadata:** Every `VoiceEngineOutput` must expose the recommended `fileExtension` and `mimeType` for the synthesized audio. Engines may rely on the defaults supplied by `VoiceEngineAudioFormat`, but should override them if their services return alternative container formats.

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

### Voice Provider Registry

SwiftHablaré exposes a **VoiceProviderRegistry** singleton that coordinates discovery, enablement, and configuration for every
`VoiceProvider` implementation shipped in the package or supplied by integrators.

Key concepts:

- **`VoiceProviderDescriptor`** – Lightweight metadata describing a provider (identifier, display name, default enablement,
  configuration requirements, and a factory closure that instantiates the provider on demand). Providers also supply a
  SwiftUI configuration panel builder used by the registry whenever the host needs to collect credentials or allow users to
  edit existing settings.
- **Automatic registration** – The registry seeds itself with the built-in `AppleVoiceProvider` (always enabled) and
  `ElevenLabsVoiceProvider` (user-enabled). External packages can either call
  `VoiceProviderRegistry.shared.register(_:)` during startup **or** subclass
  `VoiceProviderAutoRegistrar` to have their descriptors registered automatically
  when the module is loaded (Objective-C runtime platforms).
- **Enablement & configuration state** – The registry persists enablement flags in `UserDefaults` while leaving configuration
  storage to each provider. When `configuredProvider(for:)` is invoked, the registry instantiates the provider, verifies it is
  enabled, and then calls `isConfigured()` to ensure the provider’s own configuration is valid before returning it.
- **Configuration panels** – When a provider is enabled (or reconfigured later), the registry returns the provider’s SwiftUI
  configuration panel so the host app can surface the appropriate UI. Providers are responsible for saving their configuration
  and invoking the supplied completion closure to tell the registry whether setup succeeded.

Consumers should invoke `VoiceProviderRegistry.shared.availableProviders()` to render the list of choices in UI, and
`configuredProvider(for:)` to fetch a ready-to-use provider for generation.

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
- ✅ `SpeakableItem` protocol for protocol-oriented TTS with language code support (v2.3.0+)
- ✅ `SpeakableGroup` protocol for batch audio generation (v2.3.0)
- ✅ Voice provider integration (Apple TTS, ElevenLabs) with language filtering
- ✅ Provider registry and management
- ✅ Thread-safe audio generation
- ✅ Language-specific voice caching with SwiftData (v2.3.0+)
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
- **iOS/Catalyst**: Uses `AVSpeechSynthesizer.write()` for real audio generation (AIFC format)
- **macOS**: Uses `NSSpeechSynthesizer` for real audio generation (AIFF format)
- **iOS Simulator**: Limited audio support due to AVSpeechSynthesizer.write() constraints

**Features:**
- Always configured (no API key required)
- Fetches voices from platform-specific synthesizers
- Filters voices by language code (defaults to system language) (v2.3.0+)
- Supports explicit language specification for multi-language apps
- Estimates duration using text length heuristics
- Generates AIFF/AIFC format audio depending on platform
- Platform-agnostic through Engine Boundary Protocol (v3.5.1+)

**Test Coverage:**
- 22 unit tests (100% coverage)
- Integration tests run on all platforms (iOS, macOS, Catalyst)

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

The `SpeakableItem` protocol enables **protocol-oriented text-to-speech generation** where any type can become speakable by conforming to a simple protocol:

```swift
public protocol SpeakableItem {
    var voiceProvider: VoiceProvider { get }
    var voiceId: String { get }
    var textToSpeak: String { get }
    var languageCode: String { get } // v2.3.0+ - Defaults to system language
}
```

**Language Code Support (v2.3.0+):**
- The `languageCode` property has a default implementation that returns the system language
- Override to specify a custom language for multi-language applications
- Ensures voices are fetched and cached per language

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

### Language Code Usage (v2.3.0+)

The `languageCode` property allows you to specify which language's voices to use:

```swift
// Use default system language (automatic)
struct EnglishMessage: SpeakableItem {
    let voiceProvider: VoiceProvider
    let voiceId: String
    let textToSpeak: String
    // languageCode automatically uses system language
}

// Override for specific language
struct SpanishMessage: SpeakableItem {
    let voiceProvider: VoiceProvider
    let voiceId: String
    let textToSpeak: String

    var languageCode: String { "es" }
}

// Multi-language support
struct LocalizedMessage: SpeakableItem {
    let voiceProvider: VoiceProvider
    let voiceId: String
    let textToSpeak: String
    let locale: Locale

    var languageCode: String {
        locale.language.languageCode?.identifier ?? "en"
    }
}
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

## Markdown & Screenplay Support (v3.6.0)

### Overview

SwiftHablaré provides comprehensive support for markdown and screenplay elements through integration with SwiftCompartido's `GuionElement` model. This enables text-to-speech generation for parsed markdown files and Fountain screenplay documents.

**Key Concept**: SwiftCompartido normalizes markdown and Fountain files into a unified `GuionElement` model. SwiftHablaré adds voice generation capabilities for these elements through SpeakableItem conformance.

### Integration with SwiftCompartido

SwiftCompartido is a screenplay and document management library that:
- Parses markdown files using CommonMarkParser (swift-markdown)
- Parses Fountain screenplay files
- Converts both formats into `GuionElement` models
- Provides SwiftData persistence via `GuionElementModel`

SwiftHablaré consumes these models and makes them speakable.

### Supported Element Types

All GuionElement types can be converted to speech:

| ElementType | Description | Recommended Voice | Example |
|------------|-------------|-------------------|---------|
| `.action` | Narrative, paragraphs, lists, quotes | Narrator | "The sun rises over the mountains." |
| `.dialogue` | Character speech | Character | "I can't believe we made it." |
| `.character` | Character name | Narrator | "ALICE" |
| `.sceneHeading` | Location slugline | Narrator | "INT. COFFEE SHOP - DAY" |
| `.sectionHeading(level:)` | Markdown headings (# through ######) | Narrator | "## Act One" |
| `.parenthetical` | Stage directions | Narrator | "(whispering)" |
| `.transition` | Scene transitions | Narrator | "CUT TO:" |
| `.synopsis` | Scene summaries | Narrator | "Scene summary text" |
| `.lyrics` | Song lyrics | Character | "Song lyrics here" |
| `.comment` | Screenplay comments | Narrator | "/* Note: ... */" |
| `.pageBreak` | Page breaks | - | (visual only) |

### SpeakableItem Implementations

SwiftHablaré provides six GuionElement-based implementations in `Sources/SwiftHablare/Examples/GuionElementSpeakableExamples.swift`:

#### 1. GuionElementSpeakable

General adapter for any GuionElement:

```swift
let element = GuionElement(
    elementType: .action,
    elementText: "The sun rises over the mountains."
)

let speakable = GuionElementSpeakable(
    element: element,
    voiceProvider: provider,
    voiceId: voiceId,
    languageCode: "en"  // Optional, defaults to system language
)

let audioData = try await speakable.speak()
```

**Use Case**: Converting any screenplay or markdown element to speech.

#### 2. DialoguePairSpeakable

Specialized for character-dialogue pairs:

```swift
let character = GuionElement(elementType: .character, elementText: "ALICE")
let dialogue = GuionElement(elementType: .dialogue, elementText: "Hello, world!")

let speakable = DialoguePairSpeakable(
    character: character,
    dialogue: dialogue,
    voiceProvider: provider,
    voiceId: aliceVoiceId,
    includeCharacterName: false  // true: "ALICE: Hello, world!"
)
```

**Use Case**: Screenplay dialogue with character context.

#### 3. SectionHeadingSpeakable

Announces markdown/screenplay headings with level context:

```swift
let heading = GuionElement(
    elementType: .sectionHeading(level: 2),
    elementText: "Act One"
)

let speakable = SectionHeadingSpeakable(
    heading: heading,
    voiceProvider: provider,
    voiceId: narratorVoiceId,
    announceLevel: true  // Speaks: "Act: Act One"
)
```

**Heading Levels** (from Fountain.io spec):
- Level 1 (`#`): Title/Script name
- Level 2 (`##`): Act
- Level 3 (`###`): Sequence
- Level 4 (`####`): Scene group
- Level 5 (`#####`): Sub-scene
- Level 6 (`######`): Beat

**Use Case**: Document structure announcements.

#### 4. SceneSpeakable (SpeakableGroup)

Groups screenplay elements by scene:

```swift
let scene = SceneSpeakable(
    sceneHeading: sceneHeadingElement,
    elements: sceneElements,
    voiceMapping: { element in
        // Map element types to appropriate voices
        switch element.elementType {
        case .dialogue:
            return getCharacterVoice(element)
        default:
            return narratorVoiceId
        }
    },
    voiceProvider: provider
)

// Batch generate all scene audio
let list = SpeakableItemList(name: scene.groupName, items: scene.getGroupedElements())
let records = try await service.generateList(list, to: modelContext)
```

**Use Case**: Batch generation for complete scenes with voice mapping.

#### 5. ChapterSpeakable (SpeakableGroup)

Groups screenplay elements by chapter (Act level):

```swift
let chapter = ChapterSpeakable(
    chapterHeading: chapterHeadingElement,  // .sectionHeading(level: 2)
    elements: chapterElements,
    voiceMapping: { element in getVoiceId(for: element) },
    voiceProvider: provider
)

print(chapter.groupDescription)
// "25 elements (3 scenes, 12 dialogue lines)"
```

**Chapter Detection**: Chapters are defined by Level 2 section headings (`##`). SwiftCompartido uses `chapterIndex` for organizing elements.

**Use Case**: Batch generation for acts or major document sections.

#### 6. MarkdownDocumentSpeakable (SpeakableGroup)

Generates audio for complete markdown files:

```swift
// Parse markdown file
let markdownURL = URL(fileURLWithPath: "article.md")
let parsed = try GuionParsedElementCollection(file: markdownURL)

// Create speakable document
let document = MarkdownDocumentSpeakable(
    filename: "article.md",
    elements: parsed.elements,
    voiceProvider: provider,
    defaultVoiceId: narratorVoiceId
)

// Batch generate with progress
let list = SpeakableItemList(name: document.filename, items: document.getGroupedElements())
let records = try await service.generateList(list, to: modelContext)
```

**Markdown Element Mapping:**

| Markdown | → | GuionElement Type |
|----------|---|-------------------|
| `# Heading` | → | `.sectionHeading(level: 1)` |
| `## Heading` | → | `.sectionHeading(level: 2)` |
| Paragraphs | → | `.action` |
| Block quotes (`>`) | → | `.action` (with prefix) |
| Lists (`-`, `*`, `1.`) | → | `.action` (with prefix) |
| Code blocks | → | `.action` (indented) |
| `---` (thematic break) | → | `.pageBreak` |
| HTML blocks | → | `.comment` |

**Use Case**: Audio book generation from markdown articles/documents.

### Helper Extensions

SwiftHablaré adds useful extensions to `GuionElement`:

```swift
// Check if element has speakable content
if element.isSpeakable {
    // Element has non-empty, non-whitespace text
}

// Get recommended voice type
switch element.recommendedVoiceType {
case .character:
    // Dialogue, character names, lyrics
    // Use expressive character voices
case .narrator:
    // Action, scene headings, transitions
    // Use neutral narrator voice
}
```

**VoiceType Enum:**
```swift
public enum VoiceType {
    case character  // Dialogue, lyrics
    case narrator   // Action, headings, transitions
}
```

### Complete Workflow Example

Here's a complete example of parsing and generating audio for a markdown file:

```swift
import SwiftHablare
import SwiftCompartido
import SwiftData

@MainActor
func generateMarkdownAudio() async throws {
    // 1. Parse markdown file
    let markdownURL = URL(fileURLWithPath: "screenplay.md")
    let parsed = try GuionParsedElementCollection(file: markdownURL)

    // 2. Set up voice provider
    let provider = AppleVoiceProvider()
    let voices = try await provider.fetchVoices()
    let narratorVoice = voices.first { $0.name.contains("Samantha") }!
    let characterVoice = voices.first { $0.name.contains("Alex") }!

    // 3. Create speakable items with voice mapping
    let speakableItems: [any SpeakableItem] = parsed.elements.compactMap { element in
        guard element.isSpeakable else { return nil }

        let voiceId = element.recommendedVoiceType == .character
            ? characterVoice.id
            : narratorVoice.id

        return GuionElementSpeakable(
            element: element,
            voiceProvider: provider,
            voiceId: voiceId
        )
    }

    // 4. Generate audio with progress tracking
    let service = GenerationService(modelContext: modelContext)
    let list = SpeakableItemList(name: "Screenplay Audio", items: speakableItems)

    let records = try await service.generateList(list, to: modelContext)

    print("Generated \(records.count) audio files")
    print("Progress: \(list.progress * 100)%")
    print("Status: \(list.statusMessage)")
}
```

### Scene-Based Generation

For screenplays with explicit scene structure:

```swift
@MainActor
func generateSceneAudio() async throws {
    let parsed = try GuionParsedElementCollection(file: screenplayURL)
    var scenes: [SceneSpeakable] = []
    var currentScene: [GuionElement] = []
    var currentHeading: GuionElement?

    // Group elements by scene
    for element in parsed.elements {
        if case .sceneHeading = element.elementType {
            if let heading = currentHeading, !currentScene.isEmpty {
                scenes.append(SceneSpeakable(
                    sceneHeading: heading,
                    elements: currentScene,
                    voiceMapping: { getVoiceFor($0) },
                    voiceProvider: provider
                ))
            }
            currentHeading = element
            currentScene = []
        } else {
            currentScene.append(element)
        }
    }

    // Generate audio for each scene
    for scene in scenes {
        let list = SpeakableItemList(name: scene.groupName, items: scene.getGroupedElements())
        let records = try await service.generateList(list, to: modelContext)
        print("Generated \(records.count) audio files for \(scene.groupName)")
    }
}
```

### Character Voice Mapping

For screenplays with multiple characters, implement custom voice mapping:

```swift
class CharacterVoiceMapper {
    private var voiceMap: [String: String] = [:]
    private let availableVoices: [Voice]

    init(voices: [Voice]) {
        self.availableVoices = voices
    }

    func voiceId(for element: GuionElement) -> String {
        switch element.elementType {
        case .dialogue:
            // Get character name from preceding element
            return getCharacterVoiceId()
        case .character:
            // Cache mapping for this character
            let characterName = element.elementText
            if voiceMap[characterName] == nil {
                voiceMap[characterName] = assignVoice(for: characterName)
            }
            return voiceMap[characterName]!
        default:
            // Use narrator voice for everything else
            return narratorVoiceId
        }
    }

    private func assignVoice(for characterName: String) -> String {
        // Your voice assignment logic
        // Could be based on:
        // - Character metadata (age, gender)
        // - Random assignment
        // - User preferences
        // - Voice quality matching
        return availableVoices.randomElement()!.id
    }
}
```

### Test Coverage

Comprehensive test coverage in `Tests/SwiftHablareTests/GuionElementSpeakableTests.swift`:

- **26 tests** covering all GuionElement-based implementations
- **100% test coverage** on all implementations
- Tests cover:
  - GuionElementSpeakable (action, dialogue, scene headings, section headings)
  - DialoguePairSpeakable (with/without character names)
  - SectionHeadingSpeakable (all 6 levels, with/without announcement)
  - SceneSpeakable (basic scenes, empty scenes, voice mapping)
  - ChapterSpeakable (with/without heading, multiple scenes, descriptions)
  - MarkdownDocumentSpeakable (basic documents, empty documents)
  - Helper extensions (isSpeakable, recommendedVoiceType)
  - Audio generation integration
  - Batch generation
  - Duration estimation

### Thread Safety

All GuionElement-based speakable items are thread-safe:
- Use `GenerationService` actor for background audio generation
- SwiftData persistence happens on `@MainActor`
- Safe to use with structured concurrency (TaskGroup, async let)
- No race conditions in element traversal or voice mapping

### Performance Considerations

**Batch Generation:**
- Use `SpeakableItemList` for progress tracking
- Set appropriate `saveInterval` for large documents
- Consider cancellation for long-running generations

**Voice Caching:**
- Voices are automatically cached per language
- Cache persists across app launches
- Reduces startup time for large screenplays

**Memory Management:**
- GuionElement is a lightweight value type
- Audio data stored in TypedDataStorage (SwiftData)
- Large files stored externally via `fileReference`

### SwiftCompartido Integration

SwiftHablaré works seamlessly with SwiftCompartido's persistence layer:

**GuionElementModel** (SwiftData):
```swift
@Model
public final class GuionElementModel {
    public var elementType: ElementType
    public var elementText: String
    public var chapterIndex: Int
    public var orderIndex: Int

    @Relationship(inverse: \GuionDocumentModel.elements)
    public var document: GuionDocumentModel?

    @Relationship(deleteRule: .cascade)
    public var generatedContent: [TypedDataStorage]?  // Audio files
}
```

**Linking Audio to Elements:**
```swift
// Generate audio for element
let speakable = GuionElementSpeakable(element: element, provider: provider, voiceId: voiceId)
let result = try await service.generate(
    text: speakable.textToSpeak,
    providerId: "apple",
    voiceId: voiceId
)

// Create TypedDataStorage record
let storage = result.toTypedDataStorage()

// Link to GuionElementModel
storage.owningElement = elementModel
elementModel.generatedContent = [storage]

// Save to SwiftData
modelContext.insert(storage)
try modelContext.save()
```

**Benefits:**
- Automatic cleanup when elements deleted
- Query elements with/without audio
- Track generation metadata per element
- Support for multiple audio versions per element

### Resources

**Example Files:**
- `Sources/SwiftHablare/Examples/GuionElementSpeakableExamples.swift` - All 6 implementations
- `Tests/SwiftHablareTests/GuionElementSpeakableTests.swift` - Comprehensive tests

**Related Documentation:**
- [SwiftCompartido README](https://github.com/intrusive-memory/SwiftCompartido) - Screenplay parsing
- [CommonMarkParser Documentation](https://github.com/intrusive-memory/SwiftCompartido/blob/main/Sources/SwiftCompartido/Serialization/CommonMarkParser.swift) - Markdown parsing
- [Fountain.io Specification](https://fountain.io) - Screenplay format standard

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

**Language-Specific Caching (v2.3.0+):**

Voices are cached per provider AND language code to prevent cache collisions. This ensures that fetching Spanish voices doesn't return cached English voices.

**SwiftData Model:**
```swift
@Model
public final class VoiceCacheModel {
    @Attribute(.unique) public var id: String  // Format: "providerId:languageCode:voiceId"
    public var providerId: String
    public var cacheLanguageCode: String  // Language code used when fetching
    public var voiceId: String
    public var voiceName: String
    public var language: String?  // Voice's actual language (may be more specific)
    public var locality: String?
    public var gender: String?
    public var cachedAt: Date
}
```

**Usage:**
```swift
// Voices are automatically cached when fetched, keyed by language
let enVoices = try await service.fetchVoices(from: "apple", using: context, languageCode: "en")
let esVoices = try await service.fetchVoices(from: "apple", using: context, languageCode: "es")
// Both cached independently - no collision

// Check for language-specific cache
let hasEnCache = await service.hasValidCache(for: "apple", languageCode: "en", using: context)

// Clear specific language or all languages
try await service.clearVoiceCache(for: "apple", languageCode: "en", using: context)
try await service.clearVoiceCache(for: "apple", using: context) // Clears all languages
```

## Development Workflow

**⚠️ CRITICAL: See [`.claude/WORKFLOW.md`](.claude/WORKFLOW.md) for complete development workflow.**

This project follows a **strict branch-based workflow**:

### Quick Reference

- **Development branch**: `development` (all work happens here)
- **Main branch**: `main` (protected, PR-only)
- **Workflow**: `development` → PR → CI passes → Merge → Tag → Release
- **NEVER** commit directly to `main`
- **NEVER** delete the `development` branch

**See [`.claude/WORKFLOW.md`](.claude/WORKFLOW.md) for:**
- Complete branch strategy
- Commit message conventions
- PR creation templates
- Tagging and release process
- Version numbering (semver)
- Emergency hotfix procedures

### Branch Protection Configuration

**⚠️ IMPORTANT: When tests are changed or renamed, branch protections must be evaluated.**

The `main` branch has required status checks that must pass before PRs can be merged. These checks are configured in GitHub repository settings and must match the actual CI workflow job names.

**Current Required Checks (as of v3.11.0):**
- `Code Quality Checks` - Runs first (build, linting, code quality)
- `Fast Tests (iOS)` - Unit tests on iOS Simulator
- `Fast Tests (macOS)` - Unit tests on macOS

**When to Update Branch Protections:**
- ✅ When CI workflow job names change
- ✅ When test jobs are added or removed
- ✅ When platforms are added or removed (iOS, macOS, Catalyst)
- ✅ When test structure is reorganized

**How to Update Branch Protections:**

View current protections:
```bash
gh api repos/intrusive-memory/SwiftHablare/branches/main/protection/required_status_checks
```

Update required checks:
```bash
gh api --method PATCH repos/intrusive-memory/SwiftHablare/branches/main/protection/required_status_checks \
  -H "Accept: application/vnd.github.v3+json" \
  --input - <<'EOF'
{
  "strict": true,
  "contexts": [
    "Code Quality Checks",
    "Fast Tests (iOS)",
    "Fast Tests (macOS)"
  ]
}
EOF
```

**Best Practices:**
- Keep branch protection checks minimal but essential
- Align check names exactly with CI workflow job names
- Document protection changes in PR descriptions
- Test protection changes by creating a test PR

### Development Best Practices

**For New Features:**
1. Read documentation (this file, README.md, test files)
2. Plan with TodoWrite tool for complex tasks
3. Write tests first (TDD approach, aim for 95%+ coverage)
4. Implement features following existing patterns
5. Verify coverage: `swift test --enable-code-coverage`

**For Bug Fixes:**
1. Write failing test to reproduce the bug
2. Fix the bug
3. Verify test passes and existing tests still work
4. Document changes as needed

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

SwiftHablaré supports multiple Apple platforms. Choose guards deliberately:

```swift
#if os(iOS)
// UIKit-specific behavior (including Mac Catalyst)
#elseif os(macOS)
// AppKit-specific behavior
#endif
```

Use `#if targetEnvironment(macCatalyst)` to distinguish Catalyst nuances when the UIKit guard is true. Simulator-specific fallbacks should remain behind `#if targetEnvironment(simulator)` checks.

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
- ✅ Tests run on iOS Simulator (primary CI target)
- ✅ macOS builds are supported; run focused smoke tests on macOS 14+ before shipping platform-specific changes
- ✅ Mac Catalyst support (built for Catalyst, tested on simulator)

### Unit Tests

**Coverage Targets:**
- Voice Providers: 95%+
- GenerationService: 95%+
- KeychainManager: 95%+
- Models: 100%

**Current Status:**
- 259 total tests passing
- 96%+ average coverage
- 0 test failures
- Swift 6 strict concurrency compliance with strict mode enabled

### Integration Tests

**Platform Support:** Integration tests run on all supported platforms (iOS, macOS, Catalyst).

**Apple Voice Provider:**
```swift
func testEndToEndSpeechGeneration() async throws {
    #if targetEnvironment(simulator)
    // iOS Simulator may have limited TTS capabilities
    throw XCTSkip("Apple TTS integration test skipped on simulator")
    #endif

    // Test on physical devices and macOS
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

**Run all tests (recommended - uses swift test):**
```bash
swift test --enable-code-coverage
```

**Run tests on specific platform:**
```bash
# iOS Simulator
xcodebuild test \
  -scheme SwiftHablare \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'

# macOS
xcodebuild test \
  -scheme SwiftHablare \
  -destination 'platform=macOS'
```

**Run only unit tests (fast):**
```bash
xcodebuild test \
  -scheme SwiftHablare \
  -destination 'platform=macOS' \
  -skip-testing:SwiftHablareTests/AppleVoiceProviderIntegrationTests \
  -skip-testing:SwiftHablareTests/ElevenLabsVoiceProviderIntegrationTests
```

**Run only integration tests:**
```bash
xcodebuild test \
  -scheme SwiftHablare \
  -destination 'platform=macOS' \
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

**With System Language (Default):**
```swift
let provider = AppleVoiceProvider()
let voices = try await provider.fetchVoices()  // Uses system language
let audioData = try await provider.generateAudio(
    text: "Hello, world!",
    voiceId: voices.first!.id
)
// Use audioData in your app
```

**With Specific Language (v2.3.0+):**
```swift
let provider = AppleVoiceProvider()

// Fetch Spanish voices
let spanishVoices = try await provider.fetchVoices(languageCode: "es")

// Generate Spanish audio
let audioData = try await provider.generateAudio(
    text: "Hola, mundo!",
    voiceId: spanishVoices.first!.id,
    languageCode: "es"
)

// Or use GenerationService for better management
let service = GenerationService()
let result = try await service.generate(
    text: "Hola, mundo!",
    providerId: "apple",
    voiceId: spanishVoices.first!.id,
    languageCode: "es"
)
```

### Work with Provider Registry

```swift
// Create service with provider registry
let service = GenerationService(modelContext: modelContext)

// Get all available providers
let providers = await service.registeredProviders()

// Fetch voices from a specific provider (system language)
let appleVoices = try await service.fetchVoices(from: "apple")

// Fetch voices with specific language (v2.3.0+)
let spanishVoices = try await service.fetchVoices(from: "apple", languageCode: "es")

// Fetch voices from all providers
let allVoices = try await service.fetchAllVoices()
for (providerId, voices) in allVoices {
    print("\(providerId): \(voices.count) voices")
}

// Fetch voices from all providers with specific language (v2.3.0+)
let allSpanishVoices = try await service.fetchAllVoices(languageCode: "es")

// Register a custom provider
let customProvider = MyCustomVoiceProvider()
await service.registerProvider(customProvider)
```

### Cache Voices in SwiftData

**Voice caching is automatic** when using `GenerationService.fetchVoices()`. The service automatically caches voices with language-specific keys to prevent cache collisions.

**Automatic Caching:**
```swift
@MainActor
func cacheVoices() async throws {
    let service = GenerationService()

    // Voices are automatically cached with language code
    let enVoices = try await service.fetchVoices(from: "apple", using: modelContext, languageCode: "en")
    let esVoices = try await service.fetchVoices(from: "apple", using: modelContext, languageCode: "es")

    // Cache is automatically managed, no manual insertion needed
}
```

### Multi-Language Voice Generation (v2.3.0+)

**Use Case**: Applications that need to support multiple languages.

```swift
struct MultiLanguageApp {
    let service = GenerationService()

    @MainActor
    func generateMultiLanguageAudio() async throws {
        // Fetch voices for different languages
        let englishVoices = try await service.fetchVoices(
            from: "apple",
            using: modelContext,
            languageCode: "en"
        )

        let spanishVoices = try await service.fetchVoices(
            from: "apple",
            using: modelContext,
            languageCode: "es"
        )

        let frenchVoices = try await service.fetchVoices(
            from: "apple",
            using: modelContext,
            languageCode: "fr"
        )

        // All three language caches are independent
        // No collision between languages

        // Generate audio in different languages
        let enResult = try await service.generate(
            text: "Hello, world!",
            providerId: "apple",
            voiceId: englishVoices.first!.id,
            languageCode: "en"
        )

        let esResult = try await service.generate(
            text: "¡Hola, mundo!",
            providerId: "apple",
            voiceId: spanishVoices.first!.id,
            languageCode: "es"
        )

        let frResult = try await service.generate(
            text: "Bonjour, le monde!",
            providerId: "apple",
            voiceId: frenchVoices.first!.id,
            languageCode: "fr"
        )
    }
}

// Using SpeakableItem with language codes
struct LocalizedMessage: SpeakableItem {
    let voiceProvider: VoiceProvider
    let voiceId: String
    let textToSpeak: String
    let locale: Locale

    var languageCode: String {
        locale.language.languageCode?.identifier ?? "en"
    }
}

// Usage
let messages = [
    LocalizedMessage(
        voiceProvider: provider,
        voiceId: enVoiceId,
        textToSpeak: "Hello",
        locale: Locale(identifier: "en_US")
    ),
    LocalizedMessage(
        voiceProvider: provider,
        voiceId: esVoiceId,
        textToSpeak: "Hola",
        locale: Locale(identifier: "es_ES")
    )
]

// Each message uses its own language code
for message in messages {
    let audio = try await message.speak()  // Uses message.languageCode
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
- Takes text, provider ID, voice ID, and optional language code as input
- Generates audio using the specified voice provider
- Returns audio data and metadata for the consuming application
- Integrates with TypedDataStorage for SwiftData persistence
- Supports multi-language voice generation with language-specific caching (v2.3.0+)

**Out of Scope**:
- ❌ Audio playback (apps handle playback)
- ❌ Audio file I/O (apps handle file storage)
- ❌ Screenplay processing or domain-specific models
- ❌ Background task management
- ❌ Character-to-voice mapping
- ❌ Complex UI workflows

**In Scope**:
- ✅ Voice provider integration (Apple TTS, ElevenLabs) with language filtering
- ✅ Voice provider registry and management
- ✅ Language-specific voice fetching and caching (VoiceCacheModel) (v2.3.0+)
- ✅ Multi-language support with automatic system language detection (v2.3.0+)
- ✅ Thread-safe audio generation (actor-based)
- ✅ API key management (Keychain)
- ✅ TypedDataStorage integration for generated audio
- ✅ SpeakableItem protocol for protocol-oriented TTS with language codes (v2.3.0+)
- ✅ SpeakableGroup protocol for batch audio generation (v2.3.0)
- ✅ SpeakableItemList for batch generation with progress
- ✅ Platform compatibility (iOS 26+, macOS 26+, Catalyst 26+)
- ✅ Simple UI pickers (provider & voice selection)
- ✅ Audio generation buttons (individual & batch) (v2.3.0)

## Migration from 3.x to 4.0

SwiftHablaré 4.0.0 is a **performance-focused major release** with breaking changes for custom VoiceProvider implementations.

### Breaking Changes Summary

1. **VoiceProvider protocol now requires `mimeType` property**
2. **VoiceProviderType enum removed** (use string provider IDs)
3. **VoiceProviderInfo struct removed** (never used)

### Detailed Migration Instructions

#### 1. Custom VoiceProvider Implementations

**What Changed:**
The `VoiceProvider` protocol now requires a `mimeType` property to eliminate duplicate MIME type logic across the codebase.

**Before (3.x):**
```swift
public final class MyVoiceProvider: VoiceProvider {
    public let providerId = "my-provider"
    public let displayName = "My Provider"
    public let requiresAPIKey = true

    public func isConfigured() -> Bool { ... }
    public func fetchVoices(languageCode: String) async throws -> [Voice] { ... }
    public func generateAudio(text: String, voiceId: String, languageCode: String) async throws -> Data { ... }
    // ... other methods
}
```

**After (4.0):**
```swift
public final class MyVoiceProvider: VoiceProvider {
    public let providerId = "my-provider"
    public let displayName = "My Provider"
    public let requiresAPIKey = true
    public let mimeType = "audio/mpeg"  // ← ADD THIS

    public func isConfigured() -> Bool { ... }
    public func fetchVoices(languageCode: String) async throws -> [Voice] { ... }
    public func generateAudio(text: String, voiceId: String, languageCode: String) async throws -> Data { ... }
    // ... other methods
}
```

**MIME Type Reference:**
- **MP3**: `"audio/mpeg"`
- **AIFF**: `"audio/x-aiff"`
- **WAV**: `"audio/wav"`
- **OGG**: `"audio/ogg"`
- **M4A**: `"audio/mp4"`

**Migration Steps:**
1. Add `public let mimeType = "..."` to your VoiceProvider implementation
2. Choose the appropriate MIME type based on your audio output format
3. Update any tests that reference your provider
4. Build and verify compilation succeeds

#### 2. VoiceProviderType Enum Removed

**What Changed:**
The deprecated `VoiceProviderType` enum has been removed. Use provider ID strings directly.

**Before (3.x):**
```swift
// DEPRECATED - do not use
let providerType = VoiceProviderType.apple
switch providerType {
case .apple:
    // ...
case .elevenlabs:
    // ...
}
```

**After (4.0):**
```swift
// Use provider ID strings directly
let providerId = "apple"
switch providerId {
case "apple":
    // ...
case "elevenlabs":
    // ...
default:
    // ...
}
```

**Migration Steps:**
1. Find all references to `VoiceProviderType` in your codebase
2. Replace with string-based provider IDs
3. Update switch statements to use strings instead of enum cases
4. Use `provider.providerId` for dynamic provider identification

#### 3. VoiceProviderInfo Struct Removed

**What Changed:**
The unused `VoiceProviderInfo` struct has been removed.

**Migration Steps:**
No action required - this struct was never part of the public API and was not used anywhere in the codebase.

### Performance Improvements (Automatic)

These improvements are automatic and require no code changes:

**Voice Loading:**
- ⚡ **15-25% faster** - Batch cache invalidation
- ⚡ **10-20x faster cache clearing** - Single-transaction deletion

**UI Performance:**
- ⚡ **50% faster GenerateAudioButton** - Eliminated redundant FetchDescriptor creation

**Code Quality:**
- ⚡ **250+ lines of dead code removed** - Better maintainability
- ⚡ **Swift 6 compliance** - Fixed unsafe UserDefaults access in VoiceProviderRegistry

### New Utilities

#### LanguageCodeResolver

A new centralized utility for language code resolution:

```swift
import SwiftHablare

// Get system language code
let systemLang = LanguageCodeResolver.systemLanguageCode
// Returns: "en", "es", "fr", etc.

// Resolve with fallback to system language
let resolved = LanguageCodeResolver.resolve(nil)
// Returns: system language code

// Explicit language code
let explicit = LanguageCodeResolver.resolve("es")
// Returns: "es"
```

**Use Cases:**
- Consistent language code handling across your app
- Automatic fallback to system language when needed
- Centralized language logic instead of scattered implementations

### Testing Your Migration

After updating your code:

1. **Clean build**:
   ```bash
   swift package clean
   swift build
   ```

2. **Run tests**:
   ```bash
   swift test --enable-code-coverage
   ```

3. **Verify MIME types**:
   ```swift
   let provider = MyVoiceProvider()
   print(provider.mimeType)  // Should print your expected MIME type
   ```

4. **Test voice generation**:
   ```swift
   let result = try await service.generate(
       text: "Test audio",
       providerId: provider.providerId,
       voiceId: voiceId
   )
   let storage = result.toTypedDataStorage()
   print(storage.mimeType)  // Should match provider.mimeType
   ```

### Common Migration Issues

**Issue 1: Missing `mimeType` Property**
```
Error: Type 'MyVoiceProvider' does not conform to protocol 'VoiceProvider'
```
**Solution:** Add `public let mimeType = "audio/mpeg"` to your provider.

**Issue 2: VoiceProviderType Not Found**
```
Error: Cannot find 'VoiceProviderType' in scope
```
**Solution:** Replace enum references with string provider IDs.

**Issue 3: Wrong MIME Type**
```
Warning: Audio file has incorrect MIME type
```
**Solution:** Verify `mimeType` matches your actual audio format (e.g., MP3 = "audio/mpeg").

### Migration Checklist

- [ ] Updated all custom VoiceProvider implementations with `mimeType` property
- [ ] Replaced all `VoiceProviderType` enum references with strings
- [ ] Verified MIME types match actual audio formats
- [ ] Updated tests to verify `mimeType` is set correctly
- [ ] Clean build succeeded without warnings
- [ ] All tests pass
- [ ] Verified audio generation produces correct MIME type metadata

### Further Resources

- **Full Changelog**: See `CHANGELOG.md` for complete details on all changes
- **Performance Audit**: See `Docs/PERFORMANCE_AUDIT_V4.md` for detailed performance analysis
- **README Migration Guide**: See `README.md` section "Migration from 3.x to 4.0"

---

**For Questions or Contributions**:
- GitHub Issues: https://github.com/intrusive-memory/SwiftHablare/issues
- GitHub Discussions: https://github.com/intrusive-memory/SwiftHablare/discussions
- add to memory: SwiftHablaré targets iOS 26+, macOS 26+, and MacCatalyst 26+. Ensure new code paths consider all supported Apple platforms.
