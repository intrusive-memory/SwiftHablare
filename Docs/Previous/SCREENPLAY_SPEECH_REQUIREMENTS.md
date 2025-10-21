# Screenplay Speech Synthesis Requirements

## Overview

This document outlines requirements for a screenplay-to-speech system that transforms parsed SwiftGuion screenplay elements into speakable audio content using SwiftHablare's text-to-speech capabilities.

### Goals

1. **Transform screenplay elements into audio-ready content** - Convert SwiftGuion parsed elements into "Speakable Items" that understand what should and shouldn't be spoken
2. **Implement configurable speech logic** - Define clear, changeable rules for each screenplay element type
3. **Support iterative refinement** - Design the system to accommodate frequent logic changes as requirements evolve
4. **Maintain screenplay context** - Track scene-level state (e.g., which characters have already spoken)

---

## System Architecture

### Core Components

```
┌─────────────────────────────────────────────────────────────┐
│                    SwiftGuion (Input)                       │
│              Parsed Screenplay SwiftData Models             │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              ScreenplayToSpeechProcessor                    │
│  - Queries SwiftData ModelContext                           │
│  - Applies SpeechLogicRules                                 │
│  - Generates ordered SpeakableItem list                     │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                  SpeakableItem Collection                   │
│  - Ordered list of audio segments                           │
│  - Each item knows its text content and context             │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              SwiftHablare (Output)                          │
│         Text-to-Speech Generation & Audio Files             │
└─────────────────────────────────────────────────────────────┘
```

---

## Core Classes and Protocols

### 1. ScreenplayToSpeechProcessor

**Purpose**: Main class that orchestrates the transformation from screenplay elements to speakable items.

**Responsibilities**:
- Accept a SwiftData ModelContext containing SwiftGuion models
- Query and order screenplay elements (scenes, actions, dialogue, etc.)
- Apply speech logic rules to each element
- Maintain scene-level state (e.g., character first-appearance tracking)
- Generate final ordered list of SpeakableItems

**API Design**:
```swift
@MainActor
class ScreenplayToSpeechProcessor {
    let modelContext: ModelContext
    let logicRulesProvider: SpeechLogicRulesProvider

    init(modelContext: ModelContext,
         logicRulesProvider: SpeechLogicRulesProvider = DefaultSpeechLogicRules())

    /// Process entire screenplay
    func generateSpeakableItems() async throws -> [SpeakableItem]

    /// Process specific scene
    func generateSpeakableItems(forScene sceneID: UUID) async throws -> [SpeakableItem]

    /// Process range of scenes
    func generateSpeakableItems(fromScene: UUID, toScene: UUID) async throws -> [SpeakableItem]
}
```

### 2. SpeakableItem

**📋 For complete model design, see [SPEAKABLE_ITEM_MODEL_DESIGN.md](SPEAKABLE_ITEM_MODEL_DESIGN.md)**

**Purpose**: Represents a single atomic unit of speech output with its text content and metadata. **SwiftData @Model** for persistence.

**Key Design Decisions**:
- ✅ **SwiftData @Model** (not transient struct) - persistent, queryable, cached
- ✅ **Points to source GuionElementModel** - via sourceElementID
- ✅ **Stores filtered/transformed text** - speakableText after applying speech rules
- ✅ **Links to Hablare audio** - via SpeakableAudio relationship (supports multiple versions)
- ✅ **Tracks rule version** - for regeneration when rules change
- ✅ **Processing status** - textGenerated → audioQueued → audioComplete

**Core Properties**:
```swift
@Model
public final class SpeakableItem {
    // Identity
    public var id: UUID
    public var orderIndex: Int

    // Source reference
    public var sourceElementID: String      // GuionElementModel ID
    public var sourceElementType: String    // "Dialogue", "Action", etc.
    public var sceneID: String?

    // Speakable content
    public var speakableText: String        // Filtered text to speak
    public var characterName: String?       // Normalized (e.g., "john")
    public var rawCharacterName: String?    // As written (e.g., "JOHN (V.O.)")

    // Speech logic metadata
    public var ruleVersion: String          // "1.0", "1.1", etc.
    public var includesCharacterAnnouncement: Bool
    public var toneHint: ToneHint?

    // Audio generation
    @Relationship(deleteRule: .cascade)
    public var audioVersions: [SpeakableAudio]
    public var activeAudioID: UUID?
    public var status: ProcessingStatus
}

public enum ToneHint: String, Codable {
    case narrative, character, emphasis, parenthetical
}

public enum ProcessingStatus: String, Codable {
    case textGenerated, audioQueued, audioGenerating,
         audioComplete, audioFailed
}
```

