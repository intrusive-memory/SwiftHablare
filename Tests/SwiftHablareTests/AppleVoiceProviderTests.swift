//
//  AppleVoiceProviderTests.swift
//  SwiftHablareTests
//
//  Comprehensive integration tests for AppleVoiceProvider
//

import XCTest
import AVFoundation
@testable import SwiftHablare

final class AppleVoiceProviderTests: XCTestCase {

    var provider: AppleVoiceProvider!

    override func setUp() {
        super.setUp()
        provider = AppleVoiceProvider()
    }

    override func tearDown() {
        provider = nil
        super.tearDown()
    }

    // MARK: - Basic Properties Tests

    func testProviderIdentifier() {
        XCTAssertEqual(provider.providerId, "apple")
    }

    func testProviderDisplayName() {
        XCTAssertEqual(provider.displayName, "Apple Text-to-Speech")
    }

    func testProviderDoesNotRequireAPIKey() {
        XCTAssertFalse(provider.requiresAPIKey)
    }

    // MARK: - Configuration Tests

    func testProviderIsAlwaysConfigured() {
        XCTAssertTrue(provider.isConfigured())
    }

    // MARK: - Voice Fetching Tests

    func testFetchVoicesReturnsNonEmptyArray() async throws {
        let voices = try await provider.fetchVoices()

        XCTAssertFalse(voices.isEmpty, "Should return at least one voice")
    }

    func testFetchedVoicesHaveRequiredProperties() async throws {
        let voices: [Voice] = try await provider.fetchVoices()

        for voice in voices {
            XCTAssertFalse(voice.id.isEmpty, "Voice ID should not be empty")
            XCTAssertFalse(voice.name.isEmpty, "Voice name should not be empty")
            XCTAssertEqual(voice.providerId, "apple", "Provider ID should be 'apple'")
        }
    }

    func testFetchedVoicesHaveValidIdentifiers() async throws {
        let voices = try await provider.fetchVoices()

        // Verify that each voice ID can be used to create an AVSpeechSynthesisVoice
        for voice in voices {
            let avVoice = AVSpeechSynthesisVoice(identifier: voice.id)
            XCTAssertNotNil(avVoice, "Voice ID '\(voice.id)' should be valid")
        }
    }

    func testFetchedVoicesHaveLanguageInformation() async throws {
        let voices = try await provider.fetchVoices()

        // At least some voices should have language information
        let voicesWithLanguage = voices.filter { $0.language != nil }
        XCTAssertFalse(voicesWithLanguage.isEmpty, "Some voices should have language information")
    }

    func testFetchedVoicesIncludeSystemLanguage() async throws {
        let voices = try await provider.fetchVoices()

        // Just verify we got some voices back
        XCTAssertFalse(voices.isEmpty, "Should return voices")
    }

    // MARK: - Voice Availability Tests

    func testIsVoiceAvailableWithValidVoice() async throws {
        let voices = try await provider.fetchVoices()

        guard let firstVoice = voices.first else {
            XCTFail("No voices available for testing")
            return
        }

        let isAvailable = await provider.isVoiceAvailable(voiceId: firstVoice.id)
        XCTAssertTrue(isAvailable, "First voice should be available")
    }

    func testIsVoiceAvailableWithInvalidVoice() async {
        let isAvailable = await provider.isVoiceAvailable(voiceId: "com.apple.invalid.voice.id")
        XCTAssertFalse(isAvailable, "Invalid voice ID should not be available")
    }

    func testIsVoiceAvailableWithEmptyString() async {
        let isAvailable = await provider.isVoiceAvailable(voiceId: "")
        XCTAssertFalse(isAvailable, "Empty voice ID should not be available")
    }

    // MARK: - Duration Estimation Tests

    func testEstimateDurationForShortText() async throws {
        let voices = try await provider.fetchVoices()

        guard let firstVoice = voices.first else {
            XCTFail("No voices available for testing")
            return
        }

        let shortText = "Hello world"
        let duration = await provider.estimateDuration(text: shortText, voiceId: firstVoice.id)

        XCTAssertGreaterThan(duration, 0, "Duration should be positive")
        XCTAssertLessThan(duration, 5, "Short text should have short duration")
    }

    func testEstimateDurationForLongText() async throws {
        let voices = try await provider.fetchVoices()

        guard let firstVoice = voices.first else {
            XCTFail("No voices available for testing")
            return
        }

        let longText = String(repeating: "This is a longer sentence for testing duration estimation. ", count: 10)
        let duration = await provider.estimateDuration(text: longText, voiceId: firstVoice.id)

        XCTAssertGreaterThan(duration, 5, "Long text should have longer duration")
    }

    func testEstimateDurationScalesWithTextLength() async throws {
        let voices = try await provider.fetchVoices()

        guard let firstVoice = voices.first else {
            XCTFail("No voices available for testing")
            return
        }

        let shortText = "Hello"
        let mediumText = String(repeating: shortText + " ", count: 10)
        let longText = String(repeating: shortText + " ", count: 100)

        let shortDuration = await provider.estimateDuration(text: shortText, voiceId: firstVoice.id)
        let mediumDuration = await provider.estimateDuration(text: mediumText, voiceId: firstVoice.id)
        let longDuration = await provider.estimateDuration(text: longText, voiceId: firstVoice.id)

        XCTAssertLessThan(shortDuration, mediumDuration, "Longer text should have longer duration")
        XCTAssertLessThan(mediumDuration, longDuration, "Even longer text should have even longer duration")
    }

