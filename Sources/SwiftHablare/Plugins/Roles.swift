//
//  Roles.swift
//  SwiftHablare
//
//  The roles a plugin can provide (R2): synthesis, streaming synthesis, voice design, and
//  a reserved voice-conversion role. A hybrid gets its roles from other plugins.
//

import Foundation

// MARK: - Capabilities and limits

public struct SynthesisCapabilities: OptionSet, Sendable, Hashable, Codable {
  public let rawValue: Int

  public init(rawValue: Int) { self.rawValue = rawValue }

  /// Honours `SpeechRequest.instruct`; otherwise it is dropped and reported.
  public static let instruct = SynthesisCapabilities(rawValue: 1 << 0)
  /// Conforms to ``StreamingVoiceSynthesizer``.
  public static let streaming = SynthesisCapabilities(rawValue: 1 << 1)
  public static let multiSpeaker = SynthesisCapabilities(rawValue: 1 << 2)
  /// Output is reproducible from `SpeechRequest.seed`; required for a non-nil cache key (R8).
  public static let seed = SynthesisCapabilities(rawValue: 1 << 3)
  public static let onDevice = SynthesisCapabilities(rawValue: 1 << 4)
}

/// Per-request input limits (R7). `nil` means the engine imposes no limit of that kind.
public struct SynthesisLimits: Sendable, Hashable {
  public var maxCharacters: Int?
  public var maxTokens: Int?
  public var maxBytes: Int?
  /// Longest reference clip the engine conditions on.
  public var maxReferenceSeconds: TimeInterval?

  public init(
    maxCharacters: Int? = nil,
    maxTokens: Int? = nil,
    maxBytes: Int? = nil,
    maxReferenceSeconds: TimeInterval? = nil
  ) {
    self.maxCharacters = maxCharacters
    self.maxTokens = maxTokens
    self.maxBytes = maxBytes
    self.maxReferenceSeconds = maxReferenceSeconds
  }

  public static let unlimited = SynthesisLimits()
}

// MARK: - Voice sources (R3 hybrid pairing)

/// Matches `.vox` sources by engine and kind; `nil` matches anything. A synthesizer lists the
/// sources it consumes as an ordered preference (Chatterbox: `google` reference audio, then
/// `qwen3-tts`, then any); a designer lists what it produces. The registry validates a
/// hybrid pairing with ``accepts(_:)``.
public struct VoiceSourcePattern: Sendable, Hashable {
  /// "google", "qwen3-tts", "elevenlabs"; `nil` matches any engine.
  public var engine: String?
  /// `nil` matches any kind.
  public var kind: VoiceSource.Kind?

  public init(engine: String? = nil, kind: VoiceSource.Kind? = nil) {
    self.engine = engine
    self.kind = kind
  }

  /// True when every source `produced` describes is matched by this pattern.
  public func accepts(_ produced: VoiceSourcePattern) -> Bool {
    if let engine, produced.engine != engine { return false }
    if let kind, produced.kind != kind { return false }
    return true
  }
}

// MARK: - Readiness and progress

public enum VoiceReadiness: Sendable, Hashable {
  /// Ready now. `source` names the `.vox` source synthesis will use (`nil` for catalog voices).
  case ready(source: VoiceSource?)
  /// `prepare(_:)` must run first (load embeddings, cut a reference clip, warm a model).
  case needsPreparation(source: VoiceSource?)
  case unsupported(reason: String)

  /// The source synthesis will use, when known.
  public var source: VoiceSource? {
    switch self {
    case .ready(let source), .needsPreparation(let source): return source
    case .unsupported: return nil
    }
  }
}

/// Honest progress. A fraction appears only when the engine truly knows it; hosts must not
/// invent one when `expected` is `nil`.
public enum SynthesisProgress: Sendable, Hashable {
  case started
  case tokens(generated: Int, expected: Int?)
  /// Streamed audio so far.
  case audio(seconds: TimeInterval)
  case finished
}

/// One piece of a streamed take.
public struct AudioChunk: Sendable {
  public var data: Data
  public var format: AudioFormat
  public var duration: TimeInterval
  public var isFinal: Bool

  public init(data: Data, format: AudioFormat, duration: TimeInterval, isFinal: Bool = false) {
    self.data = data
    self.format = format
    self.duration = duration
    self.isFinal = isFinal
  }
}

/// A cloud plugin's estimate of what a request will cost, in the engine's billing unit.
public struct CostEstimate: Sendable, Hashable {
  public enum Unit: String, Sendable, Hashable, Codable {
    case characters, tokens, credits, seconds
  }

  public var quantity: Double
  public var unit: Unit
  /// Approximate price in US dollars, when the plugin knows its rate.
  public var approximateUSD: Decimal?

  public init(quantity: Double, unit: Unit, approximateUSD: Decimal? = nil) {
    self.quantity = quantity
    self.unit = unit
    self.approximateUSD = approximateUSD
  }
}

