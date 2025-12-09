# WellSaid Labs Integration Requirements

**Version**: 1.0
**Date**: 2025-12-09
**Target Release**: v5.3.0
**Status**: Draft

---

## Table of Contents

1. [Overview](#overview)
2. [Technical Requirements](#technical-requirements)
3. [Architecture & Methodology](#architecture--methodology)
4. [API Integration Details](#api-integration-details)
5. [Implementation Phases](#implementation-phases)
6. [Testing Strategy](#testing-strategy)
7. [Acceptance Criteria](#acceptance-criteria)
8. [References](#references)

---

## Overview

### Purpose

Integrate WellSaid Labs as a third voice provider for SwiftHablaré, providing users with access to high-quality, natural-sounding AI voices for text-to-speech generation. This integration will mirror the existing ElevenLabs implementation pattern to ensure consistency and maintainability.

### Background

**WellSaid Labs** provides enterprise-grade text-to-speech API with:
- Studio-quality AI voices
- Multiple voice avatars with distinct personalities
- Support for SSML (Speech Synthesis Markup Language)
- Real-time and asynchronous audio generation
- Commercial licensing for generated audio

**Current State**:
- SwiftHablaré currently supports 2 voice providers:
  - Apple TTS (on-device, always available)
  - ElevenLabs (API-based, requires API key)

**Goal**: Add WellSaid Labs as the 3rd provider using the same architecture patterns.

### Success Criteria

- WellSaid Labs provider fully functional with all VoiceProvider protocol methods
- Configuration UI with API key management and voice model selection
- Parity with ElevenLabs feature set (model selection, voice caching, error handling)
- 95%+ test coverage (unit + integration tests)
- All existing tests continue to pass
- Performance benchmarks within acceptable ranges

---

## Technical Requirements

### 1. Core Components

#### 1.1 WellSaidVoiceProvider

**File**: `Sources/SwiftHablare/Providers/WellSaidVoiceProvider.swift`

**Requirements**:
- Implement `VoiceProvider` protocol
- Provider ID: `"wellsaid"`
- Display Name: `"WellSaid Labs"`
- Requires API Key: `true`
- MIME Type: `"audio/mpeg"` ✅ Verified (MP3 format)

**Properties**:
```swift
public final class WellSaidVoiceProvider: VoiceProvider {
    public let providerId = "wellsaid"
    public let displayName = "WellSaid Labs"
    public let requiresAPIKey = true
    public let mimeType: String  // Determined by API response format

    private let keychainManager = KeychainManager.shared
    private let apiKeyAccount = "wellsaid-api-key"
    private let ephemeralAPIKey: String?
    private let engine = WellSaidEngine()
}
```

**Methods** (VoiceProvider protocol):
1. `isConfigured() -> Bool`
   - Check if API key exists and is valid format
   - Delegate to engine's `canGenerate(with:)` method

2. `fetchVoices(languageCode: String) async throws -> [Voice]`
   - Call WellSaid API to retrieve available voices
   - Filter by language if supported by API
   - Map response to SwiftHablaré `Voice` model
   - Handle pagination if needed

3. `generateAudio(text: String, voiceId: String, languageCode: String) async throws -> Data`
   - Use selected voice model from UserDefaults
   - Call WellSaid TTS API
   - Return raw audio data
   - Handle SSML if supported

4. `estimateDuration(text: String, voiceId: String) async -> TimeInterval`
   - Calculate based on character count and speaking rate
   - Use formula similar to ElevenLabs (adjust for WellSaid characteristics)

5. `isVoiceAvailable(voiceId: String) async -> Bool`
   - Verify voice exists via API
   - Return false if API call fails

**API Key Management**:
```swift
public func currentAPIKey() -> String?
public func updateAPIKey(_ apiKey: String) throws
public func clearAPIKey() throws
```

**Model Selection** (mirroring ElevenLabs):
```swift
public func selectedSpeaker() -> WellSaidSpeaker
public func updateSelectedSpeaker(_ speaker: WellSaidSpeaker)
```

#### 1.2 WellSaidEngine

**File**: `Sources/SwiftHablare/Providers/WellSaid/WellSaidEngine.swift`

**Requirements**:
- Implement `VoiceEngine` protocol
- Handle all HTTP communication with WellSaid API
- Manage request/response serialization
- Implement retry logic for transient failures
- Parse WellSaid-specific response formats

**Structure**:
```swift
struct WellSaidEngineConfiguration: Sendable {
    let apiKey: String
    let userAgent: String
}

struct WellSaidEngine: VoiceEngine {
    typealias Configuration = WellSaidEngineConfiguration

    var engineId: String { "wellsaid.tts" }

    func canGenerate(with configuration: WellSaidEngineConfiguration) -> Bool
    func fetchVoices(languageCode: String, configuration: WellSaidEngineConfiguration) async throws -> [Voice]
    func generateAudio(request: VoiceEngineRequest, configuration: WellSaidEngineConfiguration) async throws -> VoiceEngineOutput
    func estimateDuration(request: VoiceEngineRequest, configuration: WellSaidEngineConfiguration) -> TimeInterval
    func isVoiceAvailable(voiceId: String, configuration: WellSaidEngineConfiguration) async -> Bool
}
```

**API Response Types**:
```swift
// Mirror ElevenLabs pattern, adapted for WellSaid's "avatar" terminology
struct WellSaidAvatarsResponse: Codable {
    let avatars: [WellSaidAvatar]  // WellSaid uses "avatars" not "voices"
}

struct WellSaidAvatar: Codable {
    let id: String
    let name: String
    let description: String?
    let language: String?
    let gender: String?
    let tags: [String]?  // WellSaid provides tags like "professional", "corporate"
    // Additional WellSaid-specific fields

    // Map to SwiftHablaré's Voice model
    func toVoice(providerId: String) -> Voice {
        Voice(
            id: id,
            name: name,
            description: description,
            providerId: providerId,
            language: language,
            locality: nil,
            gender: gender
        )
    }
}
```

#### 1.3 WellSaidSpeaker Model

**File**: Within `WellSaidVoiceProvider.swift`

**Requirements**:
- Enum representing available speaker models/avatars
- Similar to `ElevenLabsModel`
- Store in UserDefaults

```swift
public enum WellSaidSpeaker: String, CaseIterable, Identifiable {
    // To be populated based on WellSaid API documentation
    // Examples (adjust based on actual API):
    case standardVoice = "standard"
    case premiumVoice = "premium"
    case customVoice = "custom"

    public var id: String { rawValue }
    public var displayName: String { /* ... */ }
    public var description: String { /* ... */ }
    public static var `default`: WellSaidSpeaker { .standardVoice }
}
```

#### 1.4 Configuration View (SwiftUI)

**File**: Within `WellSaidVoiceProvider.swift`

**Requirements**:
- SwiftUI view for configuration
- API key input (SecureField)
- Speaker/model picker (similar to ElevenLabs)
- Save/Remove API key buttons
- Link to WellSaid documentation
- Error display

```swift
#if canImport(SwiftUI)
@MainActor
private struct WellSaidVoiceProviderConfigurationView: View {
    @State private var apiKey: String
    @State private var selectedSpeaker: WellSaidSpeaker
    @State private var isProcessing = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            // API Key section
            Section(header: Text("API Key")) { /* ... */ }

            // Speaker/Model selection
            Section(header: Text("Voice Model")) {
                Picker("Speaker", selection: $selectedSpeaker) { /* ... */ }
                Link("View WellSaid Documentation", destination: URL(...)!)
            }

            // Actions
            Section {
                Button("Save API Key") { /* ... */ }
                Button("Remove API Key", role: .destructive) { /* ... */ }
            }
        }
    }
}
#endif
```

### 2. Provider Registry Integration

**File**: `Sources/SwiftHablare/VoiceProviderRegistry.swift`

**Requirements**:
- Add WellSaid descriptor to automatic registration
- Ensure `isEnabledByDefault: false` (requires API key)

```swift
extension WellSaidVoiceProvider {
    public static var descriptor: VoiceProviderDescriptor {
        VoiceProviderDescriptor(
            id: "wellsaid",
            displayName: "WellSaid Labs",
            isEnabledByDefault: false,
            requiresConfiguration: true,
            makeProvider: { WellSaidVoiceProvider() }
        )
    }
}
```

### 3. Audio Processing Integration

**Requirements**:
- WellSaid audio output must be compatible with `AudioProcessor`
- Support silence trimming if applicable
- Convert to M4A format for consistency
- **Accurate duration measurement** using AudioProcessor (not estimates)

**Duration Measurement Strategy**:

WellSaid outputs MP3 audio. To get accurate duration (not character-based estimates):

```swift
// After receiving MP3 from WellSaid API
let processed = try await AudioProcessor.process(
    audioData: mp3Data,
    mimeType: "audio/mpeg"
)

// processed.durationSeconds contains ACTUAL duration from audio file
// More accurate than character-based estimates
```

**How AudioProcessor Handles MP3**:
1. Writes MP3 to temporary file
2. Loads into AVURLAsset (reads actual audio frames)
3. Measures real duration: `asset.load(.duration).seconds`
4. Trims silence from start/end
5. Converts to M4A for consistent output
6. Returns accurate duration + processed audio

**Benefits**:
- ✅ No MP3 duration estimation issues
- ✅ Works with variable bitrate (VBR) MP3
- ✅ Accurate duration regardless of encoding
- ✅ Same processing pipeline as ElevenLabs
- ✅ Automatic silence trimming
- ✅ Consistent M4A output format

### 4. Platform Support

**Requirements**:
- iOS 26.0+
- macOS 26.0+
- Full Swift 6 concurrency compliance
- Thread-safe operations using actors where appropriate

---

## Architecture & Methodology

### Design Patterns

#### 1. Engine Boundary Pattern

Follow the established **Engine Boundary Protocol** pattern:

```
┌─────────────────────────┐
│  WellSaidVoiceProvider  │
│  (Business Logic)       │
└───────────┬─────────────┘
            │
            │ Uses
            ▼
┌─────────────────────────┐
│    WellSaidEngine       │
│  (Platform Agnostic)    │
└───────────┬─────────────┘
            │
            │ HTTP Requests
            ▼
┌─────────────────────────┐
│    WellSaid Labs API    │
│    (External Service)   │
└─────────────────────────┘
```

**Benefits**:
- Clean separation of concerns
- Testable without network calls
- Consistent with Apple TTS and ElevenLabs implementations

#### 2. Configuration Management

- **API Keys**: Stored in Keychain via `KeychainManager.shared`
- **Model Selection**: Stored in UserDefaults (key: `"wellsaid-selected-speaker"`)
- **Ephemeral Keys**: Support for testing via initializer parameter

#### 3. Error Handling

Use existing `VoiceProviderError` enum:
- `.notConfigured` - API key missing or invalid
- `.invalidRequest(_)` - Invalid parameters (empty text, invalid voice ID)
- `.networkError(_)` - API communication failures
- `.audioGenerationFailed(_)` - TTS generation errors

#### 4. Concurrency

- All async operations use Swift's modern async/await
- Network calls via `URLSession.shared.data(for:)`
- Actor isolation where necessary
- Sendable conformance for configuration types

### Code Organization

```
Sources/SwiftHablare/
├── Providers/
│   ├── WellSaidVoiceProvider.swift      (220-250 lines)
│   │   ├── WellSaidSpeaker enum
│   │   ├── WellSaidVoiceProvider class
│   │   ├── Configuration view
│   │   └── Provider descriptor
│   └── WellSaid/
│       └── WellSaidEngine.swift         (180-220 lines)
│           ├── Configuration struct
│           ├── Engine implementation
│           └── API response types
```

---

## API Integration Details

### WellSaid Labs API Endpoints

**Base URL**: `https://api.wellsaidlabs.com/v1/` ✅ Verified

**Documentation**: https://docs.wellsaidlabs.com/reference/getting-started-with-your-api

**Implementation Approach**: Direct HTTP calls using URLSession (no external SDK)
- Same pattern as ElevenLabs implementation
- Zero external dependencies
- Full control over requests/responses

#### 1. Authentication

**Method**: API Key in header
**Header**: `X-Api-Key: <api-key>` ✅ Verified

Example:
```swift
var request = URLRequest(url: url)
request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
```

#### 2. List Avatars (Voices) Endpoint

**Endpoint**: `GET /avatars` ✅ Verified
**Query Parameters**: None required (returns all available avatars)

**Response Structure** (verify exact schema with API docs):
```json
{
  "avatars": [
    {
      "id": "avatar-id-123",
      "name": "Paige",
      "description": "Professional female voice",
      "language": "en-US",
      "gender": "female",
      "tags": ["professional", "corporate"]
    }
  ]
}
```

**Note**: WellSaid uses "avatars" terminology instead of "voices"

**Implementation**:
```swift
func fetchVoices(languageCode: String, configuration: WellSaidEngineConfiguration) async throws -> [Voice] {
    let urlString = "https://api.wellsaidlabs.com/v1/voices?language=\(languageCode)"
    guard let url = URL(string: urlString) else {
        throw VoiceProviderError.invalidRequest("Invalid URL")
    }

    var request = URLRequest(url: url)
    request.setValue(configuration.apiKey, forHTTPHeaderField: "X-API-Key")
    request.setValue(configuration.userAgent, forHTTPHeaderField: "User-Agent")

    let (data, response) = try await URLSession.shared.data(for: request)
    // Parse and return voices
}
```

#### 3. Text-to-Speech Endpoint

**Endpoint Options**:
- `POST /tts/stream` - Real-time streaming TTS ✅ Verified
- `POST /tts` - Asynchronous TTS generation ✅ Verified

**Recommended**: Use `/tts/stream` for immediate response

**Content-Type**: `application/json`
**Accept**: `audio/mpeg` (for MP3 output)

**Request Body** (verify exact schema with API docs):
```json
{
  "text": "Text to synthesize",
  "speaker_id": "avatar-id-123"
}
```

**Response**: Binary audio data (MP3 format, `audio/mpeg`)

**Implementation**:
```swift
func generateAudio(request: VoiceEngineRequest, configuration: WellSaidEngineConfiguration) async throws -> VoiceEngineOutput {
    // Use streaming endpoint for immediate response
    let url = URL(string: "https://api.wellsaidlabs.com/v1/tts/stream")!
    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = "POST"
    urlRequest.setValue(configuration.apiKey, forHTTPHeaderField: "X-Api-Key")
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    urlRequest.setValue("audio/mpeg", forHTTPHeaderField: "Accept")
    urlRequest.setValue(configuration.userAgent, forHTTPHeaderField: "User-Agent")

    let body: [String: Any] = [
        "text": request.text,
        "speaker_id": request.voiceId  // WellSaid uses "speaker_id" for avatar selection
    ]

    urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

    let (data, response) = try await URLSession.shared.data(for: urlRequest)

    // Return MP3 audio data
    return VoiceEngineOutput(
        audioData: data,
        audioFormat: .mp3,
        fileExtension: "mp3",
        mimeType: "audio/mpeg",
        metadata: [
            "engineId": engineId,
            "voiceId": request.voiceId,
            "languageCode": request.languageCode
        ]
    )
}
```

#### 4. Avatar (Voice) Availability Check

**Endpoint**: `GET /avatars/{avatar_id}` ✅ Verified

**Response**: Avatar details or 404

**Implementation**:
```swift
func isVoiceAvailable(voiceId: String, configuration: WellSaidEngineConfiguration) async -> Bool {
    let url = URL(string: "https://api.wellsaidlabs.com/v1/avatars/\(voiceId)")!
    var request = URLRequest(url: url)
    request.setValue(configuration.apiKey, forHTTPHeaderField: "X-Api-Key")
    request.setValue(configuration.userAgent, forHTTPHeaderField: "User-Agent")

    do {
        let (_, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse {
            return (200...299).contains(httpResponse.statusCode)
        }
        return false
    } catch {
        return false
    }
}
```

### Error Handling

**HTTP Status Codes**:
- `200-299`: Success
- `400`: Bad Request (invalid parameters)
- `401`: Unauthorized (invalid API key)
- `403`: Forbidden (insufficient permissions)
- `404`: Not Found (invalid voice ID)
- `429`: Rate Limited
- `500+`: Server Error

**Error Response Format** (assumed):
```json
{
  "error": {
    "code": "invalid_voice",
    "message": "Voice ID not found"
  }
}
```

**Implementation**:
```swift
guard (200...299).contains(httpResponse.statusCode) else {
    var errorMessage = "HTTP \(httpResponse.statusCode)"
    if let errorJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
       let error = errorJSON["error"] as? [String: Any],
       let message = error["message"] as? String {
        errorMessage += ": \(message)"
    }
    throw VoiceProviderError.networkError(errorMessage)
}
```

### Rate Limiting

**WellSaid API Limits** ✅ Verified:
- **Default API Key**: 3 requests per second
- **Character Limit**: 1000 characters per request
- **Monthly Quota**: Varies by plan

**Implementation Strategy**:
- Respect API rate limits (3 req/sec default)
- Split long text into chunks (max 1000 characters)
- Implement exponential backoff for 429 responses
- Cache avatar (voice) lists to minimize API calls
- Use language-specific caching (same as ElevenLabs pattern)

---

## Implementation Phases

### Phase 1: Core Engine Implementation (Week 1)

**Tasks**:
1. Create `WellSaidEngine.swift` with VoiceEngine conformance
2. Implement configuration struct
3. Implement `fetchVoices()` with API integration
4. Implement `generateAudio()` with API integration
5. Implement `estimateDuration()` calculation (character-based)
6. Add AudioProcessor integration for accurate duration (from actual MP3)
7. Implement `isVoiceAvailable()` check
8. Add API response type structs
9. Add comprehensive error handling

**Deliverables**:
- [ ] `WellSaidEngine.swift` complete
- [ ] All VoiceEngine methods implemented
- [ ] Error handling in place
- [ ] Code compiles without errors

**Testing**: Unit tests with mocked network responses

### Phase 2: Voice Provider Implementation (Week 1)

**Tasks**:
1. Create `WellSaidVoiceProvider.swift`
2. Implement VoiceProvider protocol
3. Add API key management methods
4. Add speaker/model selection methods
5. Integrate with WellSaidEngine
6. Add UserDefaults storage for model selection
7. Implement provider descriptor

**Deliverables**:
- [ ] `WellSaidVoiceProvider.swift` complete
- [ ] All VoiceProvider methods implemented
- [ ] API key management functional
- [ ] Model selection functional

**Testing**: Unit tests with mock engine

### Phase 3: UI Configuration View (Week 1-2)

**Tasks**:
1. Create SwiftUI configuration view
2. Implement API key input field
3. Add speaker/model picker
4. Add documentation link
5. Implement save/remove functionality
6. Add loading states and error messages
7. Test on both iOS and macOS

**Deliverables**:
- [ ] Configuration view complete
- [ ] All UI elements functional
- [ ] Works on iOS and macOS
- [ ] Error states handled

**Testing**: Manual UI testing on both platforms

### Phase 4: Provider Registry Integration (Week 2)

**Tasks**:
1. Add WellSaid descriptor to registry
2. Update auto-registration
3. Test provider discovery
4. Verify enablement state management

**Deliverables**:
- [ ] Registry integration complete
- [ ] Provider discoverable
- [ ] Configuration UI accessible

**Testing**: Integration tests with GenerationService

### Phase 5: Testing & Quality Assurance (Week 2)

**Tasks**:
1. Write comprehensive unit tests
2. Write integration tests (with real API)
3. Add to performance benchmarks
4. Test voice caching behavior
5. Test error scenarios
6. Test on iOS simulator and device
7. Test on macOS
8. Code coverage analysis

**Deliverables**:
- [ ] 95%+ test coverage
- [ ] All tests passing
- [ ] Integration tests functional
- [ ] Performance benchmarks added

**Testing**: Full test suite execution

### Phase 6: Documentation & Release (Week 2-3)

**Tasks**:
1. Update README.md with WellSaid info
2. Update CLAUDE.md with WellSaid patterns
3. Add API documentation comments
4. Create example usage in Examples/
5. Update CHANGELOG.md
6. Version bump (v5.3.0)
7. Create PR and merge

**Deliverables**:
- [ ] Documentation complete
- [ ] Examples added
- [ ] CHANGELOG updated
- [ ] Version bumped
- [ ] PR merged

---

## Testing Strategy

### 1. Unit Tests

**File**: `Tests/SwiftHablareTests/WellSaidVoiceProviderTests.swift`

**Coverage** (30-40 test functions):

#### Provider Tests
```swift
@Suite("WellSaid Voice Provider Tests")
@MainActor
struct WellSaidVoiceProviderTests {

    // Initialization Tests
    @Test("Provider initializes with default values")
    func initializesWithDefaults()

    @Test("Provider initializes with ephemeral API key")
    func initializesWithEphemeralKey()

    // Configuration Tests
    @Test("isConfigured returns false without API key")
    func notConfiguredWithoutKey()

    @Test("isConfigured returns true with valid API key")
    func configuredWithValidKey()

    // API Key Management Tests
    @Test("Save API key to keychain")
    func saveAPIKey() throws

    @Test("Retrieve API key from keychain")
    func retrieveAPIKey() throws

    @Test("Clear API key from keychain")
    func clearAPIKey() throws

    @Test("Ephemeral key not saved to keychain")
    func ephemeralKeyNotSaved()

    // Speaker/Model Selection Tests
    @Test("Get default speaker")
    func getDefaultSpeaker()

    @Test("Update selected speaker")
    func updateSelectedSpeaker()

    @Test("Selected speaker persists")
    func speakerPersists()

    // Voice Fetching Tests
    @Test("Fetch voices with valid API key")
    func fetchVoicesSuccess() async throws

    @Test("Fetch voices throws without API key")
    func fetchVoicesNoKey() async throws

    @Test("Fetch voices filters by language")
    func fetchVoicesLanguageFilter() async throws

    // Audio Generation Tests
    @Test("Generate audio with valid parameters")
    func generateAudioSuccess() async throws

    @Test("Generate audio throws with empty text")
    func generateAudioEmptyText() async throws

    @Test("Generate audio throws with invalid voice ID")
    func generateAudioInvalidVoice() async throws

    @Test("Generate audio uses selected speaker")
    func generateAudioUsesSelectedSpeaker() async throws

    // Duration Estimation Tests
    @Test("Estimate duration for short text")
    func estimateDurationShort() async

    @Test("Estimate duration for long text")
    func estimateDurationLong() async

    @Test("Duration estimation is reasonable")
    func durationEstimationReasonable() async

    // Voice Availability Tests
    @Test("Check valid voice availability")
    func checkValidVoiceAvailable() async

    @Test("Check invalid voice availability")
    func checkInvalidVoiceAvailable() async

    // Error Handling Tests
    @Test("Handle network errors gracefully")
    func handleNetworkError() async throws

    @Test("Handle invalid API key errors")
    func handleInvalidAPIKey() async throws

    @Test("Handle rate limiting")
    func handleRateLimiting() async throws
}
```

#### Engine Tests

**File**: `Tests/SwiftHablareTests/WellSaidEngineTests.swift`

```swift
@Suite("WellSaid Engine Tests")
struct WellSaidEngineTests {

    @Test("Engine ID is correct")
    func engineId()

    @Test("canGenerate with valid configuration")
    func canGenerateValid()

    @Test("canGenerate with empty API key")
    func canGenerateEmpty()

    @Test("fetchVoices returns Voice models")
    func fetchVoicesReturnsModels() async throws

    @Test("generateAudio returns valid output")
    func generateAudioReturnsOutput() async throws

    @Test("estimateDuration calculation")
    func estimateDurationCalculation()

    @Test("isVoiceAvailable with valid ID")
    func isVoiceAvailableValid() async

    @Test("isVoiceAvailable with invalid ID")
    func isVoiceAvailableInvalid() async
}
```

#### Model Tests

**File**: `Tests/SwiftHablareTests/WellSaidModelTests.swift`

```swift
@Suite("WellSaid Speaker Model Tests")
struct WellSaidSpeakerTests {

    @Test("All speakers have unique IDs")
    func uniqueIds()

    @Test("All speakers have display names")
    func displayNames()

    @Test("All speakers have descriptions")
    func descriptions()

    @Test("Default speaker is defined")
    func defaultSpeaker()

    @Test("Speaker enum is Identifiable")
    func identifiableConformance()

    @Test("Speaker enum is CaseIterable")
    func caseIterableConformance()
}
```

### 2. Integration Tests

**File**: `Tests/SwiftHablareTests/Integration/WellSaidIntegrationTests.swift`

**Requirements**:
- Real API calls (requires valid API key)
- Skipped on CI (run weekly on schedule)
- Test actual audio generation
- Verify audio format and quality

```swift
@Suite("WellSaid Integration Tests")
@MainActor
struct WellSaidIntegrationTests {

    @Test("Fetch real voices from WellSaid API")
    func fetchRealVoices() async throws {
        #if INTEGRATION_TESTS_ENABLED
        let provider = WellSaidVoiceProvider(apiKey: ProcessInfo.processInfo.environment["WELLSAID_API_KEY"])
        let voices = try await provider.fetchVoices()
        #expect(voices.count > 0)
        #endif
    }

    @Test("Generate real audio with WellSaid API")
    func generateRealAudio() async throws {
        #if INTEGRATION_TESTS_ENABLED
        let provider = WellSaidVoiceProvider(apiKey: ProcessInfo.processInfo.environment["WELLSAID_API_KEY"])
        let voices = try await provider.fetchVoices()
        let voiceId = voices.first?.id ?? ""

        let audioData = try await provider.generateAudio(
            text: "This is a test of WellSaid Labs integration.",
            voiceId: voiceId
        )

        #expect(audioData.count > 0)
        #endif
    }

    @Test("Voice caching with WellSaid provider")
    func voiceCaching() async throws {
        // Test voice cache behavior
    }

    @Test("Audio processing with WellSaid output")
    func audioProcessing() async throws {
        // Test AudioProcessor integration
    }
}
```

### 3. User Agent Tests

**File**: `Tests/SwiftHablareTests/WellSaidUserAgentTests.swift`

```swift
@Suite("WellSaid User-Agent Tests")
struct WellSaidUserAgentTests {

    @Test("User-Agent includes SwiftHablare name")
    func userAgentIncludesName()

    @Test("User-Agent includes version")
    func userAgentIncludesVersion()

    @Test("User-Agent format is correct")
    func userAgentFormat()
}
```

### 4. UI Tests

**Manual Testing Checklist**:
- [ ] Configuration view displays correctly on iOS
- [ ] Configuration view displays correctly on macOS
- [ ] API key field accepts input
- [ ] API key is masked (SecureField)
- [ ] Speaker picker shows all options
- [ ] Speaker picker selection updates UserDefaults
- [ ] Documentation link opens browser
- [ ] Save button enables when key entered
- [ ] Save button shows loading state
- [ ] Error messages display correctly
- [ ] Remove button clears API key
- [ ] Remove button disabled when no key exists

### 5. Performance Tests

**File**: Add to `Tests/SwiftHablareTests/Integration/PerformanceIntegrationTests.swift`

```swift
@Test("WellSaid voice fetch performance")
func wellSaidVoiceFetchPerformance() async throws {
    let provider = TestFixtures.makeWellSaidProvider()

    let start = Date()
    _ = try await provider.fetchVoices()
    let duration = Date().timeIntervalSince(start)

    #expect(duration < 5.0)  // Should fetch in under 5 seconds
}

@Test("WellSaid audio generation performance")
func wellSaidAudioGenerationPerformance() async throws {
    let provider = TestFixtures.makeWellSaidProvider()
    let voices = try await provider.fetchVoices()
    let voiceId = voices.first?.id ?? ""

    let start = Date()
    _ = try await provider.generateAudio(text: "Test", voiceId: voiceId)
    let duration = Date().timeIntervalSince(start)

    #expect(duration < 10.0)  // Should generate in under 10 seconds
}
```

### 6. Test Coverage Goals

- **Unit Tests**: 95%+ coverage
- **Integration Tests**: 5+ scenarios
- **Performance Tests**: 2+ benchmarks
- **Total Test Count**: ~40-50 new tests

### 7. CI/CD Integration

**Fast Tests** (Run on every PR):
- All unit tests (without real API calls)
- Mock-based tests
- Platform: iOS Simulator + macOS

**Integration Tests** (Run weekly):
- Real API calls with test API key
- Stored in GitHub Secrets: `WELLSAID_API_KEY`
- Platform: macOS only

---

## Acceptance Criteria

### Functional Requirements

- [ ] **FR-1**: WellSaid provider appears in provider list
- [ ] **FR-2**: Configuration UI accessible and functional
- [ ] **FR-3**: API key saved securely to Keychain
- [ ] **FR-4**: Speaker/model selection persists across app restarts
- [ ] **FR-5**: Voice list fetches successfully with valid API key
- [ ] **FR-6**: Voice list filtered by language code
- [ ] **FR-7**: Audio generation successful with valid parameters
- [ ] **FR-8**: Generated audio playable and correct format
- [ ] **FR-9**: Duration estimation within 20% of actual
- [ ] **FR-10**: Voice availability check functional
- [ ] **FR-11**: Error messages clear and actionable
- [ ] **FR-12**: Documentation link opens correct URL

### Non-Functional Requirements

- [ ] **NFR-1**: 95%+ test coverage on new code
- [ ] **NFR-2**: All existing tests pass (289 tests)
- [ ] **NFR-3**: No performance regression vs ElevenLabs
- [ ] **NFR-4**: Swift 6 concurrency compliance
- [ ] **NFR-5**: iOS 26.0+ and macOS 26.0+ support
- [ ] **NFR-6**: Code follows existing style guidelines
- [ ] **NFR-7**: No compiler warnings
- [ ] **NFR-8**: Memory usage acceptable (<10MB overhead)
- [ ] **NFR-9**: Network efficiency (caching, retries)
- [ ] **NFR-10**: Accessibility support in UI (VoiceOver, keyboard navigation)

### Code Quality

- [ ] **CQ-1**: Code reviewed and approved
- [ ] **CQ-2**: Documentation comments on public APIs
- [ ] **CQ-3**: CHANGELOG.md updated
- [ ] **CQ-4**: README.md updated with WellSaid info
- [ ] **CQ-5**: Example code added to Examples/
- [ ] **CQ-6**: No TODO comments in production code
- [ ] **CQ-7**: Error handling comprehensive
- [ ] **CQ-8**: Thread safety verified

### Integration

- [ ] **INT-1**: Works with GenerationService
- [ ] **INT-2**: Works with voice caching system
- [ ] **INT-3**: Works with AudioProcessor
- [ ] **INT-4**: Works with provider registry
- [ ] **INT-5**: Works with SpeakableItem protocol
- [ ] **INT-6**: Works with SpeakableGroup protocol
- [ ] **INT-7**: Compatible with TypedDataStorage

### Platform Compatibility

- [ ] **PC-1**: Builds on iOS 26.0+
- [ ] **PC-2**: Builds on macOS 26.0+
- [ ] **PC-3**: Tests pass on iOS Simulator
- [ ] **PC-4**: Tests pass on iOS Device
- [ ] **PC-5**: Tests pass on macOS (Intel)
- [ ] **PC-6**: Tests pass on macOS (Apple Silicon)

---

## References

### WellSaid Labs Documentation

- **API Documentation**: https://wellsaidlabs.com/docs/api
- **Getting Started**: https://wellsaidlabs.com/docs/getting-started
- **Authentication**: https://wellsaidlabs.com/docs/authentication
- **Voices**: https://wellsaidlabs.com/docs/voices
- **Text-to-Speech**: https://wellsaidlabs.com/docs/text-to-speech
- **Rate Limits**: https://wellsaidlabs.com/docs/rate-limits

### SwiftHablaré Documentation

- **VoiceProvider Protocol**: `Sources/SwiftHablare/VoiceProvider.swift`
- **VoiceEngine Protocol**: `Sources/SwiftHablare/Protocols/VoiceEngine.swift`
- **Engine Boundary Pattern**: `Docs/EngineBoundaryProtocol.md`
- **ElevenLabs Reference**: `Sources/SwiftHablare/Providers/ElevenLabsVoiceProvider.swift`
- **Testing Guide**: `Tests/README.md`
- **Development Workflow**: `.claude/WORKFLOW.md`

### External Resources

- **Swift Testing**: https://developer.apple.com/documentation/testing
- **Swift Concurrency**: https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html
- **Keychain Services**: https://developer.apple.com/documentation/security/keychain_services
- **UserDefaults**: https://developer.apple.com/documentation/foundation/userdefaults

---

## Appendix

### A. Code Metrics

**Estimated Lines of Code**:
- WellSaidVoiceProvider.swift: ~220-250 lines
- WellSaidEngine.swift: ~180-220 lines
- WellSaidVoiceProviderTests.swift: ~400-500 lines
- WellSaidEngineTests.swift: ~200-300 lines
- WellSaidIntegrationTests.swift: ~150-200 lines
- **Total**: ~1,150-1,470 new lines

**Complexity**:
- Similar to ElevenLabs implementation
- Moderate complexity due to async networking
- Well-defined patterns to follow

### B. Risk Assessment

**High Risk**:
- API documentation incomplete or inaccurate
- API changes during development
- Authentication method differs from expectations

**Mitigation**:
- Early API testing with minimal implementation
- Regular API documentation review
- Flexible architecture to accommodate changes

**Medium Risk**:
- Audio format incompatibility with AudioProcessor
- Rate limiting stricter than expected
- Performance issues with large text

**Mitigation**:
- Test audio processing early
- Implement retry logic and backoff
- Add text length validation

**Low Risk**:
- Test failures due to existing code changes
- UI layout issues on different platforms
- Integration complexity

**Mitigation**:
- Comprehensive testing strategy
- Platform-specific testing
- Follow established patterns

### C. Timeline

**Week 1**:
- Days 1-2: Engine implementation
- Days 3-4: Provider implementation
- Day 5: UI configuration view

**Week 2**:
- Days 1-2: Testing (unit + integration)
- Day 3: Registry integration
- Days 4-5: QA and bug fixes

**Week 3**:
- Days 1-2: Documentation
- Day 3: Final testing and review
- Days 4-5: PR and release

**Total**: ~15 working days (3 weeks)

### D. Success Metrics

**Quantitative**:
- 95%+ test coverage
- <5% performance regression
- Zero production bugs in first month
- <2 hour additional CI runtime

**Qualitative**:
- Positive user feedback
- Easy to maintain and extend
- Clear documentation
- Consistent with existing patterns

---

**Document Version**: 1.0
**Last Updated**: 2025-12-09
**Next Review**: Upon API documentation review
**Owner**: Development Team
