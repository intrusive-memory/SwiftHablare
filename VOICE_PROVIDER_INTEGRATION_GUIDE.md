# Voice Provider Integration Guide

Welcome to the SwiftHablare Voice Provider Integration Guide. This document will walk you through creating and integrating a new voice provider into the SwiftHablare framework.

## 🚀 New: True Extensibility

**As of v2.0**, SwiftHablare supports **completely independent voice provider packages** that can be created and registered without modifying the library code. You can now:

✅ Create voice providers in separate Swift packages
✅ Register providers dynamically at runtime
✅ No need to modify the SwiftHablare library source code
✅ UI automatically discovers and displays all registered providers

This means you can distribute your custom voice provider as a separate package and integrate it seamlessly!

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Quick Start: Creating a New Provider](#quick-start-creating-a-new-provider)
3. [Step-by-Step Implementation](#step-by-step-implementation)
4. [Registration and Integration](#registration-and-integration)
5. [Testing Your Provider](#testing-your-provider)
6. [Advanced Topics](#advanced-topics)
7. [Common Patterns and Best Practices](#common-patterns-and-best-practices)
8. [Troubleshooting](#troubleshooting)
9. [Creating an External Provider Package](#creating-an-external-provider-package)

---

## Architecture Overview

SwiftHablare uses a protocol-oriented architecture with **dynamic provider registration**. The system consists of:

- **`VoiceProvider` Protocol**: The core interface all providers must implement
- **`VoiceProviderManager`**: Manages provider lifecycle, registration, switching, and caching
- **`VoiceProviderInfo`**: Struct containing provider metadata for dynamic discovery
- **Supporting Models**: `Voice`, `AudioFile` for data persistence

### Key Architectural Features

- **Dynamic Registration**: Providers register themselves at runtime using `manager.registerProvider()`
- **String-Based Identification**: Providers identified by `providerId` string (not enum)
- **Automatic UI Integration**: UI components automatically discover and display registered providers
- **Backward Compatible**: Legacy enum-based API still works (deprecated)

### Provider Responsibilities

Each provider must:
1. Fetch available voices from its source (API or system)
2. Generate audio data from text using a specified voice
3. Estimate audio duration
4. Handle its own configuration and authentication
5. Report availability status
6. Provide unique `providerId` and `displayName`

---

## Quick Start: Creating a New Provider

Here's a minimal example of a new voice provider:

```swift
import Foundation

public final class MyCustomVoiceProvider: VoiceProvider {
    // MARK: - VoiceProvider Protocol Requirements

    public let providerId = "mycustom"
    public let displayName = "My Custom TTS"
    public let requiresAPIKey = true

    private let keychainManager = KeychainManager.shared
    private let apiKeyAccount = "mycustom-api-key"

    public init() {}

    public func isConfigured() -> Bool {
        do {
            _ = try keychainManager.getAPIKey(for: apiKeyAccount)
            return true
        } catch {
            return false
        }
    }

    public func fetchVoices() async throws -> [Voice] {
        guard isConfigured() else {
            throw VoiceProviderError.notConfigured
        }

        // Fetch voices from your API
        let voices = try await fetchVoicesFromAPI()
        return voices.map { apiVoice in
            Voice(
                id: apiVoice.id,
                name: apiVoice.name,
                description: apiVoice.description,
                providerId: providerId,
                language: apiVoice.language,
                locality: apiVoice.locality,
                gender: apiVoice.gender
            )
        }
    }

    public func generateAudio(text: String, voiceId: String) async throws -> Data {
        guard isConfigured() else {
            throw VoiceProviderError.notConfigured
        }

        // Generate audio from your API
        let audioData = try await generateAudioFromAPI(text: text, voiceId: voiceId)
        return audioData
    }

    public func estimateDuration(text: String, voiceId: String) async -> TimeInterval {
        // Estimate based on characters per second
        let charactersPerSecond = 13.0
        let baseEstimate = Double(text.count) / charactersPerSecond
        return baseEstimate * 1.15 // Add 15% buffer
    }

    public func isVoiceAvailable(voiceId: String) async -> Bool {
        do {
            let voices = try await fetchVoices()
            return voices.contains { $0.id == voiceId }
        } catch {
            return false
        }
    }

    // MARK: - Private API Methods

    private func fetchVoicesFromAPI() async throws -> [APIVoice] {
        // Implement your API call here
        fatalError("Implement API call")
    }

    private func generateAudioFromAPI(text: String, voiceId: String) async throws -> Data {
        // Implement your API call here
        fatalError("Implement API call")
    }
}

// Helper struct for API responses
private struct APIVoice: Codable {
    let id: String
    let name: String
    let description: String?
    let language: String?
    let locality: String?
    let gender: String?
}
```

---

## Step-by-Step Implementation

### Step 1: Create Your Provider Package (Optional)

You can create your provider as a separate Swift package for maximum reusability:

```bash
mkdir MyCustomVoiceProvider
cd MyCustomVoiceProvider
swift package init --type library --name MyCustomVoiceProvider
```

**Package.swift:**
```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MyCustomVoiceProvider",
    platforms: [.iOS(.v26), .macCatalyst(.v15)],
    products: [
        .library(
            name: "MyCustomVoiceProvider",
            targets: ["MyCustomVoiceProvider"]),
    ],
    dependencies: [
        .package(url: "https://github.com/intrusive-memory/SwiftHablare.git", from: "2.0.0")
    ],
    targets: [
        .target(
            name: "MyCustomVoiceProvider",
            dependencies: ["SwiftHablare"]),
        .testTarget(
            name: "MyCustomVoiceProviderTests",
            dependencies: ["MyCustomVoiceProvider"]),
    ]
)
```

Or, if you prefer, create your provider directly in your app.

### Step 2: Create Your Provider Class

Create your provider class (either in your package or your app):

**File:** `Sources/SwiftHablare/Providers/MyCustomVoiceProvider.swift`

```swift
import Foundation

public final class MyCustomVoiceProvider: VoiceProvider {
    // MARK: - Constants

    private let baseURL = "https://api.mycustom.com/v1"
    private let keychainManager = KeychainManager.shared
    private let apiKeyAccount = "mycustom-api-key"

    // MARK: - VoiceProvider Protocol Properties

    public let providerId = "mycustom"
    public let displayName = "My Custom TTS"
    public let requiresAPIKey = true

    // MARK: - Initialization

    public init() {}

    // MARK: - Configuration

    public func isConfigured() -> Bool {
        // For API-based providers with authentication
        do {
            _ = try keychainManager.getAPIKey(for: apiKeyAccount)
            return true
        } catch {
            return false
        }

        // For system-based providers (like Apple)
        // return true
    }

    // MARK: - Voice Fetching

    public func fetchVoices() async throws -> [Voice] {
        guard isConfigured() else {
            throw VoiceProviderError.notConfigured
        }

        // Build request
        guard let url = URL(string: "\(baseURL)/voices") else {
            throw VoiceProviderError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        // Add authentication
        if let apiKey = try? keychainManager.getAPIKey(for: apiKeyAccount) {
            request.addValue(apiKey, forHTTPHeaderField: "Authorization")
        }

        // Make request
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw VoiceProviderError.networkError("Failed to fetch voices")
        }

        // Parse response
        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(VoicesAPIResponse.self, from: data)

        // Convert to Voice models
        return apiResponse.voices.map { apiVoice in
            Voice(
                id: apiVoice.id,
                name: apiVoice.name,
                description: apiVoice.description,
                providerId: providerId,
                language: apiVoice.language,
                locality: apiVoice.locality,
                gender: apiVoice.gender
            )
        }
    }

    // MARK: - Audio Generation

    public func generateAudio(text: String, voiceId: String) async throws -> Data {
        guard isConfigured() else {
            throw VoiceProviderError.notConfigured
        }

        // Build request
        guard let url = URL(string: "\(baseURL)/generate") else {
            throw VoiceProviderError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add authentication
        if let apiKey = try? keychainManager.getAPIKey(for: apiKeyAccount) {
            request.addValue(apiKey, forHTTPHeaderField: "Authorization")
        }

        // Build request body
        let requestBody = GenerateRequest(
            text: text,
            voiceId: voiceId,
            settings: AudioSettings()
        )

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(requestBody)

        // Make request
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw VoiceProviderError.networkError("Failed to generate audio")
        }

        return data
    }

    // MARK: - Duration Estimation

    public func estimateDuration(text: String, voiceId: String) async -> TimeInterval {
        // Common estimation: ~13-15 characters per second
        let charactersPerSecond = 13.0
        let baseEstimate = Double(text.count) / charactersPerSecond

        // Add buffer for natural speech rhythm (10-15%)
        let bufferMultiplier = 1.15

        return baseEstimate * bufferMultiplier
    }

    // MARK: - Voice Availability

    public func isVoiceAvailable(voiceId: String) async -> Bool {
        do {
            let voices = try await fetchVoices()
            return voices.contains { $0.id == voiceId }
        } catch {
            return false
        }
    }
}

// MARK: - API Models

private struct VoicesAPIResponse: Codable {
    let voices: [APIVoice]
}

private struct APIVoice: Codable {
    let id: String
    let name: String
    let description: String?
    let language: String?
    let locality: String?
    let gender: String?
}

private struct GenerateRequest: Codable {
    let text: String
    let voiceId: String
    let settings: AudioSettings
}

private struct AudioSettings: Codable {
    let format: String = "mp3"
    let sampleRate: Int = 44100
}
```

### Step 3: Handle Authentication (If Required)

If your provider requires an API key or credentials:

```swift
// Users can configure the API key like this:
let keychain = KeychainManager.shared
try keychain.saveAPIKey("your-api-key-here", for: "mycustom-api-key")

// In your provider:
public func isConfigured() -> Bool {
    do {
        _ = try keychainManager.getAPIKey(for: apiKeyAccount)
        return true
    } catch {
        return false
    }
}

// Retrieve the key when making API calls:
if let apiKey = try? keychainManager.getAPIKey(for: apiKeyAccount) {
    request.addValue(apiKey, forHTTPHeaderField: "Authorization")
    // or
    request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
}
```

For providers without authentication (like Apple's system TTS):

```swift
public let requiresAPIKey = false

public func isConfigured() -> Bool {
    return true  // Always configured
}
```

---

## Registration and Integration

### Step 4: Register Your Provider Dynamically

**NEW APPROACH**: You no longer need to modify the SwiftHablare library! Simply register your provider at runtime:

```swift
import SwiftHablare
import MyCustomVoiceProvider  // Your separate package

// Initialize the manager (built-in providers auto-register)
let manager = VoiceProviderManager(modelContext: modelContext)

// Register your custom provider dynamically
manager.registerProvider(MyCustomVoiceProvider())

// That's it! Your provider is now available
```

#### Advanced: Skip Default Providers

If you want to provide your own set of providers without the defaults:

```swift
// Initialize without auto-registering defaults
let manager = VoiceProviderManager(modelContext: modelContext, registerDefaults: false)

// Register only your providers
manager.registerProvider(MyCustomVoiceProvider())
manager.registerProvider(AnotherCustomProvider())
```

#### Check Provider Registration

```swift
// Check if a provider is registered
if manager.isProviderRegistered("mycustom") {
    print("Provider is registered!")
}

// Get all registered provider IDs
let providerIds = manager.getRegisteredProviderIds()
print("Available providers: \(providerIds)")

// Get detailed provider information
let providers = manager.getRegisteredProviders()
for info in providers {
    print("\(info.displayName) [\(info.id)] - Configured: \(info.isConfigured)")
}
```

### Step 5: Use Your Provider

```swift
// Switch to your provider using its ID
manager.switchProvider(to: "mycustom")

// Or use the returned boolean to check success
if manager.switchProvider(to: "mycustom") {
    print("Successfully switched to custom provider")
} else {
    print("Provider 'mycustom' not found")
}

// Check configuration
if manager.isCurrentProviderConfigured() {
    // Fetch voices
    let voices = try await manager.getVoices()

    // Generate audio
    let audioData = try await manager.generateAudio(
        text: "Hello, world!",
        voiceId: voices.first!.id
    )
} else {
    print("Provider not configured. Please set API key.")
}
```

### UI Integration

The best part? **No UI code changes needed!** The UI components automatically discover and display all registered providers:

```swift
// VoiceProviderWidget automatically shows all registered providers
VoiceProviderWidget(providerManager: manager)

// ProviderSelectionView also works automatically
ProviderSelectionView(providerManager: manager)
```

Your custom provider will appear in the UI with:
- Its display name
- Configuration status (configured/not configured)
- A default icon (or custom if you match the provider ID)

### Legacy Approach (Deprecated)

The old approach of modifying the `VoiceProviderType` enum still works but is deprecated:

```swift
// Old way (deprecated) - DO NOT USE
enum VoiceProviderType {
    case elevenlabs
    case apple
    case mycustom  // Had to modify library code
}
```

**Use the dynamic registration approach instead!**

---

## Testing Your Provider

### Step 6: Create Unit Tests

Create a test file in `Tests/SwiftHablareTests/Providers/`:

**File:** `Tests/SwiftHablareTests/Providers/MyCustomVoiceProviderTests.swift`

```swift
import XCTest
@testable import SwiftHablare

final class MyCustomVoiceProviderTests: XCTestCase {
    var provider: MyCustomVoiceProvider!

    override func setUp() async throws {
        provider = MyCustomVoiceProvider()
    }

    override func tearDown() async throws {
        provider = nil
        // Clean up any test API keys
        try? KeychainManager.shared.deleteAPIKey(for: "mycustom-api-key")
    }

    func testProviderIdentification() {
        XCTAssertEqual(provider.providerId, "mycustom")
        XCTAssertEqual(provider.displayName, "My Custom TTS")
        XCTAssertTrue(provider.requiresAPIKey)
    }

    func testConfigurationWithoutAPIKey() {
        XCTAssertFalse(provider.isConfigured())
    }

    func testConfigurationWithAPIKey() throws {
        try KeychainManager.shared.saveAPIKey("test-key", for: "mycustom-api-key")
        XCTAssertTrue(provider.isConfigured())
    }

    func testFetchVoicesThrowsWhenNotConfigured() async {
        do {
            _ = try await provider.fetchVoices()
            XCTFail("Should throw notConfigured error")
        } catch VoiceProviderError.notConfigured {
            // Expected
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func testGenerateAudioThrowsWhenNotConfigured() async {
        do {
            _ = try await provider.generateAudio(text: "Test", voiceId: "voice-1")
            XCTFail("Should throw notConfigured error")
        } catch VoiceProviderError.notConfigured {
            // Expected
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func testEstimateDuration() async {
        let text = "This is a test sentence with about fifty characters"
        let duration = await provider.estimateDuration(text: text, voiceId: "any")

        // Expect roughly 4-5 seconds for 50 characters
        XCTAssertGreaterThan(duration, 3.0)
        XCTAssertLessThan(duration, 6.0)
    }

    // Integration tests (require real API key)
    func testFetchVoicesWithRealAPI() async throws {
        // Skip if no API key configured
        guard provider.isConfigured() else {
            throw XCTSkip("API key not configured")
        }

        let voices = try await provider.fetchVoices()
        XCTAssertFalse(voices.isEmpty)

        // Verify voice structure
        let voice = voices.first!
        XCTAssertFalse(voice.id.isEmpty)
        XCTAssertFalse(voice.name.isEmpty)
        XCTAssertEqual(voice.providerId, "mycustom")
    }

    func testGenerateAudioWithRealAPI() async throws {
        // Skip if no API key configured
        guard provider.isConfigured() else {
            throw XCTSkip("API key not configured")
        }

        let voices = try await provider.fetchVoices()
        let voiceId = voices.first!.id

        let audioData = try await provider.generateAudio(
            text: "Test audio",
            voiceId: voiceId
        )

        XCTAssertFalse(audioData.isEmpty)
    }
}
```

### Running Tests

```bash
# Run all tests
swift test

# Run specific provider tests
swift test --filter MyCustomVoiceProviderTests

# Run with coverage
swift test --enable-code-coverage
```

---

## Advanced Topics

### Multi-Language Support

If your provider supports multiple languages, include language filtering:

```swift
public func fetchVoices(language: String? = nil) async throws -> [Voice] {
    var allVoices = try await fetchVoicesFromAPI()

    if let language = language {
        allVoices = allVoices.filter { $0.language == language }
    }

    return allVoices.map { /* convert to Voice */ }
}
```

### Streaming Audio

For real-time audio streaming:

```swift
public func generateAudioStream(
    text: String,
    voiceId: String
) -> AsyncThrowingStream<Data, Error> {
    AsyncThrowingStream { continuation in
        Task {
            do {
                // Set up streaming request
                let stream = try await setupStreamingRequest(text: text, voiceId: voiceId)

                // Yield chunks as they arrive
                for try await chunk in stream {
                    continuation.yield(chunk)
                }

                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
    }
}
```

### Custom Voice Settings

If your provider supports voice customization:

```swift
public struct VoiceSettings {
    let stability: Double       // 0.0 - 1.0
    let similarity: Double      // 0.0 - 1.0
    let speed: Double           // 0.5 - 2.0
    let pitch: Double           // 0.5 - 2.0
}

public func generateAudio(
    text: String,
    voiceId: String,
    settings: VoiceSettings? = nil
) async throws -> Data {
    let activeSettings = settings ?? defaultSettings
    // Use settings in API request
}
```

### Voice Metadata and Categories

Extend the `Voice` model with provider-specific metadata:

```swift
// In your provider
return Voice(
    id: apiVoice.id,
    name: apiVoice.name,
    description: apiVoice.description,
    providerId: providerId,
    language: apiVoice.language,
    locality: apiVoice.locality,
    gender: apiVoice.gender
)

// Access metadata
let voice = voices.first!
print("Language: \(voice.language ?? "unknown")")
print("Region: \(voice.locality ?? "unknown")")
print("Gender: \(voice.gender ?? "neutral")")
```

### Error Handling and Retry Logic

Implement robust error handling:

```swift
public func generateAudio(text: String, voiceId: String) async throws -> Data {
    var lastError: Error?

    // Retry up to 3 times
    for attempt in 1...3 {
        do {
            return try await generateAudioFromAPI(text: text, voiceId: voiceId)
        } catch let error as URLError where error.code == .timedOut {
            lastError = error
            // Wait before retry
            try await Task.sleep(nanoseconds: UInt64(attempt * 1_000_000_000))
            continue
        } catch {
            throw error  // Don't retry other errors
        }
    }

    throw lastError ?? VoiceProviderError.networkError("Max retries exceeded")
}
```

### Rate Limiting

Handle API rate limits:

```swift
actor RateLimiter {
    private var lastRequestTime: Date?
    private let minimumInterval: TimeInterval = 0.1  // 10 requests/second

    func waitForRateLimit() async {
        if let lastTime = lastRequestTime {
            let elapsed = Date().timeIntervalSince(lastTime)
            if elapsed < minimumInterval {
                let waitTime = minimumInterval - elapsed
                try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
            }
        }
        lastRequestTime = Date()
    }
}

// In your provider
private let rateLimiter = RateLimiter()

public func generateAudio(text: String, voiceId: String) async throws -> Data {
    await rateLimiter.waitForRateLimit()
    return try await generateAudioFromAPI(text: text, voiceId: voiceId)
}
```

---

## Common Patterns and Best Practices

### 1. Thread Safety

Use `Sendable` conformance and proper concurrency:

```swift
public final class MyCustomVoiceProvider: VoiceProvider {
    // Use immutable properties or actor isolation
    private let baseURL = "https://api.example.com"

    // For mutable state, use actors
    private let rateLimiter = RateLimiter()  // actor
}
```

### 2. Caching

The `VoiceProviderManager` handles caching automatically:

```swift
// Voice caching - automatically cached in SwiftData
let voices = try await manager.getVoices()  // First call: fetches from API
let voices2 = try await manager.getVoices()  // Subsequent: returns cached

// Force refresh
let freshVoices = try await manager.getVoices(forceRefresh: true)

// Audio caching - automatically cached in SwiftData
let audio = try await manager.generateAndCacheAudio(
    text: "Hello",
    voiceId: "voice-1",
    providerId: "mycustom"
)
```

### 3. Error Messages

Provide helpful error messages:

```swift
public enum MyCustomProviderError: LocalizedError {
    case invalidAPIKey
    case quotaExceeded
    case voiceNotFound(String)
    case invalidTextLength(Int, max: Int)

    public var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "Invalid API key. Please check your credentials."
        case .quotaExceeded:
            return "API quota exceeded. Please try again later."
        case .voiceNotFound(let id):
            return "Voice '\(id)' not found."
        case .invalidTextLength(let length, let max):
            return "Text too long (\(length) chars). Maximum: \(max) chars."
        }
    }
}
```

### 4. Logging

Add logging for debugging:

```swift
import os.log

private let logger = Logger(
    subsystem: "io.stovak.SwiftHablare",
    category: "MyCustomVoiceProvider"
)

public func generateAudio(text: String, voiceId: String) async throws -> Data {
    logger.info("Generating audio for voice: \(voiceId), text length: \(text.count)")

    do {
        let data = try await generateAudioFromAPI(text: text, voiceId: voiceId)
        logger.info("Successfully generated \(data.count) bytes of audio")
        return data
    } catch {
        logger.error("Failed to generate audio: \(error.localizedDescription)")
        throw error
    }
}
```

### 5. Testing with Mocks

Create a mock version for testing:

```swift
final class MockMyCustomProvider: VoiceProvider {
    var shouldThrowOnFetch = false
    var mockVoices: [Voice] = []
    var mockAudioData = Data()

    public let providerId = "mycustom-mock"
    public let displayName = "Mock Custom TTS"
    public let requiresAPIKey = false

    public func isConfigured() -> Bool { true }

    public func fetchVoices() async throws -> [Voice] {
        if shouldThrowOnFetch {
            throw VoiceProviderError.networkError("Mock error")
        }
        return mockVoices
    }

    public func generateAudio(text: String, voiceId: String) async throws -> Data {
        return mockAudioData
    }

    public func estimateDuration(text: String, voiceId: String) async -> TimeInterval {
        return 1.0
    }

    public func isVoiceAvailable(voiceId: String) async -> Bool {
        return mockVoices.contains { $0.id == voiceId }
    }
}
```

---

## Troubleshooting

### Common Issues

#### 1. Provider Not Showing in UI

**Problem:** Your provider doesn't appear in the provider selection menu.

**Solution:** Make sure you:
- Added the case to `VoiceProviderType` enum
- Implemented the `displayName` property
- Registered the provider in `VoiceProviderManager.init()`

#### 2. Configuration Always Fails

**Problem:** `isConfigured()` always returns false.

**Solution:**
- Check keychain account name matches between save and retrieve
- Verify API key is actually saved: `KeychainManager.shared.hasAPIKey(for: "account-name")`
- For system providers, return `true` directly

#### 3. Audio Generation Fails Silently

**Problem:** No error thrown but no audio returned.

**Solution:**
- Check network response status codes
- Verify API endpoint URLs
- Log response data to see actual API errors
- Ensure proper Content-Type headers

#### 4. Voices Not Appearing

**Problem:** `fetchVoices()` returns empty array.

**Solution:**
- Verify API response parsing
- Check language filtering isn't too restrictive
- Log raw API response
- Ensure proper authentication headers

#### 5. Duration Estimates Wrong

**Problem:** Estimated duration doesn't match actual audio.

**Solution:**
- Adjust `charactersPerSecond` constant
- Test with various text lengths
- Consider language-specific speaking rates
- Add buffer multiplier for safety

### Debug Checklist

When your provider isn't working:

1. **Configuration**
   - [ ] Provider added to `VoiceProviderType` enum
   - [ ] Provider registered in manager
   - [ ] API key saved correctly (if required)
   - [ ] `isConfigured()` returns true

2. **Network**
   - [ ] Base URL is correct
   - [ ] Endpoints are correct
   - [ ] Authentication headers are correct
   - [ ] Request/response models match API

3. **Data Parsing**
   - [ ] Response models match API response structure
   - [ ] Proper error handling for malformed responses
   - [ ] Voice model conversion is correct

4. **Testing**
   - [ ] Unit tests pass
   - [ ] Integration tests work with real API
   - [ ] Error cases are handled

---

## Real-World Examples

### Example 1: Google Cloud Text-to-Speech

```swift
public final class GoogleCloudVoiceProvider: VoiceProvider {
    private let baseURL = "https://texttospeech.googleapis.com/v1"
    private let keychainManager = KeychainManager.shared
    private let apiKeyAccount = "google-cloud-api-key"

    public let providerId = "google-cloud"
    public let displayName = "Google Cloud TTS"
    public let requiresAPIKey = true

    public func fetchVoices() async throws -> [Voice] {
        guard isConfigured() else {
            throw VoiceProviderError.notConfigured
        }

        let apiKey = try keychainManager.getAPIKey(for: apiKeyAccount)
        let url = URL(string: "\(baseURL)/voices?key=\(apiKey)")!

        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(GoogleVoicesResponse.self, from: data)

        return response.voices.map { gVoice in
            Voice(
                id: gVoice.name,
                name: gVoice.name,
                description: "Language: \(gVoice.languageCodes.joined(separator: ", "))",
                providerId: providerId,
                language: gVoice.languageCodes.first,
                locality: nil,
                gender: gVoice.ssmlGender?.lowercased()
            )
        }
    }

    public func generateAudio(text: String, voiceId: String) async throws -> Data {
        guard isConfigured() else {
            throw VoiceProviderError.notConfigured
        }

        let apiKey = try keychainManager.getAPIKey(for: apiKeyAccount)
        let url = URL(string: "\(baseURL)/text:synthesize?key=\(apiKey)")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody = GoogleSynthesizeRequest(
            input: GoogleTextInput(text: text),
            voice: GoogleVoiceSelection(
                languageCode: "en-US",  // Extract from voiceId
                name: voiceId
            ),
            audioConfig: GoogleAudioConfig(audioEncoding: "MP3")
        )

        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(GoogleSynthesizeResponse.self, from: data)

        // Decode base64 audio
        guard let audioData = Data(base64Encoded: response.audioContent) else {
            throw VoiceProviderError.invalidResponse
        }

        return audioData
    }
}

// API Models
private struct GoogleVoicesResponse: Codable {
    let voices: [GoogleVoice]
}

private struct GoogleVoice: Codable {
    let languageCodes: [String]
    let name: String
    let ssmlGender: String?
}

private struct GoogleSynthesizeRequest: Codable {
    let input: GoogleTextInput
    let voice: GoogleVoiceSelection
    let audioConfig: GoogleAudioConfig
}

private struct GoogleTextInput: Codable {
    let text: String
}

private struct GoogleVoiceSelection: Codable {
    let languageCode: String
    let name: String
}

private struct GoogleAudioConfig: Codable {
    let audioEncoding: String
}

private struct GoogleSynthesizeResponse: Codable {
    let audioContent: String  // Base64-encoded audio
}
```

### Example 2: Azure Cognitive Services Speech

```swift
public final class AzureVoiceProvider: VoiceProvider {
    private let region: String
    private let baseURL: String
    private let keychainManager = KeychainManager.shared
    private let apiKeyAccount = "azure-speech-api-key"

    public let providerId = "azure-speech"
    public let displayName = "Azure Cognitive Speech"
    public let requiresAPIKey = true

    public init(region: String = "eastus") {
        self.region = region
        self.baseURL = "https://\(region).tts.speech.microsoft.com"
    }

    public func generateAudio(text: String, voiceId: String) async throws -> Data {
        guard isConfigured() else {
            throw VoiceProviderError.notConfigured
        }

        let apiKey = try keychainManager.getAPIKey(for: apiKeyAccount)
        let url = URL(string: "\(baseURL)/cognitiveservices/v1")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(apiKey, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        request.addValue("ssml", forHTTPHeaderField: "Content-Type")
        request.addValue("audio-16khz-128kbitrate-mono-mp3", forHTTPHeaderField: "X-Microsoft-OutputFormat")

        // Build SSML request
        let ssml = """
        <speak version='1.0' xml:lang='en-US'>
            <voice name='\(voiceId)'>\(text)</voice>
        </speak>
        """
        request.httpBody = ssml.data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: request)
        return data
    }
}
```

---

## Creating an External Provider Package

This section shows how to create a complete, distributable voice provider package that works independently of the SwiftHablare library.

### Complete Package Structure

```
MyCustomVoiceProvider/
├── Package.swift
├── README.md
├── Sources/
│   └── MyCustomVoiceProvider/
│       ├── MyCustomVoiceProvider.swift
│       └── Models/
│           ├── CustomVoiceModels.swift
│           └── CustomAPIModels.swift
└── Tests/
    └── MyCustomVoiceProviderTests/
        └── MyCustomVoiceProviderTests.swift
```

### Example: Complete External Package

**Package.swift:**
```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MyCustomVoiceProvider",
    platforms: [.iOS(.v26), .macCatalyst(.v15)],
    products: [
        .library(
            name: "MyCustomVoiceProvider",
            targets: ["MyCustomVoiceProvider"]),
    ],
    dependencies: [
        .package(url: "https://github.com/intrusive-memory/SwiftHablare.git", from: "2.0.0")
    ],
    targets: [
        .target(
            name: "MyCustomVoiceProvider",
            dependencies: ["SwiftHablare"]),
        .testTarget(
            name: "MyCustomVoiceProviderTests",
            dependencies: ["MyCustomVoiceProvider"]),
    ]
)
```

**Sources/MyCustomVoiceProvider/MyCustomVoiceProvider.swift:**
```swift
import Foundation
import SwiftHablare

public final class MyCustomVoiceProvider: VoiceProvider {
    // MARK: - VoiceProvider Protocol

    public let providerId = "mycustom"
    public let displayName = "My Custom TTS"
    public let requiresAPIKey = true

    private let baseURL = "https://api.mycustom.com/v1"
    private let keychainManager = KeychainManager.shared
    private let apiKeyAccount = "mycustom-api-key"

    public init() {}

    public func isConfigured() -> Bool {
        do {
            _ = try keychainManager.getAPIKey(for: apiKeyAccount)
            return true
        } catch {
            return false
        }
    }

    public func fetchVoices() async throws -> [Voice] {
        guard isConfigured() else {
            throw VoiceProviderError.notConfigured
        }

        let apiKey = try keychainManager.getAPIKey(for: apiKeyAccount)
        guard let url = URL(string: "\(baseURL)/voices") else {
            throw VoiceProviderError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.addValue(apiKey, forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(VoicesResponse.self, from: data)

        return response.voices.map { apiVoice in
            Voice(
                id: apiVoice.id,
                name: apiVoice.name,
                description: apiVoice.description,
                providerId: providerId,
                language: apiVoice.language,
                locality: apiVoice.locality,
                gender: apiVoice.gender
            )
        }
    }

    public func generateAudio(text: String, voiceId: String) async throws -> Data {
        guard isConfigured() else {
            throw VoiceProviderError.notConfigured
        }

        let apiKey = try keychainManager.getAPIKey(for: apiKeyAccount)
        guard let url = URL(string: "\(baseURL)/generate") else {
            throw VoiceProviderError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "Authorization")

        let body = GenerateRequest(text: text, voiceId: voiceId)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await URLSession.shared.data(for: request)
        return data
    }

    public func estimateDuration(text: String, voiceId: String) async -> TimeInterval {
        return Double(text.count) / 13.0 * 1.15
    }

    public func isVoiceAvailable(voiceId: String) async -> Bool {
        do {
            let voices = try await fetchVoices()
            return voices.contains { $0.id == voiceId }
        } catch {
            return false
        }
    }
}

// MARK: - API Models

private struct VoicesResponse: Codable {
    let voices: [APIVoice]
}

private struct APIVoice: Codable {
    let id: String
    let name: String
    let description: String?
    let language: String?
    let locality: String?
    let gender: String?
}

private struct GenerateRequest: Codable {
    let text: String
    let voiceId: String
}
```

**README.md:**
```markdown
# My Custom Voice Provider

A SwiftHablare voice provider for My Custom TTS service.

## Installation

### Swift Package Manager

Add this to your `Package.swift`:

\```swift
dependencies: [
    .package(url: "https://github.com/yourusername/MyCustomVoiceProvider.git", from: "1.0.0")
]
\```

Or in Xcode: File > Add Package Dependencies...

## Usage

\```swift
import SwiftHablare
import MyCustomVoiceProvider

// Register the provider
let manager = VoiceProviderManager(modelContext: context)
manager.registerProvider(MyCustomVoiceProvider())

// Configure API key
try KeychainManager.shared.saveAPIKey("your-api-key", for: "mycustom-api-key")

// Switch to the provider
manager.switchProvider(to: "mycustom")

// Use it!
let voices = try await manager.getVoices()
let audio = try await manager.generateAudio(text: "Hello!", voiceId: voices.first!.id)
\```

## Configuration

This provider requires an API key from [My Custom TTS](https://mycustom.com).

## License

MIT
```

### Using Your External Package

In your app's `Package.swift`:
```swift
dependencies: [
    .package(url: "https://github.com/intrusive-memory/SwiftHablare.git", from: "2.0.0"),
    .package(url: "https://github.com/yourusername/MyCustomVoiceProvider.git", from: "1.0.0")
]
```

In your app:
```swift
import SwiftUI
import SwiftData
import SwiftHablare
import MyCustomVoiceProvider

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: [VoiceModel.self, AudioFile.self])
        }
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var providerManager: VoiceProviderManager

    init() {
        // This will be set properly in onAppear
        _providerManager = StateObject(wrappedValue: VoiceProviderManager(
            modelContext: ModelContext(try! ModelContainer(for: VoiceModel.self, AudioFile.self))
        ))
    }

    var body: some View {
        VStack {
            VoiceProviderWidget(providerManager: providerManager)
        }
        .onAppear {
            // Register custom provider
            providerManager.registerProvider(MyCustomVoiceProvider())
        }
    }
}
```

### Publishing Your Package

1. **Create a Git repository**:
   ```bash
   git init
   git add .
   git commit -m "Initial commit"
   ```

2. **Tag a release**:
   ```bash
   git tag 1.0.0
   git push origin main --tags
   ```

3. **Share it**:
   - Add it to the [Swift Package Index](https://swiftpackageindex.com)
   - Share the repository URL
   - Document it in your README

---

## Summary

To integrate a new voice provider **without modifying the library**:

1. **Create the provider class** conforming to `VoiceProvider`
   - Optionally in a separate Swift package for reusability
2. **Implement required methods**: `fetchVoices()`, `generateAudio()`, etc.
3. **Handle authentication** if needed (keychain storage)
4. **Register dynamically**: `manager.registerProvider(YourProvider())`
5. **Write tests** to verify functionality
6. **Document** any provider-specific configuration
7. **Distribute** as a package (optional)

### Key Benefits of the New Architecture

✅ **No library modification needed**
✅ **Providers can be separate packages**
✅ **Dynamic registration at runtime**
✅ **Automatic UI integration**
✅ **Backward compatible with existing code**

The architecture handles caching, persistence, and UI integration automatically once your provider is registered.

---

## Additional Resources

- **VoiceProvider Protocol**: `Sources/SwiftHablare/VoiceProvider.swift`
- **Existing Providers**:
  - `Sources/SwiftHablare/Providers/ElevenLabsVoiceProvider.swift`
  - `Sources/SwiftHablare/Providers/AppleVoiceProvider.swift`
- **Manager**: `Sources/SwiftHablare/VoiceProviderManager.swift`
- **Tests**: `Tests/SwiftHablareTests/Manager/VoiceProviderManagerTests.swift`

For questions or issues, please file an issue in the project repository.
