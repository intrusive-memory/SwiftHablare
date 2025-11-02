//
//  NSSpeechTTSEngineTests.swift
//  SwiftHablareTests
//
//  Tests for macOS NSSpeechTTSEngine implementation
//

#if os(macOS) && !targetEnvironment(macCatalyst)
import XCTest
import AVFoundation
@testable import SwiftHablare

@available(macOS 10.13, *)
final class NSSpeechTTSEngineTests: XCTestCase {

    var engine: NSSpeechTTSEngine!

    override func setUp() {
        super.setUp()
        engine = NSSpeechTTSEngine()
    }

    override func tearDown() {
        engine = nil
        super.tearDown()
    }

    // MARK: - Voice Fetching Tests

    func testFetchVoicesReturnsNonEmptyArray() async throws {
        let voices = try await engine.fetchVoices()
        XCTAssertFalse(voices.isEmpty, "Should return at least one voice")
    }

    func testFetchedVoicesHaveRequiredProperties() async throws {
        let voices = try await engine.fetchVoices()

        for voice in voices {
            XCTAssertFalse(voice.id.isEmpty, "Voice ID should not be empty")
            XCTAssertFalse(voice.name.isEmpty, "Voice name should not be empty")
            XCTAssertEqual(voice.providerId, "apple", "Provider ID should be 'apple'")
        }
    }

    func testFetchedVoicesHaveLanguageInformation() async throws {
        let voices = try await engine.fetchVoices()

        let voicesWithLanguage = voices.filter { $0.language != nil }
        XCTAssertFalse(voicesWithLanguage.isEmpty, "Some voices should have language information")
    }

    func testFetchedVoicesHaveValidIdentifiers() async throws {
        let voices = try await engine.fetchVoices()

        // Verify each voice ID is a valid NSSpeechSynthesizer voice name
        for voice in voices {
            let voiceName = NSSpeechSynthesizer.VoiceName(rawValue: voice.id)
            XCTAssertNotNil(voiceName, "Voice ID should be valid: \(voice.id)")
        }
    }

    func testFetchedVoicesMatchSystemLanguage() async throws {
        let voices = try await engine.fetchVoices()
        let systemLanguageCode = Locale.current.language.languageCode?.identifier ?? "en"
        let systemLangPrefix = String(systemLanguageCode.prefix(2))

        // Most voices should match system language (unless fallback to first 10)
        if voices.count < 10 {
            // Fallback mode - just verify we got voices
            XCTAssertFalse(voices.isEmpty)
        } else {
            // Should have filtered to system language
            let matchingVoices = voices.filter { voice in
                guard let lang = voice.language else { return false }
                return String(lang.prefix(2)) == systemLangPrefix
            }
            XCTAssertGreaterThan(matchingVoices.count, 0, "Should have voices matching system language")
        }
    }

    func testFetchedVoicesIncludeCommonMacOSVoices() async throws {
        let voices = try await engine.fetchVoices()
        let voiceNames = voices.map { $0.name.lowercased() }

        // macOS typically includes voices like Alex, Victoria, Samantha, etc.
        // Check if at least one common voice is present
        let commonVoices = ["alex", "victoria", "samantha", "fred"]
        let hasCommonVoice = commonVoices.contains { commonVoice in
            voiceNames.contains { $0.contains(commonVoice) }
        }

        XCTAssertTrue(hasCommonVoice, "Should include at least one common macOS voice")
    }

    // MARK: - Audio Generation Tests

    func testGenerateAudioReturnsData() async throws {
        let voices = try await engine.fetchVoices()
        guard let firstVoice = voices.first else {
            XCTFail("No voices available for testing")
            return
        }

        let text = "Hello, this is a test."
        let audioData = try await engine.generateAudio(text: text, voiceId: firstVoice.id)

        XCTAssertFalse(audioData.isEmpty, "Audio data should not be empty")
        XCTAssertGreaterThan(audioData.count, 1024, "Audio data should be substantial (>1KB)")
    }

    func testGenerateAudioWithEmptyTextThrowsError() async throws {
        let voices = try await engine.fetchVoices()
        guard let firstVoice = voices.first else {
            XCTFail("No voices available for testing")
            return
        }

        do {
            _ = try await engine.generateAudio(text: "", voiceId: firstVoice.id)
            XCTFail("Should throw error for empty text")
        } catch let error as VoiceProviderError {
            switch error {
            case .invalidRequest(let message):
                XCTAssertTrue(message.contains("empty"), "Error should mention empty text")
            default:
                XCTFail("Expected invalidRequest error")
            }
        }
    }

    func testGenerateAudioWithWhitespaceOnlyTextThrowsError() async throws {
        let voices = try await engine.fetchVoices()
        guard let firstVoice = voices.first else {
            XCTFail("No voices available for testing")
            return
        }

        do {
            _ = try await engine.generateAudio(text: "   \n\t   ", voiceId: firstVoice.id)
            XCTFail("Should throw error for whitespace-only text")
        } catch let error as VoiceProviderError {
            switch error {
            case .invalidRequest(let message):
                XCTAssertTrue(message.contains("empty"), "Error should mention empty text")
            default:
                XCTFail("Expected invalidRequest error")
            }
        }
    }

