# macOS Support - Quick Start Guide

This is a condensed version of MACOS_SUPPORT_PLAN.md for quick reference during implementation.

## The Big Picture

**Goal:** Make Apple TTS work natively on both platforms
- **iOS:** Keep using `AVSpeechSynthesizer` (already works)
- **macOS:** Add `NSSpeechSynthesizer` (new implementation)

## Architecture Change

### Before (iOS/Catalyst only)
```
AppleVoiceProvider
    → AVSpeechSynthesizer (iOS)
    → Placeholder (Catalyst) ← REMOVE THIS
```

### After (iOS + macOS)
```
AppleVoiceProvider
    ├─ iOS: AVSpeechTTSEngine → AVSpeechSynthesizer
    └─ macOS: NSSpeechTTSEngine → NSSpeechSynthesizer
```

## 3-Phase Implementation

### Phase 1: SwiftHablare - Create Platform Layer (3-4 hours)

1. **Create protocol** (`AppleTTSEngine.swift`)
   - `generateAudio(text:voiceId:) async throws -> Data`
   - `fetchVoices() async throws -> [Voice]`
   - `estimateDuration(text:voiceId:) -> TimeInterval`

2. **Extract iOS code** (`AVSpeechTTSEngine.swift`)
   - Move existing iOS implementation to new file
   - Wrap in `#if canImport(UIKit)`
   - Remove Catalyst placeholder code

3. **Implement macOS** (`NSSpeechTTSEngine.swift`)
   - Use `NSSpeechSynthesizer.startSpeaking(to: URL)`
   - Implement delegate for async/await wrapper
   - Wrap in `#if canImport(AppKit)`

4. **Update provider** (`AppleVoiceProvider.swift`)
   - Choose engine at init: `#if canImport(UIKit) ... #elseif canImport(AppKit)`
   - Delegate all calls to platform engine

### Phase 2: SwiftCompartido - Check Compatibility (1 hour)

5. **Audit platform dependencies**
   ```bash
   grep -r "UIKit\|UIApplication\|UIDevice" ../SwiftCompartido/Sources
   ```

6. **Wrap any UIKit code**
   ```swift
   #if canImport(UIKit)
   // iOS-specific
   #elseif canImport(AppKit)
   // macOS alternative
   #endif
   ```

### Phase 3: Produciesta - Configure Targets (2 hours)

7. **Update Package.swift** (if using SPM)
   ```swift
   platforms: [.iOS(.v16), .macOS(.v13)]
   ```

8. **Configure Xcode targets**
   - Add macOS target
   - Link SwiftHablare + SwiftCompartido
   - Set deployment target: macOS 13.0+

9. **Test on macOS**
   - Build for macOS
   - Generate audio with Apple TTS
   - Should get real speech!

## Key Code Snippets

### 1. AppleTTSEngine Protocol

```swift
// Sources/SwiftHablare/Providers/Apple/AppleTTSEngine.swift
protocol AppleTTSEngine {
    func generateAudio(text: String, voiceId: String) async throws -> Data
    func fetchVoices() async throws -> [Voice]
    func estimateDuration(text: String, voiceId: String) -> TimeInterval
}
```

### 2. macOS Implementation

```swift
// Sources/SwiftHablare/Providers/Apple/NSSpeechTTSEngine.swift
#if canImport(AppKit)
import AppKit
import AVFoundation

final class NSSpeechTTSEngine: AppleTTSEngine {
    func generateAudio(text: String, voiceId: String) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                let synthesizer = NSSpeechSynthesizer()

                if let voiceName = NSSpeechSynthesizer.VoiceName(rawValue: voiceId) {
                    synthesizer.setVoice(voiceName)
                }

                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("aiff")

                let delegate = NSSpeechDelegate { success in
                    if success {
                        let data = try? Data(contentsOf: tempURL)
                        try? FileManager.default.removeItem(at: tempURL)
                        if let data = data {
                            continuation.resume(returning: data)
                        } else {
                            continuation.resume(throwing: VoiceProviderError.networkError("Failed to read audio"))
                        }
                    } else {
                        continuation.resume(throwing: VoiceProviderError.networkError("Speech synthesis failed"))
                    }
                }

                synthesizer.delegate = delegate
                synthesizer.startSpeaking(text, to: tempURL)

                // Keep delegate alive
                objc_setAssociatedObject(synthesizer, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
            }
        }
    }

    func fetchVoices() async throws -> [Voice] {
        // Use NSSpeechSynthesizer.availableVoices
    }
}
#endif
```

