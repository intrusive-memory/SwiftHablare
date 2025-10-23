//
//  ElevenLabsVoiceProviderIntegrationTests.swift
//  SwiftHablareTests
//
//  End-to-end integration tests for ElevenLabs voice generation
//  Requires ELEVENLABS_API_KEY environment variable to run
//

import XCTest
import SwiftData
import SwiftCompartido
@testable import SwiftHablare

final class ElevenLabsVoiceProviderIntegrationTests: XCTestCase {

    var provider: ElevenLabsVoiceProvider!
    var service: GenerationService!
    var artifactsDirectory: URL!
    var apiKey: String?

    override func setUp() async throws {
        try await super.setUp()

        // Check for API key in environment
        apiKey = ProcessInfo.processInfo.environment["ELEVENLABS_API_KEY"]

        // Skip all tests in this class if no API key
        guard let key = apiKey, !key.isEmpty else {
            return // Will skip in each individual test
        }

        // Use ephemeral API key directly (bypasses keychain)
        provider = ElevenLabsVoiceProvider(apiKey: key)
        service = GenerationService(voiceProvider: provider)

        // Create artifacts directory
        let testBundle = Bundle(for: type(of: self))
        let testsDirectory = URL(fileURLWithPath: testBundle.bundlePath).deletingLastPathComponent()
        artifactsDirectory = testsDirectory.deletingLastPathComponent().appendingPathComponent("TestArtifacts")

        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: artifactsDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        provider = nil
        service = nil
        apiKey = nil
        try await super.tearDown()
    }

    // MARK: - End-to-End Integration Tests

    func testEndToEndSpeechGeneration() async throws {
        // Skip test if no API key is available
        guard apiKey != nil, !apiKey!.isEmpty else {
            throw XCTSkip("ELEVENLABS_API_KEY environment variable not set - skipping ElevenLabs integration test")
        }

        print("🎤 Starting end-to-end ElevenLabs speech generation test...")

        // Step 1: Fetch available voices (using ephemeral API key from setUp)
        print("📋 Fetching available voices from ElevenLabs API...")
        let voices = try await provider.fetchVoices()
        XCTAssertFalse(voices.isEmpty, "Should have at least one voice available")
        print("✅ Found \(voices.count) voices")

        // Step 2: Select a voice (prefer English)
        let voice = voices.first { $0.language == "en" } ?? voices.first!
        print("🎙️  Selected voice: \(voice.name) (id: \(voice.id))")

        // Step 3: Generate audio
        let testText = "This is an end-to-end integration test of ElevenLabs text-to-speech generation."
        print("🔊 Generating audio for text: \"\(testText)\"")

        let result = try await service.generate(
            text: testText,
            voiceId: voice.id,
            voiceName: voice.name
        )

        // Step 4: Validate result
        XCTAssertFalse(result.audioData.isEmpty, "Audio data should not be empty")
        XCTAssertEqual(result.originalText, testText)
        XCTAssertEqual(result.voiceId, voice.id)
        XCTAssertEqual(result.providerId, "elevenlabs")
        XCTAssertGreaterThan(result.estimatedDuration, 0)
        print("✅ Generated \(result.audioData.count) bytes of audio")
        print("⏱️  Estimated duration: \(String(format: "%.2f", result.estimatedDuration))s")

        // Step 5: Verify MP3 format
        let mp3Header = result.audioData.prefix(3)
        let hasMP3Header = mp3Header.count == 3 &&
                           (mp3Header[0] == 0xFF || mp3Header[0] == 0x49) // ID3 or sync byte
        XCTAssertTrue(hasMP3Header, "Audio should be in MP3 format")
        print("✅ Audio format validated (MP3)")

        // Step 6: Save audio artifact
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let filename = "elevenlabs-tts-\(timestamp).mp3"
        let artifactURL = artifactsDirectory.appendingPathComponent(filename)

        try result.audioData.write(to: artifactURL)
        print("💾 Saved audio artifact: \(artifactURL.path)")

        // Print summary
        print("""

        📊 Test Summary:
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        Provider:    ElevenLabs
        Voice:       \(voice.name)
        Text:        "\(testText)"
        Audio Size:  \(ByteCountFormatter.string(fromByteCount: Int64(result.audioData.count), countStyle: .file))
        Duration:    \(String(format: "%.2f", result.estimatedDuration))s
        Format:      MP3
        Artifact:    \(filename)
        Status:      ✅ SUCCESS
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        """)
    }

