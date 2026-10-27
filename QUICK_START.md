# SwiftHablaré Quick Start

Generate your first audio in a few minutes. For the full picture, read [README.md](README.md);
for 6.x code, read [MIGRATION-7.0.md](MIGRATION-7.0.md).

## Prerequisites

- Swift 6.2+
- iOS 26.0+ or macOS 26.0+

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/intrusive-memory/SwiftHablare.git", from: "<release version>"),
],
targets: [
    .target(name: "MyApp", dependencies: ["SwiftHablare"]),
    .testTarget(name: "MyAppTests", dependencies: ["SwiftHablare", "SwiftHablareTesting"]),
]
```

## Generate audio

```swift
import SwiftHablare

let service = GenerationService()   // uses PluginRegistry.default, which holds ApplePlugin
let voice = VoiceReference.catalog(
    pluginId: "apple", voiceId: "com.apple.voice.compact.en-US.Samantha")

let result = try await service.generate(text: "Hello, world.", voice: voice, languageCode: "en")
// result.audioData is 16-bit PCM, 24 kHz mono by default
```

## Add another engine

Engines are plugin packages. Depend on one, then register its type at launch:

```swift
let registry = PluginRegistry.default
await registry.register(MyPlugin.self)           // a HablarePlugin type from a plugin package
let status = try await registry.status(of: MyPlugin.id)   // .ready, .needsCredential(envVar:), ...
let service = GenerationService(registry: registry)
```

Cloud plugins read their API key from the environment first (for example `ELEVENLABS_API_KEY`),
then from the Keychain. See the credentials section of [README.md](README.md).

## Test with the fakes

```swift
import SwiftHablareTesting

let registry = PluginRegistry(
    environment: [:], fallbackKeys: [], plugins: [FakeSynthesizerPlugin.self])
let service = GenerationService(registry: registry)
let voice = VoiceReference.catalog(pluginId: FakeSynthesizerPlugin.id, voiceId: "fake-voice")
let result = try await service.generate(text: "Hello", voice: voice)
```

## Build and test this package

```bash
make build
make test
```
