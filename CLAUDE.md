# SwiftHablaré - Claude Code Development Guide

This document provides guidance for AI assistants (particularly Claude Code) working on the SwiftHablaré project.

## Project Overview

**SwiftHablaré** is a unified Swift framework for integrating multiple AI services with automatic SwiftData persistence. Currently focused on text-to-speech with screenplay processing capabilities, it's designed to expand into a comprehensive AI service integration framework.

## Current Development Sprint: UI Sprint (Phase 1-2)

### Completed in PR #38

The UI sprint focuses on building the **ScreenplaySpeech** system - a comprehensive background task management system for processing screenplays into speakable audio content.

#### Phase 1: Background Tasks Architecture ✅
- **BackgroundTask**: Observable state machine with progress tracking (100% test coverage)
- **BackgroundTaskManager**: Sequential task execution and queueing (90.48% coverage)
- **ScreenplayTask**: Protocol for executable background tasks
- **UI Components**:
  - `BackgroundTasksPalette`: Floating palette for task visualization
  - `BackgroundTaskRow`: Individual task display with status badges and progress bars

**Features**:
- State machine: `queued → running → completed/failed/cancelled`
- Progress tracking with step-by-step messages
- Auto-execution with sequential task queuing
- Cancellation support (preserves partial results)
- Error capture with user-friendly messages
- Blocking task indicators

**Test Coverage**:
- 28 total tests in Phase 1, all passing
- 100% coverage on BackgroundTask state machine
- 90.48% coverage on BackgroundTaskManager
- Integration tests for end-to-end task lifecycle

#### Phase 2: SpeakableItem Generation Task ✅
- **SpeakableItem Model Enhancement**: Added `screenplayID` property for screenplay tracking
- **SpeakableItemGenerationTask**: Complete task implementation with progress tracking
- **Processor Updates**: Updated `SpeechLogicRulesV1_0` and `ScreenplayToSpeechProcessor` for screenplay ID propagation

**Features**:
- Wraps ScreenplayToSpeechProcessor with progress tracking
- Reports progress per element processed
- Handles cancellation gracefully (preserves partial results)
- Periodic saves every 50 elements to prevent data loss
- Full integration with BackgroundTaskManager

**Test Coverage**:
- 15 comprehensive tests covering all scenarios
- 96.85% coverage on SpeakableItemGenerationTask
- 100% coverage on SpeakableItem model
- 92.81% coverage on SpeechLogicRulesV1_0
- Total: 787 tests passing

## Platform Support

### macOS, iOS, and Catalyst Ready

SwiftHablaré is now fully compatible with:
- **macOS 15.0+**
- **iOS 17.0+**
- **macCatalyst 15.0+**

All UI components use cross-platform APIs:
- SwiftUI for all user interfaces
- Cross-platform color APIs (`.systemBackground`, `.systemGray`, etc.)
- Platform-specific settings access (System Preferences on macOS, Settings app on iOS/Catalyst)
- No AppKit dependencies in production code

### Catalyst-Specific Updates

**VoiceSettingsWidget.swift**:
- Platform-aware settings access
- macOS: Opens System Preferences for voice management
- iOS/Catalyst: Opens Settings app for Accessibility > Spoken Content
- Uses `UIApplication.shared.open()` on iOS/Catalyst

**Color API Migration**:
All files updated from AppKit-specific colors to cross-platform equivalents:
- `Color(nsColor: .controlBackgroundColor)` → `Color(.systemBackground)`
- `Color(nsColor: .systemGray)` → `Color(.systemGray)`
- Removed all `import AppKit` statements from production code

**Updated Files**:
- `VoiceSettingsWidget.swift` - Platform-aware settings access
- `VoiceProviderWidget.swift` - Cross-platform colors
- `BackgroundTaskRow.swift` - Cross-platform colors
- `AudioPlayerWidget.swift` - Cross-platform colors
- `VoicePickerWidget.swift` - Cross-platform colors
- `AppleVoiceProvider.swift` - Removed unused AppKit import

## Architecture

### Core Modules

**SwiftDataModels** (Consolidated Storage):
```
SwiftDataModels/
├── TypedDataStorage.swift         # ✨ NEW: Unified model for all content types
├── AIGeneratedContent.swift       # Base model class
├── GeneratedText.swift            # Text content (legacy)
├── GeneratedAudio.swift           # Audio content (legacy)
├── GeneratedImage.swift           # Image content (legacy)
├── GeneratedVideo.swift           # Video content (legacy)
├── GeneratedStructuredData.swift  # Structured data (legacy)
├── VoiceModel.swift               # Voice caching
└── AudioFile.swift                # Audio file storage
```

