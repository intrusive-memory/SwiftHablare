# SwiftHablare Test Suite

Comprehensive test suite for SwiftHablaré voice generation library using Swift Testing framework.

## Overview

- **Total Tests**: 250+ test functions across 21 test files
- **Test Coverage**: 96%+ on voice generation components
- **Framework**: Swift Testing (migrated from XCTest in v5.1.0)
- **Concurrency**: Full Swift 6 compliance with strict concurrency enabled
- **Platforms**: iOS 26+, macOS 26+

## Test Organization

### Test Types

**Unit Tests** (Fast - ~30 seconds):
- Run on every PR
- Skip integration tests that require real audio/API keys
- Run on iOS Simulator and macOS
- 250+ tests covering all core functionality

**Integration Tests** (Slow - ~2-5 minutes):
- Run weekly on Saturdays at 3 AM UTC
- Include real API calls (require API key)
- Test actual audio generation on physical devices
- Files in `Integration/` directory

**Performance Tests**:
- Run after unit tests pass on PRs
- Benchmark audio generation, voice fetching, filtering
- Track performance regressions
- macOS only (Apple Silicon for consistent results)

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

### Mock Providers

```swift
// Configured provider (always works)
let provider = TestFixtures.makeMockProvider()

// Unconfigured provider (for error testing)
let unconfigured = TestFixtures.makeMockUnconfiguredProvider()

// Error provider (always throws)
let errorProvider = TestFixtures.makeMockErrorProvider()

// Real Apple provider
let appleProvider = TestFixtures.makeAppleProvider()

// Get available Apple voice (throws if none available)
let voiceId = try await TestFixtures.getAvailableAppleVoiceId()
```

### SpeakableItem Factories

```swift
// Simple message
let message = TestFixtures.makeSimpleMessage(
    content: "Hello",
    provider: provider,
    voiceId: "voice-id"
)

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
        let provider = TestFixtures.makeMockProvider()
        let voices = try await provider.fetchVoices()
        #expect(!voices.isEmpty)
    }
}
```

### SwiftData Testing

```swift
@Test("Create audio record")
func createAudioRecord() throws {
    let container = try TestFixtures.makeTestContainer()
    let context = ModelContext(container)
    
    let provider = TestFixtures.makeMockProvider()
    let message = TestFixtures.makeSimpleMessage(provider: provider)
    let record = TestFixtures.makeAudioRecord(for: message, in: context)
    
    try context.save()
    #expect(record.binaryValue.count > 0)
}
```

## Running Tests

```bash
# All tests
swift test

# With coverage
swift test --enable-code-coverage

# Specific suite
swift test --filter GenerationServiceTests

# Fast tests only (skip integration)
xcodebuild test -scheme SwiftHablare \
  -skip-testing:SwiftHablareTests/AppleVoiceProviderIntegrationTests \
  -skip-testing:SwiftHablareTests/ElevenLabsVoiceProviderIntegrationTests
```

## CI/CD Integration

### Required Status Checks
- Code Quality Checks
- Fast Tests (iOS)
- Fast Tests (macOS)

All must pass before merging to `main`.

### GitHub Actions Limitations

**Apple TTS Voice Availability:**

GitHub Actions macOS runners do not have Apple TTS voices pre-installed. This affects tests that require real voices from `AppleVoiceProvider`:

- **Expected Behavior**: Tests using `TestFixtures.getAvailableAppleVoiceId()` will throw `NoVoicesAvailableError` on CI
- **Test Resilience**: Tests gracefully handle missing voices by recording issues instead of failing
- **Local Development**: All tests pass normally on development machines with TTS voices installed

**Affected Test Files:**
- `SpeakableItemTests.swift` - Uses helper for voice-dependent tests
- `SpeakableItemListTests.swift` - Uses helper for batch generation tests
- `SpeakableGroupTests.swift` - Uses helper for group generation tests
- `GenerateAudioButtonTests.swift` - Uses helper for UI integration tests
- `AppleTTSEngineProtocolTests.swift` - Records issues when no voices available

**Why This is OK:**
- Tests use mock providers for most functionality testing
- Integration tests with real voices run weekly on dedicated hardware
- The test suite verifies error handling when voices aren't available
- This ensures the library gracefully degrades on systems without TTS support

## Best Practices

### ✅ DO
- Use TestFixtures for test data
- Use `@MainActor` for SwiftData tests
- Create fresh containers per test
- Skip simulator tests needing real audio
- Use descriptive `@Test` names

### ❌ DON'T
- Reuse ModelContext across tests
- Commit API keys
- Run integration tests on simulators
- Create inline mocks

## Test Coverage

- Voice Providers: 95%+
- GenerationService: 95%+
- Models: 100%
- Overall: 96%+

---

**Version**: 5.1.0 | **Framework**: Swift Testing | **Tests**: 250+
