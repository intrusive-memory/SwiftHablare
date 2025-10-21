# SpeakableItem Model Design

## Document Purpose

This document defines the SwiftData model design for `SpeakableItem` and its integration with SwiftGuion source elements and SwiftHablare audio generation.

**Version**: 1.0
**Date**: 2025-10-16

---

## Design Decisions

### Key Decisions Made

**Character Announcement**:
- ✅ Format: `"<Character> says:"` (e.g., "JOHN says: Have you seen my keys?")
- ✅ Frequency: **Once per scene** (first time character speaks in scene)
- ✅ Scene definition: Everything between two scene headings (sluglines)

**Dialogue Grouping**:
- ✅ **Do not split** character dialogue unless hitting TTS provider character limits
- ✅ All consecutive lines from same character are **grouped together** in one SpeakableItem
- ✅ Multi-line dialogue example:
  ```
  JOHN
  I can't believe this.
  We need to leave.
  Now.
  ```
  → One SpeakableItem: "JOHN says: I can't believe this. We need to leave. Now."

**Data Persistence**:
- ✅ SpeakableItem is a **SwiftData @Model** (not transient struct)
- ✅ Persistent, queryable, cached
- ✅ Allows versioning and regeneration tracking

---

## SpeakableItem SwiftData Model

### Core Model Definition

```swift
import SwiftData
import Foundation

@Model
public final class SpeakableItem {
    // MARK: - Identity

    /// Unique identifier for this speakable item
    public var id: UUID

    /// Position in the screenplay (array index in original elements)
    public var orderIndex: Int

    /// Timestamp when this item was created
    public var createdAt: Date

    // MARK: - Source Reference

    /// Reference to the source SwiftGuion element(s)
    /// For dialogue blocks, this points to the Character element
    public var sourceElementID: String  // GuionElementModel.sceneId or custom ID

    /// Type of source element (for filtering/debugging)
    public var sourceElementType: String  // "Dialogue", "Action", "Scene Heading"

    /// Scene ID this item belongs to (from GuionElementModel.sceneId)
    public var sceneID: String?

    // MARK: - Speakable Content

    /// The text to be spoken (after applying speech logic rules)
    /// This is the filtered/transformed text, not the raw screenplay text
    public var speakableText: String

    /// Character name if this is dialogue (normalized)
    /// Used for tracking who has spoken and for voice assignment
    public var characterName: String?

    /// Raw character name as it appears in screenplay (e.g., "JOHN (V.O.)")
    public var rawCharacterName: String?

    // MARK: - Speech Logic Metadata

    /// Version of speech logic rules that generated this item
    /// Format: "1.0", "1.1", etc.
    public var ruleVersion: String

    /// Whether character name was included in speakableText
    /// True if this is first dialogue from character in scene
    public var includesCharacterAnnouncement: Bool

    /// Tone hint for TTS (narrative, character, emphasis)
    public var toneHint: ToneHint?

    // MARK: - Audio Generation

    /// Relationship to generated audio (one or more versions)
    @Relationship(deleteRule: .cascade, inverse: \SpeakableAudio.speakableItem)
    public var audioVersions: [SpeakableAudio]

    /// Currently active/preferred audio version
    public var activeAudioID: UUID?

    // MARK: - Status Tracking

    /// Processing status
    public var status: ProcessingStatus

    /// Last updated timestamp
    public var updatedAt: Date

    // MARK: - Initialization

    public init(
        id: UUID = UUID(),
        orderIndex: Int,
        sourceElementID: String,
        sourceElementType: String,
        sceneID: String?,
        speakableText: String,
        characterName: String? = nil,
        rawCharacterName: String? = nil,
        ruleVersion: String,
        includesCharacterAnnouncement: Bool = false,
        toneHint: ToneHint? = nil,
        status: ProcessingStatus = .textGenerated,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.orderIndex = orderIndex
        self.sourceElementID = sourceElementID
        self.sourceElementType = sourceElementType
        self.sceneID = sceneID
        self.speakableText = speakableText
        self.characterName = characterName
        self.rawCharacterName = rawCharacterName
        self.ruleVersion = ruleVersion
        self.includesCharacterAnnouncement = includesCharacterAnnouncement
        self.toneHint = toneHint
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.audioVersions = []
        self.activeAudioID = nil
    }
}

// MARK: - Supporting Types

public enum ToneHint: String, Codable {
    case narrative      // Scene headings, action lines
    case character      // Dialogue
    case emphasis       // Special emphasis needed
    case parenthetical  // If we decide to speak parentheticals
}

public enum ProcessingStatus: String, Codable {
    case textGenerated      // SpeakableItem created, no audio yet
    case audioQueued        // Queued for audio generation
    case audioGenerating    // Currently generating audio
    case audioComplete      // Audio successfully generated
    case audioFailed        // Audio generation failed
}
```

