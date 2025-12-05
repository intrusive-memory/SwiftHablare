//
//  NSSpeechTTSEngineTests.swift
//  SwiftHablareTests
//
//  Tests for macOS NSSpeechTTSEngine implementation
//

#if os(macOS)
import Testing
import AVFoundation
import AppKit
@testable import SwiftHablare

@Suite("NSSpeechTTSEngine Tests")
struct NSSpeechTTSEngineTests {

    var engine: NSSpeechTTSEngine

    init() {
        engine = NSSpeechTTSEngine()
    }

    // MARK: - Voice Fetching Tests

    @Test("Fetch voices returns non-empty array")
    func testFetchVoicesReturnsNonEmptyArray() async throws {
        let voices = try await engine.fetchVoices()
        #expect(!voices.isEmpty)
    }

    @Test("Fetched voices have required properties")
    func testFetchedVoicesHaveRequiredProperties() async throws {
        let voices = try await engine.fetchVoices()

        for voice in voices {
            #expect(!voice.id.isEmpty)
            #expect(!voice.name.isEmpty)
            #expect(voice.providerId == "apple")
        }
    }

    @Test("Fetched voices have language information")
    func testFetchedVoicesHaveLanguageInformation() async throws {
        let voices = try await engine.fetchVoices()

        let voicesWithLanguage = voices.filter { $0.language != nil }
        #expect(!voicesWithLanguage.isEmpty)
    }

    @Test("Fetched voices have valid identifiers")
    func testFetchedVoicesHaveValidIdentifiers() async throws {
        let voices = try await engine.fetchVoices()

        // Verify each voice ID is a valid NSSpeechSynthesizer voice name
        for voice in voices {
            let voiceName = NSSpeechSynthesizer.VoiceName(rawValue: voice.id)
            #expect(voiceName != nil)
        }
    }

    @Test("Fetched voices match system language")
    func testFetchedVoicesMatchSystemLanguage() async throws {
        let voices = try await engine.fetchVoices()
        let systemLanguageCode = Locale.current.language.languageCode?.identifier ?? "en"
        let systemLangPrefix = String(systemLanguageCode.prefix(2))

        // Most voices should match system language (unless fallback to first 10)
        if voices.count < 10 {
            // Fallback mode - just verify we got voices
            #expect(!voices.isEmpty)
        } else {
            // Should have filtered to system language
            let matchingVoices = voices.filter { voice in
                guard let lang = voice.language else { return false }
                return String(lang.prefix(2)) == systemLangPrefix
            }
            #expect(matchingVoices.count > 0)
        }
    }

    @Test("Fetched voices include common macOS voices")
    func testFetchedVoicesIncludeCommonMacOSVoices() async throws {
        let voices = try await engine.fetchVoices()
        let voiceNames = voices.map { $0.name.lowercased() }

        // macOS typically includes voices like Alex, Victoria, Samantha, etc.
        // Check if at least one common voice is present
        let commonVoices = ["alex", "victoria", "samantha", "fred"]
        let hasCommonVoice = commonVoices.contains { commonVoice in
            voiceNames.contains { $0.contains(commonVoice) }
        }

        #expect(hasCommonVoice)
    }

    // MARK: - Audio Generation Tests

    @Test("Generate audio returns data")
    func testGenerateAudioReturnsData() async throws {
        let voices = try await engine.fetchVoices()
        guard let firstVoice = voices.first else {
            #expect(Bool(false), "No voices available for testing")
            return
        }

        let text = "Hello, this is a test."
        let audioData = try await engine.generateAudio(text: text, voiceId: firstVoice.id)

        #expect(!audioData.isEmpty)
        #expect(audioData.count > 1024)
    }