**SpeakableAudio Model**:
```swift
@Model
public final class SpeakableAudio {
    public var id: UUID
    public var hablareAudioID: UUID         // Reference to GeneratedAudioRecord
    public var providerName: String         // "ElevenLabs", "Apple"
    public var voiceID: String
    public var audioFormat: String
    public var isActive: Bool
    // ... metadata properties
}
```

### 3. SpeechLogicRulesProvider Protocol

**Purpose**: Define the contract for speech logic rules that can be swapped/customized.

```swift
protocol SpeechLogicRulesProvider {
    /// Transform a screenplay element into speakable text segments
    func generateSpeakableText(
        for element: ScreenplayElement,
        context: SceneContext
    ) -> [String]

    /// Determine if an element should be spoken at all
    func shouldSpeak(element: ScreenplayElement, context: SceneContext) -> Bool

    /// Update scene context after processing an element
    func updateContext(
        _ context: inout SceneContext,
        after element: ScreenplayElement
    )
}
```

### 4. SceneContext

**Purpose**: Track stateful information within a scene to enable context-aware speech logic.

```swift
struct SceneContext {
    var sceneID: UUID
    var charactersWhoHaveSpoken: Set<String> = []
    var currentSceneHeading: String?
    var lastSpeaker: String?
    var dialogueBlockCount: Int = 0
    var customFlags: [String: Any] = [:]  // Extensible state

    mutating func markCharacterSpoken(_ name: String) {
        charactersWhoHaveSpoken.insert(name)
    }

    func hasCharacterSpoken(_ name: String) -> Bool {
        charactersWhoHaveSpoken.contains(name)
    }
}
```

---

## Speech Logic Rules

### Rule Set v1.0 (Initial Implementation)

This section documents the initial speech logic rules. These are **expected to change frequently** during development.

#### 1. Scene Headings

**SwiftGuion Element**: `SceneHeading` (e.g., "INT. COFFEE SHOP - DAY")

**Rule**:
- ✅ **Always speak** scene headings
- Include entire heading text
- Optional: Add pause/emphasis markers

**Example**:
```
Input:  "INT. COFFEE SHOP - DAY"
Output: "Interior. Coffee shop. Day."
```

**Implementation Notes**:
- Consider abbreviation expansion (INT → Interior, EXT → Exterior)
- May add natural pauses between location and time

---

#### 2. Action Lines

**SwiftGuion Element**: `Action` (narrative description)

**Rule**:
- ✅ **Always speak** action lines
- Speak exactly as written
- May apply pronunciation fixes for common screenplay abbreviations

**Example**:
```
Input:  "John enters through the revolving door, shaking rain from his coat."
Output: "John enters through the revolving door, shaking rain from his coat."
```

**Implementation Notes**:
- No character name prefix needed
- Maintain original punctuation for natural pausing

---

#### 3. Character Dialogue

**SwiftGuion Elements**: `Character` → (Optional `Parenthetical`) → `Dialogue` line(s)

**Rule v1.0** (✅ **Confirmed**):
- ✅ **Character announcement format**: `"<Character> says:"` (e.g., "JOHN says:")
- ✅ **Announce ONCE per scene** - First time character speaks in scene only
- ✅ **Scene definition**: Everything between two scene headings (sluglines)
- ✅ **Dialogue grouping**: All consecutive dialogue lines from same character → **ONE SpeakableItem**
- ✅ **No splitting** unless hitting TTS provider character limit
- ❌ **Parentheticals NOT spoken** (performance directions)

**Example - Multi-line Dialogue**:
```
Input:
  Character: "JOHN"
  Dialogue: "I can't believe this is happening."
  Dialogue: "We need to get out of here."
  Dialogue: "Where did you park the car?"

Output (ONE SpeakableItem):
  "JOHN says: I can't believe this is happening. We need to get out of here. Where did you park the car?"
```