---

## SpeakableAudio Model

### Linking to SwiftHablare Generated Audio

```swift
@Model
public final class SpeakableAudio {
    // MARK: - Identity

    public var id: UUID
    public var createdAt: Date

    // MARK: - Relationship to SpeakableItem

    /// The SpeakableItem this audio was generated from
    public var speakableItem: SpeakableItem?

    // MARK: - Audio Generation Details

    /// Reference to SwiftHablare GeneratedAudioRecord
    /// This is the ID of the SwiftHablare audio model
    public var hablareAudioID: UUID

    /// TTS provider used (e.g., "ElevenLabs", "Apple", "OpenAI")
    public var providerName: String

    /// Voice ID used for generation
    public var voiceID: String

    /// Voice name (human-readable)
    public var voiceName: String?

    // MARK: - Audio Metadata

    /// Duration in seconds
    public var durationSeconds: Double?

    /// File size in bytes (if stored as file)
    public var fileSizeBytes: Int?

    /// Audio format (e.g., "mp3", "wav", "m4a")
    public var audioFormat: String

    /// Sample rate (e.g., 44100, 48000)
    public var sampleRate: Int?

    // MARK: - Generation Metadata

    /// Cost to generate (in USD or provider credits)
    public var generationCost: Double?

    /// Character count of source text
    public var characterCount: Int

    /// Generation timestamp
    public var generatedAt: Date

    /// TTS generation settings (JSON encoded)
    /// Stores settings like temperature, speed, emotion, etc.
    public var generationSettings: String?

    // MARK: - Status

    /// Whether this audio is the active/preferred version
    public var isActive: Bool

    /// Quality rating (user feedback)
    public var qualityRating: Int?  // 1-5 stars

    /// User notes about this audio version
    public var notes: String?

    // MARK: - Initialization

    public init(
        id: UUID = UUID(),
        hablareAudioID: UUID,
        providerName: String,
        voiceID: String,
        voiceName: String? = nil,
        audioFormat: String,
        characterCount: Int,
        isActive: Bool = true,
        createdAt: Date = Date(),
        generatedAt: Date = Date()
    ) {
        self.id = id
        self.hablareAudioID = hablareAudioID
        self.providerName = providerName
        self.voiceID = voiceID
        self.voiceName = voiceName
        self.audioFormat = audioFormat
        self.characterCount = characterCount
        self.isActive = isActive
        self.createdAt = createdAt
        self.generatedAt = generatedAt
    }
}
```

---

## Integration with SwiftHablare

### SwiftHablare Audio Models (Existing)

From SwiftHablare's existing architecture, we have:

```swift
// Existing SwiftHablare models (reference)
@Model
public class GeneratedAudioRecord {
    public var id: UUID
    public var text: String
    public var provider: String
    public var voiceID: String
    public var audioData: Data?  // Or file reference
    // ... other properties
}
```

### Integration Strategy

**Two-Way Linking**:

1. **SpeakableItem → SpeakableAudio → Hablare Audio**
   ```swift
   // SpeakableItem has relationship to SpeakableAudio
   speakableItem.audioVersions

   // SpeakableAudio stores Hablare audio ID
   speakableAudio.hablareAudioID  // UUID reference
   ```

