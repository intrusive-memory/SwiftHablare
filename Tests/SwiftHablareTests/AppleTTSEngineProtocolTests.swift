//
//  AppleTTSEngineProtocolTests.swift
//  SwiftHablareTests
//
//  Protocol conformance tests for AppleTTSEngine implementations
//

import Testing
import AVFoundation
@testable import SwiftHablare

/// Tests that verify both iOS and macOS engines properly conform to AppleTTSEngine protocol
@Suite
@MainActor
struct AppleTTSEngineProtocolTests {

    // Unified engine instance for all platforms
    var engine: AppleTTSEngine

    init() {
        // Create AVSpeechTTSEngine for all platforms
        self.engine = AVSpeechTTSEngine()
    }

    // MARK: - Protocol Method Signature Tests

    @Test
    func engineConformsToSendable() {
        // This test verifies that the engine type conforms to Sendable
        // which is required by the protocol for Swift 6 concurrency
        #expect(type(of: engine) is Sendable.Type)
    }

    // MARK: - fetchVoices() Protocol Tests

    @Test
    func fetchVoicesReturnsVoiceArray() async throws {
        let voices = try await engine.fetchVoices()

        // Verify return type is [Voice]
        #expect(voices is [Voice])
    }

    @Test
    func fetchVoicesDoesNotReturnEmpty() async throws {
        let voices = try await engine.fetchVoices()

        // Note: GitHub Actions runners may not have TTS voices installed
        // This test will pass if voices are empty on CI environments
        if voices.isEmpty {
            Issue.record("No Apple TTS voices available. This is expected on GitHub Actions runners.")
        }
    }

    @Test
    func fetchVoicesReturnsConsistentResults() async throws {
        let voices1 = try await engine.fetchVoices()
        let voices2 = try await engine.fetchVoices()

        // Should return similar number of voices (within tolerance for dynamic changes)
        let difference = abs(voices1.count - voices2.count)
        #expect(difference <= 5)
    }

    @Test
    func fetchVoicesAllHaveProviderId() async throws {
        let voices = try await engine.fetchVoices()

        for voice in voices {
            #expect(voice.providerId == "apple")
        }
    }

    // MARK: - generateAudio() Protocol Tests

    @Test
    func generateAudioReturnsData() async throws {
        let voices = try await engine.fetchVoices()
        guard let firstVoice = voices.first else {
            Issue.record("No voices available")
            return
        }

        let audioData = try await engine.generateAudio(text: "Test", voiceId: firstVoice.id)

        // Verify return type is Data
        #expect(audioData is Data)
    }

    @Test
    func generateAudioWithValidInputSucceeds() async throws {
        let voices = try await engine.fetchVoices()
        guard let firstVoice = voices.first else {
            Issue.record("No voices available")
            return
        }

        let audioData = try await engine.generateAudio(
            text: "Hello world",
            voiceId: firstVoice.id
        )

        #expect(!audioData.isEmpty)
    }

    @Test
    func generateAudioWithEmptyTextThrows() async throws {
        let voices = try await engine.fetchVoices()
        guard let firstVoice = voices.first else {
            Issue.record("No voices available")
            return
        }

        do {
            _ = try await engine.generateAudio(text: "", voiceId: firstVoice.id)
            Issue.record("Should throw error for empty text")
        } catch {
            // Expected to throw
            #expect(error is VoiceProviderError)
        }
    }

    @Test
    func generateAudioThrowsVoiceProviderError() async throws {
        let voices = try await engine.fetchVoices()
        guard let firstVoice = voices.first else {
            Issue.record("No voices available")
            return
        }

        do {
            _ = try await engine.generateAudio(text: "", voiceId: firstVoice.id)
            Issue.record("Should throw error")
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
                Issue.record("Unexpected error type: \(error)")
            }
        } catch {
            Issue.record("Should throw VoiceProviderError, got \(type(of: error))")
        }
    }

    // MARK: - estimateDuration() Protocol Tests

    @Test
    func estimateDurationReturnsTimeInterval() {
        let duration = engine.estimateDuration(text: "Test", voiceId: "any")

        // Verify return type is TimeInterval (Double)
        #expect(duration is TimeInterval)
    }

    @Test
    func estimateDurationReturnsPositiveValue() {
        let duration = engine.estimateDuration(text: "Hello world", voiceId: "any")

        #expect(duration > 0)
    }

    @Test
    func estimateDurationWithEmptyTextReturnsMinimum() {
        let duration = engine.estimateDuration(text: "", voiceId: "any")

        // Protocol expects minimum of 1.0 second
        #expect(duration >= 1.0)
    }

    @Test
    func estimateDurationScalesWithLength() {
        let shortText = "Hi"
        let longText = String(repeating: "This is a much longer text. ", count: 10)

        let shortDuration = engine.estimateDuration(text: shortText, voiceId: "any")
        let longDuration = engine.estimateDuration(text: longText, voiceId: "any")

        #expect(shortDuration < longDuration)
    }

    @Test
    func estimateDurationIsConsistent() {
        let text = "Consistent test text"
        let voiceId = "any-voice-id"

        let duration1 = engine.estimateDuration(text: text, voiceId: voiceId)
        let duration2 = engine.estimateDuration(text: text, voiceId: voiceId)

        #expect(duration1 == duration2)
    }

    // MARK: - Cross-Method Integration Tests

    @Test
    func fetchVoicesThenGenerateAudio() async throws {
        // Verify that voices from fetchVoices() can be used in generateAudio()
        let voices = try await engine.fetchVoices()
        guard let voice = voices.first else {
            Issue.record("No voices available")
            return
        }

        let audioData = try await engine.generateAudio(
            text: "Integration test",
            voiceId: voice.id
        )

        #expect(!audioData.isEmpty)
    }

    // MARK: - Error Handling Tests

    @Test
    func generateAudioErrorIsThrowable() async {
        let voices: [Voice]
        do {
            voices = try await engine.fetchVoices()
        } catch {
            Issue.record("fetchVoices should not throw")
            return
        }

        guard let voice = voices.first else {
            Issue.record("No voices available")
            return
        }

        // Test that errors can be caught properly
        var didThrow = false
        do {
            _ = try await engine.generateAudio(text: "", voiceId: voice.id)
        } catch {
            didThrow = true
        }

        #expect(didThrow)
    }

    // MARK: - Concurrency Tests

    @Test
    func engineIsThreadSafe() async throws {
        let voices = try await engine.fetchVoices()
        guard let voice = voices.first else {
            Issue.record("No voices available")
            return
        }

        // Copy engine to local variable to avoid sendability issues with async let
        let localEngine = engine

        // Call multiple methods concurrently
        async let voices1 = localEngine.fetchVoices()
        async let audio1 = localEngine.generateAudio(text: "Test 1", voiceId: voice.id)
        async let audio2 = localEngine.generateAudio(text: "Test 2", voiceId: voice.id)
        let duration = localEngine.estimateDuration(text: "Test", voiceId: voice.id)

        // Wait for all to complete
        let results = try await [voices1.count, audio1.count, audio2.count]

        #expect(results[0] > 0)
        #expect(results[1] > 0)
        #expect(results[2] > 0)
        #expect(duration > 0)
    }
}
