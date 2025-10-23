//
//  AppleVoiceProviderIntegrationTests.swift
//  SwiftHablareTests
//
//  End-to-end integration tests for Apple TTS voice generation
//

import XCTest
import AVFoundation
@testable import SwiftHablare

final class AppleVoiceProviderIntegrationTests: XCTestCase {

    var provider: AppleVoiceProvider!
    var service: GenerationService!
    var artifactsDirectory: URL!

    override func setUp() async throws {
        try await super.setUp()

        provider = AppleVoiceProvider()
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
        try await super.tearDown()
    }

    // MARK: - End-to-End Integration Tests

    func testEndToEndSpeechGeneration() async throws {
        print("🎤 Starting end-to-end Apple TTS speech generation test...")

        // Step 1: Fetch available voices
        print("📋 Fetching available voices...")
        let voices = try await provider.fetchVoices()
        XCTAssertFalse(voices.isEmpty, "Should have at least one voice available")
        print("✅ Found \(voices.count) voices")

        // Step 2: Select a voice (prefer English)
        let voice = voices.first { $0.language == "en" } ?? voices.first!
        print("🎙️  Selected voice: \(voice.name) (id: \(voice.id))")

        // Step 3: Generate audio
        let testText = "This is an end-to-end integration test of Apple Text-to-Speech generation."
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
        XCTAssertEqual(result.providerId, "apple")
        XCTAssertGreaterThan(result.estimatedDuration, 0)
        print("✅ Generated \(result.audioData.count) bytes of audio")
        print("⏱️  Estimated duration: \(String(format: "%.2f", result.estimatedDuration))s")

        // Step 5: Save audio artifact
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let filename = "apple-tts-\(timestamp).caf"
        let artifactURL = artifactsDirectory.appendingPathComponent(filename)

        try result.audioData.write(to: artifactURL)
        print("💾 Saved audio artifact: \(artifactURL.path)")

        // Step 6: Verify audio file is valid
        let audioFile = try AVAudioFile(forReading: artifactURL)
        XCTAssertNotNil(audioFile.processingFormat, "Audio file should have valid format")
        print("✅ Audio file validated successfully")

        // Print summary
        print("""

        📊 Test Summary:
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        Provider:    Apple Text-to-Speech
        Voice:       \(voice.name)
        Text:        "\(testText)"
        Audio Size:  \(ByteCountFormatter.string(fromByteCount: Int64(result.audioData.count), countStyle: .file))
        Duration:    \(String(format: "%.2f", result.estimatedDuration))s
        Format:      CAF (Core Audio Format)
        Artifact:    \(filename)
        Status:      ✅ SUCCESS
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        """)
    }

    func testEndToEndWithMultipleVoices() async throws {
        print("🎤 Testing with multiple Apple voices...")

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
            let filename = "apple-tts-\(voice.name.replacingOccurrences(of: " ", with: "-"))-\(timestamp).caf"
            let artifactURL = artifactsDirectory.appendingPathComponent(filename)
            try result.audioData.write(to: artifactURL)
            print("💾 Saved: \(filename)")
        }

        print("\n✅ Successfully tested \(voicesToTest.count) voices")
    }

    func testEndToEndWithLongText() async throws {
        print("🎤 Testing with longer text...")

        let voices = try await provider.fetchVoices()
        let voice = voices.first { $0.language == "en" } ?? voices.first!

        let longText = """
        This is a longer text sample to test the Apple Text-to-Speech system with more content. \
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
        let filename = "apple-tts-long-text-\(timestamp).caf"
        let artifactURL = artifactsDirectory.appendingPathComponent(filename)
        try result.audioData.write(to: artifactURL)

        print("✅ Generated \(result.audioData.count) bytes (\(String(format: "%.2f", result.estimatedDuration))s)")
        print("💾 Saved: \(filename)")
    }
}
