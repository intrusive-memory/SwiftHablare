# SwiftHablaré - Claude Code Development Guide

This document provides guidance for AI assistants (particularly Claude Code) working on the SwiftHablaré project.

## Quick Reference

- **Current Version**: 5.3.0 (check `SwiftHablare.swift:84` for actual version string)
- **Swift Version**: 6.2+
- **Minimum Deployments**: iOS 26+, macOS 26+
- **Test Suite**: 289 passing tests

## ⚠️ CRITICAL: Platform Version Enforcement

**This library ONLY supports iOS 26.0+ and macOS 26.0+. NEVER add code that supports older platforms.**

### Rules for Platform Versions

1. **NEVER add `@available` attributes** for versions below iOS 26.0 or macOS 26.0
   - ❌ WRONG: `@available(iOS 15.0, macOS 12.0, *)`
   - ✅ CORRECT: No `@available` needed (package enforces iOS 26/macOS 26)

2. **NEVER add `#available` runtime checks** for versions below iOS 26.0 or macOS 26.0
   - ❌ WRONG: `if #available(iOS 15.0, *) { ... }`
   - ✅ CORRECT: No runtime checks needed (package enforces minimum versions)

3. **Platform-specific code is OK** (macOS vs iOS differences)
   - ✅ CORRECT: `#if os(macOS)` or `#if canImport(AppKit)`
   - ✅ CORRECT: `#if canImport(UIKit)`
   - ❌ WRONG: Checking for specific OS versions below 26

4. **Package.swift must always specify iOS 26 and macOS 26**
   ```swift
   platforms: [
       .iOS(.v26),
       .macOS(.v26)
   ]
   ```

5. **User-facing messages** must reflect iOS 26/macOS 26 requirements
   - ❌ WRONG: "Requires macOS 15 or iOS 18"
   - ✅ CORRECT: "Requires macOS 26 or iOS 26"

**DO NOT lower the platform requirements. Apps using this library must update their deployment targets to iOS 26+ and macOS 26+.**
- **Test Coverage**: 96%+ on voice generation components
- **Swift Concurrency**: Full Swift 6 compliance with strict concurrency enabled
- **Test Frameworks**: Mixed XCTest and Swift Testing (`@Suite`/`@Test`)

## Project Overview

**SwiftHablaré** is a Swift voice generation library for iOS and macOS applications. It provides a unified API for text-to-speech generation using multiple voice providers (Apple TTS and ElevenLabs), with secure API key management, and optional SwiftUI components.

**Key Focus**: Voice generation library with optional UI components. Includes core generation services, SwiftUI pickers and buttons, but no audio playback, no screenplay processing beyond generation. SwiftHablaré is a **generation library** with helpful UI components, not a complete application framework.

## Core Architecture

### Key Components

```
SwiftHablare/
├── VoiceProvider.swift              # Protocol for voice providers
├── Protocols/
│   ├── VoiceEngine.swift            # Engine Boundary Protocol
│   ├── SpeakableItem.swift          # Protocol for speakable objects
│   └── SpeakableGroup.swift         # Protocol for grouped speakable items
├── Models/
│   ├── Voice.swift                  # Voice model (id, name, language, etc.)
│   ├── VoiceURI.swift               # Portable voice references (hablare:// scheme)
│   └── SpeakableItemList.swift      # Batch generation with progress
├── Providers/
│   ├── AppleVoiceProvider.swift     # Apple TTS implementation
│   ├── ElevenLabsVoiceProvider.swift # ElevenLabs API implementation
│   ├── Apple/                       # Platform-specific engines
│   └── ElevenLabs/                  # ElevenLabs engine adapter
├── Generation/
│   └── GenerationService.swift      # Actor-based service with provider registry
├── VoiceProviderRegistry.swift      # Registry + enablement state for providers
├── Security/
│   └── KeychainManager.swift        # Secure API key storage
├── UI/
│   ├── ProviderPickerView.swift     # SwiftUI provider picker
│   ├── VoicePickerView.swift        # SwiftUI voice picker
│   ├── GenerateAudioButton.swift    # Individual audio generation button
│   └── GenerateGroupButton.swift    # Batch generation button for groups
└── Examples/
    ├── SpeakableItemExamples.swift  # 5 example implementations
    ├── SpeakableGroupExamples.swift # 5 example group implementations
    └── GuionElementSpeakableExamples.swift # 6 GuionElement adapters
```

