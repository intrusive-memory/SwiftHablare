# Screenplay Speech System - Development Methodology

## Document Purpose

This document defines the phased development methodology with test-driven development (TDD) and quality gates for implementing the screenplay-to-speech system across all four design documents.

**Version**: 1.0
**Date**: 2025-10-16

---

## Overview

### Test-Driven Development Approach

**Philosophy**: Write tests BEFORE implementation code.

**Workflow**:
1. **Red** - Write failing test that defines desired behavior
2. **Green** - Write minimal code to make test pass
3. **Refactor** - Improve code while keeping tests green
4. **Repeat** - Next feature/test

**Benefits**:
- Tests serve as executable specifications
- Forces clear thinking about requirements
- High test coverage by design
- Prevents regression
- Documentation via tests

---

## Quality Gates

Each phase has defined **quality gates** that must pass before proceeding:

### Gate Requirements

1. ✅ **All Tests Pass** - 100% pass rate, no skipped tests
2. ✅ **Coverage Target Met** - Minimum coverage threshold (varies by phase)
3. ✅ **No Compiler Warnings** - Swift 6 strict concurrency compliant
4. ✅ **Documentation Complete** - All public APIs documented
5. ✅ **Code Review Approved** - Manual review checklist passed

**Gate Failure** = Phase cannot proceed until resolved.

---

## Four-Document Integration

### Document 1: SwiftGuion Integration Layer
**File**: `SWIFTGUION_INTEGRATION_ANALYSIS.md`
**Purpose**: Integration with SwiftGuion models
**Module**: `SwiftHablare/SwiftGuionIntegration/`

### Document 2: SpeakableItem Data Models
**File**: `SPEAKABLE_ITEM_MODEL_DESIGN.md`
**Purpose**: Core data models and speech logic
**Module**: `SwiftHablare/ScreenplaySpeech/Models/`

### Document 3: UI & Workflow
**File**: `SCREENPLAY_UI_WORKFLOW_DESIGN.md`
**Purpose**: Task system and UI components
**Module**: `SwiftHablare/ScreenplaySpeech/UI/`

### Document 4: Sample Application
**File**: `SAMPLE_APP_DESIGN.md`
**Purpose**: Integration showcase app
**Module**: `Examples/Hablare/`

---

## Development Phases

### Phase Overview

| Phase | Focus | Documents | Duration | Coverage Target |
|-------|-------|-----------|----------|-----------------|
| 1 | Models & Logic | Doc 2 | 1-2 days | 95% |
| 2 | SwiftGuion Integration | Doc 1 | 1-2 days | 90% |
| 3 | Task System | Doc 3 (partial) | 1 day | 90% |
| 4 | UI Components | Doc 3 (complete) | 2-3 days | 80% |
| 5 | Sample App | Doc 4 | 2-3 days | 70% |
| 6 | Integration Testing | All | 1-2 days | 85% overall |
| 7 | Polish & Documentation | All | 1 day | N/A |

---

## Phase 1: Core Models & Speech Logic

### Scope (Document 2)

**Implement**:
- `SpeakableItem` SwiftData model
- `SpeakableAudio` SwiftData model
- `CharacterVoiceMapping` SwiftData model
- `SceneContext` struct
- `SpeechLogicRulesV1_0` class
- Character normalization logic

**Quality Gate**: 95% test coverage

---

### Phase 1A: SpeakableItem Model

#### Tests to Write FIRST

**File**: `Tests/SwiftHablareTests/ScreenplaySpeech/Models/SpeakableItemTests.swift`

```swift
import XCTest
import SwiftData
@testable import SwiftHablare

@MainActor
final class SpeakableItemTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() async throws {
        container = try ModelContainer(
            for: SpeakableItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = ModelContext(container)
    }

    // MARK: - Initialization Tests

    func testSpeakableItemCreation() throws {
        // GIVEN
        let item = SpeakableItem(
            orderIndex: 0,
            sourceElementID: "scene-1",
            sourceElementType: "Dialogue",
            sceneID: "scene-1",
            speakableText: "JOHN says: Hello there",
            characterName: "john",
            rawCharacterName: "JOHN",
            ruleVersion: "1.0",
            includesCharacterAnnouncement: true,
            toneHint: .character
        )

        // WHEN
        context.insert(item)
        try context.save()

        // THEN
        XCTAssertNotNil(item.id)
        XCTAssertEqual(item.orderIndex, 0)
        XCTAssertEqual(item.speakableText, "JOHN says: Hello there")
        XCTAssertEqual(item.characterName, "john")
        XCTAssertEqual(item.status, .textGenerated)
        XCTAssertTrue(item.includesCharacterAnnouncement)
    }

    func testSpeakableItemPersistence() throws {
        // GIVEN
        let item = SpeakableItem(
            orderIndex: 1,
            sourceElementID: "scene-1",
            sourceElementType: "Action",
            sceneID: "scene-1",
            speakableText: "John enters the room.",
            ruleVersion: "1.0",
            toneHint: .narrative
        )

        context.insert(item)
        try context.save()
        let itemID = item.id

        // WHEN - Fetch in new context
        let newContext = ModelContext(container)
        let descriptor = FetchDescriptor<SpeakableItem>(
            predicate: #Predicate { $0.id == itemID }
        )
        let fetched = try newContext.fetch(descriptor).first

        // THEN
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.speakableText, "John enters the room.")
        XCTAssertEqual(fetched?.toneHint, .narrative)
    }

    func testSpeakableItemOrdering() throws {
        // GIVEN
        let items = [
            SpeakableItem(orderIndex: 2, sourceElementID: "s1", sourceElementType: "Action", speakableText: "Third", ruleVersion: "1.0"),
            SpeakableItem(orderIndex: 0, sourceElementID: "s1", sourceElementType: "Action", speakableText: "First", ruleVersion: "1.0"),
            SpeakableItem(orderIndex: 1, sourceElementID: "s1", sourceElementType: "Action", speakableText: "Second", ruleVersion: "1.0")
        ]

        for item in items {
            context.insert(item)
        }
        try context.save()

        // WHEN
        let descriptor = FetchDescriptor<SpeakableItem>(
            sortBy: [SortDescriptor(\.orderIndex)]
        )
        let sorted = try context.fetch(descriptor)

        // THEN
        XCTAssertEqual(sorted.count, 3)
        XCTAssertEqual(sorted[0].speakableText, "First")
        XCTAssertEqual(sorted[1].speakableText, "Second")
        XCTAssertEqual(sorted[2].speakableText, "Third")
    }

    func testSpeakableItemStatusTransitions() throws {
        // GIVEN
        let item = SpeakableItem(
            orderIndex: 0,
            sourceElementID: "s1",
            sourceElementType: "Dialogue",
            speakableText: "Test",
            ruleVersion: "1.0"
        )
        context.insert(item)

        // WHEN/THEN - Status progression
        XCTAssertEqual(item.status, .textGenerated)

        item.status = .audioQueued
        XCTAssertEqual(item.status, .audioQueued)

        item.status = .audioGenerating
        XCTAssertEqual(item.status, .audioGenerating)

        item.status = .audioComplete
        XCTAssertEqual(item.status, .audioComplete)
    }

    func testSpeakableItemQueryByRuleVersion() throws {
        // GIVEN
        let v1Item = SpeakableItem(orderIndex: 0, sourceElementID: "s1", sourceElementType: "Action", speakableText: "V1", ruleVersion: "1.0")
        let v2Item = SpeakableItem(orderIndex: 1, sourceElementID: "s1", sourceElementType: "Action", speakableText: "V2", ruleVersion: "2.0")

        context.insert(v1Item)
        context.insert(v2Item)
        try context.save()

        // WHEN
        let descriptor = FetchDescriptor<SpeakableItem>(
            predicate: #Predicate { $0.ruleVersion == "1.0" }
        )
        let v1Items = try context.fetch(descriptor)

        // THEN
        XCTAssertEqual(v1Items.count, 1)
        XCTAssertEqual(v1Items[0].speakableText, "V1")
    }

    func testSpeakableItemQueryByStatus() throws {
        // GIVEN
        let pending = SpeakableItem(orderIndex: 0, sourceElementID: "s1", sourceElementType: "Action", speakableText: "Pending", ruleVersion: "1.0")
        let complete = SpeakableItem(orderIndex: 1, sourceElementID: "s1", sourceElementType: "Action", speakableText: "Complete", ruleVersion: "1.0")
        complete.status = .audioComplete

        context.insert(pending)
        context.insert(complete)
        try context.save()

        // WHEN
        let descriptor = FetchDescriptor<SpeakableItem>(
            predicate: #Predicate { $0.status == .textGenerated }
        )
        let pendingItems = try context.fetch(descriptor)

        // THEN
        XCTAssertEqual(pendingItems.count, 1)
        XCTAssertEqual(pendingItems[0].speakableText, "Pending")
    }
}
```

