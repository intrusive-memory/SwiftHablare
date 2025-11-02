# macOS Support Plan for SwiftHablare

## Current State

**iOS/Catalyst:**
- Uses `AVSpeechSynthesizer` (AVFoundation)
- UIKit for any platform-specific code
- Works on physical iOS devices
- Catalyst placeholder code (buggy, now fixed but generates silence)

**macOS:**
- Not currently supported
- Has different TTS API: `NSSpeechSynthesizer` (AppKit)
- Requires AppKit imports
- Different audio output mechanism

## Goal

Support both platforms with native TTS:
- **iOS:** Continue using `AVSpeechSynthesizer` (real speech on devices)
- **macOS:** Add `NSSpeechSynthesizer` support (real speech on Mac)
- **Shared:** Keep common interfaces and SwiftUI views working on both

## Architecture Overview

### Current AppleVoiceProvider Structure

```
AppleVoiceProvider (iOS only)
    ↓
AVSpeechSynthesizer
    ↓
#if targetEnvironment(simulator) → placeholder
#else → real TTS (iOS devices only)
```

### Proposed Multi-Platform Structure

```
AppleVoiceProvider (protocol implementation)
    ↓
Platform Detection
    ↓
    ├─ iOS: AVSpeechTTSEngine
    │        ↓
    │   AVSpeechSynthesizer.write() → AIFC audio data
    │
    └─ macOS: NSSpeechTTSEngine
             ↓
        NSSpeechSynthesizer.startSpeaking(to:) → AIFF audio data
```

## Step-by-Step Implementation Plan

### Phase 1: Code Organization (SwiftHablare)

#### Step 1.1: Create Platform Abstraction Layer

**New file:** `Sources/SwiftHablare/Providers/Apple/AppleTTSEngine.swift`

```swift
import Foundation
import AVFoundation

/// Platform-agnostic TTS engine protocol
protocol AppleTTSEngine {
    /// Generate audio data from text using specified voice
    func generateAudio(text: String, voiceId: String) async throws -> Data

    /// Get available voices for this platform
    func fetchVoices() async throws -> [Voice]

    /// Estimate duration for text
    func estimateDuration(text: String, voiceId: String) -> TimeInterval
}
```

#### Step 1.2: Extract iOS Implementation

**New file:** `Sources/SwiftHablare/Providers/Apple/AVSpeechTTSEngine.swift`

```swift
#if canImport(UIKit)
import UIKit
import AVFoundation

/// iOS implementation using AVSpeechSynthesizer
@available(iOS 13.0, *)
final class AVSpeechTTSEngine: AppleTTSEngine {
    func generateAudio(text: String, voiceId: String) async throws -> Data {
        // Move current iOS implementation here
        // Use AVSpeechSynthesizer.write()
    }

    func fetchVoices() async throws -> [Voice] {
        // Move current iOS voice fetching here
        // Use AVSpeechSynthesisVoice.speechVoices()
    }

    func estimateDuration(text: String, voiceId: String) -> TimeInterval {
        // Current iOS estimation logic
    }
}
#endif
```

#### Step 1.3: Create macOS Implementation

**New file:** `Sources/SwiftHablare/Providers/Apple/NSSpeechTTSEngine.swift`

```swift
#if canImport(AppKit)
import AppKit
import AVFoundation

/// macOS implementation using NSSpeechSynthesizer
@available(macOS 10.13, *)
final class NSSpeechTTSEngine: AppleTTSEngine {
    func generateAudio(text: String, voiceId: String) async throws -> Data {
        // NEW: Implement using NSSpeechSynthesizer
        // See implementation details below
    }

    func fetchVoices() async throws -> [Voice] {
        // NEW: Use NSSpeechSynthesizer.availableVoices
    }

    func estimateDuration(text: String, voiceId: String) -> TimeInterval {
        // Estimate based on text length
    }
}
#endif
```

#### Step 1.4: Update AppleVoiceProvider

**Modified file:** `Sources/SwiftHablare/Providers/AppleVoiceProvider.swift`

