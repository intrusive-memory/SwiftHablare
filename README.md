---
type: doc
---

# SwiftHablare

<p align="center">
    <img src="icon.jpg" alt="SwiftHablare" width="200" />
</p>

**A plugin host for speech engines.** Turn text into spoken audio through pluggable engines: local, cloud, or hybrid. The on-device `ApplePlugin` ships built-in; every other engine is its own package that depends on SwiftHablare, never the reverse.

SwiftHablare has no UI. Core links no SwiftUI. Callers bring their own views.

Coming from 6.x? See [MIGRATION-7.0.md](MIGRATION-7.0.md).

## Products

| Product | Use it for |
|---|---|
| `SwiftHablare` | The core: plugin contract, roles, `PluginRegistry`, credentials, text chunking, take validation, audio normalisation, `GenerationService`, and the built-in `ApplePlugin`. |
| `SwiftHablareTesting` | Test support: fake plugins, `InMemoryAPIKeyStore`, and the plugin conformance kit. Link it from test targets only. |

```swift
dependencies: [
    .package(url: "https://github.com/intrusive-memory/SwiftHablare.git", from: "7.0.0"),
],
targets: [
    .target(name: "MyApp", dependencies: ["SwiftHablare"]),
    .testTarget(name: "MyAppTests", dependencies: ["SwiftHablare", "SwiftHablareTesting"]),
]
```

## Requirements

- Swift 6.2+
- iOS 26.0+ / macOS 26.0+

## The plugin model

```
SwiftHablare (core, no UI)
├─ Plugin contract: HablarePlugin, PluginContext
├─ Roles: VoiceSynthesizer, VoiceDesigner (VoiceConverter, reserved)
├─ PluginRegistry (instances cached)
├─ Voices: VoiceReference, VoiceAsset (.vox via VoxFormat), VoiceSettings
├─ Audio: AudioFormat, GeneratedAudio, AudioNormalizer
├─ Text: TextChunker, TakeValidator
├─ Credentials: APIKeyStoring chain (environment, then Keychain)
├─ Local models: SwiftAcervo status only (memory residency lives in mlx-audio-swift)
├─ Errors: HablareError
└─ ApplePlugin (built-in local plugin; the spec's `AppleVoiceProvider`, renamed in 7.0, see MIGRATION-7.0.md)

SwiftHablareTesting (product): fakes, InMemoryAPIKeyStore, conformance kit

Plugins ── depend on core, never the reverse
├─ SwiftVoxAlta         local   synth + design (Qwen3-TTS)
├─ SwiftHablareOnce     cloud   synth + design (ElevenLabs)
├─ SwiftHablareGemelos  cloud   synth + design (Gemini)
├─ SwiftCotorra         local   synth (Chatterbox)
└─ gemini-chatterbox    hybrid  = Gemelos designer + Cotorra synthesizer
```

A plugin is a `HablarePlugin`: static metadata (`id`, `displayName`, `kind`, `credentials`, `models`, `settingsSchema`), an `init(context:)`, a `status()`, and whichever roles it offers.

| Role | Property | What it does |
|---|---|---|
| `VoiceSynthesizer` | `synthesizer` | `synthesize(_:)` turns a `SpeechRequest` into `GeneratedAudio`. Also `readiness(for:)`, `prepare(_:)`, `release(_:)`, `cacheKey(for:)`, `estimateCost(_:)`. |
| `VoiceDesigner` | `designer` | `design(_:)` returns `VoiceCandidate`s from a text description; `save(_:into:)` writes one into a `VoiceAsset`. |
| `VoiceConverter` | `converter` | Reserved. |

Plugins are compile-time packages. The host links them and registers their types with a `PluginRegistry` at launch. A hybrid takes its roles from other plugins; `PluginRegistry.validatePairing(designer:synthesizer:)` checks that a designer's output is a voice source the synthesizer consumes.

`PluginStatus` reports readiness: `.ready`, `.needsCredential(envVar:)`, `.needsModel(_:)`, or `.unavailable(reason:)`.

## Quick start

```swift
import SwiftHablare

// ApplePlugin is registered in PluginRegistry.default.
let registry = PluginRegistry.default
// Add a companion plugin type if you depend on one:
// await registry.register(MyPlugin.self)

let service = GenerationService(registry: registry)
let voice = VoiceReference.catalog(pluginId: "apple", voiceId: "com.apple.voice.compact.en-US.Samantha")

let result = try await service.generate(text: "Hello, world.", voice: voice, languageCode: "en")
// result.audioData: 16-bit PCM at 24 kHz mono by default; result.mimeType, result.estimatedDuration
```

`GenerationService` chunks the text to the synthesizer's limits (`TextChunker`), validates each take (`TakeValidator`, with retries), normalises the audio (`AudioNormalizer`), and joins the chunks into one `GeneratedAudio` in its `targetFormat`.

To call a synthesizer directly:

```swift
let synthesizer = try await registry.synthesizer(for: voice)
let audio = try await synthesizer.synthesize(SpeechRequest(text: "Hello", voice: voice, languageCode: "en"))
// audio.data, audio.format (truthful: the bytes match it), audio.duration
```

