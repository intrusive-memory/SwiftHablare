//
//  AppleTTSEngineProtocolTests.swift
//  SwiftHablareTests
//
//  Protocol conformance tests for AppleTTSEngine implementations
//

import XCTest
import AVFoundation
@testable import SwiftHablare

/// Tests that verify both iOS and macOS engines properly conform to AppleTTSEngine protocol
@MainActor
final class AppleTTSEngineProtocolTests: XCTestCase {

    // Platform-specific engine instance
    var engine: AppleTTSEngine!

    override func setUp() {
        super.setUp()

        // Create platform-appropriate engine
        #if os(iOS) || targetEnvironment(macCatalyst)
        engine = AVSpeechTTSEngine()
        #elseif os(macOS)
        engine = NSSpeechTTSEngine()
        #else
        XCTFail("Unsupported platform")
        #endif
    }

    override func tearDown() {
        engine = nil
        super.tearDown()
    }

    // MARK: - Protocol Method Signature Tests

    func testEngineConformsToSendable() {
        // This test verifies that the engine type conforms to Sendable
        // which is required by the protocol for Swift 6 concurrency
        XCTAssertTrue(type(of: engine) is Sendable.Type,
                     "Engine should conform to Sendable protocol")
    }

    // MARK: - fetchVoices() Protocol Tests

    func testFetchVoicesReturnsVoiceArray() async throws {
        let voices = try await engine.fetchVoices()

        // Verify return type is [Voice]
        XCTAssertTrue(voices is [Voice], "Should return array of Voice objects")
    }

    func testFetchVoicesDoesNotReturnEmpty() async throws {
        let voices = try await engine.fetchVoices()

        // All platforms should have at least one voice
        XCTAssertFalse(voices.isEmpty, "Should return at least one voice")
    }

    func testFetchVoicesReturnsConsistentResults() async throws {
        let voices1 = try await engine.fetchVoices()
        let voices2 = try await engine.fetchVoices()

        // Should return similar number of voices (within tolerance for dynamic changes)
        let difference = abs(voices1.count - voices2.count)
        XCTAssertLessThanOrEqual(difference, 5, "Voice counts should be consistent across calls")
    }

    func testFetchVoicesAllHaveProviderId() async throws {
        let voices = try await engine.fetchVoices()

        for voice in voices {
            XCTAssertEqual(voice.providerId, "apple",
                          "All voices should have providerId 'apple'")
        }
    }

    // MARK: - generateAudio() Protocol Tests

    func testGenerateAudioReturnsData() async throws {
        let voices = try await engine.fetchVoices()
        guard let firstVoice = voices.first else {
            XCTFail("No voices available")
            return
        }

        let audioData = try await engine.generateAudio(text: "Test", voiceId: firstVoice.id)

        // Verify return type is Data
        XCTAssertTrue(audioData is Data, "Should return Data object")
    }

    func testGenerateAudioWithValidInputSucceeds() async throws {
        let voices = try await engine.fetchVoices()
        guard let firstVoice = voices.first else {
            XCTFail("No voices available")
            return
        }

        let audioData = try await engine.generateAudio(
            text: "Hello world",
            voiceId: firstVoice.id
        )

        XCTAssertFalse(audioData.isEmpty, "Should generate non-empty audio data")
    }

    func testGenerateAudioWithEmptyTextThrows() async throws {
        let voices = try await engine.fetchVoices()
        guard let firstVoice = voices.first else {
            XCTFail("No voices available")
            return
        }

        do {
            _ = try await engine.generateAudio(text: "", voiceId: firstVoice.id)
            XCTFail("Should throw error for empty text")
        } catch {
            // Expected to throw
            XCTAssertTrue(error is VoiceProviderError,
                         "Should throw VoiceProviderError")
        }
    }

    func testGenerateAudioThrowsVoiceProviderError() async throws {
        let voices = try await engine.fetchVoices()
        guard let firstVoice = voices.first else {
            XCTFail("No voices available")
            return
        }

        do {
            _ = try await engine.generateAudio(text: "", voiceId: firstVoice.id)
            XCTFail("Should throw error")
        } catch let error as VoiceProviderError {
            // Verify it's the correct error type
            switch error {
            case .invalidRequest:
                // Expected
                break
            case .networkError:
                // Also acceptable
                break
            default:
                XCTFail("Unexpected error type: \(error)")
            }
        } catch {
            XCTFail("Should throw VoiceProviderError, got \(type(of: error))")
        }
    }

    // MARK: - estimateDuration() Protocol Tests

    func testEstimateDurationReturnsTimeInterval() {
        let duration = engine.estimateDuration(text: "Test", voiceId: "any")

        // Verify return type is TimeInterval (Double)
        XCTAssertTrue(duration is TimeInterval, "Should return TimeInterval")
    }