**Example - Scene-based Character Tracking**:
```
Scene Context: Fresh scene, no one has spoken yet

Input:
  Character: "JOHN"
  Dialogue: "Hey, have you seen my keys?"

Output: "JOHN says: Hey, have you seen my keys?"  ← First time in scene

---

Input:
  Character: "JOHN"
  Dialogue: "I really need to find them."

Output: "I really need to find them."  ← Already announced in this scene

---

Input:
  Character: "SARAH"
  Dialogue: "Check your coat pocket."

Output: "SARAH says: Check your coat pocket."  ← First time in scene

---

Input:
  Character: "JOHN"
  Dialogue: "Found them! Thanks!"

Output: "Found them! Thanks!"  ← Already announced (even after speaker change)
```

**Implementation Notes**:
- Track `SceneContext.charactersWhoHaveSpoken` (Set<String>)
- Character names normalized: "JOHN (V.O.)" → "john"
- Character name format in speech: Use raw name from screenplay
- Combine dialogue lines with space separator
- Scene boundary = `elementType == "Scene Heading"`

---

#### 4. Parentheticals

**SwiftGuion Element**: `Parenthetical` (e.g., "(sotto voce)", "(laughing)")

**Rule**:
- ❌ **Do not speak** parentheticals by default
- They are performance directions, not dialogue

**Example**:
```
Input:
  Character: "JOHN"
  Parenthetical: "(under his breath)"
  Dialogue: "This is ridiculous."

Output: "This is ridiculous."  ← Parenthetical omitted
```

**Implementation Notes**:
- May revisit this rule to optionally speak parentheticals in a different tone
- Could be configurable per voice/character

---

#### 5. Transitions

**SwiftGuion Element**: `Transition` (e.g., "CUT TO:", "FADE OUT:")

**Rule**:
- ❌ **Do not speak** transitions by default
- They are visual/editing directions

**Example**:
```
Input:  "CUT TO:"
Output: [silence]
```

**Implementation Notes**:
- May add optional silence/pause markers between scenes

---

#### 6. Centered Text / Title Pages

**SwiftGuion Element**: `CenteredText`, `TitlePage` metadata

**Rule**:
- ❌ **Do not speak** by default
- These are formatting elements

**Implementation Notes**:
- Consider optional introduction (e.g., "A screenplay by...")

---

### Rule Versioning

Speech logic rules will be versioned to track evolution:

- **v1.0** - Initial implementation (documented above)
- **v1.1** - TBD based on testing feedback
- **v2.0** - TBD after user testing

---

## Integration Points

### SwiftGuion Integration

**✅ Confirmed Model Structure** (see [SWIFTGUION_INTEGRATION_ANALYSIS.md](SWIFTGUION_INTEGRATION_ANALYSIS.md)):
- SwiftGuion provides SwiftData `@Model` classes: `GuionDocumentModel` and `GuionElementModel`
- **Single element class** (`GuionElementModel`) for all element types
- Elements differentiated by `elementType: String` property (not enum)
- Elements stored in array (`document.elements`) in screenplay order
- **No separate Character model** - characters are elements with type `"Character"`

**Query Pattern**:
```swift
// Fetch document with all elements
let descriptor = FetchDescriptor<GuionDocumentModel>(
    predicate: #Predicate { $0.filename == targetFilename }
)
let document = try modelContext.fetch(descriptor).first

// Elements are already in screenplay order
let elements = document.elements

// Filter by scene (if needed)
let sceneElements = elements.filter { $0.sceneId == targetSceneId }
```

**Key Integration Points**:
- Element iteration is **stateful** (must group Character → Parenthetical → Dialogue)
- Character names require **parsing and normalization** (modifiers like "JOHN (V.O.)" embedded in text)
- Dual dialogue detected via `isDualDialogue: Bool` flag
- Scene headings provide parsed location data: `locationScene`, `locationTimeOfDay`, etc.

### SwiftHablare Integration