Voices are named by `VoiceReference`: `.catalog(pluginId:voiceId:)` for an engine's catalog voice, or `.asset(URL)` for a portable `.vox` voice asset (`VoiceAsset`). Plugins that list voices adopt `VoiceListing`; callers use `GenerationService.fetchVoices(from:languageCode:)` and `fetchAllVoices(languageCode:)`.

### Speakable items

Conform a type to `SpeakableItem` (provide `voice` and `textToSpeak`), then:

```swift
let audio = try await item.speak(using: registry)
```

`SpeakableGroup` and `SpeakableItemList` batch items; `GenerationService.generateList(_:to:saveInterval:pluginId:progress:)` generates a list and saves each result as `TypedDataStorage` (SwiftCompartido).

## Credentials

Cloud plugins declare what they need as `CredentialRequirement`s (an environment variable, optional aliases, and a Keychain account). Keys resolve through an `APIKeyStoring` chain, **environment first, then Keychain**:

| Store | Behaviour |
|---|---|
| `EnvironmentAPIKeyStore` | Read-only. Reads the plugin's variable, such as `ELEVENLABS_API_KEY` or `GEMINI_API_KEY` (alias `GOOGLE_API_KEY`). |
| `KeychainAPIKeyStore` | Read and write. `KeychainAPIKeyStore.intrusiveMemoryVoices` is the shared, access-grouped store. |
| `ChainedAPIKeyStore` | Tries each store in order. `setAPIKey` lands in the first writable store. `ChainedAPIKeyStore.default` is environment, then Keychain. |
| `InMemoryAPIKeyStore` | In `SwiftHablareTesting`. For tests. |

`PluginRegistry` builds the chain, including every registered plugin's requirements, and passes it to each plugin as `PluginContext.keys`. `keySource(for:)` says where a key came from without revealing it; keys never appear in `status()` or in error text.

## Writing a plugin

Depend on core, implement `HablarePlugin` with the roles you offer, and register the type at launch:

```swift
import SwiftHablare

public final class MyPlugin: HablarePlugin, @unchecked Sendable {
  public static let id = "my-engine"
  public static let displayName = "My Engine"
  public static let kind = PluginKind.cloud
  public static let credentials = [CredentialRequirement.elevenLabs]

  private let context: PluginContext
  private let engine: MySynthesizer          // conforms to VoiceSynthesizer

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

Throw `HablareError` from plugin code. Each case carries a stable `category` (`transient`, `permanent`, `permanentUntilDownloaded`, `cancelled`) that callers use to decide on a fallback. Local engines declare `models` (`ModelDescriptor`); core reports their on-disk status through SwiftAcervo, and memory residency belongs to the engine.

## Conformance kit

`SwiftHablareTesting` ships `ConformanceKit`, the shared contract test every plugin package runs:

```swift
import SwiftHablareTesting
import Testing

@Test func myPluginConforms() async throws {
  let keys = InMemoryAPIKeyStore(keys: ["elevenlabs": "planted-distinctive-key"])
  let registry = PluginRegistry(environment: [:], fallbackKeys: [keys], plugins: [MyPlugin.self])
  let context = PluginContext(keys: keys, registry: registry)

  let report = await ConformanceKit.run(
    MyPlugin.self, context: context,
    voice: .catalog(pluginId: MyPlugin.id, voiceId: "some-voice"),
    mode: .hardwareFree)   // use .full locally, where models and audio exist
  #expect(report.passed, "\(report.summary)")
}
```

Checks (`ConformanceCheck`): `initialization`, `roundTrip`, `formatTruthfulness`, `cacheKeyStability`, `cancellation`, `errorCategories`, `secrecyStatus`, `secrecyErrors`. `.hardwareFree` skips the checks that synthesize, so CI can run the rest. The kit plants a key in your store and fails the plugin if that key ever shows up in `status()`, `keySource`, or an error description.

Other test support: `FakeSynthesizerPlugin`, `FakeDesignerPlugin`, and `FakeCloudPlugin` (with `FakeVoiceSynthesizer` and `FakeVoiceDesigner`) let you test host code without an engine or a network.

## Architecture rules

- **No SwiftUI in core.** `Sources/SwiftHablare` imports no SwiftUI. UI belongs to the host app.
- **Plugins depend on core, never the reverse.** Core names no plugin except the built-in `ApplePlugin`.
- Generated audio is 16-bit integer PCM unless a caller asks for another `AudioFormat`.

## Development

SwiftHablare is Makefile-first: `make help` lists the targets (`make build`, `make test`, `make lint`). Never run `swift build` or `swift test`. See [AGENTS.md](AGENTS.md) and [CONTRIBUTING.md](CONTRIBUTING.md).

## Documentation

- [MIGRATION-7.0.md](MIGRATION-7.0.md) - symbol-by-symbol mapping from 6.x, with before and after snippets
- [CHANGELOG.md](CHANGELOG.md)
- [USAGE.md](USAGE.md) and [QUICK_START.md](QUICK_START.md)
- [Tests/README.md](Tests/README.md)

## License

MIT License - see LICENSE file for details.

## Support

- **Issues**: [GitHub Issues](https://github.com/intrusive-memory/SwiftHablare/issues)
- **Discussions**: [GitHub Discussions](https://github.com/intrusive-memory/SwiftHablare/discussions)
