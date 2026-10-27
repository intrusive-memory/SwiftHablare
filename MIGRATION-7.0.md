# Migrating from SwiftHablare 6.x to 7.0

SwiftHablare 7.0 is a deliberate **breaking** release. The single `VoiceProvider` protocol is
replaced by a plugin host: engines are `HablarePlugin` packages that depend on SwiftHablare
core, and core never depends on a plugin. Core has no UI, so every SwiftUI view is gone with
no replacement in 7.0.

Two library products ship from this package:

- `SwiftHablare` - the core: plugin contract, roles, registry, credentials, generation.
- `SwiftHablareTesting` - fakes, `InMemoryAPIKeyStore`, and the plugin conformance kit.
  Link it from test targets only.

## Removed symbols

| 6.x symbol | 7.0 replacement |
|---|---|
| `VoiceProvider` (protocol) | `HablarePlugin` plus the roles it exposes: `VoiceSynthesizer`, `VoiceDesigner`, and the reserved `VoiceConverter`. |
| `VoiceProvider.providerId` | `HablarePlugin.id` (static). |
| `VoiceProvider.displayName` | `HablarePlugin.displayName` (static). |
| `generateAudio(text:voiceId:languageCode:) -> Data` | `VoiceSynthesizer.synthesize(_:)` taking a `SpeechRequest` and returning `GeneratedAudio`. To chunk, validate takes and normalise, call `GenerationService.generate(_:pluginId:progress:)`. |
| `generateProcessedAudio` | `GenerationService.generate(...)`, which chunks (`TextChunker`), validates takes (`TakeValidator`) and normalises (`AudioNormalizer`) into one `GeneratedAudio` in the service's `targetFormat`. |
| `ProcessedAudio` | `GeneratedAudio` (`data`, `format`, `duration`, `droppedInstruct`, `sourceUsed`). `GenerationOutcome` adds `chunkCount`, `takes` and `suspectChunks`. |
| `mimeType` | `GeneratedAudio.format.mimeType` (`AudioFormat.mimeType`). Formats are truthful: the bytes match `format`. |
| `estimateDuration(text:voiceId:)` | `GeneratedAudio.duration` after synthesis; before synthesis, `VoiceSynthesizer.estimateCost(_:)` returns an optional `CostEstimate`. |
| `requiresAPIKey` | `HablarePlugin.credentials` (`[CredentialRequirement]`, empty for no key) and `HablarePlugin.kind` (`.local`, `.cloud`, `.hybrid`). |
| `isConfigured()` | `HablarePlugin.status()` returning `PluginStatus` (`.ready`, `.needsCredential(envVar:)`, `.needsModel(_:)`, `.unavailable(reason:)`). |
| `fetchVoices(languageCode:)` | `VoiceListing.voices(languageCode:)`, adopted by plugins that list voices. Callers use `GenerationService.fetchVoices(from:languageCode:)` and `fetchAllVoices(languageCode:)`. |
| `isVoiceAvailable(voiceId:)` | `VoiceSynthesizer.readiness(for:)` returning `VoiceReadiness`; `GenerationService.isVoiceAvailable(_:from:)` wraps it. |
| `defaultVoiceId` | None. Callers name a `VoiceReference` explicitly. |
| `VoiceProviderDescriptor` | `HablarePlugin` static metadata (`id`, `displayName`, `kind`, `credentials`, `models`, `settingsSchema`) plus `PluginStatus`. A plugin is registered by type, so there is no descriptor value. |
| `RegisteredVoiceProvider` | `PluginRegistry.registeredPluginIds`, `isEnabled(pluginId:)` and `status(of:configuration:)`. |
| `VoiceProviderRegistry` / `.shared` | `PluginRegistry` (an actor); `PluginRegistry.default` holds `ApplePlugin`. |
| `VoiceProviderRegistry.register(_:replaceExisting:)` | `PluginRegistry.register(_:)`, taking a `HablarePlugin.Type`. |
| `VoiceProviderRegistry.configuredProvider(for:)` | `PluginRegistry.plugin(id:configuration:)`, then `.synthesizer`; or `PluginRegistry.synthesizer(for:pluginId:)`. |
| `VoiceProviderRegistry.isEnabled` / `setEnabled` | `PluginRegistry.isEnabled(pluginId:)` / `setEnabled(_:for:)`. The persisted `voiceProvider.enabled.<id>` UserDefaults key is unchanged. |
| `VoiceProviderAutoRegistrar` | None. Plugins are compile-time packages; the host registers their types at launch. |
| `AppleVoiceProvider` | `ApplePlugin` (id `"apple"`). |
| `KeychainManager` | `APIKeyStoring`, with `KeychainAPIKeyStore`, `EnvironmentAPIKeyStore` and `ChainedAPIKeyStore`. `InMemoryAPIKeyStore` (in `SwiftHablareTesting`) serves tests. |
| `KeychainManager.saveAPIKey` / `getAPIKey` / `deleteAPIKey` / `hasAPIKey` | `APIKeyStoring.setAPIKey(_:for:)` / `apiKey(for:)` / `removeAPIKey(for:)` / `keySource(for:)`. These are synchronous, keyed by plugin id, and `apiKey(for:)` returns `nil` instead of throwing. |
| `makeConfigurationView(onConfigured:)` | Removed. No replacement in 7.0; the host app draws its own settings UI from `HablarePlugin.credentials` and `settingsSchema`. |
| `VoiceProviderDescriptor.configurationPanel` and `VoiceProviderRegistry.configurationPanel(for:onConfigured:)` | Removed with `makeConfigurationView`. No replacement in 7.0. |
| `GenerateAudioButton`, `GenerateGroupButton`, `ProviderPickerView`, `VoicePickerView`, `VoiceDownloadHelper` | Removed. Core links no SwiftUI. Call `GenerationService` from your own view model. |
| `AudioProcessor` | `AudioNormalizer`. |
| `GenerationService.generate(forElement:providerId:voiceId:...)` | `GenerationService.generate(forElement:voice:pluginId:voiceName:languageCode:progress:)`, taking a `VoiceReference`. |
| `Examples/Hablare` demo app | Removed. |