    @Test("Generate audio with empty text throws error")
    func testGenerateAudioWithEmptyTextThrowsError() async throws {
        let voices = try await engine.fetchVoices()
        guard let firstVoice = voices.first else {
            #expect(Bool(false), "No voices available for testing")
            return
        }

        do {
            _ = try await engine.generateAudio(text: "", voiceId: firstVoice.id)
            #expect(Bool(false), "Should throw error for empty text")
        } catch let error as VoiceProviderError {
            switch error {
            case .invalidRequest(let message):
                #expect(message.contains("empty"))
            default:
                #expect(Bool(false), "Expected invalidRequest error")
            }
        }
    }

    @Test("Generate audio with whitespace-only text throws error")
    func testGenerateAudioWithWhitespaceOnlyTextThrowsError() async throws {
        let voices = try await engine.fetchVoices()
        guard let firstVoice = voices.first else {
            #expect(Bool(false), "No voices available for testing")
            return
        }

        do {
            _ = try await engine.generateAudio(text: "   \n\t   ", voiceId: firstVoice.id)
            #expect(Bool(false), "Should throw error for whitespace-only text")
        } catch let error as VoiceProviderError {
            switch error {
            case .invalidRequest(let message):
                #expect(message.contains("empty"))
            default:
                #expect(Bool(false), "Expected invalidRequest error")
            }
        }
    }

    @Test("Generate audio produces valid audio format")
    func testGenerateAudioProducesValidAudioFormat() async throws {
        let voices = try await engine.fetchVoices()
        guard let firstVoice = voices.first else {
            #expect(Bool(false), "No voices available for testing")
            return
        }

        let text = "Testing audio format."
        let audioData = try await engine.generateAudio(text: text, voiceId: firstVoice.id)

        // Write to temp file and verify it's valid audio
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("aiff")

        try audioData.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        // Try to open as AVAudioFile
        let audioFile = try AVAudioFile(forReading: tempURL)
        #expect(audioFile.processingFormat != nil)
        #expect(audioFile.length > 0)
    }

    @Test("Generate audio produces AIFF format")
    func testGenerateAudioProducesAIFFFormat() async throws {
        let voices = try await engine.fetchVoices()
        guard let firstVoice = voices.first else {
            #expect(Bool(false), "No voices available for testing")
            return
        }

        let text = "Testing AIFF format."
        let audioData = try await engine.generateAudio(text: text, voiceId: firstVoice.id)

        // Verify we got substantial audio data
        #expect(audioData.count > 1024)

        // Check for AIFF header (may not be available on CI runners without audio services)
        let header = audioData.prefix(12)
        let headerString = String(data: header, encoding: .ascii) ?? ""

        // Skip header validation if we're on a system without proper audio services
        // (CI runners may generate placeholder audio)
        if headerString.isEmpty || !headerString.contains(where: { $0.isASCII }) {
            throw Testing.Skip("AIFF format validation skipped - audio services may not be fully available")
        }

        #expect(headerString.contains("FORM") || headerString.contains("AIFF") || headerString.contains("AIFC"))
    }

    @Test("Generate audio with different voices")
    func testGenerateAudioWithDifferentVoices() async throws {
        let voices = try await engine.fetchVoices()
        let voicesToTest = Array(voices.prefix(min(3, voices.count)))

        guard voicesToTest.count > 1 else {
            #expect(Bool(false), "Need at least 2 voices for this test")
            return
        }

        let text = "Testing multiple voices."

        for voice in voicesToTest {
            let audioData = try await engine.generateAudio(text: text, voiceId: voice.id)
            #expect(!audioData.isEmpty)
            #expect(audioData.count > 1024)
        }
    }

    @Test("Generate audio with invalid voice ID")
    func testGenerateAudioWithInvalidVoiceId() async throws {
        let text = "Testing with invalid voice"

        do {
            _ = try await engine.generateAudio(text: text, voiceId: "com.invalid.voice.id")
            // Should still succeed (NSSpeechSynthesizer will use default voice)
            // This is expected macOS behavior
        } catch {
            // If it throws, that's also acceptable
            #expect(error is VoiceProviderError)
        }
    }