// MARK: - Synthesis

public protocol VoiceSynthesizer: Sendable {
  var capabilities: SynthesisCapabilities { get }
  var limits: SynthesisLimits { get }
  var nativeFormats: [AudioFormat] { get }
  /// Local = 1; cloud from plugin configuration.
  var maxConcurrentRequests: Int { get }
  /// `.vox` sources this synthesizer consumes, most preferred first. Empty (the default)
  /// means it consumes none, e.g. a catalog-only engine.
  var consumedSources: [VoiceSourcePattern] { get }

  func readiness(for voice: VoiceReference) async -> VoiceReadiness
  /// Residency hook: load `.vox` embeddings, cut the reference clip, warm the model.
  func prepare(_ voice: VoiceReference) async throws
  /// Residency hook: drop whatever `prepare(_:)` loaded.
  func release(_ voice: VoiceReference) async
  func synthesize(_ request: SpeechRequest) async throws -> GeneratedAudio
  /// Synthesis with honest progress. The default reports `.started`, calls
  /// ``synthesize(_:)``, then reports `.finished` (no `.finished` when it throws).
  func synthesize(
    _ request: SpeechRequest,
    progress: @escaping @Sendable (SynthesisProgress) -> Void
  ) async throws -> GeneratedAudio
  /// R8: `nil` when output is not reproducible (no `.seed`). The default returns `nil`.
  func cacheKey(for request: SpeechRequest) -> String?
  /// Cloud only. The default returns `nil`.
  func estimateCost(_ request: SpeechRequest) -> CostEstimate?
}

extension VoiceSynthesizer {
  public var consumedSources: [VoiceSourcePattern] { [] }

  public func synthesize(
    _ request: SpeechRequest,
    progress: @escaping @Sendable (SynthesisProgress) -> Void
  ) async throws -> GeneratedAudio {
    progress(.started)
    let audio = try await synthesize(request)
    progress(.finished)
    return audio
  }

  public func cacheKey(for request: SpeechRequest) -> String? { nil }

  public func estimateCost(_ request: SpeechRequest) -> CostEstimate? { nil }
}

public protocol StreamingVoiceSynthesizer: VoiceSynthesizer {
  func stream(_ request: SpeechRequest) -> AsyncThrowingStream<AudioChunk, Error>
}

// MARK: - Design

public struct VoiceDesignRequest: Sendable, Hashable {
  public enum Gender: String, Sendable, Hashable, Codable {
    case female, male, neutral
  }

  public enum Age: String, Sendable, Hashable, Codable {
    case child, young, adult, middleAged, senior
  }

  /// The voice prompt, e.g. a CAST.md `voicePrompt`.
  public var description: String
  /// The line the candidate previews speak.
  public var sampleText: String
  public var language: String?
  public var gender: Gender?
  public var age: Age?

  public init(
    description: String,
    sampleText: String,
    language: String? = nil,
    gender: Gender? = nil,
    age: Age? = nil
  ) {
    self.description = description
    self.sampleText = sampleText
    self.language = language
    self.gender = gender
    self.age = age
  }
}

public struct VoiceCandidate: Sendable {
  /// Engine-private reference to the designed voice. Core never interprets it.
  public struct Handle: Sendable, Hashable {
    /// e.g. a Gemini `voice_…` id or an ElevenLabs generated-voice id.
    public var identifier: String
    /// Engine-private bytes (e.g. an embedding), when the identifier alone is not enough.
    public var payload: Data?

    public init(identifier: String, payload: Data? = nil) {
      self.identifier = identifier
      self.payload = payload
    }
  }

  public var preview: GeneratedAudio
  public var handle: Handle
  /// The prompt actually sent to the engine, which may differ from the request's
  /// `description` when the plugin rewrote it. Recorded, never lost.
  public var promptSent: String

  public init(preview: GeneratedAudio, handle: Handle, promptSent: String) {
    self.preview = preview
    self.handle = handle
    self.promptSent = promptSent
  }
}

public protocol VoiceDesigner: Sendable {
  /// The `.vox` sources ``save(_:into:)`` writes, for hybrid pairing validation (R3, R11).
  var producedSources: [VoiceSourcePattern] { get }
  /// Creates voice candidates from a description and a line to speak.
  func design(_ request: VoiceDesignRequest) async throws -> [VoiceCandidate]
  /// Persists the chosen candidate: writes this engine's extension and sample into the `.vox`.
  func save(_ candidate: VoiceCandidate, into asset: inout VoiceAsset) async throws
  /// Server-side cleanup.
  func delete(_ voice: VoiceReference) async throws
}

// MARK: - Conversion (reserved)

/// Audio-to-audio voice conversion (speech-to-speech). Reserved: declared so a future engine
/// is additive, but no plugin provides it in 7.0 and core never calls it.
public protocol VoiceConverter: Sendable {
  func convert(_ audio: GeneratedAudio, to voice: VoiceReference) async throws -> GeneratedAudio
}
