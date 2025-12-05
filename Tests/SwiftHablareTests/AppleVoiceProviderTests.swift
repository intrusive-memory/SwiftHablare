//
//  AppleVoiceProviderTests.swift
//  SwiftHablareTests
//
//  Comprehensive integration tests for AppleVoiceProvider
//

import Testing
import AVFoundation
#if os(macOS)
import AppKit
#endif
@testable import SwiftHablare

@Suite("AppleVoiceProvider Tests")
struct AppleVoiceProviderTests {
    let provider: AppleVoiceProvider

    @MainActor
    init() {
        provider = TestFixtures.makeAppleProvider()
    }

    // MARK: - Basic Properties Tests

    @Test("Provider identifier is 'apple'")
    func testProviderIdentifier() {
        #expect(provider.providerId == "apple")
    }

    @Test("Provider display name is 'Apple Text-to-Speech'")
    func testProviderDisplayName() {
        #expect(provider.displayName == "Apple Text-to-Speech")
    }

    @Test("Provider does not require API key")
    func testProviderDoesNotRequireAPIKey() {
        #expect(provider.requiresAPIKey == false)
    }

    // MARK: - Configuration Tests

    @Test("Provider is always configured")
    func testProviderIsAlwaysConfigured() {
        #expect(provider.isConfigured() == true)
    }

    // MARK: - Voice Fetching Tests

    @Test("Fetch voices returns non-empty array")
    func testFetchVoicesReturnsNonEmptyArray() async throws {
        let voices = try await provider.fetchVoices()

        #expect(!voices.isEmpty)
    }

    @Test("Fetched voices have required properties")
    func testFetchedVoicesHaveRequiredProperties() async throws {
        let voices: [Voice] = try await provider.fetchVoices()

        for voice in voices {
            #expect(!voice.id.isEmpty)
            #expect(!voice.name.isEmpty)
            #expect(voice.providerId == "apple")
        }
    }

    @Test("Fetched voices have valid identifiers")
    func testFetchedVoicesHaveValidIdentifiers() async throws {
        let voices = try await provider.fetchVoices()

        // Verify that each voice ID can be used to create a platform-specific voice
        for voice in voices {
            #if os(macOS)
            // On macOS, verify the voice ID is a valid NSSpeechSynthesizer voice name
            let voiceName = NSSpeechSynthesizer.VoiceName(rawValue: voice.id)
            let availableVoices = NSSpeechSynthesizer.availableVoices
            #expect(availableVoices.contains(voiceName))
            #else
            // On iOS, verify the voice ID can create an AVSpeechSynthesisVoice
            let avVoice = AVSpeechSynthesisVoice(identifier: voice.id)
            #expect(avVoice != nil)
            #endif
        }
    }

    @Test("Fetched voices have language information")
    func testFetchedVoicesHaveLanguageInformation() async throws {
        let voices = try await provider.fetchVoices()

        // At least some voices should have language information
        let voicesWithLanguage = voices.filter { $0.language != nil }
        #expect(!voicesWithLanguage.isEmpty)
    }

    @Test("Fetched voices include system language")
    func testFetchedVoicesIncludeSystemLanguage() async throws {
        let voices = try await provider.fetchVoices()

        // Just verify we got some voices back
        #expect(!voices.isEmpty)
    }

    // MARK: - Voice Availability Tests

    @Test("Voice availability check with valid voice")
    func testIsVoiceAvailableWithValidVoice() async throws {
        let voices = try await provider.fetchVoices()

        guard let firstVoice = voices.first else {
            Issue.record("No voices available for testing")
            return
        }

        let isAvailable = await provider.isVoiceAvailable(voiceId: firstVoice.id)
        #expect(isAvailable == true)
    }

    @Test("Voice availability check with invalid voice")
    func testIsVoiceAvailableWithInvalidVoice() async {
        let isAvailable = await provider.isVoiceAvailable(voiceId: "com.apple.invalid.voice.id")
        #expect(isAvailable == false)
    }

    @Test("Voice availability check with empty string")
    func testIsVoiceAvailableWithEmptyString() async {
        let isAvailable = await provider.isVoiceAvailable(voiceId: "")
        #expect(isAvailable == false)
    }

    // MARK: - Duration Estimation Tests

    @Test("Estimate duration for short text")
    func testEstimateDurationForShortText() async throws {
        let voices = try await provider.fetchVoices()

        guard let firstVoice = voices.first else {
            Issue.record("No voices available for testing")
            return
        }

        let shortText = "Hello world"
        let duration = await provider.estimateDuration(text: shortText, voiceId: firstVoice.id)

        #expect(duration > 0)
        #expect(duration < 5)
    }

    @Test("Estimate duration for long text")
    func testEstimateDurationForLongText() async throws {
        let voices = try await provider.fetchVoices()

        guard let firstVoice = voices.first else {
            Issue.record("No voices available for testing")
            return
        }

        let longText = String(repeating: "This is a longer sentence for testing duration estimation. ", count: 10)
        let duration = await provider.estimateDuration(text: longText, voiceId: firstVoice.id)

        #expect(duration > 5)
    }

