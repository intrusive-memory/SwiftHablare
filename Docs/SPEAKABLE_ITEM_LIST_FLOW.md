# SpeakableItemList Generation Flow

This document describes the complete flow for processing a `SpeakableItemList` through SwiftHablaré's generation system, from creation to SwiftData persistence via SwiftCompartido's `TypedDataStorage`.

## Overview

The SpeakableItemList system provides a structured, observable way to generate audio for multiple speakable items with:
- **Progress tracking**: Real-time updates on current item and percentage complete
- **Actor-based processing**: Background audio generation with main-thread persistence
- **Cancellation support**: Graceful cancellation with partial result preservation
- **Error handling**: Captures errors while preserving successfully generated audio
- **SwiftData integration**: Automatic persistence to TypedDataStorage

## Architecture Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    Application Layer                            │
│                      (@MainActor)                               │
│                                                                 │
│  1. Create SpeakableItemList                                    │
│     - name: "My List"                                           │
│     - items: [SpeakableItem, SpeakableItem, ...]               │
│                                                                 │
│  2. Create GenerationService                                    │
│     - voiceProvider: AppleVoiceProvider()                       │
│                                                                 │
│  3. Call service.generateList(list, to: modelContext)           │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         │ async call
                         ↓
┌─────────────────────────────────────────────────────────────────┐
│              GenerationService (actor)                          │
│                  Background Thread                              │
│                                                                 │
│  for each item in list:                                         │
│    1. Check cancellation                                        │
│    2. Get item from list (via @MainActor)                       │
│    3. Generate audio (background)                               │
│       ↓                                                          │
│       VoiceProvider.generateAudio()                             │
│       ↓                                                          │
│       Audio Data (AIFF/MP3)                                     │
│    4. Switch to @MainActor                                      │
│       ↓                                                          │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         │ Audio Data (Sendable)
                         ↓
┌─────────────────────────────────────────────────────────────────┐
│                     @MainActor Context                          │
│                      Main Thread                                │
│                                                                 │
│  5. Create TypedDataStorage                                     │
│     - id: UUID()                                                │
│     - providerId: "apple" or "elevenlabs"                       │
│     - requestorID: "provider.audio.tts"                         │
│     - mimeType: "audio/x-aiff" or "audio/mpeg"                  │
│     - binaryValue: audioData                                    │
│     - prompt: item.textToSpeak                                  │
│     - durationSeconds: estimated duration                       │
│     - voiceID: item.voiceId                                     │
│                                                                 │
│  6. Insert into ModelContext                                    │
│     modelContext.insert(record)                                 │
│                                                                 │
│  7. Save periodically                                           │
│     modelContext.save() // every N items                        │
│                                                                 │
│  8. Update progress                                             │
│     list.advanceProgress()                                      │
│     list.currentIndex++                                         │
│     list.progress = currentIndex / totalCount                   │
│                                                                 │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         │ Repeat for all items
                         ↓
┌─────────────────────────────────────────────────────────────────┐
│                SwiftData / TypedDataStorage                     │
│                  Persistent Storage                             │
│                                                                 │
│  TypedDataStorage records:                                      │
│  [                                                              │
│    { id: UUID-1, audio: Data, prompt: "Hello", ... },          │
│    { id: UUID-2, audio: Data, prompt: "World", ... },          │
│    ...                                                          │
│  ]                                                              │
│                                                                 │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         │ Final save
                         ↓
┌─────────────────────────────────────────────────────────────────┐
│                  Completion / Error                             │
│                                                                 │
│  Success:                                                       │
│    - list.isComplete = true                                     │
│    - list.isProcessing = false                                  │
│    - list.statusMessage = "Complete"                            │
│    - Returns [TypedDataStorage]                                 │
│                                                                 │
│  Cancelled:                                                     │
│    - list.isCancelled = true                                    │
│    - Partial results saved                                      │
│    - Returns generated records so far                           │
│                                                                 │
│  Error:                                                         │
│    - list.hasFailed = true                                      │
│    - list.error = captured error                                │
│    - Partial results saved                                      │
│    - Throws error after saving                                  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Step-by-Step Flow

### Step 1: Create SpeakableItemList

```swift
@MainActor
func createList() async throws {
    let provider = AppleVoiceProvider()
    let voices = try await provider.fetchVoices()
    let voiceId = voices.first!.id

    // Create your speakable items
    let items: [any SpeakableItem] = [
        SimpleMessage(
            content: "Hello, world!",
            voiceProvider: provider,
            voiceId: voiceId
        ),
        Article(
            title: "Breaking News",
            author: "Jane Doe",
            content: "This is the news content.",
            voiceProvider: provider,
            voiceId: voiceId
        ),
        CharacterDialogue(
            characterName: "Alice",
            dialogue: "How are you doing?",
            voiceProvider: provider,
            voiceId: voiceId,
            includeCharacterName: true
        )
    ]

    // Create the list
    let list = SpeakableItemList(name: "My Speech List", items: items)

    // List is now ready for processing
    print("Created list with \(list.totalCount) items")
}
```