**Text-to-Speech Generation**:
```swift
// Convert SpeakableItem to audio
let processor = ScreenplayToSpeechProcessor(modelContext: modelContext)
let speakableItems = try await processor.generateSpeakableItems()

// Use SwiftHablare to generate audio for each item
for item in speakableItems {
    let audio = try await textToSpeech.generate(
        text: item.text,
        voice: voiceForItem(item)  // Optional: different voices per character
    )
    // Save audio with reference to item.id
}
```

**Voice Assignment Strategy** (Optional Future Enhancement):
- Map character names to specific voices
- Use narrative voice for action/scene headings
- Store voice mappings in SwiftData

---

## Extensibility Requirements

### Configuration System

**Requirement**: Speech logic must be easily configurable without code changes.

**Approach Options**:

#### Option A: Protocol-Based (Recommended)
- Define `SpeechLogicRulesProvider` protocol
- Create default implementation: `DefaultSpeechLogicRules`
- Allow injection of custom implementations
- Rules can access SwiftData context for element queries

#### Option B: Declarative Rules Engine
- Define rules in JSON/YAML configuration files
- Rule conditions and actions specified declaratively
- More complex to implement, but more flexible

#### Option C: Hybrid
- Protocol for complex logic
- Configuration file for simple toggles (e.g., "speak_parentheticals: false")

**Recommended**: Start with Option A, add Option C configuration flags as needed.

---

### Documentation Requirements

Every rule implementation must include:

1. **Rule Description**: What the rule does
2. **Screenplay Element Type**: Which elements it applies to
3. **Context Dependencies**: What scene state affects the rule
4. **Examples**: Input element → Output speakable text
5. **Rationale**: Why this rule exists
6. **Open Questions**: Known limitations or unclear edge cases

