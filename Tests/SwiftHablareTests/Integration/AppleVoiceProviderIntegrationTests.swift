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
        #if os(macOS)
        let filename = "apple-tts-\(timestamp).aiff"
        #else
        let filename = "apple-tts-\(timestamp).caf"
        #endif
        let artifactURL = artifactsDirectory.appendingPathComponent(filename)

        try result.audioData.write(to: artifactURL)
        print("💾 Saved audio artifact: \(artifactURL.path)")

        // Step 6: Verify audio file has non-zero size
        let attributes = try FileManager.default.attributesOfItem(atPath: artifactURL.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        XCTAssertGreaterThan(fileSize, 1000, "Audio file should be larger than 1KB")
        print("✅ Audio file size: \(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))")

        // Step 7: Verify audio file is valid and has non-zero duration
        let audioFile = try AVAudioFile(forReading: artifactURL)
        XCTAssertNotNil(audioFile.processingFormat, "Audio file should have valid format")
        XCTAssertGreaterThan(audioFile.length, 0, "Audio file should have non-zero length")

        let duration = Double(audioFile.length) / audioFile.processingFormat.sampleRate
        XCTAssertGreaterThan(duration, 1.0, "Audio duration should be at least 1 second for this text")
        print("✅ Audio duration: \(String(format: "%.2f", duration))s (\(audioFile.length) frames)")

        // Step 8: Verify audio contains non-zero samples (not silence)
        let frameCount = AVAudioFrameCount(audioFile.length)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: frameCount) else {
            XCTFail("Failed to create audio buffer")
            return
        }
        try audioFile.read(into: buffer)

        // Check that at least some samples are non-zero
        let channelData = buffer.floatChannelData?[0]
        var hasNonZeroSamples = false
        var nonZeroCount = 0
        for i in 0..<Int(buffer.frameLength) {
            if let sample = channelData?[i], abs(sample) > 0.001 {
                hasNonZeroSamples = true
                nonZeroCount += 1
            }
        }
        XCTAssertTrue(hasNonZeroSamples, "Audio should contain non-zero samples (not silence)")
        let percentNonZero = (Double(nonZeroCount) / Double(buffer.frameLength)) * 100.0
        print("✅ Audio validated: \(String(format: "%.1f%%", percentNonZero)) non-zero samples (contains actual speech)")

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
            #if os(macOS)
            let filename = "apple-tts-\(voice.name.replacingOccurrences(of: " ", with: "-"))-\(timestamp).aiff"
            #else
            let filename = "apple-tts-\(voice.name.replacingOccurrences(of: " ", with: "-"))-\(timestamp).caf"
            #endif
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
        #if os(macOS)
        let filename = "apple-tts-long-text-\(timestamp).aiff"
        #else
        let filename = "apple-tts-long-text-\(timestamp).caf"
        #endif
        let artifactURL = artifactsDirectory.appendingPathComponent(filename)
        try result.audioData.write(to: artifactURL)

        print("✅ Generated \(result.audioData.count) bytes (\(String(format: "%.2f", result.estimatedDuration))s)")
        print("💾 Saved: \(filename)")
    }
}
