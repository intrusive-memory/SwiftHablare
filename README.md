# SwiftHablare

**Simple voice generation library** - Convert text into spoken audio using Apple TTS or ElevenLabs.

## Overview

SwiftHablare is a focused Swift library that takes text and a voice ID, then generates audio. Simple API: `text + voiceId → audio`.

**Core Features:**
- **Two voice providers**: Apple Text-to-Speech (built-in) and ElevenLabs (API-based)
- **Provider registry**: Centralized provider management with configuration panels (v3.5.1)
- **Voice caching**: Reduces API calls by caching available voices in SwiftData
- **Thread-safe generation**: Uses Swift actors for safe concurrency
- **Cross-platform**: iOS 26+ and Mac Catalyst 15.0+ (UIKit-based, no macOS)
- **Optional UI components**: SwiftUI pickers and generation buttons (v2.3.0)
- **Batch generation**: SpeakableGroup protocol for generating groups of items (v2.3.0)
- **No character mapping**: Voice selection is handled by consuming applications

**Out of Scope:**
- ❌ Character-to-voice mapping (consuming apps handle this)
- ❌ Screenplay analysis or structure parsing (consuming apps handle this)
- ❌ Automatic voice assignment (consuming apps handle this)

SwiftHablare focuses on doing one thing well: generating high-quality audio from text with a specified voice.

## Generation Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                      Your Application                            │
│                                                                   │
│  1. Select voice provider (Apple or ElevenLabs)                 │
│  2. Choose voice ID from provider's voice list                  │
│  3. Provide text to speak                                       │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             │ text + voiceId
                             ▼
                 ┌───────────────────────┐
                 │  GenerationService    │
                 │  (Actor - Thread Safe)│
                 └───────────┬───────────┘
                             │
                             │ Routes to provider
                             │
            ┌────────────────┴────────────────┐
            │                                 │
            ▼                                 ▼
  ┌─────────────────────┐         ┌─────────────────────┐
  │ AppleVoiceProvider  │         │ElevenLabsProvider   │
  │                     │         │                     │
  │ • Built-in TTS      │         │ • Neural voices     │
  │ • No API key needed │         │ • API key required  │
  │ • AIFF output       │         │ • MP3 output        │
  │ • iOS 26+ & Catalyst│         │ • Production quality│
  │ • AVSpeechSynth     │         │ • 11+ voices        │
  │ • UIKit-only        │         │ • Emotional range   │
  │                     │         │                     │
  └──────────┬──────────┘         └──────────┬──────────┘
             │                               │
             │ Audio Data (AIFF)             │ Audio Data (MP3)
             │                               │
             └───────────────┬───────────────┘
                             │
                             ▼
                 ┌───────────────────────┐
                 │   GenerationResult    │
                 │   (Sendable)          │
                 │                       │
                 │ • audioData: Data     │
                 │ • voiceId: String     │
                 │ • voiceName: String   │
                 │ • providerId: String  │
                 │ • mimeType: String    │
                 │ • requestId: UUID     │
                 └───────────┬───────────┘
                             │
                             │ Return to main thread
                             ▼
                 ┌───────────────────────┐
                 │    Main Thread        │
                 │    (@MainActor)       │
                 └───────────┬───────────┘
                             │
                             │ result.toTypedDataStorage()
                             ▼
                 ┌───────────────────────┐
                 │   TypedDataStorage    │
                 │   (SwiftData Model)   │
                 │                       │
                 │ • id: UUID            │
                 │ • providerId          │
                 │ • mimeType            │
                 │ • binaryValue: Data   │
                 │ • prompt: String      │
                 │ • voiceID: String     │
                 │ • voiceName: String   │
                 └───────────┬───────────┘
                             │
                             │ modelContext.insert()
                             ▼
                 ┌───────────────────────┐
                 │     SwiftData         │
                 │     Database          │
                 │                       │
                 │ • Persisted audio     │
                 │ • Queryable           │
                 │ • Retrievable         │
                 └───────────┬───────────┘
                             │
                             │ Fetch & use
                             ▼
                 ┌───────────────────────┐
                 │   Your Application    │
                 │                       │
                 │ • Play audio          │
                 │ • Export audio        │
                 │ • Link to content     │
                 │ • Display metadata    │
                 └───────────────────────┘