#### Implementation Steps

1. ✅ Write tests above (RED)
2. ✅ Implement `SpeakableItem` model to pass tests (GREEN)
3. ✅ Refactor if needed
4. ✅ Run tests - must be 100% pass

---

### Phase 1B: SpeakableAudio Model

#### Tests to Write FIRST

**File**: `Tests/SwiftHablareTests/ScreenplaySpeech/Models/SpeakableAudioTests.swift`

```swift
import XCTest
import SwiftData
@testable import SwiftHablare

@MainActor
final class SpeakableAudioTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() async throws {
        container = try ModelContainer(
            for: SpeakableItem.self, SpeakableAudio.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = ModelContext(container)
    }

    func testSpeakableAudioCreation() throws {
        // GIVEN
        let hablareID = UUID()
        let audio = SpeakableAudio(
            hablareAudioID: hablareID,
            providerName: "ElevenLabs",
            voiceID: "voice-123",
            voiceName: "Emma",
            audioFormat: "mp3",
            characterCount: 100
        )

        // WHEN
        context.insert(audio)
        try context.save()

        // THEN
        XCTAssertNotNil(audio.id)
        XCTAssertEqual(audio.hablareAudioID, hablareID)
        XCTAssertEqual(audio.providerName, "ElevenLabs")
        XCTAssertEqual(audio.voiceID, "voice-123")
        XCTAssertTrue(audio.isActive)
    }

    func testSpeakableAudioRelationship() throws {
        // GIVEN
        let item = SpeakableItem(
            orderIndex: 0,
            sourceElementID: "s1",
            sourceElementType: "Dialogue",
            speakableText: "Test",
            ruleVersion: "1.0"
        )

        let audio = SpeakableAudio(
            hablareAudioID: UUID(),
            providerName: "Apple",
            voiceID: "Samantha",
            audioFormat: "aac",
            characterCount: 50
        )

        // WHEN
        item.audioVersions.append(audio)
        context.insert(item)
        context.insert(audio)
        try context.save()

        // THEN
        XCTAssertEqual(item.audioVersions.count, 1)
        XCTAssertEqual(item.audioVersions[0].id, audio.id)
        XCTAssertNotNil(audio.speakableItem)
        XCTAssertEqual(audio.speakableItem?.id, item.id)
    }

    func testMultipleAudioVersions() throws {
        // GIVEN
        let item = SpeakableItem(
            orderIndex: 0,
            sourceElementID: "s1",
            sourceElementType: "Dialogue",
            speakableText: "Test",
            ruleVersion: "1.0"
        )

        let audio1 = SpeakableAudio(hablareAudioID: UUID(), providerName: "ElevenLabs", voiceID: "v1", audioFormat: "mp3", characterCount: 50)
        let audio2 = SpeakableAudio(hablareAudioID: UUID(), providerName: "Apple", voiceID: "v2", audioFormat: "aac", characterCount: 50)

        // WHEN
        item.audioVersions.append(audio1)
        item.audioVersions.append(audio2)
        audio1.isActive = true
        audio2.isActive = false

        context.insert(item)
        try context.save()

        // THEN
        XCTAssertEqual(item.audioVersions.count, 2)
        let activeAudio = item.audioVersions.first { $0.isActive }
        XCTAssertNotNil(activeAudio)
        XCTAssertEqual(activeAudio?.providerName, "ElevenLabs")
    }

    func testCascadeDelete() throws {
        // GIVEN
        let item = SpeakableItem(orderIndex: 0, sourceElementID: "s1", sourceElementType: "Dialogue", speakableText: "Test", ruleVersion: "1.0")
        let audio = SpeakableAudio(hablareAudioID: UUID(), providerName: "Apple", voiceID: "v1", audioFormat: "aac", characterCount: 50)

        item.audioVersions.append(audio)
        context.insert(item)
        try context.save()

        let audioID = audio.id

        // WHEN - Delete item
        context.delete(item)
        try context.save()

        // THEN - Audio should be deleted too
        let descriptor = FetchDescriptor<SpeakableAudio>(
            predicate: #Predicate { $0.id == audioID }
        )
        let found = try context.fetch(descriptor)
        XCTAssertTrue(found.isEmpty)
    }
}
```

---

### Phase 1C: Character Normalization

#### Tests to Write FIRST

**File**: `Tests/SwiftHablareTests/ScreenplaySpeech/CharacterNormalizerTests.swift`

