# Voice Design Feature Requirements

## Overview
Add AI-powered voice generation from character descriptions to SwiftHablare using ElevenLabs Voice Design API.

## Use Case
```swift
// Screenplay has a character "JONATHAN - A warm, professional narrator in his 40s"
let character = CastMember(name: "Jonathan", description: "A warm, professional narrator in his 40s")

// Option 1: Character has no voice yet → Design one
let previews = try await voiceDesigner.generatePreviews(from: character.description)
// Returns 3 voice options

// User selects preview #2
let permanentVoice = try await voiceDesigner.saveVoice(
    previewId: previews[1].id,
    name: character.name
)

// Option 2: Character already has a voice_id → Use it directly
let existingVoice = character.voiceId // "abc123xyz"
let audio = try await provider.generateAudio(text: dialogue, voiceId: existingVoice)
```

---

## 🔴 KEY DESIGN QUESTIONS (Need Your Input)

### Q1: Voice Selection Logic - When to Design vs. Use Existing?

**Scenario A: Character has NO voice assigned**
- ✅ MUST design a new voice from description
- User selects from 3 previews
- Save permanent voice → update CastMember with voice_id

**Scenario B: Character HAS a voice_id stored**
- ✅ MUST use the existing voice_id directly
- Skip voice design entirely

**Scenario C: User wants to RE-design a voice**
- User explicitly requests "redesign voice for Jonathan"
- Generate new previews
- Replace old voice_id with new one

**Question for you**:
- Should we allow automatic voice design, or always ask user to select from previews?
- What if character description is too vague (e.g., "GUARD")? Fallback to default voice?

---

### Q2: Voice Storage - Where to Store the Mapping?

**Current SwiftProyecto Integration**:
```swift
// From CLAUDE.md:
CastMember {
    name: String           // "Jonathan"
    voices: [String]       // ["elevenlabs://abc123xyz"]  ← Voice URIs
}
```

**Option A: Store in SwiftProyecto's CastMember** (Recommended)
- ✅ Centralized character → voice mapping
- ✅ Already integrated with SwiftHablare
- ✅ Persists across app sessions
- Update `CastMember.voices` after designing voice

**Option B: SwiftHablare maintains its own mapping**
- Store in SwiftData/UserDefaults
- Separate from project configuration
- ❌ Duplicates storage, less integrated

**Option C: App-level storage only**
- SwiftHablare provides the design capability
- Apps handle storage themselves
- ❌ Less convenient, more boilerplate

**Question for you**:
- Should SwiftHablare update CastMember.voices automatically after designing a voice?
- Or return the voice_id and let the app update SwiftProyecto?

---

### Q3: Preview Selection - Who Chooses?

**Voice Design generates 3 previews. Who selects which one?**

**Option A: Manual Selection (UI-based)** (Recommended for apps)
- Return all 3 previews to the app
- App presents UI with audio players
- User listens and picks favorite
- App calls `saveVoice(previewId: selectedId)`

**Option B: Automatic Selection (API-based)**
- SwiftHablare automatically picks first preview
- No user interaction required
- Saves immediately
- ❌ User doesn't get to hear options

**Option C: Hybrid**
- Default to automatic (first preview)
- Optionally allow manual selection via callback

**Question for you**:
- SwiftHablare is a library, not an app. Should we provide UI components for preview selection?
- Or just return previews and let apps build their own UI?

---

### Q4: Cost & Voice Slot Management

**Voice Design Costs**:
- Generating previews: Credits based on preview text length (charged once for 3 previews)
- Saving voice: Consumes 1 permanent voice slot from account

**Your account limits** (from subscription query):
- voice_limit: 160
- voice_slots_used: 15
- professional_voice_limit: 1

**Questions**:
- Should we check available voice slots before allowing design?
- Should we warn users if they're about to consume a slot?
- What if user is at limit? Return error or fallback to existing voices?

---

### Q5: Preview Audio Storage

**Voice Design returns base64-encoded MP3 previews**

**Option A: Return audio data directly**
```swift
struct VoicePreview {
    let id: String
    let audioData: Data  // Decoded from base64
    let duration: TimeInterval
}
```

**Option B: Save previews to temp files**
```swift
struct VoicePreview {
    let id: String
    let audioURL: URL  // /tmp/voice_preview_abc123.mp3
    let duration: TimeInterval
}
```

**Option C: Return base64 string (let app decode)**
```swift
struct VoicePreview {
    let id: String
    let audioBase64: String
    let duration: TimeInterval
}
```

**Question for you**:
- Apps using SwiftHablare need to play previews. What's most convenient?
- Option A (Data) seems cleanest for AVAudioPlayer usage

---

### Q6: Character Description Format

**How do apps provide character descriptions?**

**Option A: Free-form text string** (Simplest)
```swift
designVoice(description: "A warm, professional narrator in his 40s")
```

**Option B: Structured format**
```swift
struct VoiceCharacteristics {
    var age: String?        // "middle-aged"
    var gender: String?     // "male"
    var accent: String?     // "american"
    var tone: String?       // "warm", "professional"
    var pacing: String?     // "moderate"
    var emotion: String?    // "confident"
}
```

**Option C: Extract from GuionElement** (SwiftCompartido integration)
- Parse character description from screenplay format
- "JONATHAN (40s, American) - A warm narrator"
- Auto-extract: age, gender, description

**Question for you**:
- Should SwiftHablare provide helpers to build good prompts?
- Or keep it simple with free-form text?

