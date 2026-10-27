---
type: reference
---

# AGENTS.md

This file provides documentation for AI agents working with the SwiftHablaré codebase.

## Quick Reference

- **Current Version**: 7.0.0-dev (the `-dev` stamp; see `SwiftHablare.swift`)
- **Swift Version**: 6.2+
- **Minimum Deployments**: iOS 26+, macOS 26+
- **Test Suite**: 325 tests in 34 suites (Swift Testing; confirm with `make test`)
- **Products**: `SwiftHablare` (core library), `SwiftHablareTesting` (fakes, `InMemoryAPIKeyStore`, conformance kit)

## ⚠️ CRITICAL: Platform Version Enforcement

**This library ONLY supports iOS 26.0+ and macOS 26.0+. NEVER add code that supports older platforms.**

### Rules for Platform Versions

1. **NEVER add `@available` attributes** for versions below iOS 26.0 or macOS 26.0
   - ❌ WRONG: `@available(iOS 15.0, macOS 12.0, *)`
   - ✅ CORRECT: No `@available` needed (package enforces iOS 26/macOS 26)

2. **NEVER add `#available` runtime checks** for versions below iOS 26.0 or macOS 26.0
   - ❌ WRONG: `if #available(iOS 15.0, *) { ... }`
   - ✅ CORRECT: No runtime checks needed (package enforces minimum versions)

3. **Platform-specific code is OK** (macOS vs iOS differences)
   - ✅ CORRECT: `#if os(macOS)` or `#if canImport(AppKit)`
   - ✅ CORRECT: `#if canImport(UIKit)`
   - ❌ WRONG: Checking for specific OS versions below 26

4. **Package.swift must always specify iOS 26 and macOS 26**
   ```swift
   platforms: [
       .iOS(.v26),
       .macOS(.v26)
   ]
   ```

5. **User-facing messages** must reflect iOS 26/macOS 26 requirements
   - ❌ WRONG: "Requires macOS 15 or iOS 18"
   - ✅ CORRECT: "Requires macOS 26 or iOS 26"

**DO NOT lower the platform requirements. Apps using this library must update their deployment targets to iOS 26+ and macOS 26+.**

## Toolchain

- **Swift Concurrency**: Full Swift 6 compliance with strict concurrency enabled
- **Test Framework**: Swift Testing only (`@Suite`/`@Test`); no XCTest remains in `Tests/`

## Project Overview

**SwiftHablaré** is a plugin host for speech engines on iOS and macOS. Engines are `HablarePlugin` types resolved by a `PluginRegistry`; the on-device `ApplePlugin` ships built-in, and every other engine (local, cloud, or hybrid) is its own package that depends on SwiftHablare. Core has no UI.

Coming from 6.x: see [MIGRATION-7.0.md](MIGRATION-7.0.md) for each removed symbol (`VoiceProvider`, `KeychainManager`, `GenerateAudioButton`, `makeConfigurationView` and the rest) and its replacement.

## Products

| Product | Contents |
|---|---|
| `SwiftHablare` | Plugin contract, roles, `PluginRegistry`, credentials, text and audio utilities, `GenerationService`, `ApplePlugin`. |
| `SwiftHablareTesting` | `FakeSynthesizerPlugin`, `FakeDesignerPlugin`, `FakeCloudPlugin`, `InMemoryAPIKeyStore`, `ConformanceKit`. For test targets only. |

## Architecture

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

Source layout (`Sources/SwiftHablare`):

