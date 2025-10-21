# Screenplay Speech UI Sprint Methodology

## Document Purpose

This document defines a phased, test-driven approach to implementing the screenplay speech UI system as specified in [SCREENPLAY_UI_WORKFLOW_DESIGN.md](SCREENPLAY_UI_WORKFLOW_DESIGN.md).

**Version**: 1.1
**Date**: 2025-10-18
**Related Documents**:
- [SCREENPLAY_UI_WORKFLOW_DESIGN.md](SCREENPLAY_UI_WORKFLOW_DESIGN.md) - UI/Workflow specification
- [SCREENPLAY_UI_DECISIONS.md](SCREENPLAY_UI_DECISIONS.md) - **Critical UI decisions** ⚠️
- [SCREENPLAY_SPEECH_METHODOLOGY.md](SCREENPLAY_SPEECH_METHODOLOGY.md) - Backend methodology
- [SAMPLE_APP_DESIGN.md](SAMPLE_APP_DESIGN.md) - Sample app architecture

---

## Sprint Overview

### Goals
1. Implement complete screenplay speech UI as specified in workflow design
2. Maintain 90%+ test coverage on testable components
3. Use @MainActor throughout (defer concurrency complexity)
4. Follow test-driven development methodology
5. Deliver working UI integrated with existing speech processing backend

### Non-Goals
- Swift 6 strict concurrency compliance (future work)
- Advanced export features (Phase 8 placeholder)
- Voice preview/testing (Phase 8 enhancement)
- Auto voice assignment algorithm (explicitly out of scope per UI decisions)

### Estimated Timeline
- **Total**: 7 phases
- **Estimated Effort**: 16-24 hours
- **Complexity**: Medium-High (SwiftUI + SwiftData integration)

---

## Phase Breakdown

### Phase 1: Task Architecture Foundation ⚡ Priority: CRITICAL
**Goal**: Implement core task execution and progress tracking infrastructure

**⚠️ UPDATED per UI Decisions**: Replace TaskProgressOverlay with BackgroundTasksPalette

#### Requirements
1. `BackgroundTask` @Observable class (replaces TaskProgress)
   - Properties: id, name, state, currentStep, totalSteps, message, error, isBlocking
   - Computed: progressFraction, progressPercentage
   - Methods: execute() async throws, cancel()
   - States: queued, running, completed, failed, cancelled
   - Must be @MainActor

2. `ScreenplayTask` protocol
   - Properties: backgroundTask (BackgroundTask)
   - Methods: execute() async throws, cancel()
   - Must be @MainActor

3. `BackgroundTaskManager` @Observable class (replaces ScreenplayTaskCoordinator)
   - Properties: tasks (array of BackgroundTask), runningTask
   - Methods: enqueue(), cancelTask(), clearCompleted()
   - Automatically runs queued tasks when current completes
   - Must be @MainActor

4. `BackgroundTasksPalette` view
   - Floating palette showing all tasks
   - Progress bars for running tasks
   - Error display in red underneath failed tasks
   - Blocking indicators (🔒 icon)
   - Cancel buttons for running/queued tasks
   - Auto-hides when empty (optional)

#### Testing Strategy
- **Unit Tests**: BackgroundTask state machine, progress calculations
- **Integration Tests**: BackgroundTaskManager lifecycle, queueing, error handling
- **Mock Tasks**: Create simple test task implementations
- **UI Tests**: BackgroundTasksPalette display states

#### Quality Gates
- ✅ All task states tracked correctly (queued → running → completed/failed/cancelled)
- ✅ Progress calculations accurate
- ✅ Error handling comprehensive with user-friendly messages
- ✅ Task queueing works correctly
- ✅ Blocking indicators display properly
- ✅ Cancelled tasks preserve partial data
- ✅ 95%+ coverage on task infrastructure
- ✅ All tests passing

#### Deliverables
```
Sources/SwiftHablare/ScreenplaySpeech/Tasks/
├── BackgroundTask.swift
├── ScreenplayTask.swift
├── BackgroundTaskManager.swift
└── BackgroundTaskRow.swift

Sources/SwiftHablare/ScreenplaySpeech/UI/
└── BackgroundTasksPalette.swift

Tests/SwiftHablareTests/ScreenplaySpeech/Tasks/
├── BackgroundTaskTests.swift
├── BackgroundTaskManagerTests.swift
└── MockScreenplayTask.swift
```