```swift
import Foundation

public final class AppleVoiceProvider: VoiceProvider {
    public let providerId = "apple"
    public let displayName = "Apple Text-to-Speech"
    public let requiresAPIKey = false

    // Platform-specific engine
    private let engine: AppleTTSEngine

    public init() {
        #if canImport(UIKit)
        self.engine = AVSpeechTTSEngine()
        #elseif canImport(AppKit)
        self.engine = NSSpeechTTSEngine()
        #else
        fatalError("Unsupported platform for Apple TTS")
        #endif
    }

    public func fetchVoices() async throws -> [Voice] {
        return try await engine.fetchVoices()
    }

    public func generateAudio(text: String, voiceId: String) async throws -> Data {
        return try await engine.generateAudio(text: text, voiceId: voiceId)
    }

    public func estimateDuration(text: String, voiceId: String) async -> TimeInterval {
        return engine.estimateDuration(text: text, voiceId: voiceId)
    }
}
```

### Phase 2: NSSpeechSynthesizer Implementation Details

#### Key Differences: AVSpeechSynthesizer vs NSSpeechSynthesizer

| Feature | AVSpeechSynthesizer (iOS) | NSSpeechSynthesizer (macOS) |
|---------|---------------------------|------------------------------|
| **Audio output** | `write()` method returns buffers | `startSpeaking(to: URL)` writes to file |
| **Async handling** | Async/await ready | Delegate-based (need wrapper) |
| **Voice format** | Identifier string | `NSSpeechSynthesizer.VoiceName` |
| **Audio format** | AIFC | AIFF |
| **Platform** | iOS 13+ | macOS 10.13+ |

#### NSSpeechTTSEngine Implementation

```swift
#if canImport(AppKit)
import AppKit
import AVFoundation

@available(macOS 10.13, *)
final class NSSpeechTTSEngine: AppleTTSEngine {

    // MARK: - Generate Audio

    func generateAudio(text: String, voiceId: String) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                do {
                    // Validate text
                    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        throw VoiceProviderError.invalidRequest("Text cannot be empty")
                    }

                    // Create synthesizer
                    let synthesizer = NSSpeechSynthesizer()

                    // Set voice if specified
                    if let voiceName = NSSpeechSynthesizer.VoiceName(rawValue: voiceId) {
                        synthesizer.setVoice(voiceName)
                    }

                    // Create temp file for output
                    let tempURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathExtension("aiff")

                    // Create delegate to handle completion
                    let delegate = NSSpeechDelegate(onComplete: { success in
                        if success {
                            do {
                                let data = try Data(contentsOf: tempURL)
                                try? FileManager.default.removeItem(at: tempURL)
                                continuation.resume(returning: data)
                            } catch {
                                continuation.resume(throwing: VoiceProviderError.networkError("Failed to read audio: \(error)"))
                            }
                        } else {
                            continuation.resume(throwing: VoiceProviderError.networkError("Speech synthesis failed"))
                        }
                    })

                    synthesizer.delegate = delegate

                    // Start speaking to file
                    let started = synthesizer.startSpeaking(text, to: tempURL)

                    if !started {
                        throw VoiceProviderError.networkError("Failed to start speech synthesis")
                    }

                    // Keep delegate alive
                    // (stored in synthesizer's associated objects)
                    objc_setAssociatedObject(synthesizer, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)

                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Fetch Voices

    func fetchVoices() async throws -> [Voice] {
        return await MainActor.run {
            let voiceNames = NSSpeechSynthesizer.availableVoices

            return voiceNames.compactMap { voiceName -> Voice? in
                guard let attributes = NSSpeechSynthesizer.attributes(forVoice: voiceName) else {
                    return nil
                }

                let name = attributes[.name] as? String ?? voiceName.rawValue
                let locale = attributes[.localeIdentifier] as? String ?? "en_US"
                let gender = attributes[.gender] as? String

                // Parse locale
                let components = locale.components(separatedBy: "_")
                let language = components.first
                let locality = components.count > 1 ? components[1] : nil

                // Map gender
                let voiceGender: Voice.Gender?
                if let g = gender {
                    voiceGender = g.lowercased().contains("female") ? .female :
                                  g.lowercased().contains("male") ? .male : .neutral
                } else {
                    voiceGender = nil
                }

                return Voice(
                    id: voiceName.rawValue,
                    name: name,
                    description: locale,
                    providerId: "apple",
                    language: language,
                    locality: locality,
                    gender: voiceGender
                )
            }
        }
    }

    // MARK: - Estimate Duration

    func estimateDuration(text: String, voiceId: String) -> TimeInterval {
        // Rough estimation: ~14.5 characters per second (same as iOS)
        return Double(text.count) / 14.5
    }
}

// MARK: - NSSpeechSynthesizer Delegate

private class NSSpeechDelegate: NSObject, NSSpeechSynthesizerDelegate {
    let onComplete: (Bool) -> Void

    init(onComplete: @escaping (Bool) -> Void) {
        self.onComplete = onComplete
        super.init()
    }

    func speechSynthesizer(_ sender: NSSpeechSynthesizer, didFinishSpeaking finishedSpeaking: Bool) {
        onComplete(finishedSpeaking)
    }
}

#endif
```

