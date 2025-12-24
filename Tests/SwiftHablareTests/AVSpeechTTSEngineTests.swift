//
//  AVSpeechTTSEngineTests.swift
//  SwiftHablareTests
//
//  Tests for AVSpeechTTSEngine implementation (iOS and macOS)
//

#if canImport(UIKit) || canImport(AppKit)
import Testing
import AVFoundation
@testable import SwiftHablare

@Suite("AVSpeechTTSEngine Tests")
struct AVSpeechTTSEngineTests {
    var engine: AVSpeechTTSEngine

    init() {
        engine = AVSpeechTTSEngine()
    }

    // MARK: - Voice Fetching Tests

    @Test("Voice fetching returns non-empty array")
    func fetchVoicesReturnsNonEmptyArray() async throws {
        let voices = try await engine.fetchVoices()
        #expect(!voices.isEmpty)
    }

    @Test("Fetched voices have required properties")
    func fetchedVoicesHaveRequiredProperties() async throws {
        let voices = try await engine.fetchVoices()

        for voice in voices {
            #expect(!voice.id.isEmpty)
            #expect(!voice.name.isEmpty)
            #expect(voice.providerId == "apple")
        }
    }

    @Test("Fetched voices have language information")
    func fetchedVoicesHaveLanguageInformation() async throws {
        let voices = try await engine.fetchVoices()

        let voicesWithLanguage = voices.filter { $0.language != nil }
        #expect(!voicesWithLanguage.isEmpty)
    }

    @Test("Fetched voices match system language")
    func fetchedVoicesMatchSystemLanguage() async throws {
        let voices = try await engine.fetchVoices()
        let systemLanguageCode = Locale.current.language.languageCode?.identifier ?? "en"
        let systemLangPrefix = String(systemLanguageCode.prefix(2))

        // Most voices should match system language (unless fallback to first 10)
        if voices.count < 10 {
            // Fallback mode - just verify we got voices
            #expect(!voices.isEmpty)
        } else {
            // Should have filtered to system language
            let matchingVoices = voices.filter { voice in
                guard let lang = voice.language else { return false }
                return String(lang.prefix(2)) == systemLangPrefix
            }
            #expect(matchingVoices.count > 0)
        }
    }

    // MARK: - Audio Generation Tests

    @Test("Audio generation returns data")
    func generateAudioReturnsData() async throws {
        let voices = try await engine.fetchVoices()
        guard let firstVoice = voices.first else {
            Issue.record("No voices available for testing")
            return
        }

        let text = "Hello, this is a test."
        let audioData = try await engine.generateAudio(text: text, voiceId: firstVoice.id)

        #expect(!audioData.isEmpty)
        #expect(audioData.count > 1024)
    }

