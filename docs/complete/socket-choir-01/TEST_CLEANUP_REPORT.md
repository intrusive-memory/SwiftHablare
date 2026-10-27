---
type: test-cleanup-report
state: completed
updated: 2026-10-26
mission: socket-choir-01
---

# Test Cleanup Report: OPERATION SOCKET CHOIR

Scope: tests added or changed since 57c9b1d4 on mission/socket-choir/01.

## Removed

| file:test_name | reason (pattern #) | confidence |
|---|---|---|
| (none) | No test matched a high-confidence CI-failure pattern. | n/a |

## Flagged for Review

| file:test_name | concern | recommended action |
|---|---|---|
| Tests/SwiftHablareTests/VoiceURITests.swift:assetRoundTrip (and the "My Voices" test near line 76) | Uses literal `/Users/me/...` paths (pattern 1 lookalike). They are only strings fed to `URL(fileURLWithPath:)` and URI round-tripping. No file is read, so they are CI-safe. | Keep. Optionally switch to `/tmp/Voices/...` to avoid tripping path audits. |
| Tests/SwiftHablareTests/Providers/ApplePluginConformanceTests.swift:fullKit | Hardware-dependent (real AVSpeechSynthesisVoice). Gated with `.enabled(if: !CI)`, which is the correct trait. CI is safe as long as the runner sets `CI`. | Keep. Confirmed gated. |
| Tests/SwiftHablareTests/Plugins/PluginRegistryTests.swift (fixture init) | `Task.sleep(30ms)` widens a reentrancy window inside a fixture plugin. It is not a timing assertion, but the concurrency test relies on the overlap. | Keep. Watch for flakes. |
| Tests/SwiftHablareTests/Credentials/CredentialsTests.swift | Real Keychain with a per-test service and cleanup. Probably fine on macos-26 runners, not verified in CI. | Keep. Review if keychain errors appear in CI. |
| Tests/SwiftHablareTests/SpeakableTestTypes.swift | `timestamp: Date = Date()` defaults used as data in test types. No assertions on the current time found. | Keep. |

## Build Verification

- `make lint`: ran with no complaints and left no working-tree changes.
- `make test`: TEST SUCCEEDED, 325 tests in 34 suites passed (same as before cleanup, since nothing was removed).