### Phase 3: SwiftCompartido Updates

SwiftCompartido is already SwiftUI-based, so it should work on both platforms with minimal changes.

#### Step 3.1: Check Platform-Specific Code

```bash
cd ../SwiftCompartido
grep -r "UIKit\|AppKit\|#if.*os" Sources/
```

Most SwiftCompartido code should be platform-agnostic SwiftUI. Any platform-specific code needs:

```swift
#if canImport(UIKit)
import UIKit
// iOS-specific code
#elseif canImport(AppKit)
import AppKit
// macOS-specific code
#endif
```

#### Step 3.2: AudioPlayerManager

Check if `AudioPlayerManager.swift` uses any platform-specific APIs:

**If it uses AVAudioPlayer:** Should work on both platforms (AVFoundation is cross-platform)

**If it uses UIKit:** May need macOS alternatives

### Phase 4: Produciesta App Updates

#### Step 4.1: Package Dependencies

**Produciesta/Package.swift** (if using SPM) or **Xcode targets:**

```swift
// macOS target
.target(
    name: "Produciesta-macOS",
    dependencies: [
        "SwiftCompartido",
        "SwiftHablare"
    ],
    path: "Produciesta"
)

// iOS target
.target(
    name: "Produciesta-iOS",
    dependencies: [
        "SwiftCompartido",
        "SwiftHablare"
    ],
    path: "Produciesta"
)
```

#### Step 4.2: Shared SwiftUI Views

Your main views (GuionDocumentView, GuionElementsGenerateView) are SwiftUI, so they should work on both platforms!

**No changes needed** for:
- SwiftUI views
- SwiftData models
- Business logic

**May need changes** for:
- File pickers (different on macOS vs iOS)
- Platform-specific UI conventions
- Keyboard shortcuts (macOS has more)

#### Step 4.3: Platform-Specific Entry Points

**iOS: Produciesta/ProduciestaApp.swift**
```swift
#if canImport(UIKit)
import SwiftUI
import SwiftData

@main
struct ProduciestaApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [GuionDocumentModel.self, ...])
    }
}
#endif
```

**macOS: Produciesta/ProduciestaApp.swift** (same file, different target)
```swift
#if canImport(AppKit)
import SwiftUI
import SwiftData

@main
struct ProduciestaApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [GuionDocumentModel.self, ...])
        .commands {
            // macOS-specific menu commands
            CommandGroup(replacing: .newItem) {
                Button("New Script") { ... }
                    .keyboardShortcut("n", modifiers: .command)
            }
        }
    }
}
#endif
```

## Implementation Checklist

### SwiftHablare Changes

- [ ] **Step 1:** Create `AppleTTSEngine.swift` protocol
- [ ] **Step 2:** Create `AVSpeechTTSEngine.swift` (move iOS code)
- [ ] **Step 3:** Create `NSSpeechTTSEngine.swift` (new macOS code)
- [ ] **Step 4:** Update `AppleVoiceProvider.swift` to use platform engine
- [ ] **Step 5:** Remove Catalyst placeholder code (no longer needed)
- [ ] **Step 6:** Update Package.swift platforms
  ```swift
  platforms: [
      .iOS(.v16),
      .macOS(.v13)
  ]
  ```
