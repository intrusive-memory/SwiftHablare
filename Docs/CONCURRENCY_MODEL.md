# AVSpeechTTSEngine Concurrency Model

## Overview

The `AVSpeechTTSEngine` uses an **event-driven notification system** that bridges async/await with callback-based AVFoundation APIs. This architecture is **deterministic** with **no timeouts or arbitrary waits** - all timing is controlled by AVSpeechSynthesizer's delegate callbacks.

## Notification System Architecture (Current)

### Design Principles

1. **No Timeouts**: The system never waits for arbitrary durations. All waits are event-driven.
2. **Deterministic Timing**: All timing is controlled by AVSpeechSynthesizer's callbacks.
3. **Reactive Pattern**: Subscribers react to events as they occur.
4. **Thread-Safe**: Uses AsyncStream for thread-safe event emission from arbitrary threads.

### AsyncStream-Based Event Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│ CALLER THREAD (arbitrary)                                               │
│                                                                          │
│  generateRealAudio(text: String, voiceId: String)                       │
│  ↓                                                                       │
│  withCheckedThrowingContinuation { continuation in                      │
│    Task { @MainActor in                                                 │
│      // Setup synthesis                                                 │
│      let delegate = SynthesizerDelegate()  // Creates AsyncStream       │
│      synthesizer.delegate = delegate                                    │
│      synthesizer.write(utterance) { buffer in ... }                     │
│                                                                          │
│      // Subscribe to events (deterministic, no timeout)                 │
│      for await event in delegate.events {                               │
│        switch event {                                                   │
│        case .finished, .cancelled:                                      │
│          // Process results and resume continuation                     │
│          continuation.resume(returning: (data, duration))               │
│        }                                                                 │
│      }                                                                   │
│    }                                                                     │
│  }                                                                       │
└─────────────────────────────────────────────────────────────────────────┘
                           ↑
                           │ Yields events
                           │
┌─────────────────────────────────────────────────────────────────────────┐
│ SynthesizerDelegate (NSObject, AVSpeechSynthesizerDelegate)             │
│                                                                          │
│  let events: AsyncStream<SynthesisEvent>  // Thread-safe stream         │
│  private var eventContinuation: AsyncStream.Continuation?               │
│                                                                          │
│  init() {                                                                │
│    events = AsyncStream { continuation in                               │
│      eventContinuation = continuation                                   │
│    }                                                                     │
│  }                                                                       │
│                                                                          │
│  nonisolated func didFinish(...) {                                      │
│    eventContinuation?.yield(.finished)  ← Thread-safe emit              │
│    eventContinuation?.finish()                                          │
│  }                                                                       │
│                                                                          │
│  nonisolated func didCancel(...) {                                      │
│    eventContinuation?.yield(.cancelled) ← Thread-safe emit              │
│    eventContinuation?.finish()                                          │
│  }                                                                       │
└─────────────────────────────────────────────────────────────────────────┘
                           ↑
                           │ Callbacks from AVFoundation
                           │
