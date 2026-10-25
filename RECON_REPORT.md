---
type: recon-report
state: current
requirements_file: REQUIREMENTS-7.0.md
requirements_sha256: e784f624b4cb88d1f8ced6d47cdb96643a9cf8eaef83f7b092ecb638ef6d8ea7
project_head: 1ce470e3f7706854537b8812d81ab3169df29d63
search_root: ~/Projects
generated: 2026-10-24
revised: 2026-10-25
verdict: CLEAR
---

# RECON_REPORT.md: SwiftHablare 7.0

## Terminology

> **Mission**: a definable, testable scope of work.
> **Sortie**: an atomic, testable unit of work that one agent completes in one dispatch.
> **Work unit**: a group of sorties.

## Verdict

**CLEAR** (re-adjudicated 2026-10-24). All six blocking findings below were fixed in REQUIREMENTS-7.0.md (and in Produciesta's REQUIREMENTS-hablare-providers.md where it repeated them). No code assumption changed, so no spoke was re-run.

**Scoped re-run 2026-10-25 for `f5e2633c`: still CLEAR.** That commit added two decisions: the design → download sample → replicate hybrid flow (R11) and the line-by-line all-Google path (Gemini facts). They carry 7 new assumptions, A-42 to A-48. All 7 are confirmed against the prototype, vox-python, upstream mlx-audio-swift, SwiftReparto and Produciesta. The Google API's own behaviour is still U-1, which is now wider (see Unverifiable). The other 41 findings were not re-checked, because the commit touches no other section.

Original verdict: **BLOCKED.** 41 assumptions were checked. 33 were confirmed, 6 block the plan, and 2 are unverifiable.

None of the blocking findings changes the architecture. Each is a wrong statement in the requirements text about how existing code looks: dependency counts, where a type lives, and a version number. All six can be fixed by amending the doc.

## Assumption findings

| ID | Kind | Claim | Locus | Verdict | Evidence |
|----|------|-------|-------|---------|----------|
| A-01 | A-API | `AppleVoiceProvider` built in | repo | CONFIRMED | `Sources/SwiftHablare/Providers/AppleVoiceProvider.swift:26` |
| A-02 | A-API | 6.x `VoiceProvider` members slated for removal exist | repo | CONFIRMED | `VoiceProvider.swift:24,27,47,56,60,80`. `configurationPanel` is on `VoiceProviderDescriptor` (`VoiceProviderRegistry.swift:31`), not on the protocol |
| A-03 | A-API | `VoiceProviderDescriptor`, `RegisteredVoiceProvider`, `KeychainManager`, `VoiceProviderRegistry` | repo | CONFIRMED | `VoiceProviderRegistry.swift:15,75,108`; `Security/KeychainManager.swift:12` |
| A-04 | A-FILE | SwiftUI views exist; no `SwiftHablareUI` product | repo | CONFIRMED | Views are under `Sources/SwiftHablare/UI/`. There is one product. 9 source files import SwiftUI, **including `VoiceProvider.swift` and `AppleVoiceProvider.swift`** |
| A-05 | A-BEHAVIOR | `configuredProvider(for:)` rebuilds the provider on every call; enablement is persisted | repo | CONFIRMED | `VoiceProviderRegistry.swift:145-161`; UserDefaults key `voiceProvider.enabled.<id>` (:261) |
| A-06 | A-API | `GenerationService`, `SpeakableItem`/`Group`, `VoiceURI` `<id>://<voice>?lang=` | repo | CONFIRMED | `GenerationService.swift:87`; `VoiceURI.swift:6,48,97` |
| A-07 | A-INVARIANT | Core has no MLX | repo | CONFIRMED | `grep -rniE "mlx\|voxformat\|acervo" Package.swift Sources Package.resolved` returned no matches |
| A-08 | A-CONFIG | `make test` and `make lint`; CHANGELOG exists; no MIGRATION doc yet | repo | CONFIRMED | `Makefile:23,27`. `UPGRADING.md` exists and could hold the migration guide |
| A-09 | A-BEHAVIOR | Only Apple is registered by default | repo | CONFIRMED | `VoiceProviderRegistry.swift:305-307` |
| A-10 | A-DEP | Dependencies are SwiftFijos and SwiftCompartido | repo | CONFIRMED | SwiftFijos is used by tests only. The library depends on SwiftCompartido alone |
| A-11 | A-API | No 7.0 type names collide with existing types | repo | CONFIRMED | Zero declarations found for all 10 names |
| A-12 | A-DEP | Core doesn't use VoxFormat or SwiftAcervo yet | repo | CONFIRMED | Same grep as A-07 |
| A-13 | A-API | `VoxFormat.VoxFile` can read and write a `.vox` | dep:vox-format@v0.4.1 | CONFIRMED | `implementations/swift/Sources/VoxFormat/VoxFile.swift:26,67,222` |
| A-14 | A-DATA | `manifest.extensions` keyed by engine; `embeddings/<engine>/…` paths | dep:vox-format@v0.4.1 | CONFIRMED | `VoxManifest.swift:51`. Swift has no path builder; only Python's `engines.py:79` `embedding_path` has one |
| **A-15** | A-DEP | vox-format is "zero-dependency" | dep:vox-format@v0.4.1 | **REFUTED** | `Package.swift:21-23` declares ZIPFoundation (library) and swift-argument-parser (CLI) |
| **A-16** | A-DEP | SwiftAcervo is zero-dependency (Foundation + CryptoKit) | dep:SwiftAcervo@v0.25.0 | **REFUTED** | `Package.swift:23-25` declares swift-argument-parser and Progress.swift (CLI). The library imports Foundation, CryptoKit, OSLog and Security |
| A-17 | A-API | Acervo availability and download-with-progress APIs | dep:SwiftAcervo@v0.25.0 | CONFIRMED | `Acervo+Availability.swift:61` `isModelAvailable`; `Acervo+Download.swift:58` `download(_:files:force:progress:telemetry:)`; `AcervoDownloadProgress` |
| A-18 | A-DATA | HablareOnce Keychain account `elevenlabs-api-key` | dep:SwiftHablareOnce@v0.1.0 | CONFIRMED | `ElevenLabsVoiceProvider.swift:103` |
| A-19 | A-API | `pcm_24000` is available for HablareOnce 0.2.0 | dep:SwiftOnce@v1.0.0 | CONFIRMED | `Sources/SwiftOnce/Models/Enums.swift:53`. HablareOnce 0.1.0 currently requests `mp3_44100_128` (`ElevenLabsVoiceProvider.swift:148`), so switching to PCM is real work |
| A-20 | A-DATA | vox-python Google layout | vox-python 0.4.0 (installed) | CONFIRMED | `providers/gemini.py:42-46`: `embeddings/google/gemini-3.8-flash-tts/sample-audio.wav`; endpoints `/v1beta/voices` and `/v1beta/interactions` |
| A-21 | A-API | `VoxAltaModelManager`: single-slot, `checkMemory`, `validateMemory` | dep:SwiftVoxAlta@v0.14.2 | CONFIRMED | `VoxAltaModelManager.swift:203,208,564,587` (actor) |
| A-22 | A-API | `VoxAltaMemoryPolicy`: cache cap, `clearCache` | dep:SwiftVoxAlta@v0.14.2 | CONFIRMED | `VoxAltaMemoryPolicy.swift:42,79,107` |
| **A-23** | A-BEHAVIOR | VoxAlta has a "hard-coded 1.7B descriptor" | dep:SwiftVoxAlta@v0.14.2 | **STALE** | The descriptor has no model metadata (`VoxAltaProviderDescriptor.swift:30-36`). 1.7B is a default that can be overridden in `init` (`VoxAltaVoiceProvider.swift:90-91`) |
| A-24 | A-FILE | The telemetry work is a separate package | dep:SwiftVoxAlta | CONFIRMED (reframed) | It is a branch, `feature/telemetry-instrumentation`, that is 13 commits ahead of and 19 behind `v0.14.2`. The `SwiftVoxAlta-telemetry` directory is an orphaned worktree whose gitdir no longer exists |
| **A-25** | A-API | The fork's differences include `Qwen3TTSModelRepo` (re-fork item 3) | dep:mlx-audio-swift@v0.10.0 | **STALE** | Not in the fork. It is defined in `SwiftVoxAlta/VoxAltaModelManager.swift:19`. `VoiceClonePrompt` and `generateWithClonePrompt` (`Qwen3TTSVoiceClonePrompt.swift:15,230`), Acervo loading, `WiredMemoryManager` and breath chunking are confirmed in the fork |
| A-26 | A-DEP | The fork uses swift-tokenizers 0.7.x | dep:mlx-audio-swift@v0.10.0 | CONFIRMED | `Package.swift:50-51` |
| A-27 | A-API | Upstream has Chatterbox (Regular + Turbo) and S3Gen | upstream/main d8e2caf | CONFIRMED | `Models/Chatterbox/` (~3.6k lines) plus `MLXAudioCodecs/S3Gen/` (~4.2k lines). Turbo is `ChatterboxConfig.swift:232` |
| A-28 | A-DEP | Upstream uses swift-transformers | upstream/main | CONFIRMED | `Package.swift:64` swift-transformers ≥1.1.6, product `Transformers` |
| A-29 | A-API | Upstream lacks clone prompts and Acervo | upstream/main | CONFIRMED | `git grep` returned no matches |
| A-30 | A-DEP | The fork is 110 commits ahead of upstream and 191 behind | mlx-audio-swift | CONFIRMED | `rev-list --left-right` gives 191/110; merge-base dated 2026-02-08 |
| A-31 | A-DEP | SwiftTuberia uses swift-tokenizers | dep:SwiftTuberia@v0.9.0 | CONFIRMED | `Package.swift:33-34`, product `Tokenizers` |
| A-32 | A-API | No residency host exists in MLXAudioCore yet | fork and upstream | CONFIRMED | The fork's `AudioModelManager` is an Acervo download enum. Upstream has nothing comparable. The host is **new code** |
| A-33 | A-API | Vinetas `CloudAPIKeyStoring` pattern | dep:SwiftVinetas@v0.26.0 | CONFIRMED | `Cloud/CloudAPIKeyStore.swift:17-31,77,204,249,306`; `ChainedAPIKeyStore.default` is env then Keychain (:258) |
| A-34 | A-CONFIG | `GEMINI_API_KEY`, alias `GOOGLE_API_KEY` | dep:SwiftVinetas@v0.26.0 | CONFIRMED | `Cloud/CloudProvider.swift:91,101` |
| A-35 | A-CONFIG | Vinetas group `…Vinetas.shared` | dep:SwiftVinetas@v0.26.0 | CONFIRMED | `CloudAPIKeyStore.swift:80,85`. The group applies on macOS only (:88-94) |
| A-36 | A-BEHAVIOR | Prototype per-speaker knobs and defaults | prototype @56c5b33 | CONFIRMED | `render.py:34-40,205-217`: 0.5 / 0.5 / 0.8. **`seed` is global** (`render.py:37`), not per speaker |
| A-37 | A-BEHAVIOR | Reference clip ≤10 s cut on a pause; 280-char chunks; 0.3–2.2× of 14 chars/s +1.5 s | prototype | CONFIRMED | `render.py:25-26,64,85,148,231`. The clip is between 5 and 10 s; 2 retries means 3 takes |
| A-38 | A-API | `_trim`, `_cap_pauses` | prototype | CONFIRMED | `render.py:109,122` |
| A-39 | A-BEHAVIOR | Falls back to the Qwen3 sample with a warning | prototype | CONFIRMED | `render.py:191-192`: `warning: {sp} has no Gemini voice; using its {source} sample` |
| **A-40** | A-DATA | Escribir "1.2.0" doc: 6.x API, D-6, "§2.2 says a determinate ring needs" progress | app:Escribir | **STALE** | The API names and D-6 are confirmed (`docs/REQUIREMENTS-1.2.0.md:53-64,536`). **§2.2 specifies an *indeterminate* ring** and defers the determinate one (:217,240,657) |
| **A-41** | A-DATA | Voice work ships as Escribir **1.2.0** | app:Escribir | **STALE** | Tags `1.2.0-rc1` through `rc9` already exist for other work, and none of them reference SwiftHablare (`git grep` at `development`, `main` and `1.2.0-rc6` returned no matches). The voice feature needs a new version number |
| A-42 | A-BEHAVIOR | The hybrid never calls Gemini synthesis; rendering uses only the stored sample | prototype @56c5b33 | CONFIRMED | `render.py` has no `genai`, `interactions` or synthesis call. Gemini is used only in `gemini_voices.py:36-76` (`design_voice`) |
| A-43 | A-DATA | Design writes the sample to `embeddings/google/gemini-3.8-flash-tts/sample-audio.wav` and the voice id to `manifest.extensions.google` | vox-python 0.4.0; prototype | CONFIRMED | vox-python `providers/gemini.py:5-12,46,51` (`voice_id` is the first extension key). The prototype writes it through vox-python's `attach` (`gemini_voices.py:65-68`). The installed copy and the uv git checkout `582c50b` are identical here |
| A-44 | A-DATA | The design prompt comes from the character's CAST.md voice prompt | dep:SwiftReparto@v0.2.0; prototype | CONFIRMED | Reparto `CastMember+Merging.swift:76,191` (`voicePrompt`). The prototype reads `voicePrompt` (`cast.py:38`) and refuses to design without it (`gemini_voices.py:42-43`) |
| A-45 | A-API | Chatterbox clones zero-shot from reference audio | upstream mlx-audio-swift @d8e2caf | CONFIRMED | `ChatterboxModel.swift:498` `prepareConditionals(refAudio:)`; `generate(… refAudio:)` at :680 needs it (:718). Still true at today's `upstream/main` `6fd9386` |
| A-46 | A-BEHAVIOR | The reference clip is at most 10 s | upstream @d8e2caf; prototype | CONFIRMED | `ChatterboxConfig.swift:383` `decCondLen = 10 * 24000` (encoder 6 s, :382). Matches prototype `render.py:64-68` |
| A-47 | A-API | A stored voice is rendered by one `/interactions` call per text, keyed by its voice id | vox-python 0.4.0 | CONFIRMED (client shape only) | `providers/gemini.py:150-166` `synthesize(voice_id:text:)` posts one `/interactions` request with a single `speech_config` voice. Live behaviour is U-1 |
| A-48 | A-BEHAVIOR | The host joins per-line audio | app:Produciesta | CONFIRMED | `M4AExporter.export(results:to:)` stitches per-element results into one `AVMutableComposition` (`ProduciestaCore/Export/M4AExporter.swift:102-114,156`), on both `origin/main` and `origin/development` |

### Blocking findings

#### A-15 and A-16: REFUTED. vox-format and SwiftAcervo are not zero-dependency.
**Claim**: "Both are small, in-org, zero-dependency packages" (Risks), and "SwiftAcervo, which is zero-dependency (Foundation + CryptoKit), so this costs nothing transitively" (R9).
**Found**:
- vox-format v0.4.1 declares ZIPFoundation (used by the library) and swift-argument-parser (used by its CLI).
- SwiftAcervo v0.25.0 declares swift-argument-parser and Progress.swift (both used by its CLI).

SPM resolves every dependency a package declares, whether or not you use its products.
**Impact**: Small. ZIPFoundation is already in Hablare's graph through SwiftCompartido. swift-argument-parser and Progress.swift are new packages to resolve, but no library code uses them. Still, "costs nothing" is false.
**Options**:
1. Amend R9 and Risks to say "the library targets add only ZIPFoundation, which is already resolved. Each package's CLI dependencies are resolved but not linked." *(recommended)*
2. Split each CLI into its own package so the library packages are genuinely dependency-free. That is out of scope here.

#### A-23: STALE. VoxAlta has no hard-coded 1.7B descriptor.
**Claim**: Downstream table, SwiftVoxAlta row: "Fixes the hard-coded 1.7B descriptor".
**Found**: The descriptor has no model metadata. 1.7B is an overridable default on `VoxAltaVoiceProvider.init`.
**Option**: Reword the row as "Model size comes from `PluginConfiguration`, replacing the `init` default of 1.7B, and is surfaced through `models`" *(recommended)*.

#### A-25: STALE. `Qwen3TTSModelRepo` is a VoxAlta type, not one of the fork's differences.
**Claim**: Re-fork item (3), "`Qwen3TTSModelRepo` / model-size enum … that SwiftVoxAlta uses".
**Found**: The enum is defined at `SwiftVoxAlta/VoxAltaModelManager.swift:19`. Neither the fork nor upstream has it.
**Options**:
1. Drop the enum from item (3). Keep the telemetry reporter, after checking where it actually lives. *(recommended)*
2. Move the enum into MLXAudioCore together with the model host. This only makes sense if the host needs a model catalogue.

#### A-40 and A-41: STALE. The Escribir version and the §2.2 citation are wrong.
**Claim**: Consumers and Downstream: Escribir "1.2.0" adds voices, and "Escribir 1.2.0 §2.2 says a determinate ring needs" `SynthesisProgress`.
**Found**:
- Escribir's 1.2.0 release line already exists, rc1 through rc9, without any voice work.
- §2.2 asks for an indeterminate ring. It defers the determinate ring until Hablare has a progress callback.
**Impact**: The R2 progress callback is still justified, but as the thing that unblocks the deferred determinate ring, not as what §2.2 requires. The version label sends readers to the wrong release.
**Options**:
1. In both REQUIREMENTS-7.0.md and Produciesta's REQUIREMENTS-hablare-providers.md, call the work "Escribir voices (next minor after 1.2.0)" and cite §2.2 as "deferred determinate ring". Retitle the Escribir doc when that work starts. *(recommended)*
2. Leave the docs as they are and rely on readers to notice. Not recommended.

## Local dependency map

| Dependency | Declared | Resolved | Local checkout | Local HEAD | Status |
|---|---|---|---|---|---|
| intrusive-memory/SwiftCompartido | `from: 7.2.4` (sibling) | local path `../SwiftCompartido` | `pkg/SwiftCompartido` | `3f3a837` (v7.4.0 +1) | SIBLING_ACTIVE |
| intrusive-memory/SwiftFijos | `from: 1.4.1` (sibling, tests only) | local path `../SwiftFijos` | `pkg/SwiftFijos` | `c1c5367` (v1.4.1 +19) | SIBLING_ACTIVE |
| intrusive-memory/vox-format (7.0 adds this) | plan: `from: 0.4.1` | — | `~/Projects/vox-format` | `9546221` (v0.4.1 +1) | LOCAL_AHEAD; verified at `v0.4.1` |
| intrusive-memory/SwiftAcervo (7.0 adds this) | plan: `from: 0.25.0` | — | `pkg/SwiftAcervo` | `13e2879` (v0.25.0 +4) | LOCAL_AHEAD, LOCAL_DIRTY (an untracked requirements doc); verified at `v0.25.0` |
| swiftlang/swift-markdown, swift-cmark; mcritz/TextBundle; weichsel/ZIPFoundation | transitive | 0.8.0 / 0.8.0 / 1.0.7 / 0.9.20 | — | — | NO_LOCAL_CHECKOUT |

Downstream packages verified at their tags: SwiftVoxAlta `v0.14.2` (local +1), mlx-audio-swift `v0.10.0` (local +2), upstream `upstream/main` `d8e2caf` (fetched 2026-10-23), SwiftHablareOnce `v0.1.0` (+1), SwiftOnce `v1.0.0`, SwiftVinetas `v0.26.0` (+1), SwiftTuberia `v0.9.0` (+1, dirty: untracked mission files), Escribir (`development`, `main`, tags), prototype `56c5b33`, vox-python 0.4.0 (installed copy, so the commit can't be confirmed).

### Drift and ambiguity notes

- **Both of Hablare's dependencies are SIBLING_ACTIVE.** Local builds compile against `../SwiftCompartido` at v7.4.0+1, while CI resolves `from: 7.2.4`. Hablare's `Package.resolved` is untracked and has no pins for either.
- **Orphaned worktree**: `pkg/SwiftVoxAlta-telemetry/.git` points at `/Users/stovak/Projects/SwiftVoxAlta/.git/worktrees/…`, which no longer exists, because the repo moved. Its branch content still exists in `pkg/SwiftVoxAlta`.
- Every intrusive-memory checkout is at least one commit ahead of its tag (the `-dev` stamp). All verdicts above were taken at the tag.

## Unverifiable

| ID | Claim | Why | What would settle it |
|----|-------|-----|----------------------|
| U-1 | The Gemini Interactions API and the `gemini-3.8-flash-tts` / `-lite` model names behave as specified. Since `f5e2633c` this also covers: a designed voice renders one line per call; ids look like `voice_…` (vox-python also accepts `voices/…`); the one-year expiry; the 200-voice cap | **Confirmed in Google's documentation** (see the REQUIREMENTS-7.0 section "Gemini API facts"). Not yet checked with a live call | One authenticated call, using the Keychain key, in the first SwiftGemelos sortie |
| U-2 | The CDN hosts `mlx-community/Chatterbox-TTS-fp16` and the `chatterbox-turbo-*` models | **Checked: they were not on the CDN.** `manifest.json` returned 404 and Qwen3 returned 200 | Both are being shipped with `acervo ship` (queued 2026-10-24). The prototype's Python model `mlx-community/chatterbox-fp16` is a different repo and is not needed by Swift |

## Handoff to breakdown

- Every CONFIRMED fact above can be used as a sortie entry criterion without re-checking.
- Removing SwiftUI touches `VoiceProvider.swift` and `AppleVoiceProvider.swift` as well as `UI/` and `Examples/`. Scope the sortie for that.
- The MLXAudioCore model host is new code, modelled on `VoxAltaModelManager`. It is not a move.
- HablareOnce 0.2.0 must switch from `mp3_44100_128` to `pcm_24000`. SwiftOnce 1.0.0 supports it.
- Treat U-1 and U-2 as verification steps in the first SwiftGemelos and SwiftCotorra sorties.
