# Changelog

All notable changes to SwiftHablaré will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed - Library Scope Clarification

**SwiftHablare is now a focused voice generation library**:
- Simple API: `text + voiceId → audio`
- No character mapping (handled by consuming applications)
- No screenplay analysis (handled by consuming applications)
- No automatic voice assignment (handled by consuming applications)

**Rationale**:
- Single Responsibility Principle: SwiftHablare does voice generation, consuming apps handle character mapping
- Simpler API surface area
- Easier to test and maintain
- Character mapping logic should live in screenplay-specific libraries

**Documentation Updates**:
- README.md: Clarified library scope and out-of-scope features
- CLAUDE.md: Added "Library Scope and Philosophy" section
- AI_DEVELOPMENT_GUIDE.md: Updated project status
- AI_REFERENCE.md: Replaced Phase 3 character mapping plans with scope clarification

**Impact**:
- No code changes required (character mapping was never implemented)
- Only documentation updates
- Future development will focus on voice generation quality and performance

### Added - Voice Provider Integration Tests

#### End-to-End Testing with Real Audio
- **AppleVoiceProviderIntegrationTests** - Complete test suite for Apple TTS
  - Real audio generation using NSSpeechSynthesizer on macOS
  - AIFF format audio output (not silent placeholder audio)
  - Comprehensive audio validation:
    - File size checks (> 1KB)
    - Duration validation (> 1 second for test text)
    - Non-zero sample verification (confirms actual speech content)
    - Sample percentage analysis
  - Test artifacts saved to `.build/*/TestArtifacts/` directory
  - Tests with multiple voices and long text passages
  - Always runs on macOS (no external dependencies)

- **ElevenLabsVoiceProviderIntegrationTests** - Complete test suite for ElevenLabs API
  - Real API calls with production ElevenLabs service
  - Conditional execution (only runs if ELEVENLABS_API_KEY environment variable set)
  - Ephemeral API key support (bypasses keychain for clean testing)
  - MP3 audio artifact generation
  - Tests with multiple voices and long text passages
  - Graceful test skipping when API key unavailable
  - Clean test environment (no keychain pollution)

#### Enhanced Voice Provider Implementations
- **AppleVoiceProvider** - Audio generation on all platforms (AIFF format)
  - **Native macOS**: Uses NSSpeechSynthesizer (production-ready with real speech)
  - **Mac Catalyst & iOS**: Uses AVSpeechSynthesizer.write() (placeholder audio)
  - Full audio validation (duration, sample content)
  - Platform-specific implementations using `#if os(macOS) && !targetEnvironment(macCatalyst)`
  - Consistent AIFF output format across all platforms

- **ElevenLabsVoiceProvider** - Testing improvements
  - Optional ephemeral API key via initializer (`init(apiKey: String?)`)
  - Bypasses keychain for test scenarios
  - Maintains backward compatibility with keychain storage

#### Validation and Error Handling
- **Empty text validation** - Both providers now validate input
  - Throws `.invalidRequest("Text cannot be empty")` for empty/whitespace-only text
  - Prevents wasted API calls and invalid audio generation

#### Build Configuration
- **Updated .gitignore**
  - Excludes `.aiff` files (Apple TTS output)
  - Excludes `TestArtifacts/` directory
  - Keeps test output clean and git-friendly

#### CI/CD Integration
- **GitHub Actions Workflow Updates**
  - Integration tests now run automatically on all PRs
  - `ELEVENLABS_API_KEY` repository secret support for ElevenLabs tests
  - Test artifacts (AIFF and MP3 files) uploaded to GitHub Actions artifacts
  - Integration test summary in GitHub Actions job summary:
    - Shows Apple Voice Provider test execution status
    - Shows ElevenLabs test execution status (or skip reason)
    - Displays number of audio artifacts generated
  - Clear logging when ElevenLabs API key is/isn't available

### Added - Thread-Safe Voice Generation

