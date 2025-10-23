# SwiftHablare Tests

Comprehensive test suite for the SwiftHablare text-to-speech library.

## Test Coverage

### Model Tests

#### VoiceTests.swift
Tests for the `Voice` model:
- Initialization with various configurations
- Default values
- Codable conformance (encoding/decoding)
- Round-trip encoding/decoding
- Identifiable conformance
- Mutable properties

#### VoiceModelTests.swift
Tests for the `VoiceModel` SwiftData model:
- Initialization
- SwiftData persistence
- Uniqueness constraints
- Deletion
- Conversion to/from `Voice`
- Round-trip conversion
- Querying by provider ID
- Sorted queries
- Timestamp handling

#### AudioFileTests.swift
Tests for the `AudioFile` SwiftData model:
- Initialization with various metadata
- Custom IDs and dates
- SwiftData persistence
- Uniqueness constraints
- Deletion
- Querying by voice ID, provider ID, and combined criteria
- Sorted queries by creation date
- Audio format handling
- Audio metadata (sample rate, bit rate, channels)
- Mono vs stereo configurations
- Empty and large data handling

#### SwiftHablareLibraryTests.swift
Tests for the main library interface:
- Version information
- Semantic versioning format validation

### Protocol and Type Tests

#### VoiceProviderTests.swift
Tests for `VoiceProvider` protocol and related types:
- `VoiceProviderType` enum (raw values, display names, all cases, Codable)
- `VoiceProviderError` error descriptions
- `MockVoiceProvider` implementation
- Mock provider configuration and behavior
- Call tracking and verification
- Error simulation
- Sendable conformance

### Manager Tests

#### VoiceProviderManagerTests.swift
Tests for `VoiceProviderManager`:
- Initialization (default and with saved preferences)
- Provider registration and retrieval
- Provider configuration checks
- Provider switching
- Voice caching and retrieval
- Force refresh functionality
- Audio generation
- Audio caching with SwiftData
- Duplicate detection
- File writing
- Published property observation
- UserDefaults persistence
- Error handling

### Provider Tests

#### AppleVoiceProviderTests.swift
Tests for Apple Voice Provider using mock simulator (24 tests):
- Provider properties and configuration
- Voice fetching with quality levels
- Gender detection
- Language and locality parsing
- Audio generation in CAF format
- Duration estimation algorithm
- Voice availability checks
- Error handling
- Complete integration flows

#### ElevenLabsVoiceProviderTests.swift
Tests for ElevenLabs Voice Provider using mock simulator (35 tests):
- Provider properties and API key management
- Voice fetching with ElevenLabs API format
- Voice descriptions and metadata
- Gender and language information
- Audio generation in MP3 format
- HTTP error code handling (401, 404, 429, 500)
- Duration estimation algorithm
- Voice availability checks
- API response format validation
- Complete integration flows
- Multiple consecutive generations

## Mock Objects

### MockVoiceProvider.swift
A comprehensive mock implementation of `VoiceProvider` for testing:
- Configurable responses for all protocol methods
- Call tracking for verification
- Error simulation
- State management
- Reset functionality

### MockAppleVoiceProviderSimulator.swift
Simulates Apple VoiceProvider with realistic responses (no actual speech generation):
- Returns simulated Apple voices (Samantha, Alex, Daniel, Karen, Ava)
- Generates valid CAF audio file headers
- Simulates Apple's duration estimation algorithm (~14.5 chars/sec)
- Supports quality levels (Enhanced, Premium)
- Gender detection for common Apple voice names
- Language/locality parsing
- Configurable error states
- Call tracking

### MockElevenLabsVoiceProviderSimulator.swift
Simulates ElevenLabs VoiceProvider with documented API responses (no actual speech generation):
- Returns simulated ElevenLabs voices (Rachel, Antoni, Bella, etc.)
- Generates valid MP3 audio file headers
- Simulates ElevenLabs duration estimation algorithm (~13 chars/sec)
- API key management
- HTTP error code simulation (401, 404, 429, 500)
- Documented API response formats
- Voice metadata (gender, accent, age, use case)
- Configurable error states
- Call tracking

## Running Tests

```bash
# Run all tests
swift test

# Clean build and run tests
swift package clean && swift test
```

## Test Statistics

- **Total Tests**: 138
- **Test Suites**: 8
- **Model Tests**: 36
- **Protocol/Type Tests**: 16
- **Manager Tests**: 24
- **Library Tests**: 3
- **Provider Tests**: 59 (Apple: 24, ElevenLabs: 35)

### Integration Tests

#### AppleVoiceProviderIntegrationTests.swift
End-to-end tests with audio generation (always run):
- **End-to-end speech generation** - Full workflow from text to audio file
- **Multiple voice testing** - Test with different system voices
- **Long text handling** - Performance testing with extended text
- **Audio validation**:
  - File format validation (AIFF on all platforms)
  - File size checks (> 1KB)
  - Duration validation (> 1 second for test text)
  - Non-zero sample verification (confirms actual speech on native macOS)
  - Sample percentage analysis
- **Test artifacts** - Saves .aiff files to TestArtifacts/ directory
- **Cross-platform** - Runs on native macOS, Mac Catalyst, and iOS

#### ElevenLabsVoiceProviderIntegrationTests.swift
End-to-end tests with real API calls (conditional execution):
- **Conditional execution** - Only runs if ELEVENLABS_API_KEY environment variable is set
- **Ephemeral API keys** - Uses in-memory API keys (no keychain pollution)
- **End-to-end speech generation** - Full workflow with real API
- **Multiple voice testing** - Test with up to 3 different ElevenLabs voices
- **Long text handling** - Performance testing with extended text
- **Audio validation**:
  - File format validation (MP3)
  - File size checks
  - Duration estimation verification
- **Test artifacts** - Saves .mp3 files to TestArtifacts/ directory
- **Clean test environment** - No keychain side effects

**Running integration tests**:
```bash
# Run all tests (Apple integration tests always run)
swift test

# Run with ElevenLabs API key for full coverage
ELEVENLABS_API_KEY=your-key-here swift test
```

## Test Organization

```
Tests/SwiftHablareTests/
├── Mocks/
│   ├── MockVoiceProvider.swift
│   ├── MockAppleVoiceProviderSimulator.swift
│   └── MockElevenLabsVoiceProviderSimulator.swift
├── Integration/
│   ├── AppleVoiceProviderIntegrationTests.swift
│   └── ElevenLabsVoiceProviderIntegrationTests.swift
├── AudioFileTests.swift
├── VoiceTests.swift
├── VoiceModelTests.swift
├── VoiceProviderTests.swift
├── VoiceProviderManagerTests.swift
├── AppleVoiceProviderTests.swift
├── ElevenLabsVoiceProviderTests.swift
├── SwiftHablareLibraryTests.swift
└── SwiftHablareTests.swift (original)
```

## Test Artifacts

Integration tests generate audio files for manual verification:
- **Location**: `.build/*/TestArtifacts/`
- **Apple TTS**: `.aiff` files with timestamped names (all platforms)
- **ElevenLabs**: `.mp3` files with timestamped names
- **Git**: Excluded via .gitignore

## Notes

- All tests use in-memory SwiftData containers to avoid side effects
- Tests are isolated and can run in parallel
- Mock objects support comprehensive verification
- UserDefaults are cleaned up in tearDown methods
- Temporary files are cleaned up after file I/O tests
- Integration tests generate audio artifacts for verification
- ElevenLabs integration tests gracefully skip without API key
