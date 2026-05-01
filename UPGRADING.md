# Upgrading from SwiftHablare 5.x to 6.0

SwiftHablare 6.0 is provider-agnostic. The built-in `ElevenLabsVoiceProvider` was
extracted to a sibling package,
[SwiftHablareOnce](https://github.com/intrusive-memory/SwiftHablareOnce), so the host
library no longer depends on the SwiftOnce HTTP client. Apps that used the ElevenLabs
provider need a small migration; apps that only used `AppleVoiceProvider` need no code
changes beyond bumping the version pin.

## What changed

| Symbol / behavior | 5.x | 6.0 |
|---|---|---|
| `ElevenLabsVoiceProvider` | exported by `SwiftHablare` | moved to `SwiftHablareOnce` |
| `ElevenLabsModel` | exported by `SwiftHablare` | moved to `SwiftHablareOnce` |
| `VoiceProviderRegistry.shared` default providers | `[apple, elevenlabs]` | `[apple]` |
| SwiftOnce dependency | declared by `SwiftHablare` | declared by `SwiftHablareOnce` |

### Unchanged

- `AppleVoiceProvider` and the `"apple"` provider id.
- The `VoiceProvider` protocol surface and all default implementations.
- `Voice`, `VoiceURI`, and the `elevenlabs://` URI scheme.
- `VoiceProviderRegistry`'s public API (only the default content shrank — `register(_:)`,
  `configuredProvider(for:)`, `configurationPanel(for:onConfigured:)`, etc. are identical).
- `GenerationService` and the rest of the generation API.
- Persisted state: existing keychain entries under the `elevenlabs-api-key` account and
  existing UserDefaults keys (`elevenlabs-selected-model`, `elevenlabs-voice-cache-ttl`,
  `elevenlabs-audio-cache-max-bytes`) are read by the moved provider unchanged. End users
  do not need to re-enter their API key.

## Migration

### If you don't use ElevenLabs

Bump your dependency pin to 6.0.0. No code changes required.

```diff
- .package(url: "https://github.com/intrusive-memory/SwiftHablare.git", from: "5.7.0"),
+ .package(url: "https://github.com/intrusive-memory/SwiftHablare.git", from: "6.0.0"),
```

### If you use ElevenLabs

#### 1. Add `SwiftHablareOnce` as a dependency

```diff
 dependencies: [
-  .package(url: "https://github.com/intrusive-memory/SwiftHablare.git", from: "5.7.0"),
+  .package(url: "https://github.com/intrusive-memory/SwiftHablare.git", from: "6.0.0"),
+  .package(url: "https://github.com/intrusive-memory/SwiftHablareOnce.git", from: "0.1.0"),
 ],
 targets: [
   .target(
     name: "MyApp",
     dependencies: [
       .product(name: "SwiftHablare", package: "SwiftHablare"),
+      .product(name: "SwiftHablareOnce", package: "SwiftHablareOnce"),
     ]
   )
 ]
```

#### 2. Import `SwiftHablareOnce` wherever you reference ElevenLabs types

```diff
 import SwiftHablare
+import SwiftHablareOnce
```

`ElevenLabsVoiceProvider`, `ElevenLabsModel`, and the SwiftOnce-backed mapping helpers are
now exported by `SwiftHablareOnce`.

#### 3. Register the descriptor at app launch

In 5.x, `VoiceProviderRegistry` registered ElevenLabs automatically. In 6.0 you register
it explicitly — once, at startup:

```swift
import SwiftHablare
import SwiftHablareOnce

@main
struct MyApp: App {
  init() {
    Task {
      await VoiceProviderRegistry.shared.register(ElevenLabsVoiceProvider.descriptor)
    }
  }

  var body: some Scene { /* ... */ }
}
```

If you skip this step, code that resolves the provider by id throws
`VoiceProviderRegistryError.providerNotRegistered("elevenlabs")` at runtime, and
`configurationPanel(for: "elevenlabs", ...)` returns `nil`.

## Compile errors you'll see if you skip the migration

| Error | Fix |
|---|---|
| `cannot find 'ElevenLabsVoiceProvider' in scope` | Add `import SwiftHablareOnce` (step 2). |
| `cannot find 'ElevenLabsModel' in scope` | Add `import SwiftHablareOnce` (step 2). |
| `no such product 'SwiftHablareOnce'` | Add the package dependency (step 1). |

## Runtime behavior worth verifying after upgrade

- `VoiceProviderRegistry.shared.availableProviders()` returns only `apple` until you call
  `register(ElevenLabsVoiceProvider.descriptor)`. Make sure the registration runs before
  any code that depends on the registry's contents.
- `VoiceURI` strings of the form `elevenlabs://<voice-id>?lang=<code>` continue to parse
  identically — the provider id is just an opaque string.
- Existing audio in `TypedDataStorage` linked to the `elevenlabs` provider id continues to
  resolve. The provider id stored on those records was never coupled to the type's module.

## New dependency floors (informational)

SwiftHablare's own transitive dependency floors moved up. Most consumers don't need to do
anything here — these are *floors*, not pins, and SPM will resolve to the latest
compatible release. Listed for completeness:

| Dependency | 5.x `from:` | 6.0 `from:` |
|---|---|---|
| SwiftFijos | 1.0.0 | 1.4.1 |
| SwiftCompartido | 7.0.0 | 7.0.2 |
| SwiftProyecto | 3.0.0 | 3.5.0 |
| SwiftOnce | 1.0.0 *(no such release existed)* | removed (now in `SwiftHablareOnce` as 0.2.0) |

If your app pinned any of these to a lower minor that no longer satisfies the floor, lock
it in your own `Package.swift` instead of relying on what SwiftHablare resolves.
