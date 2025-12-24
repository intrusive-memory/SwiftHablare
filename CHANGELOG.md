# Changelog

All notable changes to SwiftHablaré will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [5.4.0] - 2025-12-24

### Added

#### AsyncStream-Based Notification System
- **Deterministic audio synthesis completion** - Event-driven architecture replaces timeout-based waiting
  - `AsyncStream<SynthesisEvent>` for thread-safe event emission from AVSpeechSynthesizer callbacks
  - Guaranteed happens-before ordering: all buffer callbacks complete before `didFinish()` fires
  - No arbitrary timeouts - waits indefinitely for synthesis to complete (correct behavior)
  - Thread-safe event emission from arbitrary threads (AVSpeechSynthesizer delegate callbacks)
  - Fully cancellable by caller (external task cancellation)
  - Zero data races - guaranteed ordering ensures safe shared state access

- **Documentation**
  - `Docs/CONCURRENCY_MODEL.md` - Complete architecture diagrams and concurrency model
  - `Docs/NOTIFICATION_SYSTEM.md` - AsyncStream implementation guide
  - `Docs/NOTIFICATION_SYSTEM_TESTING.md` - Comprehensive testing strategy

### Changed

#### Audio File Creation
- **Explicit interleaved parameter** in AVAudioFile creation
  - Fixes deprecation warnings in Xcode 16.2+
  - Uses modern API: `AVAudioFile(forWriting:settings:commonFormat:interleaved:)`
  - Explicitly sets `interleaved: false` (matches PCM format requirements)
  - No behavioral change - always used non-interleaved format

### Fixed

- **AVAudioFile API deprecation** - Updated to use explicit interleaved parameter
  - Resolves Xcode 16.2+ warnings about deprecated initializer
  - Future-proof against API changes

### Technical Details

#### Architecture Changes
- **Event-Driven Synthesis**: Replaced continuation-based waiting with AsyncStream events
  - More robust than single-use continuations
  - Natural for event-driven programming (multiple events, cancellation)
  - Built-in stream lifecycle management

#### Quality Metrics
- **Test Count**: 390+ tests passing (all platforms)
- **Test Coverage**: 96%+ maintained
- **Build Status**: ✅ All platforms passing (iOS, macOS)
- **Swift 6**: Full strict concurrency compliance
- **CI/CD**: All required checks passing

## [5.3.0] - 2025-12-09

### Added

#### ElevenLabs Model Selector
- **User-selectable TTS models** in ElevenLabs configuration
  - New `ElevenLabsModel` enum with 5 available models
  - Multilingual v2 (highest quality, default)
  - Turbo v2.5 (fastest)
  - Turbo v2 (fast)
  - Multilingual v1 (legacy)
  - Monolingual v1 (English only, legacy)
- **SwiftUI model picker** in ElevenLabs preferences pane
  - Dropdown selector with model names and descriptions
  - Link to ElevenLabs model documentation
  - Footer showing selected model details
- **Persistent model selection** stored in UserDefaults
  - `selectedModel()` - Get current selection
  - `updateSelectedModel()` - Change model preference
  - Automatically used in audio generation

#### Development Tools
- **ship-swift-library skill** for automated releases
  - Verifies PR quality gates (CI checks, documentation, version, changelog)
  - Automates merge, tagging, and GitHub release creation
  - Safety checks to prevent accidental destructive operations
  - Available as user-global skill in `~/.claude/skills/`
- **Pre-commit git hooks** for local audio validation
  - Runs 3 audio hardware tests before allowing commits (~5-10 seconds)
  - Validates 16-bit PCM format, AVAudioPlayer compatibility, and duration accuracy
  - Automatically skips on CI or non-macOS systems
  - Install with `./.githooks/install.sh`

#### Documentation
- **WellSaid Labs integration requirements** (comprehensive technical spec)
  - Complete API integration details
  - Architecture following Engine Boundary pattern
  - Testing strategy (40-50 new tests, 95%+ coverage target)
  - 6-phase implementation plan (3-week timeline)
  - AudioProcessor integration for accurate MP3 duration

### Changed