`VoiceProviderError` survives only as the Apple engine boundary error in
`Protocols/VoiceEngine.swift`. Errors thrown from plugin APIs are `HablareError`, each with a
stable `category` (`transient`, `permanent`, `permanentUntilDownloaded`, `cancelled`).

## Before and after

### Registration

6.x:

```swift
await VoiceProviderRegistry.shared.register(
    VoiceProviderDescriptor(
        id: "elevenlabs",
        displayName: "ElevenLabs",
        isEnabledByDefault: false,
        requiresConfiguration: true,
        makeProvider: { ElevenLabsVoiceProvider() }
    )
)
let provider = try await VoiceProviderRegistry.shared.configuredProvider(for: "elevenlabs")
```

7.0:

```swift
import SwiftHablare
import MyPluginPackage   // any plugin package; it depends on SwiftHablare, never the reverse

let registry = PluginRegistry.default          // ApplePlugin is already registered
await registry.register(MyPlugin.self)         // register the plugin type (see below)

let plugin = try await registry.plugin(id: MyPlugin.id)
switch await plugin.status() {
case .ready: break
case .needsCredential(let envVar): print("set \(envVar) or store a key")
case .needsModel(let models): print("download \(models.map(\.displayName))")
case .unavailable(let reason): print(reason)
}
```

Plugin authors replace a `VoiceProvider` conformance with a `HablarePlugin`:

```swift
public final class MyPlugin: HablarePlugin, @unchecked Sendable {
  public static let id = "my-engine"
  public static let displayName = "My Engine"
  public static let kind = PluginKind.cloud
  public static let credentials = [CredentialRequirement.elevenLabs]

  private let context: PluginContext
  private let engine: MySynthesizer          // a type conforming to VoiceSynthesizer

  public init(context: PluginContext) async throws {
    self.context = context
    self.engine = MySynthesizer(keys: context.keys)
  }

  public var synthesizer: (any VoiceSynthesizer)? { engine }

  public func status() async -> PluginStatus {
    PluginStatus.evaluate(credentials: Self.credentials, keys: context.keys, models: Self.models)
  }
}
```

### Synthesis

6.x:

```swift
let provider = try await VoiceProviderRegistry.shared.configuredProvider(for: "apple")
let processed = try await provider.generateProcessedAudio(
    text: "Hello", voiceId: voiceId, languageCode: "en")
play(processed.audioData, mimeType: processed.mimeType)
```

7.0, through the service (chunking, take validation, normalisation):

```swift
let service = GenerationService()               // PluginRegistry.default, 24 kHz mono 16-bit PCM
let voice = VoiceReference.catalog(pluginId: "apple", voiceId: voiceId)
let result = try await service.generate(text: "Hello", voice: voice, languageCode: "en")
play(result.audioData, mimeType: result.mimeType)
```

7.0, straight to the synthesizer:

```swift
let synthesizer = try await registry.synthesizer(for: voice)
let audio = try await synthesizer.synthesize(
    SpeechRequest(text: "Hello", voice: voice, languageCode: "en"))
// audio.data, audio.format, audio.duration
```

For a `SpeakableItem`, `try await item.speak(using: registry)` does the same and returns
`GeneratedAudio`.

### Credentials

6.x:

```swift
try await KeychainManager.shared.saveAPIKey(key, for: "elevenlabs-api-key")
let key = try await KeychainManager.shared.getAPIKey(for: "elevenlabs-api-key")
```

7.0 resolves a key from the environment first (`ELEVENLABS_API_KEY`, `GEMINI_API_KEY` with the
alias `GOOGLE_API_KEY`, or whatever a plugin's `CredentialRequirement` declares), then from the
shared Keychain:

```swift
let keys = ChainedAPIKeyStore.default            // EnvironmentAPIKeyStore, then Keychain
try keys.setAPIKey(key, for: "elevenlabs")       // environment is read-only; this lands in the Keychain
let found = keys.apiKey(for: "elevenlabs")       // String?, nil when absent
let origin = keys.keySource(for: "elevenlabs")   // "environment (ELEVENLABS_API_KEY)", "shared keychain", ...
```

`PluginRegistry` builds this chain for every plugin and hands it over as `PluginContext.keys`;
its `fallbackKeys` parameter replaces the Keychain tier. Tests pass an in-memory store:

```swift
import SwiftHablareTesting

let registry = PluginRegistry(
    environment: [:],
    fallbackKeys: [InMemoryAPIKeyStore(keys: ["elevenlabs": "test-key"])],
    plugins: [FakeCloudPlugin.self])
```

The Keychain account names changed: 6.x stored keys under accounts such as
`elevenlabs-api-key` with no service attribute; 7.0 uses the plugin's `keychainAccount` (`elevenlabs`, `google`) under
service `io.intrusive-memory.hablare.apiKeys`. Users re-enter a key once, or export the
environment variable.
