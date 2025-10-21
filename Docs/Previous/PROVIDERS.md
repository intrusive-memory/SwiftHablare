# SwiftHablaré Provider Documentation

**Version**: 2.0
**Last Updated**: 2025-10-12
**Status**: Production Ready

This document provides comprehensive information about all implemented AI service providers in SwiftHablaré, intended for developers and AI assistants integrating with or extending the framework.

---

## Table of Contents

- [Overview](#overview)
- [Provider Architecture](#provider-architecture)
- [Implemented Providers](#implemented-providers)
  - [OpenAI Provider](#openai-provider)
  - [Anthropic Provider](#anthropic-provider)
  - [Apple Intelligence Provider](#apple-intelligence-provider)
  - [ElevenLabs Provider](#elevenlabs-provider)
- [Common Patterns](#common-patterns)
- [Integration Guide](#integration-guide)
- [Testing Guidelines](#testing-guidelines)
- [Adding New Providers](#adding-new-providers)

---

## Overview

SwiftHablaré provides a unified interface for interacting with multiple AI service providers through the `AIServiceProvider` protocol. All providers implement consistent patterns for:

- **Secure Credential Management**: Integration with `AICredentialManager` actor
- **Error Handling**: Unified `Result<ResponseContent, AIServiceError>` pattern
- **Concurrency Safety**: Swift 6 strict concurrency compliance with `@unchecked Sendable`
- **Type Safety**: Strong typing for requests, responses, and parameters
- **Testing**: Comprehensive test coverage on all testable code paths

### Provider Capabilities

| Provider | Capabilities | Response Type | API Key Required | Network Required |
|----------|-------------|---------------|------------------|------------------|
| OpenAI | Text Generation, Embeddings | Text | ✅ Yes | ✅ Yes |
| Anthropic | Text Generation | Text | ✅ Yes | ✅ Yes |
| Apple Intelligence | Text Generation | Text | ❌ No | ❌ No (on-device) |
| ElevenLabs | Audio Generation | Audio (MP3) | ✅ Yes | ✅ Yes |

---

## Provider Architecture

### Base Classes

All network-based providers extend `BaseHTTPProvider`:

```swift
@available(macOS 15.0, iOS 17.0, *)
open class BaseHTTPProvider: @unchecked Sendable {
    public let baseURL: String
    public let timeout: TimeInterval

    // JSON POST request
    public func post<Request: Encodable, Response: Decodable>(
        endpoint: String,
        headers: [String: String],
        body: Request
    ) async throws -> Response

    // GET request
    public func get<Response: Decodable>(
        endpoint: String,
        headers: [String: String]
    ) async throws -> Response
}
```

### Protocol Requirements

All providers implement `AIServiceProvider`:

```swift
public protocol AIServiceProvider: Sendable {
    var id: String { get }
    var displayName: String { get }
    var capabilities: [AICapability] { get }
    var supportedDataStructures: [DataStructureCapability] { get }
    var requiresAPIKey: Bool { get }
    var responseType: ResponseContent.ContentType { get }

    func isConfigured() -> Bool
    func validateConfiguration() throws

    func generate(
        prompt: String,
        parameters: [String: Any]
    ) async -> Result<ResponseContent, AIServiceError>
}
```

### Credential Integration

All providers that require API keys integrate with `AICredentialManager`:

```swift
let credential: SecureString
do {
    credential = try await credentialManager.retrieve(providerID: id, type: .apiKey)
} catch {
    return .failure(.missingCredentials("Failed to retrieve API key"))
}
```

---

## Implemented Providers

### OpenAI Provider

**File**: `Sources/SwiftHablare/Providers/DefaultProviders/OpenAIProvider.swift`
**Tests**: `Tests/SwiftHablareTests/Providers/OpenAIProviderTests.swift` (40 tests)

#### Overview

Production-ready OpenAI provider with full support for GPT-4 and GPT-3.5 Turbo models via the Chat Completions API.

#### Configuration

```swift
let provider = OpenAIProvider()
// or with custom configuration
let provider = OpenAIProvider(
    credentialManager: .shared,
    baseURL: "https://api.openai.com/v1"
)
```

#### API Integration

- **Endpoint**: `/chat/completions`
- **Authentication**: Bearer token (`Authorization: Bearer {api_key}`)
- **API Key Format**: Must start with `sk-` or `test-`
- **Default Model**: `gpt-3.5-turbo`
- **Timeout**: 120 seconds

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `model` | String | `gpt-3.5-turbo` | Model to use (gpt-4, gpt-4-turbo, gpt-3.5-turbo) |
| `temperature` | Double | 0.7 | Sampling temperature (0.0-2.0) |
| `max_tokens` | Int | None | Maximum tokens in response |

#### Request Structure

```swift
struct ChatCompletionRequest: Encodable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double?
    let maxTokens: Int?
}

struct ChatMessage: Codable {
    let role: String  // "system", "user", "assistant"
    let content: String
}
```

#### Response Structure

```swift
struct ChatCompletionResponse: Decodable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [Choice]
    let usage: Usage?

    struct Choice: Decodable {
        let index: Int
        let message: ChatMessage
        let finishReason: String?
    }

    struct Usage: Decodable {
        let promptTokens: Int
        let completionTokens: Int
        let totalTokens: Int
    }
}
```

#### Usage Example

```swift
let provider = OpenAIProvider()

// Store API key (one-time)
let credential = AICredential(
    providerID: "openai",
    type: .apiKey,
    name: "Production Key"
)
try await AICredentialManager.shared.store(
    credential: credential,
    value: SecureString("sk-your-key-here")
)

// Generate text
let result = await provider.generate(
    prompt: "Explain quantum computing",
    parameters: [
        "model": "gpt-4",
        "temperature": 0.7,
        "max_tokens": 500
    ]
)

switch result {
case .success(let content):
    print(content.text ?? "")
case .failure(let error):
    print("Error: \(error)")
}
```

#### Error Handling

- Missing credentials → `.missingCredentials`
- Invalid API key format → `.invalidAPIKey`
- Authentication failure (401) → `.authenticationFailed`
- Rate limit (429) → `.rateLimitExceeded`
- Network errors → `.networkError`, `.connectionFailed`, `.timeout`

---

### Anthropic Provider

**File**: `Sources/SwiftHablare/Providers/DefaultProviders/AnthropicProvider.swift`
**Tests**: `Tests/SwiftHablareTests/Providers/AnthropicProviderTests.swift` (35 tests)

#### Overview

Production-ready Anthropic provider with full support for Claude 3 models (Opus, Sonnet, Haiku) via the Messages API.

#### Configuration

```swift
let provider = AnthropicProvider()
// or with custom configuration
let provider = AnthropicProvider(
    credentialManager: .shared,
    baseURL: "https://api.anthropic.com"
)
```

#### API Integration

- **Endpoint**: `/v1/messages`
- **Authentication**: API key header (`x-api-key: {api_key}`)
- **Required Header**: `anthropic-version: 2023-06-01`
- **API Key Format**: Must start with `sk-ant-` or `test-`
- **Default Model**: `claude-3-sonnet-20240229`
- **Timeout**: 120 seconds

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `model` | String | `claude-3-sonnet-20240229` | Claude 3 model (opus, sonnet, haiku) |
| `max_tokens` | Int | 1024 | Maximum tokens in response (required) |
| `temperature` | Double | None | Sampling temperature (0.0-1.0) |
| `system` | String | None | System prompt for context |

#### Request Structure

```swift
struct MessagesRequest: Encodable {
    let model: String
    let messages: [Message]
    let maxTokens: Int
    let temperature: Double?
    let system: String?
}

struct Message: Codable {
    let role: String  // "user", "assistant"
    let content: String
}
```

#### Response Structure

```swift
struct MessagesResponse: Decodable {
    let id: String
    let type: String
    let role: String
    let content: [Content]
    let model: String
    let stopReason: String?
    let usage: Usage

    struct Content: Decodable {
        let type: String
        let text: String
    }

    struct Usage: Decodable {
        let inputTokens: Int
        let outputTokens: Int
    }
}
```

#### Usage Example

```swift
let provider = AnthropicProvider()

// Generate with system prompt
let result = await provider.generate(
    prompt: "Explain quantum entanglement",
    parameters: [
        "model": "claude-3-opus-20240229",
        "max_tokens": 2048,
        "temperature": 0.8,
        "system": "You are a physics professor"
    ]
)
```

#### Model Options

- `claude-3-opus-20240229` - Most capable, best for complex tasks
- `claude-3-sonnet-20240229` - Balanced performance and speed
- `claude-3-haiku-20240307` - Fastest, best for simple tasks

---

### Apple Intelligence Provider

**File**: `Sources/SwiftHablare/Providers/DefaultProviders/AppleIntelligenceProvider.swift`
**Tests**: `Tests/SwiftHablareTests/Providers/AppleIntelligenceProviderTests.swift` (31 tests)

#### Overview

Privacy-first provider for on-device AI processing using Apple's built-in language models. Currently implements a simulation layer ready for integration with Apple Intelligence APIs when publicly available.

#### Configuration

```swift
let provider = AppleIntelligenceProvider()
// No credential manager needed - no API key required
```

#### API Integration

- **Processing**: On-device (no network calls)
- **Authentication**: None required
- **API Key**: Not required
- **Privacy**: All data stays on device
- **Platform**: macOS 15.0+ / iOS 17.0+

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `temperature` | Double | 0.7 | Sampling temperature |
| `max_length` | Int | 500 | Maximum response length |

#### Usage Example

```swift
let provider = AppleIntelligenceProvider()

// Works offline - no API key needed
let result = await provider.generate(
    prompt: "Summarize this article: ...",
    parameters: [
        "temperature": 0.5,
        "max_length": 200
    ]
)

// Check device capabilities
let deviceInfo = provider.getDeviceInfo()
print(deviceInfo["platform"])    // "macOS" or "iOS"
print(deviceInfo["privacy"])     // "all data stays on device"
print(deviceInfo["requires_network"])  // "false"

// Check platform support
if AppleIntelligenceProvider.isSupported() {
    // Device supports Apple Intelligence
}
```

#### Platform Detection

```swift
public static func isSupported() -> Bool
public func getDeviceInfo() -> [String: String]
```

#### Implementation Note

The current implementation simulates Apple Intelligence behavior. When Apple's on-device AI APIs become publicly available, this provider will be updated to use the official APIs. The interface and behavior will remain consistent.

---

### ElevenLabs Provider

**File**: `Sources/SwiftHablare/Providers/DefaultProviders/ElevenLabsProvider.swift`
**Tests**: Tests follow same pattern as other providers

#### Overview

Production-ready text-to-speech provider with support for multiple ElevenLabs voices and voice customization settings.

#### Configuration

```swift
let provider = ElevenLabsProvider()
// or with custom configuration
let provider = ElevenLabsProvider(
    credentialManager: .shared,
    baseURL: "https://api.elevenlabs.io"
)
```

#### API Integration

- **Endpoint**: `/v1/text-to-speech/{voice_id}`
- **Authentication**: API key header (`xi-api-key: {api_key}`)
- **API Key Format**: Minimum 32 characters (hex string)
- **Default Voice**: `21m00Tcm4TlvDq8ikWAM` (Rachel)
- **Default Model**: `eleven_monolingual_v1`
- **Response Format**: Binary MP3 audio data
- **Timeout**: 120 seconds

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `voice_id` | String | `21m00Tcm4TlvDq8ikWAM` | Voice to use (Rachel, etc.) |
| `model_id` | String | `eleven_monolingual_v1` | TTS model |
| `stability` | Double | 0.5 | Voice stability (0.0-1.0) |
| `clarity_boost` | Double | 0.75 | Similarity boost (0.0-1.0) |

#### Request Structure

```swift
struct TextToSpeechRequest: Encodable {
    let text: String
    let modelId: String
    let voiceSettings: VoiceSettings
}

struct VoiceSettings: Codable {
    let stability: Double
    let similarityBoost: Double
}
```

#### Response Format

Returns binary MP3 audio data wrapped in `ResponseContent.audio(Data, format: .mp3)`

#### Usage Example

```swift
let provider = ElevenLabsProvider()

// Generate speech
let result = await provider.generate(
    prompt: "Hello, world!",
    parameters: [
        "voice_id": "21m00Tcm4TlvDq8ikWAM",
        "model_id": "eleven_monolingual_v1",
        "stability": 0.5,
        "clarity_boost": 0.75
    ]
)

switch result {
case .success(let content):
    if let audioContent = content.audioContent {
        // audioContent.data is MP3 binary data
        // audioContent.format is .mp3
        try audioContent.data.write(to: outputURL)
    }
case .failure(let error):
    print("TTS Error: \(error)")
}
```

#### Binary Data Handling

ElevenLabs provider implements custom `postForData()` method to handle binary responses instead of JSON:

```swift
private func postForData<Request: Encodable>(
    endpoint: String,
    headers: [String: String],
    body: Request
) async throws -> Data
```

---

## Common Patterns

### 1. Provider Initialization

All providers support two initialization patterns:

```swift
// Default (uses shared credential manager and default base URL)
let provider = ProviderType()

// Custom configuration
let provider = ProviderType(
    credentialManager: customManager,
    baseURL: customURL
)
```

### 2. Factory Method

All providers provide a shared factory method:

```swift
let provider = ProviderType.shared()
```

### 3. Credential Storage

Store credentials once, use across sessions:

```swift
let credential = AICredential(
    providerID: "provider-id",
    type: .apiKey,
    name: "Display Name"
)

try await AICredentialManager.shared.store(
    credential: credential,
    value: SecureString("api-key-value")
)
```

### 4. Generation Pattern

All providers use the same generation interface:

```swift
let result = await provider.generate(
    prompt: "Your prompt here",
    parameters: ["key": "value"]
)

switch result {
case .success(let content):
    // Handle success - extract text, audio, etc.
case .failure(let error):
    // Handle error
}
```

### 5. Error Handling

All providers map errors to `AIServiceError`:

```swift
public enum AIServiceError: Error {
    case missingCredentials(String)
    case invalidAPIKey(String)
    case authenticationFailed(String)
    case rateLimitExceeded(String, retryAfter: Int? = nil)
    case invalidRequest(String)
    case timeout(String)
    case connectionFailed(String)
    case networkError(String)
    case providerError(String)
    case unexpectedResponseFormat(String)
    case dataConversionError(String)
    case configurationError(String)
}
```

### 6. Response Content Types

```swift
public enum ResponseContent: Sendable {
    case text(String)
    case data(Data)
    case audio(Data, format: AudioFormat)
    case image(Data, format: ImageFormat)
    case structured([String: SendableValue])
}
```

Extract content using type-safe accessors:

```swift
content.text                    // Optional<String>
content.dataContent             // Optional<Data>
content.audioContent            // Optional<(data: Data, format: AudioFormat)>
content.imageContent            // Optional<(data: Data, format: ImageFormat)>
content.structuredContent       // Optional<[String: SendableValue]>
```

---

## Integration Guide

### Step 1: Register Provider

```swift
let serviceManager = AIServiceManager.shared

// Register providers
serviceManager.register(OpenAIProvider())
serviceManager.register(AnthropicProvider())
serviceManager.register(AppleIntelligenceProvider())
serviceManager.register(ElevenLabsProvider())
```

### Step 2: Store Credentials

```swift
// OpenAI
let openAICredential = AICredential(
    providerID: "openai",
    type: .apiKey,
    name: "OpenAI Production Key"
)
try await AICredentialManager.shared.store(
    credential: openAICredential,
    value: SecureString("sk-...")
)

// Anthropic
let anthropicCredential = AICredential(
    providerID: "anthropic",
    type: .apiKey,
    name: "Anthropic Production Key"
)
try await AICredentialManager.shared.store(
    credential: anthropicCredential,
    value: SecureString("sk-ant-...")
)

// Apple Intelligence: No credentials needed

// ElevenLabs
let elevenLabsCredential = AICredential(
    providerID: "elevenlabs",
    type: .apiKey,
    name: "ElevenLabs Production Key"
)
try await AICredentialManager.shared.store(
    credential: elevenLabsCredential,
    value: SecureString("your-32-char-key")
)
```

### Step 3: Query Providers

```swift
// Get all providers
let allProviders = serviceManager.allProviders()

// Get providers by capability
let textProviders = serviceManager.providers(withCapability: .textGeneration)
let audioProviders = serviceManager.providers(withCapability: .audioGeneration)

// Get specific provider
if let openAI = serviceManager.provider(id: "openai") {
    // Use provider
}
```

### Step 4: Generate Content

```swift
// Text generation
if let provider = serviceManager.provider(id: "openai") {
    let result = await provider.generate(
        prompt: "Your prompt",
        parameters: ["model": "gpt-4"]
    )
}

// Audio generation
if let provider = serviceManager.provider(id: "elevenlabs") {
    let result = await provider.generate(
        prompt: "Text to speak",
        parameters: ["voice_id": "21m00Tcm4TlvDq8ikWAM"]
    )
}
```

---

## Testing Guidelines

### Test Structure

Each provider has comprehensive tests covering:

1. **Identity Tests**: ID, display name, capabilities, response type
2. **Configuration Tests**: isConfigured(), validateConfiguration()
3. **Credential Tests**: Missing credentials, invalid format, validation
4. **Request Tests**: JSON encoding, parameter handling
5. **Response Tests**: JSON decoding, error cases
6. **Error Handling Tests**: All error scenarios
7. **Edge Cases**: Empty inputs, long content, special characters

### Example Test Pattern

```swift
@Test("Provider has correct identity")
func testProviderIdentity() {
    let provider = ProviderType()

    #expect(provider.id == "expected-id")
    #expect(provider.displayName == "Expected Name")
}

@Test("Provider returns error when credentials are missing")
func testMissingCredentials() async {
    let credentialManager = AICredentialManager()
    let provider = ProviderType(
        credentialManager: credentialManager,
        baseURL: "https://test.example.com"
    )

    let result = await provider.generate(
        prompt: "test",
        parameters: [:]
    )

    switch result {
    case .success:
        Issue.record("Expected failure for missing credentials")
    case .failure(let error):
        if case .missingCredentials = error {
            // Expected
        } else {
            Issue.record("Expected missingCredentials error")
        }
    }
}
```

### Coverage Goals

- **Public API**: 100% coverage
- **Request/Response Structures**: 100% coverage
- **Parameter Handling**: 100% coverage
- **Error Paths**: 100% coverage
- **Validation Logic**: 100% coverage

Note: HTTP layer (actual network calls) requires integration testing or complex URLSession mocking and is not included in unit test coverage targets.

---

## Adding New Providers

### Step 1: Create Provider Class

```swift
@available(macOS 15.0, iOS 17.0, *)
public final class NewProvider: BaseHTTPProvider, AIServiceProvider, @unchecked Sendable {

    // Constants
    public static let defaultBaseURL = "https://api.provider.com"
    private static let defaultModel = "model-name"

    // Identity
    public let id: String = "provider-id"
    public let displayName: String = "Provider Name"

    // Capabilities
    public let capabilities: [AICapability] = [.textGeneration]
    public let supportedDataStructures: [DataStructureCapability] = []
    public let requiresAPIKey: Bool = true
    public let responseType: ResponseContent.ContentType = .text

    private let credentialManager: AICredentialManager

    // Initialization
    public init(
        credentialManager: AICredentialManager = .shared,
        baseURL: String = defaultBaseURL
    ) {
        self.credentialManager = credentialManager
        super.init(baseURL: baseURL, timeout: 120.0)
    }

    // Configuration
    public func isConfigured() -> Bool {
        return true
    }

    public func validateConfiguration() throws {
        // Empty - validation happens in generate()
    }

    // Generation
    public func generate(
        prompt: String,
        parameters: [String: Any]
    ) async -> Result<ResponseContent, AIServiceError> {
        // 1. Get credentials
        let credential: SecureString
        do {
            credential = try await credentialManager.retrieve(providerID: id, type: .apiKey)
        } catch {
            return .failure(.missingCredentials("Failed to retrieve API key"))
        }

        // 2. Validate API key
        guard credential.value.hasPrefix("expected-prefix") else {
            return .failure(.invalidAPIKey("Invalid key format"))
        }

        // 3. Extract parameters
        let model = parameters["model"] as? String ?? Self.defaultModel

        // 4. Build request
        let request = /* create request struct */

        // 5. Make API call
        do {
            let response: ResponseType = try await post(
                endpoint: "/path",
                headers: [
                    "Authorization": "Bearer \(credential.value)"
                ],
                body: request
            )

            // 6. Extract and return content
            return .success(.text(response.content))

        } catch let error as AIServiceError {
            return .failure(error)
        } catch {
            return .failure(.networkError("API request failed"))
        }
    }

    // Factory method
    public static func shared() -> NewProvider {
        return NewProvider(credentialManager: .shared)
    }
}
```

### Step 2: Define Request/Response Models

```swift
extension NewProvider {
    struct Request: Encodable {
        let model: String
        let prompt: String
        // ... other fields
    }

    struct Response: Decodable {
        let content: String
        // ... other fields
    }
}
```

### Step 3: Create Comprehensive Tests

Follow the testing pattern from existing providers (40+ tests covering all scenarios).

### Step 4: Document the Provider

Add documentation to this file following the established format.

---

## Best Practices

### 1. Credential Security

- ✅ Always use `AICredentialManager` for credentials
- ✅ Validate API key format before making requests
- ✅ Never log or expose credentials in errors
- ✅ Clear credentials from memory after use

### 2. Error Handling

- ✅ Map all errors to `AIServiceError` types
- ✅ Provide descriptive error messages
- ✅ Handle all HTTP status codes appropriately
- ✅ Don't expose internal implementation details in errors

### 3. Testing

- ✅ Test all code paths that don't require real API calls
- ✅ Test parameter extraction and validation
- ✅ Test request/response JSON encoding/decoding
- ✅ Test all error scenarios
- ✅ Test edge cases (empty inputs, special characters, etc.)

### 4. Documentation

- ✅ Complete DocC-style inline documentation
- ✅ Parameter descriptions with types and defaults
- ✅ Usage examples in docstrings
- ✅ Error cases documented

### 5. Concurrency

- ✅ Use `@unchecked Sendable` conformance
- ✅ All properties must be thread-safe
- ✅ Use actors for mutable state
- ✅ Async/await for all network operations

---

## Version History

- **v2.0** (2025-10-12): Initial release with 4 production providers
  - OpenAI Provider
  - Anthropic Provider
  - Apple Intelligence Provider
  - ElevenLabs Provider

---

## Support

For questions, issues, or contributions:
- **GitHub Issues**: https://github.com/intrusive-memory/SwiftHablare/issues
- **Documentation**: See REQUIREMENTS.md and METHODOLOGY.md
- **Examples**: Check test files for usage patterns

---

**Last Updated**: 2025-10-12
**Maintained By**: SwiftHablaré Team
