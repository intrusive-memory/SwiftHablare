# Engine Boundary Protocol

The Engine Boundary Protocol defines how SwiftHablare voice providers interact with low-level speech synthesis engines. It enables providers to focus on configuration, caching, and integration while engines focus on remote/service calls and audio generation.

## Overview

* **Protocol:** `VoiceEngine`
* **Location:** `Sources/SwiftHablare/Protocols/VoiceEngine.swift`
* **Purpose:** Standardize how providers communicate with engines that fetch voices and generate audio data.

The boundary makes it straightforward to plug in engines implemented in Swift, Swift-compatible C modules, or remote services (via HTTP, gRPC, WebSocket, etc.). Providers wrap an engine, translate library APIs into `VoiceEngineRequest`/`VoiceEngineOutput`, and manage the resulting audio assets.

## Key Types

### `VoiceEngine`

```swift
public protocol VoiceEngine: Sendable {
    associatedtype Configuration: Sendable
    var engineId: String { get }
    func canGenerate(with configuration: Configuration) -> Bool
    func fetchVoices(languageCode: String, configuration: Configuration) async throws -> [Voice]
    func generateAudio(request: VoiceEngineRequest, configuration: Configuration) async throws -> VoiceEngineOutput
    func estimateDuration(request: VoiceEngineRequest, configuration: Configuration) -> TimeInterval
    func isVoiceAvailable(voiceId: String, configuration: Configuration) async -> Bool
}
```

* **Configuration** – provider-owned struct containing credentials, platform context, or dependency handles required by the engine.
* **Engine ID** – unique identifier for analytics/debugging.
* **Lifecycle** – engines are stateless and thread-safe. Providers create requests/configurations per operation.

### `VoiceEngineRequest`

Represents an immutable synthesis request.

* `text` – content to synthesize.
* `voiceId` – engine-specific voice identifier.
* `languageCode` – BCP-47 style identifier used when the engine supports language scoping.
* `options` – string metadata for feature toggles (e.g., style, stability, codec hints).

Providers typically call `engine.makeRequest(...)` to build instances safely.

### `VoiceEngineOutput`

Encapsulates the result of generation.

* `audioData` – binary payload returned by the engine.
* `audioFormat` – `VoiceEngineAudioFormat` enum describing the encoding (`.mp3`, `.wav`, `.aifc`, etc.).
* `metadata` – dictionary for optional context such as engine version, latency, or request identifiers.

## Provider Responsibilities

1. **Configuration Management** – assemble a `Configuration` value before invoking the engine. This often includes API keys, OAuth tokens, device capabilities, or caching preferences.
2. **Request Creation** – construct a `VoiceEngineRequest` from the public `VoiceProvider` API, adding any provider-specific options.
3. **Integration Tasks** – handle Keychain access, SwiftData persistence, caching, and UI updates using the `VoiceEngineOutput`.
4. **Error Translation** – surface engine errors as `VoiceProviderError` values or custom domain errors.

## Engine Responsibilities

1. **Voice Discovery** – fetch supported voices and translate them into SwiftHablare `Voice` models.
2. **Audio Generation** – execute HTTP or native SDK calls to produce audio. Engines never persist the result; they simply return `VoiceEngineOutput`.
3. **Duration Estimation** – provide best-effort estimates for UI feedback.
4. **Voice Validation** – perform lightweight checks to confirm that a voice identifier is valid.

## Reference Implementations

SwiftHablare ships with two engine-backed providers:

| Provider | Engine | Notes |
| --- | --- | --- |
| `AppleVoiceProvider` | `AppleTTSEngineBoundary` wrapping platform engines | Uses native system APIs (`AVSpeechSynthesizer` / `NSSpeechSynthesizer`). |
| `ElevenLabsVoiceProvider` | `ElevenLabsEngine` | Performs HTTPS requests to ElevenLabs API using stored API keys. |

### Platform Example: Apple Engines

The Apple provider demonstrates how a single boundary adapter can coordinate multiple platform engines:

```swift
#if os(iOS) || targetEnvironment(macCatalyst)
let engine = AppleTTSEngineBoundary(underlying: AVSpeechTTSEngine())
#elseif os(macOS)
let engine = AppleTTSEngineBoundary(underlying: NSSpeechTTSEngine())
#endif
```

* `AVSpeechTTSEngine` targets iOS and Mac Catalyst via UIKit/AVFoundation APIs.
* `NSSpeechTTSEngine` targets macOS via AppKit's `NSSpeechSynthesizer`.

When creating new engines, follow this pattern: keep the boundary type platform-agnostic and inject the appropriate implementation at initialization time.

## Adding a New Engine

1. **Define Configuration** – create a `struct` that captures any credentials or options required by your engine.
2. **Implement `VoiceEngine`** – conform to the protocol, translating between your service/native SDK and `VoiceEngineRequest`/`VoiceEngineOutput`.
3. **Update Provider** – inject your engine into a `VoiceProvider` implementation. Retrieve configuration data (Keychain, environment, etc.) and pass it into engine calls.
4. **Document Usage** – extend provider documentation to explain new configuration fields and options.

## Testing Guidance

* Prefer dependency injection for network sessions or file handles inside engines to simplify testing.
* Mock engines by creating lightweight `VoiceEngine` conformers that return fixture data.
* Add coverage for error translation in providers to ensure engine failures surface meaningful messages.

By following the Engine Boundary Protocol, SwiftHablare can integrate new voice synthesis systems—including LLM-backed or cross-language engines—without modifying the higher-level provider or UI infrastructure.