### Key Features

- **Multi-Provider Support**: Apple TTS (built-in) and ElevenLabs (API-based)
- **Engine Boundary Protocol**: Platform-agnostic voice engine abstraction (v3.5.1+)
- **Voice URI**: Portable voice references with `hablare://` URI scheme
- **Cast List Export**: Character-to-voice mapping export (JSON format)
- **Protocol-Oriented Design**: `SpeakableItem` and `SpeakableGroup` protocols
- **Thread-Safe Generation**: Actor-based concurrency (GenerationService)
- **SwiftData Integration**: Uses `TypedDataStorage` from SwiftCompartido
- **Performance Optimizations**: 15-25% faster voice loading, 50% faster UI (v4.0.0+)

### Audio Format Requirements

**CRITICAL**: All generated audio MUST be in **16-bit integer PCM** format (not 32-bit float).

#### Why 16-bit PCM?

`AVAudioPlayer` (the standard iOS/macOS playback API) **cannot play 32-bit float PCM** audio. While `AVAudioFile` can read it, `AVAudioPlayer.prepareToPlay()` will fail (returns `false` with `duration = 0.0`).

**Symptoms of wrong format:**
- ✅ AVAudioFile can open the file
- ❌ AVAudioPlayer.prepareToPlay() returns false
- ❌ player.duration == 0.0
- ❌ No playback occurs

#### Implementation (AppleVoiceProvider)

The `AVSpeechTTSEngine` converts audio buffers during generation:

```swift
// Create 16-bit PCM output format
let format16Bit = AVAudioFormat(
    commonFormat: .pcmFormatInt16,
    sampleRate: sampleRate,
    channels: channels,
    interleaved: false
)

// Convert each buffer from AVSpeechSynthesizer (which provides float) to 16-bit
if let converter = AVAudioConverter(from: inputFormat, to: format16Bit) {
    // Convert and write 16-bit PCM to file
}
```

#### Testing Requirements

**All audio generation tests MUST verify:**

1. **Format is 16-bit integer PCM** (not float):
   ```swift
   let bitDepth = settings[AVLinearPCMBitDepthKey] as? Int
   let isFloat = settings[AVLinearPCMIsFloatKey] as? Bool
   XCTAssertEqual(bitDepth, 16)
   XCTAssertEqual(isFloat, false)
   ```

2. **AVAudioPlayer can play it**:
   ```swift
   let player = try AVAudioPlayer(contentsOf: audioURL)
   XCTAssertTrue(player.prepareToPlay())
   XCTAssertGreaterThan(player.duration, 0.0)
   ```

3. **CI environment handling**:
   - Use `.enabled(if: !ProcessInfo.processInfo.environment.keys.contains("CI"))` trait
   - Skip audio generation tests in headless CI runners (no audio hardware)

#### Benefits of 16-bit PCM

✅ **Compatible** with AVAudioPlayer (universal playback)
✅ **Smaller files** - 50% reduction vs 32-bit float
✅ **Standard format** - Works with all Apple audio APIs
✅ **Better compression** - More efficient than float for speech

#### Legacy Format Handling

If you encounter 32-bit float AIFC files (from older SwiftHablare versions):
- These require on-the-fly conversion to 16-bit PCM for playback
- See `GuionAudioLibraryView.convertTo16BitPCM()` in Produciesta
- New audio should NEVER be generated in this format

### Platform Support

