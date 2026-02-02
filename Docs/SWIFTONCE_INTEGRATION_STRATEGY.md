# SwiftOnce Integration Strategy

## Executive Summary

SwiftOnce is a zero-dependency Swift 6.2 library that provides comprehensive ElevenLabs API coverage with:
- ✅ **Comprehensive Caching** - Voice cache (in-memory TTL) + Audio cache (file-system LRU)
- ✅ **Actor-based Thread Safety** - Full Swift 6 strict concurrency
- ✅ **Rich Voice Metadata** - Categories, verified languages, preview URLs
- ✅ **Complete API Coverage** - All ElevenLabs v1/v2 endpoints

**Architecture Decision**: Hablare's ONLY responsibility is voice generation using voice IDs. Voice design and voice selection are handled by Echada (character management layer).

**Recommendation**: Replace SwiftHablare's custom ElevenLabs REST implementation (`ElevenLabsEngine`) with SwiftOnce for better caching, thread safety, and maintainability.

---

## Current State Analysis

### SwiftHablare's ElevenLabsVoiceProvider

**Current Implementation:**
- Custom REST calls via `ElevenLabsEngine`
- Minimal Voice model (id, name, language only)
- Model selection via UserDefaults
- API key storage via KeychainManager
- No Voice Design support
- No collection filtering
- No caching (relies on SwiftData for persistence)

**Files Involved:**
- `Sources/SwiftHablare/Providers/ElevenLabsVoiceProvider.swift`
- `Sources/SwiftHablare/Providers/ElevenLabs/ElevenLabsEngine.swift`
- `Sources/SwiftHablare/Providers/ElevenLabs/ElevenLabsEngineConfiguration.swift`
- `Sources/SwiftHablare/Models/Voice.swift`

### SwiftOnce Capabilities

**Complete API Coverage:**
```swift
public actor SwiftOnce {
    // Text-to-Speech
    func speak(_ text: String, voice voiceId: String, model: Model?, outputFormat: OutputFormat?) async throws -> Data
    func stream(...) -> AsyncThrowingStream<Data, Error>
    func speakWithTimestamps(...) async throws -> TimestampedAudio

    // Voice Management
    func voices(search: String?, category: VoiceCategory?, collectionId: String?, ...) async throws -> VoiceListResponse
    func voice(_ voiceId: String) async throws -> Voice

    // Voice Design
    func designVoice(description: String, previewText: String?) async throws -> VoiceDesignResponse
    func createVoice(from preview: VoicePreview, name: String, description: String) async throws -> Voice

    // Cache Management
    func clearAudioCache() async throws
    func invalidateVoiceCache() async
}
```

**Rich Voice Model:**
```swift
public struct Voice: Sendable, Codable {
    let voiceId: String
    let name: String
    let category: VoiceCategory?
    let description: String?
    let labels: [String: String]
    let previewUrl: String?
    let settings: VoiceSettings?
    let collectionIds: [String]           // ✅ Collection support
    let verifiedLanguages: [VerifiedLanguage]?  // ✅ Rich language metadata
    let isOwner: Bool?
    // ... and more
}
```

**Voice Design Models:**
```swift
public struct VoicePreview: Sendable, Identifiable {
    let id: String
    let audioData: Data
    let mediaType: String
    let duration: TimeInterval
    let language: String?
}

public struct VoiceDesignResponse: Sendable {
    let previews: [VoicePreview]  // 3 preview options
    let text: String
}
```

---

## Integration Strategy

### Phase 1: Add SwiftOnce Dependency

**Update `Package.swift`:**
```swift
let package = Package(
    name: "SwiftHablare",
    // ... existing configuration
    dependencies: [
        .package(url: "https://github.com/intrusive-memory/SwiftOnce.git", from: "1.0.0"),
        // ... existing dependencies
    ],
    targets: [
        .target(
            name: "SwiftHablare",
            dependencies: [
                .product(name: "SwiftOnce", package: "SwiftOnce"),
                // ... existing dependencies
            ]
        ),
        // ... existing targets
    ]
)
```

