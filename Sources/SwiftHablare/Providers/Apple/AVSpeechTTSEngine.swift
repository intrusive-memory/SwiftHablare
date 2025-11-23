//
//  AVSpeechTTSEngine.swift
//  SwiftHablare
//
//  iOS implementation using AVSpeechSynthesizer
//

#if canImport(UIKit)
import UIKit
import AVFoundation

/// iOS implementation of Apple TTS using AVSpeechSynthesizer
///
/// **Platform Support:**
/// - **iOS 13+**: Full TTS support with real audio generation
/// - **iOS Simulator**: Generates placeholder silent audio (API limitation)
///
/// **Audio Output:**
/// - **Physical Device**: AIFC format with actual synthesized speech
/// - **Simulator**: AIFF format with silent placeholder audio
@available(iOS 13.0, *)
final class AVSpeechTTSEngine: AppleTTSEngine {

    // MARK: - AppleTTSEngine Implementation

    func generateAudio(text: String, voiceId: String, languageCode: String) async throws -> Data {
        // Validate text is not empty
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw VoiceProviderError.invalidRequest("Text cannot be empty")
        }

        #if targetEnvironment(simulator)
        // iOS Simulator: Generate placeholder audio
        return try await generatePlaceholderAudio(text: text)
        #else
        // Physical iOS Device: Use real TTS
        // Note: languageCode is used for voice selection, but actual voice is determined by voiceId
        return try await generateRealAudio(text: text, voiceId: voiceId)
        #endif
    }

    func fetchVoices(languageCode: String) async throws -> [Voice] {
        return try await withCheckedThrowingContinuation { continuation in
            // AVSpeechSynthesisVoice must be accessed on the main thread
            DispatchQueue.main.async {
                // Get all available AVSpeechSynthesisVoice instances
                let avVoices = AVSpeechSynthesisVoice.speechVoices()

                // Ensure we have voices available
                guard !avVoices.isEmpty else {
                    continuation.resume(throwing: VoiceProviderError.invalidResponse)
                    return
                }

                // Use provided language code for filtering
                // Convert all voices first, then filter
                let allVoices = avVoices.compactMap { avVoice -> Voice? in
                    // Extract language code and quality info
                    let languageInfo = Locale.current.localizedString(forIdentifier: avVoice.language) ?? avVoice.language
                    let qualityInfo = self.qualityDescription(for: avVoice.quality)
                    let description = "\(languageInfo) - \(qualityInfo)"

                    // Extract gender from voice name or identifier patterns
                    let gender = self.extractGender(from: avVoice.name, identifier: avVoice.identifier)

                    // Store quality as string for filtering
                    let qualityString = self.qualityString(for: avVoice.quality)

                    // Split language code on dash or underscore
                    let components = avVoice.language.components(separatedBy: CharacterSet(charactersIn: "_-"))

                    var language: String?
                    var locality: String?

                    if components.count >= 1 {
                        language = components[0]
                    }
                    if components.count >= 2 {
                        locality = components[1]
                    }

                    return Voice(
                        id: avVoice.identifier,
                        name: avVoice.name,
                        description: description,
                        providerId: "apple",
                        language: language,
                        locality: locality,
                        gender: gender,
                        quality: qualityString
                    )
                }

                // Filter voices that match the requested language (first 2 characters)
                let filteredVoices = allVoices.filter { voice in
                    guard let voiceLanguage = voice.language else { return false }
                    let voiceLangPrefix = String(voiceLanguage.prefix(2))
                    let requestedLangPrefix = String(languageCode.prefix(2))
                    return voiceLangPrefix == requestedLangPrefix
                }

                // If no voices match system language, return a reasonable subset of all voices
                let result = filteredVoices.isEmpty ? Array(allVoices.prefix(10)) : filteredVoices

                guard !result.isEmpty else {
                    continuation.resume(throwing: VoiceProviderError.invalidResponse)
                    return
                }

                continuation.resume(returning: result)
            }
        }
    }

    func estimateDuration(text: String, voiceId: String) -> TimeInterval {
        // Average speech rate at default (0.5) is approximately 14-16 characters per second
        let characterCount = Double(text.count)
        let baseCharsPerSecond = 14.5

        let estimatedSeconds = characterCount / baseCharsPerSecond

        // Add small buffer for pauses and punctuation
        return max(1.0, estimatedSeconds * 1.1)
    }

    // MARK: - Real Audio Generation (Physical Device)

    private func generateRealAudio(text: String, voiceId: String) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                do {
                    let utterance = AVSpeechUtterance(string: text)

                    // Set the voice if available
                    if let voice = AVSpeechSynthesisVoice(identifier: voiceId) {
                        utterance.voice = voice
                    }

                    let synthesizer = AVSpeechSynthesizer()
                    let tempURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathExtension("aiff")

                    var audioFile: AVAudioFile?
                    var bufferCount = 0

                    // Write synthesized speech to file, capturing each audio buffer
                    synthesizer.write(utterance) { buffer in
                        // Cast to PCM buffer (AVSpeechSynthesizer provides PCM buffers)
                        guard let pcmBuffer = buffer as? AVAudioPCMBuffer else {
                            return
                        }

                        do {
                            // Create the file on first buffer using the buffer's format
                            if audioFile == nil {
                                audioFile = try AVAudioFile(forWriting: tempURL, settings: pcmBuffer.format.settings)
                            }

                            // Write this buffer to the file
                            if let file = audioFile {
                                try file.write(from: pcmBuffer)
                                bufferCount += 1
                            }
                        } catch {
                            #if DEBUG
                            print("Error writing audio buffer: \(error)")
                            #endif
                        }
                    }

                    // If no buffers were generated, fall back to placeholder
                    if bufferCount == 0 {
                        try? FileManager.default.removeItem(at: tempURL)
                        #if DEBUG
                        print("⚠️  No audio buffers generated. Falling back to placeholder audio...")
                        #endif
                        let placeholderData = try await self.generatePlaceholderAudio(text: text)
                        continuation.resume(returning: placeholderData)
                        return
                    }

                    // Read the complete synthesized audio file
                    let data = try Data(contentsOf: tempURL)

                    // Clean up temporary file
                    try? FileManager.default.removeItem(at: tempURL)

                    // Validate we got non-trivial audio data
                    guard data.count > 1024 else {
                        throw VoiceProviderError.networkError("Generated audio is too short (\(data.count) bytes)")
                    }

                    continuation.resume(returning: data)
                } catch {
                    continuation.resume(throwing: VoiceProviderError.networkError("Audio generation failed: \(error.localizedDescription)"))
                }
            }
        }
    }

    // MARK: - Placeholder Audio Generation (Simulator)

    private func generatePlaceholderAudio(text: String) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                do {
                    // Create minimal valid AIFF audio for simulator testing
                    let tempURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathExtension("aiff")

                    let format = AVAudioFormat(standardFormatWithSampleRate: 22050, channels: 1)!
                    // Generate minimal audio based on text length (rough estimation)
                    let estimatedDuration = Double(text.count) / 14.5
                    let frameCount = AVAudioFrameCount(22050 * estimatedDuration)

                    guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                        throw VoiceProviderError.networkError("Failed to create audio buffer")
                    }
                    pcmBuffer.frameLength = frameCount

                    // Fill the buffer with zeros (silence)
                    if let channelData = pcmBuffer.floatChannelData {
                        for channel in 0..<Int(pcmBuffer.format.channelCount) {
                            memset(channelData[channel], 0, Int(frameCount) * MemoryLayout<Float>.size)
                        }
                    }

                    // Write to AIFF file
                    let settings: [String: Any] = [
                        AVFormatIDKey: kAudioFormatLinearPCM,
                        AVSampleRateKey: 22050.0,
                        AVNumberOfChannelsKey: 1,
                        AVLinearPCMBitDepthKey: 16,
                        AVLinearPCMIsFloatKey: false,
                        AVLinearPCMIsBigEndianKey: true
                    ]
                    let audioFile = try AVAudioFile(forWriting: tempURL, settings: settings, commonFormat: .pcmFormatInt16, interleaved: false)
                    try audioFile.write(from: pcmBuffer)

                    let data = try Data(contentsOf: tempURL)
                    try? FileManager.default.removeItem(at: tempURL)

                    #if DEBUG
                    print("⚠️  Generated placeholder silent audio (\(data.count) bytes, duration: \(String(format: "%.2f", estimatedDuration))s)")
                    print("   Note: Real TTS audio generation is not supported in iOS Simulator.")
                    #endif
                    continuation.resume(returning: data)
                } catch {
                    continuation.resume(throwing: VoiceProviderError.networkError("Audio generation failed: \(error.localizedDescription)"))
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func qualityDescription(for quality: AVSpeechSynthesisVoiceQuality) -> String {
        switch quality {
        case .default:
            return "Standard Quality"
        case .enhanced:
            return "Enhanced Quality"
        case .premium:
            return "Premium Quality"
        @unknown default:
            return "Unknown Quality"
        }
    }

    private func qualityString(for quality: AVSpeechSynthesisVoiceQuality) -> String {
        switch quality {
        case .default:
            return "default"
        case .enhanced:
            return "enhanced"
        case .premium:
            return "premium"
        @unknown default:
            return "default"
        }
    }

    private func extractGender(from name: String, identifier: String) -> String? {
        let lowercaseName = name.lowercased()
        let lowercaseIdentifier = identifier.lowercased()

        // Common patterns in Apple voice names
        let maleIndicators = ["alex", "daniel", "diego", "fred", "jorge", "juan", "luca", "magnus", "marvin", "nicky", "thomas", "yuri"]
        let femaleIndicators = ["allison", "ava", "bella", "fiona", "joana", "karen", "kate", "laura", "lekha", "melina", "moira", "nora", "paulina", "samantha", "sara", "tessa", "veena", "victoria", "yelda", "zoe", "zosia"]

        // Check if the name contains known male indicators
        for indicator in maleIndicators {
            if lowercaseName.contains(indicator) || lowercaseIdentifier.contains(indicator) {
                return "male"
            }
        }

        // Check if the name contains known female indicators
        for indicator in femaleIndicators {
            if lowercaseName.contains(indicator) || lowercaseIdentifier.contains(indicator) {
                return "female"
            }
        }

        // If we can't determine, return nil
        return nil
    }
}

#endif