**Template**:
```swift
/// **Rule: Character Name on First Dialogue**
///
/// - Element Type: `Dialogue`
/// - Context: Checks `SceneContext.lastSpeaker` and `SceneContext.charactersWhoHaveSpoken`
/// - Logic: Include character name if:
///   1. First time speaking in scene, OR
///   2. Previous speaker was different character
///
/// - Example:
///   ```
///   Input:  Character: "JOHN", Dialogue: "Hello"
///   Output: "John says: Hello"
///   ```
///
/// - Rationale: Listeners need to know who is speaking, but repetitive
///   character introductions sound unnatural.
///
/// - Open Questions:
///   - Should we re-introduce character after long monologue by another character?
///   - How to handle off-screen voices or voice-over?
func shouldIncludeCharacterName(
    for dialogue: DialogueElement,
    context: SceneContext
) -> Bool {
    // Implementation...
}
```

---

## Testing Strategy

### Unit Tests

1. **Rule Logic Tests**: Test each speech rule in isolation
   - Given element + context → Expected speakable text
   - Test edge cases (empty dialogue, special characters, etc.)

2. **Context Management Tests**: Verify state tracking
   - Character spoken tracking
   - Speaker change detection

3. **Integration Tests**: Full screenplay processing
   - Small sample screenplay → Expected SpeakableItems array
   - Verify ordering, character name logic, element filtering

### Test Data

Create sample SwiftGuion models for testing:
- Simple scene with 2 characters, 5 dialogue lines
- Complex scene with multiple speakers, actions, parentheticals
- Multi-scene screenplay

---

## Success Criteria

### Phase 1: MVP
- ✅ `ScreenplayToSpeechProcessor` class created
- ✅ `SpeakableItem` model defined
- ✅ Basic speech logic for: Scene Headings, Action, Dialogue (with character name logic)
- ✅ Unit tests for all speech rules
- ✅ Integration test: Full scene → SpeakableItems

### Phase 2: Refinement
- ✅ Iterate on speech rules based on testing
- ✅ Add configuration system for rule toggles
- ✅ Comprehensive documentation of all rules
- ✅ Edge case handling (dual dialogue, lyrics, etc.)

### Phase 3: SwiftHablare Integration
- ✅ Connect SpeakableItems to TTS generation
- ✅ Character-to-voice mapping system
- ✅ Audio file generation and playback
- ✅ SwiftData persistence for generated audio

### Phase 4: UI & Workflow (NEW)
- ✅ Task-based processing with progress tracking
  - SpeakableItem generation task
  - Audio generation task
  - Progress bars and cancellation
- ✅ Tabbed interface design
  - Voice-to-Character mapping
  - Character-to-Voice mapping
  - Generated Audio list with player
  - Export tab (placeholder)
- ✅ Voice assignment system
  - Auto-detect characters from screenplay
  - Manual voice selection per character
  - Bidirectional mapping views

**See**: [SCREENPLAY_UI_WORKFLOW_DESIGN.md](SCREENPLAY_UI_WORKFLOW_DESIGN.md) for complete UI/workflow specification

### Phase 5: Sample Application (NEW)
- ✅ Split-view showcase application
  - Left pane: SwiftGuion screenplay editor (standard view)
  - Right pane: Hablare tabbed palette (4 tabs)
  - Sidebar: Screenplay list/selector
- ✅ View synchronization
  - Element selection highlights corresponding SpeakableItem
  - Audio playback highlights screenplay element
  - Edit detection and regeneration warnings
- ✅ Sample screenplay included
  - Demo content with multiple scenes/characters
  - Auto-loads on first launch
  - Import .fountain files support
- ✅ Complete workflow demonstration
  - Parse screenplay → Generate items → Assign voices → Generate audio → Play

**See**: [SAMPLE_APP_DESIGN.md](SAMPLE_APP_DESIGN.md) for complete sample app architecture

---

## Open Questions & Future Enhancements

**📋 For a comprehensive list of open questions, see [SCREENPLAY_SPEECH_OPEN_QUESTIONS.md](SCREENPLAY_SPEECH_OPEN_QUESTIONS.md)**

The open questions document catalogs **56 questions** across 10 categories:
- 🔴 12 Critical questions (must resolve before Phase 1)
- 🟡 24 High priority questions (resolve during Phase 1-2)
- 🟢 17 Medium priority questions (address in Phase 2-3)
- 🔵 3 Low priority questions (future enhancements)

### Key Open Questions Summary
1. **SwiftGuion Integration**: Actual model structure, element ordering, character handling
2. **Speech Logic**: Character name formatting, text splitting, transformation rules
3. **Audio Generation**: TTS limits, file organization, voice assignment
4. **Data Model**: Persistence strategy, versioning, caching
5. **User Experience**: Primary workflow, configuration UX, preview capabilities

### Future Enhancements
1. **SSML Generation**: Generate Speech Synthesis Markup Language for advanced prosody control
2. **Emotion Detection**: Infer emotion from parentheticals and adjust voice tone
3. **Background Sounds**: Add ambient audio for scene headings (rain, cafe noise, etc.)
4. **Multi-Voice Projects**: Assign different TTS voices to each character
5. **Export Formats**: Generate podcast-style audio, audiobook chapters, etc.

---

## Appendix: SwiftGuion Element Types

**📋 For complete integration details, see [SWIFTGUION_INTEGRATION_ANALYSIS.md](SWIFTGUION_INTEGRATION_ANALYSIS.md)**

### Actual SwiftGuion Models

**Source**: Analyzed from [SwiftGuion GitHub Repository](https://github.com/intrusive-memory/SwiftGuion)

```swift
@Model
public final class GuionDocumentModel {
    public var filename: String?
    public var rawContent: String?
    public var suppressSceneNumbers: Bool

    @Relationship(deleteRule: .cascade, inverse: \GuionElementModel.document)
    public var elements: [GuionElementModel]  // All elements in screenplay order

    @Relationship(deleteRule: .cascade, inverse: \TitlePageEntryModel.document)
    public var titlePage: [TitlePageEntryModel]
}

@Model
public final class GuionElementModel {
    public var elementText: String          // The actual content
    public var elementType: String          // Element type as string (NOT enum!)
    public var isCentered: Bool
    public var isDualDialogue: Bool
    public var sceneNumber: String?
    public var sectionDepth: Int
    public var sceneId: String?

    // Cached location data for Scene Headings
    public var locationLighting: String?    // "INT", "EXT"
    public var locationScene: String?       // "COFFEE SHOP"
    public var locationTimeOfDay: String?   // "DAY", "NIGHT"
    public var locationModifiers: [String]?

