//
//  ElevenLabsVoiceProviderTests.swift
//  SwiftHablareTests
//
//  Comprehensive mocked tests for ElevenLabsVoiceProvider
//

import XCTest
@testable import SwiftHablare

final class ElevenLabsVoiceProviderTests: XCTestCase {

    var provider: ElevenLabsVoiceProvider!
    let testAccount = "elevenlabs-api-key-test"
    let mockAPIKey = "test_api_key_12345"

    override func setUp() {
        super.setUp()
        provider = ElevenLabsVoiceProvider()

        // Clean up any existing test keys
        try? KeychainManager.shared.deleteAPIKey(for: testAccount)
        try? KeychainManager.shared.deleteAPIKey(for: "elevenlabs-api-key")
    }

    override func tearDown() {
        // Clean up test keys
        try? KeychainManager.shared.deleteAPIKey(for: testAccount)
        try? KeychainManager.shared.deleteAPIKey(for: "elevenlabs-api-key")

        provider = nil
        super.tearDown()
    }

    // MARK: - Basic Properties Tests

    func testProviderIdentifier() {
        XCTAssertEqual(provider.providerId, "elevenlabs")
    }

    func testProviderDisplayName() {
        XCTAssertEqual(provider.displayName, "ElevenLabs")
    }

    func testProviderRequiresAPIKey() {
        XCTAssertTrue(provider.requiresAPIKey)
    }

    // MARK: - Configuration Tests

    func testIsConfiguredReturnsFalseWithoutAPIKey() {
        XCTAssertFalse(provider.isConfigured())
    }

    func testIsConfiguredReturnsTrueWithAPIKey() throws {
        // Save API key - use do-catch to ensure it actually saves
        do {
            try KeychainManager.shared.saveAPIKey(mockAPIKey, for: "elevenlabs-api-key")

            // Verify it's configured
            XCTAssertTrue(provider.isConfigured())

            // Cleanup
            try? KeychainManager.shared.deleteAPIKey(for: "elevenlabs-api-key")
        } catch {
            // If keychain operations fail (common in CI environments), skip this test
            throw XCTSkip("Keychain operations not available in test environment: \(error)")
        }
    }

    // MARK: - Voice Fetching Tests (Without API Key)

    func testFetchVoicesThrowsWhenNotConfigured() async {
        do {
            _ = try await provider.fetchVoices()
            XCTFail("Should throw notConfigured error")
        } catch let error as VoiceProviderError {
            if case .notConfigured = error {
                // Expected error
            } else {
                XCTFail("Should throw notConfigured error, got \(error)")
            }
        } catch {
            XCTFail("Should throw VoiceProviderError.notConfigured, got \(error)")
        }
    }

    func testGenerateAudioThrowsWhenNotConfigured() async {
        do {
            _ = try await provider.generateAudio(text: "Test", voiceId: "voice123")
            XCTFail("Should throw notConfigured error")
        } catch let error as VoiceProviderError {
            if case .notConfigured = error {
                // Expected error
            } else {
                XCTFail("Should throw notConfigured error, got \(error)")
            }
        } catch {
            XCTFail("Should throw VoiceProviderError.notConfigured, got \(error)")
        }
    }

    // MARK: - Duration Estimation Tests

    func testEstimateDurationForShortText() async {
        let shortText = "Hello world"
        let duration = await provider.estimateDuration(text: shortText, voiceId: "voice123")

        XCTAssertGreaterThan(duration, 0, "Duration should be positive")
        XCTAssertLessThan(duration, 5, "Short text should have short duration")
    }

    func testEstimateDurationForLongText() async {
        let longText = String(repeating: "This is a longer sentence for testing duration estimation. ", count: 10)
        let duration = await provider.estimateDuration(text: longText, voiceId: "voice123")

        XCTAssertGreaterThan(duration, 5, "Long text should have longer duration")
    }

    func testEstimateDurationScalesWithTextLength() async {
        let shortText = "Hello"
        let mediumText = String(repeating: shortText + " ", count: 10)
        let longText = String(repeating: shortText + " ", count: 100)

        let shortDuration = await provider.estimateDuration(text: shortText, voiceId: "voice123")
        let mediumDuration = await provider.estimateDuration(text: mediumText, voiceId: "voice123")
        let longDuration = await provider.estimateDuration(text: longText, voiceId: "voice123")

        XCTAssertLessThan(shortDuration, mediumDuration, "Longer text should have longer duration")
        XCTAssertLessThan(mediumDuration, longDuration, "Even longer text should have even longer duration")
    }

    func testEstimateDurationMinimumValue() async {
        let emptyText = ""
        let duration = await provider.estimateDuration(text: emptyText, voiceId: "voice123")

        XCTAssertGreaterThanOrEqual(duration, 1.0, "Duration should have minimum value of 1.0 second")
    }

