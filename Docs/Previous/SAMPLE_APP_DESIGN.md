# Hablare Sample App Design

## Document Purpose

This document defines the architecture for the Hablare sample application, which showcases the integration between SwiftGuion screenplay editing and SwiftHablare speech generation.

**Version**: 1.0
**Date**: 2025-10-16
**App Location**: `Examples/Hablare/`

---

## Overview

The Hablare sample app is a **dual-pane showcase application** that demonstrates the complete workflow from screenplay editing to speech synthesis.

### Primary Goals

1. **Showcase SwiftHablare UI Components** - Demonstrate all tabbed interfaces and widgets
2. **Demonstrate SwiftGuion Integration** - Show screenplay editing alongside speech generation
3. **Complete Workflow Example** - End-to-end from screenplay to spoken audio
4. **Reference Implementation** - Provide developers with a working example

---

## Application Architecture

### Split-View Layout

```
┌─────────────────────────────────────────────────────────────────┐
│  Hablare Sample App                                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────────────┬──────────────────────────────┐  │
│  │                          │                              │  │
│  │   SwiftGuion             │   SwiftHablare               │  │
│  │   Screenplay View        │   Tabbed Palette             │  │
│  │                          │                              │  │
│  │  • Screenplay editor     │  Tab 1: Voice → Character    │  │
│  │  • Scene navigation      │  Tab 2: Character → Voice    │  │
│  │  • Element formatting    │  Tab 3: Generated Audio      │  │
│  │  • Standard Guion UI     │  Tab 4: Export               │  │
│  │                          │                              │  │
│  │                          │  [Task Trigger Buttons]      │  │
│  │                          │  • Generate Items            │  │
│  │                          │  • Generate Audio            │  │
│  │                          │                              │  │
│  └──────────────────────────┴──────────────────────────────┘  │
│                                                                 │
│  [Progress Overlay appears over entire window when active]     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Main App Structure

### HablareApp.swift

```swift
import SwiftUI
import SwiftData

@main
struct HablareApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            // SwiftGuion models
            GuionDocumentModel.self,
            GuionElementModel.self,
            TitlePageEntryModel.self,

            // SwiftHablare screenplay models
            SpeakableItem.self,
            SpeakableAudio.self,
            CharacterVoiceMapping.self,

            // SwiftHablare core models
            Voice.self,
            VoiceModel.self,
            AudioFile.self,
            GeneratedAudioRecord.self
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            HablareSplitView()
        }
        .modelContainer(sharedModelContainer)
        .windowStyle(.automatic)
        .defaultSize(width: 1400, height: 900)
    }
}
```

---

### HablareSplitView.swift (Main View)

```swift
import SwiftUI
import SwiftData

