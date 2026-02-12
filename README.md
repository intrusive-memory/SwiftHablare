# SwiftHablare

<p align="center">
    <img src="icon.jpg" alt="SwiftHablare" width="200" />
</p>

**Simple voice generation library** - Convert text into spoken audio using Apple TTS or ElevenLabs.

## Overview

SwiftHablare is a focused Swift library that takes text and a voice ID, then generates audio. Simple API: `text + voiceId → audio`.

**Core Features:**
- **Two voice providers**: Apple Text-to-Speech (built-in) and ElevenLabs (API-based)
- **Provider registry**: Centralized provider management with configuration panels (v3.5.1)
- **Thread-safe generation**: Uses Swift actors for safe concurrency
- **Cross-platform**: iOS 26+ and macOS 26+ (full platform support)
- **Optional UI components**: SwiftUI pickers and generation buttons (v2.3.0)
- **Batch generation**: SpeakableGroup protocol for generating groups of items (v2.3.0)
- **No character mapping**: Voice selection is handled by consuming applications

**Out of Scope:**
- ❌ Character-to-voice mapping (consuming apps handle this)
- ❌ Screenplay analysis or structure parsing (consuming apps handle this)
- ❌ Automatic voice assignment (consuming apps handle this)

SwiftHablare focuses on doing one thing well: generating high-quality audio from text with a specified voice.

## What's New in v5.3.0

SwiftHablaré v5.3.0 introduces a **deterministic event-driven notification system** for audio synthesis completion.

**Architecture Improvements:**
- ⚡ **Deterministic timing** - AsyncStream-based events replace continuation-based waiting
- ⚡ **No timeouts** - Audio generation completes exactly when synthesis finishes (no arbitrary waits)
- ⚡ **Thread-safe notifications** - AsyncStream.Continuation handles cross-thread event emission
- ⚡ **Better cancellation** - Built-in support for task cancellation

**Technical Changes:**
- 🔧 **SynthesizerDelegate refactored** - Uses AsyncStream for event emission
- 🔧 **Event-driven flow** - `for await event in delegate.events` replaces manual continuation
- 🔧 **Removed timeout logic** - All timing now deterministic and event-based

**Benefits:**
- ✅ Faster completion (no wasted time waiting)
- ✅ More reliable (no timeout failures)
- ✅ Better resource usage (no polling or arbitrary sleeps)
- ✅ Cleaner architecture (reactive programming pattern)

**No Breaking Changes:**
This is an internal refactoring. Consumer code continues to work exactly the same:

```swift
// Your code (unchanged)
let result = try await service.generate(text: "Hello", providerId: "apple", voiceId: "...")
// ✅ Now uses deterministic event system internally
```