---

### Phase 2: SpeakableItem Generation Task ⚡ Priority: HIGH
**Goal**: Implement screenplay → SpeakableItems task with progress tracking

#### Requirements
1. `SpeakableItemGenerationTask` class
   - Integrates with existing `ScreenplayToSpeechProcessor`
   - Reports progress per element
   - Handles cancellation gracefully
   - Periodic saves (every 50 elements)
   - Must be @MainActor

2. Integration with speech processing backend
   - Reuse existing `SpeechLogicRulesV1_0`
   - Use existing `SceneContext`
   - Match existing element processing logic

#### Testing Strategy
- **Unit Tests**: Task lifecycle, cancellation, progress updates
- **Integration Tests**: Full screenplay processing with progress tracking
- **Performance Tests**: Processing 100+ element screenplay
- **Mock Tests**: Use in-memory ModelContext

#### Quality Gates
- ✅ Processes screenplay correctly (matches existing processor)
- ✅ Progress tracking accurate
- ✅ Cancellation works mid-processing
- ✅ Periodic saves prevent data loss
- ✅ 90%+ coverage
- ✅ All tests passing

#### Deliverables
```
Sources/SwiftHablare/ScreenplaySpeech/Tasks/
└── SpeakableItemGenerationTask.swift

Tests/SwiftHablareTests/ScreenplaySpeech/Tasks/
└── SpeakableItemGenerationTaskTests.swift
```

---

### Phase 3: Data Models & Character Mapping ⚡ Priority: HIGH
**Goal**: Implement character-voice mapping SwiftData model and generation

**⚠️ UPDATED per UI Decisions**: Add screenplayID to SpeakableItem model

#### Requirements
1. **Update `SpeakableItem` model**
   - Add `screenplayID: String` property
   - Links to `GuionDocumentModel.id.uuidString`
   - Migration strategy for existing items
   - Update queries to filter by screenplayID

2. `CharacterVoiceMapping` @Model class
   - All properties as specified in workflow design
   - SwiftData persistence
   - Queries by screenplayID

3. `CharacterMappingGenerator` utility
   - Scans SpeakableItems for characters (filtered by screenplayID)
   - Groups by normalized name
   - Collects aliases
   - Counts dialogue lines
   - Must be @MainActor

#### Testing Strategy
- **Unit Tests**: CharacterVoiceMapping model creation
- **Integration Tests**: CharacterMappingGenerator with real SpeakableItems
- **SwiftData Tests**: Persistence, queries, relationships
- **Edge Cases**: Empty screenplay, single character, 20+ characters

#### Quality Gates
- ✅ Model persists correctly in SwiftData
- ✅ Generator creates correct mappings
- ✅ Aliases collected properly
- ✅ Dialogue counts accurate
- ✅ 90%+ coverage
- ✅ All tests passing

#### Deliverables
```
Sources/SwiftHablare/ScreenplaySpeech/Models/
├── CharacterVoiceMapping.swift
└── CharacterMappingGenerator.swift

Tests/SwiftHablareTests/ScreenplaySpeech/Models/
├── CharacterVoiceMappingTests.swift
└── CharacterMappingGeneratorTests.swift
```

---

### Phase 4: Core UI Scaffolding ⚡ Priority: HIGH
**Goal**: Implement main container, tab structure, and background tasks palette

**⚠️ UPDATED per UI Decisions**: Replace modal overlay with floating palette, add provider picker

#### Requirements
1. `ScreenplaySpeechView` main container
   - **Global provider picker at top** (segmented control or dropdown)
   - TabView with 4 tabs
   - Header with screenplay title
   - Task trigger buttons (disabled while tasks running)
   - Integration with BackgroundTaskManager

2. `ProviderPickerView` component
   - Displays available voice providers (ElevenLabs, Apple, etc.)
   - Segmented control or dropdown style
   - Updates global selected provider
   - Shows current provider status (configured/unconfigured)

3. Integration with `BackgroundTasksPalette` (from Phase 1)
   - Floating palette overlays main window
   - Positioned bottom-right by default
   - Shows/hides via toggle button
   - Displays all tasks from BackgroundTaskManager