### 3. Updated AppleVoiceProvider

```swift
// Sources/SwiftHablare/Providers/AppleVoiceProvider.swift
public final class AppleVoiceProvider: VoiceProvider {
    private let engine: AppleTTSEngine

    public init() {
        #if canImport(UIKit)
        self.engine = AVSpeechTTSEngine()
        #elseif canImport(AppKit)
        self.engine = NSSpeechTTSEngine()
        #else
        fatalError("Unsupported platform")
        #endif
    }

    public func generateAudio(text: String, voiceId: String) async throws -> Data {
        return try await engine.generateAudio(text: text, voiceId: voiceId)
    }

    public func fetchVoices() async throws -> [Voice] {
        return try await engine.fetchVoices()
    }
}
```

## Testing Checklist

After implementation:

- [ ] iOS builds successfully
- [ ] macOS builds successfully
- [ ] iOS: Generate audio with Apple TTS → Real speech
- [ ] macOS: Generate audio with Apple TTS → Real speech
- [ ] iOS: Play audio → Works
- [ ] macOS: Play audio → Works
- [ ] iOS: Voice list shows iOS voices
- [ ] macOS: Voice list shows macOS voices (different set)

## Expected Behavior

### On iOS (Physical Device)
```
Voices: Samantha, Alex, Victoria, Daniel, etc.
Audio: Real synthesized speech in AIFC format
Duration: Based on actual TTS synthesis
```

### On macOS
```
Voices: Alex, Victoria, Samantha, Fred, etc. (different from iOS!)
Audio: Real synthesized speech in AIFF format
Duration: Based on actual TTS synthesis
```

### On iOS Simulator
```
⚠️  Simulator: Generated placeholder silent audio
Note: Real TTS only works on physical devices.
```

## Common Issues

### Issue: "Cannot find type 'NSSpeechSynthesizer'"
**Fix:** Add `import AppKit` and wrap in `#if canImport(AppKit)`

### Issue: "Use of unresolved identifier 'AVSpeechSynthesizer'"
**Fix:** Code is in wrong platform block - check `#if canImport(UIKit)`

### Issue: macOS voices don't show up
**Fix:** Voice IDs are different between platforms:
- iOS: `"com.apple.voice.compact.en-US.Samantha"`
- macOS: `"com.apple.speech.synthesis.voice.samantha"`

### Issue: Audio doesn't play on macOS
**Fix:** Check AVPlayer code - should work on both platforms (AVFoundation is cross-platform)

## File Structure After Implementation

```
SwiftHablare/Sources/SwiftHablare/Providers/
├── AppleVoiceProvider.swift           (platform selector)
├── Apple/
│   ├── AppleTTSEngine.swift          (protocol)
│   ├── AVSpeechTTSEngine.swift       (iOS implementation)
│   └── NSSpeechTTSEngine.swift       (macOS implementation)
├── ElevenLabsVoiceProvider.swift     (unchanged)
└── VoiceProvider.swift                (unchanged)
```

## Time Estimates

- **Setup protocol & iOS extraction:** 1 hour
- **Implement macOS TTS:** 2 hours
- **Test & debug:** 1 hour
- **SwiftCompartido audit:** 30 min
- **Produciesta configuration:** 1 hour

**Total: ~5-6 hours**

## Next Steps

1. **Read full plan:** See `MACOS_SUPPORT_PLAN.md` for detailed implementation
2. **Start Phase 1:** Create `AppleTTSEngine.swift` protocol
3. **Test often:** Build after each major change

---

**Ready to implement?** Start with creating the protocol file!
