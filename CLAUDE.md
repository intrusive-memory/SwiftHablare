# SwiftHablaré - Claude Code Development Guide

This document provides guidance for AI assistants (particularly Claude Code) working on the SwiftHablaré project.

## Project Overview

**SwiftHablaré** is a Swift voice generation library for iOS and Mac Catalyst applications. It provides a simple, unified API for text-to-speech generation using multiple voice providers (Apple TTS and ElevenLabs), with automatic voice caching and secure API key management.

**Key Focus**: Voice generation only - no UI components, no data persistence beyond voice caching, no screenplay processing. SwiftHablaré is a **generation library**, not an application framework.

## Version Information

- **Current Version**: 2.0.1
- **Swift Version**: 6.0+
- **Minimum Deployments**: iOS 26.0, macCatalyst 15.0
- **macOS Support**: Build/test compatibility only (placeholder audio for TTS)
- **Total Tests**: 73 passing
- **Test Coverage**: 96%+ on voice generation components
- **Swift Concurrency**: Full Swift 6 compliance

## Platform Support

### iOS and Catalyst Only

SwiftHablaré targets UIKit-based platforms:
- **iOS 26.0+** ✅ Full TTS support with real audio generation
- **macCatalyst 15.0+** ✅ Full TTS support with real audio generation
- **macOS 26.0+** ⚠️ Build/test compatibility only (placeholder audio)

### Why No macOS Support?

- `AVSpeechSynthesizer.write()` does not properly invoke buffer callbacks on macOS
- The library uses platform-specific code (`#if os(macOS)`) to return placeholder audio for tests
- Real text-to-speech synthesis only works on iOS and Mac Catalyst

## Architecture

### Core Components

```
SwiftHablare/
├── VoiceProvider.swift              # Protocol for voice providers
├── Models/
│   └── Voice.swift                  # Voice model (id, name, language, etc.)
├── Providers/
│   ├── AppleVoiceProvider.swift     # Apple TTS implementation
│   └── ElevenLabsVoiceProvider.swift # ElevenLabs API implementation
├── Generation/
│   └── GenerationService.swift      # Actor-based generation service
├── Security/
│   └── KeychainManager.swift        # Secure API key storage
└── SwiftDataModels/
    └── VoiceCacheModel.swift        # Voice caching with SwiftData
```

### No UI Components

SwiftHablaré is a **generation library only**. There are NO UI components:
- ❌ No widgets
- ❌ No views
- ❌ No SwiftUI components
- ❌ No audio players
- ❌ No voice pickers

Consuming applications are responsible for building their own UI using SwiftHablaré's generation APIs.

### No Data Persistence (Beyond Voice Caching)

SwiftHablaré does NOT provide:
- ❌ TypedDataStorage
- ❌ SwiftData models for generated content
- ❌ Audio file storage
- ❌ Persistence coordinators

The only SwiftData model is `VoiceCacheModel` for caching fetched voices to improve performance.

### No Screenplay Processing

SwiftHablaré does NOT include:
- ❌ ScreenplaySpeech system
- ❌ BackgroundTask/BackgroundTaskManager
- ❌ SpeakableItem models
- ❌ Screenplay-to-speech processors

These were removed in version 2.0. SwiftHablaré is a focused voice generation library.

## Voice Providers

### AppleVoiceProvider

**Platform-Specific Behavior:**
```swift
#if os(macOS)
// Returns placeholder AIFF audio (silent) for test compatibility
// Real TTS not available on macOS due to AVSpeechSynthesizer.write() limitation
#else
// iOS/Catalyst: Real speech synthesis using AVSpeechSynthesizer.write()
// Captures audio buffers and writes to AIFF file
#endif
```

**Features:**
- Always configured (no API key required)
- Fetches voices from `AVSpeechSynthesisVoice`
- Filters voices by system language
- Estimates duration using text length heuristics
- Generates AIFF format audio

**Test Coverage:**
- 22 unit tests (100% coverage)
- 4 integration tests (skipped on macOS)

### ElevenLabsVoiceProvider

**Features:**
- Requires API key (stored in Keychain)
- Fetches voices from ElevenLabs API
- Generates MP3 format audio
- Supports ephemeral API keys for testing