4. Placeholder tab views
   - Basic ContentUnavailableView for each tab
   - Proper tab labels and icons

#### Testing Strategy
- **Preview Tests**: Xcode preview compilation
- **Snapshot Tests**: Visual regression (if tooling available)
- **State Tests**: Tab switching, palette show/hide, provider switching
- **Mock Integration**: Use mock BackgroundTaskManager

#### Quality Gates
- ✅ All views compile without errors
- ✅ Xcode previews work
- ✅ Tab navigation functional
- ✅ Provider picker switches providers correctly
- ✅ Background tasks palette displays correctly
- ✅ Task buttons disabled during execution
- ✅ Basic integration with BackgroundTaskManager

#### Deliverables
```
Sources/SwiftHablare/ScreenplaySpeech/UI/
├── ScreenplaySpeechView.swift
├── ProviderPickerView.swift
└── ExportView.swift (placeholder)

Tests/SwiftHablareTests/ScreenplaySpeech/UI/
└── ScreenplaySpeechViewTests.swift

Note: BackgroundTasksPalette delivered in Phase 1
```

---

### Phase 5: Character-Voice Mapping Views ⚡ Priority: MEDIUM
**Goal**: Implement bidirectional character↔voice mapping interfaces

**⚠️ UPDATED per UI Decisions**: Auto-detect creates mappings only, does NOT assign voices

#### Requirements
1. `CharacterToVoiceMappingView`
   - @Query for CharacterVoiceMapping by screenplayID
   - @Query for available voices (filtered by selected provider)
   - List of characters with voice pickers
   - "Auto-Detect Characters" button (creates mappings, voices remain nil)
   - Sort by dialogue count (descending)
   - Empty state guides user to generate items first

2. `CharacterMappingRow` component
   - Character display name
   - Dialogue count badge
   - Voice picker dropdown
   - Manual assignment indicator

3. `VoiceToCharacterMappingView`
   - @Query for Voice models
   - @Query for CharacterVoiceMapping
   - List of voices with assigned characters
   - Character badges

4. `VoiceMappingRow` component
   - Voice name and gender
   - Assigned character badges
   - Empty state message

#### Testing Strategy
- **Preview Tests**: All views with sample data
- **Query Tests**: SwiftData query predicates
- **Interaction Tests**: Voice picker changes, auto-detect
- **Empty State Tests**: No characters, no voices

#### Quality Gates
- ✅ Views display correctly with data
- ✅ Empty states handled gracefully
- ✅ Voice picker updates mapping
- ✅ Auto-detect generates mappings (voices remain nil/unassigned)
- ✅ User can manually assign voices via picker
- ✅ Provider switching updates available voices
- ✅ Sorting works correctly
- ✅ 85%+ coverage on testable logic

#### Deliverables
```
Sources/SwiftHablare/ScreenplaySpeech/UI/
├── CharacterToVoiceMappingView.swift
├── CharacterMappingRow.swift
├── VoiceToCharacterMappingView.swift
└── VoiceMappingRow.swift

Tests/SwiftHablareTests/ScreenplaySpeech/UI/
├── CharacterMappingViewTests.swift
└── VoiceMappingViewTests.swift
```

---

### Phase 6: Audio List & Playback View ⚡ Priority: MEDIUM
**Goal**: Implement SpeakableItems list with playback integration

#### Requirements
1. `GeneratedAudioListView`
   - @Query for SpeakableItems by screenplayID
   - Sort by orderIndex
   - AudioPlayerWidget at top
   - List of items in screenplay order

2. `SpeakableItemRow` component
   - Status icon (5 states: textGenerated, audioQueued, audioGenerating, audioComplete, audioFailed)
   - Speakable text (2 line limit)
   - Metadata badges (character, type, announcement indicator)
   - Play button (if audio complete)

3. Audio playback integration
   - Integration with existing AudioPlayerWidget
   - Fetch GeneratedAudioRecord via SpeakableAudio link
   - Play on row click

#### Testing Strategy
- **Preview Tests**: All status states
- **Query Tests**: Filtering and sorting
- **Integration Tests**: Audio playback trigger
- **Mock Tests**: Mock AudioPlayerManager