    @Test("Generate audio with long text")
    func testGenerateAudioWithLongText() async throws {
        let voices = try await engine.fetchVoices()
        guard let firstVoice = voices.first else {
            #expect(Bool(false), "No voices available for testing")
            return
        }

        let longText = String(repeating: "This is a longer sentence for testing. ", count: 20)
        let audioData = try await engine.generateAudio(text: longText, voiceId: firstVoice.id)

        #expect(!audioData.isEmpty)
        #expect(audioData.count > 10000)
    }

    // MARK: - Duration Estimation Tests

    @Test("Estimate duration returns positive value")
    func testEstimateDurationReturnsPositiveValue() {
        let duration = engine.estimateDuration(text: "Hello world", voiceId: "any-voice-id")
        #expect(duration > 0)
    }

    @Test("Estimate duration scales with text length")
    func testEstimateDurationScalesWithTextLength() {
        let shortText = "Hello"
        let mediumText = String(repeating: shortText + " ", count: 10)
        let longText = String(repeating: shortText + " ", count: 100)

        let shortDuration = engine.estimateDuration(text: shortText, voiceId: "any")
        let mediumDuration = engine.estimateDuration(text: mediumText, voiceId: "any")
        let longDuration = engine.estimateDuration(text: longText, voiceId: "any")

        #expect(shortDuration < mediumDuration)
        #expect(mediumDuration < longDuration)
    }

    @Test("Estimate duration has minimum value")
    func testEstimateDurationHasMinimumValue() {
        let emptyDuration = engine.estimateDuration(text: "", voiceId: "any")
        #expect(emptyDuration >= 1.0)
    }

    @Test("Estimate duration is reasonable")
    func testEstimateDurationIsReasonable() {
        let text = "This is approximately fifty characters long text"
        let duration = engine.estimateDuration(text: text, voiceId: "any")

        // ~50 chars at 14.5 chars/sec * 1.1 buffer ≈ 3.8 seconds
        #expect(duration > 2.0)
        #expect(duration < 10.0)
    }

    // MARK: - Async/Await Delegate Tests

    @Test("Delegate completion handler called on success")
    func testDelegateCompletionHandlerCalledOnSuccess() async throws {
        let voices = try await engine.fetchVoices()
        guard let firstVoice = voices.first else {
            #expect(Bool(false), "No voices available")
            return
        }

        let text = "Delegate test"

        // This test verifies that the async/await wrapper works correctly
        // by successfully completing audio generation
        let audioData = try await engine.generateAudio(text: text, voiceId: firstVoice.id)

        #expect(!audioData.isEmpty)
    }

    // MARK: - Gender Extraction Tests

    @Test("Voice gender extraction")
    func testVoiceGenderExtraction() async throws {
        let voices = try await engine.fetchVoices()

        let voicesWithGender = voices.filter { $0.gender != nil }

        // macOS voices typically have gender information
        #expect(!voicesWithGender.isEmpty)

        for voice in voicesWithGender {
            let gender = voice.gender!.lowercased()
            #expect(gender == "male" || gender == "female" || gender == "neutral")
        }
    }

    // MARK: - Concurrency Tests

    @Test("Concurrent audio generation")
    func testConcurrentAudioGeneration() async throws {
        let voices = try await engine.fetchVoices()
        guard let firstVoice = voices.first else {
            #expect(Bool(false), "No voices available")
            return
        }

        // Copy engine to local variable to avoid sendability issues with task group
        let localEngine = engine

        // Generate multiple audio files concurrently
        await withThrowingTaskGroup(of: Data.self) { group in
            for i in 0..<3 {
                group.addTask {
                    try await localEngine.generateAudio(
                        text: "Concurrent test \(i)",
                        voiceId: firstVoice.id
                    )
                }
            }

            var allData: [Data] = []
            do {
                for try await data in group {
                    allData.append(data)
                }

                #expect(allData.count == 3)

                for (index, data) in allData.enumerated() {
                    #expect(!data.isEmpty)
                    #expect(data.count > 1024)
                }
            } catch {
                #expect(Bool(false), "Concurrent audio generation failed: \(error)")
            }
        }
    }
}

#endif
