//
//  AppleTTSEngineBoundary.swift
//  SwiftHablare
//
//  Implements the engine boundary protocol for Apple system TTS engines.
//

import Foundation

struct AppleTTSConfiguration: Sendable {
    init() {}
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
        try await underlying.fetchVoices(languageCode: languageCode)
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

        #if os(iOS) || targetEnvironment(macCatalyst)
        let format: VoiceEngineAudioFormat = .aifc
        #else
        let format: VoiceEngineAudioFormat = .aiff
        #endif

        return VoiceEngineOutput(
            audioData: data,
            audioFormat: format,
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
