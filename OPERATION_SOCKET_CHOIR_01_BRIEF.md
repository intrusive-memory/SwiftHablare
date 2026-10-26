---
type: mission-brief
---

# Iteration 01 Brief — OPERATION SOCKET CHOIR

## Terminology

> **Mission** — A definable, testable scope of work. Defines scope, acceptance criteria, and dependency structure.

> **Sortie** — An atomic, testable unit of work executed by a single autonomous AI agent in one dispatch. One aircraft, one mission, one return.

> **Work Unit** — A grouping of sorties (package, component, phase).

**Mission:** SwiftHablare 7.0, the pluggable voice architecture: plugin contract, registry, credentials, voice assets, engine services, conformance kit, Apple plugin, the generation port, and removal of the 6.x API and all SwiftUI.
**Branch:** `mission/socket-choir/01`
**Starting Point Commit:** `57c9b1d4` (docs(recon): cover f5e2633c, still CLEAR)
**Sorties Planned:** 17
**Sorties Completed:** 17
**Sorties Failed/Blocked:** 0 (one REPLAN on Sortie 1, resolved by a plan amendment)
**Duration:** ~4.2 h wall clock, strictly sequential; ~250× relative cost (13 sonnet, 3 opus sortie runs, 1 sonnet retry, 2 sonnet verifiers)
**Outcome:** Complete
**Verdict:** `KEEP` — every sortie landed on its first counted attempt, the spec's hybrid acceptance test passes, and test cleanup found nothing to prune.
**Tests pruned:** 0
**Tests flagged for review:** 5

---

## 1. Hard Discoveries

### 1. A second library product removes the test action from SwiftPM's auto scheme

**What happened:** Sortie 1 added the `SwiftHablareTesting` product. `make test` then failed with "Scheme SwiftHablare is not currently configured for the test action". SwiftPM moved tests to an auto-generated `SwiftHablare-Package` scheme. That scheme has no `CITests` plan, so the agent's proposed rename would also have broken CI (`-testPlan CITests` exit 64).
**What was built to handle it:** A checked-in shared scheme, `.swiftpm/xcode/xcshareddata/xcschemes/SwiftHablare.xcscheme`. It has a test action, `CITests` as the default plan and `LocalAudioTests` as the second. The Makefile and CI were left unchanged.
**Should we have known this?** Yes. Recon checked the manifest, not the scheme the build tooling generates from it.
**Carry forward:** Any SwiftPM repo that tests through `xcodebuild -scheme <Name>` and adds a second library product needs a committed shared scheme in the same commit. Recon should check `xcodebuild -list` before and after the manifest change.

### 2. xctestplan `skippedTests` is ignored for swift-testing tests here

**What happened:** In Sortie 12, entries added to `CITests.xctestplan` did not skip the test, in either identifier format. The hardware tests that were "skipped" before this mission were actually gated by `.enabled(if: !CI)`, with the plan setting `CI=true`.
**What was built to handle it:** The full Apple conformance test carries the same trait. The plan entry stays only for documentation.
**Should we have known this?** Partly. The existing `AVSpeechTTSEngineTests` already used the trait pattern.
**Carry forward:** In this repo a swift-testing test is CI-safe only if it has a `!CI` trait. Plan exit criteria that say "skip in CITests" mean "add the trait".

### 3. VoxFormat 0.4.1 does not preserve extension key order

**What happened:** In Sortie 7, `manifest.extensions` is `[String: AnyCodable]`. That means `extensions.google` cannot keep vox-python's key order (`voice_id` first), and a byte-for-byte match with vox-python is impossible.
**What was built to handle it:** `VoiceAsset.googleExtensionOrder` records the Python order. Readers are unaffected.
**Should we have known this?** Yes. Recon A-14 read `VoxManifest.swift:51` but did not check how extensions are stored.
**Carry forward:** Byte parity needs an ordered extension store in vox-format. That is a change to a separate repo.

### 4. Swift's generics cannot give `CompositePlugin` the spec's id

**What happened:** In Sortie 10, `CompositePlugin<D, S>` cannot carry a custom stored static id. It derives `"<designer>+<synthesizer>"`, so the Produciesta hybrid would be `google+chatterbox` rather than the spec's `gemini-chatterbox`.
**What was built to handle it:** The derived id, which is documented.
**Should we have known this?** Yes. It is a direct consequence of D-1 combined with a generic composite.
**Carry forward:** This is Open Decision 1.

### 5. Root `Fixtures/` loses to the nearer `Tests/.../Fixtures/` in SwiftFijos lookup

**What happened:** In Sortie 7, `Fijos.getFixture("voices/X.vox")` found `Tests/SwiftHablareTests/Fixtures/` first.
**What was built to handle it:** `VoiceAssetTests.fixture(_:)` anchors the lookup at `<root>/Package.swift`.
**Carry forward:** Tests that load root fixtures should use that helper.

---

## 2. Process Discoveries

### What the Agents Did Right

