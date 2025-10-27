# GenerateAudioButton Component

## Overview

The `GenerateAudioButton` is a standardized SwiftUI component that manages the complete lifecycle of audio generation for `SpeakableItem` instances. It provides a seamless user experience by automatically checking for existing audio, generating audio on a background thread, and transitioning between generate and play states.

## Features

- ✅ **Automatic State Management**: Checks for existing audio in SwiftData on appear
- ✅ **Background Generation**: Uses `GenerationService` actor for thread-safe audio generation
- ✅ **Progress Tracking**: Real-time progress updates during generation (0-100%)
- ✅ **Cancellation Support**: Users can cancel ongoing generation
- ✅ **Error Handling**: Displays error state with retry option
- ✅ **SwiftData Integration**: Automatically persists to `TypedDataStorage`
- ✅ **Play Delegation**: Calls `onPlay` callback (app handles actual playback)

## State Transitions

```
┌─────────────┐
│  .checking  │ ──────> Check for existing audio in SwiftData
└─────────────┘
       │
       ├──> No audio found
       │         │
       │         v
       │    ┌─────────────┐
       │    │    .idle    │ ──────> Show "Generate" button
       │    └─────────────┘
       │         │
       │         │ User taps Generate
       │         v
       │    ┌─────────────┐
       │    │ .generating │ ──────> Show progress + cancel button
       │    └─────────────┘
       │         │
       │         ├──> Success ──────> .completed
       │         ├──> Error   ──────> .failed (show retry)
       │         └──> Cancelled ────> .idle
       │
       └──> Audio found
                 │
                 v
            ┌─────────────┐
            │ .completed  │ ──────> Show "Play" button
            └─────────────┘
                 │
                 │ User taps Play
                 v
            onPlay callback (app handles playback)
```

## Usage

### Basic Setup

```swift
import SwiftUI
import SwiftData
import SwiftHablare
import SwiftCompartido

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            VoiceCacheModel.self,      // Required for voice caching
            TypedDataStorage.self      // Required for audio persistence
        ])
    }
}
```

### Simple Example

```swift
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var service = GenerationService()

    var body: some View {
        let provider = AppleVoiceProvider()
        let message = SimpleMessage(
            content: "Hello, world!",
            voiceProvider: provider,
            voiceId: "com.apple.ttsbundle.Samantha-compact"
        )

        GenerateAudioButton(
            item: message,
            service: service,
            modelContext: modelContext,
            onPlay: { record in
                // App handles playback
                playAudio(record.binaryValue)
            }
        )
    }

    func playAudio(_ data: Data?) {
        // Implement your audio playback logic here
        // Example: Use AVAudioPlayer, AVPlayer, etc.
    }
}
```

### List of Items

```swift
struct MessagesView: View {
    @Environment(\.modelContext) private var modelContext
    let messages: [SimpleMessage]
    let service = GenerationService()

    var body: some View {
        List(messages, id: \.id) { message in
            HStack {
                VStack(alignment: .leading) {
                    Text(message.content)
                        .font(.body)
                    Text("Voice: \(message.voiceId)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                GenerateAudioButton(
                    item: message,
                    service: service,
                    modelContext: modelContext,
                    onPlay: { record in
                        playAudio(record)
                    }
                )
            }
        }
    }
}
```

### Custom SpeakableItem

```swift
struct Article: SpeakableItem {
    let title: String
    let content: String
    let voiceProvider: VoiceProvider
    let voiceId: String

    var textToSpeak: String {
        "\(title). \(content)"
    }
}

// Use it
let article = Article(
    title: "Breaking News",
    content: "This is the article content.",
    voiceProvider: AppleVoiceProvider(),
    voiceId: "voice-id"
)

GenerateAudioButton(
    item: article,
    service: service,
    modelContext: modelContext,
    onPlay: { record in
        playAudio(record.binaryValue)
    }
)
```

## API Reference

### Initialization

```swift
public init(
    item: any SpeakableItem,
    service: GenerationService,
    modelContext: ModelContext,
    onPlay: ((TypedDataStorage) -> Void)? = nil
)
```

**Parameters:**
- `item`: The `SpeakableItem` to generate audio for
- `service`: `GenerationService` for audio generation
- `modelContext`: SwiftData `ModelContext` for persistence
- `onPlay`: Optional callback when play button is tapped (receives the `TypedDataStorage` record)

### State Properties (Internal)

```swift
enum AudioState {
    case checking        // Checking if audio exists in SwiftData
    case idle            // No audio exists - show Generate button
    case generating      // Generating audio - show progress
    case completed(TypedDataStorage)  // Audio exists - show Play button
    case failed(Error)   // Generation failed - show retry
}

@State private var audioState: AudioState
@State private var progress: Double = 0.0  // 0.0 to 1.0
@State private var generationTask: Task<Void, Never>?
@State private var errorMessage: String?
```

## How It Works

### 1. Checking for Existing Audio

When the button appears, it queries SwiftData for existing audio:

```swift
let descriptor = FetchDescriptor<TypedDataStorage>(
    predicate: #Predicate { storage in
        storage.providerId == providerId &&
        storage.voiceID == voiceId &&
        storage.prompt == prompt
    }
)
```

- If audio exists → Transition to `.completed` state (show Play button)
- If no audio → Transition to `.idle` state (show Generate button)

### 2. Generating Audio

When the user taps Generate:

