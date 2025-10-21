# Screenplay Speech UI Decisions

## Document Purpose

This document captures critical UI/UX decisions made during the planning phase of the Screenplay Speech UI sprint. These decisions resolve ambiguities identified in the workflow design and provide implementation guidance.

**Version**: 1.0
**Date**: 2025-10-18
**Related Documents**:
- [SCREENPLAY_UI_WORKFLOW_DESIGN.md](SCREENPLAY_UI_WORKFLOW_DESIGN.md)
- [SCREENPLAY_UI_SPRINT_METHODOLOGY.md](SCREENPLAY_UI_SPRINT_METHODOLOGY.md)

---

## Critical Decisions

### 1. Voice Settings Configuration ✅ RESOLVED

**Decision**: Voice settings are **provider-specific** and exposed via provider-supplied settings palette.

**Rationale**:
- Different providers have different capabilities (ElevenLabs: stability/clarity, Apple: rate/pitch)
- Each provider knows its own parameters best
- Avoids one-size-fits-all settings UI

**Implementation**:
- Each voice provider implements a `VoiceSettingsView` protocol/component
- Settings are applied at speech generation time
- Settings UI is displayed inline or in a drawer when provider is selected

**Example Providers**:
- **ElevenLabs**: stability, clarity, style, speaker boost
- **Apple**: rate, pitch, volume
- **OpenAI**: speed, voice model variant

**UI Location**: Settings palette appears when generating audio or in character mapping view

---

### 2. Provider Selection Mechanism ✅ RESOLVED

**Decision**: Provider selection is **GLOBAL** with a switch at the top of the voice generation palette.

**Rationale**:
- Simplifies UX - one provider at a time
- Most users will use one provider for consistency
- Per-character provider switching adds complexity without clear value

**Implementation**:
```swift
// Top of ScreenplaySpeechView
Picker("Voice Provider", selection: $selectedProvider) {
    ForEach(availableProviders) { provider in
        Text(provider.name).tag(provider.id)
    }
}
.pickerStyle(.segmented)
```

**Behavior**:
- Switching provider updates available voices in character mapping
- Existing character-voice mappings are preserved but may show "unavailable" if voice doesn't exist in new provider
- Audio generation uses currently selected provider

---

### 3. Background Tasks Palette ✅ NEW REQUIREMENT

**Decision**: Implement a **separate floating palette** for background task management, distinct from the voice generation palette.

**Architecture**:
```
┌─────────────────────────────────────────┐
│  Main Window                             │
│  ┌─────────────┬────────────────────┐   │
│  │ SwiftGuion  │ Voice Generation   │   │
│  │ Editor      │ Palette (Tabs)     │   │
│  └─────────────┴────────────────────┘   │
│                                          │
│  ┌────────────────────────────────┐     │
│  │ Background Tasks (Floating)    │     │
│  │ • Task 1: [Progress] [Cancel]  │     │
│  │ • Task 2: Queued               │     │
│  └────────────────────────────────┘     │
└─────────────────────────────────────────┘
```

**Features**:
1. **Task List**:
   - Shows queued and in-progress tasks
   - Each task has: name, progress bar, status, cancel button
   - Completed tasks auto-remove after 2 seconds
   - Failed tasks remain with error visible

2. **Error Display**:
   - Errors shown in **red text** underneath the task
   - Clear, user-friendly error messages
   - Technical details available via disclosure triangle

3. **Blocking Indicators**:
   - Tasks that block others show a 🔒 icon
   - Tooltip explains what's blocked
   - Example: "Generate Items" must complete before "Generate Audio"

4. **Queuing**:
   - Tasks can be queued while another is running
   - Queue order visible
   - Users can cancel queued tasks

**UI Components**:
```swift
struct BackgroundTasksPalette: View {
    @Binding var tasks: [BackgroundTask]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Label("Background Tasks", systemImage: "list.bullet.rectangle")
                    .font(.headline)
                Spacer()
                Button("Clear Completed") { /* ... */ }
                    .disabled(!hasCompletedTasks)
            }

            // Task list
            ForEach(tasks) { task in
                BackgroundTaskRow(task: task)
            }
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(12)
        .shadow(radius: 8)
    }
}

struct BackgroundTaskRow: View {
    @Bindable var task: BackgroundTask

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Task info
            HStack {
                if task.isBlocking {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.orange)
                }

                Text(task.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                if task.state == .running {
                    Button("Cancel") { task.cancel() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }

            // Progress
            if task.state == .running {
                ProgressView(value: task.progress) {
                    Text("\(task.currentStep)/\(task.totalSteps) - \(task.message)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Error
            if let error = task.error {
                HStack(alignment: .top, spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.caption)

                    Text(error.userMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            // Status badge
            StatusBadge(state: task.state)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}
```

