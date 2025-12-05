//
//  AppleVoiceProviderIntegrationTests.swift
//  SwiftHablareTests
//
//  End-to-end integration tests for Apple TTS voice generation
//

import Testing
import AVFoundation
import SwiftData
import SwiftCompartido
@testable import SwiftHablare

@Suite("Apple Voice Provider Integration Tests")
@MainActor
struct AppleVoiceProviderIntegrationTests {

    var provider: AppleVoiceProvider
    var service: GenerationService
    var artifactsDirectory: URL
    var modelContainer: ModelContainer
    var modelContext: ModelContext

    init() throws {
        // Create in-memory SwiftData container
        let schema = Schema([VoiceCacheModel.self, TypedDataStorage.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        modelContext = ModelContext(modelContainer)

        provider = TestFixtures.makeAppleProvider()
        service = GenerationService()

        // Create artifacts directory
        let testBundle = Bundle.main
        let testsDirectory = URL(fileURLWithPath: testBundle.bundlePath).deletingLastPathComponent()
        artifactsDirectory = testsDirectory.deletingLastPathComponent().appendingPathComponent("TestArtifacts")

        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: artifactsDirectory, withIntermediateDirectories: true)
    }

    // MARK: - End-to-End Integration Tests

    @Test("End-to-end speech generation")
    func testEndToEndSpeechGeneration() async throws {
        // Skip on simulator - AVSpeechSynthesizer.write() doesn't generate real audio on simulators
        #if targetEnvironment(simulator)
        throw Testing.Skip("Apple TTS integration test skipped on simulator - real speech synthesis only works on physical iOS devices")
        #endif

        print("🎤 Starting end-to-end Apple TTS speech generation test...")

        // Step 1: Fetch available voices
        print("📋 Fetching available voices...")
        let voices = try await provider.fetchVoices()
        #expect(!voices.isEmpty, "Should have at least one voice available")
        print("✅ Found \(voices.count) voices")

        // Step 2: Select a voice (prefer English)
        let voice = voices.first { $0.language == "en" } ?? voices.first!
        print("🎙️  Selected voice: \(voice.name) (id: \(voice.id))")

        // Step 3: Generate audio
        let testText = "This is an end-to-end integration test of Apple Text-to-Speech generation."
        print("🔊 Generating audio for text: \"\(testText)\"")

        let result = try await service.generate(
            text: testText,
            providerId: "apple",
            voiceId: voice.id,
            voiceName: voice.name
        )

        // Step 4: Validate result
        #expect(!result.audioData.isEmpty, "Audio data should not be empty")
        #expect(result.originalText == testText)
        #expect(result.voiceId == voice.id)
        #expect(result.providerId == "apple")
        #expect(result.estimatedDuration > 0)
        print("✅ Generated \(result.audioData.count) bytes of audio")
        print("⏱️  Estimated duration: \(String(format: "%.2f", result.estimatedDuration))s")

        // Step 5: Save audio artifact (AIFF format on all platforms)
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let filename = "apple-tts-\(timestamp).aiff"
        let artifactURL = artifactsDirectory.appendingPathComponent(filename)

        try result.audioData.write(to: artifactURL)
        print("💾 Saved audio artifact: \(artifactURL.path)")

        // Step 6: Verify audio file has non-zero size
        let attributes = try FileManager.default.attributesOfItem(atPath: artifactURL.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        #expect(fileSize > 1000, "Audio file should be larger than 1KB")
        print("✅ Audio file size: \(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))")

        // Step 7: Verify audio file is valid and has non-zero duration
        let audioFile = try AVAudioFile(forReading: artifactURL)
        #expect(audioFile.processingFormat != nil, "Audio file should have valid format")
        #expect(audioFile.length > 0, "Audio file should have non-zero length")

        let duration = Double(audioFile.length) / audioFile.processingFormat.sampleRate
        #expect(duration > 1.0, "Audio duration should be at least 1 second for this text")
        print("✅ Audio duration: \(String(format: "%.2f", duration))s (\(audioFile.length) frames)")

        // Step 8: Verify audio contains non-zero samples (not silence)
        let frameCount = AVAudioFrameCount(audioFile.length)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: frameCount) else {
            Issue.record("Failed to create audio buffer")
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
        #expect(hasNonZeroSamples, "Audio should contain non-zero samples (not silence)")
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

    @Test("End-to-end with multiple voices")
    func testEndToEndWithMultipleVoices() async throws {
        // Skip on simulator - AVSpeechSynthesizer.write() doesn't generate real audio on simulators
        #if targetEnvironment(simulator)
        throw Testing.Skip("Apple TTS integration test skipped on simulator - real speech synthesis only works on physical iOS devices")
        #endif

        print("🎤 Testing with multiple Apple voices...")

        let voices = try await provider.fetchVoices()
        let voicesToTest = Array(voices.prefix(min(3, voices.count)))

        for (index, voice) in voicesToTest.enumerated() {
            print("\n🎙️  Testing voice \(index + 1)/\(voicesToTest.count): \(voice.name)")

            let testText = "Testing voice number \(index + 1)."
            let result = try await service.generate(
                text: testText,
                providerId: "apple",
                voiceId: voice.id,
                voiceName: voice.name
            )

            #expect(!result.audioData.isEmpty)
            print("✅ Generated \(result.audioData.count) bytes")

            // Save artifact (AIFF format on all platforms)
            let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
            let filename = "apple-tts-\(voice.name.replacingOccurrences(of: " ", with: "-"))-\(timestamp).aiff"
            let artifactURL = artifactsDirectory.appendingPathComponent(filename)
            try result.audioData.write(to: artifactURL)
            print("💾 Saved: \(filename)")
        }

        print("\n✅ Successfully tested \(voicesToTest.count) voices")
    }

    @Test("End-to-end with long text")
    func testEndToEndWithLongText() async throws {
        // Skip on simulator - AVSpeechSynthesizer.write() doesn't generate real audio on simulators
        #if targetEnvironment(simulator)
        throw Testing.Skip("Apple TTS integration test skipped on simulator - real speech synthesis only works on physical iOS devices")
        #endif

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
            providerId: "apple",
            voiceId: voice.id,
            voiceName: voice.name
        )

        #expect(!result.audioData.isEmpty)
        #expect(result.estimatedDuration > 5, "Longer text should have longer duration")

        // Save artifact (AIFF format on all platforms)
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let filename = "apple-tts-long-text-\(timestamp).aiff"
        let artifactURL = artifactsDirectory.appendingPathComponent(filename)
        try result.audioData.write(to: artifactURL)

        print("✅ Generated \(result.audioData.count) bytes (\(String(format: "%.2f", result.estimatedDuration))s)")
        print("💾 Saved: \(filename)")
    }

    // MARK: - SwiftData Persistence Integration Test

    @Test("End-to-end with SwiftData persistence")
    func testEndToEndWithSwiftDataPersistence() async throws {
        // Skip on simulator - AVSpeechSynthesizer.write() doesn't generate real audio on simulators
        #if targetEnvironment(simulator)
        throw Testing.Skip("Apple TTS integration test skipped on simulator - real speech synthesis only works on physical iOS devices")
        #endif

        print("🎤 Starting end-to-end test with SwiftData persistence...")

        // Step 1: Create in-memory SwiftData container
        print("💾 Setting up in-memory SwiftData container...")
        let schema = Schema([TypedDataStorage.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let persistenceContext = ModelContext(container)

        // Step 2: Fetch available voices
        print("📋 Fetching available voices...")
        let voices = try await provider.fetchVoices()
        #expect(!voices.isEmpty, "Should have at least one voice available")
        print("✅ Found \(voices.count) voices")

        // Step 3: Select a voice
        let voice = voices.first { $0.language == "en" } ?? voices.first!
        print("🎙️  Selected voice: \(voice.name) (id: \(voice.id))")

        // Step 4: Generate audio (background thread)
        let testText = "Testing SwiftData persistence integration."
        print("🔊 Generating audio: \"\(testText)\"")

        let result = try await service.generate(
            text: testText,
            providerId: "apple",
            voiceId: voice.id,
            voiceName: voice.name
        )

        #expect(!result.audioData.isEmpty, "Audio data should not be empty")
        print("✅ Generated \(result.audioData.count) bytes of audio")

        // Step 5: Convert to TypedDataStorage (main thread)
        print("💾 Converting result to TypedDataStorage...")
        let audioRecord = result.toTypedDataStorage()

        #expect(audioRecord.id == result.requestId)
        #expect(audioRecord.providerId == "apple")
        #expect(audioRecord.requestorID == "apple.audio.tts")
        #expect(audioRecord.mimeType == result.mimeType)
        #expect(audioRecord.binaryValue != nil)
        #expect(audioRecord.binaryValue == result.audioData)
        #expect(audioRecord.prompt == testText)
        #expect(audioRecord.voiceID == voice.id)
        #expect(audioRecord.voiceName == voice.name)
        print("✅ TypedDataStorage created successfully")

        // Step 6: Insert into SwiftData context
        print("💾 Inserting into SwiftData context...")
        persistenceContext.insert(audioRecord)

        // Step 7: Save to SwiftData
        print("💾 Saving to SwiftData...")
        try persistenceContext.save()
        print("✅ Saved to SwiftData successfully")

        // Step 8: Verify persistence by fetching from database
        print("🔍 Verifying persistence...")
        let descriptor = FetchDescriptor<TypedDataStorage>()
        let savedRecords = try persistenceContext.fetch(descriptor)

        #expect(savedRecords.count == 1, "Should have exactly one saved record")

        let savedRecord = savedRecords.first!
        #expect(savedRecord.id == result.requestId)
        #expect(savedRecord.providerId == "apple")
        #expect(savedRecord.binaryValue == result.audioData)
        #expect(savedRecord.prompt == testText)
        #expect(savedRecord.voiceID == voice.id)
        print("✅ Record successfully persisted and retrieved from SwiftData")

        // Step 9: Verify audio data integrity
        print("🔍 Verifying audio data integrity...")
        let retrievedAudioData = try savedRecord.getBinary()
        #expect(retrievedAudioData == result.audioData, "Retrieved audio should match original")
        #expect(!retrievedAudioData.isEmpty, "Retrieved audio should not be empty")
        print("✅ Audio data integrity verified")

        // Print summary
        print("""

        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        🎉 SwiftData Persistence Test Complete!
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        Provider: Apple TTS
        Voice: \(voice.name)
        Text: "\(testText)"
        Audio Size: \(ByteCountFormatter.string(fromByteCount: Int64(result.audioData.count), countStyle: .file))
        Request ID: \(result.requestId)
        ✅ Generated → TypedDataStorage → SwiftData → Retrieved
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        """)
    }
}