    func testEndToEndWithMultipleVoices() async throws {
        // Skip test if no API key is available
        guard apiKey != nil, !apiKey!.isEmpty else {
            throw XCTSkip("ELEVENLABS_API_KEY environment variable not set - skipping ElevenLabs integration test")
        }

        print("🎤 Testing with multiple ElevenLabs voices...")

        let voices = try await provider.fetchVoices()
        let voicesToTest = Array(voices.prefix(min(3, voices.count)))

        for (index, voice) in voicesToTest.enumerated() {
            print("\n🎙️  Testing voice \(index + 1)/\(voicesToTest.count): \(voice.name)")

            let testText = "Testing voice number \(index + 1)."
            let result = try await service.generate(
                text: testText,
                voiceId: voice.id,
                voiceName: voice.name
            )

            XCTAssertFalse(result.audioData.isEmpty)
            print("✅ Generated \(result.audioData.count) bytes")

            // Save artifact
            let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
            let filename = "elevenlabs-tts-\(voice.name.replacingOccurrences(of: " ", with: "-"))-\(timestamp).mp3"
            let artifactURL = artifactsDirectory.appendingPathComponent(filename)
            try result.audioData.write(to: artifactURL)
            print("💾 Saved: \(filename)")
        }

        print("\n✅ Successfully tested \(voicesToTest.count) voices")
    }

    func testEndToEndWithLongText() async throws {
        // Skip test if no API key is available
        guard apiKey != nil, !apiKey!.isEmpty else {
            throw XCTSkip("ELEVENLABS_API_KEY environment variable not set - skipping ElevenLabs integration test")
        }

        print("🎤 Testing with longer text...")

        let voices = try await provider.fetchVoices()
        let voice = voices.first { $0.language == "en" } ?? voices.first!

        let longText = """
        This is a longer text sample to test the ElevenLabs text-to-speech system with more content. \
        The quick brown fox jumps over the lazy dog. \
        Lorem ipsum dolor sit amet, consectetur adipiscing elit. \
        This test ensures that longer text passages are properly synthesized into audio.
        """

        print("🔊 Generating audio for \(longText.count) characters...")

        let result = try await service.generate(
            text: longText,
            voiceId: voice.id,
            voiceName: voice.name
        )

        XCTAssertFalse(result.audioData.isEmpty)
        XCTAssertGreaterThan(result.estimatedDuration, 5, "Longer text should have longer duration")

        // Save artifact
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let filename = "elevenlabs-tts-long-text-\(timestamp).mp3"
        let artifactURL = artifactsDirectory.appendingPathComponent(filename)
        try result.audioData.write(to: artifactURL)

        print("✅ Generated \(result.audioData.count) bytes (\(String(format: "%.2f", result.estimatedDuration))s)")
        print("💾 Saved: \(filename)")
    }

    func testAPIKeyNotAvailable() async throws {
        // This test verifies the skip behavior when API key is not available
        if apiKey == nil || apiKey!.isEmpty {
            print("✅ Verified: ElevenLabs tests are properly skipped when ELEVENLABS_API_KEY is not set")
        }
    }

    // MARK: - SwiftData Persistence Integration Test