**Behavior**:
- Palette can be shown/hidden via toggle button
- Position: Bottom-right corner of window by default
- Draggable to reposition
- Remembers position across sessions

---

### 4. Cancellation Behavior ✅ RESOLVED

**Decision**: Cancelled tasks **preserve all generated data** up to the point of cancellation.

**Rationale**:
- User may want to review partial results
- Allows resumption from last checkpoint
- No data loss from accidental cancellation

**Implementation**:
- SpeakableItems generated before cancellation remain in database
- Audio files generated before cancellation are kept
- Task state changes to `.cancelled` with count of completed items
- UI shows: "Cancelled (42 of 100 items generated)"

**Edge Cases**:
- If item is mid-generation when cancelled, that item is marked `.audioFailed`
- Periodic saves (every 50 items) ensure minimal loss
- Resume functionality can be added later by filtering for `.textGenerated` items

---

### 5. Auto-Assignment of Voices ✅ OUT OF SCOPE

**Decision**: Auto voice assignment is **NOT IMPLEMENTED** in this sprint.

**Rationale**:
- Complex algorithm (gender matching, voice characteristics)
- Requires voice metadata (gender, age, accent) that may not exist
- Manual assignment is more predictable and controllable
- Can be added in future sprint

**Implementation**:
- "Auto-Detect Characters" button only creates CharacterVoiceMapping records
- Voice fields are left nil (unassigned)
- User must manually assign voices via picker
- Empty state guides user to assign voices

**Future Enhancement**:
- Could implement simple heuristics (alphabetical voice assignment)
- Could use voice metadata for smarter matching
- Could remember user's previous assignments per character name

---

### 6. SpeakableItem Screenplay Tracking ✅ RESOLVED

**Decision**: Add `screenplayID` property to `SpeakableItem` to track which screenplay it belongs to.

**Rationale**:
- Current `sourceElementID` (sceneId) doesn't identify the screenplay
- Needed for filtering items by screenplay
- Needed for character mapping generation
- Enables multi-screenplay support

**Implementation**:
```swift
@Model
public final class SpeakableItem {
    // EXISTING PROPERTIES...

    /// NEW: Screenplay this item belongs to
    /// Links to GuionDocumentModel via its ID
    public var screenplayID: String  // GuionDocumentModel.id.uuidString

    // OR if we want a relationship:
    // public var screenplay: GuionDocumentModel?

    // EXISTING PROPERTIES...
}
```

**Migration**:
- Existing SpeakableItems need screenplay ID backfilled
- Could use sourceElementID to trace back to screenplay
- Or mark as "unknown" and require regeneration

**Queries**:
```swift
// Filter items by screenplay
let descriptor = FetchDescriptor<SpeakableItem>(
    predicate: #Predicate { $0.screenplayID == screenplay.id.uuidString },
    sortBy: [SortDescriptor(\.orderIndex)]
)
```

---

## Implementation Impact

### Modified Architecture

**OLD** (from workflow design):
```
ScreenplaySpeechView
└── TaskProgressOverlay (modal)
```

**NEW** (with decisions):
```
Main Window
├── ScreenplaySpeechView (tabbed palette)
│   ├── Provider Picker (global, at top)
│   ├── Voice-to-Character Tab
│   ├── Character-to-Voice Tab
│   ├── Generated Audio Tab
│   └── Export Tab
│
└── BackgroundTasksPalette (floating, separate)
    ├── Task Queue List
    ├── Progress Bars
    ├── Error Display
    └── Blocking Indicators
```

### Updated Component List

**New Components**:
1. `BackgroundTasksPalette` - Floating task manager
2. `BackgroundTaskRow` - Individual task display
3. `BackgroundTask` - Observable task model
4. `ProviderPickerView` - Global provider selector
5. `VoiceSettingsView` - Protocol for provider settings

