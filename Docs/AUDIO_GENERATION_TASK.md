# AudioGenerationTask - Usage Guide

## Overview

`AudioGenerationTask` is a laser-focused system for generating spoken audio from screenplay elements and storing them in SwiftData. It processes `GuionElementModel` instances one-by-one, generating audio in the background and saving to `TypedDataStorage` on the main thread.

## Features

- ✅ **Sequential Processing**: Elements processed one-at-a-time in screenplay order
- ✅ **Background Generation**: Audio generation happens on background thread (non-blocking UI)
- ✅ **Main Thread Saves**: SwiftData operations safely on @MainActor
- ✅ **Progress Tracking**: Real-time progress with `BackgroundTask`
- ✅ **Error Handling**: Per-element error tracking with partial success support
- ✅ **Automatic Linking**: Generated audio automatically linked to source element
- ✅ **Provider Support**: Works with AppleVoiceProvider and ElevenLabsVoiceProvider
- ✅ **Cancellation**: Graceful cancellation with partial results preserved

## Basic Usage

### 1. Fetch Elements from SwiftData

```swift
import SwiftData
import SwiftCompartido

// Fetch elements in screenplay order
let descriptor = FetchDescriptor<GuionElementModel>(
    sortBy: [
        SortDescriptor(\GuionElementModel.chapterIndex),
        SortDescriptor(\GuionElementModel.orderIndex)
    ]
)
let elements = try modelContext.fetch(descriptor)
```

### 2. Create and Execute Task

#### Using ElevenLabs

```swift
import SwiftHablare

// Create provider with API key in Keychain
let provider = ElevenLabsVoiceProvider()

// Create task
let task = AudioGenerationTask(
    elements: elements,
    voiceProvider: provider,
    voiceId: "21m00Tcm4TlvDq8ikWAM",  // Rachel voice
    voiceName: "Rachel",
    modelContext: modelContext
)

// Execute
try await task.execute()

// Check results
print("Success: \(task.successCount), Failed: \(task.failureCount)")
```

#### Using Apple TTS

```swift
// Create Apple provider (no API key needed)
let provider = AppleVoiceProvider()

// Create task
let task = AudioGenerationTask(
    elements: elements,
    voiceProvider: provider,
    voiceId: "com.apple.voice.compact.en-US.Samantha",
    voiceName: "Samantha",
    modelContext: modelContext
)

// Execute
try await task.execute()
```

## Advanced Usage

### Filter Elements Before Processing

```swift
// Only process dialogue elements
let dialogueElements = elements.filter {
    $0.elementType == .dialogue || $0.elementType == .character
}

let task = AudioGenerationTask(
    elements: dialogueElements,
    voiceProvider: provider,
    voiceId: voiceId,
    voiceName: voiceName,
    modelContext: modelContext
)

try await task.execute()
```

### Track Progress in UI

```swift
@MainActor
final class AudioGenerationViewModel: ObservableObject {
    @Published var task: AudioGenerationTask?

    func generateAudio(for elements: [GuionElementModel]) async throws {
        let provider = ElevenLabsVoiceProvider()

        task = AudioGenerationTask(
            elements: elements,
            voiceProvider: provider,
            voiceId: "21m00Tcm4TlvDq8ikWAM",
            voiceName: "Rachel",
            modelContext: modelContext
        )

        try await task?.execute()
    }
}

// In SwiftUI view
struct AudioGenerationView: View {
    @ObservedObject var viewModel: AudioGenerationViewModel

    var body: some View {
        VStack {
            if let task = viewModel.task {
                ProgressView(
                    value: task.backgroundTask.progressFraction
                ) {
                    Text(task.backgroundTask.message)
                }

                Text("\(task.successCount) / \(task.backgroundTask.totalSteps)")
            }
        }
    }
}
```

### Handle Errors

```swift
let task = AudioGenerationTask(
    elements: elements,
    voiceProvider: provider,
    voiceId: voiceId,
    voiceName: voiceName,
    modelContext: modelContext
)

try await task.execute()

// Check for failures
let failures = task.results.filter { !$0.isSuccess }
for failure in failures {
    print("Failed for element: \(failure.element.elementText)")
    if let error = failure.error {
        print("Error: \(error)")
    }
}
```

### Cancellation Support

```swift
// Start task
Task {
    try await task.execute()
}

// Cancel from UI
Button("Cancel") {
    task.cancel()
}

// Task will throw CancellationError and preserve partial results
```

## Complete Workflow Example

### From Fountain File to Audio

```swift
import SwiftHablare
import SwiftCompartido
import SwiftData

@MainActor
func generateAudioFromFountain(
    fileURL: URL,
    voiceId: String,
    modelContext: ModelContext
) async throws {
    // 1. Parse screenplay
    let collection = try await GuionParsedElementCollection(
        file: fileURL,
        parser: .fountain
    )

    // 2. Convert to SwiftData models
    let document = GuionDocumentModel(
        filename: collection.filename ?? "Untitled",
        screenplay: collection
    )
    modelContext.insert(document)
    try modelContext.save()

    // 3. Get elements in order
    let elements = document.sortedElements

    // 4. Generate audio
    let provider = ElevenLabsVoiceProvider()
    let task = AudioGenerationTask(
        elements: elements,
        voiceProvider: provider,
        voiceId: voiceId,
        voiceName: "Rachel",
        modelContext: modelContext
    )

    try await task.execute()

    print("Generated audio for \(task.successCount) elements")
}
```