2. **Query Pattern**:
   ```swift
   // Get all audio for a SpeakableItem
   let audioVersions = speakableItem.audioVersions

   // Get the active audio
   let activeAudio = audioVersions.first(where: { $0.isActive })

   // Fetch actual Hablare audio data
   let hablareDescriptor = FetchDescriptor<GeneratedAudioRecord>(
       predicate: #Predicate { $0.id == activeAudio.hablareAudioID }
   )
   let audioRecord = try context.fetch(hablareDescriptor).first
   let audioData = audioRecord?.audioData
   ```

**Why Separate SpeakableAudio?**
- Allows multiple audio versions (different voices, providers)
- Tracks generation metadata without modifying Hablare models
- Supports A/B testing of different voices
- User can regenerate with different settings

---

## Speech Logic Rules Implementation

### Rule Version 1.0 Specification

```swift
class SpeechLogicRulesV1_0: SpeechLogicRulesProvider {
    let version = "1.0"

    // MARK: - Configuration

    /// Character announcement format template
    let characterAnnouncementFormat = "%@ says:"  // "JOHN says:"

    /// Element types to skip (not speakable)
    let nonSpeakableTypes: Set<String> = [
        "Parenthetical",
        "Transition",
        "Note",
        "Boneyard",
        "Synopsis",
        "Section Heading",
        "Page Break"
    ]

    // MARK: - Processing

    func generateSpeakableItems(
        from elements: [GuionElementModel],
        context: ModelContext
    ) throws -> [SpeakableItem] {
        var items: [SpeakableItem] = []
        var sceneContext = SceneContext()
        var index = 0

        while index < elements.count {
            let element = elements[index]

            // Scene boundary - reset context
            if element.elementType == "Scene Heading" {
                sceneContext = SceneContext(sceneID: element.sceneId ?? "unknown")

                // Generate scene heading item
                if let item = processSceneHeading(element, orderIndex: index) {
                    items.append(item)
                }
                index += 1
                continue
            }

            // Dialogue block - group Character + Dialogue lines
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

            // Single element processing (Action, etc.)
            if !nonSpeakableTypes.contains(element.elementType) {
                if let item = processSingleElement(element, orderIndex: index) {
                    items.append(item)
                }
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

        // 1. Character element
        guard index < elements.count,
              elements[index].elementType == "Character" else {
            return ([], 1)
        }

        let characterElement = elements[index]
        let rawCharacterName = characterElement.elementText
        let normalizedName = normalizeCharacterName(rawCharacterName)
        index += 1

        // 2. Skip optional parenthetical (per rules - not spoken)
        if index < elements.count && elements[index].elementType == "Parenthetical" {
            index += 1
        }

        // 3. Collect all consecutive dialogue lines
        var dialogueLines: [String] = []
        while index < elements.count && elements[index].elementType == "Dialogue" {
            dialogueLines.append(elements[index].elementText)
            index += 1
        }

        guard !dialogueLines.isEmpty else {
            return ([], index - startIndex)
        }

        // 4. Combine dialogue lines
        let combinedDialogue = dialogueLines.joined(separator: " ")

        // 5. Determine if character announcement needed
        let isFirstTimeInScene = !context.hasCharacterSpoken(normalizedName)

        // 6. Build speakable text
        let speakableText: String
        if isFirstTimeInScene {
            speakableText = String(format: characterAnnouncementFormat, rawCharacterName) + " " + combinedDialogue
        } else {
            speakableText = combinedDialogue
        }

        // 7. Create SpeakableItem
        let item = SpeakableItem(
            orderIndex: startIndex,
            sourceElementID: characterElement.sceneId ?? "unknown",
            sourceElementType: "Dialogue",
            sceneID: context.sceneID,
            speakableText: speakableText,
            characterName: normalizedName,
            rawCharacterName: rawCharacterName,
            ruleVersion: version,
            includesCharacterAnnouncement: isFirstTimeInScene,
            toneHint: .character
        )

        // 8. Update context
        context.markCharacterSpoken(normalizedName)
        context.lastSpeaker = normalizedName

        return ([item], index - startIndex)
    }

    private func processSceneHeading(_ element: GuionElementModel, orderIndex: Int) -> SpeakableItem? {
        // Use cached location data if available
        var text = element.elementText

        if let lighting = element.locationLighting,
           let scene = element.locationScene {
            // Transform "INT." -> "Interior"
            let lightingText = lighting == "INT" ? "Interior" : (lighting == "EXT" ? "Exterior" : lighting)
            let timeOfDay = element.locationTimeOfDay ?? ""
            text = "\(lightingText). \(scene). \(timeOfDay)."
        } else {
            // Fallback: basic transformation
            text = text
                .replacingOccurrences(of: "INT.", with: "Interior.")
                .replacingOccurrences(of: "EXT.", with: "Exterior.")
        }

        return SpeakableItem(
            orderIndex: orderIndex,
            sourceElementID: element.sceneId ?? "unknown",
            sourceElementType: "Scene Heading",
            sceneID: element.sceneId,
            speakableText: text,
            ruleVersion: version,
            toneHint: .narrative
        )
    }

    private func processSingleElement(_ element: GuionElementModel, orderIndex: Int) -> SpeakableItem? {
        guard element.elementType == "Action" else {
            return nil
        }

        return SpeakableItem(
            orderIndex: orderIndex,
            sourceElementID: element.sceneId ?? "unknown",
            sourceElementType: element.elementType,
            sceneID: element.sceneId,
            speakableText: element.elementText,
            ruleVersion: version,
            toneHint: .narrative
        )
    }

    private func normalizeCharacterName(_ rawName: String) -> String {
        // Remove modifiers: "JOHN (V.O.)" -> "JOHN"
        let withoutParens = rawName.replacingOccurrences(of: /\s*\([^)]+\)\s*/, with: "")

        // Lowercase for comparison
        return withoutParens.trimmingCharacters(in: .whitespaces).lowercased()
    }
}

// MARK: - Scene Context

struct SceneContext {
    var sceneID: String
    var charactersWhoHaveSpoken: Set<String> = []
    var lastSpeaker: String?

    init(sceneID: String = "") {
        self.sceneID = sceneID
    }

    mutating func markCharacterSpoken(_ name: String) {
        charactersWhoHaveSpoken.insert(name)
    }

    func hasCharacterSpoken(_ name: String) -> Bool {
        charactersWhoHaveSpoken.contains(name)
    }
}
```