/// Main split-view container for the Hablare sample app
struct HablareSplitView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var screenplay: GuionDocumentModel?
    @State private var selectedElementID: String?

    var body: some View {
        NavigationSplitView {
            // Left pane: Screenplay list/selector
            ScreenplayListView(selectedScreenplay: $screenplay)
                .frame(minWidth: 200)
        } content: {
            // Center pane: Guion screenplay view (50% width)
            if let screenplay = screenplay {
                GuionScreenplayView(
                    document: screenplay,
                    selectedElementID: $selectedElementID
                )
                .frame(minWidth: 400)
            } else {
                ContentUnavailableView(
                    "No Screenplay Selected",
                    systemImage: "doc.text",
                    description: Text("Create or open a screenplay to begin")
                )
            }
        } detail: {
            // Right pane: Hablare tabbed palette (50% width)
            if let screenplay = screenplay {
                ScreenplaySpeechView(screenplay: screenplay)
                    .frame(minWidth: 600)
            } else {
                ContentUnavailableView(
                    "Select Screenplay",
                    systemImage: "waveform",
                    description: Text("Speech generation will appear here")
                )
            }
        }
        .navigationTitle("Hablare - Screenplay Speech Showcase")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    createNewScreenplay()
                } label: {
                    Label("New Screenplay", systemImage: "doc.badge.plus")
                }

                Button {
                    openScreenplay()
                } label: {
                    Label("Open Screenplay", systemImage: "doc")
                }
            }
        }
        .onAppear {
            loadOrCreateDefaultScreenplay()
        }
    }

    private func createNewScreenplay() {
        let newScreenplay = GuionDocumentModel(
            filename: "Untitled Screenplay.fountain",
            rawContent: "",
            suppressSceneNumbers: false
        )

        modelContext.insert(newScreenplay)

        do {
            try modelContext.save()
            screenplay = newScreenplay
        } catch {
            print("Failed to create screenplay: \(error)")
        }
    }

    private func openScreenplay() {
        // TODO: Implement file picker
        print("Open screenplay file picker")
    }

    private func loadOrCreateDefaultScreenplay() {
        // Try to fetch existing screenplays
        let descriptor = FetchDescriptor<GuionDocumentModel>(
            sortBy: [SortDescriptor(\.filename)]
        )

        if let existingScreenplays = try? modelContext.fetch(descriptor),
           let first = existingScreenplays.first {
            screenplay = first
        } else {
            // Create sample screenplay
            createSampleScreenplay()
        }
    }

    private func createSampleScreenplay() {
        let sampleContent = """
        Title: Sample Screenplay
        Author: Hablare Demo

        INT. COFFEE SHOP - DAY

        JOHN enters, looking around nervously.

        JOHN
        Have you seen Sarah?

        WAITRESS
        She left about an hour ago.

        JOHN
        Did she say where she was going?
        I really need to talk to her.

        WAITRESS
        (smiling)
        Check the park. She goes there to read.

        John rushes out.

        EXT. PARK - DAY

        Sarah sits on a bench, reading a book. John approaches.

        JOHN
        Sarah! I've been looking everywhere for you.

        SARAH
        (surprised)
        John? What's wrong?

        JOHN
        We need to talk about what happened yesterday.
        """

        let sample = GuionDocumentModel(
            filename: "Sample Screenplay.fountain",
            rawContent: sampleContent,
            suppressSceneNumbers: false
        )

        // TODO: Parse the sample content into elements
        // For now, just create the document

        modelContext.insert(sample)

        do {
            try modelContext.save()
            screenplay = sample
        } catch {
            print("Failed to create sample: \(error)")
        }
    }
}
```

---

### ScreenplayListView.swift

```swift
import SwiftUI
import SwiftData

/// Sidebar list of available screenplays
struct ScreenplayListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GuionDocumentModel.filename) private var screenplays: [GuionDocumentModel]
    @Binding var selectedScreenplay: GuionDocumentModel?

    var body: some View {
        List(selection: $selectedScreenplay) {
            ForEach(screenplays) { screenplay in
                NavigationLink(value: screenplay) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(screenplay.filename ?? "Untitled")
                            .font(.headline)

                        HStack(spacing: 8) {
                            Image(systemName: "doc.text")
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            Text("\(screenplay.elements.count) elements")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .onDelete(perform: deleteScreenplays)
        }
        .navigationTitle("Screenplays")
    }

    private func deleteScreenplays(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(screenplays[index])
            }
        }
    }
}
```

---

### GuionScreenplayView.swift (Placeholder)

```swift
import SwiftUI
import SwiftData

/// Standard SwiftGuion screenplay editor view
/// This will be implemented by the SwiftGuion package
struct GuionScreenplayView: View {
    let document: GuionDocumentModel
    @Binding var selectedElementID: String?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Screenplay")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Text(document.filename ?? "Untitled")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Screenplay content
            if document.elements.isEmpty {
                ContentUnavailableView(
                    "Empty Screenplay",
                    systemImage: "doc.text",
                    description: Text("Parse a Fountain file or create elements")
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(document.elements) { element in
                            ElementRowView(element: element, isSelected: element.sceneId == selectedElementID)
                                .onTapGesture {
                                    selectedElementID = element.sceneId
                                }
                        }
                    }
                    .padding()
                }
            }
        }
    }
}

/// Simple element display for demo purposes
struct ElementRowView: View {
    let element: GuionElementModel
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(element.elementType)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(4)