1. **Create Task**: Starts a background `Task` for cancellation support
2. **Generate Audio**: Calls `provider.generateAudio()` on background thread
3. **Update Progress**: Updates progress from 0.1 → 0.7 → 0.9 → 1.0
4. **Create Record**: Creates `TypedDataStorage` with audio data
5. **Persist**: Inserts record into SwiftData and saves
6. **Transition**: Moves to `.completed` state

```swift
let audioData = try await provider.generateAudio(
    text: text,
    voiceId: voiceId
)

let storage = TypedDataStorage(
    id: UUID(),
    providerId: providerId,
    requestorID: "\(providerId).audio.tts",
    mimeType: "audio/x-aiff",  // or "audio/mpeg" for ElevenLabs
    binaryValue: audioData,
    prompt: text,
    durationSeconds: duration,
    voiceID: voiceId
)

modelContext.insert(storage)
try modelContext.save()
```

### 3. Playing Audio

When the user taps Play:

- Calls the `onPlay` callback with the `TypedDataStorage` record
- App is responsible for playing the audio (SwiftHablare does NOT handle playback)

Example playback implementation:

```swift
import AVFoundation

func playAudio(_ data: Data?) {
    guard let audioData = data else { return }

    do {
        let player = try AVAudioPlayer(data: audioData)
        player.prepareToPlay()
        player.play()
    } catch {
        print("Failed to play audio: \(error)")
    }
}
```

## Integration with SwiftData

The button automatically creates and persists `TypedDataStorage` records:

```swift
TypedDataStorage(
    id: UUID(),
    providerId: "apple",           // or "elevenlabs"
    requestorID: "apple.audio.tts",
    mimeType: "audio/x-aiff",      // or "audio/mpeg"
    binaryValue: audioData,        // The actual audio
    prompt: "Text that was spoken",
    durationSeconds: 5.5,
    voiceID: "voice-id",
    voiceName: "Voice Name"        // Optional
)
```

These records can be queried later:

```swift
let descriptor = FetchDescriptor<TypedDataStorage>(
    predicate: #Predicate { storage in
        storage.providerId == "apple" &&
        storage.voiceID == "voice-id"
    }
)
let audioRecords = try modelContext.fetch(descriptor)
```

## Thread Safety

- ✅ **Actor-based generation**: Uses `GenerationService` actor for thread-safe operations
- ✅ **MainActor UI**: All UI updates happen on `@MainActor`
- ✅ **Swift 6 compliant**: Full Swift concurrency compliance
- ✅ **Structured concurrency**: Uses `Task` for cancellation support

## Error Handling

The button handles errors gracefully:

- **Provider not configured**: Shows error immediately
- **Generation failed**: Shows error with retry button
- **Cancelled**: Returns to idle state
- **SwiftData error**: Catches and displays error

Example error states:

```
┌─────────────────────────────────────┐
│  ⚠️  Failed                [Retry]  │
│  Provider not configured            │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│  ⚠️  Failed                [Retry]  │
│  Network error                      │
└─────────────────────────────────────┘
```

## Testing

The component includes 13 comprehensive tests:

```swift
✅ Button initializes with correct parameters
✅ Button initializes without onPlay callback
✅ Button detects existing audio in SwiftData
✅ Button shows idle state when no audio exists
✅ Button can generate audio and persist to SwiftData
✅ Button triggers onPlay callback when play is tapped
✅ Button handles missing provider gracefully
✅ Button queries SwiftData correctly
✅ Button handles multiple audio records correctly
✅ Button works with Apple provider
✅ Button works with ElevenLabs provider
✅ Generated audio uses correct MIME type for Apple
✅ Generated audio includes required metadata
```

Run tests:

```bash
xcodebuild test \
  -scheme SwiftHablare \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:SwiftHablareTests/GenerateAudioButtonTests
```

## Important Notes

### SwiftHablare Does NOT Handle Playback

The `GenerateAudioButton` **only** handles audio generation and persistence. It does **not** play audio. Apps are responsible for implementing their own audio playback logic via the `onPlay` callback.

Why?
- ✅ Keeps SwiftHablare focused (generation library, not player)
- ✅ Apps have different playback requirements
- ✅ Allows custom audio players, effects, mixing, etc.

### Audio Persistence

- Audio is automatically saved to SwiftData via `TypedDataStorage`
- Each audio record is uniquely identified by:
  - `providerId` (e.g., "apple", "elevenlabs")
  - `voiceID` (the specific voice used)
  - `prompt` (the text that was spoken)
- If you regenerate the same text with the same voice, it will overwrite the existing record

### Platform Support

- ✅ iOS 26.0+
- ✅ Mac Catalyst 26.0+
- ❌ macOS standalone (not supported)

### Simulator Limitations

On iOS Simulator, Apple TTS doesn't generate real audio buffers. The button will work but audio may be silent or placeholder.

## Files

- **Component**: `Sources/SwiftHablare/UI/GenerateAudioButton.swift`
- **Example**: `Sources/SwiftHablare/Examples/GenerateAudioButtonExample.swift`
- **Tests**: `Tests/SwiftHablareTests/GenerateAudioButtonTests.swift`
- **Documentation**: `Docs/GENERATE_AUDIO_BUTTON.md` (this file)

## Complete Example App

See `GenerateAudioButtonExample.swift` for a complete working example with:
- Provider selection
- Voice selection
- Multiple messages
- Audio playback
- List management

## Questions?

- GitHub Issues: https://github.com/intrusive-memory/SwiftHablare/issues
- GitHub Discussions: https://github.com/intrusive-memory/SwiftHablare/discussions
