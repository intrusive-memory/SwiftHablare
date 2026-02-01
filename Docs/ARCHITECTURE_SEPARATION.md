# Architecture: Hablare vs Echada Separation

## Principle: Single Responsibility

**Hablare**: Voice generation library - Given a voice ID, generate audio
**Echada**: Character/voice management - Select voices, design voices, manage cast

---

## Hablare's Scope (Voice Generation)

### Responsibilities
✅ Generate audio from text + voice ID
✅ Support multiple providers (Apple TTS, ElevenLabs)
✅ Cache generated audio (via SwiftData)
✅ Estimate audio duration
✅ Check voice availability

### NOT Hablare's Responsibility
❌ Voice design (creating new voices)
❌ Voice selection UI
❌ Collection filtering
❌ Character-to-voice mapping
❌ Voice preview playback

### API Surface
```swift
// Simple, focused API
let service = GenerationService(modelContext: context)

// Generate audio - that's it!
let result = try await service.generate(
    text: "Hello world",
    providerId: "elevenlabs",
    voiceId: "abc123",  // ← Echada provides this
    voiceName: "Jonathan"
)
```

---

## Echada's Scope (Voice Management)

### Responsibilities
✅ Character-to-voice mapping (CastMember → Voice ID)
✅ Voice design workflow (description → previews → selection → save)
✅ Voice selection UI (browse, search, filter)
✅ Collection management
✅ Voice preview playback
✅ Cast list management

### Uses SwiftOnce Directly
```swift
// Echada has direct access to SwiftOnce for voice management
let swiftOnce = SwiftOnce(apiKey: apiKey)

// 1. Design voice from character description
let response = try await swiftOnce.designVoice(
    description: "Warm, friendly female voice with slight British accent",
    previewText: characterBio
)

// 2. User previews 3 options in Echada UI
for preview in response.previews {
    // Play preview.audioData
}

// 3. User selects favorite, Echada saves it
let newVoice = try await swiftOnce.createVoice(
    from: selectedPreview,
    name: character.name,
    description: "Custom voice for \(character.name)"
)

// 4. Echada stores voice ID in CastMember
character.voices = ["elevenlabs://\(newVoice.voiceId)"]

// 5. Later, pass to Hablare for generation
let audio = try await hablareService.generate(
    text: dialogue.text,
    providerId: "elevenlabs",
    voiceId: newVoice.voiceId,
    voiceName: character.name
)
```

---

## Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│ Echada (Voice Management)                                   │
│                                                              │
│  ┌──────────────┐                                           │
│  │ Character    │                                           │
│  │ Description  │                                           │
│  └──────┬───────┘                                           │
│         │                                                    │
│         v                                                    │
│  ┌──────────────┐      ┌──────────────────────┐            │
│  │ SwiftOnce    │─────>│ Voice Design API     │            │
│  │ (Direct)     │      │ (3 previews)         │            │
│  └──────────────┘      └──────────┬───────────┘            │
│                                   │                         │
│                                   v                         │
│                        ┌──────────────────────┐            │
│                        │ User Selects Preview │            │
│                        │ in Echada UI         │            │
│                        └──────────┬───────────┘            │
│                                   │                         │
│                                   v                         │
│                        ┌──────────────────────┐            │
│                        │ Save Permanent Voice │            │
│                        │ voice_id = "xyz789"  │            │
│                        └──────────┬───────────┘            │
│                                   │                         │
│                                   v                         │
│                        ┌──────────────────────┐            │
│                        │ CastMember.voices    │            │
│                        │ = ["elevenlabs://    │            │
│                        │    xyz789"]          │            │
│                        └──────────┬───────────┘            │
│                                   │                         │
└───────────────────────────────────┼─────────────────────────┘
                                    │
                                    │ voice_id: "xyz789"
                                    │
                                    v
┌─────────────────────────────────────────────────────────────┐
│ Hablare (Voice Generation)                                  │
│                                                              │
│  ┌──────────────┐                                           │
│  │ Generation   │                                           │
│  │ Service      │                                           │
│  └──────┬───────┘                                           │
│         │                                                    │
│         v                                                    │
│  ┌──────────────┐      ┌──────────────────────┐            │
│  │ ElevenLabs   │─────>│ SwiftOnce (Internal) │            │
│  │ Provider     │      │ .speak(voiceId)      │            │
│  └──────────────┘      └──────────┬───────────┘            │
│                                   │                         │
│                                   v                         │
│                        ┌──────────────────────┐            │
│                        │ Audio Data (MP3)     │            │
│                        └──────────┬───────────┘            │
│                                   │                         │
│                                   v                         │
│                        ┌──────────────────────┐            │
│                        │ TypedDataStorage     │            │
│                        │ (SwiftData)          │            │
│                        └──────────────────────┘            │
└─────────────────────────────────────────────────────────────┘
```

---

## SwiftOnce Usage Comparison

### Echada Uses SwiftOnce Directly
```swift
import SwiftOnce

// Full access to all SwiftOnce features
let client = SwiftOnce(apiKey: apiKey)

// Voice management
let voices = try await client.voices(
    search: "female",
    category: .premade,
    collectionId: "my-collection-123"
)

// Voice design
let response = try await client.designVoice(description: "...")
let voice = try await client.createVoice(from: preview, name: "...")

// Direct generation if needed
let audio = try await client.speak("Hello", voice: voiceId)
```

### Hablare Uses SwiftOnce Internally
```swift
// Hablare wraps SwiftOnce in VoiceProvider protocol
public final class ElevenLabsVoiceProvider: VoiceProvider {
    private var swiftOnceClient: SwiftOnce?

    // Only exposes generation methods
    public func generateAudio(text: String, voiceId: String, languageCode: String) async throws -> Data {
        let client = try await client()
        return try await client.speak(text, voice: voiceId, languageCode: languageCode)
    }

    // Simplified voice listing (no design, no collections)
    public func fetchVoices(languageCode: String) async throws -> [Voice] {
        let client = try await client()
        let response = try await client.voices()
        return response.voices.map { $0.toHablareVoice() }
    }
}
```

---

## Benefits of This Separation

### For Hablare
✅ **Simple API** - Just generation, no voice management complexity
✅ **Provider Agnostic** - Apple TTS and ElevenLabs same interface
✅ **Focused Testing** - Only test generation, not voice design
✅ **Smaller Surface** - Easier to maintain and document

### For Echada
✅ **Full Control** - Direct access to all ElevenLabs features
✅ **Rich UI** - Can build sophisticated voice selection/design flows
✅ **Flexibility** - Not constrained by Hablare's abstractions
✅ **Character Context** - Can use character descriptions for voice design

### For Both
✅ **Clear Boundaries** - No confusion about responsibilities
✅ **Independent Evolution** - Can change one without affecting the other
✅ **Shared Benefits** - Both get SwiftOnce's caching, thread safety, bug fixes

---

## Migration Impact

### Before (Confused Responsibilities)
```
Hablare:
- Generate audio
- Fetch voices
- API key management
- ??? Voice design ??? (where does this belong?)
- ??? Collection filtering ??? (UI concern?)
```

### After (Clear Separation)
```
Hablare:
- Generate audio from voice ID
- List available voices (simple)
- Provider abstraction (Apple/ElevenLabs)

Echada:
- Voice design workflow
- Voice selection UI
- Collection management
- Character-to-voice mapping
- Voice preview playback
```

---

## Example: Adding a Character Voice

### Full Workflow
```swift
// 1. Echada: User creates character
let character = CastMember(name: "Jonathan", bio: "A wise mentor...")

// 2. Echada: Generate voice from description
let swiftOnce = SwiftOnce(apiKey: apiKey)
let response = try await swiftOnce.designVoice(
    description: "Deep, authoritative male voice with wisdom",
    previewText: character.bio
)

// 3. Echada: User previews 3 options
for (index, preview) in response.previews.enumerated() {
    // Echada UI plays preview.audioData
    print("Preview \(index + 1): \(preview.duration)s")
}

// 4. Echada: User selects preview #2
let selectedPreview = response.previews[1]

// 5. Echada: Save as permanent voice
let newVoice = try await swiftOnce.createVoice(
    from: selectedPreview,
    name: character.name,
    description: "Custom voice for \(character.name)"
)

// 6. Echada: Store voice ID in character
character.voices = ["elevenlabs://\(newVoice.voiceId)"]
try context.save()

// 7. Later: Hablare generates dialogue
let hablare = GenerationService(modelContext: context)
let audio = try await hablare.generate(
    text: "Welcome, young apprentice.",
    providerId: "elevenlabs",
    voiceId: newVoice.voiceId,
    voiceName: character.name
)

// 8. App plays audio
let player = AVAudioPlayer(data: audio.audioData)
player.play()
```

---

## Summary

**Hablare = Voice Generation** (library)
- Input: text + voice ID
- Output: audio data
- Uses SwiftOnce internally for ElevenLabs

**Echada = Voice Management** (app layer)
- Voice design, selection, filtering
- Character-to-voice mapping
- Uses SwiftOnce directly for full API access

**SwiftOnce = ElevenLabs API Client** (dependency)
- Used by both Hablare (wrapped) and Echada (direct)
- Provides caching, thread safety, comprehensive API coverage

This architecture keeps responsibilities clear and makes both codebases easier to maintain.