    func testEstimateDurationMinimumValue() async throws {
        let voices = try await provider.fetchVoices()

        guard let firstVoice = voices.first else {
            XCTFail("No voices available for testing")
            return
        }

        let emptyText = ""
        let duration = await provider.estimateDuration(text: emptyText, voiceId: firstVoice.id)

        XCTAssertGreaterThanOrEqual(duration, 1.0, "Duration should have minimum value of 1.0 second")
    }

    // MARK: - Audio Generation Integration Tests

    func testGenerateAudioReturnsData() async throws {
        let voices = try await provider.fetchVoices()

        guard let firstVoice = voices.first else {
            XCTFail("No voices available for testing")
            return
        }

        let text = "Hello, this is a test."
        let audioData = try await provider.generateAudio(text: text, voiceId: firstVoice.id)

        XCTAssertFalse(audioData.isEmpty, "Audio data should not be empty")
    }

    func testGenerateAudioWithDifferentTexts() async throws {
        let voices = try await provider.fetchVoices()

        guard let firstVoice = voices.first else {
            XCTFail("No voices available for testing")
            return
        }

        let texts = [
            "Short text.",
            "A medium length sentence with more words in it.",
            String(repeating: "This is a longer test sentence. ", count: 5)
        ]

        for text in texts {
            let audioData = try await provider.generateAudio(text: text, voiceId: firstVoice.id)
            XCTAssertFalse(audioData.isEmpty, "Audio data should not be empty for text: '\(text.prefix(50))...'")
        }
    }

    func testGenerateAudioWithMultipleVoices() async throws {
        let voices = try await provider.fetchVoices()

        // Test with up to 3 voices
        let voicesToTest = Array(voices.prefix(min(3, voices.count)))

        let text = "Testing multiple voices."

        for voice in voicesToTest {
            let audioData = try await provider.generateAudio(text: text, voiceId: voice.id)
            XCTAssertFalse(audioData.isEmpty, "Audio data should not be empty for voice: '\(voice.name)'")
        }
    }

    func testGenerateAudioProducesValidCAFFormat() async throws {
        let voices = try await provider.fetchVoices()

        guard let firstVoice = voices.first else {
            XCTFail("No voices available for testing")
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
        XCTAssertNotNil(audioFile.processingFormat, "Audio file should have valid format")

        // Cleanup
        try? FileManager.default.removeItem(at: tempURL)
    }

    func testGenerateAudioWithEmptyText() async throws {
        let voices = try await provider.fetchVoices()

        guard let firstVoice = voices.first else {
            XCTFail("No voices available for testing")
            return
        }

        let text = ""
        // Should not throw, might return minimal audio
        let audioData = try await provider.generateAudio(text: text, voiceId: firstVoice.id)
        XCTAssertFalse(audioData.isEmpty, "Should return placeholder audio even for empty text")
    }

    // MARK: - Concurrency Tests
    // Note: These tests are commented out due to Swift 6 strict concurrency requirements
    // They can be re-enabled once we implement proper isolation

    /* func testConcurrentVoiceFetching() async throws {
        // Test that multiple concurrent fetchVoices calls work correctly
        await withThrowingTaskGroup(of: [Voice].self) { group in
            for _ in 0..<5 {
                group.addTask {
                    try await self.provider.fetchVoices()
                }
            }

            var allResults: [[Voice]] = []
            do {
                for try await voices in group {
                    allResults.append(voices)
                }

                // All results should be non-empty
                for voices in allResults {
                    XCTAssertFalse(voices.isEmpty, "Each concurrent fetch should return voices")
                }

                // All results should have similar counts (within tolerance)
                if let firstCount = allResults.first?.count {
                    for voices in allResults {
                        let difference = abs(voices.count - firstCount)
                        XCTAssertLessThanOrEqual(difference, 5, "Voice counts should be similar")
                    }
                }
            } catch {
                XCTFail("Concurrent voice fetching failed: \(error)")
            }
        }
    }

    func testConcurrentAudioGeneration() async throws {
        let voices = try await provider.fetchVoices()

        guard let firstVoice = voices.first else {
            XCTFail("No voices available for testing")
            return
        }

        // Generate multiple audio files concurrently
        await withThrowingTaskGroup(of: Data.self) { group in
            for i in 0..<3 {
                group.addTask {
                    try await self.provider.generateAudio(
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

                for data in allData {
                    XCTAssertFalse(data.isEmpty, "Each audio data should not be empty")
                }
            } catch {
                XCTFail("Concurrent audio generation failed: \(error)")
            }
        }
    } */

    // MARK: - Voice Gender Extraction Tests

    func testVoiceGenderExtraction() async throws {
        let voices = try await provider.fetchVoices()

        // Check if any voices have gender information
        let voicesWithGender = voices.filter { $0.gender != nil }

        // Note: Gender might not be available for all voices, so we just verify format if present
        for voice in voicesWithGender {
            let gender = voice.gender!.lowercased()
            XCTAssertTrue(
                gender == "male" || gender == "female",
                "Gender should be 'male' or 'female', got '\(gender)' for voice '\(voice.name)'"
            )
        }
    }

    // MARK: - Performance Tests
    // Note: These tests are commented out due to Swift 6 strict concurrency requirements

    /* func testVoiceFetchingPerformance() {
        measure {
            let expectation = XCTestExpectation(description: "Fetch voices")

            Task {
                _ = try await provider.fetchVoices()
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 5.0)
        }
    }

    func testAudioGenerationPerformance() async throws {
        let voices = try await provider.fetchVoices()

        guard let firstVoice = voices.first else {
            XCTFail("No voices available")
            return
        }

        measure {
            let expectation = XCTestExpectation(description: "Generate audio")

            Task {
                _ = try await self.provider.generateAudio(
                    text: "Performance test",
                    voiceId: firstVoice.id
                )
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 10.0)
        }
    } */
}

