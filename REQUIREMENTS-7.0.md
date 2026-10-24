---
type: requirements
state: draft
created: 2026-10-23
---

# SwiftHablare 7.0 — Pluggable voice architecture

## Purpose

Turn SwiftHablare into a **plugin host** for speech engines: local, cloud, and hybrid. Every
engine is a plugin package that depends on SwiftHablare core. Core never depends on a plugin.
7.0 is a deliberate **breaking** release.

Two concrete targets drive the design. 7.0 must make both possible without further core changes:

1. **Gemini** (cloud): Gemini API TTS, `gemini-3.8-flash-tts` / `gemini-3.8-flash-lite-tts`.
   It synthesizes speech and designs voices from a text prompt (`type: "prompted"`). The HTTP work
   for both, voice design included, lives in the **Gemini client library, SwiftGemelos**. The Hablare plugin only
   adapts it to core's types. Voice cloning (`type: "replicated"`) is **out of scope**.
2. **Gemini/Chatterbox hybrid** (not yet built in Swift). Gemini **designs** each character's voice
   and its sample is stored in the character's `.vox`. Chatterbox then **synthesizes locally**
   (MLX), cloning zero-shot from ≤10 s of that sample. A working Python prototype lives at
   `podcasts/granville/gemini-chatterbox-hybrid` (`src/gch/render.py`). It is the behavioral
   reference for the requirements marked **[hybrid]** below.

Existing engines must port onto the same contract: `AppleVoiceProvider` (built in), SwiftVoxAlta
(local Qwen3-TTS), and SwiftHablareOnce (ElevenLabs).

## Consumers

| Consumer | How it uses Hablare | What it needs from 7.0 |
|---|---|---|
| **Escribir** (`apps/Escribir`, macOS + iOS editor) | Read-aloud: paragraph playback in a chosen voice (planned for the next minor after 1.2.0; spec drafted as `docs/REQUIREMENTS-1.2.0.md`, to be retitled, because 1.2.0 shipped other work as rc1–rc9). Voice **choice** for a cast. Later, submits screenplays to Produciesta's queue with the user's chosen provider (**macOS only**; iOS is read-aloud only) | Voice listing and preview synthesis. A host-drawn Settings pane, which needs credential and settings **metadata** rather than provider SwiftUI. Content-addressed caching (`renderIdentity` ← R8). Honest progress (R2). Keys entered here must reach Produciesta's queue (R6) |
| **Produciesta** (queue manager LaunchAgent + CLI, macOS) | Headless rendering of whole screenplays | Everything in R1–R11. No UI |

Escribir is the **only place a user configures providers and keys**. Produciesta renders with
whatever the user chose there. That drives R6's shared Keychain group and R12's metadata-not-views rule.

## What the prototype taught us (requirements, not trivia)

| Observation in `gemini-chatterbox-hybrid` | Requirement it creates |
|---|---|
| Voice **creation** (Gemini, cloud) and **synthesis** (Chatterbox, local) are different engines joined by a `.vox` | Separate designer and synthesizer roles. Voices are portable assets (R2, R3) |
| Gemini rejects prompts that describe a minor; TOBY falls back to the `.vox`'s Qwen3 sample | Typed `safetyBlocked` error; a voice asset exposes every usable source (R3, R10) |
| A prompt with no age or gender returned `500 INTERNAL` | Errors split into transient and permanent; the prompt actually sent is recorded (R3, R10) |
| Chatterbox has no instruct input, so parentheticals are lost | Capabilities are explicit; consumers can tell when direction will be dropped (R4) |
| Per-speaker `exaggeration`, `cfg_weight`, `temperature`, `seed`, `ref_start`, `max_pause` | Typed, persisted, per-voice engine settings validated by the plugin (R5) |
| ≤10 s reference window cut on a pause; `ref_start` picks a brisker stretch | Reference-audio preparation belongs to the synthesizer plugin, driven by settings (R5) |
| 280-char chunking; plausibility check plus retries for runaway or truncated takes | Synthesizers declare input limits; core ships a chunker and a take validator (R7) |
| Per-chunk take cache, so re-runs regenerate only what changed | Synthesizers provide a deterministic cache key (R8) |
| An MLX model is loaded once per run; VoxAlta also holds MLX models | Residency shared across MLX audio engines, in mlx-audio-swift rather than core (R9) |
| `GEMINI_API_KEY` scraped from Vinetas's Keychain item by hand | Env → Keychain credential chain in core, same names as Vinetas (R6) |
| A Gemini `voice_id` is project-scoped and expires after a year unused, but the stored sample keeps working offline | An asset can be valid for one consumer (sample) and stale for another (server id). Freshness is reported per source (R3) |

