# Voice Generation Thread Safety Architecture

## Overview

The Voice Generation system implements best practices for thread safety in Swift 6, ensuring safe concurrent audio generation with proper SwiftData persistence.

## Architecture

### Thread Safety Principles

1. **Background Generation** - Audio generation happens on background threads
2. **Sendable Transfer** - Data passed between threads using Sendable types
3. **Main Thread Persistence** - SwiftData saves happen on @MainActor
4. **Actor Isolation** - VoiceGenerationService uses actor for thread safety

### Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│ Main Thread (@MainActor)                                    │
├─────────────────────────────────────────────────────────────┤
│ 1. Create VoiceGenerationRequest (Sendable)                 │
│    ├─> text: "Hello, world!"                               │
│    ├─> voiceId: "voice123"                                 │
│    └─> providerId: "elevenlabs"                            │
│                                                              │
│ 2. Pass to VoiceGenerationService (actor)                   │
│    └──────────────────────────────┐                        │
└────────────────────────────────────│────────────────────────┘
                                     │ Sendable
                                     ▼
┌─────────────────────────────────────────────────────────────┐
│ Background Thread (VoiceGenerationService actor)            │
├─────────────────────────────────────────────────────────────┤
│ 3. Generate audio via VoiceProvider                         │
│    ├─> Call API (may take seconds)                         │
│    ├─> Process audio data                                  │
│    └─> Extract metadata                                    │
│                                                              │
│ 4. Create VoiceGenerationResult (Sendable)                  │
│    ├─> audioData: Data                                     │
│    ├─> mimeType: "audio/mpeg"                              │
│    ├─> metadata: duration, sample rate, etc.               │
│    └──────────────────────────────┐                        │
└────────────────────────────────────│────────────────────────┘
                                     │ Sendable
                                     ▼
┌─────────────────────────────────────────────────────────────┐
│ Main Thread (@MainActor)                                    │
├─────────────────────────────────────────────────────────────┤
│ 5. Convert to TypedDataStorage                              │
│    └─> result.toTypedDataStorage()                         │
│                                                              │
│ 6. Save to SwiftData                                        │
│    ├─> modelContext.insert(record)                         │
│    └─> try modelContext.save()                             │
└─────────────────────────────────────────────────────────────┘
```

## Components

### 1. VoiceGenerationRequest (Sendable DTO)

**Thread-safe input** for voice generation.

```swift
public struct VoiceGenerationRequest: Sendable {
    public let id: UUID
    public let text: String
    public let voiceId: String
    public let voiceName: String?
    public let providerId: String
    public let requestorId: String
    public let modelIdentifier: String?
    public let mimeType: String
    public let useFileStorage: Bool
    public let metadata: [String: String]
}
```

**Key Properties**:
- `Sendable` - Can cross actor boundaries safely
- All properties are `let` - Immutable
- Value type (`struct`) - No shared mutable state
- Simple types only - No classes or mutable references

### 2. VoiceGenerationResult (Sendable DTO)

**Thread-safe output** from voice generation.

```swift
public struct VoiceGenerationResult: Sendable {
    public let requestId: UUID
    public let audioData: Data?
    public let mimeType: String
    public let durationSeconds: Double?
    public let sampleRate: Int?
    public let voiceId: String
    public let voiceName: String?
    public let providerId: String
    public let requestorId: String
    public let originalText: String
    public let characterCount: Int
    public let fileReference: TypedDataFileReference?
    public let estimatedCost: Double?
    public let metadata: [String: String]

    @MainActor
    public func toTypedDataStorage() -> TypedDataStorage
}
```

**Key Properties**:
- `Sendable` - Safe to pass from background to main thread
- Contains all data needed for SwiftData storage
- `toTypedDataStorage()` is @MainActor for safe conversion

### 3. VoiceGenerationService (Actor)

**Thread-safe coordinator** for voice generation.

```swift
public actor VoiceGenerationService {
    private let voiceProvider: VoiceProvider
    private var activeTasks: [UUID: Task<VoiceGenerationResult, Error>]

    public func generate(_ request: VoiceGenerationRequest) async throws -> VoiceGenerationResult

    @MainActor
    public func generateAndSave(_ request: VoiceGenerationRequest, to modelContext: ModelContext) async throws -> TypedDataStorage
}
```

**Actor Benefits**:
- Automatic synchronization of access to `activeTasks`
- No data races or race conditions
- Serial execution of methods on the actor

## Usage Patterns

### Pattern 1: Manual Two-Step Process

Generate on background thread, save on main thread:

```swift
// Step 1: Generate on background thread
let service = VoiceGenerationService(voiceProvider: provider)