#### 1. They reported seams instead of quietly patching around them
**What happened:** Agents named the gaps they found. Examples: the S5 agent on the credentials-to-registry gap, the seed ambiguity, and the S6/S7 ordering; the S6 agent on fakes whose WAV bytes carried a `.pcm` label; the S12 agent on the `skippedTests` behaviour; the S15 agent on the `print(` calls in the Apple engine.
**Right or wrong?** Right. Each one became an instruction in a later dispatch, and the conformance kit then caught the fake's mislabelled format for real.
**Evidence:** S8's registry-provided environment-variable test, S11's relabelling of the fake format, and S12's `!CI` trait each closed a seam an earlier agent had reported.
**Carry forward:** Keep "report public API and seams for later sorties" in every dispatch.

#### 2. They fixed flakes at the root
**What happened:** The process-wide `FakeSynthesizerPlugin.initCount` was replaced with a task-local counter in S11. S8 used a test-local counting plugin.
**Right or wrong?** Right. `make test` passed twice in each of S8 and S11.
**Carry forward:** Never use process-wide counters in test fakes.

### What the Agents Did Wrong

#### 1. The S17 docs agent missed a spec naming mismatch
**What happened:** README and AGENTS.md said `ApplePlugin` while the spec says `AppleVoiceProvider`, with no mapping between them. The independent verifier caught it in round 1.
**Right or wrong?** Wrong but cheap. It took one continuation of about 47 s.
**Carry forward:** Docs sorties should grep the spec for every type name they rename.

#### 2. The S12 agent's report contradicted the repo
**What happened:** The agent said `make test` runs the full Apple kit. In fact the scheme's default plan is `CITests`, so the kit is skipped. The supervisor caught this by reading the scheme.
**Carry forward:** Verify agent claims about which tests ran against the scheme and the plan, not against the agent's own narrative.

### What the Planner Did Wrong

#### 1. Sortie 1 omitted the scheme consequence
**What happened:** The plan's premise was that adding a product leaves `make test` working. It did not, which caused the only REPLAN.
**Evidence:** One wasted dispatch of about 2.5 min, plus the user's time to approve the amendment.
**Carry forward:** See Hard Discovery 1.

#### 2. S6 and S7 were ordered against a hidden dependency
**What happened:** S6's `FakeDesignerPlugin.save(_:into:)` needed S7's `VoiceAsset` write API, yet both listed only S5 as an entry criterion. The supervisor dispatched S7 before S6, which violated no entry criterion.
**Carry forward:** Entry criteria must include API dependencies, not just sortie numbers.

#### 3. Exit criteria named things that did not exist
**What happened:** S14 asked for "VoiceURI cases in VoiceModelTests", but there were none. The agent wrote `VoiceURITests` instead. S12's "skip in CITests" relied on a mechanism that does not work here.
**Carry forward:** Recon should check every file and test name an exit criterion cites.

#### 4. The strict-sequential plan was the correct call
**What happened:** All 17 sorties ran one at a time.
**Right or wrong?** Right. No two sorties corrupted each other's working tree. The time cost was roughly 2 sortie lengths.

---

## 3. Open Decisions

Answer the first two before downstream missions; none block merging this branch.

### 1. Composite plugin id
**Why it matters:** Produciesta and Escribir will persist plugin ids in `VoiceURI` strings and enablement keys. A `+`-derived id becomes permanent once data is written with it.
**Options:**
- A: Accept `"<designer>+<synthesizer>"`. This is free, but the id differs from the spec.
- B: Add a naming hook. One way is an optional `CompositeNaming` protocol the composite consults for `id` and `displayName`. Another is a non-generic `HybridPlugin` base that the declaring package subclasses. Either gives `gemini-chatterbox`.
- C: The downstream package declares its own non-generic struct that wraps `CompositePlugin`.

**Recommendation:** B. It is a small core addition in a patch release, made before any downstream data exists.

### 2. Gap between joined chunks
**Why it matters:** `GenerationService` trims each chunk and joins them with no gap, leaving about 80 ms of combined edge padding. Long reads may sound rushed.
**Options:** A configurable inter-chunk gap with a sentence-end default (for example 150–250 ms), or leave it as it is.
**Recommendation:** Do a listening check on a real multi-sentence render, then decide. This needs human ears.

### 3. The `print(` calls in `AVSpeechTTSEngine.swift`
**Why it matters:** The file has about 40 `print(` calls from before this mission. CI's print check only warns. They log the text being spoken to stdout, which is noise and a minor privacy leak.
**Recommendation:** A follow-up patch that converts them to OSLog at debug level.

### 4. Stale docs outside Sortie 17's scope
**Why it matters:** `Docs/` holds about 28 files and `Skills/register_voice_provider.skill.md` still describes 6.x. They contradict the new README.
**Recommendation:** Delete or archive them per the house "docs describe the current state only" rule.

### 5. `SwiftHablare.version` is `"6.3.0-dev"`
**Recommendation:** Bump it when `/ship-swift-library` cuts our next major release.

---

## 4. Sortie Accuracy