### Phase 2: Refactor ElevenLabsVoiceProvider

**New Architecture:**
```swift
import SwiftOnce

public final class ElevenLabsVoiceProvider: VoiceProvider {
    public let providerId = "elevenlabs"
    public let displayName = "ElevenLabs"
    public let requiresAPIKey = true
    public let mimeType = "audio/mpeg"

    private let keychainManager: KeychainManagerProtocol
    private let apiKeyAccount = "elevenlabs-api-key"
    private let ephemeralAPIKey: String?

    // Replace ElevenLabsEngine with SwiftOnce actor
    private var swiftOnceClient: SwiftOnce?

    // Initialize SwiftOnce client when API key is available
    private func client() async throws -> SwiftOnce {
        if let client = swiftOnceClient {
            return client
        }

        let apiKey = try await getAPIKey()
        let config = SwiftOnceConfiguration(
            userAgent: "\(SwiftHablare.name)/\(SwiftHablare.version)",
            defaultModel: selectedModel().toSwiftOnceModel(),
            defaultOutputFormat: .mp3_44100_128
        )
        let client = SwiftOnce(apiKey: apiKey, configuration: config)
        self.swiftOnceClient = client
        return client
    }

    // VoiceProvider protocol implementation
    public func fetchVoices(languageCode: String) async throws -> [Voice] {
        let client = try await client()
        let response = try await client.voices()

        // Filter by language if needed
        return response.voices
            .filter { voice in
                guard let verifiedLanguages = voice.verifiedLanguages else { return true }
                return verifiedLanguages.contains { $0.locale?.starts(with: languageCode) ?? false }
            }
            .map { $0.toSwiftHablareVoice() }
    }

    public func generateAudio(text: String, voiceId: String, languageCode: String) async throws -> Data {
        let client = try await client()
        return try await client.speak(
            text,
            voice: voiceId,
            languageCode: languageCode
        )
    }

    // ... other VoiceProvider methods
}
```

### Phase 3: Voice Model Mapping

**Add conversion extensions:**
```swift
// In Sources/SwiftHablare/Providers/ElevenLabs/SwiftOnceVoiceMapping.swift

import SwiftOnce

extension SwiftOnce.Voice {
    /// Convert SwiftOnce rich Voice to SwiftHablare minimal Voice
    func toSwiftHablareVoice() -> SwiftHablare.Voice {
        // Use first verified language or fallback
        let primaryLanguage = verifiedLanguages?.first?.locale ?? "en-US"

        return SwiftHablare.Voice(
            id: voiceId,
            name: name,
            language: primaryLanguage
        )
    }
}

extension ElevenLabsModel {
    /// Convert SwiftHablare ElevenLabsModel to SwiftOnce Model
    func toSwiftOnceModel() -> SwiftOnce.Model {
        switch self {
        case .multilingualV2: return .multilingualV2
        case .turboV2_5: return .turboV2_5
        case .turboV2: return .turboV2
        case .multilingualV1: return .multilingualV1
        case .monolingualV1: return .monolingualV1
        }
    }
}
```

### Phase 4: Keep VoiceProvider Simple

**NO Voice Design in Hablare**
- Voice design is handled by Echada (character management layer)
- Hablare's ONLY job is to generate audio from voice IDs
- Keep VoiceProvider protocol focused on generation only

**NO Collection Filtering in Hablare**
- Voice selection and filtering is handled by Echada
- Hablare receives pre-selected voice IDs
- SwiftOnce's collection filtering is available for Echada to use directly