### Step 2: Create GenerationService

```swift
// Create the service with your chosen provider
let provider = AppleVoiceProvider()
let service = GenerationService(voiceProvider: provider)
```

### Step 3: Generate Audio for All Items

```swift
@MainActor
func generateAll() async throws {
    let list = // ... created in Step 1
    let service = // ... created in Step 2

    // Generate audio for all items with progress tracking
    let records = try await service.generateList(list, to: modelContext)

    // All items now have audio generated and persisted
    print("Generated \(records.count) audio files")
    print("Progress: \(list.progress * 100)%")
    print("Status: \(list.statusMessage)")
}
```

### Step 4: Monitor Progress (Optional)

```swift
import SwiftUI

@Observable
final class SpeechViewModel {
    var list: SpeakableItemList?
    var isGenerating: Bool = false

    @MainActor
    func generate() async throws {
        isGenerating = true
        defer { isGenerating = false }

        // list is Observable, so SwiftUI will update automatically
        let records = try await service.generateList(list!, to: modelContext)
        print("Completed with \(records.count) records")
    }
}

struct ProgressView: View {
    @Bindable var viewModel: SpeechViewModel

    var body: some View {
        if let list = viewModel.list {
            VStack {
                Text(list.name)
                    .font(.headline)

                ProgressView(value: list.progress)
                    .progressViewStyle(.linear)

                Text("\(list.currentIndex) of \(list.totalCount)")
                    .font(.caption)

                Text(list.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if list.isProcessing {
                    Button("Cancel") {
                        list.cancel()
                    }
                }
            }
            .padding()
        }
    }
}
```

### Step 5: Handle Cancellation

```swift
@MainActor
func generateWithCancellation() async throws {
    let list = SpeakableItemList(name: "My List", items: items)

    // Start generation
    Task {
        let records = try await service.generateList(list, to: modelContext)
        print("Generated \(records.count) items (may be partial)")
    }

    // Cancel after delay
    try await Task.sleep(for: .seconds(2))
    list.cancel()

    // Generation will stop gracefully
    // Partial results are preserved in SwiftData
}
```

### Step 6: Handle Errors

```swift
@MainActor
func generateWithErrorHandling() async {
    let list = SpeakableItemList(name: "My List", items: items)

    do {
        let records = try await service.generateList(list, to: modelContext)
        print("✅ Success: Generated \(records.count) items")

    } catch {
        // Partial results are already saved to SwiftData
        print("❌ Error: \(error.localizedDescription)")
        print("Saved \(list.currentIndex) items before error")

        if list.hasFailed {
            print("List error: \(list.error?.localizedDescription ?? "unknown")")
        }
    }
}
```

## Thread Safety

The system is designed with strict thread safety:

### Background Thread (Actor)
- `GenerationService` is an `actor` (automatic synchronization)
- Audio generation happens on background thread
- Non-blocking for UI

### Main Thread (@MainActor)
- `SpeakableItemList` is `@MainActor` (UI updates)
- SwiftData operations (insert, save)
- Progress updates

### Data Transfer
- Audio `Data` is `Sendable` (safe to transfer between threads)
- No data races or concurrency issues
- Swift 6 concurrency compliant

```
Background Thread                Main Thread (@MainActor)
─────────────────                ────────────────────────
generate audio
     ↓
create Data ──────────────────→ create TypedDataStorage
  (Sendable)                         ↓
                                  insert into context
                                       ↓
                                  save to SwiftData
                                       ↓
                                  update progress
```

## Error Handling Strategy

### Partial Results Preservation

When an error occurs or generation is cancelled, the system:

1. **Saves partial results**: All successfully generated items are saved to SwiftData
2. **Updates list state**: Sets error/cancelled flag
3. **Returns or throws**: Returns records (cancellation) or throws error (failure)

```swift
// Scenario: Generate 10 items, error on item 7

try await service.generateList(list, to: modelContext)
// Throws error, but items 1-6 are saved to SwiftData

// Check partial results
let descriptor = FetchDescriptor<TypedDataStorage>()
let saved = try modelContext.fetch(descriptor)
print("Saved \(saved.count) items before error") // 6
```

## Performance Considerations

### Save Intervals

By default, the system saves after every item. For large lists, adjust the save interval:

```swift
// Save every 10 items instead of every item
let records = try await service.generateList(
    list,
    to: modelContext,
    saveInterval: 10  // Default: 1
)
```

**Trade-offs**:
- **Low interval (1)**: Maximum safety, slower for large lists
- **High interval (50)**: Faster, risk losing more on crash

### Memory Management

For very large lists (500+ items), consider:
1. Processing in batches
2. Using higher save intervals
3. Monitoring memory usage