**Documentation:**
- See [Docs/NOTIFICATION_SYSTEM.md](Docs/NOTIFICATION_SYSTEM.md) for implementation guide
- See [Docs/CONCURRENCY_MODEL.md](Docs/CONCURRENCY_MODEL.md) for architecture diagrams
- See [Thread Safety & Concurrency](#asyncstream-notification-system) section below

## What's New in v4.0.0

SwiftHablaré v4.0.0 is a **performance-focused release** that significantly improves efficiency and removes deprecated code.

**Performance Improvements:**
- ⚡ **50% faster UI rendering** - Eliminated redundant FetchDescriptor creation in GenerateAudioButton
- ⚡ **Reduced memory overhead** - Removed 250+ lines of dead code

**Breaking Changes:**
- 🔴 **VoiceProviderType enum removed** (deprecated since v3.5.0)
- 🔴 **VoiceProviderInfo struct removed** (never used)
- 🔴 **VoiceProvider protocol now requires `mimeType` property**

**Improvements:**
- ✅ **Swift 6 strict concurrency compliance** - Fixed unsafe UserDefaults access in VoiceProviderRegistry
- ✅ **Centralized language code resolution** - New `LanguageCodeResolver` utility eliminates duplicate code
- ✅ **MIME type standardization** - Protocol-based MIME types replace 4 duplicate switch statements

**Migration Required:**
If you have custom VoiceProvider implementations, you must add the `mimeType` property. See the [v4.0.0 Migration Guide](#migration-from-3x-to-40) below.

**Full details:** See [CHANGELOG.md](CHANGELOG.md) for complete performance metrics and implementation details.

## Generation Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                      Your Application                            │
│                                                                   │
│  1. Select voice provider (Apple or ElevenLabs)                 │
│  2. Choose voice ID from provider's voice list                  │
│  3. Provide text to speak                                       │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             │ text + voiceId
                             ▼
                 ┌───────────────────────┐
                 │  GenerationService    │
                 │  (Actor - Thread Safe)│
                 └───────────┬───────────┘
                             │
                             │ Routes to provider
                             │
            ┌────────────────┴────────────────┐
            │                                 │
            ▼                                 ▼
  ┌─────────────────────┐         ┌─────────────────────┐
  │ AppleVoiceProvider  │         │ElevenLabsProvider   │
  │                     │         │                     │
  │ • Built-in TTS      │         │ • Neural voices     │
  │ • No API key needed │         │ • API key required  │
  │ • AIFF output       │         │ • PCM output        │
  │ • iOS/macOS         │         │ • Production quality│
  │ • Platform-agnostic │         │ • 11+ voices        │
  │ • Cross-platform    │         │ • Emotional range   │
  │                     │         │                     │
  └──────────┬──────────┘         └──────────┬──────────┘
             │                               │
             │ Audio Data (AIFF)             │ Audio Data (PCM)
             │                               │
             └───────────────┬───────────────┘
                             │
                             ▼
                 ┌───────────────────────┐
                 │   GenerationResult    │
                 │   (Sendable)          │
                 │                       │
                 │ • audioData: Data     │
                 │ • voiceId: String     │
                 │ • voiceName: String   │
                 │ • providerId: String  │
                 │ • mimeType: String    │
                 │ • requestId: UUID     │
                 └───────────┬───────────┘
                             │
                             │ Return to main thread
                             ▼
                 ┌───────────────────────┐
                 │    Main Thread        │
                 │    (@MainActor)       │
                 └───────────┬───────────┘
                             │
                             │ result.toTypedDataStorage()
                             ▼
                 ┌───────────────────────┐
                 │   TypedDataStorage    │
                 │   (SwiftData Model)   │
                 │                       │
                 │ • id: UUID            │
                 │ • providerId          │
                 │ • mimeType            │
                 │ • binaryValue: Data   │
                 │ • prompt: String      │
                 │ • voiceID: String     │
                 │ • voiceName: String   │
                 └───────────┬───────────┘
                             │
                             │ modelContext.insert()
                             ▼
                 ┌───────────────────────┐
                 │     SwiftData         │
                 │     Database          │
                 │                       │
                 │ • Persisted audio     │
                 │ • Queryable           │
                 │ • Retrievable         │
                 └───────────┬───────────┘
                             │
                             │ Fetch & use
                             ▼
                 ┌───────────────────────┐
                 │   Your Application    │
                 │                       │
                 │ • Play audio          │
                 │ • Export audio        │
                 │ • Link to content     │
                 │ • Display metadata    │
                 └───────────────────────┘
```

**Key Points:**
- **Provider Selection**: Your app chooses Apple or ElevenLabs based on needs
- **Voice Selection**: Your app selects specific voice ID from provider's available voices
- **Thread Safety**: Generation happens on background thread via actor
- **Consistent API**: Same flow regardless of provider choice
- **SwiftData Integration**: `toTypedDataStorage()` converts result to SwiftData model
- **Persistence**: Audio and metadata saved to database for later retrieval

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/intrusive-memory/SwiftHablare.git", from: "5.7.0"),
    .package(url: "https://github.com/intrusive-memory/SwiftCompartido.git", from: "6.6.0")
]
```

## Requirements

- Swift 6.0+
- iOS 26.0+ / macOS 26.0+
- SwiftCompartido 6.6.0+
- Cross-platform (iOS, macOS)

**Platform Support**: SwiftHablaré provides first-class support for iOS 26+ and macOS 26+ with platform-specific TTS engines.

## Quick Start

```swift
import SwiftHablare
import SwiftCompartido
import SwiftData

// 1. Get a screenplay element
let descriptor = FetchDescriptor<GuionElementModel>()
let elements = try modelContext.fetch(descriptor)
let element = elements.first!

// 2. Create voice provider
let provider = ElevenLabsVoiceProvider()

// 3. Create generation service
let service = GenerationService(voiceProvider: provider)

// 4. Generate audio (happens on background thread)
let result = try await service.generate(
    forElement: element,
    voiceId: "21m00Tcm4TlvDq8ikWAM",
    voiceName: "Rachel"
)

// 5. Save to SwiftData (on main thread)
await MainActor.run {
    let audioRecord = result.toTypedDataStorage()

    // Link to element
    if element.generatedContent == nil {
        element.generatedContent = []
    }
    element.generatedContent?.append(audioRecord)

    // Save
    modelContext.insert(audioRecord)
    try? modelContext.save()
}
```

## Architecture

### Core Components

```
SwiftHablare/
├── VoiceProvider.swift          # Protocol for voice providers
├── Providers/
│   ├── AppleVoiceProvider.swift # Built-in Apple TTS
│   └── ElevenLabsVoiceProvider.swift # ElevenLabs API
├── Generation/
│   └── GenerationService.swift  # Actor-based generation coordinator
├── Models/
│   └── Voice.swift              # Voice model (Sendable DTO)
└── Security/
    └── KeychainManager.swift    # API key storage
```

### Generation Flow

```
┌─────────────────┐
│ VoiceProvider   │  1. Fetch available voices
│ (init)          │     ↓
└─────────────────┘
        ↓
┌─────────────────┐
│ GenerationService│  2. Takes GuionElementModel
│ (actor)         │     ↓
└─────────────────┘  3. Generates audio (background)
        ↓
┌─────────────────┐
│ GenerationResult │  4. Sendable result
│ (Sendable)      │     ↓
└─────────────────┘  5. Main thread receives
        ↓
┌─────────────────┐
│ TypedDataStorage │  6. Save to SwiftCompartido
│ (SwiftData)     │     ↓
└─────────────────┘  7. Link to GuionElementModel
```

## Voice Providers

### Apple Voice Provider

Built-in text-to-speech for iOS 26+ and macOS 26+. No API key required.

```swift
let provider = AppleVoiceProvider()

// Check configuration
if provider.isConfigured() {
    // Fetch available voices
    let voices = try await provider.fetchVoices()

    // Generate audio
    let audioData = try await provider.generateAudio(
        text: "Hello, world!",
        voiceId: "com.apple.voice.compact.en-US.Samantha"
    )
}
```

**Features:**
- Built-in system voices with real audio output
- Automatic language filtering
- Quality detection (standard/enhanced/premium)
- Gender detection based on voice name
- Platform-agnostic through Engine Boundary Protocol

**Unified Implementation:**
- **iOS 26+**: Uses AVSpeechSynthesizer.write() (AIFC format)
- **macOS 26+**: Uses AVSpeechSynthesizer.write() (AIFC format)
- Single implementation across all platforms via AVSpeechTTSEngine

### ElevenLabs Voice Provider

High-quality neural text-to-speech via ElevenLabs API.

```swift
let provider = ElevenLabsVoiceProvider()

// Set API key (stored in keychain)
try KeychainManager.shared.saveAPIKey(apiKey, for: "elevenlabs-api-key")

// Check configuration
if provider.isConfigured() {
    // Fetch voices filtered by system language
    let voices = try await provider.fetchVoices()

    // Generate audio
    let audioData = try await provider.generateAudio(
        text: "Hello, world!",
        voiceId: "21m00Tcm4TlvDq8ikWAM"
    )
}
```

**Features:**
- Production-quality neural voices
- Language and gender metadata
- Automatic error handling
- Supports all ElevenLabs voice settings

**API Key:**
Get your API key at [elevenlabs.io](https://elevenlabs.io)

### Voice Provider Registry (v3.5.1)

SwiftHablaré includes a centralized `VoiceProviderRegistry` for managing voice providers with enablement and configuration state.

```swift
import SwiftHablare

// Access the shared registry
let registry = VoiceProviderRegistry.shared

// Get all available providers with status
let providers = await registry.availableProviders()
for provider in providers {
    print("\(provider.displayName): enabled=\(provider.isEnabled), configured=\(provider.isConfigured)")
}

// Enable/disable providers
await registry.setEnabled(true, for: "elevenlabs")

// Get a configured provider instance
if let provider = try? await registry.configuredProvider(for: "apple") {
    let voices = try await provider.fetchVoices()
}

// Register custom providers
let descriptor = VoiceProviderDescriptor(
    id: "my-provider",
    displayName: "My Provider",
    isEnabledByDefault: false,
    requiresConfiguration: true,
    makeProvider: { MyVoiceProvider() }
)
await registry.register(descriptor)
```

**Key Features:**
- **Automatic Registration**: Built-in providers (Apple, ElevenLabs) auto-register on startup
- **Enablement State**: User-controlled on/off state persisted in UserDefaults
- **Configuration Validation**: Ensures providers are properly configured before use
- **SwiftUI Configuration Panels**: Each provider supplies a configuration view for credentials
- **External Provider Support**: Third-party packages can register custom providers

**For Custom Providers:**

```swift
// Option 1: Direct registration
class MyVoiceProvider: VoiceProvider {
    // ... implementation
}

let service = GenerationService()
await service.registerProvider(MyVoiceProvider())

// Option 2: Using VoiceProviderAutoRegistrar (requires manual registration)
class MyProviderRegistrar: VoiceProviderAutoRegistrar {
    override class var descriptors: [VoiceProviderDescriptor] {
        [
            VoiceProviderDescriptor(
                id: "my-provider",
                displayName: "My Provider",
                isEnabledByDefault: false,
                requiresConfiguration: true,
                makeProvider: { MyVoiceProvider() }
            )
        ]
    }
}

// In your app initialization:
await MyProviderRegistrar.registerProviders(into: .shared)
```

**Note**: Swift does not support Objective-C's `+load` method for automatic registration. External packages must call `registerProviders(into:)` during app initialization to make their providers available.

## Voice URIs for Cast Management

SwiftHablaré uses simple URI strings for character-to-voice mappings, managed by [SwiftProyecto](https://github.com/intrusive-memory/SwiftProyecto)'s `CastMember` model.

### Voice URI Format

**Format**: `<provider>://<voice_id>`

Voice URIs are plain strings with no special parsing required:

```swift
// Examples from SwiftProyecto CastMember
let voiceURIs = [
    "apple://com.apple.voice.premium.en-US.Aaron",
    "elevenlabs://en/wise-elder"
]
```

**Provider Prefixes:**
- `apple://` - Apple TTS voices (format: `apple://com.apple.voice.{quality}.{locale}.{name}`)
- `elevenlabs://` - ElevenLabs API voices (format: `elevenlabs://<language>/<voiceId>`)

### Character-to-Voice Mapping with SwiftProyecto

Use SwiftProyecto's `CastMember` for screenplay character voice assignments:

```swift
import SwiftProyecto

// Define cast with voice URIs
let cast = [
    CastMember(
        character: "GANDALF",
        actor: "Ian McKellen",
        voices: [
            "apple://com.apple.voice.premium.en-US.Aaron",  // Try Apple voice first
            "elevenlabs://en/wise-elder"                     // Fallback to ElevenLabs
        ]
    ),
    CastMember(
        character: "FRODO",
        actor: "Elijah Wood",
        voices: ["apple://com.apple.voice.enhanced.en-US.Samantha"]
    )
]

// Filter voices by provider
let gandalfAppleVoices = cast[0].filterVoices(provider: "apple")
// Returns: ["apple://com.apple.voice.premium.en-US.Aaron"]

let gandalfElevenLabsVoices = cast[0].filterVoices(provider: "elevenlabs")
// Returns: ["elevenlabs://en/wise-elder"]
```

### Using Cast Members with SwiftHablaré

```swift
import SwiftHablare
import SwiftProyecto
import SwiftData

@MainActor
func generateDialogueWithCast(cast: [CastMember]) async throws {
    let service = GenerationService(modelContext: modelContext)

    // Find cast member by character name
    guard let gandalf = cast.first(where: { $0.character == "GANDALF" }) else {
        throw VoiceError.characterNotFound
    }

    // Get first available voice URI (primary voice)
    guard let voiceURI = gandalf.primaryVoice else {
        throw VoiceError.noVoiceAssigned
    }

    // Parse the URI to extract provider and voice ID
    // Format: "provider://voice_id"
    let components = voiceURI.split(separator: "://", maxSplits: 1)
    guard components.count == 2 else {
        throw VoiceError.invalidURIFormat
    }

    let provider = String(components[0])
    let voiceId = String(components[1])

    // Generate audio
    let result = try await service.generate(
        text: "You shall not pass!",
        providerId: provider,
        voiceId: voiceId,
        languageCode: "en"
    )

    // Save to SwiftData
    let storage = result.toTypedDataStorage()
    modelContext.insert(storage)
    try modelContext.save()
}
```

**See [SwiftProyecto documentation](https://github.com/intrusive-memory/SwiftProyecto) for complete CastMember API and PROJECT.md cast list format.**

## UI Components (v2.3.0)

SwiftHablaré provides optional SwiftUI components for voice selection and audio generation:

### ProviderPickerView & VoicePickerView

Simple pickers for selecting voice providers and voices:

```swift
import SwiftUI
import SwiftHablare

struct VoiceSelectionView: View {
    let service = GenerationService(modelContext: modelContext)

    @State private var selectedProviderId: String?
    @State private var selectedVoiceId: String?

    var body: some View {
        Form {
            ProviderPickerView(
                service: service,
                selection: $selectedProviderId
            )

            if let providerId = selectedProviderId {
                VoicePickerView(
                    service: service,
                    providerId: providerId,
                    selection: $selectedVoiceId
                )
            }
        }
    }
}
```

### GenerateAudioButton

Individual element audio generation with progress tracking:

```swift
import SwiftUI
import SwiftHablare

struct ElementRow: View {
    let item: any SpeakableItem
    let service: GenerationService
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        HStack {
            Text(item.textToSpeak)
            Spacer()

            GenerateAudioButton(
                item: item,
                service: service,
                modelContext: modelContext,
                onPlay: { record in
                    // Handle play action
                    print("Play audio: \(record.id)")
                }
            )
        }
    }
}
```

**Features:**
- Automatically checks for existing audio
- Shows "Generate" or "Play" based on audio availability
- Progress bar and cancellation support
- Race condition safe

### GenerateGroupButton & SpeakableGroup Protocol

Batch generation for groups of speakable items:

```swift
import SwiftUI
import SwiftHablare

// Define a speakable group
struct Chapter: SpeakableGroup {
    let number: Int
    let title: String
    let dialogueLines: [DialogueLine]
    let provider: VoiceProvider

    var groupName: String {
        "Chapter \(number): \(title)"
    }

    var groupDescription: String? {
        "\(dialogueLines.count) dialogue lines"
    }

    func getGroupedElements() -> [any SpeakableItem] {
        return dialogueLines.map { line in
            CharacterDialogue(
                characterName: line.characterName,
                dialogue: line.text,
                voiceProvider: provider,
                voiceId: line.voiceId,
                includeCharacterName: true
            )
        }
    }
}

// Use with GenerateGroupButton
struct ChapterView: View {
    let chapter: Chapter
    let service: GenerationService
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack {
            Text(chapter.groupName)
                .font(.headline)

            GenerateGroupButton(
                group: chapter,
                service: service,
                modelContext: modelContext,
                onComplete: { records in
                    print("Generated \(records.count) audio files")
                }
            )
        }
    }
}
```

**Features:**
- Shows "Generate All (N items)" or "Regenerate All (N items)"
- Progress tracking as "X/Y items (Z%)"
- Skips items with existing audio by default
- Cancellation support with partial results
- Recursive group expansion

**Example Groups:**
- Chapter (books with dialogue)
- Scene (theatrical scripts)
- MessagePlaylist (notifications with priority)
- ArticleSections (long-form content)
- ShoppingList (enumerated tasks)

See `Sources/SwiftHablare/Examples/SpeakableGroupExamples.swift` for complete implementations.

### Markdown & Screenplay Support

SwiftHablaré provides SpeakableItem implementations for markdown and screenplay elements from SwiftCompartido.

**What's SwiftCompartido?**
SwiftCompartido parses markdown and Fountain screenplay files into a unified `GuionElement` model. SwiftHablaré adds voice generation support for these elements.

#### Supported Element Types

SwiftHablaré can generate audio for all markdown and screenplay elements:

| Element Type | Description | Voice Type |
|-------------|-------------|------------|
| **Action** | Narrative description, paragraphs, lists | Narrator |
| **Dialogue** | Character speech | Character |
| **Character** | Character name announcements | Narrator |
| **Scene Heading** | Location sluglines (INT. COFFEE SHOP - DAY) | Narrator |
| **Section Heading** | Markdown headings (# through ######) | Narrator |
| **Parenthetical** | Stage directions | Narrator |
| **Transition** | Scene transitions (CUT TO:, FADE OUT) | Narrator |
| **Synopsis** | Scene summaries | Narrator |
| **Lyrics** | Song lyrics | Character |

#### Basic Usage

```swift
import SwiftHablare
import SwiftCompartido

// Parse markdown file
let markdownURL = URL(fileURLWithPath: "article.md")
let parsed = try GuionParsedElementCollection(file: markdownURL)
let elements = parsed.elements

// Create speakable items
let provider = AppleVoiceProvider()
let voices = try await provider.fetchVoices()
let voiceId = voices.first!.id

let speakableElements = elements.map { element in
    GuionElementSpeakable(
        element: element,
        voiceProvider: provider,
        voiceId: voiceId
    )
}

// Generate audio for each element
for speakable in speakableElements {
    let audioData = try await speakable.speak()
    // Save to TypedDataStorage...
}
```

#### Dialogue Pairs

For screenplay dialogue (character + dialogue pairs):

```swift
// Extract character-dialogue pairs
var pairs: [DialoguePairSpeakable] = []
for i in 0..<elements.count - 1 {
    if case .character = elements[i].elementType,
       case .dialogue = elements[i + 1].elementType {
        let pair = DialoguePairSpeakable(
            character: elements[i],
            dialogue: elements[i + 1],
            voiceProvider: provider,
            voiceId: getVoiceForCharacter(elements[i].elementText),
            includeCharacterName: false  // Just speak the dialogue
        )
        pairs.append(pair)
    }
}
```

#### Section Headings

Announce markdown headings with level context:

```swift
let heading = GuionElement(
    elementType: .sectionHeading(level: 2),
    elementText: "Act One"
)

let speakable = SectionHeadingSpeakable(
    heading: heading,
    voiceProvider: provider,
    voiceId: narratorVoiceId,
    announceLevel: true  // Speaks: "Act: Act One"
)
```

#### Batch Generation by Scene

Group screenplay elements by scene:

```swift
let scene = SceneSpeakable(
    sceneHeading: sceneHeadingElement,
    elements: sceneElements,
    voiceMapping: { element in
        // Map different elements to different voices
        switch element.elementType {
        case .dialogue:
            return characterVoiceId
        default:
            return narratorVoiceId
        }
    },
    voiceProvider: provider
)

// Generate all scene audio
let service = GenerationService(modelContext: modelContext)
let records = try await service.generateList(
    SpeakableItemList(name: scene.groupName, items: scene.getGroupedElements()),
    to: modelContext
)
```

#### Batch Generation by Chapter

Group screenplay elements by chapter (Act level):

```swift
let chapter = ChapterSpeakable(
    chapterHeading: chapterHeadingElement,  // Level 2 heading (##)
    elements: chapterElements,
    voiceMapping: { element in
        // Return appropriate voiceId for element type
        getVoiceId(for: element)
    },
    voiceProvider: provider
)

print(chapter.groupDescription)
// "25 elements (3 scenes, 12 dialogue lines)"
```

#### Complete Markdown Document

Generate audio for an entire markdown file:

```swift
let document = MarkdownDocumentSpeakable(
    filename: "article.md",
    elements: parsed.elements,
    voiceProvider: provider,
    defaultVoiceId: narratorVoiceId
)

// Generate all audio with progress tracking
let list = SpeakableItemList(
    name: document.filename,
    items: document.getGroupedElements()
)

let records = try await service.generateList(list, to: modelContext)
print("Generated \(records.count) audio files")
```

#### Helper Extensions

SwiftHablaré adds useful extensions to `GuionElement`:

```swift
// Check if element has speakable content
if element.isSpeakable {
    // Element has non-empty text
}

// Get recommended voice type
switch element.recommendedVoiceType {
case .character:
    // Use character voice
case .narrator:
    // Use narrator voice
}
```

#### Available Implementations

SwiftHablaré provides these ready-to-use implementations in `Sources/SwiftHablare/Examples/GuionElementSpeakableExamples.swift`:

1. **GuionElementSpeakable** - General adapter for any GuionElement
2. **DialoguePairSpeakable** - Character-dialogue pairs
3. **SectionHeadingSpeakable** - Markdown headings with level announcements
4. **SceneSpeakable** - Scene grouping for batch generation
5. **ChapterSpeakable** - Chapter grouping for batch generation
6. **MarkdownDocumentSpeakable** - Complete document batch generation

#### Markdown Element Mapping

CommonMarkParser in SwiftCompartido converts markdown to GuionElements:

| Markdown | → | GuionElement Type |
|----------|---|-------------------|
| `# Heading` | → | `.sectionHeading(level: 1)` |
| `## Heading` | → | `.sectionHeading(level: 2)` |
| Paragraphs | → | `.action` |
| Block quotes | → | `.action` (with `>` prefix) |
| Lists | → | `.action` (with `•` or numbers) |
| Code blocks | → | `.action` (indented) |
| `---` | → | `.pageBreak` |

See the [SwiftCompartido documentation](https://github.com/intrusive-memory/SwiftCompartido) for more details on screenplay parsing.

## Thread Safety & Concurrency

SwiftHablare follows Swift 6 strict concurrency:

### Generation Service (Actor)

```swift
public actor GenerationService {
    // All methods are actor-isolated
    // Automatically runs on background thread
    // No data races possible

    func generate(...) async throws -> GenerationResult
    func fetchVoices() async throws -> [Voice]
}
```

### Sendable Results

```swift
public struct GenerationResult: Sendable {
    // All properties are Sendable
    // Can be safely transferred between threads
    public let audioData: Data
    public let voiceId: String
    // ...
}
```

### Main Thread Saves

```swift
// Generation happens off main thread
let result = try await service.generate(forElement: element, ...)

// SwiftData saves MUST happen on main thread
await MainActor.run {
    let record = result.toTypedDataStorage()
    modelContext.insert(record)
    try? modelContext.save()
}
```

### AsyncStream Notification System

SwiftHablare v5.3+ uses an **event-driven notification system** for audio synthesis completion. This architecture provides deterministic, timeout-free synthesis handling.

**Key Benefits:**
- ✅ **No Timeouts** - Events fire exactly when synthesis completes (no arbitrary waits)
- ✅ **Deterministic** - All timing controlled by AVSpeechSynthesizer callbacks
- ✅ **Thread-Safe** - AsyncStream handles cross-thread event emission automatically
- ✅ **Cancellable** - Built-in support for task cancellation

**How It Works:**

The system uses Swift's `AsyncStream` to emit events when audio synthesis completes:

```swift
// Internal implementation (AVSpeechTTSEngine)
private enum SynthesisEvent: Sendable {
    case finished   // Synthesis completed successfully
    case cancelled  // Synthesis was cancelled
}

private final class SynthesizerDelegate: NSObject, AVSpeechSynthesizerDelegate {
    let events: AsyncStream<SynthesisEvent>
    private var eventContinuation: AsyncStream<SynthesisEvent>.Continuation?

    // Emit events when AVSpeechSynthesizer completes
    nonisolated func speechSynthesizer(_:didFinish:) {
        eventContinuation?.yield(.finished)
        eventContinuation?.finish()
    }
}

// Subscriber waits deterministically for completion
for await event in delegate.events {
    switch event {
    case .finished, .cancelled:
        // Process results - no timeout needed!
        return (audioData, duration)
    }
}
```

**Why This Matters:**

Traditional approaches use timeouts or polling:
```swift
// ❌ OLD: Arbitrary timeout
try await Task.sleep(nanoseconds: 5_000_000_000)  // Wait 5 seconds
// Problem: Wastes time if synthesis finishes early, fails if takes longer

// ✅ NEW: Event-driven
for await event in delegate.events {
    // Completes immediately when ready, no wasted time
}
```

**Consumer Impact:**

As a SwiftHablare consumer, you don't need to change anything! The notification system is internal to the library. Your code continues to work exactly the same:

```swift
// Your code (unchanged)
let result = try await service.generate(
    text: "Hello, world!",
    providerId: "apple",
    voiceId: "voice-id"
)
// ✅ This now completes deterministically without timeouts
```

**Technical Details:**

See [Docs/NOTIFICATION_SYSTEM.md](Docs/NOTIFICATION_SYSTEM.md) for implementation details and [Docs/CONCURRENCY_MODEL.md](Docs/CONCURRENCY_MODEL.md) for architecture diagrams.

## TypedDataStorage Integration

Generated audio is saved using `TypedDataStorage` from SwiftCompartido:

```swift
// Automatic conversion from GenerationResult
let audioRecord = result.toTypedDataStorage()

// Properties set automatically:
// - id: Request UUID
// - providerId: "apple" or "elevenlabs"
// - requestorID: "{providerId}.audio.tts"
// - mimeType: "audio/mpeg" or "audio/wav"
// - binaryValue: Audio data
// - prompt: Original text
// - durationSeconds: Estimated duration
// - voiceID, voiceName: Voice metadata

// Link to element
element.generatedContent?.append(audioRecord)
modelContext.insert(audioRecord)
try modelContext.save()
```

### File-Based Storage

For large audio files, use file-based storage:

```swift
import SwiftCompartido

let requestID = UUID()
let storage = StorageAreaReference.temporary(requestID: requestID)

let result = try await service.generate(forElement: element, ...)

await MainActor.run {
    let audioRecord = result.toTypedDataStorage()

    // Save to file (instead of in-memory)
    try? audioRecord.saveBinary(
        result.audioData,
        to: storage,
        fileName: "audio.mp3"
    )

    element.generatedContent?.append(audioRecord)
    modelContext.insert(audioRecord)
    try? modelContext.save()
}
```

## Advanced Usage

### Batch Generation

```swift
@MainActor
func generateAudioForElements(_ elements: [GuionElementModel]) async throws {
    let service = GenerationService(voiceProvider: ElevenLabsVoiceProvider())

    for element in elements {
        do {
            let result = try await service.generate(
                forElement: element,
                voiceId: "21m00Tcm4TlvDq8ikWAM",
                voiceName: "Rachel"
            )

            let audioRecord = result.toTypedDataStorage()
            element.generatedContent?.append(audioRecord)
            modelContext.insert(audioRecord)

            // Save every 10 elements
            if elements.firstIndex(of: element)! % 10 == 0 {
                try modelContext.save()
            }
        } catch {
            print("Failed to generate audio for element: \(error)")
        }
    }

    // Final save
    try modelContext.save()
}
```

### Progress Tracking

```swift
@MainActor
func generateWithProgress(_ elements: [GuionElementModel]) async throws {
    let service = GenerationService(voiceProvider: ElevenLabsVoiceProvider())

    for (index, element) in elements.enumerated() {
        let progress = Double(index) / Double(elements.count)
        updateProgressBar(progress)

        let result = try await service.generate(forElement: element, ...)
        let audioRecord = result.toTypedDataStorage()

        element.generatedContent?.append(audioRecord)
        modelContext.insert(audioRecord)
    }

    try modelContext.save()
}
```

### Custom Voice Selection

```swift
// Fetch voices and let user select
let voices = try await service.fetchVoices()

// Filter by gender
let femaleVoices = voices.filter { $0.gender == "female" }

// Filter by language
let englishVoices = voices.filter { $0.language == "en" }

// Generate with selected voice
let selectedVoice = englishVoices.first!
let result = try await service.generate(
    forElement: element,
    voiceId: selectedVoice.id,
    voiceName: selectedVoice.name
)
```

## Error Handling

```swift
do {
    let result = try await service.generate(forElement: element, ...)
    // Success
} catch VoiceProviderError.notConfigured {
    // Provider not configured (missing API key)
    promptForAPIKey()
} catch VoiceProviderError.networkError(let message) {
    // Network error (API down, rate limit, etc.)
    showError("Network error: \(message)")
} catch VoiceProviderError.invalidResponse {
    // Invalid response from provider
    showError("Invalid response from provider")
} catch {
    // Other errors
    showError("Generation failed: \(error)")
}
```

## Testing

SwiftHablaré has a comprehensive test suite with 390+ passing tests and 96%+ coverage.

### Test Organization

Tests are organized into two categories for optimal CI performance:

**Fast Tests (Unit Tests):**
- ✅ Run on every pull request
- ✅ Run on push to main/master
- ⚡ Complete in ~30 seconds
- 📱 Run on **macOS** (primary platform)
- 📁 All test files except those with "Integration" in the name
- Examples:
  - `AppleVoiceProviderTests.swift`
  - `GenerationServiceTests.swift`
  - `SpeakableItemTests.swift`
  - `VoiceModelTests.swift`

**Integration Tests (Long-Running):**
- 🗓️ Run weekly on Saturdays at 3 AM UTC
- 🧪 Real API calls to voice providers
- ⏱️ Complete in ~2-5 minutes
- 💻 Run on **macOS** and **iOS Simulator**
- 📁 Tests with "Integration" in the class name
- Examples:
  - `AppleVoiceProviderIntegrationTests.swift`
  - `ElevenLabsVoiceProviderIntegrationTests.swift`

**Platform Support:**
- ✅ iOS 26+ (tested on iOS Simulator and physical devices)
- ✅ macOS 26+ (tested natively on macOS)

### Running Tests Locally

**Quick test (recommended - runs on macOS):**
```bash
swift test --enable-code-coverage
```

**Run all tests on specific platform:**
```bash
# macOS (native)
xcodebuild test \
  -scheme SwiftHablare \
  -destination 'platform=macOS'

# iOS Simulator
xcodebuild test \
  -scheme SwiftHablare \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

**Run only fast tests (skip integration):**
```bash
xcodebuild test \
  -scheme SwiftHablare \
  -destination 'platform=macOS' \
  -skip-testing:SwiftHablareTests/AppleVoiceProviderIntegrationTests \
  -skip-testing:SwiftHablareTests/ElevenLabsVoiceProviderIntegrationTests
```

**Run only integration tests:**
```bash
xcodebuild test \
  -scheme SwiftHablare \
  -destination 'platform=macOS' \
  -only-testing:SwiftHablareTests/AppleVoiceProviderIntegrationTests \
  -only-testing:SwiftHablareTests/ElevenLabsVoiceProviderIntegrationTests
```

**With code coverage:**
```bash
swift test --enable-code-coverage
```

### Pre-Commit Hooks

SwiftHablaré includes a pre-commit hook that validates local audio generation before commits:

**Install the hooks:**
```bash
./.githooks/install.sh
```

**What it does:**
- Runs 3 audio hardware tests (~5-10 seconds)
- Validates 16-bit PCM audio format generation
- Tests AVAudioPlayer compatibility
- Verifies accurate duration calculation
- Automatically skips on CI or non-macOS systems

**Bypass (not recommended):**
```bash
git commit --no-verify
```

See `.githooks/README.md` for complete documentation.

### CI/CD Workflows

SwiftHablaré uses GitHub Actions with three workflows running on macOS runners.

1. **`fast-tests.yml`** - Runs on every PR
   - ✅ Executes unit tests on macOS
   - ⚡ Provides fast feedback for pull requests (~30s)
   - ⏭️ Skips integration tests to keep PRs responsive
   - 💻 Runs natively on macOS runners

2. **`integration-tests.yml`** - Runs weekly
   - 🗓️ Saturday at 3 AM UTC (middle of the night for US timezones)
   - 🧪 Executes integration tests with real API calls
   - ⏱️ Long-running tests (~2-5 minutes)
   - 🎮 Can be triggered manually via workflow_dispatch
   - 💻 Runs on macOS runners

3. **`tests-full.yml`** - Manual only
   - 📋 Full test suite (unit + integration)
   - 🔧 Useful for comprehensive testing before releases
   - 🎮 Triggered manually when needed
   - 💻 Runs on macOS runners

### Writing Tests

Example unit test:

```swift
import XCTest
@testable import SwiftHablare

final class MyTests: XCTestCase {
    func testVoiceGeneration() async throws {
        let provider = AppleVoiceProvider()
        let voices = try await provider.fetchVoices()

        let audioData = try await provider.generateAudio(
            text: "Hello, world!",
            voiceId: voices.first!.id
        )

        XCTAssertGreaterThan(audioData.count, 1024)
    }
}
```

Example integration test (long-running):

```swift
import XCTest
@testable import SwiftHablare

// Note: "Integration" in the class name marks this as a long-running test
final class MyProviderIntegrationTests: XCTestCase {
    func testRealAPICall() async throws {
        #if targetEnvironment(simulator)
        // Skip on iOS simulator if needed
        throw XCTSkip("Integration test requires physical device or macOS")
        #endif

        // This test will be skipped in PR checks
        // and only run on the weekly schedule
        let provider = ElevenLabsVoiceProvider()
        let voices = try await provider.fetchVoices()

        // Real API calls...
    }
}
```

## Dependencies

- **SwiftCompartido** (required): Provides `GuionElementModel` and `TypedDataStorage`
- **SwiftData** (system): For `TypedDataStorage` persistence
- **AVFoundation** (system): For Apple TTS provider
- **Foundation** (system): Core Swift types

## Migration from 3.x to 4.0

SwiftHablaré 4.0.0 is a **performance-focused release** with breaking changes for custom VoiceProvider implementations.

### Breaking Changes

#### 1. VoiceProvider Protocol Requires `mimeType`

**What Changed:**
The `VoiceProvider` protocol now requires a `mimeType` property. This eliminates duplicate MIME type logic across the codebase.

**Before (3.x):**
```swift
public final class MyVoiceProvider: VoiceProvider {
    public let providerId = "my-provider"
    public let displayName = "My Provider"
    public let requiresAPIKey = true

    // No mimeType property needed
}
```

**After (4.0):**
```swift
public final class MyVoiceProvider: VoiceProvider {
    public let providerId = "my-provider"
    public let displayName = "My Provider"
    public let requiresAPIKey = true
    public let mimeType = "audio/mpeg"  // ADD THIS

    // Return appropriate MIME type for your audio format:
    // - "audio/mpeg" for MP3
    // - "audio/x-aiff" for AIFF
    // - "audio/wav" for WAV
    // - "audio/ogg" for OGG
    // - "audio/pcm" for raw PCM
}
```

**Migration Steps:**
1. Add `public let mimeType = "..."` to your VoiceProvider implementation
2. Choose the appropriate MIME type for your audio output format
3. Update any tests that reference your provider

#### 2. VoiceProviderType Enum Removed

**What Changed:**
The deprecated `VoiceProviderType` enum has been removed. Use provider IDs (strings) instead.

**Before (3.x):**
```swift
// DEPRECATED - do not use
let providerType = VoiceProviderType.apple
```

**After (4.0):**
```swift
// Use provider ID strings directly
let providerId = "apple"
```

**Migration Steps:**
1. Replace all `VoiceProviderType` references with string provider IDs
2. Use `provider.providerId` instead of enum cases

#### 3. VoiceProviderInfo Struct Removed

**What Changed:**
The unused `VoiceProviderInfo` struct has been removed. This struct was never used in the public API.

**Migration Steps:**
No action required - this struct was never part of the public API.

### Performance Improvements (No Migration Needed)

These improvements are automatic and require no code changes:

- ⚡ **50% faster UI rendering** - Optimized FetchDescriptor creation
- ⚡ **Swift 6 compliance** - Fixed concurrency violations

### New Features

#### LanguageCodeResolver Utility

A new centralized utility for language code resolution:

```swift
import SwiftHablare

// Get system language code
let systemLang = LanguageCodeResolver.systemLanguageCode  // "en", "es", etc.

// Resolve with fallback
let resolved = LanguageCodeResolver.resolve(nil)  // Returns system language
let explicit = LanguageCodeResolver.resolve("es")  // Returns "es"
```

### Testing Your Migration

After updating your custom VoiceProvider:

1. **Build your project** - Ensure no compilation errors
2. **Run tests** - Verify all tests pass
3. **Check MIME types** - Ensure audio files have correct MIME type metadata
4. **Test voice generation** - Generate sample audio and verify format

### Full Changelog

See [CHANGELOG.md](CHANGELOG.md) for complete details on all changes, performance metrics, and implementation notes.

## Migration from 2.x

SwiftHablare 3.0 is a complete rewrite. Key changes:

### Removed
- All text generation (OpenAI, Anthropic)
- All image generation
- All video generation
- All UI components (AudioPlayerManager, widgets, etc.)
- All SwiftData models

### Added
- GenerationService actor for safe concurrency
- Direct TypedDataStorage integration

### Migration Guide

**Before (2.x):**
```swift
// Old: Complex task-based system
let task = AudioGenerationTask(
    elements: elements,
    voiceProvider: provider,
    voiceId: voiceId,
    modelContext: modelContext
)
try await task.execute()
```

**After (3.0):**
```swift
// New: Simple service-based system
let service = GenerationService(voiceProvider: provider)
let result = try await service.generate(forElement: element, voiceId: voiceId)
let audioRecord = result.toTypedDataStorage()
modelContext.insert(audioRecord)
```

## Development Workflow

This project follows a **strict branch-based workflow**. All development happens on the `development` branch, with PRs to `main` for releases.

### Quick Start for Contributors

1. **Fork and clone** the repository
2. **Switch to development branch**: `git checkout development`
3. **Make your changes** on the `development` branch
4. **Run tests**: `swift test`
5. **Create a PR** to `main` when ready
6. **Wait for CI** to pass before merging

### Detailed Workflow

See [`.claude/WORKFLOW.md`](.claude/WORKFLOW.md) for complete details on:
- Branch strategy (`development` → `main`)
- Commit message conventions (conventional commits)
- PR creation and merging process
- Tagging and release procedures
- Version numbering (semantic versioning)

### Key Rules

- ✅ **Always work on `development` branch**
- ✅ **Never commit directly to `main`**
- ✅ **All changes require PR approval from CI**
- ✅ **Never delete the `development` branch**

## License

MIT License - see LICENSE file for details.

## Contributing

Contributions welcome! Please see CONTRIBUTING.md for guidelines on the development workflow and coding standards.

## Support

- **Issues**: [GitHub Issues](https://github.com/intrusive-memory/SwiftHablare/issues)
- **Discussions**: [GitHub Discussions](https://github.com/intrusive-memory/SwiftHablare/discussions)