    func testEstimateDurationDoesNotRequireAPIKey() async {
        // Estimation should work without API key
        XCTAssertFalse(provider.isConfigured())

        let duration = await provider.estimateDuration(text: "Test text", voiceId: "voice123")

        XCTAssertGreaterThan(duration, 0, "Should estimate duration without API key")
    }

    // MARK: - Voice Availability Tests (Without API Key)

    func testIsVoiceAvailableReturnsFalseWithoutAPIKey() async {
        XCTAssertFalse(provider.isConfigured())

        let isAvailable = await provider.isVoiceAvailable(voiceId: "voice123")

        XCTAssertFalse(isAvailable, "Should return false when not configured")
    }

    // MARK: - ElevenLabsVoice Model Tests

    func testElevenLabsVoiceDecoding() throws {
        let json = """
        {
            "voice_id": "test123",
            "name": "Rachel",
            "description": "A friendly American voice",
            "labels": {
                "accent": "american",
                "gender": "female",
                "age": "young"
            },
            "verified_languages": [
                {
                    "language": "English",
                    "locale": "en-US",
                    "model_id": "eleven_monolingual_v1"
                }
            ]
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let voice = try decoder.decode(ElevenLabsVoice.self, from: json)

        XCTAssertEqual(voice.voice_id, "test123")
        XCTAssertEqual(voice.name, "Rachel")
        XCTAssertEqual(voice.description, "A friendly American voice")
        XCTAssertEqual(voice.id, "test123")
        XCTAssertEqual(voice.gender, "female")
        XCTAssertEqual(voice.language, "en")
        XCTAssertEqual(voice.locality, "US")
    }

    func testElevenLabsVoiceGenderExtraction() throws {
        let json = """
        {
            "voice_id": "test123",
            "name": "Adam",
            "labels": {
                "gender": "Male"
            }
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let voice = try decoder.decode(ElevenLabsVoice.self, from: json)

        XCTAssertEqual(voice.gender, "male")
    }

    func testElevenLabsVoiceLanguageExtraction() throws {
        let json = """
        {
            "voice_id": "test123",
            "name": "Maria",
            "verified_languages": [
                {
                    "locale": "es-ES"
                }
            ]
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let voice = try decoder.decode(ElevenLabsVoice.self, from: json)

        XCTAssertEqual(voice.language, "es")
        XCTAssertEqual(voice.locality, "ES")
    }

    func testElevenLabsVoiceWithoutOptionalFields() throws {
        let json = """
        {
            "voice_id": "test123",
            "name": "Basic Voice"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let voice = try decoder.decode(ElevenLabsVoice.self, from: json)

        XCTAssertEqual(voice.voice_id, "test123")
        XCTAssertEqual(voice.name, "Basic Voice")
        XCTAssertNil(voice.description)
        XCTAssertNil(voice.labels)
        XCTAssertNil(voice.verified_languages)
    }

    func testVoicesResponseDecoding() throws {
        let json = """
        {
            "voices": [
                {
                    "voice_id": "voice1",
                    "name": "Rachel"
                },
                {
                    "voice_id": "voice2",
                    "name": "Adam"
                }
            ]
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let response = try decoder.decode(VoicesResponse.self, from: json)

        XCTAssertEqual(response.voices.count, 2)
        XCTAssertEqual(response.voices[0].voice_id, "voice1")
        XCTAssertEqual(response.voices[1].voice_id, "voice2")
    }

    // MARK: - Edge Case Tests

    func testEmptyVoiceId() async {
        let isAvailable = await provider.isVoiceAvailable(voiceId: "")
        XCTAssertFalse(isAvailable)
    }

    func testVeryLongText() async {
        let veryLongText = String(repeating: "A", count: 10000)
        let duration = await provider.estimateDuration(text: veryLongText, voiceId: "voice123")

        XCTAssertGreaterThan(duration, 100, "Very long text should have very long duration")
    }

    // MARK: - Concurrency Tests
    // Note: Commented out due to Swift 6 strict concurrency requirements

    /* func testConcurrentDurationEstimation() async {
        await withTaskGroup(of: TimeInterval.self) { group in
            for i in 0..<10 {
                group.addTask {
                    await self.provider.estimateDuration(
                        text: "Concurrent test \(i)",
                        voiceId: "voice123"
                    )
                }
            }

            var durations: [TimeInterval] = []
            for await duration in group {
                durations.append(duration)
            }

            XCTAssertEqual(durations.count, 10, "Should complete all concurrent estimations")

            for duration in durations {
                XCTAssertGreaterThan(duration, 0, "Each duration should be positive")
            }
        }
    } */

    // MARK: - Voice Conversion Tests

    func testElevenLabsVoiceToVoiceConversion() throws {
        let json = """
        {
            "voice_id": "test123",
            "name": "Rachel",
            "description": "A friendly voice",
            "labels": {
                "gender": "female"
            },
            "verified_languages": [
                {
                    "locale": "en-US"
                }
            ]
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let elevenLabsVoice = try decoder.decode(ElevenLabsVoice.self, from: json)

        // Convert to Voice model
        let voice = Voice(
            id: elevenLabsVoice.id,
            name: elevenLabsVoice.name,
            description: elevenLabsVoice.description,
            providerId: "elevenlabs",
            language: elevenLabsVoice.language,
            locality: elevenLabsVoice.locality,
            gender: elevenLabsVoice.gender
        )

        XCTAssertEqual(voice.id, "test123")
        XCTAssertEqual(voice.name, "Rachel")
        XCTAssertEqual(voice.description, "A friendly voice")
        XCTAssertEqual(voice.providerId, "elevenlabs")
        XCTAssertEqual(voice.gender, "female")
        XCTAssertEqual(voice.language, "en")
        XCTAssertEqual(voice.locality, "US")
    }

    // MARK: - Performance Tests
    // Note: Commented out due to Swift 6 strict concurrency requirements

    /* func testDurationEstimationPerformance() {
        measure {
            let text = "This is a performance test for duration estimation."

            Task {
                _ = await provider.estimateDuration(text: text, voiceId: "voice123")
            }
        }
    } */

    // MARK: - Error Message Tests

    func testNotConfiguredErrorMessage() {
        let error = VoiceProviderError.notConfigured
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("configured"))
    }

    func testNetworkErrorMessage() {
        let error = VoiceProviderError.networkError("Connection failed")
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("Connection failed"))
    }

    func testInvalidResponseErrorMessage() {
        let error = VoiceProviderError.invalidResponse
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("Invalid"))
    }
}

