# SwiftHablare

**Audio generation library for screenplays** - Convert screenplay elements into spoken audio using Apple TTS or ElevenLabs.

## Overview

SwiftHablare is a focused, generation-only Swift library that converts `GuionElementModel` instances from SwiftCompartido into spoken audio. It provides:

- **Two voice providers**: Apple Text-to-Speech (built-in) and ElevenLabs (API-based)
- **Voice caching**: Reduces API calls by caching available voices in SwiftData
- **Thread-safe generation**: Uses Swift actors for safe concurrency
- **TypedDataStorage integration**: Saves audio using SwiftCompartido's unified storage model
- **No UI components**: Pure generation logic - UI lives in consuming apps
- **No circular dependencies**: Depends on SwiftCompartido, but SwiftCompartido doesn't depend on SwiftHablare

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/intrusive-memory/SwiftHablare.git", from: "3.0.0"),
    .package(url: "https://github.com/intrusive-memory/SwiftCompartido.git", from: "2.1.0")
]
```

## Requirements

- Swift 6.2+
- macOS 26.0+ / iOS 26.0+ / Mac Catalyst 26.0+
- SwiftCompartido 2.1.0+

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

Built-in macOS/iOS text-to-speech. No API key required.

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
- Uses NSSpeechSynthesizer on macOS (reliable, production-ready)
- Generates AIFF format audio files
- Automatic language filtering
- Quality detection (standard/enhanced/premium)
- Gender detection based on voice name

**Platform Support:**
- **macOS**: Full support with NSSpeechSynthesizer
- **iOS/Catalyst**: Limited support (audio generation in progress)

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