---

## Complete Workflow

### 1. Generate SpeakableItems from Screenplay

```swift
@MainActor
class ScreenplayProcessor {
    let context: ModelContext
    let rules = SpeechLogicRulesV1_0()

    func procesScreenplay(documentID: String) async throws -> [SpeakableItem] {
        // 1. Fetch GuionDocument
        let descriptor = FetchDescriptor<GuionDocumentModel>(
            predicate: #Predicate { $0.filename == documentID }
        )
        guard let document = try context.fetch(descriptor).first else {
            throw ProcessingError.documentNotFound
        }

        // 2. Generate SpeakableItems
        let items = try rules.generateSpeakableItems(
            from: document.elements,
            context: context
        )

        // 3. Persist to SwiftData
        for item in items {
            context.insert(item)
        }

        try context.save()

        return items
    }
}
```

### 2. Generate Audio from SpeakableItems

```swift
@MainActor
class AudioGenerator {
    let context: ModelContext
    let audioRequestor: ElevenLabsAudioRequestor  // From SwiftHablare

    func generateAudio(for item: SpeakableItem, voiceID: String) async throws -> SpeakableAudio {
        // 1. Check TTS character limit (e.g., 5000 for ElevenLabs)
        let maxChars = 5000
        var textToSpeak = item.speakableText

        if textToSpeak.count > maxChars {
            // TODO: Implement text splitting logic
            textToSpeak = String(textToSpeak.prefix(maxChars))
        }

        // 2. Generate audio using SwiftHablare
        let audioRecord = try await audioRequestor.generate(
            text: textToSpeak,
            voiceID: voiceID,
            settings: AudioSettings(format: "mp3", sampleRate: 44100)
        )

        // 3. Create SpeakableAudio linking record
        let speakableAudio = SpeakableAudio(
            hablareAudioID: audioRecord.id,
            providerName: "ElevenLabs",
            voiceID: voiceID,
            audioFormat: "mp3",
            characterCount: textToSpeak.count
        )

        // 4. Link to SpeakableItem
        item.audioVersions.append(speakableAudio)
        item.activeAudioID = speakableAudio.id
        item.status = .audioComplete
        item.updatedAt = Date()

        // 5. Save
        context.insert(speakableAudio)
        try context.save()

        return speakableAudio
    }

    func generateAudioForAllItems(_ items: [SpeakableItem], voiceID: String) async throws {
        for (index, item) in items.enumerated() {
            print("Generating audio \(index + 1)/\(items.count)")

            item.status = .audioQueued
            try context.save()

            do {
                _ = try await generateAudio(for: item, voiceID: voiceID)
            } catch {
                item.status = .audioFailed
                try context.save()
                print("Failed to generate audio for item \(item.id): \(error)")
            }
        }
    }
}
```