┌─────────────────────────────────────────────────────────────────────────┐
│ AVSpeechSynthesizer (Apple's internal thread)                           │
│                                                                          │
│  Buffer callbacks (N times):                                            │
│    { buffer in ... }  ← Write audio data to file                        │
│                                                                          │
│  Completion callback (1 time):                                          │
│    delegate.didFinish() or delegate.didCancel()                         │
│    ↓                                                                     │
│    Emits event to AsyncStream ────────────────────────────────────────► │
└─────────────────────────────────────────────────────────────────────────┘
```

### Event Flow Sequence

1. **Setup (MainActor)**
   - Create `SynthesizerDelegate` → initializes `AsyncStream<SynthesisEvent>`
   - Assign delegate to `AVSpeechSynthesizer`
   - Call `synthesizer.write(utterance)` → registers buffer callbacks

2. **Buffer Processing (AVFoundation Thread)**
   - Apple calls buffer callback N times
   - Each callback writes audio frames to file
   - Updates `bufferCount`, `totalFrames` (shared mutable state)

3. **Completion Notification (AVFoundation Thread)**
   - Apple calls `delegate.didFinish()` or `delegate.didCancel()`
   - Delegate emits event via `eventContinuation.yield(.finished)`
   - Event stream finishes via `eventContinuation.finish()`

4. **Event Handling (MainActor)**
   - `for await event in delegate.events` receives event
   - Process completion:
     - Finalize audio file
     - Calculate duration
     - Resume continuation with results

### Thread Safety Analysis

✅ **AsyncStream.Continuation is thread-safe**
- Apple's delegate callbacks run on arbitrary threads
- `yield()` and `finish()` are safe to call from any thread
- Internal synchronization handled by Swift runtime

✅ **Happens-before relationship**
- All buffer callbacks complete **before** `didFinish()` is called
- MainActor reads `bufferCount`/`totalFrames` **after** event is received
- No data races due to guaranteed ordering

✅ **No timeout needed**
- System waits indefinitely for AVSpeechSynthesizer to complete
- If synthesis never completes, task suspends (appropriate behavior)
- Caller can cancel the task externally if needed

## Legacy Concurrency Architecture (Deprecated)

### Old Continuation-Based Approach

The previous implementation used a continuation stored in the delegate:

```
┌─────────────────────────────────────────────────────────────────────────┐
│ CALLER THREAD (arbitrary)                                               │
│                                                                          │
│  generateRealAudio(text: String, voiceId: String)                       │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────┐          │
│  │ withCheckedThrowingContinuation { continuation in        │          │
│  │                                                           │          │
│  │   ┌───────────────────────────────────────────────┐      │          │
│  │   │ Task { @MainActor in                          │      │          │
│  │   │   // THREAD SWITCH: arbitrary → main thread   │      │          │
│  │   └───────────────────────────────────────────────┘      │          │
│  │                       │                                   │          │
│  └───────────────────────┼───────────────────────────────────┘          │
│                          │                                              │
└──────────────────────────┼──────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ MAIN ACTOR (main thread - required by AVSpeechSynthesizer)              │
│                                                                          │
│  do {                                                                    │
│    let utterance = AVSpeechUtterance(string: text)                      │
│    guard let voice = AVSpeechSynthesisVoice(identifier: voiceId) ...    │
│                                                                          │
│    let synthesizer = AVSpeechSynthesizer()                              │
│    let delegate = SynthesizerDelegate()                                 │
│    synthesizer.delegate = delegate                                      │
│                                                                          │
│    var audioFile: AVAudioFile?                                          │
│    var bufferCount = 0                                                  │
│    var totalFrames: AVAudioFrameCount = 0                               │
│                                                                          │
│    // Register SYNCHRONOUS callback (called on AVSpeechSynthesizer's    │
│    // internal thread)                                                  │
│    synthesizer.write(utterance) { buffer in ─────────┐                 │
│                                                       │                 │
│    }                                                  │                 │
│                                                       │                 │
│    // PROBLEM: await inside MainActor.run?           │                 │
│    await delegate.waitForCompletion() ◄───────┐      │                 │
│                                                │      │                 │
│    // Process results...                      │      │                 │
│    let data = try Data(contentsOf: tempURL)   │      │                 │
│    continuation.resume(returning: (data, ...))│      │                 │
│                                                │      │                 │
│  } catch {                                     │      │                 │
│    continuation.resume(throwing: ...)          │      │                 │
│  }                                             │      │                 │
│                                                │      │                 │
└────────────────────────────────────────────────┼──────┼─────────────────┘
                                                 │      │
                                                 │      │
┌────────────────────────────────────────────────┼──────┼─────────────────┐
│ AVSpeechSynthesizer INTERNAL THREAD (Apple's)  │      │                 │
│                                                 │      │                 │
│  Buffer Callback (SYNCHRONOUS, called N times) │      │                 │
│  ◄──────────────────────────────────────────────┘      │                 │
│                                                         │                 │
│  { buffer in                                           │                 │
│    guard let pcmBuffer = buffer as? AVAudioPCMBuffer   │                 │
│                                                         │                 │
│    // Create/write to audioFile (shared mutable state) │                 │
│    if audioFile == nil {                               │                 │
│      audioFile = try AVAudioFile(...)                  │                 │
│    }                                                    │                 │
│                                                         │                 │
│    let converted = convertFloat32ToInt16(pcmBuffer)    │                 │
│    try audioFile?.write(from: converted)               │                 │
│    bufferCount += 1                                    │                 │
│    totalFrames += converted.frameLength                │                 │
│  }                                                      │                 │
│                                                         │                 │
│  // After all buffers processed...                     │                 │
│                                                         │                 │
│  Delegate Callback (ARBITRARY THREAD)                  │                 │
│  ◄──────────────────────────────────────────────────────┘                 │
│                                                                          │
│  speechSynthesizer(_:didFinish:) or didCancel:                          │
│                                                                          │
│  ┌────────────────────────────────────────────────────┐                │
│  │ SynthesizerDelegate.didFinish()                     │                │
│  │                                                     │                │
│  │   continuation?.resume()   ─────────────────────────┼────┐          │
│  │   continuation = nil                                │    │          │
│  └────────────────────────────────────────────────────┘    │          │
│                                                             │          │
└─────────────────────────────────────────────────────────────┼──────────┘
                                                              │
                                                              │
┌─────────────────────────────────────────────────────────────┼──────────┐
│ CONTINUATION BRIDGE                                         │          │
│                                                             │          │
│  ┌────────────────────────────────────────────────────┐    │          │
│  │ SynthesizerDelegate                                 │    │          │
│  │                                                     │    │          │
│  │   nonisolated(unsafe) var continuation:            │    │          │
│  │     CheckedContinuation<Void, Never>?              │    │          │
│  │                                                     │    │          │
│  │   func waitForCompletion() async {                 │    │          │
│  │     await withCheckedContinuation { cont in        │    │          │
│  │       self.continuation = cont  ◄──────────────────┼────┘          │
│  │     }                                               │               │
│  │   }                                                 │               │
│  │                                                     │               │
│  │   nonisolated func didFinish(...) {                │               │
│  │     continuation?.resume()  ────────────────────────────────────┐  │
│  │     continuation = nil                             │             │  │
│  │   }                                                 │             │  │
│  └────────────────────────────────────────────────────┘             │  │
│                                                                      │  │
└──────────────────────────────────────────────────────────────────────┼──┘
                                                                       │
                                                                       │
                                    Resumes MainActor task ◄───────────┘
                                    which then processes results
                                    and calls continuation.resume()
```

## Thread Flow Summary

### Step 1: Entry (Arbitrary Thread)
```swift
func generateRealAudio() async throws -> (Data, TimeInterval)
```
- Called from any thread
- Returns a continuation-based async result

### Step 2: Switch to MainActor
```swift
Task { @MainActor in
  // All AVSpeechSynthesizer operations must happen here
}
```
- AVSpeechSynthesizer requires main thread
- Task creates main actor-isolated context

### Step 3: Setup (Main Thread)
```swift
let synthesizer = AVSpeechSynthesizer()  // ✅ Main thread required
let delegate = SynthesizerDelegate()     // ✅ Uninisolated
synthesizer.delegate = delegate          // ✅ Main thread required
```

### Step 4: Buffer Callback Registration (Main Thread)
```swift
synthesizer.write(utterance) { buffer in
  // ⚠️ SYNCHRONOUS callback on Apple's internal thread
  // ⚠️ Accesses shared mutable state: audioFile, bufferCount, totalFrames
}
```

**CONCURRENCY ISSUE #1: Race Condition**
- Buffer callback runs on AVSpeechSynthesizer's internal thread
- Modifies `audioFile`, `bufferCount`, `totalFrames` without synchronization
- MainActor code reads these variables after `await delegate.waitForCompletion()`
- **Potential data race** if buffer callback still running when MainActor reads

### Step 5: Wait for Completion (Main Thread)
```swift
await delegate.waitForCompletion()
```

**CONCURRENCY ISSUE #2: Nested Async**
- We're inside `Task { @MainActor in ... }` (async context)
- Calling `await` suspends the MainActor task
- When delegate resumes continuation, MainActor task resumes
- This is **correct** but creates nested async contexts

### Step 6: Delegate Callback (Arbitrary Thread)
```swift
nonisolated func speechSynthesizer(_:didFinish:) {
  continuation?.resume()  // ⚠️ Called from arbitrary thread
  continuation = nil
}
```

**CONCURRENCY ISSUE #3: Continuation Access**
- `continuation` marked `nonisolated(unsafe)` (suppresses warnings)
- Accessed from arbitrary thread (Apple's delegate callback thread)
- **Potential data race** if multiple threads access simultaneously

## Identified Concurrency Issues

### Issue 1: Shared Mutable State (audioFile, bufferCount, totalFrames)
**Problem:** Buffer callback (Apple's thread) writes to variables that MainActor reads.

**Current Code:**
```swift
var audioFile: AVAudioFile?        // ⚠️ Shared mutable state
var bufferCount = 0                // ⚠️ Shared mutable state
var totalFrames: AVAudioFrameCount = 0  // ⚠️ Shared mutable state

synthesizer.write(utterance) { buffer in
  // Apple's thread
  audioFile = try AVAudioFile(...)  // ⚠️ WRITE
  bufferCount += 1                  // ⚠️ WRITE
  totalFrames += frames             // ⚠️ WRITE
}

await delegate.waitForCompletion()

// MainActor reads
let duration = Double(totalFrames) / sampleRate  // ⚠️ READ
```

**Why It Might Work:**
- The `await delegate.waitForCompletion()` ensures all buffer callbacks have finished
- Buffer callbacks complete **before** `didFinish` is called
- So the read happens **after** all writes are done
- **This is actually safe** due to happens-before ordering

### Issue 2: Continuation Thread Safety
**Problem:** `continuation` accessed from multiple threads without protection.

**Current Code:**
```swift
private final class SynthesizerDelegate {
  nonisolated(unsafe) private var continuation: CheckedContinuation<Void, Never>?

  func waitForCompletion() async {
    await withCheckedContinuation { cont in
      self.continuation = cont  // Thread A (caller thread)
    }
  }

  nonisolated func didFinish(...) {
    continuation?.resume()  // Thread B (Apple's delegate thread)
    continuation = nil      // Thread B
  }
}
```

**Why It Might Work:**
- `waitForCompletion()` is called first, sets continuation
- `didFinish()` is called later, reads and clears continuation
- Happens-before relationship via AVSpeechSynthesizer's internal synchronization
- **This is actually safe** due to API contract

### Issue 3: Nested Async Contexts
**Problem:** Using `await` inside `Task { @MainActor in }` which is inside a continuation.

**Current Code:**
```swift
return try await withCheckedThrowingContinuation { continuation in
  Task { @MainActor in
    // ...
    await delegate.waitForCompletion()  // ⚠️ Nested await
    // ...
    continuation.resume(returning: ...)
  }
}
```

**Why This Is Correct:**
- `Task { @MainActor in }` is **asynchronous** (not MainActor.run which is synchronous)
- The `await` suspends the task, not the continuation callback
- When resumed, the task continues and eventually calls `continuation.resume()`
- **This is the correct pattern**

## Why Tests Might Be Failing

The concurrency model is **actually correct**, so test failures are likely due to:

1. **CI Environment Issues**
   - No TTS voices installed on CI runners
   - Already handled with `CI` environment check
   - Should generate placeholder audio

2. **AVSpeechSynthesizer Behavior**
   - On CI/Simulator: Might not call buffer callback at all
   - Code handles this: Falls back to placeholder if `bufferCount == 0`

3. **Test Timeout**
   - Tests might be timing out waiting for synthesis
   - `delegate.waitForCompletion()` might hang if delegate never called

4. **Missing @MainActor Annotations**
   - Some tests might not be running on MainActor
   - AVSpeechSynthesizer requires main thread

## Recommendations

### 1. Add Timeout to Delegate Wait
```swift
func waitForCompletion(timeout: TimeInterval = 30.0) async throws {
  try await withThrowingTaskGroup(of: Void.self) { group in
    group.addTask {
      await withCheckedContinuation { cont in
        self.continuation = cont
      }
    }

    group.addTask {
      try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
      throw VoiceProviderError.timeout
    }

    try await group.next()
    group.cancelAll()
  }
}
```

### 2. Verify MainActor in Tests
```swift
@Test @MainActor
func testAudioGeneration() async throws {
  // Ensures AVSpeechSynthesizer runs on main thread
}
```

### 3. Add Debug Logging for Delegate
```swift
nonisolated func speechSynthesizer(_:didFinish:) {
  #if DEBUG
  print("🎤 [Delegate] didFinish called on thread: \(Thread.current)")
  print("🎤 [Delegate] continuation exists: \(continuation != nil)")
  #endif
  continuation?.resume()
  continuation = nil
}
```

## Concurrency Model Summary

✅ **What's Correct:**
- Task { @MainActor in } for AVSpeechSynthesizer operations
- Continuation bridge between callback and async/await
- Happens-before ordering ensures thread safety
- Fallback to placeholder when buffers not generated

⚠️ **Potential Issues:**
- No timeout on delegate wait (could hang forever)
- Tests might not be @MainActor annotated
- CI environment might not call delegate at all

🔍 **Next Steps:**
1. Add timeout to `waitForCompletion()`
2. Add @MainActor to integration tests
3. Add debug logging to track delegate callbacks
4. Check if tests are hanging vs failing