let request = VoiceGenerationRequest(
    text: "Hello, world!",
    voiceId: "voice123",
    providerId: "elevenlabs",
    requestorId: "elevenlabs.audio.tts"
)

let result = try await service.generate(request)

// Step 2: Save on main thread
await MainActor.run {
    let record = result.toTypedDataStorage()
    modelContext.insert(record)
    try? modelContext.save()
}
```

### Pattern 2: Single-Step Convenience Method

Generate and save in one call:

```swift
let service = VoiceGenerationService(voiceProvider: provider)

let request = VoiceGenerationRequest(
    text: "Hello, world!",
    voiceId: "voice123",
    providerId: "elevenlabs",
    requestorId: "elevenlabs.audio.tts"
)

// Must be called from @MainActor context
let record = try await service.generateAndSave(request, to: modelContext)
```

### Pattern 3: With Progress Tracking

Track active generation tasks:

```swift
let service = VoiceGenerationService(voiceProvider: provider)

// Start generation
let request = VoiceGenerationRequest(...)
let generationTask = Task {
    try await service.generate(request)
}

// Check progress
let activeCount = await service.activeCount
print("Active generations: \(activeCount)")

// Cancel if needed
await service.cancel(request.id)

// Wait for result
let result = try await generationTask.value
```

## Swift 6 Concurrency Compliance

### Sendable Conformance

All data transferred between threads is `Sendable`:

✅ **VoiceGenerationRequest** - Sendable struct
✅ **VoiceGenerationResult** - Sendable struct
✅ **TypedDataFileReference** - Sendable struct
✅ **Data** - Already Sendable
✅ **String** - Already Sendable
✅ **[String: String]** - Sendable dictionary

### Actor Isolation

```swift
// VoiceGenerationService is an actor
public actor VoiceGenerationService {
    // Mutable state is protected by actor
    private var activeTasks: [UUID: Task<...>] = [:]

    // Methods are isolated to the actor
    public func generate(...) async throws { ... }
}
```

### @MainActor for SwiftData

SwiftData operations require @MainActor:

```swift
extension VoiceGenerationResult {
    @MainActor
    public func toTypedDataStorage() -> TypedDataStorage {
        // Safe to create TypedDataStorage on main thread
        return TypedDataStorage(...)
    }
}

@MainActor
public func generateAndSave(..., to modelContext: ModelContext) async throws {
    // Safe to use modelContext on main thread
    modelContext.insert(record)
    try modelContext.save()
}
```

## Error Handling

### Generation Errors

```swift
do {
    let result = try await service.generate(request)
} catch VoiceProviderError.notConfigured {
    // Provider not configured
} catch VoiceProviderError.networkError(let message) {
    // Network issue
} catch TypedDataError.unsupportedMimeType(let type, _) {
    // Invalid MIME type
}
```

### Storage Errors

```swift
do {
    let record = try await service.generateAndSave(request, to: modelContext)
} catch {
    // SwiftData save error or generation error
}
```

## Thread Safety Guarantees

### ✅ Safe Operations

1. **Concurrent Generation** - Multiple requests can be generated in parallel
   ```swift
   let task1 = Task { try await service.generate(request1) }
   let task2 = Task { try await service.generate(request2) }
   let (result1, result2) = try await (task1.value, task2.value)
   ```

2. **Main Thread Saves** - SwiftData operations always on main thread
   ```swift
   await MainActor.run {
       modelContext.insert(record)  // Safe on main thread
   }
   ```

3. **Sendable Transfer** - No data races when passing results
   ```swift
   let result = try await service.generate(request)  // Safe
   await use(result)  // Safe - result is Sendable
   ```

### ❌ Unsafe Patterns (Prevented by Compiler)

1. **Accessing SwiftData off main thread** - Compiler error
   ```swift
   Task {
       modelContext.insert(record)  // ❌ Compiler error
   }
   ```

2. **Sharing mutable state** - Prevented by actor
   ```swift
   var sharedState: [UUID: Data] = [:]  // ❌ Not Sendable
   Task { sharedState[id] = data }  // ❌ Compiler error
   ```

3. **Non-Sendable transfer** - Compiler error
   ```swift
   class NonSendable { var data: Data }
   Task {
       let obj = NonSendable()
       await service.use(obj)  // ❌ Compiler error
   }
   ```

## Performance Characteristics

### Background Generation

- ✅ **Non-blocking** - UI remains responsive
- ✅ **Parallel** - Multiple generations can run simultaneously
- ✅ **Cancellable** - Can cancel in-flight requests

### Main Thread Operations

- ⚠️ **Fast** - Conversion to TypedDataStorage is O(1)
- ⚠️ **SwiftData Save** - May take time for large batches

### Memory Management

- ✅ **Efficient** - Audio data passed by value (copy-on-write)
- ⚠️ **Large Data** - Consider file storage for large audio
- ✅ **Automatic Cleanup** - Tasks cleaned up after completion

## Best Practices

### 1. Always Use Sendable DTOs

```swift
// ✅ Good - Sendable struct
struct Request: Sendable {
    let text: String
}