```swift
import XCTest
@testable import SwiftHablare

final class CharacterNormalizerTests: XCTestCase {
    var normalizer: CharacterNormalizer!

    override func setUp() {
        normalizer = CharacterNormalizer()
    }

    func testBasicNormalization() {
        XCTAssertEqual(normalizer.normalize("JOHN"), "john")
        XCTAssertEqual(normalizer.normalize("Sarah"), "sarah")
        XCTAssertEqual(normalizer.normalize("THE MAYOR"), "the mayor")
    }

    func testVoiceOverModifier() {
        XCTAssertEqual(normalizer.normalize("JOHN (V.O.)"), "john")
        XCTAssertEqual(normalizer.normalize("SARAH (V.O.)"), "sarah")
    }

    func testOffScreenModifier() {
        XCTAssertEqual(normalizer.normalize("JOHN (O.S.)"), "john")
        XCTAssertEqual(normalizer.normalize("SARAH (O.S.)"), "sarah")
    }

    func testContinuedModifier() {
        XCTAssertEqual(normalizer.normalize("JOHN (CONT'D)"), "john")
        XCTAssertEqual(normalizer.normalize("SARAH (CONT'D)"), "sarah")
    }

    func testMultipleModifiers() {
        XCTAssertEqual(normalizer.normalize("JOHN (V.O.) (CONT'D)"), "john")
    }

    func testWhitespaceHandling() {
        XCTAssertEqual(normalizer.normalize("  JOHN  "), "john")
        XCTAssertEqual(normalizer.normalize("JOHN (V.O.) "), "john")
    }

    func testUserDefinedAliases() {
        // GIVEN
        normalizer.userDefinedAliases["JOHN (V.O.)"] = "john"
        normalizer.userDefinedAliases["YOUNG JOHN"] = "john"

        // THEN
        XCTAssertEqual(normalizer.normalize("JOHN (V.O.)"), "john")
        XCTAssertEqual(normalizer.normalize("YOUNG JOHN"), "john")
    }

    func testConsistency() {
        // Same character different representations should normalize to same
        let variations = ["JOHN", "JOHN (V.O.)", "JOHN (O.S.)", "john", "John"]
        let normalized = variations.map { normalizer.normalize($0) }

        XCTAssertEqual(Set(normalized).count, 1)
        XCTAssertEqual(normalized.first, "john")
    }
}
```

---

### Phase 1D: Speech Logic Rules

#### Tests to Write FIRST

**File**: `Tests/SwiftHablareTests/ScreenplaySpeech/SpeechLogicRulesV1_0Tests.swift`

```swift
import XCTest
import SwiftData
@testable import SwiftHablare

@MainActor
final class SpeechLogicRulesV1_0Tests: XCTestCase {
    var rules: SpeechLogicRulesV1_0!
    var context: SceneContext!

    override func setUp() {
        rules = SpeechLogicRulesV1_0()
        context = SceneContext(sceneID: "scene-1")
    }

    // MARK: - Scene Heading Tests

    func testSceneHeadingTransformation_InteriorDay() {
        // GIVEN
        let element = createMockElement(
            type: "Scene Heading",
            text: "INT. COFFEE SHOP - DAY",
            locationLighting: "INT",
            locationScene: "COFFEE SHOP",
            locationTimeOfDay: "DAY"
        )

        // WHEN
        let item = rules.processSceneHeading(element, orderIndex: 0)

        // THEN
        XCTAssertNotNil(item)
        XCTAssertEqual(item?.speakableText, "Interior. COFFEE SHOP. DAY.")
        XCTAssertEqual(item?.toneHint, .narrative)
    }

    func testSceneHeadingTransformation_ExteriorNight() {
        // GIVEN
        let element = createMockElement(
            type: "Scene Heading",
            text: "EXT. PARK - NIGHT",
            locationLighting: "EXT",
            locationScene: "PARK",
            locationTimeOfDay: "NIGHT"
        )

        // WHEN
        let item = rules.processSceneHeading(element, orderIndex: 0)

        // THEN
        XCTAssertEqual(item?.speakableText, "Exterior. PARK. NIGHT.")
    }

    // MARK: - Character Announcement Tests

    func testCharacterAnnouncement_FirstTimeInScene() {
        // GIVEN
        let elements = [
            createMockElement(type: "Character", text: "JOHN"),
            createMockElement(type: "Dialogue", text: "Hello there.")
        ]

        // WHEN
        let (items, _) = rules.processDialogueBlock(
            startIndex: 0,
            elements: elements,
            context: &context
        )

        // THEN
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].speakableText, "JOHN says: Hello there.")
        XCTAssertTrue(items[0].includesCharacterAnnouncement)
        XCTAssertTrue(context.hasCharacterSpoken("john"))
    }

    func testCharacterAnnouncement_SecondLineNoAnnouncement() {
        // GIVEN - First dialogue
        let elements1 = [
            createMockElement(type: "Character", text: "JOHN"),
            createMockElement(type: "Dialogue", text: "First line.")
        ]
        _ = rules.processDialogueBlock(startIndex: 0, elements: elements1, context: &context)

        // GIVEN - Second dialogue same scene
        let elements2 = [
            createMockElement(type: "Character", text: "JOHN"),
            createMockElement(type: "Dialogue", text: "Second line.")
        ]

        // WHEN
        let (items, _) = rules.processDialogueBlock(
            startIndex: 0,
            elements: elements2,
            context: &context
        )

        // THEN
        XCTAssertEqual(items[0].speakableText, "Second line.")
        XCTAssertFalse(items[0].includesCharacterAnnouncement)
    }

    func testCharacterAnnouncement_DifferentCharacter() {
        // GIVEN - JOHN speaks first
        let elements1 = [
            createMockElement(type: "Character", text: "JOHN"),
            createMockElement(type: "Dialogue", text: "Hello.")
        ]
        _ = rules.processDialogueBlock(startIndex: 0, elements: elements1, context: &context)

        // GIVEN - SARAH speaks (different character)
        let elements2 = [
            createMockElement(type: "Character", text: "SARAH"),
            createMockElement(type: "Dialogue", text: "Hi there.")
        ]

        // WHEN
        let (items, _) = rules.processDialogueBlock(
            startIndex: 0,
            elements: elements2,
            context: &context
        )

        // THEN - SARAH gets announcement (first time)
        XCTAssertEqual(items[0].speakableText, "SARAH says: Hi there.")
        XCTAssertTrue(items[0].includesCharacterAnnouncement)
    }

    func testCharacterAnnouncement_AlternatingCharacters() {
        // GIVEN - JOHN speaks
        var elements = [createMockElement(type: "Character", text: "JOHN"), createMockElement(type: "Dialogue", text: "Line 1.")]
        _ = rules.processDialogueBlock(startIndex: 0, elements: elements, context: &context)

        // SARAH speaks
        elements = [createMockElement(type: "Character", text: "SARAH"), createMockElement(type: "Dialogue", text: "Line 2.")]
        _ = rules.processDialogueBlock(startIndex: 0, elements: elements, context: &context)

        // JOHN speaks again
        elements = [createMockElement(type: "Character", text: "JOHN"), createMockElement(type: "Dialogue", text: "Line 3.")]

        // WHEN
        let (items, _) = rules.processDialogueBlock(startIndex: 0, elements: elements, context: &context)

        // THEN - JOHN already announced in this scene, no announcement
        XCTAssertEqual(items[0].speakableText, "Line 3.")
        XCTAssertFalse(items[0].includesCharacterAnnouncement)
    }

    // MARK: - Dialogue Grouping Tests

    func testDialogueGrouping_MultipleLines() {
        // GIVEN
        let elements = [
            createMockElement(type: "Character", text: "JOHN"),
            createMockElement(type: "Dialogue", text: "I can't believe this."),
            createMockElement(type: "Dialogue", text: "We need to leave."),
            createMockElement(type: "Dialogue", text: "Now.")
        ]

        // WHEN
        let (items, consumed) = rules.processDialogueBlock(
            startIndex: 0,
            elements: elements,
            context: &context
        )

        // THEN
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].speakableText, "JOHN says: I can't believe this. We need to leave. Now.")
        XCTAssertEqual(consumed, 4)
    }

    func testDialogueGrouping_WithParenthetical() {
        // GIVEN
        let elements = [
            createMockElement(type: "Character", text: "JOHN"),
            createMockElement(type: "Parenthetical", text: "(whispering)"),
            createMockElement(type: "Dialogue", text: "We need to go.")
        ]

        // WHEN
        let (items, consumed) = rules.processDialogueBlock(
            startIndex: 0,
            elements: elements,
            context: &context
        )

        // THEN - Parenthetical skipped, not spoken
        XCTAssertEqual(items[0].speakableText, "JOHN says: We need to go.")
        XCTAssertEqual(consumed, 3)
    }

    // MARK: - Character Modifier Tests

    func testCharacterModifier_VoiceOver() {
        // GIVEN
        let elements = [
            createMockElement(type: "Character", text: "JOHN (V.O.)"),
            createMockElement(type: "Dialogue", text: "This is my story.")
        ]

        // WHEN
        let (items, _) = rules.processDialogueBlock(
            startIndex: 0,
            elements: elements,
            context: &context
        )

        // THEN
        XCTAssertEqual(items[0].characterName, "john")  // Normalized
        XCTAssertEqual(items[0].rawCharacterName, "JOHN (V.O.)")  // Original preserved
        XCTAssertEqual(items[0].speakableText, "JOHN (V.O.) says: This is my story.")
    }

    func testCharacterModifier_SameCharacterDifferentModifiers() {
        // GIVEN - JOHN (V.O.)
        var elements = [createMockElement(type: "Character", text: "JOHN (V.O.)"), createMockElement(type: "Dialogue", text: "Line 1.")]
        _ = rules.processDialogueBlock(startIndex: 0, elements: elements, context: &context)

        // GIVEN - JOHN (no modifier)
        elements = [createMockElement(type: "Character", text: "JOHN"), createMockElement(type: "Dialogue", text: "Line 2.")]

        // WHEN
        let (items, _) = rules.processDialogueBlock(startIndex: 0, elements: elements, context: &context)

        // THEN - Both normalize to "john", so no announcement
        XCTAssertEqual(items[0].speakableText, "Line 2.")
        XCTAssertFalse(items[0].includesCharacterAnnouncement)
    }

    // MARK: - Action Line Tests

    func testActionLine_Speakable() {
        // GIVEN
        let element = createMockElement(
            type: "Action",
            text: "John enters the room, looking around nervously."
        )

        // WHEN
        let item = rules.processSingleElement(element, orderIndex: 0)

        // THEN
        XCTAssertNotNil(item)
        XCTAssertEqual(item?.speakableText, "John enters the room, looking around nervously.")
        XCTAssertEqual(item?.toneHint, .narrative)
    }

    // MARK: - Non-Speakable Elements Tests

    func testNonSpeakableElements() {
        let nonSpeakable = ["Parenthetical", "Transition", "Note", "Boneyard", "Synopsis"]

        for type in nonSpeakable {
            let element = createMockElement(type: type, text: "Should not be spoken")
            let item = rules.processSingleElement(element, orderIndex: 0)
            XCTAssertNil(item, "\(type) should not be speakable")
        }
    }

    // MARK: - Helper Methods

    private func createMockElement(
        type: String,
        text: String,
        locationLighting: String? = nil,
        locationScene: String? = nil,
        locationTimeOfDay: String? = nil
    ) -> GuionElementModel {
        let element = GuionElementModel(
            elementText: text,
            elementType: type,
            isCentered: false,
            isDualDialogue: false
        )
        element.locationLighting = locationLighting
        element.locationScene = locationScene
        element.locationTimeOfDay = locationTimeOfDay
        return element
    }
}
```

