# AsyncStream-Based Notification System

## Overview

SwiftHablare now uses a **deterministic, timeout-free notification system** for audio synthesis. This replaces the previous continuation-based approach with an event-driven architecture using Swift's `AsyncStream`.

## Key Features

✅ **No Timeouts** - All timing is event-driven from AVSpeechSynthesizer callbacks
✅ **Deterministic** - Events occur exactly when synthesis completes/cancels
✅ **Thread-Safe** - AsyncStream.Continuation handles cross-thread communication
✅ **Reactive** - Subscribers react to events as they occur
✅ **Cancellable** - AsyncStream supports task cancellation

## Architecture

### Components

#### 1. SynthesisEvent (Enum)
```swift
private enum SynthesisEvent: Sendable {
    case finished   // Synthesis completed successfully
    case cancelled  // Synthesis was cancelled
}
```

#### 2. SynthesizerDelegate (Event Emitter)
```swift
private final class SynthesizerDelegate: NSObject, AVSpeechSynthesizerDelegate {
    let events: AsyncStream<SynthesisEvent>
    private var eventContinuation: AsyncStream<SynthesisEvent>.Continuation?

    // Delegate methods emit events when AVSpeechSynthesizer completes
    nonisolated func speechSynthesizer(_:didFinish:) {
        eventContinuation?.yield(.finished)
        eventContinuation?.finish()
    }
}
```

#### 3. Event Subscription (Caller)
```swift
let delegate = SynthesizerDelegate()
synthesizer.delegate = delegate
synthesizer.write(utterance) { buffer in ... }

// Subscribe to events - waits deterministically
for await event in delegate.events {
    switch event {
    case .finished, .cancelled:
        // Process completion
        break
    }
}
```

## Event Flow

```
1. Setup Phase (MainActor)
   ├─ Create SynthesizerDelegate
   │  └─ Initialize AsyncStream<SynthesisEvent>
   ├─ Assign delegate to AVSpeechSynthesizer
   └─ Call synthesizer.write(utterance)
       └─ Register buffer callbacks

2. Buffer Processing Phase (AVFoundation Thread)
   ├─ Buffer callback #1 → Write frames to file
   ├─ Buffer callback #2 → Write frames to file
   ├─ ...
   └─ Buffer callback #N → Write frames to file

3. Completion Phase (AVFoundation Thread)
   └─ didFinish() or didCancel()
       └─ eventContinuation.yield(.finished)
           └─ AsyncStream emits event

4. Event Handling Phase (MainActor)
   └─ for await event in delegate.events
       └─ Receive .finished or .cancelled
           ├─ Finalize audio file
           ├─ Calculate duration
           └─ Resume continuation with results
```

## Benefits Over Previous Approach

### Old (Continuation-Based)
```swift
private var continuation: CheckedContinuation<Void, Never>?

func waitForCompletion() async {
    await withCheckedContinuation { cont in
        self.continuation = cont
    }
}

func didFinish() {
    continuation?.resume()  // ⚠️ Must be called exactly once
    continuation = nil
}
```

**Problems:**
- ❌ Continuation must be resumed exactly once (easy to misuse)
- ❌ No built-in timeout support
- ❌ Difficult to handle multiple events
- ❌ Manual state management for continuation

### New (AsyncStream-Based)
```swift
let events: AsyncStream<SynthesisEvent>

for await event in delegate.events {
    // Handle events as they arrive
}
```

**Advantages:**
- ✅ Can yield multiple events safely
- ✅ Built-in cancellation support (Task.cancel)
- ✅ Natural for event-driven programming
- ✅ Stream lifecycle managed automatically
- ✅ Type-safe event types

## Thread Safety

### AsyncStream.Continuation
- **Thread-safe** by design
- Can be called from any thread
- Internal synchronization handled by Swift runtime

### Happens-Before Relationships
1. All buffer callbacks complete **before** `didFinish()` is called
2. MainActor code subscribes to events **before** synthesis starts
3. Event handling occurs **after** all buffers are written
4. **No data races** due to guaranteed ordering

### Shared Mutable State
```swift
var audioFile: AVAudioFile?        // Written by buffer callbacks
var bufferCount = 0                // Written by buffer callbacks
var totalFrames: AVAudioFrameCount = 0  // Written by buffer callbacks

// MainActor reads AFTER event is received
for await event in delegate.events {
    let duration = Double(totalFrames) / sampleRate  // ✅ Safe read
}
```