---

### Q7: Error Handling - When Voice Design Fails

**Potential failures**:
- No API key configured
- Invalid description (too short/empty)
- API quota exceeded
- Network errors
- Preview generation failed (rare)

**Question**:
- Should we provide fallback to voice search if design fails?
- Or just throw error and let app handle it?

---

### Q8: Integration with Existing Voice Fetching

**Current flow** (without Voice Design):
```swift
// Fetch available voices
let voices = try await provider.fetchVoices(languageCode: "en", collectionId: nil)

// Pick one manually
let selectedVoice = voices.first { $0.name.contains("Professional") }

// Generate audio
let audio = try await provider.generateAudio(text: text, voiceId: selectedVoice.id)
```

**New flow** (with Voice Design):
```swift
// Design voice from character description
let previews = try await provider.designVoice(description: "Warm male narrator")

// Select preview
let selected = previews[0]

// Save as permanent voice
let voice = try await provider.saveDesignedVoice(previewId: selected.id, name: "Jonathan")

// Generate audio
let audio = try await provider.generateAudio(text: text, voiceId: voice.id)
```

**Question**:
- Should these be separate APIs (`designVoice` vs `fetchVoices`)?
- Or unified API that handles both?

---

## Proposed API Design (Strawman)

### New Protocol: VoiceDesignable

```swift
/// Protocol for providers that support voice design from text descriptions
public protocol VoiceDesignable: VoiceProvider {
    /// Generate voice previews from a text description
    /// - Parameters:
    ///   - description: Text description of desired voice characteristics
    ///   - previewText: Optional text for preview audio (100-1000 chars)
    ///   - count: Number of previews to generate (typically 3)
    /// - Returns: Array of voice previews with audio samples
    func generateVoicePreviews(
        description: String,
        previewText: String?,
        count: Int
    ) async throws -> [VoicePreview]

    /// Save a preview as a permanent voice
    /// - Parameters:
    ///   - previewId: The generated_voice_id from a preview
    ///   - name: Custom name for the permanent voice
    ///   - description: Description for the permanent voice
    /// - Returns: Permanent Voice object with voice_id
    func saveDesignedVoice(
        previewId: String,
        name: String,
        description: String
    ) async throws -> Voice

    /// Check if voice design is available (has quota, configured, etc.)
    func canDesignVoice() async -> Bool
}
```

### New Model: VoicePreview

```swift
public struct VoicePreview: Identifiable, Sendable {
    public let id: String                    // generated_voice_id (temporary)
    public let audioData: Data               // Decoded MP3 preview
    public let duration: TimeInterval        // Preview length in seconds
    public let mediaType: String             // "audio/mpeg"

    // Optional metadata
    public var detectedLanguage: String?
}
```

### Usage Flow

```swift
// 1. Check if voice design is available
guard await provider.canDesignVoice() else {
    // Fallback to manual voice selection
}

// 2. Generate previews
let previews = try await provider.generateVoicePreviews(
    description: "A warm, professional American male narrator in his 40s",
    previewText: nil,  // Auto-generate
    count: 3
)

// 3. App presents UI for user to select (plays preview audio)
// ... user selects previews[1] ...

// 4. Save selected preview as permanent voice
let permanentVoice = try await provider.saveDesignedVoice(
    previewId: previews[1].id,
    name: "Jonathan Parker",
    description: "Warm professional narrator"
)

// 5. Update SwiftProyecto CastMember (app-level code)
character.voices = ["elevenlabs://\(permanentVoice.id)"]

// 6. Use the voice for generation
let audio = try await provider.generateAudio(
    text: dialogue,
    voiceId: permanentVoice.id,
    languageCode: "en"
)
```

---

## Questions Summary - YOUR INPUT NEEDED

Please answer these to finalize the requirements:

1. **Q1**: Should automatic voice design be allowed, or always require user preview selection?
2. **Q2**: Should SwiftHablare auto-update CastMember.voices, or return voice_id for app to handle?
3. **Q3**: Should we provide UI components for preview selection, or just return data?
4. **Q4**: Should we check/warn about voice slot limits before designing?
5. **Q5**: Audio format preference for previews: Data, URL, or base64 string?
6. **Q6**: Free-form description string, or structured VoiceCharacteristics?
7. **Q7**: Fallback to search if design fails, or just throw error?
8. **Q8**: Separate APIs for design vs. fetch, or unified?

---

## Out of Scope (For Now)

- ❌ Voice cloning from audio samples (different feature)
- ❌ Voice editing/modification after creation
- ❌ Voice deletion (should be done via ElevenLabs UI)
- ❌ Similar voice search/recommendation (future enhancement)
- ❌ UI components for preview playback (apps handle this)

---

## Next Steps

1. Answer design questions above
2. Finalize API surface
3. Update `VoiceProvider` protocol vs. new `VoiceDesignable` protocol
4. Implement `ElevenLabsVoiceProvider` voice design support
5. Add tests for voice design flow
6. Document integration with SwiftProyecto
7. Update CHANGELOG for 6.0.0 or 7.0.0

---

## References

- [ElevenLabs Voice Design API](https://elevenlabs.io/docs/api-reference/text-to-voice/design)
- [Voice Design Best Practices](https://elevenlabs.io/docs/creative-platform/voices/voice-design)
- [Voice Design v3 Features](https://elevenlabs.io/blog/voice-design-v3)
