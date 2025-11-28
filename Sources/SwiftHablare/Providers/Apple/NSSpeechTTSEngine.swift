//
//  NSSpeechTTSEngine.swift
//  SwiftHablare
//
//  macOS implementation using NSSpeechSynthesizer
//

#if os(macOS)
import AppKit
import AVFoundation
import ObjectiveC

/// macOS implementation of Apple TTS using NSSpeechSynthesizer
///
/// **Platform Support:**
/// - **macOS 10.13+**: Full TTS support with real audio generation
///
/// **Audio Output:**
/// - AIFF format with actual synthesized speech
@available(macOS 10.13, *)
final class NSSpeechTTSEngine: AppleTTSEngine {

    // MARK: - AppleTTSEngine Implementation

    func generateAudio(text: String, voiceId: String, languageCode: String) async throws -> Data {
        // Validate text is not empty
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw VoiceProviderError.invalidRequest("Text cannot be empty")
        }

        // Note: languageCode is used for voice selection, but actual voice is determined by voiceId
        return try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                do {
                    // Create synthesizer
                    let synthesizer = NSSpeechSynthesizer()

                    // Set voice if specified
                    let voiceName = NSSpeechSynthesizer.VoiceName(rawValue: voiceId)
                    synthesizer.setVoice(voiceName)

                    // Create temp file for output
                    let tempURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathExtension("aiff")

                    // Create delegate to handle completion
                    let delegate = NSSpeechDelegate { success in
                        if success {
                            do {
                                let data = try Data(contentsOf: tempURL)
                                try? FileManager.default.removeItem(at: tempURL)

                                // Validate we got non-trivial audio data
                                guard data.count > 1024 else {
                                    continuation.resume(throwing: VoiceProviderError.networkError("Generated audio is too short (\(data.count) bytes)"))
                                    return
                                }

                                continuation.resume(returning: data)
                            } catch {
                                continuation.resume(throwing: VoiceProviderError.networkError("Failed to read audio: \(error.localizedDescription)"))
                            }
                        } else {
                            try? FileManager.default.removeItem(at: tempURL)
                            continuation.resume(throwing: VoiceProviderError.networkError("Speech synthesis failed"))
                        }
                    }

                    synthesizer.delegate = delegate

                    // Start speaking to file
                    let started = synthesizer.startSpeaking(text, to: tempURL)

                    if !started {
                        throw VoiceProviderError.networkError("Failed to start speech synthesis")
                    }

                    // Keep delegate alive by storing it in associated objects
                    objc_setAssociatedObject(synthesizer, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)

                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func fetchVoices(languageCode: String) async throws -> [Voice] {
        return await MainActor.run {
            // Get all available voice names
            let voiceNames = NSSpeechSynthesizer.availableVoices

            // Ensure we have voices available
            guard !voiceNames.isEmpty else {
                return []
            }

            // Use provided language code for filtering
            // Convert all voices first
            let allVoices = voiceNames.compactMap { voiceName -> Voice? in
                let attributes = NSSpeechSynthesizer.attributes(forVoice: voiceName)

                // Extract voice attributes
                let name = attributes[.name] as? String ?? voiceName.rawValue
                let locale = attributes[.localeIdentifier] as? String ?? "en_US"
                let genderString = attributes[.gender] as? String

                // Parse locale into language and locality
                let components = locale.components(separatedBy: "_")
                let language = components.first
                let locality = components.count > 1 ? components[1] : nil

                // Create description from locale
                let description = Locale.current.localizedString(forIdentifier: locale) ?? locale

                // Map gender string to our gender type
                let gender: String?
                if let g = genderString {
                    if g.lowercased().contains("female") {
                        gender = "female"
                    } else if g.lowercased().contains("male") {
                        gender = "male"
                    } else {
                        gender = "neutral"
                    }
                } else {
                    gender = nil
                }

                // Extract quality from voice name
                // macOS voice names often include quality indicators like "Premium" or "Enhanced"
                let quality = self.extractQuality(from: name, identifier: voiceName.rawValue)

                return Voice(
                    id: voiceName.rawValue,
                    name: name,
                    description: description,
                    providerId: "apple",
                    language: language,
                    locality: locality,
                    gender: gender,
                    quality: quality
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

            return result
        }
    }

    func estimateDuration(text: String, voiceId: String) -> TimeInterval {
        // Average speech rate at default is approximately 14-16 characters per second
        let characterCount = Double(text.count)
        let baseCharsPerSecond = 14.5

        let estimatedSeconds = characterCount / baseCharsPerSecond

        // Add small buffer for pauses and punctuation
        return max(1.0, estimatedSeconds * 1.1)
    }

    // MARK: - Helper Methods

    /// Extract quality level from voice name or identifier
    /// macOS NSSpeechSynthesizer doesn't expose quality directly, so we parse it from the name
    private func extractQuality(from name: String, identifier: String) -> String {
        let lowercasedName = name.lowercased()
        let lowercasedIdentifier = identifier.lowercased()

        // Check for quality indicators in name or identifier
        if lowercasedName.contains("premium") || lowercasedIdentifier.contains("premium") {
            return "premium"
        } else if lowercasedName.contains("enhanced") || lowercasedIdentifier.contains("enhanced") {
            return "enhanced"
        } else {
            // Default to "default" quality if no indicator found
            return "default"
        }
    }
}

// MARK: - NSSpeechSynthesizer Delegate

/// Delegate wrapper to convert NSSpeechSynthesizer's delegate-based API to async/await
private class NSSpeechDelegate: NSObject, NSSpeechSynthesizerDelegate {
    let onComplete: (Bool) -> Void

    init(onComplete: @escaping (Bool) -> Void) {
        self.onComplete = onComplete
        super.init()
    }

    func speechSynthesizer(_ sender: NSSpeechSynthesizer, didFinishSpeaking finishedSpeaking: Bool) {
        onComplete(finishedSpeaking)
    }
}

#endif