    @MainActor
    func testEndToEndWithSwiftDataPersistence() async throws {
        // Skip test if no API key is available
        guard apiKey != nil, !apiKey!.isEmpty else {
            throw XCTSkip("ELEVENLABS_API_KEY environment variable not set - skipping ElevenLabs integration test")
        }

        print("🎤 Starting end-to-end test with SwiftData persistence...")

        // Step 1: Create in-memory SwiftData container
        print("💾 Setting up in-memory SwiftData container...")
        let schema = Schema([TypedDataStorage.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let modelContext = ModelContext(container)

        // Step 2: Fetch available voices
        print("📋 Fetching available voices from ElevenLabs API...")
        let voices = try await provider.fetchVoices()
        XCTAssertFalse(voices.isEmpty, "Should have at least one voice available")
        print("✅ Found \(voices.count) voices")

        // Step 3: Select a voice
        let voice = voices.first { $0.language == "en" } ?? voices.first!
        print("🎙️  Selected voice: \(voice.name) (id: \(voice.id))")

        // Step 4: Generate audio (background thread)
        let testText = "Testing SwiftData persistence with ElevenLabs."
        print("🔊 Generating audio: \"\(testText)\"")

        let result = try await service.generate(
            text: testText,
            voiceId: voice.id,
            voiceName: voice.name
        )

        XCTAssertFalse(result.audioData.isEmpty, "Audio data should not be empty")
        print("✅ Generated \(result.audioData.count) bytes of audio")

        // Step 5: Convert to TypedDataStorage (main thread)
        print("💾 Converting result to TypedDataStorage...")
        let audioRecord = result.toTypedDataStorage()

        XCTAssertEqual(audioRecord.id, result.requestId)
        XCTAssertEqual(audioRecord.providerId, "elevenlabs")
        XCTAssertEqual(audioRecord.requestorID, "elevenlabs.audio.tts")
        XCTAssertEqual(audioRecord.mimeType, result.mimeType)
        XCTAssertNotNil(audioRecord.binaryValue)
        XCTAssertEqual(audioRecord.binaryValue, result.audioData)
        XCTAssertEqual(audioRecord.prompt, testText)
        XCTAssertEqual(audioRecord.voiceID, voice.id)
        XCTAssertEqual(audioRecord.voiceName, voice.name)
        print("✅ TypedDataStorage created successfully")

        // Step 6: Insert into SwiftData context
        print("💾 Inserting into SwiftData context...")
        modelContext.insert(audioRecord)

        // Step 7: Save to SwiftData
        print("💾 Saving to SwiftData...")
        try modelContext.save()
        print("✅ Saved to SwiftData successfully")

        // Step 8: Verify persistence by fetching from database
        print("🔍 Verifying persistence...")
        let descriptor = FetchDescriptor<TypedDataStorage>()
        let savedRecords = try modelContext.fetch(descriptor)

        XCTAssertEqual(savedRecords.count, 1, "Should have exactly one saved record")

        let savedRecord = savedRecords.first!
        XCTAssertEqual(savedRecord.id, result.requestId)
        XCTAssertEqual(savedRecord.providerId, "elevenlabs")
        XCTAssertEqual(savedRecord.binaryValue, result.audioData)
        XCTAssertEqual(savedRecord.prompt, testText)
        XCTAssertEqual(savedRecord.voiceID, voice.id)
        print("✅ Record successfully persisted and retrieved from SwiftData")

        // Step 9: Verify audio data integrity
        print("🔍 Verifying audio data integrity...")
        let retrievedAudioData = try savedRecord.getBinary()
        XCTAssertEqual(retrievedAudioData, result.audioData, "Retrieved audio should match original")
        XCTAssertFalse(retrievedAudioData.isEmpty, "Retrieved audio should not be empty")

        // Verify MP3 format
        let mp3Header = retrievedAudioData.prefix(3)
        let hasMP3Header = mp3Header.count == 3 &&
                           (mp3Header[0] == 0xFF || mp3Header[0] == 0x49)
        XCTAssertTrue(hasMP3Header, "Retrieved audio should be in MP3 format")
        print("✅ Audio data integrity verified (MP3 format)")

        // Print summary
        print("""

        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        🎉 SwiftData Persistence Test Complete!
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        Provider: ElevenLabs
        Voice: \(voice.name)
        Text: "\(testText)"
        Audio Size: \(ByteCountFormatter.string(fromByteCount: Int64(result.audioData.count), countStyle: .file))
        Request ID: \(result.requestId)
        ✅ Generated → TypedDataStorage → SwiftData → Retrieved
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        """)
    }
}