- [ ] **Step 7:** Add macOS target to Xcode project
- [ ] **Step 8:** Test iOS TTS still works
- [ ] **Step 9:** Test macOS TTS generates real audio

### SwiftCompartido Changes

- [ ] **Step 10:** Audit for UIKit dependencies
- [ ] **Step 11:** Wrap any platform-specific code in `#if canImport()`
- [ ] **Step 12:** Update Package.swift platforms
- [ ] **Step 13:** Test SwiftUI views on both platforms

### Produciesta Changes

- [ ] **Step 14:** Update app targets (macOS + iOS)
- [ ] **Step 15:** Configure signing & capabilities
- [ ] **Step 16:** Test SwiftData on macOS
- [ ] **Step 17:** Test audio generation on macOS
- [ ] **Step 18:** Test audio playback on macOS
- [ ] **Step 19:** Add macOS-specific features (menus, shortcuts)
- [ ] **Step 20:** Update UI for macOS conventions

## Testing Strategy

### Unit Tests

```swift
#if canImport(UIKit)
func testAVSpeechEngine() async throws {
    let engine = AVSpeechTTSEngine()
    let audio = try await engine.generateAudio(text: "Hello", voiceId: "com.apple.voice.compact.en-US.Samantha")
    XCTAssertGreaterThan(audio.count, 1024)
}
#endif

#if canImport(AppKit)
func testNSSpeechEngine() async throws {
    let engine = NSSpeechTTSEngine()
    let audio = try await engine.generateAudio(text: "Hello", voiceId: "com.apple.speech.synthesis.voice.Alex")
    XCTAssertGreaterThan(audio.count, 1024)
}
#endif
```

### Integration Tests

1. **iOS:** Generate audio with Apple TTS → Should work (physical device)
2. **macOS:** Generate audio with Apple TTS → Should work (native)
3. **Both:** Generate audio with ElevenLabs → Should work
4. **Both:** Play generated audio → Should work

## Migration Path

### Current Users (If Any)

**Database compatibility:**
- SwiftData models are platform-agnostic
- Database files should work on both platforms
- Audio data (TypedDataStorage) is just Data - no platform dependency

**Audio files:**
- iOS: AIFC format
- macOS: AIFF format
- Both can be played by AVPlayer on both platforms

## Estimated Effort

- **SwiftHablare refactor:** 4-6 hours
  - Protocol + iOS extraction: 1-2 hours
  - macOS implementation: 2-3 hours
  - Testing: 1 hour

- **SwiftCompartido audit:** 1-2 hours
  - Most code should be fine (SwiftUI)
  - Any UIKit code needs wrapping

- **Produciesta setup:** 2-3 hours
  - Xcode target configuration
  - macOS app conventions
  - Testing

**Total: 7-11 hours**

## Benefits

✅ **Real TTS on macOS** - No more placeholder silence
✅ **Native platform feel** - iOS uses iOS TTS, macOS uses macOS TTS
✅ **Shared codebase** - SwiftUI views work on both
✅ **Future-proof** - Clean abstraction for adding more platforms

## Alternatives Considered

### Alternative 1: Keep Catalyst, Use ElevenLabs Only
**Pros:** No code changes needed
**Cons:** No free Apple TTS, requires API key

### Alternative 2: Use AVFAudio on macOS
**Pros:** Single API
**Cons:** AVSpeechSynthesizer.write() doesn't work on macOS

### Alternative 3: WebView with Web Speech API
**Pros:** Cross-platform
**Cons:** Requires internet, poor quality, complex

**Chosen approach (NSSpeechSynthesizer) is best** because it gives native, high-quality TTS with minimal code duplication.

---

**Next Step:** Start with Phase 1, Step 1.1 - Create the AppleTTSEngine protocol

Let me know when you're ready to begin implementation!
