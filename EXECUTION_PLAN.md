---
type: execution-plan
refined: 2026-10-25
feature_name: OPERATION SOCKET CHOIR
starting_point_commit: 57c9b1d4fc947c4c92f6402ec953075c5b737a02
mission_branch: mission/socket-choir/01
iteration: 1
---

# EXECUTION_PLAN.md — SwiftHablare 7.0 (pluggable voice architecture)

## Terminology

> **Mission** — A definable, testable scope of work. Defines scope, acceptance criteria, and dependency structure.

> **Sortie** — An atomic, testable unit of work executed by a single autonomous AI agent in one dispatch. One aircraft, one mission, one return.

> **Work Unit** — A grouping of sorties (package, component, phase).

## Scope

Source: `REQUIREMENTS-7.0.md` (R1–R13, "Removed in 7.0", Acceptance). Ground truth: `RECON_REPORT.md` (CLEAR, revised 2026-10-25, hash `e784f624…`).

**In scope:** the SwiftHablare core package only. That means the `SwiftHablare` and `SwiftHablareTesting` products, the port of the built-in Apple engine and the generation service, removal of the 6.x API and all SwiftUI, and the migration docs.

**Out of scope:** everything in the spec's "Downstream work" table. Each item is its own mission in its own repo: SwiftVoxAlta, telemetry, SwiftHablareOnce, SwiftGemelos/SwiftHablareGemelos, the mlx-audio-swift re-fork, SwiftCotorra, gemini-chatterbox, Produciesta and Escribir. Recon's U-1 (live Gemini call) and U-2 (Chatterbox on the CDN) belong to those missions, not this one. Tagging and releasing is also out of scope; it happens afterwards with `/ship-swift-library` as our next major release version.

**Rules for every sortie:**
- Build and test only with `make build` / `make test` (xcodebuild). Never `swift build` or `swift test`.
- Run `make lint` before finishing; afterwards `git status --porcelain` shows only the sortie's intended files.
- "`make test` passes" means exit status 0 **and** the executed test count is ≥ the count recorded after the previous sortie (the Sortie 1 baseline to start). Sorties 16 and 17 may lower it only by the tests of deleted code, listed in their report.
- Core tests need no network, no MLX and no API keys (R13).
- No sortie may edit a dependency checkout listed in the Local Dependency Map.
- No `print(` in `Sources/`: CI greps for it (`.github/workflows/tests.yml:75`). Use OSLog.
- The 6.x API stays compiling until Sortie 16 removes it. New types live alongside it; earlier sorties do not delete old files.
- Each sortie ends with one commit on the mission branch.

## Decisions

| ID | Decision | Source |
|---|---|---|
| D-1 (was OQ-1) | `SettingValue` is an enum: `.bool(Bool)`, `.int(Int)`, `.double(Double)`, `.string(String)`, `.choice(String)`; `Codable`, `Hashable`, `Sendable`. `PluginConfiguration` is a struct wrapping a `VoiceSettings` validated against the plugin schema's `perPlugin` keys (e.g. VoxAlta model size `.choice("1.7b")`); `Hashable`. No generics or associated types on `HablarePlugin`. | Recommendation accepted 2026-10-25 |

## Work Units

| Work Unit | Directory | Sorties | Layer | Dependencies |
|-----------|-----------|---------|-------|-------------|
| WU1 Foundation | `Package.swift`, `Sources/SwiftHablare/Core`, `Credentials` | 4 (S1–S4) | 0 | none |
| WU2 Plugin host | `Sources/SwiftHablare/Plugins`, `Voices`, `Sources/SwiftHablareTesting` | 4 (S5–S8) | 1 | WU1 |
| WU3 Engine services | `Sources/SwiftHablare/Text`, `Audio`, `Plugins`, `Providers`, `Sources/SwiftHablareTesting` | 5 (S9–S13) | 2 | WU2 (S13 needs only S2) |
| WU4 Port and remove | `Sources/SwiftHablare/Protocols`, `Models`, `Generation`, `Tests`, `Examples`, docs | 4 (S14–S17) | 3 | WU3 |

---

## WU1 Foundation

### Sortie 1: Package manifest and the testing product

**Priority**: 52.5 — blocks all 16 later sorties; dependency resolution is the first risk.
**Model**: sonnet

**Entry criteria**:
- [ ] First sortie — no prerequisites.
- [ ] `RECON_REPORT.md` A-12 is CONFIRMED: core does not use VoxFormat or SwiftAcervo yet.

