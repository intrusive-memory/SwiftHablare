//
//  AppleTTSEngineBoundary.swift
//  SwiftHablare
//
//  Implements the engine boundary protocol for Apple system TTS engines.
//

import Foundation

struct AppleTTSConfiguration: Sendable {
    /// If true, only show Enhanced and Premium quality voices. Default: false (show all voices)
    var filterToHighQualityOnly: Bool

    init(filterToHighQualityOnly: Bool = false) {
        self.filterToHighQualityOnly = filterToHighQualityOnly
    }
}

/// Adapter that exposes AppleTTSEngine implementations through the engine boundary.
struct AppleTTSEngineBoundary: VoiceEngine {
    typealias Configuration = AppleTTSConfiguration

    let underlying: any AppleTTSEngine

    init(underlying: any AppleTTSEngine) {
        self.underlying = underlying
    }

    var engineId: String { "apple.system.tts" }

    func canGenerate(with configuration: AppleTTSConfiguration) -> Bool {
        // Apple engines are always available on supported platforms once initialized.
        true
    }

    func fetchVoices(languageCode: String, configuration: AppleTTSConfiguration) async throws -> [Voice] {
        let voices = try await underlying.fetchVoices(languageCode: languageCode)

        // Apply quality filter if enabled
        if configuration.filterToHighQualityOnly {
            return voices.filter { voice in
                guard let quality = voice.quality else { return false }
                return quality == "enhanced" || quality == "premium"
            }
        }

        return voices
    }

    func generateAudio(
        request: VoiceEngineRequest,
        configuration: AppleTTSConfiguration
    ) async throws -> VoiceEngineOutput {
        let data = try await underlying.generateAudio(
            text: request.text,
            voiceId: request.voiceId,
            languageCode: request.languageCode
        )

        #if os(iOS)
        let format: VoiceEngineAudioFormat = .aifc
        let fileExtension = "aifc"
        #else
        let format: VoiceEngineAudioFormat = .aiff
        let fileExtension = "aiff"
        #endif
        let mimeType = "audio/aiff"

        return VoiceEngineOutput(
            audioData: data,
            audioFormat: format,
            fileExtension: fileExtension,
            mimeType: mimeType,
            metadata: [
                "engineId": engineId,
                "voiceId": request.voiceId,
                "languageCode": request.languageCode
            ]
        )
    }

    func estimateDuration(
        request: VoiceEngineRequest,
        configuration: AppleTTSConfiguration
    ) -> TimeInterval {
        underlying.estimateDuration(text: request.text, voiceId: request.voiceId)
    }

    func isVoiceAvailable(
        voiceId: String,
        configuration: AppleTTSConfiguration
    ) async -> Bool {
        do {
            let voices = try await underlying.fetchVoices()
            return voices.contains { $0.id == voiceId }
        } catch {
            return false
        }
    }
}
