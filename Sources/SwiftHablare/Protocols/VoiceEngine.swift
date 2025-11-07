//
//  VoiceEngine.swift
//  SwiftHablare
//
//  Defines the Engine Boundary Protocol used by voice providers to
//  separate generation engines from provider integration concerns.
//

import Foundation

/// Represents the audio format returned by a voice engine.
public enum VoiceEngineAudioFormat: String, Sendable, Codable {
    case aiff
    case aifc
    case mp3
    case wav
    case pcm16
    case unknown
}

/// Request payload for engine-based synthesis.
public struct VoiceEngineRequest: Sendable {
    public let text: String
    public let voiceId: String
    public let languageCode: String
    public let options: [String: String]

    public init(
        text: String,
        voiceId: String,
        languageCode: String,
        options: [String: String] = [:]
    ) {
        self.text = text
        self.voiceId = voiceId
        self.languageCode = languageCode
        self.options = options
    }
}

/// Response payload returned by a voice engine.
public struct VoiceEngineOutput: Sendable {
    public let audioData: Data
    public let audioFormat: VoiceEngineAudioFormat
    public let metadata: [String: String]

    public init(
        audioData: Data,
        audioFormat: VoiceEngineAudioFormat,
        metadata: [String: String] = [:]
    ) {
        self.audioData = audioData
        self.audioFormat = audioFormat
        self.metadata = metadata
    }
}

/// Engine Boundary Protocol – describes the contract that voice engines must implement.
///
/// The Engine Boundary separates low-level synthesis responsibilities (engines) from
/// provider integration concerns (API keys, caching, storage). Providers own
/// configuration management and translate between library APIs and the engine boundary.
public protocol VoiceEngine: Sendable {
    associatedtype Configuration: Sendable

    /// Unique identifier for the engine implementation.
    var engineId: String { get }

    /// Determine if the engine can generate with the supplied configuration.
    /// Providers typically check API keys, platform availability, etc.
    func canGenerate(with configuration: Configuration) -> Bool

    /// Fetch voices from the engine for a language code.
    func fetchVoices(
        languageCode: String,
        configuration: Configuration
    ) async throws -> [Voice]

    /// Generate audio for a request with the supplied configuration.
    func generateAudio(
        request: VoiceEngineRequest,
        configuration: Configuration
    ) async throws -> VoiceEngineOutput

    /// Estimate duration for a request.
    func estimateDuration(
        request: VoiceEngineRequest,
        configuration: Configuration
    ) -> TimeInterval

    /// Determine if a voice identifier is available.
    func isVoiceAvailable(
        voiceId: String,
        configuration: Configuration
    ) async -> Bool
}

public extension VoiceEngine {
    /// Helper to wrap provider API into engine request.
    func makeRequest(
        text: String,
        voiceId: String,
        languageCode: String,
        options: [String: String] = [:]
    ) -> VoiceEngineRequest {
        VoiceEngineRequest(text: text, voiceId: voiceId, languageCode: languageCode, options: options)
    }
}
