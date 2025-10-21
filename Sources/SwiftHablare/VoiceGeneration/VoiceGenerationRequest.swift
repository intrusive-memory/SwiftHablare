//
//  VoiceGenerationRequest.swift
//  SwiftHablare
//
//  Sendable request for thread-safe voice generation
//

import Foundation

/// Thread-safe request for voice generation.
///
/// This struct is Sendable, allowing it to be safely passed between threads.
/// Use this to initiate voice generation on a background thread.
///
/// ## Thread Safety
/// - Sendable: Can be passed across actor boundaries
/// - Immutable: All properties are let constants
/// - Value type: No shared mutable state
///
/// ## Example
/// ```swift
/// let request = VoiceGenerationRequest(
///     text: "Hello, world!",
///     voiceId: "21m00Tcm4TlvDq8ikWAM",
///     providerId: "elevenlabs",
///     requestorId: "elevenlabs.audio.tts",
///     mimeType: "audio/mpeg",
///     modelIdentifier: "eleven_monolingual_v1"
/// )
///
/// let result = await service.generate(request)
/// ```
public struct VoiceGenerationRequest: Sendable {

    // MARK: - Identity

    /// Unique identifier for this request
    public let id: UUID

    // MARK: - Input

    /// Text to convert to speech
    public let text: String

    /// Voice ID to use for generation
    public let voiceId: String

    /// Human-readable voice name (optional)
    public let voiceName: String?

    // MARK: - Provider Configuration

    /// Provider identifier (e.g., "elevenlabs", "openai")
    public let providerId: String

    /// Requestor identifier (e.g., "elevenlabs.audio.tts")
    public let requestorId: String

    /// Model identifier (e.g., "eleven_monolingual_v1")
    public let modelIdentifier: String?

    // MARK: - Output Configuration

    /// Desired MIME type for output (e.g., "audio/mpeg", "audio/wav")
    public let mimeType: String

    /// Whether to store result in external file (for large audio)
    public let useFileStorage: Bool

    // MARK: - Metadata

    /// Optional metadata for the request
    public let metadata: [String: String]

    // MARK: - Initialization

    /// Creates a voice generation request
    ///
    /// - Parameters:
    ///   - id: Unique identifier (defaults to new UUID)
    ///   - text: Text to convert to speech
    ///   - voiceId: Voice ID to use
    ///   - voiceName: Human-readable voice name (optional)
    ///   - providerId: Provider identifier
    ///   - requestorId: Requestor identifier
    ///   - modelIdentifier: Model identifier (optional)
    ///   - mimeType: Desired output MIME type
    ///   - useFileStorage: Whether to use file storage (defaults to true)
    ///   - metadata: Additional metadata (defaults to empty)
    public init(
        id: UUID = UUID(),
        text: String,
        voiceId: String,
        voiceName: String? = nil,
        providerId: String,
        requestorId: String,
        modelIdentifier: String? = nil,
        mimeType: String = "audio/mpeg",
        useFileStorage: Bool = true,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.text = text
        self.voiceId = voiceId
        self.voiceName = voiceName
        self.providerId = providerId
        self.requestorId = requestorId
        self.modelIdentifier = modelIdentifier
        self.mimeType = mimeType
        self.useFileStorage = useFileStorage
        self.metadata = metadata
    }
}

// MARK: - Identifiable

extension VoiceGenerationRequest: Identifiable {}

// MARK: - CustomStringConvertible

extension VoiceGenerationRequest: CustomStringConvertible {
    public var description: String {
        "VoiceGenerationRequest(id: \(id), text: \"\(text.prefix(30))...\", voice: \(voiceId), provider: \(providerId))"
    }
}