---

### Phase 1 Quality Gate

**Must Pass Before Phase 2**:

1. ✅ All 50+ tests pass (100% pass rate)
2. ✅ Test coverage ≥ 95% for:
   - SpeakableItem model
   - SpeakableAudio model
   - CharacterNormalizer
   - SpeechLogicRulesV1_0
3. ✅ SwiftData models save/fetch correctly
4. ✅ Character normalization handles all edge cases
5. ✅ Speech logic rules match specification exactly
6. ✅ No compiler warnings
7. ✅ All public APIs documented

**Gate Commands**:
```bash
swift test --enable-code-coverage
xcrun llvm-cov report .build/debug/SwiftHablarePackageTests.xctest/Contents/MacOS/SwiftHablarePackageTests --instr-profile .build/debug/codecov/default.profdata
```

**Expected Output**: Coverage ≥ 95%

---

## Phase 2: SwiftGuion Integration

### Scope (Document 1)

**Implement**:
- Mock GuionElementModel for testing (if not available)
- Element iteration logic
- Dialogue block grouping
- Scene boundary detection

**Quality Gate**: 90% test coverage

---

### Phase 2A: GuionElementModel Mocking

#### Tests to Write FIRST

**File**: `Tests/SwiftHablareTests/SwiftGuionIntegration/MockGuionElementTests.swift`

```swift
import XCTest
import SwiftData
@testable import SwiftHablare

@MainActor
final class MockGuionElementTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() async throws {
        container = try ModelContainer(
            for: GuionDocumentModel.self, GuionElementModel.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = ModelContext(container)
    }

    func testCreateMockScreenplay() throws {
        // GIVEN
        let document = GuionDocumentModel(
            filename: "Test.fountain",
            rawContent: "",
            suppressSceneNumbers: false
        )

        let sceneHeading = GuionElementModel(
            elementText: "INT. COFFEE SHOP - DAY",
            elementType: "Scene Heading",
            isCentered: false,
            isDualDialogue: false
        )
        sceneHeading.sceneId = "scene-1"
        sceneHeading.locationLighting = "INT"
        sceneHeading.locationScene = "COFFEE SHOP"
        sceneHeading.locationTimeOfDay = "DAY"

        document.elements.append(sceneHeading)

        // WHEN
        context.insert(document)
        try context.save()

        // THEN
        XCTAssertEqual(document.elements.count, 1)
        XCTAssertEqual(document.elements[0].elementType, "Scene Heading")
    }

    func testMockDialogueSequence() throws {
        // GIVEN
        let document = createMockDocument()

        let character = GuionElementModel(elementText: "JOHN", elementType: "Character", isCentered: false, isDualDialogue: false)
        let dialogue = GuionElementModel(elementText: "Hello there.", elementType: "Dialogue", isCentered: false, isDualDialogue: false)

        document.elements.append(character)
        document.elements.append(dialogue)

        context.insert(document)
        try context.save()

        // WHEN
        let elements = document.elements

        // THEN
        XCTAssertEqual(elements.count, 2)
        XCTAssertEqual(elements[0].elementType, "Character")
        XCTAssertEqual(elements[1].elementType, "Dialogue")
    }

    func testElementOrdering() throws {
        // GIVEN
        let document = createMockDocument()
        document.elements = [
            createElement(type: "Scene Heading", text: "INT. ROOM - DAY"),
            createElement(type: "Action", text: "John enters."),
            createElement(type: "Character", text: "JOHN"),
            createElement(type: "Dialogue", text: "Hello.")
        ]

        context.insert(document)
        try context.save()

        // WHEN
        let ordered = document.elements

        // THEN - Order preserved
        XCTAssertEqual(ordered[0].elementType, "Scene Heading")
        XCTAssertEqual(ordered[1].elementType, "Action")
        XCTAssertEqual(ordered[2].elementType, "Character")
        XCTAssertEqual(ordered[3].elementType, "Dialogue")
    }

    private func createMockDocument() -> GuionDocumentModel {
        GuionDocumentModel(filename: "Test.fountain", rawContent: "", suppressSceneNumbers: false)
    }

    private func createElement(type: String, text: String) -> GuionElementModel {
        GuionElementModel(elementText: text, elementType: type, isCentered: false, isDualDialogue: false)
    }
}
```