#### Quality Gates
- ✅ All status icons display correctly
- ✅ Items sorted by orderIndex
- ✅ Play button triggers audio fetch
- ✅ Empty state handled
- ✅ Metadata displays correctly
- ✅ 85%+ coverage on testable logic

#### Deliverables
```
Sources/SwiftHablare/ScreenplaySpeech/UI/
├── GeneratedAudioListView.swift
└── SpeakableItemRow.swift

Tests/SwiftHablareTests/ScreenplaySpeech/UI/
└── GeneratedAudioListViewTests.swift
```

---

### Phase 7: Audio Generation Task & Integration ⚡ Priority: MEDIUM
**Goal**: Implement audio generation task with provider integration

**⚠️ UPDATED per UI Decisions**: Provider-specific settings, global provider selection

#### Requirements
1. `AudioGenerationTask` class
   - Iterates SpeakableItems (filtered by screenplayID)
   - Calls audio requestor for each item using selected provider
   - Updates item status (.audioQueued → .audioGenerating → .audioComplete/.audioFailed)
   - Creates SpeakableAudio linking records
   - Rate limiting pause between requests
   - Must be @MainActor

2. `VoiceGenerationSettings` struct
   - Provider name, voice ID, voice name
   - Audio format, max characters
   - Provider-specific settings (passed through to provider)

3. `VoiceSettingsView` protocol
   - Each provider implements custom settings UI
   - ElevenLabs: stability, clarity, style
   - Apple: rate, pitch, volume
   - Settings displayed inline or in drawer

4. `AudioRequestorProtocol` protocol
   - Method: generateAudio(text:voice:settings:) async throws -> GeneratedAudioRecord
   - Adapter for existing provider infrastructure

5. Integration with ScreenplaySpeechView
   - Uses globally selected provider
   - Provider-specific settings UI (optional, can use defaults)
   - Trigger audio generation for items with status .textGenerated
   - Respects character-voice mappings

#### Testing Strategy
- **Unit Tests**: Task lifecycle, status transitions
- **Mock Tests**: Mock AudioRequestorProtocol
- **Integration Tests**: Full generation cycle with mock provider
- **Error Tests**: API failures, rate limits, character limits

#### Quality Gates
- ✅ Task executes correctly
- ✅ Status transitions accurate
- ✅ SpeakableAudio records created
- ✅ Error handling robust
- ✅ Rate limiting works
- ✅ 90%+ coverage
- ✅ All tests passing

#### Deliverables
```
Sources/SwiftHablare/ScreenplaySpeech/Tasks/
├── AudioGenerationTask.swift
├── VoiceGenerationSettings.swift
├── AudioRequestorProtocol.swift
└── VoiceSettingsView.swift (protocol)

Sources/SwiftHablare/ScreenplaySpeech/Providers/
├── ElevenLabsSettingsView.swift (example implementation)
└── AppleVoiceSettingsView.swift (example implementation)

Tests/SwiftHablareTests/ScreenplaySpeech/Tasks/
├── AudioGenerationTaskTests.swift
└── MockAudioRequestor.swift
```

---

### Phase 8: Polish, Documentation & Future Work ⚡ Priority: LOW
**Goal**: Final QA, documentation, and identify future enhancements

#### Requirements
1. **Code Review & Refactoring**
   - Review all UI code for consistency
   - Extract common components
   - Optimize SwiftData queries
   - Fix compiler warnings

2. **Documentation**
   - Add inline documentation to all public interfaces
   - Document SwiftData relationships
   - Create usage examples
   - Update README with UI sprint completion

3. **Accessibility**
   - VoiceOver labels
   - Keyboard navigation
   - Dynamic type support

4. **Future Enhancements** (Not in scope, document only)
   - Export functionality (audiobook, ZIP)
   - Batch regeneration
   - Character alias editing UI
   - Voice preview/testing
   - Custom voice settings per character
   - Retry failed audio generation

#### Testing Strategy
- **Accessibility Tests**: VoiceOver navigation
- **Performance Tests**: Large screenplay (500+ items)
- **Manual QA**: Full workflow end-to-end

#### Quality Gates
- ✅ All compiler warnings resolved
- ✅ All public APIs documented
- ✅ Accessibility labels added
- ✅ README updated
- ✅ Future enhancements documented
- ✅ Full workflow tested manually