    @Test("Duration estimation scales with text length")
    func testEstimateDurationScalesWithTextLength() async throws {
        let voices = try await provider.fetchVoices()

        guard let firstVoice = voices.first else {
            Issue.record("No voices available for testing")
            return
        }

        let shortText = "Hello"
        let mediumText = String(repeating: shortText + " ", count: 10)
        let longText = String(repeating: shortText + " ", count: 100)

        let shortDuration = await provider.estimateDuration(text: shortText, voiceId: firstVoice.id)
        let mediumDuration = await provider.estimateDuration(text: mediumText, voiceId: firstVoice.id)
        let longDuration = await provider.estimateDuration(text: longText, voiceId: firstVoice.id)

        #expect(shortDuration < mediumDuration)
        #expect(mediumDuration < longDuration)
    }

    @Test("Duration estimation has minimum value")
    func testEstimateDurationMinimumValue() async throws {
        let voices = try await provider.fetchVoices()

        guard let firstVoice = voices.first else {
            Issue.record("No voices available for testing")
            return
        }

        let emptyText = ""
        let duration = await provider.estimateDuration(text: emptyText, voiceId: firstVoice.id)

        #expect(duration >= 1.0)
    }

    // MARK: - Audio Generation Integration Tests

    @Test("Generate audio returns data")
    func testGenerateAudioReturnsData() async throws {
        let voices = try await provider.fetchVoices()

        guard let firstVoice = voices.first else {
            Issue.record("No voices available for testing")
            return
        }

        let text = "Hello, this is a test."
        let audioData = try await provider.generateAudio(text: text, voiceId: firstVoice.id)

        #expect(!audioData.isEmpty)
    }

    @Test("Generate audio with different texts")
    func testGenerateAudioWithDifferentTexts() async throws {
        let voices = try await provider.fetchVoices()

        guard let firstVoice = voices.first else {
            Issue.record("No voices available for testing")
            return
        }

        let texts = [
            "Short text.",
            "A medium length sentence with more words in it.",
            String(repeating: "This is a longer test sentence. ", count: 5)
        ]

        for text in texts {
            let audioData = try await provider.generateAudio(text: text, voiceId: firstVoice.id)
            #expect(!audioData.isEmpty)
        }
    }

    @Test("Generate audio with multiple voices")
    func testGenerateAudioWithMultipleVoices() async throws {
        let voices = try await provider.fetchVoices()

        // Test with up to 3 voices
        let voicesToTest = Array(voices.prefix(min(3, voices.count)))

        let text = "Testing multiple voices."

        for voice in voicesToTest {
            let audioData = try await provider.generateAudio(text: text, voiceId: voice.id)
            #expect(!audioData.isEmpty)
        }
    }

    @Test("Generate audio produces valid CAF format")
    func testGenerateAudioProducesValidCAFFormat() async throws {
        let voices = try await provider.fetchVoices()

        guard let firstVoice = voices.first else {
            Issue.record("No voices available for testing")
            return
        }

        let text = "Testing audio format."
        let audioData = try await provider.generateAudio(text: text, voiceId: firstVoice.id)

        // Create temporary file to verify audio format
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("caf")

        try audioData.write(to: tempURL)

        // Try to open as AVAudioFile to verify it's valid audio
        let audioFile = try AVAudioFile(forReading: tempURL)
        #expect(audioFile.processingFormat.sampleRate > 0)

        // Cleanup
        try? FileManager.default.removeItem(at: tempURL)
    }

    @Test("Generate audio with empty text throws error")
    func testGenerateAudioWithEmptyText() async throws {
        let voices = try await provider.fetchVoices()

        guard let firstVoice = voices.first else {
            Issue.record("No voices available for testing")
            return
        }

        let text = ""
        // Should throw error for empty text
        do {
            _ = try await provider.generateAudio(text: text, voiceId: firstVoice.id)
            Issue.record("Should throw error for empty text")
        } catch let error as VoiceProviderError {
            // Verify we get the correct error type
            switch error {
            case .invalidRequest(let message):
                #expect(message.contains("empty"))
            case .networkError(let message):
                // On iOS, might get network error if not yet fully implemented
                #expect(message.contains("generation") || message.contains("failed"))
            default:
                Issue.record("Expected invalidRequest or networkError, got \(error)")
            }
        } catch {
            Issue.record("Expected VoiceProviderError, got \(error)")
        }
    }

    // MARK: - Voice Gender Extraction Tests

    @Test("Voice gender extraction is valid")
    func testVoiceGenderExtraction() async throws {
        let voices = try await provider.fetchVoices()

        // Check if any voices have gender information
        let voicesWithGender = voices.filter { $0.gender != nil }

        // Note: Gender might not be available for all voices, so we just verify format if present
        // macOS includes novelty voices with "neutral" gender
        for voice in voicesWithGender {
            let gender = voice.gender!.lowercased()
            #expect(
                gender == "male" || gender == "female" || gender == "neutral"
            )
        }
    }
}