---

### Phase 2B: Full Screenplay Processing

#### Tests to Write FIRST

**File**: `Tests/SwiftHablareTests/SwiftGuionIntegration/ScreenplayProcessingTests.swift`

```swift
import XCTest
import SwiftData
@testable import SwiftHablare

@MainActor
final class ScreenplayProcessingTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!
    var processor: ScreenplayToSpeechProcessor!

    override func setUp() async throws {
        // Setup model container with all models
        let schema = Schema([
            GuionDocumentModel.self,
            GuionElementModel.self,
            SpeakableItem.self,
            SpeakableAudio.self
        ])

        container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        context = ModelContext(container)

        processor = ScreenplayToSpeechProcessor(
            context: context,
            rulesProvider: SpeechLogicRulesV1_0()
        )
    }

    func testProcessSimpleScene() async throws {
        // GIVEN
        let screenplay = createSimpleScreenplay()
        context.insert(screenplay)
        try context.save()

        // WHEN
        let items = try await processor.processScreenplay(screenplay)

        // THEN
        XCTAssertEqual(items.count, 4)  // Scene heading + action + 2 dialogue

        // Scene heading
        XCTAssertEqual(items[0].sourceElementType, "Scene Heading")
        XCTAssertTrue(items[0].speakableText.contains("Interior"))

        // Action
        XCTAssertEqual(items[1].sourceElementType, "Action")

        // Dialogue 1 (JOHN first time)
        XCTAssertEqual(items[2].characterName, "john")
        XCTAssertTrue(items[2].includesCharacterAnnouncement)

        // Dialogue 2 (SARAH first time)
        XCTAssertEqual(items[3].characterName, "sarah")
        XCTAssertTrue(items[3].includesCharacterAnnouncement)
    }

    func testProcessMultipleScenes() async throws {
        // GIVEN
        let screenplay = createMultiSceneScreenplay()
        context.insert(screenplay)
        try context.save()

        // WHEN
        let items = try await processor.processScreenplay(screenplay)

        // THEN - Count items
        let sceneHeadings = items.filter { $0.sourceElementType == "Scene Heading" }
        XCTAssertEqual(sceneHeadings.count, 2)

        // Characters should be re-announced in Scene 2
        let scene1Items = items.filter { $0.sceneID == "scene-1" }
        let scene2Items = items.filter { $0.sceneID == "scene-2" }

        XCTAssertGreaterThan(scene1Items.count, 0)
        XCTAssertGreaterThan(scene2Items.count, 0)

        // Find JOHN's first line in each scene
        let johnScene1 = scene1Items.first { $0.characterName == "john" }
        let johnScene2 = scene2Items.first { $0.characterName == "john" }

        XCTAssertTrue(johnScene1?.includesCharacterAnnouncement ?? false)
        XCTAssertTrue(johnScene2?.includesCharacterAnnouncement ?? false)
    }

    func testProcessComplexDialogue() async throws {
        // GIVEN - Multi-line dialogue with parenthetical
        let screenplay = createComplexDialogueScreenplay()
        context.insert(screenplay)
        try context.save()

        // WHEN
        let items = try await processor.processScreenplay(screenplay)

        // THEN
        let johnDialogue = items.first { $0.characterName == "john" }
        XCTAssertNotNil(johnDialogue)

        // Should combine all dialogue lines
        XCTAssertTrue(johnDialogue!.speakableText.contains("Line 1"))
        XCTAssertTrue(johnDialogue!.speakableText.contains("Line 2"))
        XCTAssertTrue(johnDialogue!.speakableText.contains("Line 3"))

        // Should NOT include parenthetical
        XCTAssertFalse(johnDialogue!.speakableText.contains("whispering"))
    }

    func testSceneBoundaryDetection() async throws {
        // GIVEN
        let screenplay = createTwoSceneScreenplay()
        context.insert(screenplay)
        try context.save()

        // WHEN
        let items = try await processor.processScreenplay(screenplay)

        // THEN
        let sceneIDs = Set(items.compactMap { $0.sceneID })
        XCTAssertEqual(sceneIDs.count, 2)
    }

    func testCharacterConsistencyAcrossScenes() async throws {
        // GIVEN
        let screenplay = createScreenplayWithRecurringCharacter()
        context.insert(screenplay)
        try context.save()

        // WHEN
        let items = try await processor.processScreenplay(screenplay)

        // THEN
        let johnItems = items.filter { $0.characterName == "john" }
        XCTAssertGreaterThan(johnItems.count, 2)

        // All items should have same normalized name
        XCTAssertTrue(johnItems.allSatisfy { $0.characterName == "john" })
    }

    // MARK: - Helper Methods

    private func createSimpleScreenplay() -> GuionDocumentModel {
        let doc = GuionDocumentModel(filename: "Simple.fountain", rawContent: "", suppressSceneNumbers: false)

        doc.elements = [
            createElement(type: "Scene Heading", text: "INT. ROOM - DAY", sceneId: "scene-1", lighting: "INT", location: "ROOM", time: "DAY"),
            createElement(type: "Action", text: "John enters."),
            createElement(type: "Character", text: "JOHN"),
            createElement(type: "Dialogue", text: "Hello."),
            createElement(type: "Character", text: "SARAH"),
            createElement(type: "Dialogue", text: "Hi there.")
        ]

        return doc
    }

    private func createMultiSceneScreenplay() -> GuionDocumentModel {
        let doc = GuionDocumentModel(filename: "MultiScene.fountain", rawContent: "", suppressSceneNumbers: false)

        doc.elements = [
            // Scene 1
            createElement(type: "Scene Heading", text: "INT. ROOM - DAY", sceneId: "scene-1"),
            createElement(type: "Character", text: "JOHN"),
            createElement(type: "Dialogue", text: "Scene 1 line."),

            // Scene 2
            createElement(type: "Scene Heading", text: "EXT. PARK - DAY", sceneId: "scene-2"),
            createElement(type: "Character", text: "JOHN"),
            createElement(type: "Dialogue", text: "Scene 2 line.")
        ]

        return doc
    }

    private func createComplexDialogueScreenplay() -> GuionDocumentModel {
        let doc = GuionDocumentModel(filename: "Complex.fountain", rawContent: "", suppressSceneNumbers: false)

        doc.elements = [
            createElement(type: "Scene Heading", text: "INT. ROOM - DAY", sceneId: "scene-1"),
            createElement(type: "Character", text: "JOHN"),
            createElement(type: "Parenthetical", text: "(whispering)"),
            createElement(type: "Dialogue", text: "Line 1."),
            createElement(type: "Dialogue", text: "Line 2."),
            createElement(type: "Dialogue", text: "Line 3.")
        ]

        return doc
    }

    private func createTwoSceneScreenplay() -> GuionDocumentModel {
        let doc = GuionDocumentModel(filename: "TwoScenes.fountain", rawContent: "", suppressSceneNumbers: false)

        doc.elements = [
            createElement(type: "Scene Heading", text: "INT. ROOM - DAY", sceneId: "scene-1"),
            createElement(type: "Action", text: "Action in scene 1."),
            createElement(type: "Scene Heading", text: "EXT. PARK - DAY", sceneId: "scene-2"),
            createElement(type: "Action", text: "Action in scene 2.")
        ]

        return doc
    }

    private func createScreenplayWithRecurringCharacter() -> GuionDocumentModel {
        let doc = GuionDocumentModel(filename: "Recurring.fountain", rawContent: "", suppressSceneNumbers: false)

        doc.elements = [
            createElement(type: "Scene Heading", text: "INT. ROOM - DAY", sceneId: "scene-1"),
            createElement(type: "Character", text: "JOHN"),
            createElement(type: "Dialogue", text: "Line 1."),
            createElement(type: "Character", text: "JOHN (V.O.)"),
            createElement(type: "Dialogue", text: "Line 2."),
            createElement(type: "Character", text: "JOHN"),
            createElement(type: "Dialogue", text: "Line 3.")
        ]

        return doc
    }

    private func createElement(
        type: String,
        text: String,
        sceneId: String? = nil,
        lighting: String? = nil,
        location: String? = nil,
        time: String? = nil
    ) -> GuionElementModel {
        let element = GuionElementModel(elementText: text, elementType: type, isCentered: false, isDualDialogue: false)
        element.sceneId = sceneId
        element.locationLighting = lighting
        element.locationScene = location
        element.locationTimeOfDay = time
        return element
    }
}
```