**Modified Components**:
1. `ScreenplaySpeechView` - Add provider picker, remove modal overlay
2. `SpeakableItem` - Add screenplayID property
3. `CharacterMappingGenerator` - Use screenplayID for filtering

**Removed Components**:
1. ~~`TaskProgressOverlay`~~ - Replaced by BackgroundTasksPalette

---

## Updated Phase Breakdown

### Phase 1: Task Architecture (MODIFIED)
**Add**:
- `BackgroundTask` observable model
- `BackgroundTasksPalette` view
- `BackgroundTaskRow` view

**Remove**:
- ~~`TaskProgressOverlay`~~

### Phase 3: Data Models (MODIFIED)
**Add**:
- `screenplayID` property to `SpeakableItem`
- Migration strategy for existing items

### Phase 4: Core UI (MODIFIED)
**Add**:
- `ProviderPickerView` at top of palette
- Background tasks palette integration

**Remove**:
- ~~Modal overlay~~

### Phase 7: Audio Generation (MODIFIED)
**Add**:
- Provider-specific settings integration
- Settings passed to audio requestor

---

## Open Questions (Lower Priority)

### 1. Background Tasks Palette Persistence
- [ ] Should task history persist across app restarts?
- [ ] How long should completed/failed tasks remain visible?
- [ ] Should there be a "Task History" log?

### 2. Provider Settings Storage
- [ ] Are provider settings saved per-character or globally?
- [ ] Do settings persist across sessions?
- [ ] Should there be "presets" for common configurations?

### 3. Multiple Screenplays
- [ ] Can multiple screenplays be open simultaneously?
- [ ] Does each screenplay get its own palette?
- [ ] How to switch between screenplays' tasks?

### 4. Task Priorities
- [ ] Should users be able to reorder queued tasks?
- [ ] Should certain tasks auto-prioritize?
- [ ] Should blocking tasks always go first?

---

## Deferred Features

These features are explicitly OUT OF SCOPE for this sprint:

1. ✋ Auto voice assignment algorithm
2. ✋ Voice preview/testing before assignment
3. ✋ Character alias editing UI
4. ✋ Multiple audio version management UI
5. ✋ Export functionality (beyond placeholder)
6. ✋ Task resumption after cancellation
7. ✋ Task history/logging
8. ✋ Per-character provider selection
9. ✋ Voice characteristic metadata
10. ✋ Batch operations (regenerate all, delete all)

---

## Design Mockup: Background Tasks Palette

```
┌──────────────────────────────────────────┐
│ 📋 Background Tasks        [Clear ✓]     │
├──────────────────────────────────────────┤
│ 🔒 Generate SpeakableItems               │
│ ━━━━━━━━━━━━━━━━━━━━━ 68%              │
│ 68/100 - Processing Scene Heading...     │
│                              [Cancel]     │
├──────────────────────────────────────────┤
│ ⏸️  Generate Audio (Queued)              │
│ Waiting for SpeakableItems...            │
├──────────────────────────────────────────┤
│ ❌ Export Audiobook (Failed)             │
│ ⚠️  No audio files available             │
│    └─ Generate audio first               │
└──────────────────────────────────────────┘
```

**States**:
- 🔒 = Blocking task
- ━━ = Progress bar
- ⏸️ = Queued
- ✅ = Completed (auto-removes)
- ❌ = Failed
- ⚠️ = Error message

---

## Change Log

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-10-18 | Initial UI decisions document |

---

## Summary of Decisions

| # | Topic | Decision | Impact |
|---|-------|----------|--------|
| 1 | Voice Settings | Provider-specific settings palette | Add VoiceSettingsView protocol |
| 2 | Provider Selection | Global provider picker at top | Add ProviderPickerView component |
| 3 | Task Progress | Separate floating background tasks palette | Replace modal with BackgroundTasksPalette |
| 4 | Cancellation | Preserve partial results | No rollback logic needed |
| 5 | Auto-Assignment | Out of scope | Remove from Phase 5 |
| 6 | Screenplay Tracking | Add screenplayID to SpeakableItem | Model migration required |

**Net Change**: +3 new components, -1 removed component, 1 model change