```

**Key Points:**
- **Provider Selection**: Your app chooses Apple or ElevenLabs based on needs
- **Voice Selection**: Your app selects specific voice ID from provider's available voices
- **Thread Safety**: Generation happens on background thread via actor
- **Consistent API**: Same flow regardless of provider choice
- **SwiftData Integration**: `toTypedDataStorage()` converts result to SwiftData model
- **Persistence**: Audio and metadata saved to database for later retrieval

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/intrusive-memory/SwiftHablare.git", from: "3.0.0"),
    .package(url: "https://github.com/intrusive-memory/SwiftCompartido.git", from: "2.1.0")
]
```

## Requirements

- Swift 6.0+
- iOS 26.0+ / Mac Catalyst 15.0+
- SwiftCompartido 2.1.0+
- UIKit-based (no macOS support)

**Platform Support**: SwiftHablare is a UIKit-based library supporting iOS 26+ and Mac Catalyst 15+. Native macOS is not supported.

## Quick Start

```swift
import SwiftHablare
import SwiftCompartido
import SwiftData

// 1. Get a screenplay element
let descriptor = FetchDescriptor<GuionElementModel>()
let elements = try modelContext.fetch(descriptor)
let element = elements.first!

// 2. Create voice provider
let provider = ElevenLabsVoiceProvider()

// 3. Create generation service
let service = GenerationService(voiceProvider: provider)

// 4. Generate audio (happens on background thread)
let result = try await service.generate(
    forElement: element,
    voiceId: "21m00Tcm4TlvDq8ikWAM",
    voiceName: "Rachel"
)

// 5. Save to SwiftData (on main thread)
await MainActor.run {
    let audioRecord = result.toTypedDataStorage()

    // Link to element
    if element.generatedContent == nil {
        element.generatedContent = []
    }
    element.generatedContent?.append(audioRecord)

    // Save
    modelContext.insert(audioRecord)
    try? modelContext.save()
}
```

## Architecture

### Core Components

```
SwiftHablare/
├── VoiceProvider.swift          # Protocol for voice providers
├── Providers/
│   ├── AppleVoiceProvider.swift # Built-in Apple TTS
│   └── ElevenLabsVoiceProvider.swift # ElevenLabs API
├── Generation/
│   └── GenerationService.swift  # Actor-based generation coordinator
├── SwiftDataModels/
│   └── VoiceCacheModel.swift    # Cache for provider voices
├── Models/
│   └── Voice.swift              # Voice model (Sendable DTO)
└── Security/
    └── KeychainManager.swift    # API key storage
```

### Generation Flow

```
┌─────────────────┐
│ VoiceProvider   │  1. Fetch available voices
│ (init)          │     ↓
└─────────────────┘  2. Cache in VoiceCacheModel
        ↓
┌─────────────────┐
│ GenerationService│  3. Takes GuionElementModel
│ (actor)         │     ↓
└─────────────────┘  4. Generates audio (background)
        ↓
┌─────────────────┐
│ GenerationResult │  5. Sendable result
│ (Sendable)      │     ↓
└─────────────────┘  6. Main thread receives
        ↓
┌─────────────────┐
│ TypedDataStorage │  7. Save to SwiftCompartido
│ (SwiftData)     │     ↓
└─────────────────┘  8. Link to GuionElementModel
```

## Voice Providers

### Apple Voice Provider

Built-in text-to-speech for iOS 26+ and Mac Catalyst. No API key required.

```swift
let provider = AppleVoiceProvider()

// Check configuration
if provider.isConfigured() {
    // Fetch available voices
    let voices = try await provider.fetchVoices()

    // Generate audio
    let audioData = try await provider.generateAudio(
        text: "Hello, world!",
        voiceId: "com.apple.voice.compact.en-US.Samantha"
    )
}
```

**Features:**
- Built-in system voices with real audio output
- Automatic language filtering
- Quality detection (standard/enhanced/premium)
- Gender detection based on voice name

**Implementation:**
- iOS 26+ & Catalyst: Uses AVSpeechSynthesizer.write()
- Consistent AIFF format output across all platforms
- UIKit-based, no macOS support

**All platforms generate AIFF format audio** for consistency across iOS 26+ and Catalyst applications.

### ElevenLabs Voice Provider

High-quality neural text-to-speech via ElevenLabs API.