---

### Phase 2 Quality Gate

**Must Pass Before Phase 3**:

1. ✅ All 30+ integration tests pass
2. ✅ Test coverage ≥ 90% for integration module
3. ✅ Correctly processes multi-scene screenplays
4. ✅ Character tracking works across scenes
5. ✅ Dialogue grouping handles all edge cases
6. ✅ Scene boundary detection accurate
7. ✅ No memory leaks with large screenplays

---

## Phase 3: Task System

### Scope (Document 3 - Partial)

**Implement**:
- `TaskProgress` observable model
- `ScreenplayTask` protocol
- `SpeakableItemGenerationTask`
- `AudioGenerationTask` (stub)
- `ScreenplayTaskCoordinator`

**Quality Gate**: 90% test coverage

---

### Phase 3A: Task Progress

#### Tests to Write FIRST

**File**: `Tests/SwiftHablareTests/ScreenplaySpeech/Tasks/TaskProgressTests.swift`

```swift
import XCTest
@testable import SwiftHablare

@MainActor
final class TaskProgressTests: XCTestCase {
    var progress: TaskProgress!

    override func setUp() {
        progress = TaskProgress()
    }

    func testInitialState() {
        XCTAssertEqual(progress.currentStep, 0)
        XCTAssertEqual(progress.totalSteps, 0)
        XCTAssertEqual(progress.currentMessage, "")
        XCTAssertFalse(progress.isRunning)
        XCTAssertFalse(progress.isCancelled)
        XCTAssertNil(progress.error)
    }

    func testProgressFraction() {
        progress.totalSteps = 100
        progress.currentStep = 50

        XCTAssertEqual(progress.progressFraction, 0.5, accuracy: 0.01)
    }

    func testProgressPercentage() {
        progress.totalSteps = 100
        progress.currentStep = 75

        XCTAssertEqual(progress.progressPercentage, 75)
    }

    func testProgressFraction_ZeroSteps() {
        progress.totalSteps = 0
        progress.currentStep = 0

        XCTAssertEqual(progress.progressFraction, 0.0)
    }

    func testStateTransitions() {
        XCTAssertFalse(progress.isRunning)

        progress.isRunning = true
        XCTAssertTrue(progress.isRunning)

        progress.isCancelled = true
        XCTAssertTrue(progress.isCancelled)
    }
}
```

---

### Phase 3B: SpeakableItem Generation Task

#### Tests to Write FIRST

**File**: `Tests/SwiftHablareTests/ScreenplaySpeech/Tasks/SpeakableItemGenerationTaskTests.swift`

```swift
import XCTest
import SwiftData
@testable import SwiftHablare

@MainActor
final class SpeakableItemGenerationTaskTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() async throws {
        let schema = Schema([
            GuionDocumentModel.self,
            GuionElementModel.self,
            SpeakableItem.self
        ])

        container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        context = ModelContext(container)
    }

    func testTaskExecution_Simple() async throws {
        // GIVEN
        let screenplay = createSimpleScreenplay()
        context.insert(screenplay)
        try context.save()

        let task = SpeakableItemGenerationTask(
            context: context,
            document: screenplay
        )

        // WHEN
        try await task.execute()

        // THEN
        XCTAssertFalse(task.progress.isRunning)
        XCTAssertFalse(task.progress.isCancelled)
        XCTAssertNil(task.progress.error)

        // Verify items created
        let descriptor = FetchDescriptor<SpeakableItem>(
            sortBy: [SortDescriptor(\.orderIndex)]
        )
        let items = try context.fetch(descriptor)

        XCTAssertGreaterThan(items.count, 0)
    }

    func testTaskProgress_Updates() async throws {
        // GIVEN
        let screenplay = createLargeScreenplay(elementCount: 100)
        context.insert(screenplay)
        try context.save()

        let task = SpeakableItemGenerationTask(
            context: context,
            document: screenplay
        )

        // WHEN
        let progressUpdates = [Int]()
        Task {
            try await task.execute()
        }

        // Wait a bit for progress
        try await Task.sleep(for: .milliseconds(100))

        // THEN
        XCTAssertGreaterThan(task.progress.currentStep, 0)
        XCTAssertEqual(task.progress.totalSteps, 100)
    }

    func testTaskCancellation() async throws {
        // GIVEN
        let screenplay = createLargeScreenplay(elementCount: 1000)
        context.insert(screenplay)
        try context.save()

        let task = SpeakableItemGenerationTask(
            context: context,
            document: screenplay
        )

        // WHEN
        Task {
            try await task.execute()
        }

        // Cancel after brief delay
        try await Task.sleep(for: .milliseconds(50))
        task.cancel()

        // Wait for cancellation to process
        try await Task.sleep(for: .milliseconds(100))

        // THEN
        XCTAssertTrue(task.progress.isCancelled)
    }

    func testTaskPersistsItems() async throws {
        // GIVEN
        let screenplay = createSimpleScreenplay()
        context.insert(screenplay)
        try context.save()

        let task = SpeakableItemGenerationTask(
            context: context,
            document: screenplay
        )

        // WHEN
        try await task.execute()

        // THEN - Items persisted
        let newContext = ModelContext(container)
        let descriptor = FetchDescriptor<SpeakableItem>()
        let items = try newContext.fetch(descriptor)

        XCTAssertGreaterThan(items.count, 0)
    }

    // MARK: - Helpers

    private func createSimpleScreenplay() -> GuionDocumentModel {
        let doc = GuionDocumentModel(filename: "Test.fountain", rawContent: "", suppressSceneNumbers: false)

        doc.elements = [
            createElement(type: "Scene Heading", text: "INT. ROOM - DAY"),
            createElement(type: "Character", text: "JOHN"),
            createElement(type: "Dialogue", text: "Hello.")
        ]

        return doc
    }

    private func createLargeScreenplay(elementCount: Int) -> GuionDocumentModel {
        let doc = GuionDocumentModel(filename: "Large.fountain", rawContent: "", suppressSceneNumbers: false)

        doc.elements = (0..<elementCount).map { i in
            createElement(type: "Action", text: "Action \(i)")
        }

        return doc
    }

    private func createElement(type: String, text: String) -> GuionElementModel {
        GuionElementModel(elementText: text, elementType: type, isCentered: false, isDualDialogue: false)
    }
}
```