**Supported Platforms:**
- **iOS 26+**: Full TTS support with `AVSpeechSynthesizer.write()` (AIFC format)
- **macOS 26+**: Full TTS support with `AVSpeechSynthesizer.write()` (AIFC format)

**Unified Implementation:**
- Both iOS and macOS use `AVSpeechTTSEngine` (AVFoundation)
- Single implementation using `AVSpeechSynthesizer` across all platforms
- No platform-specific engine code required

**Simulator Behavior:**
- Physical iOS/macOS devices: Real TTS audio generation
- iOS Simulator: Limited audio support (AVSpeechSynthesizer.write() constraints, generates placeholder audio)
- macOS: Always produces real audio

Integration tests requiring real audio are skipped on simulators using `#if targetEnvironment(simulator)`.

## Core Protocols

### VoiceProvider

Defines interface for voice generation services:

```swift
public protocol VoiceProvider {
    var providerId: String { get }
    var displayName: String { get }
    var requiresAPIKey: Bool { get }
    var mimeType: String { get }

    func isConfigured() -> Bool
    func fetchVoices(languageCode: String?) async throws -> [Voice]
    func generateAudio(text: String, voiceId: String, languageCode: String?) async throws -> Data
    func estimateDuration(text: String, voiceId: String) async -> TimeInterval
    func isVoiceAvailable(voiceId: String) async -> Bool
}
```

**Implementations**: `AppleVoiceProvider` (always configured), `ElevenLabsVoiceProvider` (requires API key)

### VoiceEngine

Platform-agnostic engine boundary for low-level synthesis:

```swift
public protocol VoiceEngine {
    func fetchVoices(request: VoiceEngineRequest) async throws -> [Voice]
    func generateAudio(request: VoiceEngineRequest) async throws -> VoiceEngineOutput
}
```

See `Docs/EngineBoundaryProtocol.md` for detailed architecture.

### SpeakableItem

Protocol-oriented text-to-speech generation:

```swift
public protocol SpeakableItem {
    var voiceProvider: VoiceProvider { get }
    var voiceId: String { get }
    var textToSpeak: String { get }
    var languageCode: String { get } // Defaults to system language
}
```

**Example Implementations** (see `Examples/SpeakableItemExamples.swift`):
- SimpleMessage, CharacterDialogue, Article, Notification, ListItem

**Convenience Methods**:
- `speak() async throws -> Data` - Generate audio for item
- `estimateDuration() async -> TimeInterval` - Estimate duration
- `isVoiceAvailable() async -> Bool` - Check voice availability

### SpeakableGroup

Batch audio generation for grouped items:

```swift
public protocol SpeakableGroup {
    var groupName: String { get }
    func getGroupedElements() -> [any SpeakableItem]
    var groupDescription: String? { get }
}
```

**Example Implementations** (see `Examples/SpeakableGroupExamples.swift`):
- Chapter, Scene, MessagePlaylist, ArticleSections, ShoppingList

### SpeakableItemList

Observable batch generation with progress tracking:

```swift
@Observable
public final class SpeakableItemList {
    public let name: String
    public private(set) var currentIndex: Int = 0
    public let totalCount: Int
    public var progress: Double { ... }
    public var isProcessing: Bool { ... }
    public var statusMessage: String { ... }
}
```

**Features**: Sequential processing, progress tracking, cancellation support, SwiftData integration

## Voice Providers

### AppleVoiceProvider

- **Configuration**: Always configured (no API key)
- **Format**: AIFF (macOS), AIFC (iOS)
- **MIME Type**: `audio/x-aiff`
- **Test Coverage**: 22 unit tests (100%)

### ElevenLabsVoiceProvider