### 3. Playback Query

```swift
func playScreenplay(documentID: String) async throws {
    // 1. Fetch all SpeakableItems for screenplay, ordered
    let descriptor = FetchDescriptor<SpeakableItem>(
        predicate: #Predicate { $0.sourceElementID.contains(documentID) },
        sortBy: [SortDescriptor(\.orderIndex)]
    )
    let items = try context.fetch(descriptor)

    // 2. For each item, get active audio
    for item in items {
        guard let activeAudioID = item.activeAudioID,
              let activeAudio = item.audioVersions.first(where: { $0.id == activeAudioID }) else {
            print("No audio for item: \(item.speakableText)")
            continue
        }

        // 3. Fetch Hablare audio data
        let audioDescriptor = FetchDescriptor<GeneratedAudioRecord>(
            predicate: #Predicate { $0.id == activeAudio.hablareAudioID }
        )
        guard let audioRecord = try context.fetch(audioDescriptor).first else {
            print("Audio record not found")
            continue
        }

        // 4. Play audio
        playAudio(audioRecord.audioData)
    }
}
```

---

## Query Examples

### Get all items for a scene

```swift
let sceneItems = try context.fetch(
    FetchDescriptor<SpeakableItem>(
        predicate: #Predicate { $0.sceneID == "scene-1" },
        sortBy: [SortDescriptor(\.orderIndex)]
    )
)
```

### Get all dialogue from a character

```swift
let johnDialogue = try context.fetch(
    FetchDescriptor<SpeakableItem>(
        predicate: #Predicate { $0.characterName == "john" },
        sortBy: [SortDescriptor(\.orderIndex)]
    )
)
```

### Get items needing audio generation

```swift
let pendingItems = try context.fetch(
    FetchDescriptor<SpeakableItem>(
        predicate: #Predicate { $0.status == .textGenerated }
    )
)
```

### Get items with failed audio

```swift
let failedItems = try context.fetch(
    FetchDescriptor<SpeakableItem>(
        predicate: #Predicate { $0.status == .audioFailed }
    )
)
```

---

## Schema Migration Considerations

### Version 1.0 → 1.1 Example

If speech logic rules change:

```swift
// Detect items generated with old rules
let oldItems = try context.fetch(
    FetchDescriptor<SpeakableItem>(
        predicate: #Predicate { $0.ruleVersion != "1.1" }
    )
)

// Option A: Regenerate all
for item in oldItems {
    // Delete old item and audio
    context.delete(item)
}
// Re-run processing with v1.1 rules

// Option B: Update in place
for item in oldItems {
    // Apply rule changes to existing item
    item.ruleVersion = "1.1"
    // Invalidate audio
    item.status = .textGenerated
    item.activeAudioID = nil
}
```

---

## Next Steps

1. ✅ Model design complete
2. 🔜 Implement SpeakableItem and SpeakableAudio models in SwiftHablare
3. 🔜 Implement SpeechLogicRulesV1_0 processor
4. 🔜 Add character normalization logic
5. 🔜 Integrate with Hablare audio generation
6. 🔜 Build test suite with sample screenplay
7. 🔜 Add TTS character limit handling and text splitting

---

## Change Log

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-10-16 | Initial model design based on user requirements |
