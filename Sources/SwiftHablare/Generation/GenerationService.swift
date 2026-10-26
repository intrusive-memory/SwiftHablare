//
//  GenerationService.swift
//  SwiftHablare
//
//  Actor-based generation over `PluginRegistry` + `VoiceSynthesizer` (R12): a `SpeechRequest`
//  goes in, one `GeneratedAudio` in the service's target format comes out. Each request is
//  chunked to the synthesizer's limits (`TextChunker`), every chunk is synthesized through
//  `TakeValidator` and normalised with `AudioNormalizer`, and the chunks are joined.
//

import Foundation
import OSLog
import SwiftCompartido
import SwiftData

// MARK: - Progress and outcome

/// Progress of one ``GenerationService`` request: which chunk is being synthesized, and the
/// synthesizer's own ``SynthesisProgress`` for it, passed through unchanged.
public struct GenerationProgress: Sendable, Hashable {
  /// Zero-based index of the chunk being synthesized.
  public var chunk: Int
  /// Number of chunks the request was split into.
  public var chunkCount: Int
  /// The synthesizer's progress for this chunk. A retried take reports `.started` again.
  public var synthesis: SynthesisProgress

  public init(chunk: Int, chunkCount: Int, synthesis: SynthesisProgress) {
    self.chunk = chunk
    self.chunkCount = chunkCount
    self.synthesis = synthesis
  }

  /// Completed chunks over all chunks. Exact, because the chunk count is known up front.
  public var fractionCompleted: Double {
    guard chunkCount > 0 else { return 0 }
    let done = chunk + (synthesis == .finished ? 1 : 0)
    return Double(done) / Double(chunkCount)
  }
}

/// A generated request plus what the pipeline learned producing it.
public struct GenerationOutcome: Sendable {
  /// The joined audio, in the service's target format.
  public var audio: GeneratedAudio
  /// Number of chunks the text was split into.
  public var chunkCount: Int
  /// Total synthesize calls across all chunks, retries included.
  public var takes: Int
  /// Indices of the chunks whose takes all failed the plausibility check (R7).
  public var suspectChunks: [Int]

  public init(audio: GeneratedAudio, chunkCount: Int, takes: Int, suspectChunks: [Int]) {
    self.audio = audio
    self.chunkCount = chunkCount
    self.takes = takes
    self.suspectChunks = suspectChunks
  }

  /// True when any chunk is suspect.
  public var isSuspect: Bool { !suspectChunks.isEmpty }
}

// MARK: - GenerationResult

/// Result of audio generation, ready to persist as SwiftCompartido `TypedDataStorage`.
public struct GenerationResult: Sendable {
  /// Generated audio data
  public let audioData: Data

  /// Original text that was spoken
  public let originalText: String

  /// Voice ID used for generation (the catalog voice id, or the asset URL string)
  public let voiceId: String

  /// Voice name (if available)
  public let voiceName: String?

  /// Plugin ID that synthesized the audio (stored as `TypedDataStorage.providerId`)
  public let providerId: String

  /// MIME type of generated audio
  public let mimeType: String

  /// Duration in seconds (the true duration when ``format`` is set)
  public let estimatedDuration: TimeInterval

  /// Request ID for tracking
  public let requestId: UUID

  /// The format of ``audioData``, when it came from a ``GeneratedAudio``.
  public let format: AudioFormat?

  /// True when a chunk failed take validation (see ``GenerationOutcome/suspectChunks``).
  public let isSuspect: Bool

  public init(
    audioData: Data,
    originalText: String,
    voiceId: String,
    voiceName: String?,
    providerId: String,
    mimeType: String,
    estimatedDuration: TimeInterval,
    requestId: UUID = UUID(),
    format: AudioFormat? = nil,
    isSuspect: Bool = false
  ) {
    self.audioData = audioData
    self.originalText = originalText
    self.voiceId = voiceId
    self.voiceName = voiceName
    self.providerId = providerId
    self.mimeType = mimeType
    self.estimatedDuration = estimatedDuration
    self.requestId = requestId
    self.format = format
    self.isSuspect = isSuspect
  }

