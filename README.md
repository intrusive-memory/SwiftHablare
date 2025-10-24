# SwiftHablare

**Simple voice generation library** - Convert text into spoken audio using Apple TTS or ElevenLabs.

## Overview

SwiftHablare is a focused Swift library that takes text and a voice ID, then generates audio. Simple API: `text + voiceId → audio`.

**Core Features:**
- **Two voice providers**: Apple Text-to-Speech (built-in) and ElevenLabs (API-based)
- **Voice caching**: Reduces API calls by caching available voices in SwiftData
- **Thread-safe generation**: Uses Swift actors for safe concurrency
- **Cross-platform**: iOS 26+ and Mac Catalyst 15.0+ (UIKit-based, no macOS)
- **No UI components**: Pure generation logic - UI lives in consuming apps
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

SwiftHablare includes support for testing generation workflows:

```swift
import SwiftHablare
import Testing

@Test("Voice provider generates audio")
func testVoiceGeneration() async throws {
    let provider = AppleVoiceProvider()
    let service = GenerationService(voiceProvider: provider)

    let element = GuionElementModel(/* ... */)
    let result = try await service.generate(
        forElement: element,
        voiceId: "test-voice",
        voiceName: "Test Voice"
    )

    #expect(result.audioData.count > 0)
    #expect(result.voiceId == "test-voice")
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