---

### Phase 3 Quality Gate

**Must Pass Before Phase 4**:

1. ✅ All 20+ task tests pass
2. ✅ Test coverage ≥ 90% for task system
3. ✅ Progress updates correctly during execution
4. ✅ Cancellation works reliably
5. ✅ No race conditions
6. ✅ Memory safe with large tasks

---

## Phase 4: UI Components

### Scope (Document 3 - Complete)

**Implement**:
- `ScreenplaySpeechView` (tabbed container)
- `CharacterToVoiceMappingView`
- `VoiceToCharacterMappingView`
- `GeneratedAudioListView`
- `TaskProgressOverlay`
- CharacterMappingGenerator

**Quality Gate**: 80% test coverage (UI testing is lower coverage)

---

### Phase 4 Testing Strategy

**UI Preview Testing** (Manual):
```swift
#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: SpeakableItem.self,
        configurations: config
    )

    let context = container.mainContext

    // Create sample data
    let item = SpeakableItem(...)
    context.insert(item)

    return ScreenplaySpeechView(screenplay: mockScreenplay)
        .modelContainer(container)
}
```

**Snapshot Testing** (Optional):
- Use swift-snapshot-testing library
- Capture UI state at key points
- Verify layout consistency

**Integration Tests**:

**File**: `Tests/SwiftHablareTests/ScreenplaySpeech/UI/CharacterMappingIntegrationTests.swift`

```swift
import XCTest
import SwiftData
@testable import SwiftHablare

@MainActor
final class CharacterMappingIntegrationTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!
    var generator: CharacterMappingGenerator!

    override func setUp() async throws {
        let schema = Schema([
            SpeakableItem.self,
            CharacterVoiceMapping.self
        ])

        container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        context = ModelContext(container)
        generator = CharacterMappingGenerator(context: context)
    }

    func testGenerateMappingsFromSpeakableItems() throws {
        // GIVEN - SpeakableItems with characters
        let items = [
            createSpeakableItem(characterName: "john", rawName: "JOHN"),
            createSpeakableItem(characterName: "john", rawName: "JOHN (V.O.)"),
            createSpeakableItem(characterName: "sarah", rawName: "SARAH"),
            createSpeakableItem(characterName: "sarah", rawName: "SARAH")
        ]

        for item in items {
            context.insert(item)
        }
        try context.save()

        // WHEN
        let mappings = try generator.generateMappings(for: "test-screenplay")

        // THEN
        XCTAssertEqual(mappings.count, 2)  // john and sarah

        let johnMapping = mappings.first { $0.characterName == "john" }
        XCTAssertNotNil(johnMapping)
        XCTAssertEqual(johnMapping?.dialogueCount, 2)
        XCTAssertEqual(johnMapping?.aliases.count, 2)
        XCTAssertTrue(johnMapping?.aliases.contains("JOHN") ?? false)
        XCTAssertTrue(johnMapping?.aliases.contains("JOHN (V.O.)") ?? false)
    }

    func testMappingPersistence() throws {
        // GIVEN
        let items = [
            createSpeakableItem(characterName: "john", rawName: "JOHN")
        ]

        for item in items {
            context.insert(item)
        }
        try context.save()

        // WHEN
        _ = try generator.generateMappings(for: "test-screenplay")

        // THEN - Fetch in new context
        let newContext = ModelContext(container)
        let descriptor = FetchDescriptor<CharacterVoiceMapping>()
        let mappings = try newContext.fetch(descriptor)

        XCTAssertEqual(mappings.count, 1)
    }

    private func createSpeakableItem(characterName: String, rawName: String) -> SpeakableItem {
        SpeakableItem(
            orderIndex: 0,
            sourceElementID: "test-screenplay",
            sourceElementType: "Dialogue",
            sceneID: "scene-1",
            speakableText: "Test",
            characterName: characterName,
            rawCharacterName: rawName,
            ruleVersion: "1.0"
        )
    }
}
```

---

### Phase 4 Quality Gate

**Must Pass Before Phase 5**:

1. ✅ All 15+ UI tests pass
2. ✅ Test coverage ≥ 80% for UI logic
3. ✅ Character mapping generation works
4. ✅ Views render without crashes
5. ✅ Preview targets compile
6. ✅ No SwiftUI state warnings

---

## Phase 5: Sample Application

### Scope (Document 4)

**Implement**:
- `HablareApp.swift`
- `HablareSplitView.swift`
- `ScreenplayListView.swift`
- `GuionScreenplayView.swift` (placeholder)
- Sample screenplay data

**Quality Gate**: 70% test coverage (app-level testing)

---

### Phase 5 Testing Strategy

**End-to-End Tests**:

**File**: `Examples/Hablare/HablareTests/EndToEndTests.swift`

