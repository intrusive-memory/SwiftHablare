//
//  AVSpeechTTSEngineTests.swift
//  SwiftHablareTests
//
//  Tests for iOS AVSpeechTTSEngine implementation
//

#if canImport(UIKit)
import XCTest
import AVFoundation
@testable import SwiftHablare

@available(iOS 13.0, *)
final class AVSpeechTTSEngineTests: XCTestCase {

    var engine: AVSpeechTTSEngine!

    override func setUp() {
        super.setUp()
        engine = AVSpeechTTSEngine()
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
        }
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

    // MARK: - Platform-Specific Tests

    #if targetEnvironment(simulator)
    func testSimulatorGeneratesPlaceholderAudio() async throws {
        let voices = try await engine.fetchVoices()
        guard let firstVoice = voices.first else {
            XCTFail("No voices available")
            return
        }

        let text = "Simulator test"
        let audioData = try await engine.generateAudio(text: text, voiceId: firstVoice.id)

        // Should still get valid audio data (placeholder)
        XCTAssertFalse(audioData.isEmpty)
        XCTAssertGreaterThan(audioData.count, 1024)
    }
    #else
    func testPhysicalDeviceGeneratesRealAudio() async throws {
        let voices = try await engine.fetchVoices()
        guard let firstVoice = voices.first else {
            XCTFail("No voices available")
            return
        }

        let text = "Physical device test"
        let audioData = try await engine.generateAudio(text: text, voiceId: firstVoice.id)

        // Should get real TTS audio
        XCTAssertFalse(audioData.isEmpty)
        XCTAssertGreaterThan(audioData.count, 1024)

        // Verify it's AIFC format (real TTS output)
        let header = audioData.prefix(12)
        let headerString = String(data: header, encoding: .ascii) ?? ""
        // Real TTS typically produces AIFC format
        XCTAssertTrue(headerString.contains("FORM") || headerString.contains("AIFC") || headerString.contains("AIFF"),
                     "Should be AIFF/AIFC format")
    }
    #endif
}

#endif