## Architecture

```
SwiftHablare (core, no UI: SwiftUI removed in 7.0)
├─ Plugin contract: HablarePlugin, PluginContext
├─ Roles: VoiceSynthesizer, VoiceDesigner
│         (VoiceConverter, reserved)
├─ PluginRegistry (instances cached)
├─ Voices: VoiceReference, VoiceAsset (.vox via VoxFormat), VoiceSettings
├─ Audio: AudioFormat, GeneratedAudio, AudioNormalizer
├─ Text: TextChunker, TakeValidator
├─ Credentials: APIKeyStoring chain (env → Keychain)
├─ Local models: SwiftAcervo status only (memory residency lives in mlx-audio-swift)
├─ Errors: HablareError
└─ AppleVoiceProvider (built-in local plugin)

SwiftHablareTesting (product): fakes, InMemoryAPIKeyStore, conformance test kit

Plugins ── depend on core, never the reverse
├─ SwiftVoxAlta            local   synth + design (Qwen3-TTS 1.7B / 0.6B)
├─ SwiftHablareOnce        cloud   synth + design (ElevenLabs)
├─ SwiftHablareGemelos     cloud   synth + design (adapts SwiftGemelos)
├─ SwiftCotorra            local   synth (Chatterbox, zero-shot from reference audio)  ← new engine
└─ gemini-chatterbox       hybrid  = Gemelos designer + Cotorra synthesizer   ← composition, declared in Produciesta
```

## Requirements

### R1 — Plugin contract and registry

```swift
public enum PluginKind: Sendable { case local, cloud, hybrid }

public protocol HablarePlugin: Sendable {
  static var id: String { get }                     // "voxalta", "elevenlabs", "google", "chatterbox", "gemini-chatterbox"
  static var displayName: String { get }
  static var kind: PluginKind { get }
  static var credentials: [CredentialRequirement] { get }   // empty for local
  static var models: [ModelDescriptor] { get }
  static var settingsSchema: SettingsSchema { get }         // per-voice + per-plugin settings (R5)
  init(context: PluginContext) async throws

  var synthesizer: (any VoiceSynthesizer)? { get }
  var designer: (any VoiceDesigner)? { get }
  func status() async -> PluginStatus   // .ready | .needsCredential(envVar:) | .needsModel([ModelDescriptor]) | .unavailable(reason)
}

public struct PluginContext: Sendable {
  public let keys: any APIKeyStoring
  public let configuration: PluginConfiguration    // host-supplied, plugin-typed (e.g. VoxAlta model size)
  public let registry: PluginRegistry               // lets a hybrid resolve its component plugins
}
```

- Plugins are **compile-time packages**: the host links them and calls
  `PluginRegistry.register(MyPlugin.self)` at launch. There is no dynamic loading, which iOS
  forbids anyway.
- `PluginRegistry` is an actor. It holds **one instance per `(pluginId, configuration)`** and keeps it
  alive, so loaded voices and models persist between calls. (6.x rebuilt a provider on every
  `configuredProvider(for:)`.) Enablement persists as in 6.x.
- `ModelDescriptor`: `id`, `displayName`, `kind` (local/cloud), `languages`, `capabilities`, and, for
  local models, `approximateBytes` and `minimumMemoryBytes`.
- Only `AppleVoiceProvider` is registered by default.

### R2 — Roles

A plugin provides any subset of these roles. A hybrid gets its roles from other plugins.