#### Deliverables
```
- Documentation updates
- README.md updates
- FUTURE_ENHANCEMENTS.md (optional)
```

---

## Testing Strategy

### Unit Testing (90% coverage target)
- **Task Architecture**: TaskProgress, TaskCoordinator
- **Data Models**: CharacterVoiceMapping, generator logic
- **Task Implementations**: SpeakableItemGenerationTask, AudioGenerationTask
- **Utilities**: Character normalization, dialogue grouping

### Integration Testing (85% coverage target)
- **End-to-End Workflows**:
  - Screenplay → SpeakableItems generation
  - Character mapping generation
  - Audio generation (with mocks)
  - Full UI workflow

- **SwiftData Integration**:
  - Model persistence and queries
  - Relationships (SpeakableItem ↔ SpeakableAudio)
  - Cascade deletion

### UI Testing (Manual + Preview)
- **Preview Tests**: All views have working Xcode previews
- **State Tests**: Tab switching, overlay states, task execution
- **Empty States**: All empty state views tested
- **Error States**: Task failures, network errors, API limits

### Performance Testing
- **Large Screenplay**: 500+ elements, 50+ characters
- **Memory**: No leaks during repeated task execution
- **Responsiveness**: UI remains responsive during tasks

---

## Quality Gates Summary

### Phase 1: Task Architecture
- [ ] TaskProgress calculations correct
- [ ] Task lifecycle managed properly
- [ ] Error handling comprehensive
- [ ] 95%+ test coverage
- [ ] All tests passing

### Phase 2: SpeakableItem Generation
- [ ] Processes screenplay correctly
- [ ] Progress accurate
- [ ] Cancellation works
- [ ] 90%+ coverage
- [ ] All tests passing

### Phase 3: Character Mapping
- [ ] Models persist correctly
- [ ] Generator works accurately
- [ ] 90%+ coverage
- [ ] All tests passing

### Phase 4: Core UI
- [ ] All views compile
- [ ] Previews work
- [ ] Navigation functional
- [ ] Basic integration complete

### Phase 5: Mapping Views
- [ ] Views display correctly
- [ ] Empty states handled
- [ ] Pickers update data
- [ ] 85%+ coverage

### Phase 6: Audio List
- [ ] Status icons correct
- [ ] Sorting works
- [ ] Playback triggers
- [ ] 85%+ coverage

### Phase 7: Audio Generation
- [ ] Task executes correctly
- [ ] Status transitions accurate
- [ ] Error handling robust
- [ ] 90%+ coverage

### Phase 8: Polish
- [ ] Warnings resolved
- [ ] Documentation complete
- [ ] Accessibility added
- [ ] README updated

---

## Dependencies & Integration Points

### Existing Systems (Already Implemented)
1. **Speech Processing Backend**
   - `ScreenplayToSpeechProcessor`
   - `SpeechLogicRulesV1_0`
   - `SceneContext`
   - `SpeakableItem` and `SpeakableAudio` models

2. **SwiftHablare Core**
   - `Voice` model
   - `VoiceProviderManager`
   - `AudioPlayerWidget`
   - Audio provider infrastructure (`ElevenLabsProvider`, `AppleVoiceProvider`)

3. **SwiftGuion**
   - `GuionDocumentModel`
   - `GuionElementModel`
   - `FountainParser`

### New Dependencies
- None (uses existing infrastructure)

---

## Risk Assessment

### High Risk
- **SwiftData @Query complexity**: Predicates with enums and complex filters
  - *Mitigation*: Test thoroughly, use workarounds where needed

- **Audio API integration**: Rate limits, character limits, API failures
  - *Mitigation*: Robust error handling, retry logic, graceful degradation

### Medium Risk
- **Performance with large screenplays**: 500+ elements, 50+ characters
  - *Mitigation*: Periodic saves, query optimization, pagination if needed

- **Task cancellation edge cases**: Mid-save, mid-API call
  - *Mitigation*: Comprehensive cancellation tests

### Low Risk
- **UI layout on different screen sizes**: Mostly standard SwiftUI
  - *Mitigation*: Test on multiple screen sizes

---

## Success Criteria