**Test Coverage:**
- 30 unit tests (95%+ coverage)
- 5 integration tests (conditional - require API key)

## Key Patterns

### 1. Voice Generation

**Basic Usage:**
```swift
// Initialize provider
let provider = AppleVoiceProvider()
// OR
let provider = ElevenLabsVoiceProvider()

// Fetch available voices
let voices = try await provider.fetchVoices()

// Generate audio
let audioData = try await provider.generateAudio(
    text: "Hello, world!",
    voiceId: voices.first!.id
)
```

### 2. Thread-Safe Generation with GenerationService

**Recommended Pattern:**
```swift
// Create service (actor for thread safety)
let service = GenerationService(voiceProvider: provider)

// Generate audio (thread-safe)
let audioData = try await service.generate(
    text: "Hello, world!",
    voiceId: "voice-id",
    voiceName: "Voice Name"
)
```

**Benefits:**
- ✅ Actor-based synchronization (no data races)
- ✅ Swift 6 concurrency compliant
- ✅ Automatic thread management
- ✅ Clean separation of concerns

### 3. API Key Management

**Storing API Keys:**
```swift
let keychain = KeychainManager()

// Store API key
try keychain.save(
    key: "elevenlabs-api-key",
    value: "your-api-key-here"
)

// Retrieve API key
let apiKey = try keychain.get(key: "elevenlabs-api-key")

// Delete API key
try keychain.delete(key: "elevenlabs-api-key")
```

**Security:**
- ✅ Uses system Keychain for secure storage
- ✅ Thread-safe operations
- ✅ Automatic cleanup on delete

### 4. Voice Caching

**SwiftData Model:**
```swift
@Model
public final class VoiceCacheModel {
    @Attribute(.unique) public var id: String
    public var name: String
    public var providerId: String
    public var language: String?
    public var locality: String?
    public var gender: String?
    public var cachedAt: Date
}
```

**Usage:**
```swift
// Voices are automatically cached when fetched
// Cache reduces API calls and improves performance
// Consuming apps should invalidate cache periodically
```

## Development Workflow

### For New Features

1. **Read Documentation**:
   - This file (CLAUDE.md)
   - README.md for API overview
   - Test files for usage examples

2. **Plan with Todos**:
   - Use TodoWrite tool for complex tasks
   - Break down into manageable steps
   - Track progress throughout implementation

3. **Write Tests First** (TDD approach):
   - Unit tests for core logic
   - Integration tests for end-to-end workflows
   - Aim for 95%+ coverage

4. **Implement Features**:
   - Follow existing patterns
   - Use actors for thread safety
   - Ensure Swift 6 concurrency compliance

5. **Verify Coverage**:
   - Run tests: `swift test --enable-code-coverage`
   - Check coverage: `xcrun llvm-cov report`
   - Aim for 95%+ on all new code

### For Bug Fixes

1. **Write Failing Test**: Create a test that reproduces the bug
2. **Fix the Bug**: Implement the fix
3. **Verify**: Ensure the test passes and existing tests still work
4. **Document**: Update comments and docs as needed

## Code Style

### Voice Provider Implementation

```swift
public final class MyVoiceProvider: VoiceProvider {
    public let providerId = "my-provider"
    public let displayName = "My Provider"
    public let requiresAPIKey = true

    public func isConfigured() -> Bool {
        // Check if API key exists
        return (try? keychain.get(key: "\(providerId)-api-key")) != nil
    }

    public func fetchVoices() async throws -> [Voice] {
        // Fetch voices from API
        // Return Voice models
    }

    public func generateAudio(text: String, voiceId: String) async throws -> Data {
        // Generate audio using API
        // Return audio data (MP3, AIFF, etc.)
    }

    public func estimateDuration(text: String, voiceId: String) async -> TimeInterval {
        // Estimate duration based on text length
        // Return estimated seconds
    }

    public func isVoiceAvailable(voiceId: String) async -> Bool {
        // Check if voice is available
        // Return true/false
    }
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
        // All state access is synchronized
        return MyResult()
    }
}
```

### Platform-Specific Code

```swift
#if os(macOS)
// macOS-specific implementation
// Usually placeholder/mock for testing
#else
// iOS/Catalyst implementation
// Real functionality
#endif
```

## Testing Strategy

### Unit Tests