- **Configuration**: Requires API key (stored in Keychain)
- **Format**: MP3 (128kbps, 44.1kHz)
- **MIME Type**: `audio/mpeg`
- **Output Format**: `mp3_44100_128` (MP3 audio, processed to M4A via AudioProcessor)
- **Model**: `eleven_multilingual_v2` (highest quality, emotionally-aware, 29 languages)
- **Note**: Audio is automatically processed to M4A with silence trimming via `generateProcessedAudio()`
- **Test Coverage**: 30 unit tests (95%+), 5 integration tests

## Voice URI & Cast List Export

**VoiceURI** provides portable voice references using the `hablare://` URI scheme:

```swift
// Format: hablare://<providerId>/<voiceId>?lang=<languageCode>
let uri = VoiceURI(providerId: "apple", voiceId: "voice-id", languageCode: "en")

// Parse from string (failable initializer)
guard let parsed = VoiceURI(uriString: "hablare://elevenlabs/voice-id?lang=en") else {
    throw VoiceError.invalidURI
}

// Resolve to Voice with automatic fallback
let voice = try await uri.resolve(using: service)

// Check availability
let isAvailable = await uri.isAvailable(using: service)
```

**CastListPage Integration** (from SwiftCompartido):

```swift
// Create cast list from voice mappings
let voiceMappings: [String: VoiceURI] = [
    "ALICE": VoiceURI(from: voice1, languageCode: "en"),
    "BOB": VoiceURI(from: voice2, languageCode: "en")
]
let castList = CastListPage.fromVoiceMapping(title: "Cast", mapping: voiceMappings)

// Export to JSON (SwiftCompartido custom-pages.json format)
try castList.exportToJSON(url: jsonURL)

// Import from JSON
let imported = try CastListPage.importFromJSON(url: jsonURL)
let mappings = imported.exportVoiceMappings()
```

**Test Coverage**: 48 tests in `VoiceURITests.swift` (100%)

## SwiftCompartido Integration

SwiftHablaré integrates with SwiftCompartido for:
- **TypedDataStorage**: Generated audio persistence
- **GuionElement**: Screenplay/markdown element voice generation
- **CastListPage**: Character-to-voice mapping export/import

### GuionElement Support

Comprehensive support for markdown and screenplay elements:

**Example Implementations** (see `Examples/GuionElementSpeakableExamples.swift`):
1. **GuionElementSpeakable** - General adapter for any GuionElement
2. **DialoguePairSpeakable** - Character-dialogue pairs
3. **SectionHeadingSpeakable** - Markdown/screenplay headings with level context
4. **SceneSpeakable** - Groups screenplay elements by scene (SpeakableGroup)
5. **ChapterSpeakable** - Groups elements by chapter/act (SpeakableGroup)
6. **MarkdownDocumentSpeakable** - Complete markdown file generation (SpeakableGroup)

**Test Coverage**: 26 tests in `GuionElementSpeakableTests.swift` (100%)

## Key Patterns

### 1. Thread-Safe Generation with GenerationService

```swift
// Create service (actor for thread safety)
let service = GenerationService(modelContext: modelContext)

// Generate audio
let result = try await service.generate(
    text: "Hello, world!",
    providerId: "apple",
    voiceId: "voice-id",
    voiceName: "Voice Name"
)

// Convert to SwiftData
let storage = result.toTypedDataStorage()
modelContext.insert(storage)
try modelContext.save()
```

### 2. Voice Provider Registry

```swift
// Get all registered providers
let providers = await service.registeredProviders()

// Fetch voices from specific provider
let appleVoices = try await service.fetchVoices(from: "apple")

// Fetch with specific language
let spanishVoices = try await service.fetchVoices(from: "apple", languageCode: "es")

// Fetch from all providers
let allVoices = try await service.fetchAllVoices()
```

### 3. Batch Generation with Progress

```swift
// Create speakable items
let items: [any SpeakableItem] = [ /* ... */ ]

// Create list with progress tracking
let list = SpeakableItemList(name: "My List", items: items)

// Generate with observable progress
let records = try await service.generateList(list, to: modelContext)

// Access progress properties (Observable)
list.currentIndex  // 0, 1, 2, ...
list.progress      // 0.0 to 1.0
list.statusMessage // "Processing...", "Complete", etc.
```