  /// A result for `audio`; the MIME type comes from `audio.format`.
  public init(
    audio: GeneratedAudio,
    originalText: String,
    voice: VoiceReference,
    pluginId: String,
    voiceName: String? = nil,
    isSuspect: Bool = false,
    requestId: UUID = UUID()
  ) {
    self.init(
      audioData: audio.data,
      originalText: originalText,
      voiceId: GenerationService.voiceIdentifier(of: voice),
      voiceName: voiceName,
      providerId: pluginId,
      mimeType: audio.format.mimeType,
      estimatedDuration: audio.duration,
      requestId: requestId,
      format: audio.format,
      isSuspect: isSuspect
    )
  }
}

// MARK: - GenerationService

/// Actor-based service for coordinating audio generation with safe concurrency.
///
/// Plugins are resolved through a ``PluginRegistry``; the service keeps no plugin list of its
/// own (register, enable and inspect plugins on the registry).
///
/// ## Pipeline (per request)
///
/// 1. Split the text with ``TextChunker`` to the synthesizer's `limits.maxCharacters`
///    (or ``fallbackMaxCharacters`` when the engine has no character limit).
/// 2. Synthesize each chunk through ``TakeValidator`` (retries with a new seed; a chunk that
///    never passes is recorded as suspect).
/// 3. Normalise each chunk with ``AudioNormalizer`` and join the samples.
/// 4. Return one ``GeneratedAudio`` in ``targetFormat`` (default ``AudioFormat/pcm24kMono16``).
///
/// `Task` cancellation is checked between chunks and between list items and surfaces as
/// ``HablareError/cancelled``.
///
/// ## Usage
///
/// ```swift
/// let service = GenerationService(registry: .default)
/// let result = try await service.generate(
///     text: element.elementText,
///     voice: .catalog(pluginId: "apple", voiceId: voiceId))
///
/// // Save to SwiftData (on main thread)
/// await MainActor.run {
///     let audioRecord = result.toTypedDataStorage()
///     modelContext.insert(audioRecord)
///     try? modelContext.save()
/// }
/// ```
public actor GenerationService {

  // MARK: - Properties

  /// The registry plugins are resolved through.
  public nonisolated let registry: PluginRegistry
  /// The format every generated request is returned in (`.pcm` or `.wav`, 16-bit).
  public nonisolated let targetFormat: AudioFormat
  /// The take-validation policy applied to each chunk.
  public nonisolated let takePolicy: TakePolicy
  /// Silence trim and pause cap applied to each chunk.
  public nonisolated let normalizerConfiguration: AudioNormalizer.Configuration
  /// Chunk size used when the synthesizer declares no `maxCharacters`.
  public nonisolated let fallbackMaxCharacters: Int

  private static let logger = Logger(
    subsystem: "io.intrusive-memory.SwiftHablare", category: "GenerationService")

  // MARK: - Initialization

  /// Create a generation service.
  ///
  /// - Parameters:
  ///   - registry: Where plugins are resolved (default: ``PluginRegistry/default``).
  ///   - targetFormat: Output format; `.pcm` or `.wav` (default: ``AudioFormat/pcm24kMono16``).
  ///   - takePolicy: Take validation per chunk (default: ``TakePolicy/default``).
  ///   - normalizerConfiguration: Trim and pause cap per chunk.
  ///   - fallbackMaxCharacters: Chunk size for engines with no character limit.
  public init(
    registry: PluginRegistry = .default,
    targetFormat: AudioFormat = .pcm24kMono16,
    takePolicy: TakePolicy = .default,
    normalizerConfiguration: AudioNormalizer.Configuration = .default,
    fallbackMaxCharacters: Int = TextChunker.defaultMaxCharacters
  ) {
    self.registry = registry
    self.targetFormat = targetFormat
    self.takePolicy = takePolicy
    self.normalizerConfiguration = normalizerConfiguration
    self.fallbackMaxCharacters = fallbackMaxCharacters
  }

  // MARK: - Generation

  /// Generates `request` and returns the joined audio in ``targetFormat``.
  ///
  /// - Parameters:
  ///   - request: The text, voice and settings. `request.seed` seeds every chunk's first take.
  ///   - pluginId: The synthesizing plugin; required when `request.voice` is an asset.
  ///   - progress: Per-chunk progress, with the synthesizer's own progress passed through.
  /// - Throws: ``HablareError`` (``HablareError/cancelled`` on task cancellation).
  public func generate(
    _ request: SpeechRequest,
    pluginId: String? = nil,
    progress: (@Sendable (GenerationProgress) -> Void)? = nil
  ) async throws -> GeneratedAudio {
    try await generateValidated(request, pluginId: pluginId, progress: progress).audio
  }

  /// Like ``generate(_:pluginId:progress:)``, and also reports the chunk count, the number of
  /// takes, and which chunks are suspect.
  public func generateValidated(
    _ request: SpeechRequest,
    pluginId: String? = nil,
    progress: (@Sendable (GenerationProgress) -> Void)? = nil
  ) async throws -> GenerationOutcome {
    let resolved = try await resolveSynthesizer(for: request.voice, pluginId: pluginId)
    return try await run(request, synthesizer: resolved.synthesizer, progress: progress)
  }

  /// Generates `text` and packages it as a ``GenerationResult`` for SwiftData.
  ///
  /// - Parameters:
  ///   - text: Text to convert to speech
  ///   - voice: The voice to speak with
  ///   - pluginId: The synthesizing plugin; required when `voice` is an asset
  ///   - voiceName: Voice name for metadata (optional)
  ///   - languageCode: Language code (optional, defaults to the system language)
  ///   - progress: Per-chunk progress
  public func generate(
    text: String,
    voice: VoiceReference,
    pluginId: String? = nil,
    voiceName: String? = nil,
    languageCode: String? = nil,
    progress: (@Sendable (GenerationProgress) -> Void)? = nil
  ) async throws -> GenerationResult {
    let request = SpeechRequest(
      text: text, voice: voice, languageCode: LanguageCodeResolver.resolve(languageCode))
    let resolved = try await resolveSynthesizer(for: voice, pluginId: pluginId)
    let outcome = try await run(request, synthesizer: resolved.synthesizer, progress: progress)
    return GenerationResult(
      audio: outcome.audio,
      originalText: text,
      voice: voice,
      pluginId: resolved.pluginId,
      voiceName: voiceName,
      isSuspect: outcome.isSuspect)
  }

  /// Generates audio for a `GuionElementModel`'s text. Save the result on the main thread.
  public func generate(
    forElement element: GuionElementModel,
    voice: VoiceReference,
    pluginId: String? = nil,
    voiceName: String? = nil,
    languageCode: String? = nil,
    progress: (@Sendable (GenerationProgress) -> Void)? = nil
  ) async throws -> GenerationResult {
    try await generate(
      text: element.elementText,
      voice: voice,
      pluginId: pluginId,
      voiceName: voiceName,
      languageCode: languageCode,
      progress: progress)
  }

  // MARK: - Voices

  /// True when `pluginId` resolves to an enabled synthesizer that does not report the catalog
  /// voice `voiceId` as unsupported.
  public func isVoiceAvailable(_ voiceId: String, from pluginId: String) async -> Bool {
    let voice = VoiceReference.catalog(pluginId: pluginId, voiceId: voiceId)
    guard let resolved = try? await resolveSynthesizer(for: voice, pluginId: nil) else {
      return false
    }
    if case .unsupported = await resolved.synthesizer.readiness(for: voice) { return false }
    return true
  }

  /// The catalog voices of `pluginId`, from its ``VoiceListing`` (the plugin, or its
  /// synthesizer).
  ///
  /// - Parameters:
  ///   - pluginId: Plugin identifier (e.g. "apple")
  ///   - languageCode: Language to list (optional, defaults to the system language)
  /// - Throws: ``HablareError/invalidRequest(detail:)`` when the plugin is unknown, disabled,
  ///   or cannot list voices.
  public func fetchVoices(from pluginId: String, languageCode: String? = nil) async throws
    -> [Voice]
  {
    try await requireEnabled(pluginId)
    let plugin = try await registry.plugin(id: pluginId)
    guard let listing = (plugin as? any VoiceListing) ?? (plugin.synthesizer as? any VoiceListing)
    else {
      throw HablareError.invalidRequest(detail: "plugin '\(pluginId)' does not list voices")
    }
    return try await listing.voices(languageCode: LanguageCodeResolver.resolve(languageCode))
  }

  /// Voices from every enabled registered plugin that can list them, keyed by plugin id.
  /// Plugins that cannot list, or fail to, are left out.
  public func fetchAllVoices(languageCode: String? = nil) async throws -> [String: [Voice]] {
    var voicesByPlugin: [String: [Voice]] = [:]
    for pluginId in await registry.registeredPluginIds {
      guard let voices = try? await fetchVoices(from: pluginId, languageCode: languageCode)
      else { continue }
      voicesByPlugin[pluginId] = voices
    }
    return voicesByPlugin
  }

  // MARK: - Lists

  /// Generate audio for all items in a SpeakableItemList.
  ///
  /// Items are generated sequentially through the pipeline; a `TypedDataStorage` record is
  /// created for each and saved every `saveInterval` items. `list.cancel()` stops before the
  /// next item and returns what was made; `Task` cancellation throws
  /// ``HablareError/cancelled`` after saving partial results.
  ///
  /// - Parameters:
  ///   - list: SpeakableItemList to process
  ///   - context: SwiftData ModelContext for persistence
  ///   - saveInterval: How often to save (default: after each item)
  ///   - pluginId: The synthesizing plugin for items whose voice is an asset
  ///   - progress: Item index plus that item's ``GenerationProgress``
  /// - Returns: Array of TypedDataStorage records that were created
  @MainActor
  public func generateList(
    _ list: SpeakableItemList,
    to context: ModelContext,
    saveInterval: Int = 1,
    pluginId: String? = nil,
    progress: (@Sendable (_ itemIndex: Int, _ progress: GenerationProgress) -> Void)? = nil
  ) async throws -> [TypedDataStorage] {
    list.startProcessing()

    var savedRecords: [TypedDataStorage] = []
    let interval = max(1, saveInterval)

    for index in 0..<list.totalCount {
      if list.isCancelled {
        list.completeProcessing()
        break
      }

      guard let item = list.item(at: index) else { continue }

      do {
        if Task.isCancelled { throw HablareError.cancelled }

        let request = item.speechRequest
        var itemProgress: (@Sendable (GenerationProgress) -> Void)?
        if let progress {
          itemProgress = { @Sendable report in progress(index, report) }
        }
        let outcome = try await generateItem(
          request, pluginId: pluginId, progress: itemProgress)

        let storage = GenerationResult(
          audio: outcome.outcome.audio,
          originalText: request.text,
          voice: request.voice,
          pluginId: outcome.pluginId,
          isSuspect: outcome.outcome.isSuspect
        ).toTypedDataStorage()
        context.insert(storage)

        if (index + 1) % interval == 0 || (index + 1) == list.totalCount {
          try context.save()
        }

        savedRecords.append(storage)
        list.advanceProgress(message: "Generated \(index + 1) of \(list.totalCount)")
      } catch {
        do {
          try context.save()
          Self.logger.debug("Saved \(savedRecords.count) partial results before failure")
        } catch let saveError {
          Self.logger.error(
            "Error saving partial results: \(saveError.localizedDescription, privacy: .public)")
        }
        let failure: any Error = error is CancellationError ? HablareError.cancelled : error
        list.failProcessing(with: failure)
        throw failure
      }
    }

    do {
      try context.save()
    } catch {
      Self.logger.error(
        "Error in final save of generation list: \(error.localizedDescription, privacy: .public)")
      list.failProcessing(with: error)
      throw error
    }

    list.completeProcessing()
    return savedRecords
  }

  /// One list item through the pipeline, on the actor.
  private func generateItem(
    _ request: SpeechRequest,
    pluginId: String?,
    progress: (@Sendable (GenerationProgress) -> Void)?
  ) async throws -> (pluginId: String, outcome: GenerationOutcome) {
    let resolved = try await resolveSynthesizer(for: request.voice, pluginId: pluginId)
    let outcome = try await run(request, synthesizer: resolved.synthesizer, progress: progress)
    return (resolved.pluginId, outcome)
  }

  // MARK: - Resolution

  /// The plugin id and synthesizer for `voice`, requiring the plugin to be enabled.
  private func resolveSynthesizer(
    for voice: VoiceReference, pluginId: String?
  ) async throws -> (pluginId: String, synthesizer: any VoiceSynthesizer) {
    let id: String
    switch voice {
    case .catalog(let catalogPluginId, _):
      id = pluginId ?? catalogPluginId
    case .asset:
      guard let pluginId else {
        throw HablareError.invalidRequest(
          detail: "a voice asset needs the id of the plugin that synthesizes it")
      }
      id = pluginId
    }
    try await requireEnabled(id)
    return (id, try await registry.synthesizer(for: voice, pluginId: id))
  }

  private func requireEnabled(_ pluginId: String) async throws {
    guard await registry.isRegistered(pluginId) else {
      throw HablareError.invalidRequest(detail: "no plugin registered with id '\(pluginId)'")
    }
    guard await registry.isEnabled(pluginId: pluginId) else {
      throw HablareError.invalidRequest(detail: "plugin '\(pluginId)' is disabled")
    }
  }

  /// The string stored as `voiceID`: the catalog voice id, or the asset URL.
  nonisolated static func voiceIdentifier(of voice: VoiceReference) -> String {
    switch voice {
    case .catalog(_, let voiceId): return voiceId
    case .asset(let url): return url.absoluteString
    }
  }

  // MARK: - Pipeline

  private func run(
    _ request: SpeechRequest,
    synthesizer: any VoiceSynthesizer,
    progress: (@Sendable (GenerationProgress) -> Void)?
  ) async throws -> GenerationOutcome {
    guard targetFormat.container == .pcm || targetFormat.container == .wav else {
      throw HablareError.invalidRequest(
        detail:
          "GenerationService cannot write \(targetFormat.container.rawValue); use .pcm or .wav")
    }
    let limit = synthesizer.limits.maxCharacters ?? fallbackMaxCharacters
    let chunks = TextChunker(maxCharacters: limit).chunks(request.text)
    guard !chunks.isEmpty else {
      throw HablareError.invalidRequest(detail: "text cannot be empty")
    }

    let pcmFormat = AudioFormat(
      container: .pcm, sampleRate: targetFormat.sampleRate, channels: targetFormat.channels,
      bitDepth: 16)
    let normalizer = AudioNormalizer(
      targetFormat: pcmFormat, configuration: normalizerConfiguration)
    let validator = TakeValidator(policy: takePolicy)

    var pcm = Data()
    var takes = 0
    var suspectChunks: [Int] = []
    var droppedInstruct = false
    var sourceUsed: VoiceSource?

    for (index, text) in chunks.enumerated() {
      if Task.isCancelled { throw HablareError.cancelled }

      var chunkRequest = request
      chunkRequest.text = text
      var chunkSynthesizer: any VoiceSynthesizer = synthesizer
      if let progress {
        chunkSynthesizer = ProgressForwardingSynthesizer(
          base: synthesizer, chunk: index, chunkCount: chunks.count, report: progress)
      }

      let take: ValidatedTake
      do {
        take = try await validator.synthesize(chunkRequest, using: chunkSynthesizer)
      } catch is CancellationError {
        throw HablareError.cancelled
      }

      takes += take.takes
      if take.suspect {
        suspectChunks.append(index)
        Self.logger.notice(
          "Chunk \(index + 1) of \(chunks.count) is suspect after \(take.takes) takes")
      }
      droppedInstruct = droppedInstruct || take.audio.droppedInstruct
      if sourceUsed == nil { sourceUsed = take.audio.sourceUsed }

      pcm.append(try normalizer.normalize(take.audio).data)
    }

    let bytesPerFrame = 2 * max(targetFormat.channels, 1)
    let duration = Double(pcm.count / bytesPerFrame) / Double(max(targetFormat.sampleRate, 1))
    var format = targetFormat
    format.bitDepth = 16
    let data: Data
    if targetFormat.container == .wav {
      data =
        AudioNormalizer.riffHeader(
          dataBytes: pcm.count, sampleRate: targetFormat.sampleRate,
          channels: targetFormat.channels) + pcm
    } else {
      data = pcm
    }

    return GenerationOutcome(
      audio: GeneratedAudio(
        data: data, format: format, duration: duration, droppedInstruct: droppedInstruct,
        sourceUsed: sourceUsed),
      chunkCount: chunks.count,
      takes: takes,
      suspectChunks: suspectChunks)
  }
}