                Spacer()
            }

            Text(element.elementText)
                .font(fontForElementType(element.elementType))
                .foregroundColor(.primary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.blue.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
    }

    private func fontForElementType(_ type: String) -> Font {
        switch type {
        case "Scene Heading":
            return .headline.bold()
        case "Character":
            return .body.bold()
        case "Dialogue":
            return .body
        case "Action":
            return .body
        case "Parenthetical":
            return .body.italic()
        case "Transition":
            return .body.italic()
        default:
            return .body
        }
    }
}
```

---

## View Synchronization

### Screenplay ↔ Hablare Sync

**Shared State**:
- Both views reference the same `GuionDocumentModel`
- Changes in screenplay automatically trigger UI updates
- SpeakableItems reference source elements via `sourceElementID`

**Synchronization Points**:

1. **Element Selection**
   - User clicks element in Guion view
   - Corresponding SpeakableItem highlights in Audio List tab

2. **Audio Playback**
   - User plays audio in Hablare panel
   - Corresponding element highlights in Guion view

3. **Screenplay Edits**
   - User edits screenplay in Guion view
   - SpeakableItems marked as "stale" (need regeneration)
   - UI shows warning indicator

**Future Enhancement**:
```swift
@Observable
class ViewSyncCoordinator {
    var selectedElementID: String?
    var currentlyPlayingItemID: UUID?

    func highlightElement(_ elementID: String) {
        selectedElementID = elementID
    }