**TypedDataStorage**: Unified model using MIME types
- **text/** types → `textValue` field
- **audio/**, **video/**, **image/** → `binaryValue` field
- **application/**, **multipart/** → Rejected (out of scope)
- Type-specific metadata stored as JSON

**VoiceGeneration** (Thread-Safe Audio):
```
VoiceGeneration/
├── VoiceGenerationRequest.swift   # ✨ Sendable input DTO
├── VoiceGenerationResult.swift    # ✨ Sendable output DTO
└── VoiceGenerationService.swift   # ✨ Actor-based service
```

**Thread Safety Architecture**:
```
Background Thread              Main Thread (@MainActor)
─────────────────              ────────────────────────
generate(request)
├─> Call provider API
├─> Process audio
└─> Return result ─────────────> toTypedDataStorage()
    (Sendable)                    ├─> Create model
                                  ├─> Insert to context
                                  └─> Save
```

**ScreenplaySpeech** (UI Sprint):
```
ScreenplaySpeech/
├── Tasks/
│   ├── BackgroundTask.swift          # State machine for async tasks
│   ├── BackgroundTaskManager.swift   # Task queue and execution
│   ├── ScreenplayTask.swift          # Task protocol
│   └── SpeakableItemGenerationTask.swift  # Screenplay processing task
├── UI/
│   ├── BackgroundTasksPalette.swift  # Floating task palette
│   └── BackgroundTaskRow.swift       # Task UI component
├── Models/
│   ├── SpeakableItem.swift           # SwiftData model with screenplayID
│   └── SpeakableAudio.swift          # Audio versions for items
├── Processing/
│   └── ScreenplayToSpeechProcessor.swift  # Screenplay → SpeakableItems
└── Logic/
    └── SpeechLogicRulesV1_0.swift    # Processing rules
```

**UI Widgets** (Catalyst-compatible):
```
UI/
├── VoiceSettingsWidget.swift      # API key and voice settings
├── VoiceProviderWidget.swift      # Provider selection
├── VoicePickerWidget.swift        # Voice selection
├── AudioPlayerWidget.swift        # Audio playback
├── TextConfigurationView.swift    # Text generation config
└── CrossPlatformColors.swift      # Color helpers
```

### Testing Strategy

**Coverage Targets**:
- Unit Tests: 95%+ coverage
- Integration Tests: 90%+ coverage
- UI Tests: Xcode Previews + manual testing
- Performance Tests: For large datasets (500+ elements)

**Current Status**:
- 787 total tests passing
- 96%+ average coverage on ScreenplaySpeech modules
- 100% coverage on critical paths (BackgroundTask, SpeakableItem)
- Swift 6 strict concurrency compliance

## Development Workflow

### For New Features

1. **Read Documentation**:
   - `AI_DEVELOPMENT_GUIDE.md` - Comprehensive development patterns
   - `AI_REFERENCE.md` - Quick reference for common tasks
   - `SCREENPLAY_UI_SPRINT_METHODOLOGY.md` - UI sprint phases

2. **Plan with Todos**:
   - Use TodoWrite tool for complex tasks
   - Break down into manageable steps
   - Track progress throughout implementation

3. **Write Tests First** (TDD approach):
   - Unit tests for core logic
   - Integration tests for workflows
   - Xcode previews for UI components

4. **Implement Features**:
   - Follow existing patterns
   - Use `@MainActor` for UI code
   - Ensure Swift 6 concurrency compliance

5. **Verify Coverage**:
   - Run tests: `swift test --enable-code-coverage`
   - Check coverage: `xcrun llvm-cov report`
   - Aim for 90%+ on all new code

### For Bug Fixes

1. **Write Failing Test**: Create a test that reproduces the bug
2. **Fix the Bug**: Implement the fix
3. **Verify**: Ensure the test passes and existing tests still work
4. **Document**: Update comments and docs as needed

### For Catalyst/Cross-Platform Work

1. **Use Cross-Platform APIs**:
   - `Color(.systemBackground)` instead of `Color(nsColor: .controlBackgroundColor)`
   - `#if os(macOS)` / `#if os(iOS)` for platform-specific code
   - Avoid AppKit/UIKit direct usage when SwiftUI alternatives exist

2. **Test on Multiple Platforms**:
   - Build for macOS, iOS, and Catalyst
   - Verify UI layouts work on all platforms
   - Test platform-specific features (settings, file access, etc.)

## Code Style

### SwiftUI Components

```swift
public struct MyWidget: View {
    @ObservedObject var manager: MyManager
    @State private var selection: String?

    public init(manager: MyManager) {
        self.manager = manager
    }

    public var body: some View {
        VStack(spacing: 16) {
            // Content
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))  // Cross-platform!
                .shadow(color: .black.opacity(0.1), radius: 10, y: 4)
        )
    }
}

#Preview {
    MyWidget(manager: MyManager())
}
```

### Background Tasks

```swift
@MainActor
final class MyTask: ScreenplayTask {
    let task: BackgroundTask

    init(name: String, isBlocking: Bool = false) {
        self.task = BackgroundTask(name: name, isBlocking: isBlocking)
    }

    func execute() async throws {
        task.state = .running
        task.totalSteps = 100

        for step in 0..<100 {
            // Check for cancellation
            if task.state == .cancelled {
                throw CancellationError()
            }

            task.currentStep = step
            task.message = "Processing item \(step)..."

            // Do work...
        }

        task.state = .completed
    }
}
```

### SwiftData Models

**TypedDataStorage** (Preferred for new code):
```swift
// Unified model for all content types
let record = TypedDataStorage(
    providerId: "elevenlabs",
    requestorID: "elevenlabs.audio.tts",
    mimeType: "audio/mpeg",           // Determines storage field
    binaryValue: audioData,            // For audio/*, video/*, image/*
    prompt: "Speak this text",
    metadata: try? JSONSerialization.data(withJSONObject: [
        "voiceID": "voice123",
        "voiceName": "Rachel",
        "durationSeconds": 10.5
    ])
)
modelContext.insert(record)
try modelContext.save()
```

**Domain-Specific Models**:
```swift
@Model
public final class MyModel {
    @Attribute(.unique) public var id: UUID
    public var createdAt: Date
    public var screenplayID: String  // For screenplay-related models

    public init(screenplayID: String) {
        self.id = UUID()
        self.createdAt = Date()
        self.screenplayID = screenplayID
    }
}
```

**MIME Type Validation**:
```swift
// Validate MIME type before storage
try MimeTypeHelper.validate("audio/mpeg")  // ✅ OK
try MimeTypeHelper.validate("text/plain")  // ✅ OK
try MimeTypeHelper.validate("application/json")  // ❌ Throws unsupportedMimeType
```

## Key Patterns

### 1. Thread-Safe Voice Generation

**Using VoiceGenerationService** (Recommended):
```swift
// Create service (actor for thread safety)
let service = VoiceGenerationService(voiceProvider: provider)

// Create request (Sendable - can cross thread boundaries)
let request = VoiceGenerationRequest(
    text: "Hello, world!",
    voiceId: "voice123",
    providerId: "elevenlabs",
    requestorId: "elevenlabs.audio.tts",
    mimeType: "audio/mpeg"
)

// Option 1: Manual two-step process
let result = try await service.generate(request)  // Background thread
await MainActor.run {
    let record = result.toTypedDataStorage()
    modelContext.insert(record)
    try? modelContext.save()
}

// Option 2: Convenience method (must be on @MainActor)
@MainActor
func generateAndSave() async throws {
    let record = try await service.generateAndSave(request, to: modelContext)
}
```

**Key Points**:
- ✅ `VoiceGenerationService` is an **actor** (automatic synchronization)
- ✅ `VoiceGenerationRequest` and `VoiceGenerationResult` are **Sendable**
- ✅ Generation happens on **background thread** (non-blocking)
- ✅ SwiftData operations on **@MainActor** (thread-safe)
- ✅ No data races or concurrency issues

### 2. TypedDataStorage with MIME Types

**Storing Different Content Types**:
```swift
// Text content
let textRecord = TypedDataStorage(
    providerId: "openai",
    requestorID: "openai.text.gpt4",
    mimeType: "text/plain",
    textValue: "Generated text...",    // text/* uses textValue
    prompt: "Write a story"
)

// Audio content
let audioRecord = TypedDataStorage(
    providerId: "elevenlabs",
    requestorID: "elevenlabs.audio.tts",
    mimeType: "audio/mpeg",
    binaryValue: audioData,             // audio/* uses binaryValue
    prompt: "Speak this"
)

// Image content
let imageRecord = TypedDataStorage(
    providerId: "openai",
    requestorID: "openai.image.dalle3",
    mimeType: "image/png",
    binaryValue: imageData,             // image/* uses binaryValue
    prompt: "Generate image"
)
```

**Querying by Type**:
```swift
let descriptor = FetchDescriptor<TypedDataStorage>()
let allRecords = try modelContext.fetch(descriptor)

// Filter by MIME type
let audioRecords = allRecords.filter { $0.mimeType.hasPrefix("audio/") }
let textRecords = allRecords.filter { MimeTypeHelper.isTextMimeType($0.mimeType) }
```

**Retrieving Content**:
```swift
// Get text content (validates MIME type is text/*)
let text = try record.getText()

// Get binary content
let data = try record.getBinary()

// Get metadata
if let metadata = try record.decodeMetadata() {
    let duration = metadata["durationSeconds"] as? Double
    let voiceID = metadata["voiceID"] as? String
}
```

### 3. Progress Tracking
```swift
task.totalSteps = items.count
for (index, item) in items.enumerated() {
    task.currentStep = index
    task.message = "Processing \(item.name)..."
    // Process item
}
```

### 4. Sendable DTOs for Thread Safety

**Creating Sendable Data Transfer Objects**:
```swift
// ✅ Good - Sendable struct with immutable properties
public struct MyRequest: Sendable {
    public let text: String
    public let voiceId: String
    public let metadata: [String: String]  // Dictionary is Sendable

    // All properties are 'let' (immutable)
    // No classes or mutable state
}

// ❌ Bad - Non-Sendable class
public class MyRequest {
    public var text: String  // Mutable property
    public var voiceId: String
}
```

**Passing Data Between Threads**:
```swift
// Background thread creates Sendable result
actor MyService {
    func process(_ request: MyRequest) async -> MyResult {
        // Process on background thread
        let data = await someOperation()

        // Return Sendable result
        return MyResult(data: data)  // ✅ Safe to return
    }
}

// Main thread receives and uses result
@MainActor
func handleResult() async {
    let result = await service.process(request)  // ✅ Safe transfer
    // Use result on main thread
}
```

### 5. Cancellation Handling
```swift
if task.state == .cancelled {
    throw CancellationError()
}
```

### 6. Error Handling
```swift
do {
    try await performOperation()
    task.state = .completed
} catch {
    task.state = .failed
    task.error = error
}
```

### 7. Periodic Saves
```swift
let saveInterval = 50
for (index, item) in items.enumerated() {
    // Process item

    if (index + 1) % saveInterval == 0 {
        try modelContext.save()
    }
}
try modelContext.save()  // Final save
```

## Quality Gates

Before submitting a PR:

- ✅ All tests pass
- ✅ 90%+ test coverage on new code
- ✅ Swift 6 strict concurrency compliance
- ✅ No compiler warnings
- ✅ Xcode previews work
- ✅ Documentation updated
- ✅ CHANGELOG.md updated
- ✅ Cross-platform compatibility verified (if UI changes)

## Resources

### Documentation
- `AI_DEVELOPMENT_GUIDE.md` - Comprehensive guide for AI assistants
- `AI_REFERENCE.md` - Quick reference
- `README.md` - Project overview
- `Docs/SCREENPLAY_UI_SPRINT_METHODOLOGY.md` - UI sprint phases
- `Docs/SCREENPLAY_UI_DECISIONS.md` - Design decisions
- `Docs/TYPED_DATA_STORAGE.md` - ✨ TypedDataStorage guide
- `Docs/VOICE_GENERATION_THREAD_SAFETY.md` - ✨ Thread safety architecture
- `Docs/SWIFTDATA_MODELS_ORGANIZATION.md` - Model organization
- `Docs/RECENT_CHANGES_SUMMARY.md` - Latest changes overview

### Testing
- `Tests/SwiftHablareTests/` - All test suites
- `Docs/Previous/PHASE1_TESTING_STRATEGY.md` - Testing methodology

### Examples
- `Examples/Hablare/` - Sample application

## Common Tasks

### Generate Audio with Thread Safety

**Recommended Pattern**:
```swift
// 1. Create service
let service = VoiceGenerationService(voiceProvider: provider)

// 2. Create request
let request = VoiceGenerationRequest(
    text: "Text to speak",
    voiceId: "voice123",
    providerId: "elevenlabs",
    requestorId: "elevenlabs.audio.tts"
)

// 3. Generate and save (must be on @MainActor)
@MainActor
func generate() async throws {
    let record = try await service.generateAndSave(request, to: modelContext)
    print("Saved audio: \(record.id)")
}
```

### Store Content with TypedDataStorage

**Text Content**:
```swift
let record = TypedDataStorage(
    providerId: "openai",
    requestorID: "openai.text.gpt4",
    mimeType: "text/plain",
    textValue: generatedText,
    prompt: originalPrompt
)
modelContext.insert(record)
try modelContext.save()
```

**Audio Content**:
```swift
let record = TypedDataStorage(
    providerId: "elevenlabs",
    requestorID: "elevenlabs.audio.tts",
    mimeType: "audio/mpeg",
    binaryValue: audioData,
    prompt: textToSpeak,
    metadata: try? JSONSerialization.data(withJSONObject: [
        "voiceID": voiceId,
        "durationSeconds": duration
    ])
)
modelContext.insert(record)
try modelContext.save()
```

### Add a New Background Task
1. Create class conforming to `ScreenplayTask`
2. Implement `execute()` method with progress tracking
3. Add cancellation checks
4. Write comprehensive tests (15+ test cases)
5. Update documentation

### Add a New UI Widget
1. Create SwiftUI view with public init
2. Use cross-platform colors (`Color.systemBackgroundColor`)
3. Add Xcode preview
4. Test on macOS, iOS, and Catalyst
5. Document in CLAUDE.md

### Create Thread-Safe Service
1. Use `actor` for the service class
2. Create `Sendable` request/result DTOs (structs with `let` properties)
3. Background generation returns `Sendable` result
4. @MainActor for SwiftData operations
5. Add cancellation support

### Update for Catalyst Compatibility
1. Replace AppKit-specific APIs with cross-platform alternatives
2. Use `Color.systemBackgroundColor` instead of `Color(nsColor: ...)`
3. Use `#if os(macOS)` / `#if os(iOS)` for platform-specific code
4. Test on all three platforms
5. Update documentation

## Version Information

- **Current Version**: 2.0 (in development)
- **Swift Version**: 6.0+
- **Minimum Deployments**: macOS 15.0, iOS 17.0, macCatalyst 15.0
- **Total Tests**: 787 passing
- **Average Coverage**: 96%+ on ScreenplaySpeech modules
- **SwiftData Models**: 15 total (9 general, 2 ScreenplaySpeech, 4 TypedData)
- **Thread Safety**: Full Swift 6 concurrency compliance

## Recent Changes

### TypedDataStorage Consolidation

**Before**: 4 separate models (GeneratedTextRecord, GeneratedAudioRecord, etc.)
**After**: 1 unified TypedDataStorage model with MIME type routing

**Migration**:
```swift
// Old (deprecated but still works)
let record = GeneratedAudioRecord(
    audioData: data,
    format: "mp3",
    voiceID: "voice123"
)

// New (recommended)
let record = TypedDataStorage(
    mimeType: "audio/mpeg",
    binaryValue: data,
    metadata: try? JSONSerialization.data(withJSONObject: [
        "voiceID": "voice123"
    ])
)
```

### Thread-Safe Voice Generation

**New Architecture**:
- `VoiceGenerationService` (actor) - Thread-safe coordinator
- `VoiceGenerationRequest` (Sendable) - Input DTO
- `VoiceGenerationResult` (Sendable) - Output DTO
- Background generation with main thread SwiftData saves

**Benefits**:
- Swift 6 concurrency compliant
- No data races
- Responsive UI during generation
- Proper error propagation
- Cancellation support

## Next Steps

**Phase 3: Character Mapping Models** (Upcoming)
- CharacterVoiceMapping SwiftData model
- Character detection and mapping generator
- Bidirectional voice assignment UI
- 90%+ test coverage target

**Phase 4: Core UI Scaffolding** (Upcoming)
- Main screenplay speech view
- Tab-based navigation
- BackgroundTasksPalette integration
- ProviderPickerView

See `Docs/SCREENPLAY_UI_SPRINT_METHODOLOGY.md` for complete roadmap.

---

**For Questions or Contributions**:
- GitHub Issues: https://github.com/intrusive-memory/SwiftHablare/issues
- GitHub Discussions: https://github.com/intrusive-memory/SwiftHablare/discussions