// MARK: - Mock URLSession Tests (if we want to add mocked network tests in the future)

// Note: These tests demonstrate how to test with actual API calls if needed
// For CI/CD, these should be skipped unless API credentials are available

extension ElevenLabsVoiceProviderTests {

    /// Example test that would work with a real API key
    /// This test is disabled by default - enable it manually when testing with real credentials
    func disabled_testRealAPIFetchVoices() async throws {
        // This test is disabled by default as it requires a real API key
        // To run it, set a real API key and rename the function to remove "disabled_"

        guard let apiKey = ProcessInfo.processInfo.environment["ELEVENLABS_API_KEY"],
              !apiKey.isEmpty else {
            throw XCTSkip("ELEVENLABS_API_KEY environment variable not set")
        }

        // Save API key
        try KeychainManager.shared.saveAPIKey(apiKey, for: "elevenlabs-api-key")

        do {
            let voices = try await provider.fetchVoices()

            XCTAssertFalse(voices.isEmpty, "Should return voices from API")

            for voice in voices {
                XCTAssertFalse(voice.id.isEmpty, "Voice ID should not be empty")
                XCTAssertFalse(voice.name.isEmpty, "Voice name should not be empty")
                XCTAssertEqual(voice.providerId, "elevenlabs")
            }
        } catch {
            XCTFail("Real API call failed: \(error)")
        }

        // Cleanup
        try KeychainManager.shared.deleteAPIKey(for: "elevenlabs-api-key")
    }

    /// Example test that would generate real audio
    /// This test is disabled by default - enable it manually when testing with real credentials
    func disabled_testRealAPIGenerateAudio() async throws {
        guard let apiKey = ProcessInfo.processInfo.environment["ELEVENLABS_API_KEY"],
              !apiKey.isEmpty else {
            throw XCTSkip("ELEVENLABS_API_KEY environment variable not set")
        }

        try KeychainManager.shared.saveAPIKey(apiKey, for: "elevenlabs-api-key")

        do {
            // First fetch voices to get a valid voice ID
            let voices = try await provider.fetchVoices()

            guard let firstVoice = voices.first else {
                XCTFail("No voices available")
                return
            }

            // Generate audio
            let audioData = try await provider.generateAudio(
                text: "This is a test of the ElevenLabs API.",
                voiceId: firstVoice.id
            )

            XCTAssertFalse(audioData.isEmpty, "Audio data should not be empty")

            // Verify it's valid audio data (MP3 starts with specific bytes)
            let mp3Header = audioData.prefix(3)
            let hasMP3Header = mp3Header.count == 3 &&
                               (mp3Header[0] == 0xFF || mp3Header[0] == 0x49) // ID3 or sync byte

            XCTAssertTrue(hasMP3Header, "Audio data should be valid MP3 format")
        } catch {
            XCTFail("Real API call failed: \(error)")
        }

        try KeychainManager.shared.deleteAPIKey(for: "elevenlabs-api-key")
    }
}