### Retrieve Generated Audio

```swift
// Get all audio for an element
func getAudioForElement(_ element: GuionElementModel) -> [TypedDataStorage] {
    return element.generatedContent?.filter {
        $0.mimeType.hasPrefix("audio/")
    } ?? []
}

// Get audio data
if let audioRecord = getAudioForElement(element).first,
   let audioData = audioRecord.binaryValue {
    // Play audio
    playAudio(data: audioData, format: audioRecord.audioFormat ?? "mp3")
}

// Get metadata
if let audioRecord = getAudioForElement(element).first {
    print("Duration: \(audioRecord.durationSeconds ?? 0) seconds")
    print("Voice: \(audioRecord.voiceName ?? "Unknown")")
    print("Provider: \(audioRecord.providerId)")
}
```

## Provider Setup

### ElevenLabs Setup

```swift
import SwiftHablare

// Store API key in Keychain
try KeychainManager.shared.storePassword(
    apiKey,
    account: "elevenlabs-api-key"
)

// Create provider
let provider = ElevenLabsVoiceProvider()

// Fetch available voices
let voices = try await provider.fetchVoices()
for voice in voices {
    print("\(voice.name): \(voice.id)")
}
```

### Apple TTS Setup

```swift
// No API key needed - uses system voices
let provider = AppleVoiceProvider()

// Fetch available voices
let voices = try await provider.fetchVoices()
for voice in voices {
    print("\(voice.name): \(voice.id)")
}
```

## Error Types

### VoiceProviderError

```swift
public enum VoiceProviderError: Error {
    case notConfigured              // Missing API key
    case networkError(String)       // Network/HTTP errors
    case invalidResponse            // Malformed response
    case unsupportedProvider        // Unknown provider
    case notSupported              // Platform not supported
}
```

### TypedDataStorageError

```swift
public enum TypedDataStorageError: Error {
    case unsupportedMimeType(String)
    case storageTypeNotAvailable(mimeType: String, reason: String)
    case invalidStorageConfiguration(reason: String)
    case contentTypeMismatch(expected: String, got: String)
}
```

## Thread Safety

The task is fully thread-safe and Swift 6 concurrency compliant:

```
Background Thread              Main Thread (@MainActor)
─────────────────             ────────────────────────
AudioGenerationTask.execute()
├─> For each element:
│   ├─> service.generate()    (Background)
│   │   ├─> provider.generateAudio()
│   │   └─> Return Sendable result
│   │
│   └─> result.toTypedDataStorage()  ──> (Main thread)
│       ├─> element.generatedContent.append()
│       ├─> modelContext.insert()
│       └─> modelContext.save()  (periodic)
│
└─> Final modelContext.save()
```

## Performance

### Periodic Saves

Audio records are saved every 10 elements to prevent data loss:

```swift
// Automatic in AudioGenerationTask
if (index + 1) % 10 == 0 {
    try modelContext.save()
}
```

### Estimated Duration

```swift
// Each element generation time varies by provider:
// - Apple TTS: ~0.1-1 second per element
// - ElevenLabs: ~1-3 seconds per element (network dependent)

// For 100 elements:
// - Apple TTS: ~1-2 minutes
// - ElevenLabs: ~2-5 minutes
```

## Integration with BackgroundTaskManager

```swift
import SwiftHablare

// Use with BackgroundTaskManager for UI integration
let taskManager = BackgroundTaskManager()

let audioTask = AudioGenerationTask(
    elements: elements,
    voiceProvider: provider,
    voiceId: voiceId,
    voiceName: voiceName,
    modelContext: modelContext
)

// Queue the task
taskManager.queueTask(audioTask)

// Task will execute automatically with UI updates
```

## Querying Generated Audio

### Get All Audio for Document

```swift
// Get all audio records for a screenplay
let audioRecords = document.sortedElementGeneratedContent(mimeTypePrefix: "audio/")

print("Total audio files: \(audioRecords.count)")

// Calculate total duration
let totalDuration = audioRecords.compactMap { $0.durationSeconds }.reduce(0, +)
print("Total audio duration: \(totalDuration) seconds")
```

### Get Audio for Specific Element Types

```swift
// Get all dialogue audio
let dialogueAudio = document.sortedElementGeneratedContent(for: .dialogue)

// Get all character name audio
let characterAudio = document.sortedElementGeneratedContent(for: .character)
```

## Best Practices

1. **Always fetch elements in screenplay order** using `chapterIndex` and `orderIndex`
2. **Use try-catch** around execute() to handle errors gracefully
3. **Check results** after execution to identify failures
4. **Store API keys securely** in Keychain (for ElevenLabs)
5. **Filter elements** before processing to only generate audio for desired types
6. **Monitor progress** via BackgroundTask for UI updates
7. **Handle cancellation** appropriately in UI
8. **Batch processing**: For large screenplays, consider processing in chunks

## Related Documentation

- `VOICE_GENERATION_THREAD_SAFETY.md` - Thread safety architecture
- `TYPED_DATA_STORAGE.md` - Storage model details
- `SWIFTDATA_MODELS_ORGANIZATION.md` - Model relationships
- `SCREENPLAY_UI_SPRINT_METHODOLOGY.md` - UI integration patterns

## File Location

- **AudioGenerationTask.swift**: `/Users/stovak/Projects/SwiftHablare/Sources/SwiftHablare/AudioGeneration/AudioGenerationTask.swift`