| Directory | Holds |
|---|---|
| `Plugins/` | `HablarePlugin`, `PluginContext`, `PluginStatus`, `PluginRegistry`, `Roles.swift` (synthesizer, designer, converter, capabilities, limits), `CompositePlugin`, `ModelDescriptor`, `LocalModelAvailability`, `VoiceListing`, `VoiceSourceSelection` |
| `Core/` | `SpeechRequest`, `GeneratedAudio`, `AudioFormat`, `VoiceReference`, `VoiceSettings`, `SettingsSchema`, `PluginConfiguration`, `CacheKey`, `HablareError` |
| `Credentials/` | `APIKeyStoring`, `CredentialRequirement`, `EnvironmentAPIKeyStore`, `KeychainAPIKeyStore`, `ChainedAPIKeyStore` |
| `Voices/` | `VoiceAsset`, `VoiceSource` |
| `Text/` | `TextChunker`, `TakeValidator`, `TakePolicy` |
| `Audio/` | `AudioNormalizer` |
| `Generation/` | `GenerationService`, `GenerationResult`, `GenerationOutcome`, `GenerationProgress` |
| `Providers/` | `ApplePlugin` and the Apple engine (`AVSpeechTTSEngine`, `AppleTTSEngine`, boundary protocol) |
| `Protocols/` | `SpeakableItem`, `SpeakableGroup`, `VoiceEngine` (Apple engine boundary) |
| `Models/` | `Voice`, `VoiceURI`, `SpeakableItemList` |

### Rules

1. **No SwiftUI in core.** `Sources/SwiftHablare` must not import SwiftUI or ship views. UI belongs to host apps.
2. **Plugins depend on core, never the reverse.** Core names no plugin but the built-in `ApplePlugin`.
3. No generics or associated types on `HablarePlugin`; plugins are compile-time packages registered by type.
4. Plugin and engine errors are `HablareError`, each with a stable category. Secrets never appear in `status()`, `keySource`, or any error text.

### Credentials

Keys resolve through `APIKeyStoring`: `EnvironmentAPIKeyStore` first (read-only), then `KeychainAPIKeyStore` (the shared access-grouped store is `KeychainAPIKeyStore.intrusiveMemoryVoices`), joined by `ChainedAPIKeyStore`. `PluginRegistry` builds the chain from every registered plugin's `credentials` and passes it as `PluginContext.keys`. Tests use `InMemoryAPIKeyStore`.

### Generation

`GenerationService` (an actor) resolves a synthesizer through the registry, chunks text to the synthesizer's limits (`TextChunker`), synthesizes each chunk through `TakeValidator` (retry on implausible takes), normalises with `AudioNormalizer`, and joins the chunks into one `GeneratedAudio` in its `targetFormat` (16-bit PCM, 24 kHz mono by default). Check `Sources/SwiftHablare/Generation/GenerationService.swift` for the exact signatures.

### Audio format

Generated audio is 16-bit integer PCM by default. `GeneratedAudio.format` must describe the bytes truthfully (`.wav` carries a matching RIFF header, `.pcm` carries none). The conformance kit checks this.

## Writing a plugin

1. Depend on `SwiftHablare` (core). Never make core depend on your package.
2. Conform a final class or struct to `HablarePlugin`: static `id`, `displayName`, `kind`, optional `credentials`, `models`, `settingsSchema`; `init(context: PluginContext) async throws`; `status()`; and the roles you provide (`synthesizer`, `designer`, `converter`).
3. Implement `VoiceSynthesizer` (`synthesize(_:)`, `readiness(for:)`, `prepare(_:)`, `release(_:)`, capabilities, limits, native formats) and/or `VoiceDesigner` (`design(_:)`, `save(_:into:)`, `delete(_:)`).
4. Use `PluginStatus.evaluate(credentials:keys:models:)` for the common status logic.
5. Register the type at launch: `await registry.register(MyPlugin.self)`.
6. Run the conformance kit from your test target (links `SwiftHablareTesting`):

```swift
let report = await ConformanceKit.run(
  MyPlugin.self, context: context, voice: voice, mode: .hardwareFree)
#expect(report.passed, "\(report.summary)")
```

`.full` runs every check and needs the engine's real resources; `.hardwareFree` skips the checks that synthesize, for CI. Checks: `initialization`, `roundTrip`, `formatTruthfulness`, `cacheKeyStability`, `cancellation`, `errorCategories`, `secrecyStatus`, `secrecyErrors`.