#### VoiceGeneration Module
- **VoiceGenerationRequest** - Sendable DTO for thread-safe input
  - All properties immutable (`let`)
  - Value type (struct) with no shared state
  - Can be safely passed across actor boundaries
- **VoiceGenerationResult** - Sendable DTO for thread-safe output
  - Immutable result from background generation
  - Contains all metadata for SwiftData storage
  - `toTypedDataStorage()` method for @MainActor conversion
- **VoiceGenerationService** - Actor-based generation coordinator
  - Background thread audio generation
  - Sendable data transfer to main thread
  - SwiftData persistence on @MainActor
  - Cancellation support for active tasks
  - Convenience `generateAndSave()` method

**Thread Safety Architecture**:
```
Background Thread                    Main Thread (@MainActor)
─────────────────                    ────────────────────────
generate(request)
├─> Call provider API
├─> Process audio
└─> Return result (Sendable) ───────> toTypedDataStorage()
                                      ├─> Create model
                                      ├─> Insert to context
                                      └─> Save
```

**Benefits**:
- Swift 6 concurrency compliant
- No data races or race conditions
- UI remains responsive during generation
- Proper error propagation
- Cancellable operations

### Changed - Code Organization

#### SwiftData Models Reorganization
- **Created `SwiftDataModels/` folder** - Centralized location for general SwiftData models
- **Split `AIGeneratedContent.swift`** - Separated into individual files for each model:
  - `AIGeneratedContent.swift` - Base model class
  - `GeneratedText.swift` - Text content model
  - `GeneratedAudio.swift` - Audio content model
  - `GeneratedImage.swift` - Image content model
  - `GeneratedVideo.swift` - Video content model
  - `GeneratedStructuredData.swift` - Structured data model
- **Moved models to `SwiftDataModels/`**:
  - `VoiceModel.swift` (from `Models/`)
  - `AudioFile.swift` (from `Models/`)
- **Domain-specific models remain organized**:
  - `ScreenplaySpeech/Models/` - SpeakableItem, SpeakableAudio
  - `TypedData/` - Generated*Record models

**Benefits**:
- Each SwiftData model in its own file named after the class
- Clearer separation between general and domain-specific models
- Easier navigation and maintenance
- Better organization for future model additions

### Deprecated - Legacy TypedData Models

#### Deprecated in Favor of TypedDataStorage
- **GeneratedTextRecord** - Deprecated, use `TypedDataStorage` with `mimeType: "text/plain"`
- **GeneratedAudioRecord** - Deprecated, use `TypedDataStorage` with `mimeType: "audio/*"`
- **GeneratedImageRecord** - Deprecated, use `TypedDataStorage` with `mimeType: "image/*"`
- **GeneratedEmbeddingRecord** - Deprecated, use `TypedDataStorage` with custom embedding type

**Migration Path**:
```swift
// Old approach
let record = GeneratedAudioRecord(
    providerId: "elevenlabs",
    requestorID: "elevenlabs.audio.tts",
    audioData: data,
    format: "mp3",
    voiceID: "voice123",
    voiceName: "Rachel"
)

// New approach
let record = TypedDataStorage(
    providerId: "elevenlabs",
    requestorID: "elevenlabs.audio.tts",
    mimeType: "audio/mpeg",
    binaryValue: data,
    prompt: "Speak this",
    metadata: try? JSONSerialization.data(withJSONObject: [
        "voiceID": "voice123",
        "voiceName": "Rachel"
    ])
)
```

**Why Deprecated**:
- Consolidates 4 models into 1
- MIME type-based storage routing
- More flexible metadata handling
- Simpler codebase maintenance

### Added - UI Sprint Phase 1-2 (PR #38)

#### Background Tasks Architecture (Phase 1)
- **BackgroundTask** - Observable state machine for tracking async task execution
  - State transitions: `queued → running → completed/failed/cancelled`
  - Progress tracking with `currentStep`, `totalSteps`, and `progressFraction`
  - Error capture and user-friendly error messages
  - Blocking task indicators
  - Cancellation support with partial result preservation
  - 100% test coverage (13 unit tests)