**Tasks**:
1. Run `make test` before editing and record the executed test count in the sortie report as the mission baseline.
2. Add `vox-format` (`from: "0.4.1"`, product `VoxFormat`) and `SwiftAcervo` (`from: "0.25.0"`, product `SwiftAcervo`) to `Package.swift` with the existing `sibling(...)` helper. Link both into the `SwiftHablare` target only.
3. Add a `SwiftHablareTesting` library target at `Sources/SwiftHablareTesting/` that depends on `SwiftHablare`, and a `SwiftHablareTesting` product. Give it one placeholder public type so it compiles; Sortie 6 replaces it.
4. Make `SwiftHablareTests` depend on `SwiftHablareTesting`.
5. A second library product makes SwiftPM drop the test action from the auto-generated `SwiftHablare` scheme (`make test` fails: "Scheme SwiftHablare is not currently configured for the test action"). Commit a shared scheme at `.swiftpm/xcode/xcshareddata/xcschemes/SwiftHablare.xcscheme` that builds the `SwiftHablare` target, runs `SwiftHablareTests`, and lists `CITests.xctestplan` (default) and `LocalAudioTests.xctestplan` as its test plans. Keep the scheme name `SwiftHablare`; do not change the `Makefile` or `.github/workflows/tests.yml`. (Renaming to `SwiftHablare-Package` was rejected: that scheme has no `CITests` plan, so CI's `-testPlan CITests` fails.)

**Exit criteria**:
- [ ] `grep -c 'sibling(' Package.swift` counts the two new `sibling(` calls for `vox-format` and `SwiftAcervo`, in addition to the existing two.
- [ ] `grep -n 'SwiftHablareTesting' Package.swift` shows a `.library` product, a `.target`, and a test-target dependency.
- [ ] The `SwiftHablare` target's dependencies list `VoxFormat` and `SwiftAcervo` only by product name, with no `ArgumentParser` or `Progress` products (recon A-15/A-16).
- [ ] `git ls-files .swiftpm/xcode/xcshareddata/xcschemes/SwiftHablare.xcscheme` lists the shared scheme, and `xcodebuild -showTestPlans -scheme SwiftHablare` lists `CITests` and `LocalAudioTests`.
- [ ] CI's exact command passes locally: `xcodebuild test -scheme SwiftHablare -destination 'platform=macOS' -testPlan CITests`.
- [ ] `make build` and `make test` pass; the report states the baseline count (219 tests, 19 suites, recorded 2026-10-26) and the new count, ≥ 219.

### Sortie 2: Errors, audio and request value types (R4, R10)

**Priority**: 49 — every later type references these.
**Model**: sonnet

**Entry criteria**:
- [ ] Sortie 1 exit criteria met.

**Tasks**:
1. `Sources/SwiftHablare/Core/HablareError.swift`: every R10 case, plus `var category: ErrorCategory` (`.transient`, `.permanent`, `.permanentUntilDownloaded`, `.cancelled`). `rateLimited` is transient; `quotaExceeded` is permanent. `description` never includes a key value.
2. `Sources/SwiftHablare/Core/AudioFormat.swift`: `AudioFormat` with `Container` (`wav, aiff, mp3, pcm, opus`) and the `pcm24kMono16` constant.
3. `Sources/SwiftHablare/Core/VoiceReference.swift`: `VoiceReference` (`.catalog(pluginId:voiceId:)`, `.asset(URL)`), `Hashable`.
4. `Sources/SwiftHablare/Core/SpeechRequest.swift`: `SpeechRequest` and `GeneratedAudio` as in R4. Declare a minimal `public struct VoiceSettings` stub at the bottom of this file; Sortie 4 moves and completes it.
5. Tests in `Tests/SwiftHablareTests/Core/`: `HablareErrorTests.swift` (one assertion per R10 case) and `AudioFormatTests.swift`.

**Exit criteria**:
- [ ] `ls Sources/SwiftHablare/Core/{HablareError,AudioFormat,VoiceReference,SpeechRequest}.swift` lists all four.
- [ ] `HablareErrorTests` asserts the category of every case in R10's table (9 cases including `quotaExceeded`).
- [ ] An `AudioFormatTests` case asserts `pcm24kMono16` is 24000 Hz, 1 channel, 16-bit, `.pcm`.
- [ ] `make build` and `make test` pass.

### Sortie 3: Credentials chain (R6)

**Priority**: 45 — blocks the plugin contract; Keychain behaviour is the riskiest foundation piece.
**Model**: sonnet

**Entry criteria**:
- [ ] Sortie 2 exit criteria met.
- [ ] Reference pattern: `SwiftVinetas/Sources/SwiftVinetas/Cloud/CloudAPIKeyStore.swift` at v0.26.0 (recon A-33: lines 17-31, 77, 204, 249, 306; `ChainedAPIKeyStore.default` at 258). Copy the pattern; do not import SwiftVinetas.

**Tasks**:
1. `Sources/SwiftHablare/Credentials/APIKeyStoring.swift`: the protocol (`apiKey(for:)`, `setAPIKey`, `removeAPIKey`, `keySource(for:)`) keyed by plugin id, and `CredentialRequirement` with every R6 field.
2. `Sources/SwiftHablare/Credentials/EnvironmentAPIKeyStore.swift` (read-only; `primaryEnvironmentVariable` then `aliases`; environment dictionary injectable, default `ProcessInfo`), `KeychainAPIKeyStore.swift` (`service`, optional `accessGroup`), `ChainedAPIKeyStore.swift` (`.default = [environment, keychain]`, environment wins).
3. `KeychainAPIKeyStore.intrusiveMemoryVoices`: service `io.intrusive-memory.hablare.apiKeys`, access group `H3EJ6Y8VJ6.io.intrusive-memory.hablare`.
4. `Sources/SwiftHablareTesting/InMemoryAPIKeyStore.swift`.
5. Tests in `Tests/SwiftHablareTests/Credentials/`. Keychain round trip uses a per-test unique `service` with `accessGroup: nil` and removes the item in teardown. Assert the `intrusiveMemoryVoices` constants by value only; the test host has no `keychain-access-groups` entitlement.

**Exit criteria**:
- [ ] `git diff --stat` shows `Security/KeychainManager.swift` untouched.
- [ ] A test puts different values for the same plugin in an injected environment and in an `InMemoryAPIKeyStore` behind it, and asserts the environment value wins.
- [ ] A test resolves `GEMINI_API_KEY` through its `GOOGLE_API_KEY` alias.
- [ ] A test asserts neither `String(describing:)` of each store nor `keySource(for:)` contains the key value.
- [ ] `make build` and `make test` pass.

### Sortie 4: Typed voice settings (R5, D-1)

**Priority**: 44 — the registry key and every plugin schema depend on it.
**Model**: sonnet

**Entry criteria**:
- [ ] Sortie 2 exit criteria met.
- [ ] D-1 (Decisions table) defines `SettingValue` and `PluginConfiguration`.

**Tasks**:
1. `Sources/SwiftHablare/Core/SettingsSchema.swift`: `SettingsSchema`, `SettingDefinition` (key, value type, range, default, scope `perVoice`/`perPlugin`, `label`, `help`, `step`), and `SettingValue` per D-1.
2. `Sources/SwiftHablare/Core/VoiceSettings.swift`: move the Sortie 2 stub here and complete it: a `[String: SettingValue]`, `Codable`, `Hashable`, with `validated(against:scope:)` that rejects unknown keys with `HablareError.invalidRequest` naming the key, rejects out-of-range values, and fills defaults.
3. `Sources/SwiftHablare/Core/PluginConfiguration.swift` per D-1, with an `.empty` value.
4. Tests in `Tests/SwiftHablareTests/Core/SettingsTests.swift` using the prototype's Chatterbox knobs as the sample schema (recon A-36): `exaggeration` 0–2 default 0.5, `cfg_weight` 0–1 default 0.5, `temperature` default 0.8, `seed`, `ref_start`, `max_pause`.

**Exit criteria**:
- [ ] A test validates `["bogus": .int(1)]` and asserts the thrown error's description contains `bogus`.
- [ ] A test validates `exaggeration = 3.0` and asserts it throws.
- [ ] A test encodes and decodes a `VoiceSettings` with JSON and asserts equality.
- [ ] A test puts two equal `PluginConfiguration`s in a `Set` and asserts a count of 1.
- [ ] `make build` and `make test` pass.

---

## WU2 Plugin host

### Sortie 5: Plugin contract and roles (R1, R2, R9 hooks)

**Priority**: 41.5 — the core design; 12 sorties build on it.
**Model**: opus

**Entry criteria**:
- [ ] Sorties 3 and 4 exit criteria met.
- [ ] SwiftAcervo availability API at v0.25.0 (recon A-17): `Acervo+Availability.swift:61` `isModelAvailable`.

**Tasks**:
1. `Sources/SwiftHablare/Plugins/HablarePlugin.swift`: `PluginKind`, `HablarePlugin`, `PluginContext` (keys, configuration, registry), `PluginStatus` (`.ready`, `.needsCredential(envVar:)`, `.needsModel([ModelDescriptor])`, `.unavailable(reason)`). `PluginContext.registry` is typed as `PluginRegistry`; declare `public actor PluginRegistry {}` in `Plugins/PluginRegistry.swift` as an empty shell that Sortie 8 fills in.
2. `ModelDescriptor` with every R1 field plus `acervoModelId: String?` (R9).
3. `Sources/SwiftHablare/Plugins/Roles.swift`: `VoiceSynthesizer`, `StreamingVoiceSynthesizer`, `VoiceDesigner`, a declared-only `VoiceConverter`, `SynthesisCapabilities` (an `OptionSet`: `.instruct`, `.streaming`, `.multiSpeaker`, `.seed`, `.onDevice`), `SynthesisLimits`, `VoiceReadiness`, `SynthesisProgress`, `AudioChunk`, `CostEstimate`, `VoiceDesignRequest`, `VoiceCandidate` (preview audio, opaque handle, `promptSent`).
4. A protocol-extension default `synthesize(_:progress:)` that reports `.started`, calls `synthesize(_:)`, then reports `.finished`.
5. `Sources/SwiftHablare/Plugins/LocalModelAvailability.swift`: maps a `ModelDescriptor`'s `acervoModelId` to available/missing via `Acervo.isModelAvailable`. No downloader.
6. Tests in `Tests/SwiftHablareTests/Plugins/ContractTests.swift`, with a minimal in-test synthesizer.

**Exit criteria**:
- [ ] `grep -rn "import MLX" Sources/SwiftHablare` returns nothing.
- [ ] A test records the default overload's progress callbacks and asserts exactly `[.started, .finished]`.
- [ ] A test asserts a descriptor with `acervoModelId: "intrusive-memory/does-not-exist"` reports missing, with no network access.
- [ ] `make build` and `make test` pass.

### Sortie 6: Fake plugins (R13 part 1)

**Priority**: 27.5 — the registry, composite and conformance-kit tests all run on these.
**Model**: sonnet

**Entry criteria**:
- [ ] Sortie 5 exit criteria met.

**Tasks**:
1. Replace the Sortie 1 placeholder. In `Sources/SwiftHablareTesting/`, add:
   - `FakeSynthesizerPlugin`: local, `.seed`, deterministic (output bytes derived from text + seed), a valid WAV header in `.pcm24kMono16`, a source preference list (`google` → `qwen3-tts` → any), and an init counter.
   - `FakeDesignerPlugin`: returns candidates with a fixed preview WAV, records `promptSent`, writes a `google` extension and sample in `save(_:into:)`, and counts calls.
   - `FakeCloudPlugin`: declares a credential, so `status()` reports `.needsCredential` when the key store is empty.
2. Each fake can be told to throw a chosen `HablareError` on its next call and to report a chosen `VoiceReadiness`.
3. Tests in `Tests/SwiftHablareTests/Testing/FakePluginTests.swift`.

**Exit criteria**:
- [ ] The three fake types are `public` in `SwiftHablareTesting` and the placeholder type is gone.
- [ ] A test synthesizes the same request twice and asserts identical `data`; a different seed gives different `data`.
- [ ] A test asserts `FakeCloudPlugin.status()` is `.needsCredential` with an empty `InMemoryAPIKeyStore` and `.ready` after a key is set.
- [ ] `make build` and `make test` pass.

### Sortie 7: Voice assets over VoxFormat (R3)

**Priority**: 27 — byte-compatibility with vox-python is the highest-risk format work.
**Model**: sonnet

**Entry criteria**:
- [ ] Sortie 5 exit criteria met.
- [ ] VoxFormat source read at tag `v0.4.1` in `/Users/stovak/Projects/vox-format/implementations/swift/Sources/VoxFormat/` (recon A-13 `VoxFile.swift:26,67,222`; A-14 `VoxManifest.swift:51`). Swift has no embedding-path builder; the vox-python reference is `engines.py:79` `embedding_path`.
- [ ] Google layout (recon A-20, A-43): `manifest.extensions.google` (keys in vox-python's order, first `voice_id`) and `embeddings/google/gemini-3.8-flash-tts/sample-audio.wav`.

**Tasks**:
1. Copy two real granville voices into the repo's existing `Fixtures/voices/`: `CLARK.vox` (has a Google sample) and `TOBY.vox` (Qwen3 samples only, the spec's fallback case) from `/Users/stovak/Projects/podcasts/granville/voices/`. Tests load them with `Fijos.getFixture("voices/CLARK.vox")` and copy them to a temp directory before any write.
2. `Sources/SwiftHablare/Voices/VoiceAsset.swift`: `VoiceAsset` wrapping `VoxFile` (open, write) and `sources: [VoiceSource]` derived from the manifest's embeddings and extensions. `VoiceSource` has `Kind` (`.serverHandle`, `.embedding`, `.referenceAudio`) and `Freshness` (`.current`, `.expiresAt(Date)`, `.stale(reason)`).
3. Namespaced write helpers: writes go only to `embeddings/<engine>/…` and `manifest.extensions.<engine>` for the calling engine; anything else throws `invalidRequest`.
4. An embedding-path builder matching vox-python's `embedding_path`.
5. Google server-handle freshness from `expire_time`; the reference-audio source is never marked stale by that expiry.
6. Tests in `Tests/SwiftHablareTests/Voices/VoiceAssetTests.swift`.

**Exit criteria**:
- [ ] A test opens `CLARK.vox` and asserts a `google` `.referenceAudio` source and a `google` `.serverHandle` source; `TOBY.vox` yields `qwen3-tts` sources and no `google` source.
- [ ] A test writes a Google sample + extension into a temp copy of `TOBY.vox`, reopens it, and asserts the entry path is `embeddings/google/gemini-3.8-flash-tts/sample-audio.wav` and `extensions.google.voice_id` is present.
- [ ] A test asserts writing to another engine's namespace throws.
- [ ] A test sets `expire_time` in the past and asserts the server handle is `.stale` while the reference audio stays `.current`.
- [ ] `make build` and `make test` pass.

### Sortie 8: PluginRegistry (R1)

**Priority**: 26 — hosts and the composite resolve every plugin through it.
**Model**: sonnet

**Entry criteria**:
- [ ] Sortie 6 exit criteria met.
- [ ] 6.x enablement persistence to copy: `Sources/SwiftHablare/VoiceProviderRegistry.swift` `isEnabled`/`setEnabled` (lines 171-185) and `enabledKey` (285-287).

**Tasks**:
1. Fill in `Sources/SwiftHablare/Plugins/PluginRegistry.swift`: `register(_ type: any HablarePlugin.Type)`, `plugin(id:configuration:)` returning **one cached instance per `(pluginId, PluginConfiguration)`**, `registeredPluginIds`, `status(of:)`, and enablement get/set persisted with the 6.x `UserDefaults` key shape (injectable `UserDefaults`; tests use `Tests/SwiftHablareTests/Support/TestUserDefaults.swift`).
2. A pairing-validation hook (`validatePairing`) that Sortie 10's composite calls at registration.
3. `PluginRegistry.default` exists and registers nothing yet; Sortie 12 adds Apple.
4. Tests in `Tests/SwiftHablareTests/Plugins/PluginRegistryTests.swift`.

**Exit criteria**:
- [ ] A test resolves the same plugin with the same configuration twice and asserts the fake's init counter is 1.
- [ ] A test resolves it with a second `PluginConfiguration` and asserts the counter is 2.
- [ ] A test sets enablement off, builds a new registry over the same `UserDefaults` suite, and asserts it reads off.
- [ ] `make build` and `make test` pass.

---

## WU3 Engine services

### Sortie 9: Text chunking, take validation, cache keys (R7, R8)

**Priority**: 26 — the composite, the conformance kit and the generation port use all three.
**Model**: sonnet

**Entry criteria**:
- [ ] Sortie 6 exit criteria met.
- [ ] Prototype reference (recon A-37): `/Users/stovak/Projects/podcasts/granville/gemini-chatterbox-hybrid/src/gch/render.py:25-26,64,85,146-148,231` at `56c5b33`. 280-char chunks; plausibility window 0.3×–2.2× of 14 chars/s, +1.5 s; 2 retries = 3 takes.

**Tasks**:
1. `Sources/SwiftHablare/Text/TextChunker.swift`: splits on sentence boundaries to fit a character limit; a sentence longer than the limit falls back to clause, then word boundaries; never splits a word.
2. `Sources/SwiftHablare/Text/TakeValidator.swift`: a configurable policy (rate, window, slack, max retries; defaults from the prototype). Retries call the synthesizer again with a new seed; after the last failure the take is returned flagged `suspect`.
3. `Sources/SwiftHablare/Core/CacheKey.swift`: SHA-256 over plugin id, model id, voice-source fingerprint, validated settings (sorted keys), seed, text and format (R8). A synthesizer without `.seed` gets `nil`.
4. Tests in `Tests/SwiftHablareTests/Text/` and `Tests/SwiftHablareTests/Core/CacheKeyTests.swift`, using the fakes.

**Exit criteria**:
- [ ] A test asserts every chunk of a 2,000-character sample is ≤ 280 characters and the chunks rejoin to the input (whitespace-normalised).
- [ ] A test makes the fake return implausibly short audio every time and asserts exactly 3 synthesize calls and `suspect == true`.
- [ ] A test changes each cache-key input, one at a time, and asserts the key changes each time; identical inputs give identical keys.
- [ ] `make build` and `make test` pass.

### Sortie 10: CompositePlugin and the hybrid acceptance test (R11)

**Priority**: 24 — proves the spec's main acceptance criterion.
**Model**: opus

**Entry criteria**:
- [ ] Sorties 7, 8 and 9 exit criteria met.

**Tasks**:
1. `Sources/SwiftHablare/Plugins/CompositePlugin.swift`: `CompositePlugin<Designer, Synthesizer>` with kind `.hybrid`, credentials = union of its components', models = the synthesizer's, components resolved through `PluginContext.registry`.
2. `status()` names a missing component. With a sample already in the `.vox`, a missing design credential does **not** make synthesis report `.needsCredential` (R6).
3. Pairing validation at registration through `validatePairing`: the designer's produced source kinds must be among the synthesizer's consumed sources, otherwise `invalidRequest`.
4. `readiness(for:)` reports the source the synthesizer will use, following its preference list (R3).
5. `Tests/SwiftHablareTests/Plugins/HybridAcceptanceTests.swift`, the spec's acceptance test: fake designer + fake synthesizer composite → design → `save(_:into:)` into a temp copy of `TOBY.vox` → readiness names `google` → synthesize → `GeneratedAudio.sourceUsed` matches.

**Exit criteria**:
- [ ] The acceptance test asserts `sourceUsed?.engine == "google"` after design and save, and `"qwen3-tts"` when synthesizing from an untouched copy of `TOBY.vox`.
- [ ] A test asserts the designer's call counter does not change across 3 synthesize calls (rendering never calls the designer; mirrors recon A-42).
- [ ] A test registers a pairing whose designer produces a source the synthesizer doesn't consume and asserts it throws.
- [ ] A test with an empty key store and a `.vox` that already has the Google sample asserts the composite's synthesis status is `.ready`, not `.needsCredential`.
- [ ] `make build` and `make test` pass.

### Sortie 11: Conformance kit (R13 part 2)

**Priority**: 23 — every downstream plugin repo runs this kit.
**Model**: sonnet

**Entry criteria**:
- [ ] Sortie 10 exit criteria met.

**Tasks**:
1. `Sources/SwiftHablareTesting/ConformanceKit.swift`: a public suite a plugin's own tests call with a plugin type, a context and a sample voice. It checks:
   - readiness → prepare → synthesize → release round trip
   - format truthfulness: `GeneratedAudio.format` matches the bytes' header for WAV
   - cache-key stability: same request, same key; `nil` exactly when `.seed` is absent
   - cancellation: a cancelled task throws `HablareError.cancelled` between chunks
   - error categories: each thrown error has a category
   - secrecy: a planted key value never appears in any thrown error's description, in `status()`, or in `keySource`
2. Run the kit against all three fakes in `Tests/SwiftHablareTests/Testing/ConformanceKitTests.swift`.
3. Add a kit mode that runs only the hardware-free checks, so CI can use it.

**Exit criteria**:
- [ ] `ConformanceKitTests` runs the kit against each of the three fakes and passes in `make test`.
- [ ] A test feeds the kit a deliberately broken fake (format lies about its sample rate) and asserts the kit reports that failure.
- [ ] `grep -rnE 'Logger|os_log' Sources | grep -iE 'apiKey|\\(key'` returns nothing.
- [ ] `make build` and `make test` pass.

### Sortie 12: Apple plugin and default registration (R1)

**Priority**: 18 — the only built-in plugin, needed by the generation port.
**Model**: sonnet

**Entry criteria**:
- [ ] Sortie 11 exit criteria met.
- [ ] Existing engine code: `Sources/SwiftHablare/Providers/AppleVoiceProvider.swift`, `Providers/Apple/` (recon A-01) and `Protocols/VoiceEngine.swift`.

**Tasks**:
1. `Sources/SwiftHablare/Providers/ApplePlugin.swift`: the Apple engine as a `HablarePlugin` with only a synthesizer role (`.onDevice`), built on the existing `AppleTTSEngine`/`AVSpeechTTSEngine`. No credentials, no models.
2. `PluginRegistry.default` registers `ApplePlugin` and nothing else.
3. Port `Tests/SwiftHablareTests/VoiceQualityFilterTests.swift` from `AppleVoiceProvider` to `ApplePlugin`.
4. Add `Tests/SwiftHablareTests/Providers/ApplePluginConformanceTests.swift` running the full conformance kit against `ApplePlugin`. Add it to `LocalAudioTests.xctestplan` and skip it in `CITests.xctestplan`; CI runs the hardware-free kit mode against `ApplePlugin` instead.

**Exit criteria**:
- [ ] A test asserts `PluginRegistry.default.registeredPluginIds` equals Apple's id alone.
- [ ] `VoiceQualityFilterTests.swift` no longer references `AppleVoiceProvider` (`grep -c AppleVoiceProvider` is 0).
- [ ] `ApplePluginConformanceTests` appears in `CITests.xctestplan`'s `skippedTests`, and both plans parse with `python3 -m json.tool`.
- [ ] `AppleVoiceProvider.swift` still compiles (removed in Sortie 16).
- [ ] `make build` and `make test` pass.

### Sortie 13: AudioNormalizer (R4)

**Priority**: 12 — needed by the generation port and the `AudioProcessor` removal.
**Model**: sonnet

**Entry criteria**:
- [ ] Sortie 2 exit criteria met (also runs after Sortie 12 in sequence).
- [ ] Existing code: `Sources/SwiftHablare/Utilities/AudioProcessor.swift` (silence detection, trim). Prototype `_trim`/`_cap_pauses` at `render.py:109,122` (recon A-38).

**Tasks**:
1. `Sources/SwiftHablare/Audio/AudioNormalizer.swift`: converts any `GeneratedAudio` to a target `AudioFormat` with `AVAudioConverter`, trims leading and trailing silence, caps internal pauses at a configured length, and returns a `GeneratedAudio` whose `format` and `duration` describe the output.
2. Keep `AudioProcessor` compiling; Sortie 16 removes it.
3. Tests in `Tests/SwiftHablareTests/Audio/AudioNormalizerTests.swift` on synthetic in-memory PCM (no audio hardware).

**Exit criteria**:
- [ ] A test converts 44.1 kHz stereo PCM to `pcm24kMono16` and asserts 24000 Hz, 1 channel, 16-bit, with `duration` within 10 ms of the input length minus trimmed silence.
- [ ] A test inserts a 3.0 s internal silence and asserts it is ≤ the configured cap after normalising.
- [ ] `AudioNormalizerTests` is not in `CITests.xctestplan`'s `skippedTests`.
- [ ] `make build` and `make test` pass.

---

## WU4 Port and remove

### Sortie 14: Port VoiceURI and the Speakable types (R12 last bullet)

**Priority**: 11
**Model**: sonnet

**Entry criteria**:
- [ ] Sortie 13 exit criteria met.

**Tasks**:
1. `Models/VoiceURI.swift`: add `.asset`, keep the `<plugin>://<voiceId>?lang=` string form, and add conversion to and from `VoiceReference`.
2. Port `Protocols/SpeakableItem.swift` and `Protocols/SpeakableGroup.swift` from `voiceProvider: VoiceProvider` + `generateAudio` to a `VoiceReference` plus a `VoiceSynthesizer` resolved through `PluginRegistry`, returning `GeneratedAudio`.
3. Port `Models/SpeakableItemList.swift` (types and doc comments) to the same.
4. Port `Tests/SwiftHablareTests/TestFixtures.swift`, `SpeakableItemTests.swift`, `SpeakableGroupTests.swift`, `SpeakableItemListTests.swift`, `GuionElementSpeakableTests.swift`, and the `VoiceURI` cases in `VoiceModelTests.swift` to the fakes.

**Exit criteria**:
- [ ] `grep -nw 'VoiceProvider\|generateAudio\|AppleVoiceProvider' Sources/SwiftHablare/Protocols/SpeakableItem.swift Sources/SwiftHablare/Protocols/SpeakableGroup.swift Sources/SwiftHablare/Models/SpeakableItemList.swift Sources/SwiftHablare/Models/VoiceURI.swift` returns nothing. (`Protocols/VoiceEngine.swift` is the Apple engine's internal boundary and keeps its `generateAudio`.)
- [ ] A test round-trips `VoiceURI` ↔ `VoiceReference` for `.catalog` and `.asset`, and parses `apple://com.apple.voice.compact.en-US.Samantha?lang=en`.
- [ ] `make build` and `make test` pass.

### Sortie 15: Port GenerationService (R12 last bullet)

**Priority**: 9.5
**Model**: opus

**Entry criteria**:
- [ ] Sortie 14 exit criteria met.

**Tasks**:
1. Port `Generation/GenerationService.swift` to `PluginRegistry` + `VoiceSynthesizer`: `SpeechRequest` in, `GeneratedAudio` out, with `TextChunker`, `TakeValidator` and `AudioNormalizer` applied and progress passed through. `generateList` drives the ported `SpeakableItemList`.
2. Keep `GenerationResult` and `toTypedDataStorage()` with their SwiftData/SwiftCompartido output; the stored MIME type comes from `GeneratedAudio.format`.
3. Remove the service's provider-management methods that duplicate `PluginRegistry` (`registerProvider`, `provider(withId:)`, `isProviderRegistered`, `setProvider`, `isProviderEnabled`, `availableProviderStatuses`, `configuredProvider`); keep voice listing through the plugin's synthesizer.
4. Port `Tests/SwiftHablareTests/GenerationServiceTests.swift` to the fakes.

**Exit criteria**:
- [ ] `grep -nw 'VoiceProvider\|RegisteredVoiceProvider\|configuredProvider' Sources/SwiftHablare/Generation/GenerationService.swift` returns nothing.
- [ ] A `GenerationServiceTests` case generates a 600-character item through `FakeSynthesizerPlugin` and asserts it was synthesized in 3 or more chunks and the result's format is `.pcm24kMono16`.
- [ ] A test cancels `generateList` mid-list and asserts `HablareError.cancelled` and that no later item was synthesized.
- [ ] `make build` and `make test` pass.

### Sortie 16: Remove the 6.x API and all SwiftUI (R12, "Removed in 7.0")

**Priority**: 5
**Model**: sonnet

**Entry criteria**:
- [ ] Sortie 15 exit criteria met.
- [ ] `Examples/Hablare` is not referenced by `Package.swift`, `Makefile` or `.github/` (checked 2026-10-25).

**Tasks**:
1. Delete `Sources/SwiftHablare/UI/` (5 files), `Sources/SwiftHablare/Examples/` (5 files) and the `Examples/Hablare` example app.
2. Delete `VoiceProvider.swift`, `VoiceProviderRegistry.swift`, `VoiceProviderAutoRegistrar.swift`, `Security/KeychainManager.swift`, `Providers/AppleVoiceProvider.swift` and `Utilities/AudioProcessor.swift`, plus anything else listed under "Removed in 7.0" that remains.
3. Remove `import SwiftUI` from every remaining file in the target. `SwiftHablare.swift` keeps `SwiftData` only if a remaining type needs it.
4. Delete the tests of removed code: `GenerateAudioButtonTests.swift`, `ElementGenerationButtonTests.swift`, `VoiceProviderAutoRegistrarTests.swift`. Remove their entries from both `.xctestplan` files.
5. List in the sortie report every deleted test and its test count, so the lower total can be checked.

**Exit criteria**:
- [ ] `grep -rn "import SwiftUI" Sources/SwiftHablare` returns nothing (spec Acceptance).
- [ ] `grep -rnw 'VoiceProvider\|VoiceProviderRegistry\|VoiceProviderDescriptor\|RegisteredVoiceProvider\|KeychainManager\|ProcessedAudio\|AudioProcessor\|makeConfigurationView\|configurationPanel\|GenerateAudioButton\|GenerateGroupButton\|ProviderPickerView\|VoicePickerView\|VoiceDownloadHelper\|generateProcessedAudio' Sources Tests` returns nothing.
- [ ] `test -d Examples/Hablare` fails.
- [ ] Both `.xctestplan` files parse with `python3 -m json.tool`, and neither names a deleted test class.
- [ ] `make build` and `make test` pass; the count drop equals the deleted tests listed in the report.

### Sortie 17: Migration guide and docs (Acceptance)

**Priority**: 1.5
**Model**: sonnet

**Entry criteria**:
- [ ] Sortie 16 exit criteria met.

**Tasks**:
1. `MIGRATION-7.0.md`: one row per removed symbol in "Removed in 7.0" mapped to its replacement, plus before/after snippets for registration, synthesis and credentials.
2. `CHANGELOG.md`: an entry for our next major release version (relative wording; the number is chosen at ship time).
3. `README.md`: the plugin model, both products, the credential chain, and the conformance kit; remove every UI example.
4. `AGENTS.md` (and `CLAUDE.md`/`GEMINI.md` where they repeat it): products, the architecture tree, plugin authoring with the conformance kit, the no-SwiftUI-in-core rule, and an updated test count. Leave the version line as the `-dev` stamp.

**Exit criteria**:
- [ ] For each of `VoiceProvider`, `generateAudio`, `generateProcessedAudio`, `ProcessedAudio`, `mimeType`, `estimateDuration`, `requiresAPIKey`, `VoiceProviderDescriptor`, `RegisteredVoiceProvider`, `KeychainManager`, `makeConfigurationView` and `configurationPanel`, `grep -c` in `MIGRATION-7.0.md` is ≥ 1.
- [ ] `grep -nE 'GenerateAudioButton|makeConfigurationView|KeychainManager' README.md AGENTS.md` matches only lines that link to `MIGRATION-7.0.md`.
- [ ] `grep -n 'SwiftHablareTesting' README.md AGENTS.md` matches in both files.
- [ ] [judgment] README and AGENTS.md describe the plugin model consistently with `REQUIREMENTS-7.0.md` § Architecture: the same type and product names, and plugins depend on core, never the reverse.
- [ ] `make build` and `make test` pass.

---

## Parallelism Structure

**Critical path**: S1 → S2 → S3 → S5 → S6 → S8 → S10 → S11 → S12 → S14 → S15 → S16 → S17 (13 sorties). S4, S7, S9 and S13 sit off it but still feed it (S4 → S5, S7 → S10, S9 → S10, S13 → S15).

**Parallel execution groups**: none. All 17 sorties run **sequentially, on the supervising agent's schedule, one agent at a time**.

**Agent constraints**:
- Every sortie has a `make build`/`make test` step, so under the skill's rule every sortie is **supervising-agent-gated**: the supervisor verifies each with a build before dispatching the next.
- Logically independent pairs exist (S3 ‖ S4, S7 ‖ S8, S9 ‖ S7/S8, S13 ‖ S5–S12), but they would share one working tree and one mission branch. One agent's half-finished files would break the other's `make test`.
- **Worktrees are not a safe workaround here.** `Package.swift` resolves `../SwiftCompartido` and `../SwiftFijos` (and, from S1, `../vox-format`-style siblings) relative to the checkout. A worktree outside `pkg/` silently falls back to the remote pins and builds a different graph. Revisit only if the sibling helper's lookup is made path-independent.

**Missed opportunities**: S3 ‖ S4 and S9 ‖ S7 would save about 2 sortie-lengths of wall-clock time if run in worktrees under `pkg/`. Not taken, because of the sibling-resolution risk above.

## Local Dependency Map

<!-- Carried from RECON_REPORT.md. Sortie agents may read these paths; they may not edit them. -->

| Dependency | Resolved version | Local checkout | Status |
|------------|------------------|----------------|--------|
| intrusive-memory/SwiftCompartido | `from: 7.2.4` (sibling) → local `3f3a837` (v7.4.0 +1) | `/Users/stovak/Projects/package-collection/pkg/SwiftCompartido` | SIBLING_ACTIVE |
| intrusive-memory/SwiftFijos | `from: 1.4.1` (sibling, tests only) → local `c1c5367` (v1.4.1 +19) | `/Users/stovak/Projects/package-collection/pkg/SwiftFijos` | SIBLING_ACTIVE |
| intrusive-memory/vox-format (added in S1) | plan `from: 0.4.1`; verified at `v0.4.1` | `/Users/stovak/Projects/vox-format` (`9546221`, v0.4.1 +1) | LOCAL_AHEAD |
| intrusive-memory/SwiftAcervo (added in S1) | plan `from: 0.25.0`; verified at `v0.25.0` | `/Users/stovak/Projects/package-collection/pkg/SwiftAcervo` (`13e2879`, v0.25.0 +4, untracked doc) | LOCAL_AHEAD, LOCAL_DIRTY |
| swift-markdown, swift-cmark, TextBundle, ZIPFoundation | transitive | — | NO_LOCAL_CHECKOUT |

Read-only references (not dependencies): the Python prototype `/Users/stovak/Projects/podcasts/granville/gemini-chatterbox-hybrid` @ `56c5b33`; vox-python 0.4.0 `providers/gemini.py` (uv cache); SwiftVinetas `CloudAPIKeyStore.swift` @ v0.26.0; granville voices `/Users/stovak/Projects/podcasts/granville/voices/`.

**Sibling resolution warning.** `sibling(...)` resolves `../<name>` relative to this checkout. vox-format lives at `/Users/stovak/Projects/vox-format`, not `pkg/vox-format`, so locally it resolves from the **remote** pin while the other three resolve from siblings. That is the safer direction for vox-format. For SwiftCompartido and SwiftFijos, a sortie that passes locally only through unreleased sibling API has not passed: CI resolves the remote pins.

## Open Questions

_No blocking open questions remain. OQ-1 was resolved as D-1 (recommendation accepted 2026-10-25)._

## Summary

| Metric | Value |
|--------|-------|
| Work units | 4 |
| Total sorties | 17 |
| Open questions | 0 |
| Dependencies mapped | 4 direct (2 existing, 2 added) + 4 transitive |
| Dependency structure | layers, executed sequentially |
| Critical path | 13 sorties |