**Simplified Architecture:**
```swift
// Hablare's VoiceProvider stays simple
public protocol VoiceProvider: Sendable {
    var providerId: String { get }
    var displayName: String { get }
    var requiresAPIKey: Bool { get }
    var mimeType: String { get }

    func isConfigured() async -> Bool
    func fetchVoices(languageCode: String) async throws -> [Voice]
    func generateAudio(text: String, voiceId: String, languageCode: String) async throws -> Data
    func estimateDuration(text: String, voiceId: String) async -> TimeInterval
    func isVoiceAvailable(voiceId: String) async -> Bool
}

// Echada uses SwiftOnce directly for voice management
// - Voice design: SwiftOnce.designVoice()
// - Voice creation: SwiftOnce.createVoice()
// - Collection filtering: SwiftOnce.voices(collectionId:)
// - Voice selection: Echada's UI
// Then passes voice ID to Hablare for generation
```

---

## Migration Path

### Step 1: Non-Breaking Changes
1. Add SwiftOnce dependency to Package.swift
2. Create `SwiftOnceVoiceMapping.swift` with conversion extensions
3. Add `VoiceDesignable` protocol (doesn't break existing code)
4. Add unit tests for voice mapping

### Step 2: Refactor ElevenLabsVoiceProvider
1. Replace `ElevenLabsEngine` with SwiftOnce client
2. Update `fetchVoices()` implementation
3. Update `generateAudio()` implementation
4. Update tests to use new implementation
5. Verify existing integration tests pass

### Step 3: Cleanup
1. Remove `ElevenLabsEngine.swift`
2. Remove `ElevenLabsEngineConfiguration.swift`
3. Remove custom REST implementation
4. Update CHANGELOG.md

---

## Testing Strategy

### Unit Tests
```swift
@Suite("SwiftOnce Integration Tests")
struct SwiftOnceIntegrationTests {
    @Test("Voice model mapping preserves data")
    func testVoiceMapping() async throws {
        let swiftOnceVoice = SwiftOnce.Voice(
            voiceId: "test-123",
            name: "Test Voice",
            category: .premade,
            description: "Test description",
            labels: ["accent": "american"],
            previewUrl: "https://example.com/preview.mp3",
            settings: nil,
            collectionIds: ["coll-1", "coll-2"],
            highQualityBaseModelIds: [],
            verifiedLanguages: [
                VerifiedLanguage(language: "English", modelId: nil, accent: "American", locale: "en-US", previewUrl: nil)
            ],
            availableForTiers: nil,
            isOwner: true,
            isLegacy: false,
            createdAtUnix: 1234567890
        )

        let hablareVoice = swiftOnceVoice.toSwiftHablareVoice()

        #expect(hablareVoice.id == "test-123")
        #expect(hablareVoice.name == "Test Voice")
        #expect(hablareVoice.language == "en-US")
    }

    @Test("ElevenLabsModel converts to SwiftOnce Model")
    func testModelMapping() {
        #expect(ElevenLabsModel.multilingualV2.toSwiftOnceModel() == .multilingualV2)
        #expect(ElevenLabsModel.turboV2_5.toSwiftOnceModel() == .turboV2_5)
        #expect(ElevenLabsModel.turboV2.toSwiftOnceModel() == .turboV2)
    }
}
```

### Integration Tests
```swift
@Suite("ElevenLabsVoiceProvider Integration Tests")
struct ElevenLabsProviderIntegrationTests {
    @Test("Fetch voices from ElevenLabs", .tags(.integration))
    func testFetchVoices() async throws {
        guard let apiKey = ProcessInfo.processInfo.environment["ELEVENLABS_API_KEY"] else {
            throw XCTSkip("ELEVENLABS_API_KEY not set")
        }

        let provider = ElevenLabsVoiceProvider(apiKey: apiKey)
        let voices = try await provider.fetchVoices(languageCode: "en")

        #expect(voices.count > 0)
        #expect(voices.allSatisfy { !$0.id.isEmpty })
        #expect(voices.allSatisfy { !$0.name.isEmpty })
    }

    @Test("Generate audio with ElevenLabs", .tags(.integration))
    func testGenerateAudio() async throws {
        guard let apiKey = ProcessInfo.processInfo.environment["ELEVENLABS_API_KEY"] else {
            throw XCTSkip("ELEVENLABS_API_KEY not set")
        }

        let provider = ElevenLabsVoiceProvider(apiKey: apiKey)
        let voices = try await provider.fetchVoices(languageCode: "en")
        guard let firstVoice = voices.first else {
            throw XCTSkip("No voices available")
        }

        let audioData = try await provider.generateAudio(
            text: "Hello, this is a test.",
            voiceId: firstVoice.id,
            languageCode: "en"
        )

        #expect(audioData.count > 0)
    }
}
```

---

## Benefits of Integration

### Immediate Benefits
✅ **Better Caching** - Audio cache (file-system LRU) + Voice cache (TTL)
✅ **Actor-based Safety** - Full Swift 6 concurrency compliance
✅ **Reduced Code** - Remove ~500 lines of custom REST implementation
✅ **Rich Metadata** - Voice categories, preview URLs (available for Echada)

### Maintenance Benefits
✅ **Reduced Code** - Remove ~500 lines of custom REST code
✅ **Better Testing** - SwiftOnce has comprehensive test coverage
✅ **Bug Fixes** - SwiftOnce updates benefit SwiftHablare automatically
✅ **API Parity** - SwiftOnce tracks ElevenLabs API changes
✅ **Clear Boundaries** - Hablare focuses on generation, Echada handles voice management

### Echada Benefits (Voice Management Layer)
✅ **Voice Design** - Echada can use SwiftOnce directly for custom voice generation
✅ **Collection Filtering** - Echada can use SwiftOnce.voices(collectionId:)
✅ **Rich Voice Data** - Full access to categories, verified languages, metadata
✅ **Direct Access** - Echada uses SwiftOnce for voice management, passes IDs to Hablare

---

## Risks and Mitigations

### Risk: SwiftOnce API Changes
**Mitigation**: Pin SwiftOnce version with semantic versioning
```swift
.package(url: "https://github.com/intrusive-memory/SwiftOnce.git", exact: "1.0.0")
```

### Risk: Breaking Existing Apps
**Mitigation**:
- Phase migration over multiple releases
- Keep VoiceProvider protocol stable
- Add deprecation warnings before removal
- Provide migration guide in CHANGELOG

### Risk: Performance Regression
**Mitigation**:
- Benchmark audio generation before/after
- Verify cache hit rates
- Monitor memory usage with actor isolation

### Risk: SwiftOnce Maintenance
**Mitigation**:
- Both repos owned by same organization (intrusive-memory)
- Zero external dependencies means fewer breakages
- Comprehensive test coverage (95%+)
- Active development and maintenance

---

## Timeline Estimate

- **Phase 1** (Add Dependency): 1 hour
- **Phase 2** (Refactor Provider): 4-6 hours
- **Phase 3** (Voice Mapping): 2 hours
- **Testing**: 3-4 hours
- **Documentation**: 1-2 hours

**Total**: 11-15 hours of focused development

---

## Decision: Proceed?

**Recommendation**: ✅ **YES - Proceed with Integration**

SwiftOnce provides better architecture (actor-based, comprehensive caching) with less maintenance burden (remove ~500 lines of custom REST code). The integration is straightforward and keeps Hablare focused on its core responsibility: voice generation.

**Clear Separation of Concerns**:
- **Hablare**: Voice generation from voice IDs (uses SwiftOnce internally)
- **Echada**: Voice management, selection, design (uses SwiftOnce directly)

**Next Steps**:
1. ✅ User approved simplified architecture (Hablare = generation only)
2. Start with Phase 1 (add dependency) as a non-breaking change
3. Implement Phase 2 (refactor provider) in a feature branch
4. Add comprehensive tests before merging
5. Document migration in CHANGELOG.md

---

**Questions for Review**:
1. Should we expose SwiftOnce's streaming TTS through VoiceProvider (or keep it simple)?
2. Do we want to preserve ElevenLabsEngine for one release cycle with deprecation warnings?
3. Should Hablare expose any SwiftOnce configuration (cache size, TTL) or keep defaults?
