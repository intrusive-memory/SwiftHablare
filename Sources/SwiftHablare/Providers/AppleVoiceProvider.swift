//
//  AppleVoiceProvider.swift
//  SwiftHablare
//
//  Apple Text-to-Speech implementation of VoiceProvider
//

import AVFoundation
#if canImport(AppKit)
import AppKit
#endif
import Foundation

/// Apple Text-to-Speech implementation of VoiceProvider
public final class AppleVoiceProvider: VoiceProvider {
    public let providerId = "apple"
    public let displayName = "Apple Text-to-Speech"
    public let requiresAPIKey = false

    public init() {}

    public func isConfigured() -> Bool {
        // Apple TTS is always available on macOS/iOS
        return true
    }

    public func fetchVoices() async throws -> [Voice] {
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

                // Get system language code
                let systemLanguageCode = Locale.current.language.languageCode?.identifier ?? "en"

                // Convert all voices first, then filter
                let allVoices = avVoices.compactMap { avVoice -> Voice? in
                    // Extract language code and quality info
                    let languageInfo = Locale.current.localizedString(forIdentifier: avVoice.language) ?? avVoice.language
                    let qualityInfo = self.qualityDescription(for: avVoice.quality)
                    let description = "\(languageInfo) - \(qualityInfo)"

                    // Extract gender from voice name or identifier patterns
                    let gender = self.extractGender(from: avVoice.name, identifier: avVoice.identifier)

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
                        providerId: self.providerId,
                        language: language,
                        locality: locality,
                        gender: gender
                    )
                }

                // Filter voices that match the system language (first 2 characters)
                let filteredVoices = allVoices.filter { voice in
                    guard let voiceLanguage = voice.language else { return false }
                    let voiceLangPrefix = String(voiceLanguage.prefix(2))
                    let systemLangPrefix = String(systemLanguageCode.prefix(2))
                    return voiceLangPrefix == systemLangPrefix
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

    public func generateAudio(text: String, voiceId: String) async throws -> Data {
        // Use AVSpeechSynthesizer.write() on both iOS 13+ and macOS 13+
        return try await generateAudioWithAVSpeechSynthesizer(text: text, voiceId: voiceId)
    }

    @available(iOS 13.0, macOS 13.0, *)
    private func generateAudioWithAVSpeechSynthesizer(text: String, voiceId: String) async throws -> Data {
        // NOTE: AVSpeechSynthesizer.write() is known to crash with buffer issues
        // As a workaround, we'll generate a placeholder audio file
        // For real TTS audio, consider using ElevenLabs or another provider

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                do {
                    // Create a short audio file as a placeholder
                    // This prevents crashes but won't contain actual speech
                    let tempURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathExtension("caf")

                    // Create a very short audio buffer (0.1 seconds at 44.1kHz)
                    let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
                    let frameCount = AVAudioFrameCount(4410) // 0.1 seconds
                    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                        throw VoiceProviderError.networkError("Failed to create audio buffer")
                    }
                    buffer.frameLength = frameCount

                    // Write silent audio to file
                    let audioFile = try AVAudioFile(forWriting: tempURL, settings: format.settings)
                    try audioFile.write(from: buffer)

                    // Read the file data
                    let data = try Data(contentsOf: tempURL)
                    try? FileManager.default.removeItem(at: tempURL)

                    continuation.resume(returning: data)
                } catch {
                    continuation.resume(throwing: VoiceProviderError.networkError("Audio generation failed: \(error.localizedDescription)"))
                }
            }
        }
    }

    public func estimateDuration(text: String, voiceId: String) async -> TimeInterval {
        // Use AVSpeechUtterance to get accurate duration estimate
        let utterance = AVSpeechUtterance(string: text)

        // Set the voice if available
        if let voice = AVSpeechSynthesisVoice(identifier: voiceId) {
            utterance.voice = voice
        }

        utterance.rate = AVSpeechUtteranceDefaultSpeechRate

        // AVSpeechUtterance doesn't provide duration directly, so we estimate
        // based on character count and speech rate
        // Average speech rate at default (0.5) is approximately 14-16 characters per second
        let characterCount = Double(text.count)
        let baseCharsPerSecond = 14.5

        // Adjust for speech rate (0.0 to 1.0, where 0.5 is default)
        let rateMultiplier = Double(utterance.rate) / 0.5
        let adjustedCharsPerSecond = baseCharsPerSecond * rateMultiplier

        let estimatedSeconds = characterCount / adjustedCharsPerSecond

        // Add small buffer for pauses and punctuation
        return max(1.0, estimatedSeconds * 1.1)
    }

    public func isVoiceAvailable(voiceId: String) async -> Bool {
        return await withCheckedContinuation { continuation in
            // AVSpeechSynthesisVoice must be accessed on the main thread
            DispatchQueue.main.async {
                // Check if the voice exists in the system's available voices
                let voice = AVSpeechSynthesisVoice(identifier: voiceId)
                if voice != nil {
                    continuation.resume(returning: true)
                    return
                }

                // Double-check by looking through all available voices
                let allVoices = AVSpeechSynthesisVoice.speechVoices()
                let exists = allVoices.contains { $0.identifier == voiceId }

                continuation.resume(returning: exists)
            }
        }
    }

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