- **BackgroundTaskManager** - Task queue and sequential execution manager
  - Auto-execution of queued tasks
  - Sequential task processing
  - Error handling with task continuation
  - Clear completed tasks functionality
  - 90.48% test coverage (12 unit tests)

- **ScreenplayTask Protocol** - Standard interface for executable background tasks
  - Simple protocol requiring `task: BackgroundTask` and `execute()` method
  - Enables consistent task creation across the system

- **BackgroundTasksPalette** - Floating UI palette for task visualization
  - Material background with visual hierarchy
  - Real-time task status updates
  - Progress bars with step-by-step messages
  - Status badges (queued, running, completed, failed, cancelled)
  - Empty state display
  - Clear completed tasks button
  - Xcode previews for all states

- **BackgroundTaskRow** - Individual task UI component
  - Task name and status display
  - Progress bar with percentage
  - Cancel button for running tasks
  - Error message display
  - Blocking task indicator
  - Status badge with color coding

#### SpeakableItem Generation (Phase 2)
- **SpeakableItem Model Enhancement**
  - Added `screenplayID` property for screenplay tracking
  - Enables filtering SpeakableItems by source screenplay
  - Migration path for existing data

- **SpeakableItemGenerationTask** - Complete screenplay processing task
  - Wraps ScreenplayToSpeechProcessor with progress tracking
  - Per-element progress reporting
  - Graceful cancellation with partial result preservation
  - Periodic saves every 50 elements
  - Full BackgroundTaskManager integration
  - 96.85% test coverage (15 comprehensive tests)

- **Processor Updates**
  - Updated `SpeechLogicRulesV1_0` to accept and propagate screenplayID
  - Updated `ScreenplayToSpeechProcessor` to extract and pass screenplayID
  - All SpeakableItems now include screenplayID for proper tracking

#### Test Infrastructure
- **28 Phase 1 Tests** - Complete background task system coverage
  - BackgroundTaskTests: 13 unit tests for state machine
  - BackgroundTaskManagerTests: 12 unit tests for task management
  - TaskExecutionIntegrationTests: 3 integration tests for full lifecycle
  - MockScreenplayTask: Test utility for task simulation

- **15 Phase 2 Tests** - Comprehensive SpeakableItemGenerationTask coverage
  - Basic execution and empty screenplay handling
  - Progress tracking verification
  - Cancellation scenarios (mid-execution and pre-execution)
  - Periodic saves functionality
  - Scene heading, dialogue, and action processing
  - Complex screenplay integration
  - Large screenplay performance (100+ elements)
  - Rule version assignment

- **Total Test Count**: 787 tests passing (up from 559)
- **Coverage Achievements**:
  - BackgroundTask: 100% line coverage
  - SpeakableItem: 100% line coverage
  - SpeakableItemGenerationTask: 96.85% coverage
  - ScreenplayToSpeechProcessor: 96.67% coverage
  - SpeechLogicRulesV1_0: 92.81% coverage
  - BackgroundTaskManager: 92.45% coverage

#### Platform Support
- **macCatalyst Support** - Full compatibility with Mac Catalyst
  - Cross-platform color APIs throughout UI components
  - Platform-aware settings access (System Preferences on macOS, Settings app on iOS/Catalyst)
  - No AppKit dependencies in production code
  - Tested on macOS, iOS, and Catalyst

### Changed

#### Platform Compatibility Updates
- **VoiceSettingsWidget** - Platform-aware system voice settings access
  - macOS: Opens System Preferences for voice management
  - iOS/Catalyst: Opens Settings app for Accessibility > Spoken Content
  - Uses platform-appropriate URL schemes and APIs

- **Color API Migration** - Updated all UI components to use cross-platform colors
  - `Color(nsColor: .controlBackgroundColor)` → `Color(.systemBackground)`
  - `Color(nsColor: .systemGray)` → `Color(.systemGray)`
  - Ensures consistent appearance across macOS, iOS, and Catalyst