    func testEstimateDurationReturnsPositiveValue() {
        let duration = engine.estimateDuration(text: "Hello world", voiceId: "any")

        XCTAssertGreaterThan(duration, 0, "Duration should always be positive")
    }

    func testEstimateDurationWithEmptyTextReturnsMinimum() {
        let duration = engine.estimateDuration(text: "", voiceId: "any")

        // Protocol expects minimum of 1.0 second
        XCTAssertGreaterThanOrEqual(duration, 1.0,
                                   "Empty text should return minimum duration of 1.0 second")
    }

    func testEstimateDurationScalesWithLength() {
        let shortText = "Hi"
        let longText = String(repeating: "This is a much longer text. ", count: 10)

        let shortDuration = engine.estimateDuration(text: shortText, voiceId: "any")
        let longDuration = engine.estimateDuration(text: longText, voiceId: "any")

        XCTAssertLessThan(shortDuration, longDuration,
                         "Duration should scale with text length")
    }

    func testEstimateDurationIsConsistent() {
        let text = "Consistent test text"
        let voiceId = "any-voice-id"

        let duration1 = engine.estimateDuration(text: text, voiceId: voiceId)
        let duration2 = engine.estimateDuration(text: text, voiceId: voiceId)

        XCTAssertEqual(duration1, duration2, accuracy: 0.01,
                      "Duration estimation should be consistent")
    }

    // MARK: - Cross-Method Integration Tests

    func testFetchVoicesThenGenerateAudio() async throws {
        // Verify that voices from fetchVoices() can be used in generateAudio()
        let voices = try await engine.fetchVoices()
        guard let voice = voices.first else {
            XCTFail("No voices available")
            return
        }

        let audioData = try await engine.generateAudio(
            text: "Integration test",
            voiceId: voice.id
        )

        XCTAssertFalse(audioData.isEmpty, "Should generate audio with fetched voice")
    }

    func testEstimateDurationMatchesGeneratedAudio() async throws {
        #if targetEnvironment(simulator) || targetEnvironment(macCatalyst)
        throw XCTSkip("Duration validation test skipped on simulator/Catalyst - audio generation doesn't produce valid audio buffers")
        #else
        let voices = try await engine.fetchVoices()
        guard let voice = voices.first else {
            XCTFail("No voices available")
            return
        }

        let text = "Duration matching test with reasonable length text"
        let estimatedDuration = engine.estimateDuration(text: text, voiceId: voice.id)
        let audioData = try await engine.generateAudio(text: text, voiceId: voice.id)

        // Write to temp file to get actual duration
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("aiff")

        try audioData.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let audioFile = try AVAudioFile(forReading: tempURL)
        let actualDuration = Double(audioFile.length) / audioFile.fileFormat.sampleRate

        // Estimation should be within 50% of actual (rough estimation)
        let tolerance = actualDuration * 0.5
        XCTAssertEqual(estimatedDuration, actualDuration, accuracy: tolerance,
                      "Estimated duration should be reasonably close to actual")
        #endif
    }

    // MARK: - Error Handling Tests

    func testGenerateAudioErrorIsThrowable() async {
        let voices: [Voice]
        do {
            voices = try await engine.fetchVoices()
        } catch {
            XCTFail("fetchVoices should not throw")
            return
        }

        guard let voice = voices.first else {
            XCTFail("No voices available")
            return
        }

        // Test that errors can be caught properly
        var didThrow = false
        do {
            _ = try await engine.generateAudio(text: "", voiceId: voice.id)
        } catch {
            didThrow = true
        }

        XCTAssertTrue(didThrow, "Should be able to catch thrown errors")
    }

    // MARK: - Concurrency Tests

    func testEngineIsThreadSafe() async throws {
        let voices = try await engine.fetchVoices()
        guard let voice = voices.first else {
            XCTFail("No voices available")
            return
        }

        // Copy engine to local variable to avoid sendability issues with async let
        let localEngine = engine!

        // Call multiple methods concurrently
        async let voices1 = localEngine.fetchVoices()
        async let audio1 = localEngine.generateAudio(text: "Test 1", voiceId: voice.id)
        async let audio2 = localEngine.generateAudio(text: "Test 2", voiceId: voice.id)
        let duration = localEngine.estimateDuration(text: "Test", voiceId: voice.id)

        // Wait for all to complete
        let results = try await [voices1.count, audio1.count, audio2.count]

        XCTAssertGreaterThan(results[0], 0, "Should fetch voices concurrently")
        XCTAssertGreaterThan(results[1], 0, "Should generate audio 1 concurrently")
        XCTAssertGreaterThan(results[2], 0, "Should generate audio 2 concurrently")
        XCTAssertGreaterThan(duration, 0, "Should estimate duration concurrently")
    }
}