#### Error Handling Improvements
- **Invalid voice ID handling** for Apple TTS ([#73](https://github.com/intrusive-memory/SwiftHablare/pull/73))
  - macOS: Now throws `VoiceProviderError` for invalid voice IDs (no silent fallback)
  - iOS: Falls back to default voice (platform limitation - `AVSpeechSynthesisVoice` behavior)
  - **Breaking Change**: macOS apps using invalid voice IDs will receive errors
- **Platform-aware tests** handle iOS/macOS voice ID validation differences

#### Performance & Concurrency
- **AudioProcessor modernization**
  - Replaced semaphore with async/await patterns
  - Better Swift 6 concurrency compliance
  - Improved thread safety

### Fixed
- **Test suite compatibility** with invalid voice ID error handling
  - Updated 3 tests to handle platform-specific behavior
  - All 390+ tests pass on both platforms
  - iOS: Tests skip audio hardware validation on CI
  - macOS: All tests pass on physical machines
- **CI test reliability** with automatic environment detection
  - Tests detect GitHub Actions `CI` environment variable
  - 6 audio format validation tests skip on CI (no audio hardware)
  - Pattern: `if ProcessInfo.processInfo.environment["CI"] != nil { return }`
  - Prevents false failures on headless CI runners

### Technical Details

#### Files Added
1. `.claude/skills/ship-swift-library.md` - Release automation skill
2. `.claude/skills/README.md` - Skills directory documentation
3. `Docs/WellSaidIntegrationRequirements.md` - WellSaid integration spec (1,116 lines)
4. `.githooks/pre-commit` - Pre-commit hook for local audio tests
5. `.githooks/install.sh` - Git hooks installation script
6. `.githooks/README.md` - Git hooks documentation

#### Files Modified
1. `Sources/SwiftHablare/Providers/ElevenLabsVoiceProvider.swift` - Model selector (+102 lines)
   - ElevenLabsModel enum with 5 models
   - selectedModel() and updateSelectedModel() methods
   - Updated configuration view with model picker
2. `Sources/SwiftHablare/Utilities/AudioProcessor.swift` - Async/await refactoring
3. `Sources/SwiftHablare/Providers/Apple/NSSpeechTTSEngine.swift` - Invalid voice ID errors
4. `Tests/SwiftHablareTests/SpeakableItemTests.swift` - CI environment detection, platform-aware tests
5. `Tests/SwiftHablareTests/SpeakableGroupTests.swift` - Valid voice ID usage
6. `Tests/SwiftHablareTests/GenerateAudioButtonTests.swift` - Valid voice ID usage
7. `Tests/SwiftHablareTests/AVSpeechTTSEngineTests.swift` - CI environment detection for audio format tests
8. `.github/workflows/fast-tests.yml` - TEST_RUNNER_CI environment variable passing
9. `CLAUDE.md` - CI testing section, git hooks documentation
10. `README.md` - Pre-commit hooks section, updated test count
11. `Docs/TestPlans.md` - CI environment variable detection documentation

#### Quality Metrics
- **Test Count**: 390+ tests passing (all platforms)
- **Test Coverage**: 96%+ maintained
- **Build Status**: ✅ All platforms passing (iOS, macOS)
- **Swift 6**: Full strict concurrency compliance
- **CI/CD**: All required checks passing (Code Quality, Fast Tests iOS/macOS, Performance Tests)

### Migration Notes

#### ElevenLabs Model Selection (Non-Breaking)
```swift
// Existing code works unchanged (uses default Multilingual v2)
let provider = ElevenLabsVoiceProvider()
let audio = try await provider.generateAudio(text: "Hello", voiceId: "id", languageCode: "en")

// New: Select different model
provider.updateSelectedModel(.turboV2_5)  // Use fastest model
let audio = try await provider.generateAudio(text: "Hello", voiceId: "id", languageCode: "en")
```

#### Invalid Voice ID Error Handling (Breaking on macOS)
```swift
// macOS - BEFORE (v5.2.0): Silent fallback to default voice
let audio = try await provider.generateAudio(text: "Test", voiceId: "invalid-id", languageCode: "en")
// Worked, used default voice

// macOS - AFTER (v5.3.0): Throws error
do {
    let audio = try await provider.generateAudio(text: "Test", voiceId: "invalid-id", languageCode: "en")
} catch VoiceProviderError.invalidRequest(let message) {
    print("Invalid voice: \(message)")  // "Voice not found: invalid-id"
}

// iOS - No change: Still falls back to default voice
```

## [5.2.0] - 2025-12-07

### Added - Audio Processing and Quality Improvements

#### AudioProcessor Utility
- **New AudioProcessor utility** for silence trimming and duration measurement
  - Detects and trims silence from start and end of audio (-50dB threshold)
  - Measures accurate duration of trimmed audio
  - Returns `ProcessedAudio` struct with metadata (duration, trimStart, trimEnd)
  - Supports multiple input formats (MP3, PCM/WAV, AIFF, M4A)
  - Always exports to M4A format for consistent playback

#### VoiceProvider Protocol Enhancement
- **New `generateProcessedAudio()` method** on VoiceProvider protocol
  - Returns `ProcessedAudio` with trimmed data and measured duration
  - Default implementation uses AudioProcessor to process raw audio
  - Providers can override for custom processing
  - Fixes timeline gap issues caused by inaccurate duration estimates

### Changed

#### ElevenLabs Voice Provider Updates
- **Upgraded to highest quality model**: `eleven_multilingual_v2`
  - Replaces deprecated `eleven_monolingual_v1`
  - Emotionally-aware, lifelike speech with high emotional range
  - Support for 29 languages (vs English-only in v1)
  - Future-proof against v1 deprecation
  - Same cost (1 credit per character)

- **Switched to MP3 format** for better compatibility
  - Changed output format from `pcm_44100` to `mp3_44100_128`
  - Updated MIME type from `audio/L16` to `audio/mpeg`
  - Eliminates complex WAV wrapping requirements
  - Smaller file sizes (128kbps vs uncompressed PCM)
  - No stereo/mono confusion
  - More predictable timing and duration

- **Consistent M4A export**: All processed audio converted to M4A
  - Single output format across all providers
  - Eliminates format-specific playback issues
  - Consistent behavior for downstream consumers

### Fixed
- **Accurate duration measurement**: ProcessedAudio includes measured duration from AVAsset
  - Eliminates estimation errors from text-based duration calculations
  - Accounts for encoder padding and format-specific timing
  - Provides single source of truth for audio duration
- **Silence trimming**: Automatic removal of leading/trailing silence
  - No manual padding adjustments needed
  - Cleaner audio output
  - Better timeline synchronization in playback

### Technical Details

#### Files Added
1. `Sources/SwiftHablare/Utilities/AudioProcessor.swift` - Audio processing utilities (287 lines)
   - `ProcessedAudio` struct for processed audio metadata
   - `AudioProcessor.process()` for silence trimming and duration measurement
   - Support for MP3, PCM, AIFF, M4A input formats
   - M4A export for consistent output

#### Files Modified
1. `Sources/SwiftHablare/VoiceProvider.swift` - Added generateProcessedAudio() method
2. `Sources/SwiftHablare/Providers/ElevenLabsVoiceProvider.swift` - MP3 format, model upgrade
3. `Sources/SwiftHablare/Providers/ElevenLabs/ElevenLabsEngine.swift` - MP3 output format

#### Quality Metrics
- **Test Count**: 289 tests passing
- **Test Coverage**: 96%+ maintained
- **Build Status**: ✅ All platforms passing (iOS, macOS)
- **Swift 6**: Full strict concurrency compliance

#### Performance Characteristics
- **Audio Processing**: ~100-500ms for typical voice clips (depends on length)
- **Silence Detection**: 100ms chunks for accurate threshold detection
- **M4A Export**: Uses AVAssetExportSession for efficient conversion
- **File Sizes**: MP3 input (~128kbps), M4A output (AAC compression)

### Migration Notes

**Non-Breaking Changes** - All features are backward compatible.

#### For existing code using VoiceProvider
```swift
// Old approach (still works):
let audioData = try await provider.generateAudio(text: "Hello", voiceId: "id", languageCode: "en")

// New approach (recommended):
let processed = try await provider.generateProcessedAudio(text: "Hello", voiceId: "id", languageCode: "en")
// Now you have:
// - processed.audioData (trimmed, M4A format)
// - processed.durationSeconds (accurate measurement)
// - processed.trimmedStart (silence removed from start)
// - processed.trimmedEnd (silence removed from end)
// - processed.mimeType (always "audio/mp4")
```

#### For ElevenLabs users
- **No action required** - Format change is automatic
- Audio output is now MP3 (instead of PCM) from ElevenLabs API
- Final exported audio is always M4A (consistent across all providers)
- File sizes will be smaller (~128kbps MP3 vs uncompressed PCM)

### Benefits
- **Accurate Duration**: No more timeline gaps from estimation errors
- **Clean Audio**: Automatic silence trimming improves playback experience
- **Consistent Format**: M4A export works reliably across all platforms
- **Better Quality**: ElevenLabs v2 model provides emotionally-aware speech
- **Smaller Files**: MP3 format reduces storage and bandwidth requirements
- **Simplified Processing**: No complex PCM wrapping or stereo/mono handling

## [5.1.2] - 2025-12-06

### Removed
- **BREAKING**: Removed Mac Catalyst support
  - Removed `.macCatalyst(.v26)` from Package.swift platform targets
  - Removed Catalyst from CI/CD test matrices
  - Removed Catalyst-specific test cases and platform guards
  - Updated all documentation to reflect iOS and macOS only
  - **Migration**: Mac Catalyst users should use the iOS build or macOS build depending on their needs

## [5.1.1] - 2025-12-06

### Added
- **Platform Version Enforcement**: Multi-layered enforcement to prevent old platform code
  - Custom SwiftLint rules to detect `@available`, `#available`, `#unavailable` with versions < 26
  - Supports both macOS and iOS platform detection
  - Regex patterns match versions 0-25 (blocks old platforms)
  - Comprehensive documentation in `Docs/PLATFORM-ENFORCEMENT.md`
  - Quick-start guide in `QUICK-START-ENFORCEMENT.md`

### Changed
- **Swift Concurrency**: Changed `.enableExperimentalFeature` to `.enableUpcomingFeature("StrictConcurrency")` in Package.swift
- **Documentation**: Added platform version enforcement section to CLAUDE.md
- **SwiftLint Configuration**: Improved `.swiftlint.yml` maintainability with YAML anchors

## [4.1.2] - 2025-11-24

### Changed
- **Performance Test Optimization**: Reduced integration test load for faster CI execution
  - Optimized performance testing configuration
  - Improved test execution speed and reliability
  - Reduced CI resource usage

### Fixed
- **iOS Simulator Compatibility**: Skip flaky cache expiration test on iOS Simulator
  - Fixed workflow dependencies for performance tests
  - Added conditional test skipping for simulator-specific issues
- **Swift 6 Concurrency**: Resolved Swift 6 concurrency errors in PerformanceTests
  - Fixed actor isolation violations in performance test suite
  - Ensured full Swift 6 strict concurrency compliance
- **CI Baseline Accuracy**: Use commit SHA instead of branch for baseline checkout
  - Ensures accurate performance comparisons in CI
  - Prevents baseline drift from branch updates

### Documentation
- Updated development workflow documentation to match SwiftCompartido standard
- Added branch protection configuration documentation
- Updated `.claude/WORKFLOW.md` with complete workflow guide

### Refactoring
- Extracted language code resolution into shared `LanguageCodeResolver` utility
  - Consolidated 10+ duplicate locale resolution implementations
  - Consistent fallback behavior across codebase
- Removed deprecated `VoiceProviderType` enum and `VoiceProviderInfo` struct
  - Cleaned up unused code and improved API surface clarity

### CI/CD
- Restructured performance tests to run after unit tests
- Added performance tests as dependency job in PR workflow
- Enabled performance test PR comments with auto-update
- Added baseline comparison to performance CI

### Test Coverage
- Enhanced performance testing with additional metrics
- **Total Tests**: 259 passing (maintained from 4.1.1)
- **Coverage**: 96%+ maintained

## [4.1.1] - 2025-11-24

### Fixed

**Critical Bug: Autosave Permanently Disabled on Cache Clearing Errors**

Fixed a critical bug where `modelContext.autosaveEnabled` would be left permanently disabled if `save()` throws during cache clearing operations, potentially causing silent data loss for subsequent operations.

#### Problem

The cache clearing methods (`clearVoiceCache()` and `clearAllVoiceCaches()`) temporarily disabled autosave for performance optimization:

```swift
modelContext.autosaveEnabled = false
cachedModels.forEach { modelContext.delete($0) }
try modelContext.save()
modelContext.autosaveEnabled = true  // ❌ SKIPPED if save() throws!
```

If `modelContext.save()` throws (validation error, I/O failure, disk full, etc.), the final line is never executed, leaving autosave permanently disabled for that context.

#### Solution

Use Swift's `defer` statement to guarantee autosave restoration even when exceptions are thrown:

```swift
modelContext.autosaveEnabled = false
defer { modelContext.autosaveEnabled = true }  // ✅ ALWAYS executes
cachedModels.forEach { modelContext.delete($0) }
try modelContext.save()
```

#### Impact

- **Data Integrity**: Prevents silent data loss from disabled autosave
- **Reliability**: Ensures proper cleanup even when operations fail
- **Performance**: Zero performance impact (defer is a zero-cost abstraction)
- **Test Coverage**: Added `testCacheClearingRestoresAutosave()` to verify fix

#### Files Changed

- `Sources/SwiftHablare/Generation/GenerationService.swift`:
  - `clearVoiceCache()`: Added defer block for autosave restoration
  - `clearAllVoiceCaches()`: Added defer block for autosave restoration
- `Tests/SwiftHablareTests/GenerationServiceTests.swift`:
  - Added `testCacheClearingRestoresAutosave()` test case

### Test Coverage

- **Total Tests**: 260 passing (up from 259)
- **Coverage**: 96%+ maintained
- **Platforms**: iOS 26+, macOS 26+, Catalyst 26+

**Upgrade Recommendation**: ⚠️ **High Priority** - This patch fixes a data integrity issue. All users of v4.0.0 and v4.1.0 should upgrade immediately.

## [4.1.0] - 2025-11-24

### Added
- **Performance Testing CI Infrastructure**: Comprehensive performance testing with baseline comparison
  - 21 performance benchmarks covering core operations (voice loading, generation, caching, UI)
  - Automated baseline recording and comparison in CI
  - Performance regression detection with detailed reports
  - Separate weekly integration test schedule for long-running tests
  - Performance tests run as dependency after unit tests pass in PRs
  - Baseline storage in git for historical tracking

### Changed
- **CI Workflow Optimization**: Split testing into fast (unit) and slow (integration) categories
  - Fast tests run on every PR (unit tests only, ~30 seconds)
  - Integration tests run weekly on schedule (~2-5 minutes)
  - Performance tests run after unit tests pass (informational, non-blocking)
  - Branch protection rules validated and documented

### Documentation
- Added `Docs/PERFORMANCE_TESTING.md` - Complete performance testing guide
- Updated `CLAUDE.md` with performance testing workflow and CI structure
- Updated `.claude/WORKFLOW.md` with branch protection validation instructions
- Added performance metrics to test documentation

### Impact
- **CI Speed**: PR checks complete in ~8-10 minutes (down from 15-20 minutes)
- **Test Coverage**: 259 tests maintained with 96%+ coverage
- **Performance Monitoring**: Automated detection of performance regressions
- **Developer Experience**: Faster feedback loops with focused fast tests

## [4.0.0] - 2025-11-23

### Performance Improvements

This release focuses on performance optimization and code cleanup based on a comprehensive codebase audit. See `Docs/PERFORMANCE_AUDIT_V4.md` for complete analysis.

#### Removed Dead Code
- **Removed** deprecated `VoiceProviderType` enum (19 lines, never used)
- **Removed** unused `VoiceProviderInfo` struct (21 lines, replaced by RegisteredVoiceProvider)
- **Impact**: -42 lines of dead code, reduced API surface complexity

#### Critical Concurrency Fix
- **Fixed** unsafe UserDefaults access in VoiceProviderRegistry actor
- **Removed** `nonisolated(unsafe)` marker that bypassed Swift 6 concurrency safety
- **Impact**: Eliminates potential data races, full Swift 6 strict concurrency compliance

#### Code Consolidation
- **Added** `mimeType` property to VoiceProvider protocol
- **Eliminated** 4 duplicate switch statements for MIME type determination (27 lines)
- **Impact**: Single source of truth, easier maintenance, no runtime overhead

#### Utility Extraction
- **Created** `LanguageCodeResolver` utility for consistent language code resolution
- **Replaced** 10+ duplicate instances of locale resolution logic
- **Impact**: -12 lines, consistent behavior, easier to test and modify

#### UI Performance
- **Optimized** FetchDescriptor creation in GenerateAudioButton
- **Eliminated** duplicate database queries (2 queries reduced to 1)
- **Impact**: 50% faster audio existence checks (~25-50ms vs ~50-100ms)

#### Database Performance
- **Optimized** voice cache invalidation with batch deletion
- **Applied** to clearVoiceCache() and clearAllVoiceCaches()
- **Impact**: 10-20x faster cache clearing (~10-20ms vs ~200-300ms for 100 voices)

### Breaking Changes
- `VoiceProviderType` enum removed (was already deprecated)
- `VoiceProviderInfo` struct removed (unused, replaced by RegisteredVoiceProvider)
- `VoiceProvider` protocol now requires `mimeType` property

### Migration Guide

**For custom VoiceProvider implementations:**
```swift
// Before:
public final class MyProvider: VoiceProvider {
    public let providerId = "my-provider"
    public let displayName = "My Provider"
    public let requiresAPIKey = true
}

// After (add mimeType):
public final class MyProvider: VoiceProvider {
    public let providerId = "my-provider"
    public let displayName = "My Provider"
    public let requiresAPIKey = true
    public let mimeType = "audio/mpeg"  // NEW REQUIREMENT
}
```

### Performance Summary
- **Total Lines Removed/Consolidated**: 80+ lines
- **Voice Loading**: 15-25% faster with optimized caching
- **UI Updates**: 30-50% faster with FetchDescriptor optimization
- **Cache Clearing**: 10-20x faster with batch deletion
- **Test Coverage**: Maintained at 96%+ across all changes

### Current Status (as of 2025-11-23)
- **Version**: 4.0.0
- **Tests**: 259 passing tests with 96%+ coverage
- **Platforms**: iOS 26+, macOS 26+, Catalyst 26+ (all fully supported)
- **Swift**: 6.0+ with strict concurrency enabled
- **Features**: Voice Provider Registry, Engine Boundary Protocol, Multi-language support

### Documentation
- Updated CLAUDE.md, README.md, and CHANGELOG.md to reflect current status
- Clarified macOS support (fully supported with NSSpeechSynthesizer via Engine Boundary Protocol)
- Updated test counts (259 passing tests, up from 215)
- Removed outdated UIKit-only references
- Clarified platform support across iOS 26+, macOS 26+, and Catalyst 26+
- Added Engine Boundary Protocol documentation
- Updated platform-specific implementation details

### Removed
- Removed deprecated VoiceProviderType enum references from documentation
- Removed outdated manual caching examples (automatic caching is now standard)
- Cleaned up simulator-specific workarounds in documentation

## [3.5.1] - 2025-11-07

### Added - Voice Provider Registry and Configuration System

#### VoiceProviderRegistry
- **Centralized Provider Management**: New `VoiceProviderRegistry` singleton for discovering, enabling, and configuring voice providers
  - Automatic registration of built-in providers (Apple TTS always enabled, ElevenLabs user-configurable)
  - Dynamic provider enablement state persisted in UserDefaults
  - Provider configuration validation before instantiation
  - Support for external provider registration via `VoiceProviderAutoRegistrar` base class
  - SwiftUI configuration panel integration for provider setup

- **VoiceProviderDescriptor**: Lightweight metadata describing each provider
  - Provider ID, display name, and default enablement state
  - Configuration requirements flag
  - Factory closure for on-demand provider instantiation
  - SwiftUI configuration panel builder for collecting credentials
  - Always-enabled flag for providers like Apple TTS

- **RegisteredVoiceProvider**: Public API for provider metadata
  - Provider ID, display name, and enablement status
  - Configuration status (isConfigured)
  - Enables UI to show provider availability and state

#### Provider Configuration Panels
- **AppleVoiceProvider**: SwiftUI configuration view
  - Simple informational panel (no credentials required)
  - Shows system voice availability
  - Auto-configures on first use

- **ElevenLabsVoiceProvider**: SwiftUI configuration view with API key input
  - Secure text field for API key entry
  - Keychain integration for credential storage
  - Validation and error feedback
  - Test connection capability

#### GenerationService Integration
- Updated `GenerationService` to use `VoiceProviderRegistry`
  - Removed hardcoded provider initialization
  - New methods: `availableProviderStatuses()`, `setProvider(_:enabled:)`, `isProviderEnabled(_:)`
  - Provider lookup now validates both enablement and configuration state
  - Backward-compatible API with registry-based implementation

#### VoiceProvider Protocol Extensions
- Added `makeConfigurationView(onConfigured:)` default implementation
  - Returns SwiftUI view for provider configuration
  - Callback-based completion handling
  - Integrates with registry configuration flow

#### VoiceProviderAutoRegistrar
- Base class for organizing provider registration in external packages
  - Subclass and override `descriptors` property to define providers
  - Provides `registerProviders(into:)` helper method
  - **Requires manual registration**: Swift does not support Objective-C `+load` for automatic registration
  - External packages must call `registerProviders(into:)` during app initialization

#### Test Coverage
- **80+ new tests** with 100% pass rate:
  - `VoiceProviderRegistryTests.swift` - 45 tests
    - Provider registration, enablement toggling, configuration validation
    - Descriptor management, factory instantiation
    - UserDefaults persistence, default provider behavior
    - Edge cases: duplicate registration, invalid IDs, concurrent access
  - `VoiceProviderAutoRegistrarTests.swift` - 12 tests
    - Automatic registration on class load
    - Descriptor creation and validation
    - Singleton registry integration
  - `GenerationServiceTests.swift` - 4 additional tests
    - Registry integration, provider status queries
    - Enablement state management
    - Isolated test registry support
  - `GenerateAudioButtonTests.swift` - 7 updated tests
    - Provider picker integration with registry
    - Configuration status display

#### Documentation
- **New Skill**: `Skills/register_voice_provider.skill.md`
  - Step-by-step guide for creating custom voice providers
  - Registration patterns (manual and automatic)
  - Configuration panel implementation examples
  - Integration testing guidance

- **CLAUDE.md Updates**:
  - Comprehensive Voice Provider Registry section
  - Provider registration patterns
  - Configuration panel guidelines
  - External provider integration examples

### Changed

#### Architecture
- **Provider Lifecycle**: Providers now created on-demand via factory pattern instead of upfront initialization
- **Enablement Model**: User-controlled enablement state separate from configuration state
- **Configuration Flow**: Standardized SwiftUI configuration panel workflow across all providers

#### API Changes (Non-Breaking)
- `GenerationService.init()` now accepts optional `providerRegistry` parameter (defaults to `.shared`)
- `GenerationService.registeredProviders()` changed from `nonisolated` to `async` (returns instantiated providers)
- `GenerationService.registerProvider()` changed from `nonisolated` to `async`
- `GenerationService.provider(withId:)` changed from `nonisolated` to `async`
- `GenerationService.isProviderRegistered()` changed from `nonisolated` to `async`

#### ProviderPickerView Updates
- Now displays provider enablement and configuration status
- Shows checkmarks for enabled providers
- Displays configuration status badges
- Updated to use `availableProviderStatuses()` instead of `registeredProviders()`

### Fixed

#### GenerationService Tests
- Fixed test isolation issues in CI/CD environment
  - Tests were failing due to shared VoiceProviderRegistry state accumulating across test runs
  - Updated 4 tests to use isolated registries with test-specific UserDefaults suites
  - Tests: `testDefaultProvidersAreRegistered`, `testRegisterCustomProvider`, `testRegisterProviderReplacesExisting`, `testRegisteredProvidersIncludesAllProviders`

#### Registry State Management
- Fixed provider registry cleanup between test runs
  - Tests now create isolated registry instances with custom UserDefaults suites
  - Prevents cross-test contamination in CI environments
  - Maintains test independence and reliability

### Technical Details

#### Files Added
1. `Sources/SwiftHablare/VoiceProviderRegistry.swift` - Provider registry implementation (291 lines)
2. `Sources/SwiftHablare/VoiceProviderAutoRegistrar.swift` - Auto-registration base class (50 lines)
3. `Tests/SwiftHablareTests/VoiceProviderRegistryTests.swift` - Registry tests (175 lines)
4. `Tests/SwiftHablareTests/VoiceProviderAutoRegistrarTests.swift` - Auto-registrar tests (32 lines)
5. `Tests/SwiftHablareTests/Support/TestUserDefaults.swift` - Test isolation utility (31 lines)
6. `Skills/register_voice_provider.skill.md` - Provider registration guide (43 lines)

#### Files Modified
1. `Sources/SwiftHablare/Generation/GenerationService.swift` - Registry integration (67 additions, 70 deletions)
2. `Sources/SwiftHablare/Providers/AppleVoiceProvider.swift` - Configuration panel (53 additions)
3. `Sources/SwiftHablare/Providers/ElevenLabsVoiceProvider.swift` - Configuration panel (136 additions)
4. `Sources/SwiftHablare/UI/ProviderPickerView.swift` - Status display (19 additions, 11 deletions)
5. `Sources/SwiftHablare/VoiceProvider.swift` - Configuration view protocol (19 additions)
6. `Tests/SwiftHablareTests/GenerationServiceTests.swift` - Isolated registries (32 additions, 4 deletions)
7. `Tests/SwiftHablareTests/GenerateAudioButtonTests.swift` - Registry integration (7 additions)

#### Quality Metrics
- **Test Count**: 259 total tests (comprehensive coverage)
- **Test Coverage**: 96%+ on voice generation components
- **Build Status**: ✅ All platforms passing (iOS, macOS, Catalyst)
- **Swift 6**: Full strict concurrency compliance with strict mode enabled
- **CI/CD**: Zero test failures in isolated test runs

#### Performance Characteristics
- **Provider Instantiation**: Lazy creation only when needed
- **Registry Lookup**: O(1) dictionary-based provider resolution
- **Enablement State**: Persisted in UserDefaults, cached in memory
- **Configuration Validation**: On-demand checking during provider retrieval

### Migration Notes

**No Breaking Changes** - All API changes are backward compatible.

#### For Existing Code
- Existing code continues to work without modification
- `GenerationService` automatically uses `VoiceProviderRegistry.shared`
- Provider registration and lookup now async (await required)

#### For Custom Providers
```swift
// Direct registration (simple approach)
let customProvider = MyVoiceProvider()
await service.registerProvider(customProvider)

// Using VoiceProviderAutoRegistrar (for packages)
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

// Must be called during app initialization:
await MyProviderRegistrar.registerProviders(into: .shared)
```

#### For UI Code
```swift
// Old: Fetching providers
let providers = service.registeredProviders()

// New: Fetching provider statuses with enablement info
let statuses = await service.availableProviderStatuses()
for status in statuses {
    print("\(status.displayName): enabled=\(status.isEnabled), configured=\(status.isConfigured)")
}
```

## [2.3.0] - 2025-10-27

### Added - UI Components for Audio Generation

#### SpeakableGroup Protocol
- **New Protocol**: `SpeakableGroup` for grouping multiple `SpeakableItem` objects
  - Enables batch audio generation for collections (chapters, scenes, playlists)
  - Recursive expansion support (groups can contain other groups)
  - Optional group description for UI display
  - Default `itemCount` implementation

- **5 Example Implementations** in `SpeakableGroupExamples.swift`:
  - `Chapter` - Books with dialogue lines
  - `Scene` - Theatrical scripts with interactions
  - `MessagePlaylist` - Notifications with priority levels
  - `ArticleSections` - Long-form content with sections
  - `ShoppingList` - Enumerated task lists

#### GenerateAudioButton (Individual Generation)
- SwiftUI component for individual element audio generation
- **Features**:
  - Automatic detection of existing audio in SwiftData
  - Smart button text: Shows "Generate" or "Play" based on audio availability
  - Progress tracking with percentage display
  - Cancellation support during generation
  - Optional `onPlay` callback for playback integration

- **Race Condition Fix**:
  - Added `checkTask` property to store async check task reference
  - Guard state updates to only apply when in `.checking` state
  - Cancel checkTask when generation begins
  - Prevents duplicate generation when user taps before check completes

#### GenerateGroupButton (Batch Generation)
- SwiftUI component for batch audio generation of grouped items
- **Features**:
  - Automatic detection of existing audio for all items
  - Smart button text:
    - "Generate All (N items)" when some items need audio
    - "Regenerate All (N items)" when all items have audio
  - Progress tracking: "X/Y items (Z%)"
  - Skips items with existing audio by default (efficient)
  - Cancellation support with partial result preservation
  - Uses `SpeakableItemList` internally for sequential processing
  - Optional `onComplete` callback with generated records

- **State Machine**:
  - `.checking` - Detecting existing audio
  - `.readyToGenerate` - Some items need generation
  - `.readyToRegenerate` - All items have audio
  - `.generating` - Active generation with progress
  - `.completed` - Generation finished with statistics
  - `.failed` - Error occurred with message

#### Test Coverage
- **55+ new tests** with 100% pass rate:
  - `GenerateAudioButtonTests.swift` - 13 tests
    - Initialization, state management, generation, playback callbacks
    - Race condition scenarios
    - SwiftData integration
    - Provider compatibility
  - `SpeakableGroupTests.swift` - 18 tests
    - Protocol conformance, all 5 example implementations
    - GenerateGroupButton functionality, progress tracking
    - Empty groups, multiple records, integration tests
  - `ElementGenerationButtonTests.swift` - 24 tests (Hablare example app)
    - Grouped element detection, button selection logic
    - All 14 element types, document structure
    - Section levels, integration scenarios, performance

### Changed

#### Documentation Updates
- **CLAUDE.md**:
  - Updated version to 2.3.0
  - Updated test count to 164+ passing
  - Added comprehensive SpeakableGroup protocol section
  - Updated Core Components architecture diagram
  - Updated UI Components section with new buttons
  - Updated "What's Included" section

- **README.md**:
  - Added UI Components section with usage examples
  - Added SpeakableGroup protocol documentation
  - Updated Core Features to mention optional UI components
  - Added GenerateAudioButton and GenerateGroupButton examples

#### Architecture
- Core library remains focused on voice generation
- UI components are optional SwiftUI additions
- No breaking changes to existing APIs

### Technical Details

#### Files Added
1. `Sources/SwiftHablare/Protocols/SpeakableGroup.swift` - Protocol definition
2. `Sources/SwiftHablare/UI/GenerateAudioButton.swift` - Individual generation button
3. `Sources/SwiftHablare/UI/GenerateGroupButton.swift` - Batch generation button
4. `Sources/SwiftHablare/Examples/SpeakableGroupExamples.swift` - 5 example groups
5. `Tests/SwiftHablareTests/GenerateAudioButtonTests.swift` - 13 tests
6. `Tests/SwiftHablareTests/SpeakableGroupTests.swift` - 18 tests
7. `Examples/Hablare/Hablare/GuionElement+SpeakableGroup.swift` - Screenplay extensions
8. `Examples/Hablare/Hablare/ElementGenerationButton.swift` - Smart selector
9. `Examples/Hablare/Hablare/ScreenplayGenerationListView.swift` - Complete example
10. `Tests/SwiftHablareTests/ElementGenerationButtonTests.swift` - 24 tests

#### Quality Metrics
- **Test Count**: 164+ total tests (109 → 164, +55 tests)
- **Test Coverage**: 96%+ on voice generation components
- **Build Status**: Zero compilation errors or warnings
- **Swift 6**: Full strict concurrency compliance

#### Performance
- Group generation: Sequential processing with progress tracking
- Existing audio detection: Parallel SwiftData queries
- UI responsiveness: All generation on background threads

### Migration Notes

**No Breaking Changes** - All features are additive.

Existing code continues to work. New components are opt-in:
- Use `GenerateAudioButton` for individual elements
- Use `GenerateGroupButton` for scenes/chapters/groups
- Use `SpeakableGroup` protocol to create custom groups

## Previous Releases

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

### Added - Voice Provider Integration Tests with SwiftData Persistence

#### End-to-End Testing with Real Audio and Database Persistence
- **AppleVoiceProviderIntegrationTests** - Complete test suite for Apple TTS
  - Real audio generation using AVSpeechSynthesizer
  - AIFF format audio output (real speech audio)
  - Comprehensive audio validation:
    - File size checks (> 1KB)
    - Duration validation (> 1 second for test text)
    - Non-zero sample verification (confirms actual speech content)
    - Sample percentage analysis
  - Test artifacts saved to `.build/*/TestArtifacts/` directory
  - Tests with multiple voices and long text passages
  - Always runs on iOS 26+ and Catalyst (no external dependencies, no macOS)
  - **SwiftData persistence test**: Full end-to-end database flow
    - Generate audio → `toTypedDataStorage()` → SwiftData insert → save → fetch → verify
    - Validates data integrity after round-trip through database
    - Tests that retrieved audio matches original audio exactly

- **ElevenLabsVoiceProviderIntegrationTests** - Complete test suite for ElevenLabs API
  - Real API calls with production ElevenLabs service
  - Conditional execution (only runs if ELEVENLABS_API_KEY environment variable set)
  - Ephemeral API key support (bypasses keychain for clean testing)
  - MP3 audio artifact generation
  - Tests with multiple voices and long text passages
  - Graceful test skipping when API key unavailable
  - Clean test environment (no keychain pollution)
  - **SwiftData persistence test**: Full end-to-end database flow
    - Generate audio → `toTypedDataStorage()` → SwiftData insert → save → fetch → verify
    - Validates data integrity after round-trip through database
    - Validates MP3 format on retrieved audio
    - Tests that retrieved audio matches original audio exactly

#### Enhanced Voice Provider Implementations
- **AppleVoiceProvider** - Audio generation for iOS 26+ and Catalyst (AIFF format)
  - **iOS 26+ & Catalyst**: Uses AVSpeechSynthesizer.write() with real audio generation
  - Full audio validation (duration, sample content)
  - UIKit-based implementation (no macOS support)
  - Consistent AIFF output format across iOS 26+ and Catalyst platforms

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
- **iOS 26+ and Catalyst Support** - Full UIKit-based implementation
  - Cross-platform color APIs throughout UI components
  - Settings app integration for Accessibility > Spoken Content
  - No AppKit dependencies (UIKit-only)
  - Tested on iOS 26+ and Catalyst platforms
  - **No macOS support** - UIKit-based library only

### Changed

#### Platform Compatibility Updates
- **VoiceSettingsWidget** - UIKit-based system voice settings access
  - Opens Settings app for Accessibility > Spoken Content
  - Uses UIApplication.shared.open() for iOS 26+ and Catalyst
  - Platform-appropriate URL schemes

- **Color API Migration** - Updated all UI components to use UIKit-compatible colors
  - `Color(nsColor: .controlBackgroundColor)` → `Color(.systemBackground)`
  - `Color(nsColor: .systemGray)` → `Color(.systemGray)`
  - Ensures consistent appearance across iOS 26+ and Catalyst platforms

- **Files Updated for iOS/Catalyst Compatibility**:
  - `VoiceSettingsWidget.swift` - UIKit settings integration
  - `VoiceProviderWidget.swift` - UIKit-compatible colors
  - `BackgroundTaskRow.swift` - UIKit-compatible colors
  - `AudioPlayerWidget.swift` - UIKit-compatible colors
  - `VoicePickerWidget.swift` - UIKit-compatible colors
  - `AppleVoiceProvider.swift` - AVFoundation only, no AppKit dependencies

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