    @Test("Audio generation with empty text throws error")
    func generateAudioWithEmptyTextThrowsError() async throws {
        let voices = try await engine.fetchVoices()
        guard let firstVoice = voices.first else {
            Issue.record("No voices available for testing")
            return
        }

        await #expect(throws: VoiceProviderError.self) {
            try await engine.generateAudio(text: "", voiceId: firstVoice.id)
        }
    }

    @Test("Audio generation with whitespace-only text throws error")
    func generateAudioWithWhitespaceOnlyTextThrowsError() async throws {
        let voices = try await engine.fetchVoices()
        guard let firstVoice = voices.first else {
            Issue.record("No voices available for testing")
            return
        }

        await #expect(throws: VoiceProviderError.self) {
            try await engine.generateAudio(text: "   \n\t   ", voiceId: firstVoice.id)
        }
    }

    #if !targetEnvironment(simulator)
    @Test("Audio generation produces valid audio format")
    func generateAudioProducesValidAudioFormat() async throws {
        // Skip on CI - requires real TTS voices for valid audio format
        if ProcessInfo.processInfo.environment["CI"] != nil {
            return
        }

        let voices = try await engine.fetchVoices()
        guard let firstVoice = voices.first else {
            Issue.record("No voices available for testing")
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
        #expect(audioFile.processingFormat != nil)
        #expect(audioFile.length > 0)
    }

    @Test("Audio generation produces 16-bit PCM format (AVAudioPlayer compatible)",
          .enabled(if: !ProcessInfo.processInfo.environment.keys.contains("CI")))
    func generateAudioProduces16BitPCM() async throws {

        let voices = try await engine.fetchVoices()
        guard let firstVoice = voices.first else {
            Issue.record("No voices available for testing")
            return
        }

        let text = "Testing 16-bit PCM format."
        let audioData = try await engine.generateAudio(text: text, voiceId: firstVoice.id)

        // Write to temp file and check format
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("aiff")

        try audioData.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        // Verify format using AVAudioFile
        let audioFile = try AVAudioFile(forReading: tempURL)
        let format = audioFile.fileFormat

        // We manually convert Float32 to Int16 for AVAudioPlayer compatibility
        let settings = format.settings
        let formatID = settings[AVFormatIDKey] as? UInt32
        let bitDepth = settings[AVLinearPCMBitDepthKey] as? Int
        let isFloat = settings[AVLinearPCMIsFloatKey] as? Bool

        #expect(formatID == kAudioFormatLinearPCM, "Expected LPCM format")
        #expect(bitDepth == 16, "Expected 16-bit depth")
        #expect(isFloat == false, "Expected integer PCM, not float")
    }

    @Test("Generated audio is playable by AVAudioPlayer",
          .enabled(if: !ProcessInfo.processInfo.environment.keys.contains("CI")))
    func generatedAudioIsPlayableByAVAudioPlayer() async throws {
        let voices = try await engine.fetchVoices()
        guard let firstVoice = voices.first else {
            Issue.record("No voices available for testing")
            return
        }

        let text = "Testing AVAudioPlayer compatibility."
        let audioData = try await engine.generateAudio(text: text, voiceId: firstVoice.id)

        // Write to temp file
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("aiff")

        try audioData.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        // CRITICAL: Test that AVAudioPlayer can prepare the audio
        let player = try AVAudioPlayer(contentsOf: tempURL)

        // prepareToPlay() returns false if the format is not supported
        let prepareResult = player.prepareToPlay()
        #expect(prepareResult == true, "AVAudioPlayer.prepareToPlay() failed - audio format not compatible")

        // Verify player has valid duration (not 0.0 which indicates format error)
        #expect(player.duration > 0.0, "Player duration is 0.0 - indicates format incompatibility")

        // Verify player has correct channel count
        #expect(player.numberOfChannels > 0, "Player has no channels")
    }

    @Test("Generated audio with duration has correct format",
          .enabled(if: !ProcessInfo.processInfo.environment.keys.contains("CI")))
    func generateAudioWithDurationHasCorrectFormat() async throws {
        let voices = try await engine.fetchVoices()
        guard let firstVoice = voices.first else {
            Issue.record("No voices available for testing")
            return
        }

        let text = "Testing duration with format."
        let (audioData, duration) = try await engine.generateAudioWithDuration(
            text: text,
            voiceId: firstVoice.id,
            languageCode: "en"
        )

        // Write to temp file and check format
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("aiff")

        try audioData.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        // Verify it's 16-bit PCM when using generateAudioWithDuration
        let audioFile = try AVAudioFile(forReading: tempURL)
        let format = audioFile.fileFormat
        let settings = format.settings
        let bitDepth = settings[AVLinearPCMBitDepthKey] as? Int
        let isFloat = settings[AVLinearPCMIsFloatKey] as? Bool

        #expect(bitDepth == 16, "generateAudioWithDuration should produce 16-bit PCM")
        #expect(isFloat == false, "generateAudioWithDuration should produce integer format")
        #expect(duration > 0, "Duration should be positive")

        // Verify AVAudioPlayer compatibility
        let player = try AVAudioPlayer(contentsOf: tempURL)
        #expect(player.prepareToPlay() == true, "AVAudioPlayer should be able to play generateAudioWithDuration output")
    }
    #endif

    @Test("Audio generation with different voices")
    func generateAudioWithDifferentVoices() async throws {
        let voices = try await engine.fetchVoices()
        let voicesToTest = Array(voices.prefix(min(3, voices.count)))

        guard voicesToTest.count > 1 else {
            Issue.record("Need at least 2 voices for this test")
            return
        }

        let text = "Testing multiple voices."

        for voice in voicesToTest {
            let audioData = try await engine.generateAudio(text: text, voiceId: voice.id)
            #expect(!audioData.isEmpty)
        }
    }

    // MARK: - Duration Estimation Tests

    @Test("Duration estimation returns positive value")
    func estimateDurationReturnsPositiveValue() {
        let duration = engine.estimateDuration(text: "Hello world", voiceId: "any-voice-id")
        #expect(duration > 0)
    }

    @Test("Duration estimation scales with text length")
    func estimateDurationScalesWithTextLength() {
        let shortText = "Hello"
        let mediumText = String(repeating: shortText + " ", count: 10)
        let longText = String(repeating: shortText + " ", count: 100)

        let shortDuration = engine.estimateDuration(text: shortText, voiceId: "any")
        let mediumDuration = engine.estimateDuration(text: mediumText, voiceId: "any")
        let longDuration = engine.estimateDuration(text: longText, voiceId: "any")

        #expect(shortDuration < mediumDuration)
        #expect(mediumDuration < longDuration)
    }

    @Test("Duration estimation has minimum value")
    func estimateDurationHasMinimumValue() {
        let emptyDuration = engine.estimateDuration(text: "", voiceId: "any")
        #expect(emptyDuration >= 1.0)
    }

    @Test("Duration estimation is reasonable")
    func estimateDurationIsReasonable() {
        let text = "This is approximately fifty characters long text"
        let duration = engine.estimateDuration(text: text, voiceId: "any")

        // ~50 chars at 14.5 chars/sec * 1.1 buffer ≈ 3.8 seconds
        #expect(duration > 2.0)
        #expect(duration < 10.0)
    }

    // MARK: - Platform-Specific Tests

    #if targetEnvironment(simulator)
    @Test("Simulator generates placeholder audio")
    func simulatorGeneratesPlaceholderAudio() async throws {
        let voices = try await engine.fetchVoices()
        guard let firstVoice = voices.first else {
            Issue.record("No voices available")
            return
        }

        let text = "Simulator test"
        let audioData = try await engine.generateAudio(text: text, voiceId: firstVoice.id)

        // Should still get valid audio data (placeholder)
        #expect(!audioData.isEmpty)
        #expect(audioData.count > 1024)
    }
    #else
    @Test("Physical device generates real audio")
    func physicalDeviceGeneratesRealAudio() async throws {
        // Skip on CI - requires real TTS voices to check AIFC format
        if ProcessInfo.processInfo.environment["CI"] != nil {
            return
        }

        let voices = try await engine.fetchVoices()
        guard let firstVoice = voices.first else {
            Issue.record("No voices available")
            return
        }

        let text = "Physical device test"
        let audioData = try await engine.generateAudio(text: text, voiceId: firstVoice.id)

        // Should get real TTS audio
        #expect(!audioData.isEmpty)
        #expect(audioData.count > 1024)

        // Verify it's AIFC format (real TTS output)
        let header = audioData.prefix(12)
        let headerString = String(data: header, encoding: .ascii) ?? ""
        // Real TTS typically produces AIFC format
        #expect(headerString.contains("FORM") || headerString.contains("AIFC") || headerString.contains("AIFF"))
    }
    #endif
}

#endif