### Functional Requirements
1. ✅ Generate SpeakableItems from screenplay with progress tracking
2. ✅ Auto-detect characters and create voice mappings
3. ✅ Assign voices to characters via UI
4. ✅ Generate audio for SpeakableItems with progress tracking
5. ✅ View and play generated audio in screenplay order
6. ✅ Handle errors gracefully with user feedback

### Technical Requirements
1. ✅ All code on @MainActor (no complex concurrency)
2. ✅ 90%+ test coverage on business logic
3. ✅ 85%+ test coverage on UI-testable components
4. ✅ All SwiftData models tested
5. ✅ All task implementations tested
6. ✅ Zero compiler warnings (or documented as acceptable)

### User Experience
1. ✅ Progress feedback for all long-running operations
2. ✅ Cancel button works reliably
3. ✅ Empty states guide user to next action
4. ✅ Error messages are clear and actionable
5. ✅ UI remains responsive during tasks

---

## Phase Prioritization

### Sprint 1 (Critical Path - 8-12 hours)
1. **Phase 1**: Task Architecture (2-3 hours)
2. **Phase 2**: SpeakableItem Generation Task (2-3 hours)
3. **Phase 3**: Character Mapping Models (2-3 hours)
4. **Phase 4**: Core UI Scaffolding (2-3 hours)

**Goal**: Minimum viable UI that can generate SpeakableItems with progress tracking

### Sprint 2 (Feature Completion - 6-8 hours)
5. **Phase 5**: Character-Voice Mapping Views (2-3 hours)
6. **Phase 6**: Audio List & Playback (2-3 hours)
7. **Phase 7**: Audio Generation Task (2-3 hours)

**Goal**: Full workflow from screenplay to audio playback

### Sprint 3 (Polish - 2-4 hours)
8. **Phase 8**: Polish, Documentation, QA (2-4 hours)

**Goal**: Production-ready UI

---

## Change Log

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-10-18 | Initial UI sprint methodology |
| 1.1 | 2025-10-18 | **Major update based on UI decisions**: Replace TaskProgressOverlay with BackgroundTasksPalette, add ProviderPickerView, add screenplayID to SpeakableItem, clarify auto-detect as detect-only (no auto-assignment), add provider-specific settings |

---

## Appendix: Testing Utilities

### Mock Task for Testing
```swift
@MainActor
class MockScreenplayTask: ScreenplayTask {
    let progress = TaskProgress()
    var shouldFail = false
    var executionDelay: Duration = .milliseconds(100)

    func execute() async throws {
        progress.isRunning = true
        progress.totalSteps = 10

        for i in 1...10 {
            guard !progress.isCancelled else { break }
            progress.currentStep = i
            progress.currentMessage = "Step \(i) of 10"
            try await Task.sleep(for: executionDelay)
        }

        if shouldFail {
            throw TestError.simulatedFailure
        }

        progress.isRunning = false
    }

    func cancel() {
        progress.isCancelled = true
        progress.isRunning = false
    }
}

enum TestError: Error {
    case simulatedFailure
}
```

### Mock Audio Requestor
```swift
@MainActor
class MockAudioRequestor: AudioRequestorProtocol {
    var shouldFail = false
    var requestDelay: Duration = .milliseconds(50)

    func generateAudio(
        text: String,
        voice: String,
        settings: VoiceGenerationSettings
    ) async throws -> GeneratedAudioRecord {
        try await Task.sleep(for: requestDelay)

        if shouldFail {
            throw AudioError.apiFailure
        }

        // Generate mock audio data
        let mockData = Data(repeating: 0, count: 1024)
        return GeneratedAudioRecord(
            id: UUID(),
            audioData: mockData,
            duration: Double(text.count) / 10.0  // ~10 chars/second
        )
    }
}

enum AudioError: Error {
    case apiFailure
}
```

---

## Notes for Implementation

1. **Keep @MainActor Throughout**: Defer Swift 6 strict concurrency work to future sprint
2. **Iterate on Tests**: If tests fail in CI, iterate locally until passing
3. **Use Existing Infrastructure**: Leverage existing audio providers, don't reimplement
4. **SwiftData Best Practices**: Use fetch descriptors, avoid complex predicates
5. **Progress Feedback**: User should never see UI freeze >100ms
6. **Error Messages**: Always user-friendly, never show raw errors