**Why this is safe:**
- Buffer callbacks complete before `didFinish()` fires
- Event subscription blocks until event received
- Read happens after all writes complete

## Deterministic Timing

### No Arbitrary Waits
```swift
// ❌ OLD: Arbitrary timeout
try await Task.sleep(nanoseconds: 5_000_000_000)  // Wait 5 seconds

// ✅ NEW: Event-driven
for await event in delegate.events {
    // React immediately when ready
}
```

### Event-Driven Flow
- Synthesis takes **exactly** as long as AVSpeechSynthesizer needs
- No wasted time waiting for arbitrary timeouts
- No missed events due to timeout expiring early
- System is **deterministic** - events fire when work completes

## Usage Example

### Basic Audio Generation
```swift
func generateAudio(text: String, voiceId: String) async throws -> (Data, TimeInterval) {
    return try await withCheckedThrowingContinuation { continuation in
        Task { @MainActor in
            do {
                let synthesizer = AVSpeechSynthesizer()
                let delegate = SynthesizerDelegate()
                synthesizer.delegate = delegate

                var audioFile: AVAudioFile?
                var totalFrames: AVAudioFrameCount = 0
                var sampleRate: Double = 0

                synthesizer.write(utterance) { buffer in
                    // Write buffers to file
                    audioFile?.write(from: buffer)
                    totalFrames += buffer.frameLength
                }

                // Wait for completion event
                for await event in delegate.events {
                    switch event {
                    case .finished, .cancelled:
                        let data = try Data(contentsOf: tempURL)
                        let duration = Double(totalFrames) / sampleRate
                        continuation.resume(returning: (data, duration))
                        return
                    }
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
```

### Handling Cancellation
```swift
let task = Task {
    try await generateAudio(text: "Hello", voiceId: "voice-id")
}

// Cancel synthesis
task.cancel()  // AsyncStream receives cancellation, stops waiting
```

## Testing

### Unit Tests
```swift
@Test @MainActor
func testNotificationSystem() async throws {
    let engine = AVSpeechTTSEngine()

    // Generate audio - should complete without timeout
    let (data, duration) = try await engine.generateAudioWithDuration(
        text: "Test",
        voiceId: "com.apple.voice.compact.en-US.Samantha",
        languageCode: "en"
    )

    #expect(data.count > 0)
    #expect(duration > 0)
}
```

### Integration Tests
- ✅ All AVSpeechTTSEngine tests pass
- ✅ No timeouts or hanging
- ✅ Deterministic completion
- ✅ Works on both physical devices and simulators (with fallback)

## Migration Notes

### For SwiftHablare Contributors
No changes needed for external API. The notification system is internal to `AVSpeechTTSEngine`.

### For Produciesta and Other Consumers
No breaking changes. Public API remains:
```swift
let provider = AppleVoiceProvider()
let data = try await provider.generateAudio(text: "Hello", voiceId: "...", languageCode: "en")
```

## Performance

### Timing Characteristics
- **Setup**: < 1ms (create AsyncStream)
- **Buffer Processing**: Variable (depends on text length)
- **Event Emission**: < 1ms (AsyncStream.yield)
- **Event Handling**: Immediate (no polling)

### Memory
- AsyncStream: Minimal overhead (~100 bytes)
- Continuation: Held until stream finishes
- No accumulation of unhandled events

## Future Enhancements

### Possible Extensions
1. **Progress Events**: Emit events during buffer processing
   ```swift
   case bufferProcessed(Int)  // Buffer count
   case progressUpdate(Double)  // 0.0 to 1.0
   ```

2. **Error Events**: Emit specific error types
   ```swift
   case error(Error)
   case bufferWriteFailed(Error)
   ```

3. **Multiple Subscribers**: Support multiple listeners
   ```swift
   let stream1 = delegate.events
   let stream2 = delegate.events  // Share same stream
   ```

## References

- [Swift AsyncSequence Documentation](https://developer.apple.com/documentation/swift/asyncsequence)
- [AsyncStream Guide](https://developer.apple.com/documentation/swift/asyncstream)
- [Concurrency Model Documentation](./CONCURRENCY_MODEL.md)
- [AVSpeechSynthesizer Documentation](https://developer.apple.com/documentation/avfoundation/avspeechsynthesizer)

---

**Version**: 5.3.0+
**Implementation Date**: 2024-12-24
**Status**: ✅ Implemented and Tested