## Development Workflow

**⚠️ CRITICAL: See [`.claude/WORKFLOW.md`](.claude/WORKFLOW.md) for complete workflow.**

**Quick Reference:**
- **Development branch**: `development` (all work happens here)
- **Main branch**: `main` (protected, PR-only)
- **Workflow**: `development` → PR → CI passes → Merge → Tag → Release
- **NEVER** commit directly to `main`
- **NEVER** delete the `development` branch

### Branch Protection

**Current Required CI Checks:**
- `Code Quality Checks` - Build, linting, code quality
- `Fast Tests (iOS)` - Unit tests on iOS Simulator
- `Fast Tests (macOS)` - Unit tests on macOS

Update branch protection when CI workflow changes:
```bash
gh api repos/intrusive-memory/SwiftHablare/branches/main/protection/required_status_checks
```

### Git Hooks

**Pre-commit Audio Tests:**

SwiftHablare includes a pre-commit hook that runs local audio tests before allowing commits. This ensures audio generation features remain working on development machines.

**Install hooks:**
```bash
./.githooks/install.sh
```

**What the hook does:**
- Runs `LocalAudioTests.xctestplan` (3 tests, ~5-10 seconds)
- Validates 16-bit PCM format generation
- Tests AVAudioPlayer compatibility
- Verifies accurate duration calculation
- Automatically skips on CI or non-macOS systems

**Bypass (not recommended):**
```bash
git commit --no-verify
```

**See `.githooks/README.md` for detailed documentation.**

### Development Best Practices

**For New Features:**
1. Read documentation (this file, README.md, test files)
2. Plan with TodoWrite tool for complex tasks
3. Write tests first (TDD approach, aim for 95%+ coverage)
4. Implement features following existing patterns
5. Verify coverage: `swift test --enable-code-coverage`

**For Bug Fixes:**
1. Write failing test to reproduce the bug
2. Fix the bug
3. Verify test passes and existing tests still work
4. Document changes as needed

## Testing Strategy

### Test Organization

**Fast Tests (Unit):**
- Run on every PR
- Complete in ~30 seconds
- Test class names WITHOUT "Integration"
- 390+ test functions across 21 files

**Integration Tests:**
- Run weekly on Saturdays at 3 AM UTC
- Complete in ~2-5 minutes
- Include real API calls (require API key)
- Test class names WITH "Integration"

### Running Tests

```bash
# Run all tests (recommended)
swift test --enable-code-coverage

# iOS Simulator
xcodebuild test -scheme SwiftHablare \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'

# macOS
xcodebuild test -scheme SwiftHablare \
  -destination 'platform=macOS'
```

### Test Frameworks

**Mixed Framework Support:**
- **XCTest**: Legacy tests with async setUp/tearDown
- **Swift Testing**: Modern tests with `@Suite` and `@Test` macros
- Both frameworks work together seamlessly

**SwiftData Test Pattern:**

```swift
// XCTest pattern
@MainActor
class MyTests: XCTestCase {
    var modelContext: ModelContext!
    var modelContainer: ModelContainer!

    override func setUp() async throws {
        let schema = Schema([TypedDataStorage.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [config])
        modelContext = ModelContext(modelContainer)
    }
}

// Swift Testing pattern
@Suite @MainActor
struct MyTests {
    func makeTestContainer() throws -> ModelContainer {
        let schema = Schema([TypedDataStorage.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
```

### Coverage Targets

- Voice Providers: 95%+
- GenerationService: 95%+
- KeychainManager: 95%+
- Models: 100%
- **Current**: 96%+ average coverage, 0 failures

## Code Style

### Voice Provider Implementation