- **Files Updated for Catalyst**:
  - `VoiceSettingsWidget.swift` - Platform-aware settings
  - `VoiceProviderWidget.swift` - Cross-platform colors
  - `BackgroundTaskRow.swift` - Cross-platform colors
  - `AudioPlayerWidget.swift` - Cross-platform colors
  - `VoicePickerWidget.swift` - Cross-platform colors
  - `AppleVoiceProvider.swift` - Removed unused AppKit import

#### Documentation
- **New Documentation Files**:
  - `CLAUDE.md` - Comprehensive guide for AI assistants working on the project
  - `CHANGELOG.md` - This file, tracking all changes
  - `Docs/SCREENPLAY_UI_SPRINT_METHODOLOGY.md` - 8-phase UI sprint plan
  - `Docs/SCREENPLAY_UI_DECISIONS.md` - 6 critical UI design decisions
  - `Docs/Previous/PHASE1_TESTING_STRATEGY.md` - Detailed testing strategy

- **Updated Documentation**:
  - `AI_DEVELOPMENT_GUIDE.md` - Added ScreenplaySpeech sections
  - `AI_REFERENCE.md` - Added SpeakableItemGenerationTask deep dive
  - `README.md` - Updated with Catalyst support and test counts

- **Documentation Organization**:
  - Moved 28 older documentation files to `Docs/Previous/`
  - Moved `AI_DEVELOPMENT_GUIDE.md` to project root for easier access
  - Kept current sprint docs in main `Docs/` directory

### Fixed

- **BackgroundTaskManager Queue Processing** - Fixed infinite task re-execution bug
  - Tasks now properly transition from `.queued` to `.running` to `.completed`
  - Queue processor no longer re-executes completed tasks
  - While loop terminates correctly after processing all tasks

### Technical Details

#### Architecture Decisions
1. **Background Tasks**: Floating palette (not modal overlay) for better UX
2. **Voice Settings**: Provider-specific settings palette
3. **Provider Selection**: Global provider picker at top of palette
4. **Cancellation**: Preserve partial results, no rollback
5. **Auto-Assignment**: OUT OF SCOPE (auto-detect only)
6. **Screenplay Tracking**: screenplayID added to SpeakableItem

#### Quality Metrics
- **Test Coverage**: 90%+ on all non-UI ScreenplaySpeech code
- **Test Count**: 787 total tests (559 → 787, +228 tests)
- **Code Quality**: Swift 6 strict concurrency compliant
- **Build Status**: Zero compilation errors or warnings

#### Performance Characteristics
- **Typical Performance**: ~500 elements/second screenplay processing
- **Memory Usage**: Incremental saves every 50 elements
- **Cancellation Latency**: <100ms response time
- **UI Responsiveness**: All operations on background threads

## [1.x] - Previous Releases

See previous commit history for v1.x changes.

### Phase 0-7 Completion Summary
- ✅ Core protocol definitions (AIServiceProvider, AIGeneratable)
- ✅ Comprehensive error handling framework
- ✅ SwiftData model base classes for all content types
- ✅ Provider registry system (AIServiceManager)
- ✅ Thread-safe request management (AIRequestManager actor)
- ✅ Secure keychain integration (SecureKeychainManager)
- ✅ Real provider implementations (OpenAI, Anthropic, Apple Intelligence, ElevenLabs)
- ✅ Typed return data system with SwiftData persistence
- ✅ 12 AI requestors across 4 content types (Text, Audio, Image, Embedding)
- ✅ 559 tests with 90%+ coverage across all core modules
- ✅ Swift 6.0 strict concurrency compliance

---

## Version History

- **Unreleased**: UI Sprint Phase 1-2 (787 tests, Catalyst support)
- **1.x**: Core framework with 559 tests, 90%+ coverage

## Links

- [GitHub Repository](https://github.com/intrusive-memory/SwiftHablare)
- [Issue Tracker](https://github.com/intrusive-memory/SwiftHablare/issues)
- [Pull Requests](https://github.com/intrusive-memory/SwiftHablare/pulls)