```swift
public protocol VoiceSynthesizer: Sendable {
  var capabilities: SynthesisCapabilities { get }      // .instruct, .streaming, .multiSpeaker, .seed, .onDevice
  var limits: SynthesisLimits { get }                  // maxCharacters | maxTokens | maxBytes; maxReferenceSeconds
  var nativeFormats: [AudioFormat] { get }
  var maxConcurrentRequests: Int { get }               // local = 1, cloud from plugin config
  func readiness(for voice: VoiceReference) async -> VoiceReadiness   // .ready | .needsPreparation | .unsupported(reason)
  func prepare(_ voice: VoiceReference) async throws   // load .vox embeddings, cut reference clip, warm model
  func release(_ voice: VoiceReference) async
  func synthesize(_ request: SpeechRequest) async throws -> GeneratedAudio
  func cacheKey(for request: SpeechRequest) -> String?                 // R8
  func estimateCost(_ request: SpeechRequest) -> CostEstimate?         // cloud only
}

/// Honest progress. A fraction appears only when the engine truly knows it.
public enum SynthesisProgress: Sendable {
  case started
  case tokens(generated: Int, expected: Int?)   // expected only when the engine knows it
  case audio(seconds: TimeInterval)             // streamed audio so far
  case finished
}
// `synthesize(_:progress:)` overload with an `@Sendable (SynthesisProgress) -> Void` callback,
// defaulting to `.started` / `.finished`. Escribir's voice spec §2.2 ships an *indeterminate* ring and
// defers a determinate one until Hablare exposes progress (its l.240, l.657); this unblocks it.
// Hosts must not invent a fraction when `expected` is nil.

public protocol StreamingVoiceSynthesizer: VoiceSynthesizer {
  func stream(_ request: SpeechRequest) -> AsyncThrowingStream<AudioChunk, Error>
}

public protocol VoiceDesigner: Sendable {
  /// Creates voice candidates from a description and a line to speak.
  func design(_ request: VoiceDesignRequest) async throws -> [VoiceCandidate]
  /// Persists the chosen candidate. Writes this engine's extension and sample into the .vox.
  func save(_ candidate: VoiceCandidate, into asset: inout VoiceAsset) async throws
  func delete(_ voice: VoiceReference) async throws      // server-side cleanup (Gemini has no PATCH)
}

```

- `VoiceConverter` (audio → audio, for speech-to-speech) is **reserved**: declared but not required
  in 7.0, so that a future voice-conversion engine is additive.
- **No cloning role in 7.0.** Cloning from a user's recording (Gemini `replicated`, consent-gated) is
  out of scope. It can be added later as a new role without breaking anything. The hybrid's
  Chatterbox step conditions on a *designed* sample. That is synthesizer-internal reference
  conditioning (R3, R5), not a cloning role.
