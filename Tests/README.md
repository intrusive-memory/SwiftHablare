# SwiftHablare Test Suite

Comprehensive test suite for SwiftHablaré voice generation library using Swift Testing framework.

## Overview

- **Total Tests**: 325 tests in 34 suites
- **Framework**: Swift Testing (migrated from XCTest in v5.1.0)
- **Concurrency**: Full Swift 6 compliance with strict concurrency enabled
- **Platforms**: iOS 26+, macOS 26+

## Test Organization

### Test Plans

SwiftHablare uses **Xcode Test Plans** to separate tests by audio hardware requirements:

**CITests.xctestplan** (Default for CI):
- All tests EXCEPT those requiring real audio hardware
- Uses placeholder audio when TTS voices unavailable
- Runs on GitHub Actions CI runners
- Completes in well under a minute

**LocalAudioTests.xctestplan** (Local Development Only):
- Only 3 tests requiring real TTS voices and audio hardware
- Tests 16-bit PCM format validation
- Tests AVAudioPlayer compatibility
- Tests accurate duration calculation
- **Cannot run on CI** (no audio hardware)

See `Docs/TestPlans.md` for complete documentation.

### Test Types

**Unit Tests** (Fast - ~30 seconds):
- Run on every PR via `CITests.xctestplan`
- Skip integration tests that require real audio/API keys
- Run on iOS Simulator and macOS
- Covers all core functionality

**Audio Hardware Tests** (Local Only):
- Run via `LocalAudioTests.xctestplan`
- Require macOS with TTS voices installed
- 3 tests validating real audio generation
- **Never run on CI**
- macOS only

## Swift Testing Framework

### Why Swift Testing?

SwiftHablaré uses **Swift Testing** (introduced in Swift 6) instead of XCTest:

**Advantages:**
- Modern macro-based syntax with `@Suite` and `@Test`
- Cleaner assertions with `#expect()` macro
- Better test organization and discoverability
- Built-in async/await support
- Improved error messages
- Better Xcode integration

### Migration from XCTest

All tests migrated in v5.1.0:

| XCTest | Swift Testing |
|--------|---------------|
| `import XCTest` | `import Testing` |
| `class FooTests: XCTestCase` | `@Suite struct FooTests` |
| `func testFoo()` | `@Test func foo()` |
| `XCTAssertEqual(a, b)` | `#expect(a == b)` |
| `XCTAssertTrue(x)` | `#expect(x)` |
| `XCTAssertFalse(x)` | `#expect(!x)` |
| `XCTAssertNil(x)` | `#expect(x == nil)` |
| `XCTFail("msg")` | `Issue.record("msg")` |
| `XCTSkip("msg")` | `throw Issue.skip("msg")` |

## TestFixtures Helper

Central test utility for creating test data and mocks.

### Container Creation

```swift
// Create in-memory ModelContainer
let container = try TestFixtures.makeTestContainer()
let context = ModelContext(container)
```

### Fake Plugins

The fakes live in the `SwiftHablareTesting` product (no inline mocks):

```swift
import SwiftHablareTesting

// A registry holding only FakeSynthesizerPlugin (no network, no audio hardware)
let registry = TestFixtures.makeFakeRegistry()

// The fake plugin and its synthesizer, for call counts and failure injection
let plugin = try #require(
    try await registry.plugin(id: FakeSynthesizerPlugin.id) as? FakeSynthesizerPlugin)
plugin.failNextCall(with: .transient(underlying: URLError(.timedOut)))

// Cloud-shaped fake with a credential, and a designer fake
// FakeCloudPlugin, FakeDesignerPlugin

// API keys without the Keychain
let keys = InMemoryAPIKeyStore(keys: ["fake-cloud": "test-key"])
```

The conformance kit (`ConformanceKit.run`) is covered by `Testing/ConformanceKitTests.swift`.

### SpeakableItem Factories

```swift
// Simple message
let message = TestFixtures.makeSimpleMessage(
    content: "Hello",
    voice: TestFixtures.fakeVoice   // .catalog(pluginId: "fake-synth", voiceId: "fake-voice")
)

// Speak it through a registry holding only FakeSynthesizerPlugin
let registry = TestFixtures.makeFakeRegistry()
let audio = try await message.speak(using: registry)

// Character dialogue
let dialogue = TestFixtures.makeCharacterDialogue(
    characterName: "ALICE",
    dialogue: "Hello, Bob!"
)
```

## Writing Tests

### Basic Pattern

```swift
import Testing
import SwiftData
@testable import SwiftHablare

@Suite("My Tests")
@MainActor
struct MyTests {
    
    @Test("Basic test")
    func basicTest() {
        #expect(42 == 42)
    }
    
    @Test("Async test")
    func asyncTest() async throws {
        let registry = TestFixtures.makeFakeRegistry()
        let synthesizer = try await registry.synthesizer(for: TestFixtures.fakeVoice)
        let audio = try await synthesizer.synthesize(
            SpeechRequest(text: "Hello", voice: TestFixtures.fakeVoice))
        #expect(audio.duration > 0)
    }
}
```

### SwiftData Testing

```swift
@Test("Create audio record")
func createAudioRecord() throws {
    let container = try TestFixtures.makeTestContainer()
    let context = ModelContext(container)
    
    let message = TestFixtures.makeSimpleMessage()
    let record = TestFixtures.makeAudioRecord(for: message, in: context)
    
    try context.save()
    #expect(record.binaryValue.count > 0)
}
```

## Running Tests

Never run `swift test`. Use the Makefile:

```bash
make test    # all tests
make lint    # format check (CI runs it first)
```

## CI/CD Integration

### Required Status Checks
- Code Quality Checks
- Fast Tests (iOS)
- Fast Tests (macOS)

All must pass before merging to `main`.

### GitHub Actions Limitations

**Apple TTS Voice Availability:**

GitHub Actions macOS runners do not have Apple TTS voices pre-installed. Tests that need real `ApplePlugin` voices skip themselves when `CI` is set or no voice is installed, and everything else runs against the fakes from `SwiftHablareTesting`. Local runs on a machine with TTS voices exercise the real engine (the pre-commit hook runs `LocalAudioTests.xctestplan`).

## Best Practices

### ✅ DO
- Use TestFixtures for test data
- Use `@MainActor` for SwiftData tests
- Create fresh containers per test
- Skip simulator tests needing real audio
- Use the fakes from `SwiftHablareTesting` for plugin tests
- Use descriptive `@Test` names

### ❌ DON'T
- Reuse ModelContext across tests
- Commit API keys
- Run integration tests on simulators
- Create inline mocks

## Test Coverage

Measure with `make test` and the Xcode coverage report; no fixed percentage is asserted here.

---

**Framework**: Swift Testing | **Tests**: 325 in 34 suites
