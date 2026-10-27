# SwiftHablaré Usage Guide

The day-to-day tasks for integrating or extending SwiftHablaré. See [README.md](README.md) for
the plugin model and [MIGRATION-7.0.md](MIGRATION-7.0.md) for 6.x code.

## 1. Package integration

1. Add the package to `Package.swift` and `SwiftHablare` to the targets that need speech.
   Add `SwiftHablareTesting` to test targets only.
2. Target iOS 26+ or macOS 26+ with Swift 6.2+.
3. Link SwiftData in the host target if you save results as `TypedDataStorage`.

## 2. Registry and service

```swift
import SwiftHablare

let registry = PluginRegistry.default            // ApplePlugin included
// await registry.register(MyPlugin.self)        // add companion plugin types at launch
let service = GenerationService(registry: registry)
```

`PluginRegistry` is an actor: it caches one plugin instance per plugin and configuration, and
persists each plugin's enabled state (`isEnabled(pluginId:)`, `setEnabled(_:for:)`).

## 3. Generate audio

```swift
let voice = VoiceReference.catalog(pluginId: "apple", voiceId: voiceId)

// Text in, one normalised GeneratedAudio out
let result = try await service.generate(text: "Hello", voice: voice, languageCode: "en") { progress in
  print(progress.fractionCompleted)
}

// From a GuionElementModel (SwiftCompartido)
let elementResult = try await service.generate(forElement: element, voice: voice)

// Save to SwiftData on the main actor
await MainActor.run {
  modelContext.insert(result.toTypedDataStorage())
  try? modelContext.save()
}
```

For lists, conform your items to `SpeakableItem`, collect them in a `SpeakableItemList`, and call
`service.generateList(_:to:saveInterval:pluginId:progress:)`.

## 4. Voices

```swift
let voices = try await service.fetchVoices(from: "apple", languageCode: "en")
let all = try await service.fetchAllVoices()
let available = await service.isVoiceAvailable(voiceId, from: "apple")
```

A voice is a `VoiceReference`: `.catalog(pluginId:voiceId:)` or `.asset(URL)` for a `.vox` voice
asset (then pass `pluginId` so the service knows which plugin synthesizes it).

## 5. Credentials

Keys come from the environment first, then the Keychain (`APIKeyStoring`, `ChainedAPIKeyStore`).
Read a key with `apiKey(for:)`, store one with `setAPIKey(_:for:)`, and check its origin with
`keySource(for:)`. Ask a plugin whether it can run with `await plugin.status()`.

## 6. Errors

Plugin and generation errors are `HablareError`. Branch on its `category` (`transient`,
`permanent`, `permanentUntilDownloaded`, `cancelled`) to decide whether to retry or fall back.

## 7. Testing

Use `SwiftHablareTesting`: `FakeSynthesizerPlugin`, `FakeDesignerPlugin`, `FakeCloudPlugin`,
`InMemoryAPIKeyStore`, and `ConformanceKit` for plugin authors. Run `make test`; never
`swift test`.
