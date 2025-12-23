//
//  AVSpeechTTSEngine.swift
//  SwiftHablare
//
//  Implementation using AVSpeechSynthesizer for iOS and macOS
//

import AVFoundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Apple TTS implementation using AVSpeechSynthesizer
///
/// **Platform Support:**
/// - **iOS 26+**: Full TTS support with real audio generation
/// - **macOS 26+**: Full TTS support with real audio generation
/// - **iOS Simulator**: Generates placeholder silent audio (API limitation)
///
/// **Audio Output:**
/// - **Physical Device**: AIFC format with actual synthesized speech
/// - **Simulator**: AIFF format with silent placeholder audio
@available(iOS 13.0, macOS 14.0, *)
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
        let (data, _) = try await generateRealAudio(text: text, voiceId: voiceId)
        return data
        #endif
    }

    /// Generate audio with accurate duration measured from buffer frames
    /// - Returns: Tuple of (audio data, duration in seconds)
    func generateAudioWithDuration(text: String, voiceId: String, languageCode: String) async throws -> (Data, TimeInterval) {
        // Validate text is not empty
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw VoiceProviderError.invalidRequest("Text cannot be empty")
        }

        #if targetEnvironment(simulator)
        // iOS Simulator: Generate placeholder audio with estimated duration
        let data = try await generatePlaceholderAudio(text: text)
        let duration = Double(text.count) / 14.5
        return (data, duration)
        #else
        // Physical Device: Use real TTS with frame-calculated duration
        return try await generateRealAudio(text: text, voiceId: voiceId)
        #endif
    }

    func fetchVoices(languageCode: String) async throws -> [Voice] {
        // Use MainActor.run to properly execute on main thread from async context
        // This eliminates unsafeForcedSync warnings that occur with DispatchQueue.main.async
        return try await MainActor.run {
            #if DEBUG
            print("🎤 [AVSpeechTTSEngine] About to call AVSpeechSynthesisVoice.speechVoices()")
            print("🎤 [AVSpeechTTSEngine] Using MainActor.run (no unsafeForcedSync warnings)")
            print("🎤 [AVSpeechTTSEngine] Current thread: \(Thread.current)")
            print("🎤 [AVSpeechTTSEngine] Is main thread: \(Thread.isMainThread)")
            #endif

            // Get all available AVSpeechSynthesisVoice instances
            // AVSpeechSynthesisVoice must be accessed on the main thread
            let avVoices = AVSpeechSynthesisVoice.speechVoices()

            #if DEBUG
            print("🎤 [AVSpeechTTSEngine] Returned from AVSpeechSynthesisVoice.speechVoices() with \(avVoices.count) voices")
            #endif

            // Ensure we have voices available
            guard !avVoices.isEmpty else {
                throw VoiceProviderError.invalidResponse
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
                throw VoiceProviderError.invalidResponse
            }

            return result
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

    private func generateRealAudio(text: String, voiceId: String) async throws -> (Data, TimeInterval) {
        return try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                do {
                    let utterance = AVSpeechUtterance(string: text)

                    // Set the voice - throw error if voice doesn't exist
                    guard let voice = AVSpeechSynthesisVoice(identifier: voiceId) else {
                        throw VoiceProviderError.invalidRequest("Voice not found: \(voiceId)")
                    }
                    utterance.voice = voice

                    let synthesizer = AVSpeechSynthesizer()
                    let tempURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathExtension("aiff")

                    var audioFile: AVAudioFile?
                    var bufferCount = 0
                    var totalFrames: AVAudioFrameCount = 0
                    var sampleRate: Double = 0

                    // Create delegate to track completion
                    let delegate = SynthesizerDelegate()
                    synthesizer.delegate = delegate

                    // Write synthesized speech to file, capturing each audio buffer
                    #if DEBUG
                    print("🎤 [AVSpeechTTSEngine] Calling synthesizer.write() with utterance")
                    #endif

                    synthesizer.write(utterance) { buffer in
                        #if DEBUG
                        print("🎤 [AVSpeechTTSEngine] ✅ Buffer callback invoked! Buffer type: \(type(of: buffer))")
                        #endif

                        // Cast to PCM buffer (AVSpeechSynthesizer provides PCM buffers)
                        guard let pcmBuffer = buffer as? AVAudioPCMBuffer else {
                            #if DEBUG
                            print("🎤 [AVSpeechTTSEngine] ❌ Buffer is not AVAudioPCMBuffer")
                            #endif
                            return
                        }

                        #if DEBUG
                        print("🎤 [AVSpeechTTSEngine] ✅ Got PCM buffer with \(pcmBuffer.frameLength) frames")
                        print("🎤 [AVSpeechTTSEngine] Input format: \(pcmBuffer.format)")
                        #endif

                        do {
                            // Create the file on first buffer using the original format from AVSpeechSynthesizer
                            // Note: We write in the original format (typically Float32) to avoid conversion issues
                            // The audio can be converted to 16-bit PCM later if needed for playback compatibility
                            if audioFile == nil {
                                sampleRate = pcmBuffer.format.sampleRate

                                // Use the original format directly (no conversion needed)
                                audioFile = try AVAudioFile(forWriting: tempURL, settings: pcmBuffer.format.settings)

                                #if DEBUG
                                print("🎤 [AVSpeechTTSEngine] ✅ Created audio file with format: \(pcmBuffer.format)")
                                #endif
                            }

                            // Write buffer directly to file (no conversion)
                            if let file = audioFile {
                                try file.write(from: pcmBuffer)
                                bufferCount += 1
                                totalFrames += pcmBuffer.frameLength
                                #if DEBUG
                                print("🎤 [AVSpeechTTSEngine] ✅ Wrote buffer #\(bufferCount) (\(pcmBuffer.frameLength) frames)")
                                #endif
                            }
                        } catch {
                            #if DEBUG
                            print("🎤 [AVSpeechTTSEngine] ❌ Error writing audio buffer: \(error)")
                            #endif
                        }
                    }

                    // CRITICAL: Wait for synthesis to complete before checking buffer count
                    // The write() callback is asynchronous, so we need to wait for the delegate callback
                    #if DEBUG
                    print("🎤 [AVSpeechTTSEngine] Waiting for synthesis completion...")
                    #endif
                    await delegate.waitForCompletion()

                    #if DEBUG
                    print("🎤 [AVSpeechTTSEngine] Synthesis complete. Buffer count: \(bufferCount), Total frames: \(totalFrames)")
                    #endif

                    // If no buffers were generated, fall back to placeholder
                    if bufferCount == 0 {
                        try? FileManager.default.removeItem(at: tempURL)
                        #if DEBUG
                        print("⚠️  No audio buffers generated. Falling back to placeholder audio...")
                        #endif
                        let placeholderData = try await self.generatePlaceholderAudio(text: text)
                        // Estimate duration for placeholder (14.5 chars/sec)
                        let estimatedDuration = Double(text.count) / 14.5
                        continuation.resume(returning: (placeholderData, estimatedDuration))
                        return
                    }

                    // Calculate duration from frames and sample rate
                    let duration = sampleRate > 0 ? Double(totalFrames) / sampleRate : 0.0
                    #if DEBUG
                    print("🎤 [AVSpeechTTSEngine] ✅ Calculated duration: \(String(format: "%.2f", duration))s from \(totalFrames) frames at \(sampleRate) Hz")
                    #endif

                    // CRITICAL: Deallocate AVAudioFile to finalize AIFF header with correct file size
                    // If we read the file while AVAudioFile is still alive, the header won't be updated
                    audioFile = nil
                    #if DEBUG
                    print("🎤 [AVSpeechTTSEngine] ✅ AVAudioFile deallocated, AIFF header finalized")
                    #endif

                    // Read the complete synthesized audio file
                    let data = try Data(contentsOf: tempURL)

                    // Clean up temporary file
                    try? FileManager.default.removeItem(at: tempURL)

                    // Validate we got non-trivial audio data
                    guard data.count > 1024 else {
                        throw VoiceProviderError.networkError("Generated audio is too short (\(data.count) bytes)")
                    }

                    continuation.resume(returning: (data, duration))
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

                    // Generate minimal audio based on text length (rough estimation)
                    let estimatedDuration = Double(text.count) / 14.5
                    let sampleRate = 22050.0
                    let frameCount = AVAudioFrameCount(sampleRate * estimatedDuration)

                    // Use explicit Int16 PCM format for maximum compatibility with AVAssetExportSession
                    // This matches the format that AVSpeechSynthesizer typically generates
                    let settings: [String: Any] = [
                        AVFormatIDKey: kAudioFormatLinearPCM,
                        AVSampleRateKey: sampleRate,
                        AVNumberOfChannelsKey: 1,
                        AVLinearPCMBitDepthKey: 16,
                        AVLinearPCMIsFloatKey: false,
                        AVLinearPCMIsBigEndianKey: false,
                        AVLinearPCMIsNonInterleaved: false
                    ]

                    guard let format = AVAudioFormat(settings: settings) else {
                        throw VoiceProviderError.networkError("Failed to create audio format")
                    }

                    // Create audio file first
                    let audioFile = try AVAudioFile(forWriting: tempURL, settings: settings, commonFormat: .pcmFormatInt16, interleaved: false)

                    // Create buffer with proper capacity
                    guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                        throw VoiceProviderError.networkError("Failed to create audio buffer")
                    }

                    // CRITICAL: Set frameLength BEFORE accessing channel data
                    // This ensures the internal AudioBufferList is properly configured
                    pcmBuffer.frameLength = frameCount

                    // Fill with silence (zeros) - use int16ChannelData for Int16 format
                    if let channelData = pcmBuffer.int16ChannelData {
                        let byteSize = Int(frameCount) * MemoryLayout<Int16>.size
                        for channel in 0..<Int(pcmBuffer.format.channelCount) {
                            memset(channelData[channel], 0, byteSize)
                        }
                    }

                    // Write the buffer to file
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

// MARK: - Synthesizer Delegate

/// Delegate to track AVSpeechSynthesizer completion
///
/// Note: Not isolated to MainActor to avoid actor isolation conflicts with AVSpeechSynthesizerDelegate.
/// The delegate methods can be called from any thread, so we use thread-safe continuation handling.
private final class SynthesizerDelegate: NSObject, AVSpeechSynthesizerDelegate {
    private var continuation: CheckedContinuation<Void, Never>?

    /// Wait for synthesis to complete
    func waitForCompletion() async {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    /// Called when synthesis completes
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        #if DEBUG
        print("🎤 [SynthesizerDelegate] didFinish called")
        #endif
        continuation?.resume()
        continuation = nil
    }

    /// Called when synthesis is cancelled
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        #if DEBUG
        print("🎤 [SynthesizerDelegate] didCancel called")
        #endif
        continuation?.resume()
        continuation = nil
    }
}