- `VoiceDesignRequest` carries `description`, `sampleText`, `language`, and `gender`/`age` hints.
  `VoiceCandidate` carries a preview `GeneratedAudio`, an opaque engine handle, and the **prompt
  actually sent** (the prototype rewrote NARRATOR's prompt; the rewrite must be recorded, not lost).

### R3 — Voices are portable assets

```swift
public enum VoiceReference: Sendable, Hashable {
  case catalog(pluginId: String, voiceId: String)   // a built-in or server voice id
  case asset(URL)                                    // a .vox file
}

public struct VoiceAsset: Sendable {                 // wraps VoxFormat.VoxFile
  public var sources: [VoiceSource]                  // everything usable in this .vox
}

public struct VoiceSource: Sendable {
  public let engine: String            // "google", "qwen3-tts", "elevenlabs"
  public let model: String?            // "gemini-3.8-flash-tts", "1.7b"
  public let kind: Kind                // .serverHandle, .embedding, .referenceAudio
  public let freshness: Freshness      // .current | .expiresAt(Date) | .stale(reason)
}
```

- Core depends on **vox-format** (`VoxFormat`, ≥ 0.4.1) and is the single reader and writer of
  `.vox` for every plugin. Plugins read and write only their own namespace: `embeddings/<engine>/…`
  and `manifest.extensions.<engine>`.
- The Google layout must match vox-python's `providers/gemini.py` byte-for-byte:
  `manifest.extensions.google` and `embeddings/google/gemini-3.8-flash-tts/sample-audio.wav`.
  This keeps the Python tools and Swift interoperable.
- **[hybrid]** A synthesizer declares which sources it consumes, as an ordered preference.
  Chatterbox: `referenceAudio` from `google` → `qwen3-tts` → any. `readiness(for:)` reports which
  source it will use, so a consumer can warn (the prototype printed "TOBY has no Gemini voice;
  using its qwen3 sample").
- Server-handle freshness (Gemini's one-year expiry) never blocks a synthesizer that uses the
  sample instead.

### R4 — Requests, responses, capabilities

```swift
public struct SpeechRequest: Sendable {
  public var text: String
  public var voice: VoiceReference
  public var languageCode: String?
  public var instruct: String?             // dropped, and reported, when not .instruct
  public var settings: VoiceSettings       // R5
  public var preferredFormat: AudioFormat?
  public var seed: UInt64?
}

public struct GeneratedAudio: Sendable {
  public var data: Data
  public var format: AudioFormat           // the truth, which may differ from preferredFormat
  public var duration: TimeInterval
  public var droppedInstruct: Bool
  public var sourceUsed: VoiceSource?      // which .vox source conditioned this take
}

public struct AudioFormat: Sendable, Hashable {
  public enum Container: String, Sendable { case wav, aiff, mp3, pcm, opus }
  public var container: Container; public var sampleRate: Int; public var channels: Int; public var bitDepth: Int?
  public static let pcm24kMono16: AudioFormat   // Produciesta pipeline format; Gemini 3.8 and Chatterbox are native 24 kHz
}
```

- `AudioNormalizer` (core, AVAudioConverter): converts any `GeneratedAudio` to a target format,
  with silence trim and an internal-pause cap (the prototype's `_trim` / `_cap_pauses`). Consumers
  get one implementation instead of one each.

### R5 — Typed, persisted voice settings

- `SettingsSchema` declares each key's type, range, default, scope (`perVoice` / `perPlugin`), and
  display metadata (`label`, `help`, `step`), so a host can draw the control (R12).
  `VoiceSettings` is a validated `[String: SettingValue]`. Unknown keys are rejected with the
  offending key named.
- **[hybrid]** The Chatterbox schema covers `exaggeration` (0–2, default 0.5), `cfg_weight` (0–1, 0.5),
  `temperature` (0.8), `seed`, `ref_start` (seconds), and `max_pause` (seconds). These are the
  prototype's knobs.
- Settings are stored with the cast (CAST.md, per character, per plugin). This is the consumer's
  choice. Core only provides `Codable` round-tripping.

### R6 — Credentials (environment first, Keychain fallback)

Copy the SwiftVinetas pattern (`SwiftVinetas/Sources/SwiftVinetas/Cloud/CloudAPIKeyStore.swift`),
keyed by `pluginId` instead of an enum:

- `APIKeyStoring`: `apiKey(for:)`, `setAPIKey`, `removeAPIKey`, `keySource(for:)`.
- `EnvironmentAPIKeyStore` (read-only), `KeychainAPIKeyStore`, `InMemoryAPIKeyStore` (testing product).
- `ChainedAPIKeyStore.default = [Environment, Keychain]`. **Environment wins.**
- `CredentialRequirement`: `primaryEnvironmentVariable`, `aliases`, `keychainAccount`,
  `displayName` ("ElevenLabs API key"), `placeholder` ("sk_…"), `helpURL` (where to get a key).
  This is enough for a host to draw its own credential field with no provider UI. The host writes
  the key through `APIKeyStoring` and never stores it itself. This preserves Escribir's
  decision D-6, "Escribir never touches an API key": the key goes straight to Hablare's store.
  - `elevenlabs`: `ELEVENLABS_API_KEY`
  - `google`: `GEMINI_API_KEY`, alias `GOOGLE_API_KEY` (same as Vinetas, so one key serves both apps)
- A hybrid declares the **union** of its components' requirements. `gemini-chatterbox` needs
  `GEMINI_API_KEY` only to *design* voices. Synthesis from an existing sample needs no key, and
  `status()` must say so rather than reporting `.needsCredential`.
- Keys never appear in errors, logs, `description`, or `keySource` output.
- The Keychain is required, not optional. Processes that launchd starts don't inherit shell
  environment: GUI apps opened from Finder or the Dock, and **per-user LaunchAgents registered with
  `SMAppService`**, which is how Produciesta's queue manager runs generation. iOS has no user
  environment at all. Environment variables cover CLIs, CI, and agent skills.
- `KeychainAPIKeyStore` takes a `service` and an optional `accessGroup`.
- **Cross-app sharing:** core defines `KeychainAPIKeyStore.intrusiveMemoryVoices`, service
  `io.intrusive-memory.hablare.apiKeys` in access group `H3EJ6Y8VJ6.io.intrusive-memory.hablare`.
  A key entered once in Escribir's Settings is then readable by Produciesta.app,
  `produciesta-queuectl`, and the queue's LaunchAgents. Each of those targets carries the
  `keychain-access-groups` entitlement.
  - On iOS the group still applies within the team's apps on the device, but iOS keys serve only
    Escribir's own read-aloud. **Produciesta integration is macOS-only** (decided 2026-10-23).
  - Vinetas's existing group (`…Vinetas.shared`) stays separate. Unifying image and voice keys is a
    later decision. Until then, a user with both apps enters `GEMINI_API_KEY` twice in the GUI.
    Environment-variable users are unaffected.

### R7 — Text limits, chunking, take validation

- `SynthesisLimits` per synthesizer:
  - Chatterbox: ~280 characters
  - Gemini: 8,192 input tokens (not in Google's TTS docs; confirm with a live call)
  - ElevenLabs: per-model character limit
- `TextChunker` (core) splits on sentence boundaries to fit `limits`.
- `TakeValidator` (core): a characters-per-second plausibility window (the prototype uses
  0.3×–2.2× of 14 chars/s, +1.5 s). A failed take is retried up to N times with a new seed, and the
  result is flagged `suspect` if it still fails. The policy is configurable. Retries go through the
  synthesizer, so cloud plugins count them against rate limits.

### R8 — Determinism and caching

- `cacheKey(for:)` covers plugin id, model id, voice-source fingerprint (a hash of the reference
  clip actually used), the full validated settings, seed, text, and format.
- It returns `nil` when output is not reproducible, i.e. the engine has no seed support.
- Core does not own the cache. Consumers like Produciesta do.

### R9 — Local models: SwiftAcervo for files, mlx-audio-swift for memory

- **SwiftAcervo is the model interface** for discovery, download, verification, and the on-disk
  cache. Core depends on SwiftAcervo. Its library target imports only Foundation, CryptoKit, OSLog and
  Security, but the package also declares swift-argument-parser and Progress.swift for its `acervo`
  CLI. SPM resolves those but Hablare never links them.
- A local `ModelDescriptor` carries its Acervo model id. `PluginStatus.needsModel` and the UI's
  download progress come straight from SwiftAcervo's availability and download APIs. Plugins
  **must not** implement their own downloaders or caches.
- **Core has no residency coordinator and never links MLX.** In-memory residency belongs to the
  MLX layer that every local audio engine already shares: **mlx-audio-swift `MLXAudioCore`**
  (see Downstream). Core's only residency hooks are `VoiceSynthesizer.prepare` and `release`, plus
  `PluginStatus`.

### R10 — Errors

`HablareError` with a stable category on every case:

| Case | Category | Example |
|---|---|---|
| `missingCredential(pluginId, environmentVariable)` | permanent | No `GEMINI_API_KEY` |
| `safetyBlocked(reason)` | permanent | Gemini refusing a child-voice prompt |
| `invalidRequest(detail)` | permanent | Unknown settings key |
| `unsupportedVoice(VoiceReference, reason)` | permanent | Chatterbox given a `.vox` with no audio |
| `modelNotAvailable(ModelDescriptor)` | permanent until downloaded | — |
| `rateLimited(retryAfter)`, `quotaExceeded` | transient / permanent | — |
| `transient(underlying)` | transient | Gemini `500 INTERNAL` |
| `cancelled` | — | Task cancellation, checked between chunks and takes |

Consumers decide fallback (e.g. the TOBY → Qwen3 sample case) from the category. Core never
silently substitutes a voice.

### R11 — Hybrid composition

```swift
public struct CompositePlugin<Designer: HablarePlugin, Synthesizer: HablarePlugin>: HablarePlugin
```

- `gemini-chatterbox` is declared as a composite: `id`, `designer` from `google`, `synthesizer` from
  `chatterbox`. It has no engine code of its own. Kind is `.hybrid`. Credentials are the union (R6).
  Models are the synthesizer's local models.
- The composite resolves its components through `PluginContext.registry`. Both component plugins
  must be linked and registered, and `status()` names whichever one is missing.
- Any designer can pair with any synthesizer whose consumed sources (R3) include what the designer
  produces. Example: VoxAlta-designed voices synthesized by Chatterbox. The registry validates the
  pairing at registration.

### R12 — Package structure: no UI in 7.0

- Products: `SwiftHablare` (core) and `SwiftHablareTesting`. **There is no `SwiftHablareUI`.**
- Remove all SwiftUI from the package: `GenerateAudioButton`, `GenerateGroupButton`,
  `ProviderPickerView`, `VoicePickerView`, `VoiceDownloadHelper`, the UI examples, and
  `makeConfigurationView` / `configurationPanel` on providers and descriptors.
- **Why (decided 2026-10-23):**
  - Produciesta's GUI is a queue manager, and generation runs headless.
  - Escribir, the one app with voice settings, draws its own Settings pane in its own design. Its
    voice spec already rejects Hablare's `GenerateAudioButton` for faking progress.
  - So hosts render from **metadata**: `CredentialRequirement` (R6), `SettingsSchema` (R5),
    `ModelDescriptor` plus SwiftAcervo download state (R9), `PluginStatus`, and
    `APIKeyStoring.keySource`. Plugins ship no views.
- `apps/produciesta-old`, the only user of the 6.x UI, stays pinned to 6.x.
- A UI product can come back in a later minor release if a real consumer appears. Nothing in core
  may assume it won't.
- `GenerationService`, `SpeakableItem`/`SpeakableGroup`, and `VoiceURI` port to the new types.
  `VoiceURI` gains `.asset` and keeps the `<plugin>://<voiceId>?lang=` string form.

### R13 — Testing

- `SwiftHablareTesting` ships fake plugins for each role, `InMemoryAPIKeyStore`, and a
  **conformance kit**. Every plugin runs it in its own tests: readiness/prepare/synthesize
  round-trip, format truthfulness, cache-key stability, cancellation, error categories, and that no
  key appears in errors or logs.
- Core tests need no network, no MLX, and no keys. Cloud and model tests in plugins skip-gate on
  GitHub runners (see the Acervo CI memory: hosted runners have no MLX).

## Removed in 7.0 (migration guide required)

`VoiceProvider` as the single type → `HablarePlugin` + roles. Also removed:
- `generateAudio(text:voiceId:languageCode:) -> Data`
- `generateProcessedAudio` / `ProcessedAudio`
- `mimeType`, `estimateDuration`, `requiresAPIKey`
- `VoiceProviderDescriptor` / `RegisteredVoiceProvider` → `HablarePlugin` static metadata + `PluginStatus`
- `KeychainManager` → `APIKeyStoring`
- All SwiftUI views and `makeConfigurationView` / `configurationPanel` → removed (no replacement in 7.0)

`MIGRATION-7.0.md` maps each removed symbol to its replacement.

## Downstream work (separate repos, not part of this release)

| Package | Change | Notes |
|---|---|---|
| SwiftVoxAlta | Plugin: synth (`.instruct`, `.onDevice`) + design; residency via the MLXAudioCore model host (R9); model size via `PluginConfiguration` | Today 1.7B is only an `init` default and the descriptor carries no model metadata. 7.0 makes the size a `PluginConfiguration` value that `models` reports |
| SwiftVoxAlta-telemetry | Port | |
| SwiftHablareOnce 0.2.0 | Plugin: synth + design; `pcm_24000` → WAV for `.pcm24kMono16`; Keychain account `elevenlabs-api-key` copied once into R6 | |
| SwiftGemelos (client) + SwiftHablareGemelos (plugin) | SwiftOnce-parity client covering speech **and voice design** (`POST /v1beta/voices` `prompted`, list, delete); the plugin is a thin adapter to `VoiceSynthesizer` + `VoiceDesigner`. No cloning | `.vox` layout per vox-python |
| **mlx-audio-swift** (re-fork, prerequisite) | **Option A, decided 2026-10-23: re-base the fork on current `Blaizzy/mlx-audio-swift` `main`** and re-apply our differences as a thin, documented layer: (1) SwiftAcervo model loading in place of swift-huggingface downloads; (2) persisted voice clone prompts (`VoiceClonePrompt`, `generateWithClonePrompt`), which existing `.vox` `clone-prompt.bin` embeddings depend on; (3) the telemetry reporter that SwiftVoxAlta uses (`Qwen3TTSModelRepo` is **not** a fork difference: it lives in SwiftVoxAlta and stays there); (4) a **shared audio model host in MLXAudioCore**, promoted from `VoxAltaModelManager` (single-slot, `checkMemory`/`validateMemory`) and `VoxAltaMemoryPolicy` (MLX cache cap, `clearCache`); (5) the fork's Qwen3 cloning fixes, if upstream doesn't already have them (reference-audio trimming, no forced repetition penalty, config dimensions). Chatterbox (Regular + Turbo) and upstream's other models come with the re-base. The fork's breath helpers, language-key accessors, and `WiredMemoryManager` are **dropped** (no external users). Offer (2) upstream as a PR | **Tokenizer conflict:** upstream uses swift-transformers, while the fork, SwiftVoxAlta, and SwiftTuberia use swift-tokenizers, and both provide a `Tokenizers` module. Resolve it in one coordinated move with SwiftTuberia (and thus Vinetas). **Qwen3 output must match current renders** in a listening check before SwiftVoxAlta adopts the re-fork |
| SwiftVoxAlta | Adopt the MLXAudioCore model host; keep a thin `VoxAltaModelManager` facade for one release | In addition to its plugin port above |
| SwiftCotorra | **Thin Hablare plugin** over mlx-audio-swift's `ChatterboxModel` (the SwiftVoxAlta pattern): `.vox` reference selection and ≤10 s clip on a pause (R3, R5), chunking/validation (R7), residency via MLXAudioCore. Models `mlx-community/Chatterbox-TTS-fp16` (multilingual, emotion) and `chatterbox-turbo-*` (English, faster), via the Acervo CDN | The engine already exists upstream. Remaining risk is port fidelity against the Python prototype |
| gemini-chatterbox | `CompositePlugin` declaration, a few dozen lines | Declared in Produciesta, its only consumer. Becomes its own package only when a second app needs it (SwiftCotorra must not depend on SwiftHablareGemelos) |
| Produciesta | Consumes R1–R11; see `apps/Produciesta/REQUIREMENTS-hablare-providers.md` | |
| **Escribir** | The voice release (voices in the paragraph well; next minor after 1.2.0, since the 1.2.0 line already shipped other work) is specified in a draft written against the **6.x** API: `VoiceProvider`, `VoiceProviderRegistry`, `generateAudio -> Data`, `makeConfigurationView`, `KeychainManager`. Build it **on 7.0**: registry → `PluginRegistry`, provider config sheet → host-drawn form from `CredentialRequirement` + `SettingsSchema`, `renderIdentity` ← `cacheKey(for:)`, model download progress from SwiftAcervo, the determinate ring its §2.2 defers, from `SynthesisProgress`. Later: provider-qualified casting in the `.guion` it submits to Produciesta's queue | Starting the voice release on 6.x means rewriting its seam within one release. See ordering below |
| apps/produciesta-old | Stays on 6.x | No port |

### Gemini API facts for SwiftGemelos (from Google's docs, 2026-10-24)

Source: <https://ai.google.dev/gemini-api/docs/speech-generation>. These have not yet been checked with a live call; the first SwiftGemelos sortie does that, using the Keychain key.

- **Models**: `gemini-3.8-flash-tts` (130+ languages) and `gemini-3.8-flash-lite-tts` (100+). Both do single and
  multi-speaker synthesis, voice design and replication. Older `gemini-3.1-flash-tts-preview` and
  `gemini-2.5-pro-preview-tts` don't do design.
- **Synthesis**: `POST /v1beta/interactions`, header `x-goog-api-key`. The body has:
  - `model`
  - `input: [{type: "user_input", content: [{type: "text", text, annotations: [{type: "speech_metadata", speaker?, style?}]}]}]`
  - `response_format: {type: "audio", mime_type?, sample_rate?}`
  - `generation_config.speech_config: [{voice}]`, or `{speakers: [{speaker, voice}]}` for multi-speaker
  - `stream?`

  The `voice` field takes a prebuilt name (30 studio voices, plus a 2,000+ Extended Voice Library), a `voice_…` id, or a
  `voicekey_…` id.
- **Output**:
  - Unary responses default to `audio/wav`: 24 kHz, mono, 16-bit LE PCM, 44-byte RIFF header. That matches `.pcm24kMono16`, so no conversion is needed.
  - Streaming defaults to headerless `audio/l16` and returns `step.delta` events. Gemelos is a `StreamingVoiceSynthesizer`.
  - Other options: `audio/mulaw` and `audio/alaw`; sample rate 24000, 16000 or 8000.
- **Voice design**: `POST /v1beta/voices` with `type: "prompted"`. Voices are listed with `GET /v1beta/voices`, filterable by `language_code`, `gender`, `pitch`, `type`, `search` and `page_size`.
- **Voice limits**:
  - Stateful `voice_…` voices are capped at **200 per project**, shared between prompted and replicated voices. They are deleted after 1 year without use, and each use resets that clock.
  - Stateless `voicekey_…` handles last 7 days.
  - So the designer must store the sample in the `.vox` (R3). It also needs `delete`, and `status()` should report when the project is near the 200 cap.
- **Multi-speaker works only with prebuilt voices**, at most 2 speakers. Custom voices are rendered one turn at a time, so for designed voices Gemelos does **not** advertise `.multiSpeaker`.
- **Not documented**:
  - The input limit. R7's 8,192 tokens is unconfirmed.
  - A `seed` parameter. Without one Gemelos lacks `.seed`, and `cacheKey` returns `nil` unless Google confirms reproducibility.
  - The `DELETE /v1beta/voices/{id}` and `GET` paths. vox-python calls both (`providers/gemini.py`).
  - The safety rule that rejects prompts describing minors. We saw it in the prototype; Google doesn't document it.

## Ordering (critical path)

```
SwiftHablare 7.0 ──► SwiftVoxAlta on 7.0 (CURRENT fork) ──► Escribir voices ──► Escribir → Produciesta queue rendering
        │                     ▲
        ├──► SwiftHablareOnce 0.2.0, SwiftGemelos/SwiftHablareGemelos   (cloud choices in Escribir)
        │
mlx-audio-swift re-fork (Option A) ──► SwiftVoxAlta adopts shared model host ──► SwiftCotorra / gemini-chatterbox
```

**SwiftVoxAlta's port to the 7.0 plugin contract does not wait for the mlx-audio-swift re-fork.**
The current fork already has everything VoxAlta uses: clone prompts, SwiftAcervo loading, and the
model enum. The re-fork is needed only for Chatterbox and the shared model host. Keeping them
apart takes the re-fork, the riskiest item, off Escribir's path. VoxAlta then adopts the re-forked
mlx-audio-swift in a later minor release, behind its own listening gate.

## Acceptance

- `make test` green on core with the conformance kit run against the fakes and `AppleVoiceProvider`.
- A test-only composite (fake designer + fake synthesizer) proves R11 end-to-end: design → save into a
  temp `.vox` → readiness reports the expected source → synthesize → `sourceUsed` matches.
- `MIGRATION-7.0.md` and the CHANGELOG are written. README and AGENTS.md describe the plugin model.
- No SwiftUI import in the `SwiftHablare` target.

## Risks

- **The mlx-audio-swift re-fork is the critical path.** Chatterbox exists upstream (T3 + S3Gen +
  HiFi-GAN, reference-audio cloning, streaming), but getting it means re-basing a fork that is
  191 commits behind. The risks are:
  - the tokenizer swap forces SwiftTuberia and Vinetas to move in step
  - Qwen3 output could regress, which every existing podcast voice depends on
  Gate on a listening comparison against current renders, and check Chatterbox output against the
  Python prototype (mlx-audio).
- **Over-design risk.** R2's designer role and R11's composition are justified by exactly one
  hybrid. That is acceptable because the prototype exists, but the reserved
  `VoiceConverter` stays declared-only until something uses it.
- **Core now depends on vox-format and SwiftAcervo.** Both are small and in-org. Their library targets add only ZIPFoundation (already in the graph via SwiftCompartido); their CLIs add swift-argument-parser and Progress.swift, which resolve but don't link. The alternative is every
  plugin parsing `.vox` itself, which is how the formats drift.
- **Gemini's Interactions API is `v1beta`.** That risk belongs to the plugin, not core.
- **Coordinated majors.** VoxAlta, HablareOnce, and telemetry must all release before Produciesta
  moves.

## Open questions

1. ~~Package names~~: resolved 2026-10-23. **SwiftGemelos** (Gemini client),
   **SwiftHablareGemelos** (plugin), **SwiftCotorra** (Chatterbox engine + plugin). The hybrid is
   declared in Produciesta.
2. ~~Where residency lives~~: resolved 2026-10-23, in mlx-audio-swift `MLXAudioCore`.
3. ~~Selective port vs. resync~~: resolved 2026-10-23, Option A (re-base the fork on upstream).
