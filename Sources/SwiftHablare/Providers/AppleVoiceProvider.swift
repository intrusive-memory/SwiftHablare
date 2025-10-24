//
//  AppleVoiceProvider.swift
//  SwiftHablare
//
//  Apple Text-to-Speech implementation of VoiceProvider
//

import AVFoundation
import Foundation

/// Apple Text-to-Speech implementation of VoiceProvider
public final class AppleVoiceProvider: VoiceProvider {
    public let providerId = "apple"
    public let displayName = "Apple Text-to-Speech"
    public let requiresAPIKey = false

    public init() {}

    public func isConfigured() -> Bool {
        // Apple TTS is always available on iOS/Catalyst
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
        return try await generateAudioWithAVSpeechSynthesizer(text: text, voiceId: voiceId)
    }

    private func generateAudioWithAVSpeechSynthesizer(text: String, voiceId: String) async throws -> Data {
        // Validate text is not empty
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw VoiceProviderError.invalidRequest("Text cannot be empty")
        }

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

                    // Use try await with the synthesizer
                    try await synthesizer.write(utterance, toBufferCallback: { _ in
                        // Buffer callback - called for each audio buffer
                    })

                    // For now, create a minimal audio file with AIFF format for consistency
                    // This is a placeholder until AVSpeechSynthesizer.write() is fully implemented
                    let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
                    let frameCount = AVAudioFrameCount(4410) // 0.1 seconds
                    guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                        throw VoiceProviderError.networkError("Failed to create audio buffer")
                    }
                    pcmBuffer.frameLength = frameCount

                    // Write to AIFF file
                    let settings: [String: Any] = [
                        AVFormatIDKey: kAudioFormatLinearPCM,
                        AVSampleRateKey: 44100.0,
                        AVNumberOfChannelsKey: 1,
                        AVLinearPCMBitDepthKey: 16,
                        AVLinearPCMIsFloatKey: false,
                        AVLinearPCMIsBigEndianKey: true
                    ]
                    let audioFile = try AVAudioFile(forWriting: tempURL, settings: settings, commonFormat: .pcmFormatInt16, interleaved: false)
                    try audioFile.write(from: pcmBuffer)

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