```swift
public final class MyVoiceProvider: VoiceProvider {
    public let providerId = "my-provider"
    public let displayName = "My Provider"
    public let requiresAPIKey = true
    public let mimeType = "audio/mpeg"

    public func isConfigured() -> Bool {
        return (try? keychain.get(key: "\(providerId)-api-key")) != nil
    }

    public func fetchVoices(languageCode: String?) async throws -> [Voice] { /* ... */ }
    public func generateAudio(text: String, voiceId: String, languageCode: String?) async throws -> Data { /* ... */ }
    public func estimateDuration(text: String, voiceId: String) async -> TimeInterval { /* ... */ }
    public func isVoiceAvailable(voiceId: String) async -> Bool { /* ... */ }
}
```

### Actor-Based Services

```swift
actor MyService {
    private let provider: VoiceProvider

    init(voiceProvider: VoiceProvider) {
        self.provider = voiceProvider
    }

    func process(_ request: MyRequest) async throws -> MyResult {
        // Actor ensures thread-safe operations
        return MyResult()
    }
}
```

### Platform-Specific Code

```swift
#if os(iOS)
// UIKit-specific behavior
#elseif os(macOS)
// AppKit-specific behavior
#endif

#if targetEnvironment(simulator)
// Simulator-specific behavior (skip audio tests, etc.)
#endif
```

## Library Scope

**In Scope:**
- ✅ Voice provider integration (Apple TTS, ElevenLabs) with language filtering
- ✅ Provider registry and management
- ✅ Language-specific voice fetching
- ✅ Multi-language support with automatic system language detection
- ✅ Thread-safe audio generation (actor-based)
- ✅ API key management (Keychain)
- ✅ TypedDataStorage integration for generated audio
- ✅ SpeakableItem protocol for protocol-oriented TTS with language codes
- ✅ SpeakableGroup protocol for batch audio generation
- ✅ SpeakableItemList for batch generation with progress
- ✅ Platform compatibility (iOS 26+, macOS 26+)
- ✅ Simple UI pickers (provider & voice selection)
- ✅ Audio generation buttons (individual & batch)

**Out of Scope:**
- ❌ Audio playback (apps handle playback)
- ❌ Audio file I/O (apps handle file storage)
- ❌ Screenplay processing or domain-specific models (use SwiftCompartido)
- ❌ Background task management
- ❌ Character-to-voice mapping (provided via VoiceURI + CastListPage)
- ❌ Complex UI workflows beyond generation

## Quality Gates

Before submitting a PR:
- ✅ All tests pass
- ✅ 95%+ test coverage on new code
- ✅ Swift 6 strict concurrency compliance
- ✅ No compiler warnings
- ✅ Documentation updated
- ✅ CHANGELOG.md updated
- ✅ Platform compatibility verified (iOS/macOS)

## Resources

### Documentation
- `README.md` - Project overview and API documentation
- `CHANGELOG.md` - Version history
- `.claude/WORKFLOW.md` - Complete development workflow
- `Docs/EngineBoundaryProtocol.md` - Engine architecture details
- `Docs/SPEAKABLE_ITEM_LIST_FLOW.md` - Batch generation flow diagrams

### Testing
- `Tests/SwiftHablareTests/` - 390+ tests across 21 test files
- `Tests/README.md` - Test suite documentation

### Examples
- `Examples/Hablare/` - Sample application (minimal reference)
- `Sources/SwiftHablare/Examples/` - Protocol implementation examples

### External Resources
- [SwiftCompartido](https://github.com/intrusive-memory/SwiftCompartido) - Screenplay parsing and TypedDataStorage
- [Fountain.io Specification](https://fountain.io) - Screenplay format standard

---

**For Questions or Contributions:**
- GitHub Issues: https://github.com/intrusive-memory/SwiftHablare/issues
- GitHub Discussions: https://github.com/intrusive-memory/SwiftHablare/discussions

**Note**: SwiftHablaré targets iOS 26+ and macOS 26+. Ensure new code paths consider both supported Apple platforms.