**Coverage Targets:**
- Voice Providers: 95%+
- GenerationService: 95%+
- KeychainManager: 95%+
- Models: 100%

**Current Status:**
- 73 total tests passing
- 96%+ average coverage
- 0 test failures
- Swift 6 strict concurrency compliance

### Integration Tests

**Apple Voice Provider:**
```swift
func testEndToEndSpeechGeneration() async throws {
    #if os(macOS)
    throw XCTSkip("Apple TTS integration test skipped on macOS")
    #endif

    // Test on iOS/Catalyst only
    let provider = AppleVoiceProvider()
    let voices = try await provider.fetchVoices()
    let audioData = try await provider.generateAudio(text: "Test", voiceId: voices.first!.id)

    // Validate audio
    XCTAssertGreaterThan(audioData.count, 1024)
}
```

**ElevenLabs Voice Provider:**
```swift
func testEndToEndWithElevenLabs() async throws {
    guard let apiKey = ProcessInfo.processInfo.environment["ELEVENLABS_API_KEY"] else {
        throw XCTSkip("ELEVENLABS_API_KEY not set")
    }

    // Test with real API
    let provider = ElevenLabsVoiceProvider()
    // ... test implementation
}
```

### Performance Tests

```swift
func testVoiceFetchingPerformance() async throws {
    measure {
        let voices = try await provider.fetchVoices()
        XCTAssertFalse(voices.isEmpty)
    }
}
```

## Quality Gates

Before submitting a PR:

- ✅ All tests pass
- ✅ 95%+ test coverage on new code
- ✅ Swift 6 strict concurrency compliance
- ✅ No compiler warnings
- ✅ Documentation updated
- ✅ CHANGELOG.md updated
- ✅ Platform compatibility verified (iOS/Catalyst)

## Common Tasks

### Add a New Voice Provider

1. Create class conforming to `VoiceProvider`
2. Implement all required methods
3. Add API key support if needed
4. Write comprehensive tests (20+ test cases)
5. Update documentation

### Generate Audio

```swift
let provider = AppleVoiceProvider()
let voices = try await provider.fetchVoices()
let audioData = try await provider.generateAudio(
    text: "Hello, world!",
    voiceId: voices.first!.id
)
// Use audioData in your app
```

### Cache Voices in SwiftData

```swift
@MainActor
func cacheVoices() async throws {
    let provider = AppleVoiceProvider()
    let voices = try await provider.fetchVoices()

    for voice in voices {
        let cache = VoiceCacheModel(
            id: voice.id,
            name: voice.name,
            providerId: voice.providerId,
            language: voice.language,
            locality: voice.locality,
            gender: voice.gender
        )
        modelContext.insert(cache)
    }
    try modelContext.save()
}
```

## Resources

### Documentation
- `README.md` - Project overview and API documentation
- `CHANGELOG.md` - Version history
- `Tests/README.md` - Test suite documentation
- `VOICE_PROVIDER_INTEGRATION_GUIDE.md` - Provider integration guide

### Testing
- `Tests/SwiftHablareTests/` - All test suites
  - `AppleVoiceProviderTests.swift` - Apple provider tests
  - `GenerationServiceTests.swift` - Service tests
  - `VoiceModelTests.swift` - Model tests
  - `Integration/` - End-to-end integration tests

### Examples
- `Examples/Hablare/` - Sample application (minimal reference)

## Library Scope and Philosophy

**SwiftHablaré is a focused voice generation library**:
- Takes text and voice ID as input
- Generates audio using the specified voice provider
- Returns audio data for the consuming application to use

**Out of Scope**:
- ❌ UI components (apps build their own)
- ❌ Data persistence (beyond voice caching)
- ❌ Audio playback (apps handle playback)
- ❌ Screenplay processing
- ❌ Background task management
- ❌ Character-to-voice mapping

**In Scope**:
- ✅ Voice provider integration (Apple TTS, ElevenLabs)
- ✅ Voice fetching and caching
- ✅ Thread-safe audio generation
- ✅ API key management
- ✅ Platform compatibility (iOS, Catalyst)

---

**For Questions or Contributions**:
- GitHub Issues: https://github.com/intrusive-memory/SwiftHablare/issues
- GitHub Discussions: https://github.com/intrusive-memory/SwiftHablare/discussions