    func highlightPlayingItem(_ itemID: UUID) {
        currentlyPlayingItemID = itemID
    }
}
```

---

## Layout Configuration

### Window Sizing

```swift
WindowGroup {
    HablareSplitView()
}
.defaultSize(width: 1400, height: 900)
.windowStyle(.automatic)
```

**Recommended Dimensions**:
- **Minimum Width**: 1200px
- **Default Width**: 1400px
- **Default Height**: 900px
- **Split Ratio**: 50/50 or adjustable

### Split Pane Sizing

```swift
NavigationSplitView(columnVisibility: .constant(.all)) {
    // Sidebar: 200px min
    ScreenplayListView(...)
        .frame(minWidth: 200)
} content: {
    // Guion view: 400px min, flexible
    GuionScreenplayView(...)
        .frame(minWidth: 400)
} detail: {
    // Hablare view: 600px min, flexible
    ScreenplaySpeechView(...)
        .frame(minWidth: 600)
}
```

---

## Sample Data

### Demo Screenplay Content

The app includes a built-in sample screenplay with:
- Multiple scenes (INT/EXT)
- Multiple characters (3-5)
- Variety of element types (dialogue, action, parentheticals)
- Good length for demo (~20 speakable items)

**Sample Scenes**:
1. INT. COFFEE SHOP - DAY (intro scene)
2. EXT. PARK - DAY (conversation scene)

**Sample Characters**:
- JOHN (protagonist, ~8 lines)
- SARAH (secondary, ~5 lines)
- WAITRESS (minor, ~2 lines)

---

## Task Integration

### Task Triggers

Tasks are triggered from the Hablare panel header:

```swift
HStack(spacing: 12) {
    Button {
        triggerSpeakableItemGeneration()
    } label: {
        Label("Generate Items", systemImage: "wand.and.stars")
    }
    .disabled(taskCoordinator.currentTask != nil)

    Button {
        triggerAudioGeneration()
    } label: {
        Label("Generate Audio", systemImage: "waveform")
    }
    .disabled(taskCoordinator.currentTask != nil)
}
```

### Progress Overlay

Modal overlay appears **over entire window** during task execution:

```swift
.overlay {
    if let currentTask = taskCoordinator.currentTask {
        TaskProgressOverlay(task: currentTask) {
            taskCoordinator.cancelCurrentTask()
        }
        .zIndex(100)  // Ensure it's on top
    }
}
```

---

## User Workflows

### Workflow 1: First-Time User

1. **App launches** → Sample screenplay loads automatically
2. User sees:
   - Left: Screenplay with formatted elements
   - Right: Empty Hablare tabs
3. User clicks **"Generate Items"**
   - Progress overlay appears
   - SpeakableItems are created
4. Hablare tabs populate:
   - Character → Voice tab shows detected characters
   - Audio List tab shows items (no audio yet)
5. User assigns voices to characters
6. User clicks **"Generate Audio"**
   - Progress overlay shows generation progress
   - Audio appears in list
7. User plays audio
   - Corresponding screenplay element highlights

### Workflow 2: Import Screenplay

1. User clicks **"Open Screenplay"**
2. Selects .fountain file
3. SwiftGuion parses file → Elements appear in left pane
4. User proceeds with "Generate Items" workflow

### Workflow 3: Edit and Regenerate

1. User edits screenplay in Guion view
2. Hablare panel shows "⚠️ Screenplay modified"
3. User clicks **"Regenerate Items"**
4. SpeakableItems update
5. User clicks **"Regenerate Audio"** (for changed items only)

---

## Feature Showcase Checklist

### SwiftHablare Features Demonstrated

- ✅ **Task System**
  - SpeakableItem generation with progress
  - Audio generation with progress
  - Cancellation support

- ✅ **Voice-Character Mapping**
  - Auto-detection of characters
  - Manual voice assignment
  - Bidirectional mapping views

- ✅ **Audio Generation**
  - Multiple providers (ElevenLabs, Apple)
  - Voice selection per character
  - Batch generation

- ✅ **Audio Playback**
  - Player widget with controls
  - Ordered playlist
  - Status indicators

- ✅ **Speech Logic**
  - Character announcement rules
  - Dialogue grouping
  - Scene-based context

### SwiftGuion Features Demonstrated

- ✅ **Screenplay Editing**
  - Element display
  - Formatting
  - Scene navigation

- ✅ **Fountain Parsing**
  - Import .fountain files
  - Element detection
  - Relationship tracking

---

## Development Phases

### Phase 1: Basic Split View
- ✅ NavigationSplitView structure
- ✅ Screenplay list sidebar
- ✅ Empty Guion pane
- ✅ Empty Hablare pane

### Phase 2: Guion Integration
- ✅ Basic element display
- ✅ Sample screenplay loading
- ✅ Element selection

### Phase 3: Hablare Integration
- ✅ Tabbed palette integration
- ✅ Task triggers
- ✅ Progress overlay

### Phase 4: Synchronization
- ⏸️ Element ↔ SpeakableItem highlighting
- ⏸️ Playback ↔ Element sync
- ⏸️ Edit detection

### Phase 5: Polish
- ⏸️ File import/export
- ⏸️ Keyboard shortcuts
- ⏸️ Menu bar integration

---

## Project Structure

```
Examples/Hablare/
├── Hablare.xcodeproj/
├── Hablare/
│   ├── HablareApp.swift                  (Main app entry)
│   ├── HablareSplitView.swift           (Root split view)
│   ├── Views/
│   │   ├── ScreenplayListView.swift     (Sidebar)
│   │   ├── GuionScreenplayView.swift    (Left pane)
│   │   └── [Hablare views imported]     (Right pane)
│   ├── Models/
│   │   └── [SwiftData models imported]
│   ├── Resources/
│   │   └── SampleScreenplay.fountain    (Demo content)
│   └── Info.plist
├── HablareTests/
└── HablareUITests/
```

---

## Dependencies

### Swift Package Dependencies

```swift
dependencies: [
    .package(url: "https://github.com/intrusive-memory/SwiftGuion", from: "1.0.0"),
    .package(url: "https://github.com/intrusive-memory/SwiftHablare", from: "1.0.0")
]
```

### SwiftGuion Integration

- GuionDocumentModel (SwiftData)
- GuionElementModel (SwiftData)
- Fountain parser (if available)
- Screenplay view components (if available)

### SwiftHablare Integration

- All screenplay speech models (SpeakableItem, SpeakableAudio, CharacterVoiceMapping)
- All UI views (ScreenplaySpeechView, AudioPlayerWidget, etc.)
- Task system (SpeakableItemGenerationTask, AudioGenerationTask)

---

## Next Steps

1. ✅ **Requirements documented**
2. 🔜 Implement HablareSplitView structure
3. 🔜 Create sample screenplay with parser
4. 🔜 Integrate Hablare tabbed views
5. 🔜 Add task triggers
6. 🔜 Implement basic synchronization
7. 🔜 Add polish and testing

---

## Change Log

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-10-16 | Initial sample app design - split-view architecture with Guion + Hablare integration |