    public var summary: String?
    public var document: GuionDocumentModel?
}
```

### Element Type Strings

| Type | String Value | Example |
|------|--------------|---------|
| Scene Heading | `"Scene Heading"` | "INT. COFFEE SHOP - DAY" |
| Action | `"Action"` | "John enters the room." |
| Character | `"Character"` | "JOHN" or "JOHN (V.O.)" |
| Dialogue | `"Dialogue"` | "Have you seen Sarah?" |
| Parenthetical | `"Parenthetical"` | "(whispering)" |
| Transition | `"Transition"` | "CUT TO:" |
| Section Heading | `"Section Heading"` | "# ACT ONE" |
| Centered | `"Centered"` | Title text |
| Synopsis | `"Synopsis"` | Summary metadata |
| Note | `"Note"` | `[[ Comment ]]` |
| Boneyard | `"Boneyard"` | Omitted content |
| Lyrics | `"Lyrics"` | Song text |

### Key Differences from Initial Assumptions

**❌ Wrong Assumptions**:
- No `ElementType` enum (uses strings)
- No separate classes per element type (all use `GuionElementModel`)
- No `Character` model (characters are elements)
- No `orderIndex` property (order is array position)
- Parentheticals are separate elements, not properties of Dialogue

**✅ Confirmed**:
- SwiftData `@Model` classes
- Elements maintain screenplay order in array
- Scene headings have parsed location data

### Dialogue Structure

Dialogue is represented as **consecutive elements**:

1. Character element: `elementType: "Character"`, `elementText: "JOHN"`
2. (Optional) Parenthetical: `elementType: "Parenthetical"`, `elementText: "(whispering)"`
3. Dialogue line(s): `elementType: "Dialogue"`, `elementText: "The actual line"`

**Processing requires stateful iteration** to group these elements together.

---

## Change Log

| Version | Date | Changes |
|---------|------|---------|
| 0.1 | 2025-10-16 | Initial requirements draft |
| 0.2 | 2025-10-16 | Added comprehensive open questions document (56 questions identified) |
| 1.0 | 2025-10-16 | **Updated with actual SwiftGuion model structure**. Replaced assumptions with confirmed model details from source code analysis. Added integration analysis document. |
| 2.0 | 2025-10-16 | **MAJOR UPDATE - 93% Critical Questions Resolved**<br>• Finalized Speech Logic v1.0 rules (character announcement, dialogue grouping)<br>• Designed complete SpeakableItem SwiftData model<br>• Designed SpeakableAudio integration with Hablare<br>• Updated all rule examples with confirmed behavior<br>• Added SPEAKABLE_ITEM_MODEL_DESIGN.md<br>• **Ready for Phase 1 implementation** |
| 3.0 | 2025-10-16 | **UI & WORKFLOW DESIGN COMPLETE - 94% Critical Questions Resolved**<br>• Added complete UI/workflow architecture<br>• Designed task system with progress tracking<br>• Designed 4-tab interface (Voice↔Character mapping, Audio list, Export)<br>• Created CharacterVoiceMapping SwiftData model<br>• Added SCREENPLAY_UI_WORKFLOW_DESIGN.md<br>• **Complete specification ready for implementation** |
| 3.1 | 2025-10-16 | **SAMPLE APP DESIGN ADDED**<br>• Designed split-view showcase application (Examples/Hablare)<br>• Left pane: SwiftGuion screenplay editor<br>• Right pane: Hablare tabbed palette<br>• View synchronization strategy<br>• Sample screenplay with demo content<br>• Added SAMPLE_APP_DESIGN.md |
| 3.2 | 2025-10-16 | **TDD METHODOLOGY COMPLETE**<br>• Added comprehensive test-driven development methodology<br>• 7 development phases with quality gates<br>• 500+ test specifications (write tests FIRST)<br>• Module-specific coverage targets (95% models, 85% overall)<br>• Complete TDD workflow documentation<br>• Added SCREENPLAY_SPEECH_METHODOLOGY.md |

---

## Review & Approval

This document should be reviewed and approved before implementation begins.

**Stakeholders**:
- [ ] Product Owner
- [ ] Lead Developer
- [ ] SwiftGuion Integration Lead
- [ ] Testing Lead

**Next Steps**:
1. Review SwiftGuion API documentation for accurate element types
2. Validate speech logic rules with sample screenplay readings
3. Create implementation plan with milestones
4. Begin Phase 1 development