| Sortie | Task | Model | Attempts | Accurate? | Notes |
|--------|------|-------|----------|-----------|-------|
| 1 | Manifest + testing product | sonnet | 1 (+REPLAN) | Yes | Shared scheme was added after the plan amendment |
| 2 | Errors, audio, request types | sonnet | 1 | Yes | Its stubs were completed by S4, S5 and S7 as planned |
| 3 | Credentials chain | sonnet | 1 | Yes | The static `builtIn` map was widened by S8 through the registry |
| 4 | Voice settings | sonnet | 1 | Yes | |
| 5 | Plugin contract | opus | 1 | Yes | The contract survived unchanged through S17 |
| 7 | VoiceAsset over VoxFormat | sonnet | 1 | Yes | Ran before S6; key-order limit is upstream |
| 6 | Fakes | sonnet | 1 | Mostly | Format label corrected to `.wav` in S11; global init counter replaced in S11 |
| 8 | PluginRegistry | sonnet | 1 | Yes | Accepted deviation: test-local counter |
| 9 | Chunker, validator, cache key | sonnet | 1 | Yes | |
| 10 | Composite + acceptance | opus | 1 | Yes | Id naming is an open decision |
| 11 | Conformance kit | sonnet | 1 | Yes | Also fixed S6's fakes |
| 12 | ApplePlugin | sonnet | 1 | Yes | Full kit green on the real engine |
| 13 | AudioNormalizer | sonnet | 1 | Yes | |
| 14 | VoiceURI + Speakable port | sonnet | 1 | Yes | Shims removed in S15 and S16 as designed |
| 15 | GenerationService port | opus | 1 | Yes | 29 old tests became 41 |
| 16 | Remove 6.x + SwiftUI | sonnet | 1 | Yes | −46 tests, all of deleted code |
| 17 | Migration + docs | sonnet | 1 (verifier 2/2) | Yes | Naming mapping added after verifier FAIL |

---

## 5. Harvest Summary

The 7.0 architecture held up under implementation. The contract written in S5 needed no rework through 12 dependent sorties, and the spec's acceptance test passes: design into `TOBY.vox`, readiness names `google`, and `sourceUsed` matches, while an untouched voice falls back to `qwen3-tts`. Every sortie succeeded on its first counted attempt. All the friction came from tooling around the code: SwiftPM scheme generation, swift-testing ignoring the test plan's skip list, SwiftFijos lookup order, and VoxFormat's unordered extensions. None of it was the design. The most important change for the next iteration is to make recon check build and test tooling as well as source APIs. Run `xcodebuild -list`, look at how tests are skipped, and check that every file an exit criterion names exists. Test cleanup pruned 0 of the mission's tests and flagged 5 borderline cases. All 5 are CI-safe as written, and none points to a systemic pattern.

**Not yet verified:** this branch has not run on GitHub CI. CI's macos-26 runner compiles with an older Swift than this machine's local toolchain, so a green local build does not prove a green CI build. The PR's checks are the first real test.

---

## 6. Files

**Preserve (read-only reference for next iteration):**

| File | Branch | Why |
|------|--------|-----|
| `docs/complete/socket-choir-01/` (this brief, plan, state, completion log, cleanup report) | `mission/socket-choir/01` | Mission record |
| `MIGRATION-7.0.md` | `mission/socket-choir/01` | Downstream plugin repos port against it |
| `Sources/SwiftHablareTesting/ConformanceKit.swift` | `mission/socket-choir/01` | Every downstream plugin mission runs it |

**Discard:** none (verdict is KEEP).

---

## 7. Iteration Metadata

**Starting point commit:** `57c9b1d4` (docs(recon): cover f5e2633c, still CLEAR)
**Mission branch:** `mission/socket-choir/01`
**Final commit on mission branch:** `798acbbe` before the brief and archival commits; see `git log`
**Rollback target:** `57c9b1d4`
**Next iteration branch:** `mission/socket-choir/02` (not needed under KEEP)

---

## 8. Rollback Verdict

**Verdict:** `KEEP`

**Reasoning:** All 4 work units completed with zero FATAL or BACKOFF sorties. The single REPLAN was a tooling premise fixed by a one-task amendment (Section 1.1). The hard discoveries are all tooling or upstream constraints, and none undermines the design (Section 1). Test cleanup removed 0% of the mission's tests (Section 5). Every sortie's output survived to the final state with no rework beyond planned stub completion (Section 4).

**Recommended action:**
- Open a PR from `mission/socket-choir/01` into `development`, mark it ready so CI runs, and treat the CI result as the outstanding gate (Section 5, CI Swift version risk).
- Follow-ups: Open Decision 1 (composite id) before the gemini-chatterbox and Produciesta missions; Decision 2 (a listening check on chunk gaps); Decision 3 (OSLog in `AVSpeechTTSEngine`); Decision 4 (stale `Docs/` and `Skills/`); Decision 5 (version bump at ship).
- Flagged tests: optionally switch the `VoiceURITests` literal `/Users/me/...` strings to `/tmp/...`, and watch `PluginRegistryTests`'s concurrency test and `CredentialsTests`'s Keychain test on the first CI runs.