```swift
import XCTest
import SwiftData
@testable import Hablare

@MainActor
final class EndToEndTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() async throws {
        // Create full model container
        container = try createTestContainer()
        context = ModelContext(container)
    }

    func testCompleteWorkflow() async throws {
        // GIVEN - Sample screenplay
        let screenplay = createSampleScreenplay()
        context.insert(screenplay)
        try context.save()

        // WHEN - Generate speakable items
        let task = SpeakableItemGenerationTask(
            context: context,
            document: screenplay
        )
        try await task.execute()

        // THEN - Items created
        let itemDescriptor = FetchDescriptor<SpeakableItem>(
            sortBy: [SortDescriptor(\.orderIndex)]
        )
        let items = try context.fetch(itemDescriptor)

        XCTAssertGreaterThan(items.count, 0)

        // AND - Character mappings can be generated
        let generator = CharacterMappingGenerator(context: context)
        let mappings = try generator.generateMappings(for: screenplay.filename ?? "")

        XCTAssertGreaterThan(mappings.count, 0)
    }

    func testSampleScreenplayLoading() throws {
        // GIVEN - Empty database
        let descriptor = FetchDescriptor<GuionDocumentModel>()
        let existing = try context.fetch(descriptor)
        XCTAssertEqual(existing.count, 0)

        // WHEN - Load sample
        let sample = createSampleScreenplay()
        context.insert(sample)
        try context.save()

        // THEN
        let loaded = try context.fetch(descriptor)
        XCTAssertEqual(loaded.count, 1)
        XCTAssertGreaterThan(loaded[0].elements.count, 0)
    }

    private func createSampleScreenplay() -> GuionDocumentModel {
        // Create same sample as app
        let doc = GuionDocumentModel(
            filename: "Sample Screenplay.fountain",
            rawContent: "",
            suppressSceneNumbers: false
        )

        doc.elements = [
            // ... sample elements
        ]

        return doc
    }

    private func createTestContainer() throws -> ModelContainer {
        let schema = Schema([
            GuionDocumentModel.self,
            GuionElementModel.self,
            SpeakableItem.self,
            SpeakableAudio.self,
            CharacterVoiceMapping.self
        ])

        return try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
    }
}
```

---

### Phase 5 Quality Gate

**Must Pass Before Phase 6**:

1. ✅ All 10+ E2E tests pass
2. ✅ App launches without crashes
3. ✅ Sample screenplay loads correctly
4. ✅ All tabs render
5. ✅ Task buttons functional
6. ✅ No memory leaks

---

## Phase 6: Integration Testing

### Cross-Module Integration

**Test Scenarios**:
1. SwiftGuion → SpeakableItems → Audio generation
2. Character mapping → Voice assignment → Audio generation
3. UI interactions → Task execution → Data persistence
4. Screenplay edits → Regeneration workflow

**File**: `Tests/SwiftHablareTests/Integration/FullIntegrationTests.swift`

```swift
import XCTest
import SwiftData
@testable import SwiftHablare

@MainActor
final class FullIntegrationTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    func testFullPipeline() async throws {
        // GIVEN - Complete screenplay
        let screenplay = createFullTestScreenplay()
        context.insert(screenplay)
        try context.save()

        // STEP 1: Generate SpeakableItems
        let task1 = SpeakableItemGenerationTask(context: context, document: screenplay)
        try await task1.execute()

        let itemsDescriptor = FetchDescriptor<SpeakableItem>(
            sortBy: [SortDescriptor(\.orderIndex)]
        )
        let items = try context.fetch(itemsDescriptor)

        XCTAssertGreaterThan(items.count, 0)

        // STEP 2: Generate character mappings
        let generator = CharacterMappingGenerator(context: context)
        let mappings = try generator.generateMappings(for: screenplay.filename ?? "")

        XCTAssertGreaterThan(mappings.count, 0)

        // STEP 3: Assign voices
        for mapping in mappings {
            mapping.voiceID = "test-voice-\(mapping.characterName)"
            mapping.providerName = "TestProvider"
            mapping.isManuallyAssigned = true
        }
        try context.save()

        // STEP 4: Verify voice assignments persisted
        let mappingsDescriptor = FetchDescriptor<CharacterVoiceMapping>()
        let persistedMappings = try context.fetch(mappingsDescriptor)

        XCTAssertTrue(persistedMappings.allSatisfy { $0.voiceID != nil })
    }

    // Additional integration scenarios...
}
```

---

### Phase 6 Quality Gate

**Must Pass Before Phase 7**:

1. ✅ All 20+ integration tests pass
2. ✅ Overall test coverage ≥ 85%
3. ✅ No integration failures
4. ✅ Performance acceptable (< 1s for typical screenplay)
5. ✅ Memory usage stable

---

## Phase 7: Polish & Documentation

### Final QA

**Checklist**:
- [ ] All tests pass (500+ tests)
- [ ] Code coverage ≥ 85%
- [ ] All public APIs documented
- [ ] README updated
- [ ] Examples/Hablare README created
- [ ] CONTRIBUTING.md updated
- [ ] No compiler warnings
- [ ] Swift 6 strict concurrency compliant
- [ ] Performance benchmarks recorded

---

## Test Organization

### Directory Structure

```
Tests/SwiftHablareTests/
├── ScreenplaySpeech/
│   ├── Models/
│   │   ├── SpeakableItemTests.swift
│   │   ├── SpeakableAudioTests.swift
│   │   └── CharacterVoiceMappingTests.swift
│   ├── Logic/
│   │   ├── CharacterNormalizerTests.swift
│   │   └── SpeechLogicRulesV1_0Tests.swift
│   ├── Tasks/
│   │   ├── TaskProgressTests.swift
│   │   ├── SpeakableItemGenerationTaskTests.swift
│   │   └── AudioGenerationTaskTests.swift
│   └── UI/
│       ├── CharacterMappingIntegrationTests.swift
│       └── TaskCoordinatorTests.swift
├── SwiftGuionIntegration/
│   ├── MockGuionElementTests.swift
│   └── ScreenplayProcessingTests.swift
└── Integration/
    └── FullIntegrationTests.swift

Examples/Hablare/HablareTests/
└── EndToEndTests.swift
```

---

## TDD Workflow Summary

### Per Feature

1. **Write Test** (RED)
   - Define expected behavior
   - Write failing test
   - Verify test fails for right reason

2. **Implement** (GREEN)
   - Write minimal code to pass test
   - Run test until green
   - Don't over-engineer

3. **Refactor** (REFACTOR)
   - Improve code quality
   - Keep tests passing
   - Document public APIs

4. **Gate Check**
   - Run all tests
   - Check coverage
   - Resolve warnings
   - Review code

### Per Phase

1. Write ALL tests for phase
2. Verify all tests FAIL appropriately
3. Implement to make tests pass
4. Refactor for quality
5. Run quality gate checks
6. Only proceed if gate passes

---

## Coverage Targets

### Module-Specific Targets

| Module | Target | Rationale |
|--------|--------|-----------|
| Models | 95% | Critical data integrity |
| Speech Logic | 95% | Core business logic |
| SwiftGuion Integration | 90% | Complex parsing logic |
| Task System | 90% | Concurrency-critical |
| UI Components | 80% | Visual testing supplemented by manual |
| Sample App | 70% | Integration focus |

### Overall Target

**85% total coverage** across all modules.

---

## Continuous Integration

### CI Pipeline

```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run Tests
        run: swift test --enable-code-coverage
      - name: Generate Coverage Report
        run: xcrun llvm-cov report ...
      - name: Verify Coverage
        run: |
          coverage=$(xcrun llvm-cov report ... | grep TOTAL | awk '{print $4}')
          if [ "${coverage%.*}" -lt 85 ]; then
            echo "Coverage below 85%: $coverage"
            exit 1
          fi
```

---

## Change Log

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-10-16 | Initial methodology with TDD approach and quality gates |