## Core protocols

- `SpeakableItem`: a value with `voice` and `textToSpeak`; `speechRequest` and `speak(using:pluginId:)` come from the extension.
- `SpeakableGroup`: a group of items for batch generation.
- `SpeakableItemList`: observable batch with progress and cancellation; used by `GenerationService.generateList`.
- `VoiceEngine`: the Apple engine boundary; not a plugin API.

## SwiftCompartido Integration

SwiftHablare depends on SwiftCompartido for `GuionElementModel` and `TypedDataStorage`. Generated audio is saved as `TypedDataStorage` via `GenerationResult.toTypedDataStorage()` on the main actor. SwiftCompartido does not depend on SwiftHablare.

## Development Workflow

**See [`.claude/WORKFLOW.md`](.claude/WORKFLOW.md) for the complete workflow.**

- **Development branch**: `development` (all work happens here)
- **Main branch**: `main` (protected, PR-only)
- **Workflow**: `development` -> PR -> CI passes -> merge -> tag -> release
- Never commit directly to `main`; never delete `development`.

### Build and test

SwiftHablare is **Makefile-first**. Run `make help`.

- `make build`, `make test`, `make lint`, `make clean`, `make resolve`
- **NEVER** use `swift build` or `swift test`. Use `make` (which wraps `xcodebuild`) or XcodeBuildMCP.

### Git hooks

A pre-commit hook runs `LocalAudioTests.xctestplan` (local audio tests). Install with `./.githooks/install.sh`; see `.githooks/README.md`. It skips itself on CI.

## Testing Strategy

- Swift Testing (`@Suite`, `@Test`, `#expect`); 325 tests in 34 suites.
- `Tests/SwiftHablareTests/TestFixtures.swift` provides `TestFixtures.makeFakeRegistry()` (a registry holding only `FakeSynthesizerPlugin`), `TestFixtures.fakeVoice`, and SpeakableItem factories. Prefer the fakes from `SwiftHablareTesting` over inline mocks.
- GitHub Actions sets `CI=true`; tests that need real audio hardware or TTS voices skip themselves. Test plans (`CITests.xctestplan`, `LocalAudioTests.xctestplan`) are described in `Docs/TestPlans.md`.
- SwiftData tests use an in-memory `ModelContainer` for `TypedDataStorage`, on `@MainActor`.

## Library Scope

**In scope:** the plugin contract and registry; the built-in Apple plugin; credentials; text chunking, take validation and audio normalisation; actor-based generation; `TypedDataStorage` integration; `SpeakableItem`, `SpeakableGroup` and `SpeakableItemList`; the testing product.

**Out of scope:** any UI (views, pickers, buttons, settings panels); audio playback; file I/O beyond `.vox` voice assets; screenplay processing (SwiftCompartido); character-to-voice mapping (SwiftProyecto's `CastMember`); concrete cloud or local engines other than `ApplePlugin` (they live in plugin packages).

## Quality Gates

Before submitting a PR:
- All tests pass (`make test`)
- `make lint` is clean
- Swift 6 strict concurrency, no compiler warnings
- Docs updated (README.md, AGENTS.md, MIGRATION-7.0.md when API moves)
- CHANGELOG.md updated
- iOS and macOS verified

## Resources

- `README.md` - overview and API
- `MIGRATION-7.0.md` - 6.x to 7.0 mapping
- `CHANGELOG.md` - version history
- `Tests/README.md` - test suite documentation
- `.claude/WORKFLOW.md` - development workflow
- [SwiftCompartido](https://github.com/intrusive-memory/SwiftCompartido) - screenplay parsing and TypedDataStorage

**Note**: SwiftHablaré targets iOS 26+ and macOS 26+. Ensure new code paths consider both supported platforms.