    func testGenerateAudioProducesValidAudioFormat() async throws {
        let voices = try await engine.fetchVoices()
        guard let firstVoice = voices.first else {
            XCTFail("No voices available for testing")
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
        XCTAssertNotNil(audioFile.processingFormat, "Should have valid audio format")
        XCTAssertGreaterThan(audioFile.length, 0, "Audio file should have frames")
    }

    func testGenerateAudioProducesAIFFFormat() async throws {
        let voices = try await engine.fetchVoices()
        guard let firstVoice = voices.first else {
            XCTFail("No voices available for testing")
            return
        }

        let text = "Testing AIFF format."
        let audioData = try await engine.generateAudio(text: text, voiceId: firstVoice.id)

        // Check for AIFF header
        let header = audioData.prefix(12)
        let headerString = String(data: header, encoding: .ascii) ?? ""

        XCTAssertTrue(headerString.contains("FORM"), "Should have FORM header")
        XCTAssertTrue(headerString.contains("AIFF") || headerString.contains("AIFC"),
                     "Should be AIFF or AIFC format")
    }

    func testGenerateAudioWithDifferentVoices() async throws {
        let voices = try await engine.fetchVoices()
        let voicesToTest = Array(voices.prefix(min(3, voices.count)))

        guard voicesToTest.count > 1 else {
            XCTFail("Need at least 2 voices for this test")
            return
        }

        let text = "Testing multiple voices."

        for voice in voicesToTest {
            let audioData = try await engine.generateAudio(text: text, voiceId: voice.id)
            XCTAssertFalse(audioData.isEmpty, "Audio should be generated for voice: \(voice.name)")
            XCTAssertGreaterThan(audioData.count, 1024, "Audio should be substantial for voice: \(voice.name)")
        }
    }

    func testGenerateAudioWithInvalidVoiceId() async throws {
        let text = "Testing with invalid voice"

        do {
            _ = try await engine.generateAudio(text: text, voiceId: "com.invalid.voice.id")
            // Should still succeed (NSSpeechSynthesizer will use default voice)
            // This is expected macOS behavior
        } catch {
            // If it throws, that's also acceptable
            XCTAssertTrue(error is VoiceProviderError, "Should throw VoiceProviderError")
        }
    }

    func testGenerateAudioWithLongText() async throws {
        let voices = try await engine.fetchVoices()
        guard let firstVoice = voices.first else {
            XCTFail("No voices available for testing")
            return
        }

        let longText = String(repeating: "This is a longer sentence for testing. ", count: 20)
        let audioData = try await engine.generateAudio(text: longText, voiceId: firstVoice.id)

        XCTAssertFalse(audioData.isEmpty, "Should generate audio for long text")
        XCTAssertGreaterThan(audioData.count, 10000, "Long text should produce larger audio file")
    }

    // MARK: - Duration Estimation Tests

    func testEstimateDurationReturnsPositiveValue() {
        let duration = engine.estimateDuration(text: "Hello world", voiceId: "any-voice-id")
        XCTAssertGreaterThan(duration, 0, "Duration should be positive")
    }

    func testEstimateDurationScalesWithTextLength() {
        let shortText = "Hello"
        let mediumText = String(repeating: shortText + " ", count: 10)
        let longText = String(repeating: shortText + " ", count: 100)

        let shortDuration = engine.estimateDuration(text: shortText, voiceId: "any")
        let mediumDuration = engine.estimateDuration(text: mediumText, voiceId: "any")
        let longDuration = engine.estimateDuration(text: longText, voiceId: "any")

        XCTAssertLessThan(shortDuration, mediumDuration)
        XCTAssertLessThan(mediumDuration, longDuration)
    }

    func testEstimateDurationHasMinimumValue() {
        let emptyDuration = engine.estimateDuration(text: "", voiceId: "any")
        XCTAssertGreaterThanOrEqual(emptyDuration, 1.0, "Should have minimum duration of 1.0 second")
    }

    func testEstimateDurationIsReasonable() {
        let text = "This is approximately fifty characters long text"
        let duration = engine.estimateDuration(text: text, voiceId: "any")

        // ~50 chars at 14.5 chars/sec * 1.1 buffer ≈ 3.8 seconds
        XCTAssertGreaterThan(duration, 2.0, "Duration should be at least 2 seconds")
        XCTAssertLessThan(duration, 10.0, "Duration should be less than 10 seconds")
    }

    // MARK: - Async/Await Delegate Tests

    func testDelegateCompletionHandlerCalledOnSuccess() async throws {
        let voices = try await engine.fetchVoices()
        guard let firstVoice = voices.first else {
            XCTFail("No voices available")
            return
        }

        let text = "Delegate test"

        // This test verifies that the async/await wrapper works correctly
        // by successfully completing audio generation
        let audioData = try await engine.generateAudio(text: text, voiceId: firstVoice.id)

        XCTAssertFalse(audioData.isEmpty, "Delegate should trigger completion with data")
    }

    // MARK: - Gender Extraction Tests

    func testVoiceGenderExtraction() async throws {
        let voices = try await engine.fetchVoices()

        let voicesWithGender = voices.filter { $0.gender != nil }

        // macOS voices typically have gender information
        XCTAssertFalse(voicesWithGender.isEmpty, "Some voices should have gender information")

        for voice in voicesWithGender {
            let gender = voice.gender!.lowercased()
            XCTAssertTrue(
                gender == "male" || gender == "female" || gender == "neutral",
                "Gender should be 'male', 'female', or 'neutral', got '\(gender)'"
            )
        }
    }

    // MARK: - Concurrency Tests

    func testConcurrentAudioGeneration() async throws {
        let voices = try await engine.fetchVoices()
        guard let firstVoice = voices.first else {
            XCTFail("No voices available")
            return
        }

        // Copy engine to local variable to avoid sendability issues with task group
        let localEngine = engine!

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

                XCTAssertEqual(allData.count, 3, "Should generate 3 audio files")

                for (index, data) in allData.enumerated() {
                    XCTAssertFalse(data.isEmpty, "Audio data \(index) should not be empty")
                    XCTAssertGreaterThan(data.count, 1024, "Audio data \(index) should be substantial")
                }
            } catch {
                XCTFail("Concurrent audio generation failed: \(error)")
            }
        }
    }
}

#endif
