# SwiftHablaré Usage Guide

This guide summarizes the day-to-day tasks most automations perform when integrating or extending SwiftHablaré. It condenses the key workflows so AI agents can operate with minimal context switching.

## 1. Package Integration Checklist

1. Add the package to the `dependencies` array in your `Package.swift`:
   ```swift
   .package(url: "https://github.com/intrusive-memory/SwiftHablare", from: "1.0.0")
   ```
2. Add `SwiftHablare` to the target dependencies that need text-to-speech features.
3. Ensure the host app targets iOS 26+ or macOS 26+ and uses Swift 6.0 or newer with Xcode 15+.
4. Link SwiftData in the host target (SwiftHablaré persists data through it).
5. On iOS, entitle the app for microphone/speaker usage when playing audio.

## 2. Bootstrapping the Manager

```swift
import SwiftData
import SwiftHablare

let container = try ModelContainer(for: AudioFile.self, VoiceModel.self)
let manager = VoiceProviderManager(modelContext: container.mainContext)
```

The manager auto-registers the built-in providers (`ElevenLabsVoiceProvider` and `AppleVoiceProvider`) and restores the last-selected provider from `UserDefaults`.

### Switching Providers

```swift
manager.switchProvider(to: .apple)
manager.switchProvider(to: .elevenlabs)
```

The helper `isCurrentProviderConfigured()` returns `true` when prerequisites (for example, an API key) are satisfied.

## 3. Managing Voices

```swift
let cachedVoices = try await manager.getVoices()
let freshVoices = try await manager.getVoices(forceRefresh: true)
```

Voice metadata is cached in SwiftData (`VoiceModel`). Refresh only when provider-side changes are expected.

To inspect or work with a provider directly:

```swift
if let provider = manager.getProvider(for: "elevenlabs"), await provider.isVoiceAvailable(voiceId: "voice-id") {
    let voices = try await provider.fetchVoices()
}
```

## 4. Generating Audio

### Cached Generation

```swift
let audio = try await manager.generateAndCacheAudio(
    text: "Hello World",
    voiceId: "voice-id",
    providerId: "elevenlabs",
    audioFormat: "mp3"
)
```

This method reuses cached audio if the same `(text, voiceId, providerId)` triple already exists, otherwise it stores the new result in SwiftData (`AudioFile`).

### Direct Generation

```swift
let rawData = try await manager.generateAudio(text: "Hello", voiceId: "voice-id")
```

Use this when you do not need persistence.

### Persisting to Disk

```swift
let outputURL = URL(fileURLWithPath: "/tmp/output.mp3")
try manager.writeAudioFile(audio, to: outputURL)
```

## 5. API Key Management

`KeychainManager.shared` stores sensitive provider credentials. Typical usage:

```swift
try KeychainManager.shared.saveAPIKey("your-api-key", for: "elevenlabs-api-key")
let key = try KeychainManager.shared.getAPIKey(for: "elevenlabs-api-key")
let isConfigured = KeychainManager.shared.hasAPIKey(for: "elevenlabs-api-key")
try KeychainManager.shared.deleteAPIKey(for: "elevenlabs-api-key")
```

## 6. SwiftUI Widgets Snapshot

SwiftHablaré ships SwiftUI helper views designed for iOS 26+ and macOS apps. They bind directly to `VoiceProviderManager` and the SwiftData models:

- `VoiceProviderWidget` – Picker for switching providers and showing provider status.
- `VoiceSettingsWidget` – Composite control for configuring providers and selecting voices.
- `VoicePickerWidget` – Standalone voice picker that supports searching, filtering, and previews.

Inspect the files under `Sources/SwiftHablare/UI/` for customizable sections. Automated agents can reuse these components in host apps without re-implementing the UI logic.

## 7. Common Automation Tasks

| Task | Call Sequence |
| --- | --- |
| Ensure provider credentials exist | `KeychainManager.shared.hasAPIKey` → `saveAPIKey` if missing |
| Refresh cached voice list | `await manager.getVoices(forceRefresh: true)` |
| Generate & persist audio | `await manager.generateAndCacheAudio` → `writeAudioFile` |
| Switch default provider | `manager.switchProvider(to:)` |
| Enumerate providers | `manager.getAvailableProviders()` |

Refer to [`API.md`](API.md) for type-level details when implementing new providers or extending the data models.
