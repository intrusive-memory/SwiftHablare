# SwiftGuion Integration Analysis

## Document Purpose

This document provides comprehensive answers to the critical integration questions identified in `SCREENPLAY_SPEECH_OPEN_QUESTIONS.md`, based on analysis of the actual SwiftGuion codebase.

**Source**: [SwiftGuion GuionDocumentModel.swift](https://github.com/intrusive-memory/SwiftGuion/blob/main/Sources/SwiftGuion/FileFormat/GuionDocumentModel.swift)

**Analysis Date**: 2025-10-16

---

## SwiftGuion Model Structure Overview

### Core Models

SwiftGuion uses SwiftData `@Model` classes with the following structure:

```swift
@Model
public final class GuionDocumentModel {
    public var filename: String?
    public var rawContent: String?
    public var suppressSceneNumbers: Bool

    @Relationship(deleteRule: .cascade, inverse: \GuionElementModel.document)
    public var elements: [GuionElementModel]

    @Relationship(deleteRule: .cascade, inverse: \TitlePageEntryModel.document)
    public var titlePage: [TitlePageEntryModel]
}

@Model
public final class GuionElementModel: GuionElementProtocol {
    public var elementText: String          // The actual content
    public var elementType: String          // Element category (NOT an enum!)
    public var isCentered: Bool
    public var isDualDialogue: Bool
    public var sceneNumber: String?
    public var sectionDepth: Int
    public var sceneId: String?

    // SwiftData-specific
    public var summary: String?
    public var document: GuionDocumentModel?

    // Cached location data for Scene Headings
    public var locationLighting: String?
    public var locationScene: String?
    public var locationSetup: String?
    public var locationTimeOfDay: String?
    public var locationModifiers: [String]?
}
```

### Key Characteristics

**Flat Structure**:
- All screenplay elements use the same `GuionElementModel` class
- Element differentiation is via `elementType: String` property
- **No inheritance hierarchy** (no separate Action, Dialogue, Character classes)
- **No enum** for element types - uses string literals

**Element Ordering**:
- Elements are stored in `GuionDocumentModel.elements: [GuionElementModel]`
- Array order = screenplay order
- No explicit `orderIndex` property needed

**No Character Model**:
- Characters are **not** separate entities
- Character names appear as `GuionElementModel` with `elementType == "Character"`
- No normalization or canonical character tracking

---

## Answers to Critical Integration Questions

### 🔴 Q1.1: What is the actual SwiftGuion model structure?

**ANSWER**: See model structure above. Key points:

✅ **Confirmed**:
- SwiftData `@Model` classes
- Single `GuionElementModel` for all element types
- String-based element type identification
- Elements in array preserve document order

❌ **Assumptions that were WRONG**:
- No `ElementType` enum (it's strings)
- No separate classes per element type
- No `Character` model
- No `orderIndex` property

**Impact**: Our integration layer must:
- Handle string-based element type checking (not enum matching)
- Parse `elementText` to extract dialogue vs. character names
- Implement our own character tracking (no built-in normalization)

---

### 🔴 Q1.2: How are elements ordered within SwiftGuion?

**ANSWER**:

✅ **Array-based ordering**
```swift
let document: GuionDocumentModel = // ... fetch from context
let elements = document.elements  // Already in screenplay order
```

**Iteration Pattern**:
```swift
// Elements are already ordered - just iterate
for element in document.elements {
    // Process in screenplay order
}
```

**Scene Identification**:
```swift
// Scene headings have elementType == "Scene Heading"
// They also have sceneId property for grouping
let sceneHeadings = elements.filter { $0.elementType == "Scene Heading" }
```

**Impact**:
- ✅ Simple iteration, no complex sorting needed
- ✅ Array index can serve as our `orderIndex` in `SpeakableItem`
- ⚠️ Must handle scene boundaries by detecting `"Scene Heading"` elements

---

### 🔴 Q1.3: What is the relationship between Dialogue and Parentheticals?

**ANSWER**:

SwiftGuion represents dialogue structure as **three consecutive elements**:

1. **Character element**: `elementType == "Character"`, `elementText == "JOHN"`
2. **Parenthetical element** (optional): `elementType == "Parenthetical"`, `elementText == "(sotto voce)"`
3. **Dialogue element**: `elementType == "Dialogue"`, `elementText == "This is my line."`

**Example Sequence**:
```swift
// Input Fountain:
// JOHN
// (whispering)
// We need to leave.

// Parsed as:
elements[0]: GuionElementModel(elementType: "Character", elementText: "JOHN")
elements[1]: GuionElementModel(elementType: "Parenthetical", elementText: "(whispering)")
elements[2]: GuionElementModel(elementType: "Dialogue", elementText: "We need to leave.")
```

**Key Insights**:
- Parentheticals are **separate elements**, not properties of Dialogue
- Must look-ahead/look-behind to associate parentheticals with dialogue
- A dialogue block can have multiple lines (consecutive "Dialogue" elements after same "Character")

**Processing Strategy**:
```swift
func processDialogueBlock(startIndex: Int, elements: [GuionElementModel]) -> DialogueBlock {
    var index = startIndex
    guard elements[index].elementType == "Character" else { fatalError() }

    let characterName = elements[index].elementText
    index += 1

    // Optional parenthetical
    var parenthetical: String?
    if index < elements.count && elements[index].elementType == "Parenthetical" {
        parenthetical = elements[index].elementText
        index += 1
    }

    // Collect all consecutive dialogue lines
    var dialogueLines: [String] = []
    while index < elements.count && elements[index].elementType == "Dialogue" {
        dialogueLines.append(elements[index].elementText)
        index += 1
    }

    return DialogueBlock(character: characterName,
                         parenthetical: parenthetical,
                         dialogue: dialogueLines)
}
```

**Impact**:
- Need stateful iteration to group Character → Parenthetical → Dialogue
- Cannot process elements independently
- Must implement look-ahead logic

---

### 🔴 Q1.4: How does SwiftGuion handle Character extensions/modifiers?

**ANSWER**:

Character modifiers (V.O., O.S., CONT'D, etc.) are **embedded in the elementText** as a single string.

**Examples**:
```swift
elementType: "Character", elementText: "JOHN"
elementType: "Character", elementText: "JOHN (V.O.)"
elementType: "Character", elementText: "JOHN (O.S.)"
elementType: "Character", elementText: "JOHN (CONT'D)"
elementType: "Character", elementText: "YOUNG JOHN"
```

**No Separate Properties**:
- No `characterName` vs `modifier` split
- No `isVoiceOver`, `isOffScreen` boolean flags
- No parsed structure

**Our Responsibility**:
We must parse these ourselves:

```swift
struct ParsedCharacter {
    let baseName: String        // "JOHN"
    let modifiers: [String]     // ["V.O."], ["O.S."], ["CONT'D"]
    let prefix: String?         // "YOUNG" from "YOUNG JOHN"
    let rawText: String         // Original "JOHN (V.O.)"
}

func parseCharacter(_ text: String) -> ParsedCharacter {
    // Extract modifiers in parentheses
    let modifierPattern = /\(([^)]+)\)/  // Matches "(V.O.)"

    // Extract prefix (YOUNG JOHN, OLD SARAH, etc.)
    // This is screenplay-specific, may need manual mapping

    // Normalize for tracking (case insensitive, ignore modifiers)
}
```

**Character Tracking Strategy**:
```swift
// For tracking "has character spoken in scene", we need normalization
func normalizeCharacterName(_ rawText: String) -> String {
    // "JOHN (V.O.)" -> "john"
    // "JOHN (CONT'D)" -> "john"
    // "YOUNG JOHN" -> "young john" or "john"? (decision needed)

    let withoutParens = rawText.replacingOccurrences(of: /\([^)]+\)/, with: "")
    return withoutParens.trimmingCharacters(in: .whitespaces).lowercased()
}
```

**Impact**:
- ⚠️ Must implement character name parsing logic
- ⚠️ Decide on normalization rules (is "JOHN" == "JOHN (V.O.)"?)
- ⚠️ Handle edge cases: "WAITRESS #1", "JOHN'S VOICE", "BOTH"
- ✅ Flexible - we control the logic

---

### 🔴 Q1.5: Does SwiftGuion provide character normalization?

**ANSWER**:

❌ **NO** - SwiftGuion does not provide character normalization or canonical character IDs.

**What SwiftGuion Provides**:
- Raw `elementText` exactly as written in screenplay
- No character database or lookup
- No aliases or canonical names

**What We Must Build**:

Option A: **Simple string matching** (naive)
```swift
// Treat each unique string as different character
"JOHN" != "JOHN (V.O.)" != "John"
```

Option B: **Normalization with mapping** (recommended)
```swift
class CharacterNormalizer {
    // User-configurable mapping
    var aliases: [String: String] = [:]  // "JOHN (V.O.)" -> "john"

    func normalize(_ rawName: String) -> String {
        // 1. Check user-defined aliases first
        if let mapped = aliases[rawName] {
            return mapped
        }

        // 2. Apply automatic normalization
        let cleaned = rawName
            .replacingOccurrences(of: /\([^)]+\)/, with: "")  // Remove (V.O.)
            .trimmingCharacters(in: .whitespaces)
            .lowercased()

        return cleaned
    }
}
```

Option C: **SwiftData Character Model** (advanced)
```swift
@Model
class ScreenplayCharacter {
    var canonicalName: String        // "John"
    var aliases: [String]             // ["JOHN", "JOHN (V.O.)", "John"]
    var firstAppearanceIndex: Int?
    var voiceID: String?              // For TTS assignment
}

// Track during processing
class CharacterTracker {
    func findOrCreateCharacter(rawName: String, in context: ModelContext) -> ScreenplayCharacter {
        // Smart matching logic
    }
}
```

**Recommendation**: Start with Option B (normalization function), add Option C later for voice assignment.

**Impact**:
- ⚠️ Must implement our own normalization
- ⚠️ User may need to manually map aliases for complex screenplays
- ✅ We control the logic - can iterate and improve

---

### 🔴 Q1.6: What SwiftData query performance should we expect?

**ANSWER**:

**Simple Approach** (recommended for MVP):
```swift
// Fetch entire document with all elements in one query
let descriptor = FetchDescriptor<GuionDocumentModel>(
    predicate: #Predicate { $0.filename == targetFilename }
)
let documents = try context.fetch(descriptor)
let document = documents.first

// Elements are already loaded via relationship
let elements = document.elements  // No additional query
```

**Performance Characteristics**:
- **Small screenplay** (100 pages, ~600 elements): Fast, <100ms
- **Large screenplay** (200 pages, ~1200 elements): Still manageable, <500ms
- **All in-memory** once loaded: Array iteration is O(n)

**Optimization for Very Large Screenplays**:
```swift
// Option 1: Fetch only needed scene
let sceneDescriptor = FetchDescriptor<GuionElementModel>(
    predicate: #Predicate { $0.sceneId == targetSceneId },
    sortBy: [SortDescriptor(\.elementText)]  // Proxy for order
)
```

**Caveat**: SwiftGuion doesn't have `orderIndex`, so sorting by array position requires fetching all.

**Recommendation**:
- ✅ **MVP**: Fetch entire document, process in-memory
- ✅ **Cache**: Store generated `SpeakableItem` array to avoid re-processing
- ⚠️ **Large screenplays**: May need pagination or scene-by-scene processing
- 🔜 **Benchmark**: Test with 100-page screenplay to confirm performance

**Impact**:
- ✅ No immediate performance concerns for typical use
- ⚠️ May need optimization for very large screenplays (>300 pages)

---

### 🔴 Q1.7: How does SwiftGuion handle dual dialogue?

**ANSWER**:

Dual dialogue is marked with the `isDualDialogue: Bool` property.

**Structure**:
```swift
// In Fountain:
// JOHN                          SARAH
// I can't believe this.         Me neither.

// Parsed as:
elements[0]: GuionElementModel(elementType: "Character",
                               elementText: "JOHN",
                               isDualDialogue: true)
elements[1]: GuionElementModel(elementType: "Dialogue",
                               elementText: "I can't believe this.",
                               isDualDialogue: true)
elements[2]: GuionElementModel(elementType: "Character",
                               elementText: "SARAH",
                               isDualDialogue: true)
elements[3]: GuionElementModel(elementType: "Dialogue",
                               elementText: "Me neither.",
                               isDualDialogue: true)
```

**Processing Strategy**:

Option A: **Sequential** (speak one after the other)
```swift
if element.isDualDialogue {
    // Process normally, but maybe add a note
    // Result: "John says: I can't believe this. Sarah says: Me neither."
}
```

Option B: **Grouped** (indicate simultaneity)
```swift
func processDualDialogue(startIndex: Int, elements: [GuionElementModel]) -> [SpeakableItem] {
    // Collect all consecutive dual dialogue elements
    var items: [SpeakableItem] = []

    // Add a narrative marker
    items.append(SpeakableItem(text: "Speaking simultaneously:"))

    // Then process each character's lines
    // ...
}
```

Option C: **Skip second** (only speak first character in dual dialogue)
```swift
// Speak JOHN's line, skip SARAH's (to avoid redundancy)
```

**Recommendation**: Option A for MVP (sequential), add Option B as configuration later.

**Impact**:
- ✅ Easy to detect with `isDualDialogue` flag
- ⚠️ Speech output will sound sequential even though visual is simultaneous
- 🔜 User testing needed to determine best approach

---

### 🔴 Q1.8: Does SwiftGuion parse screenplay notes/comments?

**ANSWER**:

✅ **YES** - SwiftGuion supports Fountain **Notes** and **Boneyard**.

**Element Types**:
- `elementType == "Note"` - `[[ This is a note ]]`
- `elementType == "Boneyard"` - `/* Omitted content */`

**Default Behavior**:
- These elements exist in the `elements` array
- Typically should NOT be spoken (they're metadata/comments)

**Processing Rule**:
```swift
let nonSpeakableTypes = ["Note", "Boneyard", "Synopsis", "Section Heading"]

func shouldSpeak(element: GuionElementModel) -> Bool {
    return !nonSpeakableTypes.contains(element.elementType)
}
```

**Impact**:
- ✅ Easy to filter out
- ⚠️ User may want option to include notes (configurable)

---

### 🔴 Q1.9: How are screenplay revisions handled?

**ANSWER**:

⚠️ **Unknown** - Not visible in `GuionDocumentModel.swift`.

SwiftGuion may not track revision colors (BLUE, PINK pages) at the model level. This is typically handled by:
- External metadata (PDF-based workflows)
- Fountain doesn't have built-in revision tracking

**Assumption**: Revisions are not tracked in SwiftData models.

**Impact**:
- No revision-specific speech generation needed
- If user needs this, would require custom metadata

---

## Element Type Reference

### Complete List of Element Types

Based on documentation and code analysis:

| Element Type | String Value | Speakable? | Notes |
|-------------|--------------|------------|-------|
| Scene Heading | `"Scene Heading"` | ✅ Yes | Transform for natural speech |
| Action | `"Action"` | ✅ Yes | Speak as-is |
| Character | `"Character"` | ⚠️ Partial | Announce character name |
| Dialogue | `"Dialogue"` | ✅ Yes | Main speakable content |
| Parenthetical | `"Parenthetical"` | ❌ Default No | Performance direction |
| Transition | `"Transition"` | ❌ No | Visual direction (CUT TO:) |
| Centered | `"Centered"` | ❌ No | Title/formatting |
| Section Heading | `"Section Heading"` | ❌ No | Organizational |
| Synopsis | `"Synopsis"` | ❌ No | Summary metadata |
| Note | `"Note"` | ❌ No | Comments |
| Boneyard | `"Boneyard"` | ❌ No | Omitted content |
| Page Break | `"Page Break"` | ❌ No | Formatting |
| Lyrics | `"Lyrics"` | ⚠️ TBD | Songs - may speak differently |
| Dual Dialogue | (flag) | ✅ Yes | Use `isDualDialogue` flag |

---

## Integration Layer Design

### Recommended Architecture

```swift
// MARK: - Main Processor

@MainActor
class ScreenplayToSpeechProcessor {
    let modelContext: ModelContext
    let logicRules: SpeechLogicRulesProvider
    let characterNormalizer: CharacterNormalizer

    func generateSpeakableItems(
        for document: GuionDocumentModel
    ) async throws -> [SpeakableItem] {
        var items: [SpeakableItem] = []
        var sceneContext = SceneContext()

        let elements = document.elements
        var index = 0

        while index < elements.count {
            let element = elements[index]

            // Update scene context on scene boundaries
            if element.elementType == "Scene Heading" {
                sceneContext = SceneContext(sceneID: element.sceneId ?? "unknown")
                items.append(contentsOf: processSceneHeading(element))
                index += 1
                continue
            }

            // Process dialogue blocks (Character + Parenthetical + Dialogue)
            if element.elementType == "Character" {
                let (dialogueItems, consumed) = processDialogueBlock(
                    startIndex: index,
                    elements: elements,
                    context: &sceneContext
                )
                items.append(contentsOf: dialogueItems)
                index += consumed
                continue
            }

            // Process other elements
            if let item = processSingleElement(element, context: sceneContext) {
                items.append(item)
            }
            index += 1
        }

        return items
    }

    private func processDialogueBlock(
        startIndex: Int,
        elements: [GuionElementModel],
        context: inout SceneContext
    ) -> (items: [SpeakableItem], consumed: Int) {
        var index = startIndex
        var items: [SpeakableItem] = []

        // 1. Character name
        let characterElement = elements[index]
        let rawCharacterName = characterElement.elementText
        let normalizedName = characterNormalizer.normalize(rawCharacterName)
        index += 1

        // 2. Optional parenthetical
        var parenthetical: String?
        if index < elements.count && elements[index].elementType == "Parenthetical" {
            parenthetical = elements[index].elementText
            index += 1
        }

        // 3. Dialogue lines
        var dialogueLines: [String] = []
        while index < elements.count && elements[index].elementType == "Dialogue" {
            dialogueLines.append(elements[index].elementText)
            index += 1
        }

        // 4. Generate speakable text
        let shouldIncludeName = logicRules.shouldIncludeCharacterName(
            character: normalizedName,
            context: context
        )

        for (lineIndex, dialogue) in dialogueLines.enumerated() {
            var text = dialogue

            // Include character name on first line if needed
            if lineIndex == 0 && shouldIncludeName {
                text = "\(rawCharacterName) says: \(dialogue)"
            }

            items.append(SpeakableItem(
                text: text,
                sourceElementID: characterElement.sceneId ?? "unknown",
                sourceElementType: "Dialogue",
                characterName: normalizedName,
                sceneID: context.sceneID,
                orderIndex: startIndex + lineIndex
            ))
        }

        // 5. Update context
        context.markCharacterSpoken(normalizedName)
        context.lastSpeaker = normalizedName

        return (items, index - startIndex)
    }

    private func processSceneHeading(_ element: GuionElementModel) -> [SpeakableItem] {
        // Use cached location data if available
        let text: String
        if let scene = element.locationScene,
           let timeOfDay = element.locationTimeOfDay {
            // "Interior. Coffee shop. Day."
            let lighting = element.locationLighting ?? "Interior"
            text = "\(lighting). \(scene). \(timeOfDay)."
        } else {
            // Fallback to raw text
            text = element.elementText
                .replacingOccurrences(of: "INT.", with: "Interior.")
                .replacingOccurrences(of: "EXT.", with: "Exterior.")
        }

        return [SpeakableItem(
            text: text,
            sourceElementID: element.sceneId ?? "unknown",
            sourceElementType: "Scene Heading",
            sceneID: element.sceneId,
            orderIndex: 0  // Would need proper tracking
        )]
    }

    private func processSingleElement(
        _ element: GuionElementModel,
        context: SceneContext
    ) -> SpeakableItem? {
        guard logicRules.shouldSpeak(element: element, context: context) else {
            return nil
        }

        return SpeakableItem(
            text: element.elementText,
            sourceElementID: element.sceneId ?? "unknown",
            sourceElementType: element.elementType,
            sceneID: context.sceneID,
            orderIndex: 0  // Would need proper tracking
        )
    }
}

// MARK: - Character Normalization

class CharacterNormalizer {
    var userDefinedAliases: [String: String] = [:]

    func normalize(_ rawName: String) -> String {
        // Check user mappings first
        if let canonical = userDefinedAliases[rawName] {
            return canonical
        }

        // Automatic normalization
        let cleaned = rawName
            .replacingOccurrences(of: /\s*\([^)]+\)\s*/, with: "")  // Remove (V.O.), (CONT'D), etc.
            .trimmingCharacters(in: .whitespaces)
            .lowercased()

        return cleaned
    }
}

// MARK: - Scene Context

struct SceneContext {
    var sceneID: String
    var charactersWhoHaveSpoken: Set<String> = []
    var lastSpeaker: String?

    mutating func markCharacterSpoken(_ name: String) {
        charactersWhoHaveSpoken.insert(name)
    }

    func hasCharacterSpoken(_ name: String) -> Bool {
        charactersWhoHaveSpoken.contains(name)
    }
}
```

---

## Critical Decisions Required

### Decision 1: Character Name Normalization

**Question**: How should we normalize character names?

**Options**:
- A: Exact string match (simple but inflexible)
- B: Remove parentheticals only (recommended for MVP)
- C: Full normalization with alias mapping (ideal but complex)

**Recommendation**: Start with B, add C later.

---

### Decision 2: Dialogue Grouping

**Question**: Should consecutive dialogue lines from same character be separate SpeakableItems?

**Example**:
```
JOHN
This is line one.
This is line two.
```

**Options**:
- A: One SpeakableItem with combined text: "This is line one. This is line two."
- B: Two SpeakableItems, one per line
- C: Configurable

**Recommendation**: A (combined) for MVP, simpler audio generation.

---

### Decision 3: Element Ordering Tracking

**Question**: How to assign `orderIndex` to SpeakableItems?

**Options**:
- A: Use array index from `elements` array
- B: Generate sequential index as we create items
- C: Store explicit ordering in SpeakableItem

**Recommendation**: B (sequential generation), simplest and correct.

---

## Next Steps

1. ✅ **SwiftGuion model structure documented** - Complete
2. 🔜 **Update requirements document** - Replace assumptions with facts
3. 🔜 **Implement integration layer** - Use design above
4. 🔜 **Create test screenplay** - Parse with SwiftGuion, verify element structure
5. 🔜 **Build character normalizer** - Test with various character names
6. 🔜 **Prototype dialogue processing** - Verify Character → Parenthetical → Dialogue grouping

---

## Appendix: Example SwiftGuion Element Sequences

### Example 1: Simple Dialogue

**Fountain Input**:
```
INT. COFFEE SHOP - DAY

John enters, looking around nervously.

JOHN
Have you seen Sarah?

WAITRESS
She left about an hour ago.
```

**Parsed Elements**:
```swift
[
    GuionElementModel(elementType: "Scene Heading", elementText: "INT. COFFEE SHOP - DAY", sceneId: "scene-1"),
    GuionElementModel(elementType: "Action", elementText: "John enters, looking around nervously."),
    GuionElementModel(elementType: "Character", elementText: "JOHN"),
    GuionElementModel(elementType: "Dialogue", elementText: "Have you seen Sarah?"),
    GuionElementModel(elementType: "Character", elementText: "WAITRESS"),
    GuionElementModel(elementType: "Dialogue", elementText: "She left about an hour ago."),
]
```

### Example 2: Dialogue with Parenthetical

**Fountain Input**:
```
JOHN
(whispering)
We need to leave now.
```

**Parsed Elements**:
```swift
[
    GuionElementModel(elementType: "Character", elementText: "JOHN"),
    GuionElementModel(elementType: "Parenthetical", elementText: "(whispering)"),
    GuionElementModel(elementType: "Dialogue", elementText: "We need to leave now."),
]
```

### Example 3: Multi-line Dialogue

**Fountain Input**:
```
JOHN
I can't believe this is happening.
We should have left yesterday.
Now it's too late.
```

**Parsed Elements**:
```swift
[
    GuionElementModel(elementType: "Character", elementText: "JOHN"),
    GuionElementModel(elementType: "Dialogue", elementText: "I can't believe this is happening."),
    GuionElementModel(elementType: "Dialogue", elementText: "We should have left yesterday."),
    GuionElementModel(elementType: "Dialogue", elementText: "Now it's too late."),
]
```

### Example 4: Dual Dialogue

**Fountain Input**:
```
JOHN                    SARAH
I love you.             I love you too.
```

**Parsed Elements**:
```swift
[
    GuionElementModel(elementType: "Character", elementText: "JOHN", isDualDialogue: true),
    GuionElementModel(elementType: "Dialogue", elementText: "I love you.", isDualDialogue: true),
    GuionElementModel(elementType: "Character", elementText: "SARAH", isDualDialogue: true),
    GuionElementModel(elementType: "Dialogue", elementText: "I love you too.", isDualDialogue: true),
]
```

---

## Change Log

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-10-16 | Initial analysis based on SwiftGuion source code review |