```swift
// Process large list in batches
let allItems = // ... 1000 items
let batchSize = 100

for i in stride(from: 0, to: allItems.count, by: batchSize) {
    let endIndex = min(i + batchSize, allItems.count)
    let batch = Array(allItems[i..<endIndex])

    let batchList = SpeakableItemList(
        name: "Batch \(i/batchSize + 1)",
        items: batch
    )

    let records = try await service.generateList(
        batchList,
        to: modelContext,
        saveInterval: 20
    )

    print("Completed batch \(i/batchSize + 1)")
}
```

## Integration with SwiftCompartido

The system automatically creates `TypedDataStorage` records from SwiftCompartido:

```swift
// Generated record structure
TypedDataStorage(
    id: UUID(),
    providerId: "apple",           // or "elevenlabs"
    requestorID: "apple.audio.tts",
    mimeType: "audio/x-aiff",      // or "audio/mpeg" for ElevenLabs
    textValue: nil,                // Audio is binary
    binaryValue: audioData,        // The actual audio
    prompt: "Text that was spoken",
    durationSeconds: 5.2,          // Estimated duration
    voiceID: "com.apple.voice...",
    voiceName: nil
)
```

### Querying Generated Audio

```swift
@MainActor
func fetchGeneratedAudio() throws -> [TypedDataStorage] {
    // Fetch all audio records
    let descriptor = FetchDescriptor<TypedDataStorage>(
        predicate: #Predicate { record in
            record.mimeType.hasPrefix("audio/")
        }
    )

    let records = try modelContext.fetch(descriptor)
    return records
}

@MainActor
func playAudio(for record: TypedDataStorage) throws {
    // Get the binary audio data
    let audioData = try record.getBinary()

    // Play using AVAudioPlayer or your audio system
    // ...
}
```

## Complete Example

Here's a complete, runnable example:

```swift
import SwiftUI
import SwiftData
import SwiftHablare
import SwiftCompartido

@Observable
@MainActor
final class SpeechListViewModel {
    var list: SpeakableItemList?
    var isGenerating = false
    var generatedRecords: [TypedDataStorage] = []
    var errorMessage: String?

    private let service: GenerationService
    private let modelContext: ModelContext

    init(service: GenerationService, modelContext: ModelContext) {
        self.service = service
        self.modelContext = modelContext
    }

    func createList() async throws {
        let provider = AppleVoiceProvider()
        let voices = try await provider.fetchVoices()
        let voiceId = voices.first!.id

        let items: [any SpeakableItem] = [
            SimpleMessage(content: "Hello", voiceProvider: provider, voiceId: voiceId),
            SimpleMessage(content: "World", voiceProvider: provider, voiceId: voiceId),
            Article(
                title: "News",
                author: "Reporter",
                content: "Breaking news today.",
                voiceProvider: provider,
                voiceId: voiceId
            )
        ]

        list = SpeakableItemList(name: "Sample List", items: items)
    }

    func generate() async {
        guard let list = list else { return }

        isGenerating = true
        errorMessage = nil

        do {
            generatedRecords = try await service.generateList(list, to: modelContext)
            print("✅ Generated \(generatedRecords.count) audio files")
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Error: \(error)")
        }

        isGenerating = false
    }

    func cancel() {
        list?.cancel()
    }
}

struct SpeechListView: View {
    @Bindable var viewModel: SpeechListViewModel

    var body: some View {
        VStack(spacing: 20) {
            if let list = viewModel.list {
                VStack {
                    Text(list.name)
                        .font(.headline)

                    ProgressView(value: list.progress)
                        .progressViewStyle(.linear)

                    HStack {
                        Text("\(list.currentIndex) of \(list.totalCount)")
                        Spacer()
                        Text("\(Int(list.progress * 100))%")
                    }
                    .font(.caption)

                    Text(list.statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )

                if viewModel.isGenerating {
                    Button("Cancel", action: viewModel.cancel)
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                } else if list.isComplete {
                    Text("✅ Complete!")
                        .font(.headline)
                        .foregroundStyle(.green)
                } else {
                    Button("Generate", action: {
                        Task { await viewModel.generate() }
                    })
                    .buttonStyle(.borderedProminent)
                }

                if let error = viewModel.errorMessage {
                    Text("Error: \(error)")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                if !viewModel.generatedRecords.isEmpty {
                    List(viewModel.generatedRecords, id: \.id) { record in
                        VStack(alignment: .leading) {
                            Text(record.prompt ?? "")
                                .font(.body)
                            Text("\(record.binaryValue?.count ?? 0) bytes")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .task {
            try? await viewModel.createList()
        }
    }
}
```

## Summary

The SpeakableItemList system provides:

✅ **Structured processing**: Organized, sequential audio generation
✅ **Progress tracking**: Real-time observable progress updates
✅ **Thread safety**: Actor-based background processing with main-thread persistence
✅ **Cancellation**: Graceful cancellation with partial result preservation
✅ **Error handling**: Captures errors while saving completed work
✅ **SwiftData integration**: Automatic persistence via TypedDataStorage
✅ **SwiftUI ready**: Observable properties for reactive UI updates

This architecture enables robust, production-ready audio generation for any iOS or Mac Catalyst application using SwiftHablaré with SwiftCompartido.