// MARK: - Progress forwarding

/// Routes ``TakeValidator``'s plain `synthesize(_:)` calls through the base synthesizer's
/// progress-reporting overload, tagging each report with the chunk it belongs to.
private struct ProgressForwardingSynthesizer: VoiceSynthesizer {
  let base: any VoiceSynthesizer
  let chunk: Int
  let chunkCount: Int
  let report: @Sendable (GenerationProgress) -> Void

  var capabilities: SynthesisCapabilities { base.capabilities }
  var limits: SynthesisLimits { base.limits }
  var nativeFormats: [AudioFormat] { base.nativeFormats }
  var maxConcurrentRequests: Int { base.maxConcurrentRequests }
  var consumedSources: [VoiceSourcePattern] { base.consumedSources }

  func readiness(for voice: VoiceReference) async -> VoiceReadiness {
    await base.readiness(for: voice)
  }

  func prepare(_ voice: VoiceReference) async throws { try await base.prepare(voice) }

  func release(_ voice: VoiceReference) async { await base.release(voice) }

  func synthesize(_ request: SpeechRequest) async throws -> GeneratedAudio {
    let chunk = chunk
    let chunkCount = chunkCount
    let report = report
    return try await base.synthesize(request) { synthesis in
      report(GenerationProgress(chunk: chunk, chunkCount: chunkCount, synthesis: synthesis))
    }
  }

  func cacheKey(for request: SpeechRequest) -> String? { base.cacheKey(for: request) }

  func estimateCost(_ request: SpeechRequest) -> CostEstimate? { base.estimateCost(request) }
}

// MARK: - GenerationResult Extensions

extension GenerationResult {

  /// Convert result to TypedDataStorage for SwiftData persistence
  ///
  /// The stored MIME type comes from ``format`` when the result has one (see
  /// ``AudioFormat/mimeType``); the format's container, sample rate and channel count are
  /// recorded too, so headerless `.pcm` stays decodable.
  ///
  /// **Must be called on @MainActor**
  ///
  /// - Returns: TypedDataStorage instance ready for SwiftData
  @MainActor
  public func toTypedDataStorage() -> TypedDataStorage {
    return TypedDataStorage(
      id: requestId,
      providerId: providerId,
      requestorID: "\(providerId).audio.tts",
      mimeType: format?.mimeType ?? mimeType,
      textValue: nil,  // Audio is binary
      binaryValue: audioData,
      prompt: originalText,
      audioFormat: format?.container.rawValue,
      durationSeconds: estimatedDuration,
      sampleRate: format?.sampleRate,
      channels: format?.channels,
      voiceID: voiceId,
      voiceName: voiceName
    )
  }
}