```swift
let provider = ElevenLabsVoiceProvider()

// Set API key (stored in keychain)
try KeychainManager.shared.saveAPIKey(apiKey, for: "elevenlabs-api-key")

// Check configuration
if provider.isConfigured() {
    // Fetch voices filtered by system language
    let voices = try await provider.fetchVoices()

    // Generate audio
    let audioData = try await provider.generateAudio(
        text: "Hello, world!",
        voiceId: "21m00Tcm4TlvDq8ikWAM"
    )
}
```

**Features:**
- Production-quality neural voices
- Language and gender metadata
- Automatic error handling
- Supports all ElevenLabs voice settings

**API Key:**
Get your API key at [elevenlabs.io](https://elevenlabs.io)

### Voice Provider Registry (v3.5.1)

SwiftHablaré includes a centralized `VoiceProviderRegistry` for managing voice providers with enablement and configuration state.

```swift
import SwiftHablare

// Access the shared registry
let registry = VoiceProviderRegistry.shared

// Get all available providers with status
let providers = await registry.availableProviders()
for provider in providers {
    print("\(provider.displayName): enabled=\(provider.isEnabled), configured=\(provider.isConfigured)")
}

// Enable/disable providers
await registry.setEnabled(true, for: "elevenlabs")

// Get a configured provider instance
if let provider = try? await registry.configuredProvider(for: "apple") {
    let voices = try await provider.fetchVoices()
}

// Register custom providers
let descriptor = VoiceProviderDescriptor(
    id: "my-provider",
    displayName: "My Provider",
    isEnabledByDefault: false,
    requiresConfiguration: true,
    makeProvider: { MyVoiceProvider() }
)
await registry.register(descriptor)
```

**Key Features:**
- **Automatic Registration**: Built-in providers (Apple, ElevenLabs) auto-register on startup
- **Enablement State**: User-controlled on/off state persisted in UserDefaults
- **Configuration Validation**: Ensures providers are properly configured before use
- **SwiftUI Configuration Panels**: Each provider supplies a configuration view for credentials
- **External Provider Support**: Third-party packages can register custom providers

**For Custom Providers:**

```swift
// Option 1: Direct registration
class MyVoiceProvider: VoiceProvider {
    // ... implementation
}

let service = GenerationService()
await service.registerProvider(MyVoiceProvider())

// Option 2: Using VoiceProviderAutoRegistrar (requires manual registration)
class MyProviderRegistrar: VoiceProviderAutoRegistrar {
    override class var descriptors: [VoiceProviderDescriptor] {
        [
            VoiceProviderDescriptor(
                id: "my-provider",
                displayName: "My Provider",
                isEnabledByDefault: false,
                requiresConfiguration: true,
                makeProvider: { MyVoiceProvider() }
            )
        ]
    }
}

// In your app initialization:
await MyProviderRegistrar.registerProviders(into: .shared)
```

**Note**: Swift does not support Objective-C's `+load` method for automatic registration. External packages must call `registerProviders(into:)` during app initialization to make their providers available.

## UI Components (v2.3.0)

SwiftHablaré provides optional SwiftUI components for voice selection and audio generation:

### ProviderPickerView & VoicePickerView

Simple pickers for selecting voice providers and voices:

```swift
import SwiftUI
import SwiftHablare

struct VoiceSelectionView: View {
    let service = GenerationService(modelContext: modelContext)

    @State private var selectedProviderId: String?
    @State private var selectedVoiceId: String?

    var body: some View {
        Form {
            ProviderPickerView(
                service: service,
                selection: $selectedProviderId
            )

            if let providerId = selectedProviderId {
                VoicePickerView(
                    service: service,
                    providerId: providerId,
                    selection: $selectedVoiceId
                )
            }
        }
    }
}
```

### GenerateAudioButton

Individual element audio generation with progress tracking:

```swift
import SwiftUI
import SwiftHablare

struct ElementRow: View {
    let item: any SpeakableItem
    let service: GenerationService
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        HStack {
            Text(item.textToSpeak)
            Spacer()

            GenerateAudioButton(
                item: item,
                service: service,
                modelContext: modelContext,
                onPlay: { record in
                    // Handle play action
                    print("Play audio: \(record.id)")
                }
            )
        }
    }
}
```

**Features:**
- Automatically checks for existing audio
- Shows "Generate" or "Play" based on audio availability
- Progress bar and cancellation support
- Race condition safe

### GenerateGroupButton & SpeakableGroup Protocol

Batch generation for groups of speakable items:

```swift
import SwiftUI
import SwiftHablare

// Define a speakable group
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
struct ChapterView: View {
    let chapter: Chapter
    let service: GenerationService
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack {
            Text(chapter.groupName)
                .font(.headline)

            GenerateGroupButton(
                group: chapter,
                service: service,
                modelContext: modelContext,
                onComplete: { records in
                    print("Generated \(records.count) audio files")
                }
            )
        }
    }
}
```

**Features:**
- Shows "Generate All (N items)" or "Regenerate All (N items)"
- Progress tracking as "X/Y items (Z%)"
- Skips items with existing audio by default
- Cancellation support with partial results
- Recursive group expansion

**Example Groups:**
- Chapter (books with dialogue)
- Scene (theatrical scripts)
- MessagePlaylist (notifications with priority)
- ArticleSections (long-form content)
- ShoppingList (enumerated tasks)

See `Sources/SwiftHablare/Examples/SpeakableGroupExamples.swift` for complete implementations.

## Voice Caching

SwiftHablare automatically caches voices in SwiftData to reduce API calls:

```swift
// VoiceCacheModel properties:
// - providerId: "apple" or "elevenlabs"
// - voiceId: Provider's voice identifier
// - voiceName: Display name
// - language, locality, gender: Metadata
// - cachedAt, lastValidatedAt: Timestamps
// - isAvailable: Current availability

// Fetch cached voices
let descriptor = VoiceCacheModel.fetchDescriptor(forProvider: "elevenlabs")
let cachedVoices = try modelContext.fetch(descriptor)

// Check if cache is stale (default: 24 hours)
if cachedVoices.first?.isStale() == true {
    // Refresh from provider
    let freshVoices = try await provider.fetchVoices()
}
```

## Thread Safety & Concurrency

SwiftHablare follows Swift 6 strict concurrency:

### Generation Service (Actor)

```swift
public actor GenerationService {
    // All methods are actor-isolated
    // Automatically runs on background thread
    // No data races possible

    func generate(...) async throws -> GenerationResult
    func fetchVoices() async throws -> [Voice]
}
```

### Sendable Results

```swift
public struct GenerationResult: Sendable {
    // All properties are Sendable
    // Can be safely transferred between threads
    public let audioData: Data
    public let voiceId: String
    // ...
}
```

### Main Thread Saves

```swift
// Generation happens off main thread
let result = try await service.generate(forElement: element, ...)

// SwiftData saves MUST happen on main thread
await MainActor.run {
    let record = result.toTypedDataStorage()
    modelContext.insert(record)
    try? modelContext.save()
}
```

## TypedDataStorage Integration

Generated audio is saved using `TypedDataStorage` from SwiftCompartido:

```swift
// Automatic conversion from GenerationResult
let audioRecord = result.toTypedDataStorage()

// Properties set automatically:
// - id: Request UUID
// - providerId: "apple" or "elevenlabs"
// - requestorID: "{providerId}.audio.tts"
// - mimeType: "audio/mpeg" or "audio/wav"
// - binaryValue: Audio data
// - prompt: Original text
// - durationSeconds: Estimated duration
// - voiceID, voiceName: Voice metadata

// Link to element
element.generatedContent?.append(audioRecord)
modelContext.insert(audioRecord)
try modelContext.save()
```

### File-Based Storage

For large audio files, use file-based storage:

```swift
import SwiftCompartido

let requestID = UUID()
let storage = StorageAreaReference.temporary(requestID: requestID)

let result = try await service.generate(forElement: element, ...)

await MainActor.run {
    let audioRecord = result.toTypedDataStorage()

    // Save to file (instead of in-memory)
    try? audioRecord.saveBinary(
        result.audioData,
        to: storage,
        fileName: "audio.mp3"
    )

    element.generatedContent?.append(audioRecord)
    modelContext.insert(audioRecord)
    try? modelContext.save()
}
```

## Advanced Usage

### Batch Generation

```swift
@MainActor
func generateAudioForElements(_ elements: [GuionElementModel]) async throws {
    let service = GenerationService(voiceProvider: ElevenLabsVoiceProvider())

    for element in elements {
        do {
            let result = try await service.generate(
                forElement: element,
                voiceId: "21m00Tcm4TlvDq8ikWAM",
                voiceName: "Rachel"
            )

            let audioRecord = result.toTypedDataStorage()
            element.generatedContent?.append(audioRecord)
            modelContext.insert(audioRecord)

            // Save every 10 elements
            if elements.firstIndex(of: element)! % 10 == 0 {
                try modelContext.save()
            }
        } catch {
            print("Failed to generate audio for element: \(error)")
        }
    }

    // Final save
    try modelContext.save()
}
```

### Progress Tracking

```swift
@MainActor
func generateWithProgress(_ elements: [GuionElementModel]) async throws {
    let service = GenerationService(voiceProvider: ElevenLabsVoiceProvider())

    for (index, element) in elements.enumerated() {
        let progress = Double(index) / Double(elements.count)
        updateProgressBar(progress)

        let result = try await service.generate(forElement: element, ...)
        let audioRecord = result.toTypedDataStorage()

        element.generatedContent?.append(audioRecord)
        modelContext.insert(audioRecord)
    }

    try modelContext.save()
}
```

### Custom Voice Selection

```swift
// Fetch voices and let user select
let voices = try await service.fetchVoices()

// Filter by gender
let femaleVoices = voices.filter { $0.gender == "female" }

// Filter by language
let englishVoices = voices.filter { $0.language == "en" }

// Generate with selected voice
let selectedVoice = englishVoices.first!
let result = try await service.generate(
    forElement: element,
    voiceId: selectedVoice.id,
    voiceName: selectedVoice.name
)
```

## Error Handling

```swift
do {
    let result = try await service.generate(forElement: element, ...)
    // Success
} catch VoiceProviderError.notConfigured {
    // Provider not configured (missing API key)
    promptForAPIKey()
} catch VoiceProviderError.networkError(let message) {
    // Network error (API down, rate limit, etc.)
    showError("Network error: \(message)")
} catch VoiceProviderError.invalidResponse {
    // Invalid response from provider
    showError("Invalid response from provider")
} catch {
    // Other errors
    showError("Generation failed: \(error)")
}
```

## Testing

SwiftHablare has a comprehensive test suite with over 109 passing tests and 96%+ coverage.

### Test Organization

Tests are organized into two categories for optimal CI performance:

**Fast Tests (Unit Tests):**
- ✅ Run on every pull request
- ✅ Run on push to main/master
- ⚡ Complete in ~30 seconds
- 📱 Run on **iOS Simulator** (iPhone 16 Pro)
- ❌ **Not run on macOS** (iOS and Catalyst only)
- 📁 All test files except those with "Integration" in the name
- Examples:
  - `AppleVoiceProviderTests.swift`
  - `GenerationServiceTests.swift`
  - `SpeakableItemTests.swift`
  - `VoiceModelTests.swift`

**Integration Tests (Long-Running):**
- 🗓️ Run weekly on Saturdays at 3 AM UTC
- 🧪 Real API calls to voice providers
- ⏱️ Complete in ~2-5 minutes
- 📱 Run on **iOS Simulator** (iPhone 16 Pro)
- ❌ **Not run on macOS** (iOS and Catalyst only)
- 📁 Tests with "Integration" in the class name
- Examples:
  - `AppleVoiceProviderIntegrationTests.swift`
  - `ElevenLabsVoiceProviderIntegrationTests.swift`

**Platform Support:**
- ✅ iOS 26+ (tested on iOS Simulator)
- ✅ Mac Catalyst 26+ (built for Catalyst, tested on simulator)
- ❌ macOS (not supported - tests will NOT run on macOS)

### Running Tests Locally

**Important:** Tests must be run on iOS Simulator, not macOS. Use `xcodebuild` with proper destinations.

**Run all tests on iOS Simulator:**
```bash
xcodebuild test \
  -scheme SwiftHablare \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

**Run only fast tests (skip integration) on iOS Simulator:**
```bash
xcodebuild test \
  -scheme SwiftHablare \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -skip-testing:SwiftHablareTests/AppleVoiceProviderIntegrationTests \
  -skip-testing:SwiftHablareTests/ElevenLabsVoiceProviderIntegrationTests
```

**Run only integration tests on iOS Simulator:**
```bash
xcodebuild test \
  -scheme SwiftHablare \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:SwiftHablareTests/AppleVoiceProviderIntegrationTests \
  -only-testing:SwiftHablareTests/ElevenLabsVoiceProviderIntegrationTests
```

**With code coverage:**
```bash
xcodebuild test \
  -scheme SwiftHablare \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -enableCodeCoverage YES
```

**Quick test with swift test (may default to macOS):**
> ⚠️ **Warning:** `swift test` without destinations may run tests for macOS, which is not supported. Use `xcodebuild` with explicit destinations for reliable testing.

```bash
# This may run on macOS - not recommended
swift test
```

### CI/CD Workflows

SwiftHablare uses GitHub Actions with three workflows. **All tests run on iOS Simulator (iPhone 16 Pro), not macOS.**

1. **`fast-tests.yml`** - Runs on every PR
   - ✅ Executes unit tests only on iOS Simulator
   - ⚡ Provides fast feedback for pull requests (~30s)
   - ⏭️ Skips integration tests to keep PRs responsive
   - ❌ Does not run on macOS (iOS/Catalyst only)

2. **`integration-tests.yml`** - Runs weekly
   - 🗓️ Saturday at 3 AM UTC (middle of the night for US timezones)
   - 🧪 Executes integration tests with real API calls on iOS Simulator
   - ⏱️ Long-running tests (~2-5 minutes)
   - 🎮 Can be triggered manually via workflow_dispatch
   - ❌ Does not run on macOS (iOS/Catalyst only)

3. **`tests-full.yml`** - Manual only
   - 📋 Full test suite (unit + integration) on iOS Simulator
   - 🔧 Useful for comprehensive testing before releases
   - 🎮 Triggered manually when needed
   - ❌ Does not run on macOS (iOS/Catalyst only)

### Writing Tests

Example unit test:

```swift
import XCTest
@testable import SwiftHablare

final class MyTests: XCTestCase {
    func testVoiceGeneration() async throws {
        let provider = AppleVoiceProvider()
        let voices = try await provider.fetchVoices()

        let audioData = try await provider.generateAudio(
            text: "Hello, world!",
            voiceId: voices.first!.id
        )

        XCTAssertGreaterThan(audioData.count, 1024)
    }
}
```

Example integration test (long-running):

```swift
import XCTest
@testable import SwiftHablare

// Note: "Integration" in the class name marks this as a long-running test
final class MyProviderIntegrationTests: XCTestCase {
    func testRealAPICall() async throws {
        // This test will be skipped in PR checks
        // and only run on the weekly schedule
        let provider = ElevenLabsVoiceProvider()
        let voices = try await provider.fetchVoices()

        // Real API calls...
    }
}
```

## Dependencies

- **SwiftCompartido** (required): Provides `GuionElementModel` and `TypedDataStorage`
- **SwiftData** (system): For `VoiceCacheModel` persistence
- **AVFoundation** (system): For Apple TTS provider
- **Foundation** (system): Core Swift types

## Migration from 2.x

SwiftHablare 3.0 is a complete rewrite. Key changes:

### Removed
- All text generation (OpenAI, Anthropic)
- All image generation
- All video generation
- All UI components (AudioPlayerManager, widgets, etc.)
- All SwiftData models except VoiceCacheModel

### Added
- VoiceCacheModel for voice caching
- GenerationService actor for safe concurrency
- Direct TypedDataStorage integration

### Migration Guide

**Before (2.x):**
```swift
// Old: Complex task-based system
let task = AudioGenerationTask(
    elements: elements,
    voiceProvider: provider,
    voiceId: voiceId,
    modelContext: modelContext
)
try await task.execute()
```

**After (3.0):**
```swift
// New: Simple service-based system
let service = GenerationService(voiceProvider: provider)
let result = try await service.generate(forElement: element, voiceId: voiceId)
let audioRecord = result.toTypedDataStorage()
modelContext.insert(audioRecord)
```

## License

MIT License - see LICENSE file for details.

## Contributing

Contributions welcome! Please see CONTRIBUTING.md for guidelines.

## Support

- **Issues**: [GitHub Issues](https://github.com/intrusive-memory/SwiftHablare/issues)
- **Discussions**: [GitHub Discussions](https://github.com/intrusive-memory/SwiftHablare/discussions)