// ❌ Bad - Non-Sendable class
class Request {
    var text: String
}
```

### 2. SwiftData on Main Thread

```swift
// ✅ Good - @MainActor for SwiftData
@MainActor
func saveAudio(_ result: VoiceGenerationResult, context: ModelContext) {
    let record = result.toTypedDataStorage()
    context.insert(record)
}

// ❌ Bad - SwiftData off main thread
func saveAudio(_ result: VoiceGenerationResult, context: ModelContext) {
    Task {
        context.insert(...)  // ❌ Crash risk!
    }
}
```

### 3. Handle Cancellation

```swift
// ✅ Good - Cancellation support
let service = VoiceGenerationService(voiceProvider: provider)
let task = Task {
    try await service.generate(request)
}

// User cancels
task.cancel()
await service.cancel(request.id)
```

### 4. Error Handling

```swift
// ✅ Good - Specific error handling
do {
    let result = try await service.generate(request)
    await saveToSwiftData(result)
} catch VoiceProviderError.notConfigured {
    showConfigurationError()
} catch VoiceProviderError.networkError(let message) {
    showNetworkError(message)
} catch {
    showGenericError(error)
}
```

## Testing

### Unit Tests

```swift
func testVoiceGeneration() async throws {
    let service = VoiceGenerationService(voiceProvider: MockProvider())

    let request = VoiceGenerationRequest(
        text: "Test",
        voiceId: "test",
        providerId: "mock",
        requestorId: "mock.audio"
    )

    let result = try await service.generate(request)

    XCTAssertEqual(result.originalText, "Test")
    XCTAssertNotNil(result.audioData)
}
```

### Thread Safety Tests

```swift
func testConcurrentGeneration() async throws {
    let service = VoiceGenerationService(voiceProvider: provider)

    // Generate 10 requests concurrently
    try await withThrowingTaskGroup(of: VoiceGenerationResult.self) { group in
        for i in 0..<10 {
            let request = VoiceGenerationRequest(...)
            group.addTask {
                try await service.generate(request)
            }
        }

        var results: [VoiceGenerationResult] = []
        for try await result in group {
            results.append(result)
        }

        XCTAssertEqual(results.count, 10)
    }
}
```

## Migration from Old Code

### Before (Unsafe)

```swift
// ❌ Old pattern - no thread safety
func generateAudio(text: String, voice: String) {
    Task {
        let audio = try await provider.generateAudio(text: text, voiceId: voice)

        // Dangerous - SwiftData off main thread!
        let record = GeneratedAudioRecord(...)
        modelContext.insert(record)
        try modelContext.save()
    }
}
```

### After (Safe)

```swift
// ✅ New pattern - thread safe
func generateAudio(text: String, voice: String) {
    Task {
        let request = VoiceGenerationRequest(
            text: text,
            voiceId: voice,
            providerId: "elevenlabs",
            requestorId: "elevenlabs.audio.tts"
        )

        // Generate on background thread
        let result = try await service.generate(request)

        // Save on main thread
        await MainActor.run {
            let record = result.toTypedDataStorage()
            modelContext.insert(record)
            try? modelContext.save()
        }
    }
}
```

---

**See Also**:
- [VoiceGenerationRequest.swift](../Sources/SwiftHablare/VoiceGeneration/VoiceGenerationRequest.swift)
- [VoiceGenerationResult.swift](../Sources/SwiftHablare/VoiceGeneration/VoiceGenerationResult.swift)
- [VoiceGenerationService.swift](../Sources/SwiftHablare/VoiceGeneration/VoiceGenerationService.swift)
- [TypedDataStorage.swift](../Sources/SwiftHablare/SwiftDataModels/TypedDataStorage.swift)
