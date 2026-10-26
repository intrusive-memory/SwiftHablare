//
//  ConformanceKit.swift
//  SwiftHablareTesting
//
//  The conformance suite every plugin runs against itself (R13). It depends on no test
//  framework: `ConformanceKit.run` returns a `ConformanceReport`, and the caller's own test
//  asserts on it (`#expect(report.failures.isEmpty, "\(report.summary)")`).
//

import Foundation
import SwiftHablare

/// One conformance check.
public enum ConformanceCheck: String, Sendable, Hashable, CaseIterable {
  /// The plugin builds from its context and declares an id, a name and at least one role.
  case initialization
  /// readiness, then prepare when needed, then synthesize, then release.
  case roundTrip
  /// `GeneratedAudio.format` agrees with the bytes: `.wav` bytes carry a matching RIFF header,
  /// `.pcm` bytes carry none.
  case formatTruthfulness
  /// Same request, same key; `nil` exactly when `.seed` is absent from the capabilities.
  case cacheKeyStability
  /// A task cancelled after the first chunk of a multi-chunk synthesis throws
  /// `HablareError.cancelled` on the next chunk.
  case cancellation
  /// Every error thrown by a bad request is a `HablareError` (so it has a category).
  case errorCategories
  /// A planted key never appears in `status()` or in `keySource`.
  case secrecyStatus
  /// A planted key never appears in any thrown error's description.
  case secrecyErrors

  /// True when the check calls `prepare`/`synthesize`/`release` and so needs the engine's
  /// real resources (a voice, a model, audio services). Skipped in ``ConformanceMode/hardwareFree``.
  public var needsHardware: Bool {
    switch self {
    case .initialization, .cacheKeyStability, .secrecyStatus: return false
    case .roundTrip, .formatTruthfulness, .cancellation, .errorCategories, .secrecyErrors:
      return true
    }
  }
}

public enum ConformanceMode: Sendable, Hashable {
  /// Every check. Run locally.
  case full
  /// Only the checks that never synthesize; the rest are reported as skipped. Run in CI.
  case hardwareFree
}

public struct ConformanceResult: Sendable, Hashable {
  public enum Outcome: Sendable, Hashable {
    case passed
    case failed
    /// Not applicable (no such role, no credentials) or excluded by the mode.
    case skipped
  }

  public let check: ConformanceCheck
  public let outcome: Outcome
  /// Why it failed or was skipped; a short note when it passed. Never contains a secret.
  public let message: String

  public init(check: ConformanceCheck, outcome: Outcome, message: String) {
    self.check = check
    self.outcome = outcome
    self.message = message
  }
}

public struct ConformanceReport: Sendable {
  public let pluginId: String
  public let mode: ConformanceMode
  public let results: [ConformanceResult]

  public var failures: [ConformanceResult] { results.filter { $0.outcome == .failed } }
  public var skipped: [ConformanceResult] { results.filter { $0.outcome == .skipped } }
  public var passedChecks: [ConformanceResult] { results.filter { $0.outcome == .passed } }
  /// True when no check failed (skips do not fail a report).
  public var passed: Bool { failures.isEmpty }

  public func result(for check: ConformanceCheck) -> ConformanceResult? {
    results.first { $0.check == check }
  }

  /// One line per result, for an assertion message.
  public var summary: String {
    let lines = results.map { "[\($0.outcome)] \($0.check.rawValue): \($0.message)" }
    return "Conformance of '\(pluginId)' (\(mode)):\n" + lines.joined(separator: "\n")
  }
}

public enum ConformanceKit {
  /// Runs the kit against `pluginType`.
  ///
  /// - Parameters:
  ///   - context: Builds the plugin. For a cloud plugin its key store should hold a planted,
  ///     distinctive key under each credential's `keychainAccount`; the kit scans for it.
  ///   - voice: A voice the plugin can synthesize with.
  ///   - mode: ``ConformanceMode/full`` or ``ConformanceMode/hardwareFree``.
  ///   - secrets: Extra secret values to scan for, beyond the keys found in `context.keys`.
  public static func run<P: HablarePlugin>(
    _ pluginType: P.Type,
    context: PluginContext,
    voice: VoiceReference,
    mode: ConformanceMode = .full,
    secrets: [String] = []
  ) async -> ConformanceReport {
    var runner = Runner(
      pluginId: P.id, mode: mode, context: context, voice: voice, extraSecrets: secrets)
    await runner.execute(pluginType)
    return ConformanceReport(pluginId: P.id, mode: mode, results: runner.results)
  }
}

// MARK: - Runner

private struct Runner {
  let pluginId: String
  let mode: ConformanceMode
  let context: PluginContext
  let voice: VoiceReference
  let extraSecrets: [String]
  var results: [ConformanceResult] = []
  var knownSecrets: [String] = []

  init(
    pluginId: String, mode: ConformanceMode, context: PluginContext, voice: VoiceReference,
    extraSecrets: [String]
  ) {
    self.pluginId = pluginId
    self.mode = mode
    self.context = context
    self.voice = voice
    self.extraSecrets = extraSecrets
  }

  mutating func record(_ check: ConformanceCheck, _ outcome: ConformanceResult.Outcome, _ m: String)
  {
    results.append(ConformanceResult(check: check, outcome: outcome, message: m))
  }

  mutating func pass(_ check: ConformanceCheck, _ message: String = "ok") {
    record(check, .passed, message)
  }
  mutating func fail(_ check: ConformanceCheck, _ message: String) {
    record(check, .failed, message)
  }
  mutating func skip(_ check: ConformanceCheck, _ message: String) {
    record(check, .skipped, message)
  }

  mutating func execute<P: HablarePlugin>(_ type: P.Type) async {
    let secrets = collectSecrets(P.credentials)
    knownSecrets = secrets
    let plugin: P
    do {
      plugin = try await P(context: context)
    } catch {
      fail(.initialization, "init(context:) threw: \(safe(error))")
      for check in ConformanceCheck.allCases where check != .initialization {
        skip(check, "plugin did not initialise")
      }
      return
    }
    if P.id.isEmpty || P.displayName.isEmpty {
      fail(.initialization, "id and displayName must be non-empty")
    } else if plugin.synthesizer == nil && plugin.designer == nil {
      fail(.initialization, "provides no role (neither synthesizer nor designer)")
    } else {
      pass(.initialization)
    }

    for check in ConformanceCheck.allCases where check != .initialization {
      if mode == .hardwareFree && check.needsHardware {
        skip(check, "hardware-dependent; excluded in hardware-free mode")
        continue
      }
      switch check {
      case .initialization: break
      case .roundTrip: await roundTrip(plugin)
      case .formatTruthfulness: await formatTruthfulness(plugin)
      case .cacheKeyStability: cacheKeyStability(plugin)
      case .cancellation: await cancellation(plugin)
      case .errorCategories: await errorCategories(plugin)
      case .secrecyStatus: await secrecyStatus(plugin, secrets: secrets, type: type)
      case .secrecyErrors: await secrecyErrors(plugin, secrets: secrets)
      }
    }
  }

  // MARK: Requests

  private func request(
    _ text: String = "The quick brown fox jumps over the lazy dog.", seed: UInt64? = 42
  ) -> SpeechRequest {
    SpeechRequest(text: text, voice: voice, seed: seed)
  }

  /// Makes the voice ready (prepare when asked). Returns a failure message, or nil.
  private func makeReady(_ synth: any VoiceSynthesizer) async -> String? {
    switch await synth.readiness(for: voice) {
    case .ready: return nil
    case .unsupported(let reason): return "readiness is unsupported for the sample voice: \(reason)"
    case .needsPreparation:
      do {
        try await synth.prepare(voice)
      } catch {
        return "prepare threw: \(safe(error))"
      }
      if case .ready = await synth.readiness(for: voice) { return nil }
      return "readiness is not .ready after prepare"
    }
  }

  // MARK: Checks

  private mutating func roundTrip(_ plugin: some HablarePlugin) async {
    guard let synth = plugin.synthesizer else {
      return skip(.roundTrip, "no synthesizer role")
    }
    if let problem = await makeReady(synth) { return fail(.roundTrip, problem) }
    do {
      let audio = try await synth.synthesize(request())
      await synth.release(voice)
      if audio.data.isEmpty { return fail(.roundTrip, "synthesize returned no bytes") }
      if !(audio.duration > 0) { return fail(.roundTrip, "duration is not positive") }
      pass(.roundTrip, "\(audio.data.count) bytes, \(audio.duration) s")
    } catch {
      await synth.release(voice)
      fail(.roundTrip, "synthesize threw: \(safe(error))")
    }
  }

  private mutating func formatTruthfulness(_ plugin: some HablarePlugin) async {
    guard let synth = plugin.synthesizer else {
      return skip(.formatTruthfulness, "no synthesizer role")
    }
    if let problem = await makeReady(synth) { return fail(.formatTruthfulness, problem) }
    do {
      let audio = try await synth.synthesize(request())
      await synth.release(voice)
      switch Self.verify(audio.format, against: audio.data) {
      case nil: pass(.formatTruthfulness, "\(audio.format.container.rawValue) bytes match")
      case .some(let problem): fail(.formatTruthfulness, problem)
      }
    } catch {
      await synth.release(voice)
      fail(.formatTruthfulness, "synthesize threw: \(safe(error))")
    }
  }

  /// `.wav` must carry a RIFF/WAVE header whose rate, channels and bit depth match the label;
  /// `.pcm` must carry none. Other containers are not inspected. Returns a problem or `nil`.
  static func verify(_ format: AudioFormat, against data: Data) -> String? {
    let hasRIFF = data.count >= 12 && data.prefix(4) == Data("RIFF".utf8)
    switch format.container {
    case .pcm:
      return hasRIFF
        ? "labelled .pcm but the bytes start with a RIFF header (label it .wav, or strip it)"
        : nil
    case .wav:
      guard hasRIFF, data.subdata(in: 8..<12) == Data("WAVE".utf8) else {
        return "labelled .wav but the bytes carry no RIFF/WAVE header"
      }
      guard let fmt = wavFormat(data) else { return "WAV header has no readable 'fmt ' chunk" }
      if fmt.sampleRate != format.sampleRate {
        return "label says \(format.sampleRate) Hz but the WAV header says \(fmt.sampleRate) Hz"
      }
      if fmt.channels != format.channels {
        return "label says \(format.channels) channel(s) but the WAV header says \(fmt.channels)"
      }
      if let depth = format.bitDepth, depth != fmt.bits {
        return "label says \(depth)-bit but the WAV header says \(fmt.bits)-bit"
      }
      return nil
    default:
      return nil
    }
  }

  private static func wavFormat(_ data: Data) -> (sampleRate: Int, channels: Int, bits: Int)? {
    let bytes = [UInt8](data)
    func u16(_ at: Int) -> Int { Int(bytes[at]) | Int(bytes[at + 1]) << 8 }
    func u32(_ at: Int) -> Int { u16(at) | u16(at + 2) << 16 }
    var offset = 12
    while offset + 8 <= bytes.count {
      let size = u32(offset + 4)
      if bytes[offset..<offset + 4].elementsEqual("fmt ".utf8) {
        guard size >= 16, offset + 8 + 16 <= bytes.count else { return nil }
        let body = offset + 8
        return (u32(body + 4), u16(body + 2), u16(body + 14))
      }
      offset += 8 + size + (size & 1)
    }
    return nil
  }

  private mutating func cacheKeyStability(_ plugin: some HablarePlugin) {
    guard let synth = plugin.synthesizer else {
      return skip(.cacheKeyStability, "no synthesizer role")
    }
    let seedCapable = synth.capabilities.contains(.seed)
    let a = synth.cacheKey(for: request())
    let b = synth.cacheKey(for: request())
    let unseeded = synth.cacheKey(for: request(seed: nil))
    if !seedCapable {
      if a != nil || b != nil || unseeded != nil {
        return fail(.cacheKeyStability, "lacks .seed but returned a cache key (must be nil)")
      }
      return pass(.cacheKeyStability, "no .seed capability; keys are nil")
    }
    if a == nil || b == nil {
      return fail(.cacheKeyStability, "has .seed but returned a nil cache key")
    }
    if a != b { return fail(.cacheKeyStability, "same request produced two different keys") }
    if a == synth.cacheKey(for: request("A different line of text.")) {
      return fail(.cacheKeyStability, "different text produced the same key")
    }
    if a == synth.cacheKey(for: request(seed: 43)) {
      return fail(.cacheKeyStability, "different seed produced the same key")
    }
    pass(.cacheKeyStability, "stable and sensitive to text and seed")
  }

  private mutating func cancellation(_ plugin: some HablarePlugin) async {
    guard let synth = plugin.synthesizer else {
      return skip(.cancellation, "no synthesizer role")
    }
    if let problem = await makeReady(synth) { return fail(.cancellation, problem) }
    let limit = synth.limits.maxCharacters ?? TextChunker.defaultMaxCharacters
    let sentence = "The quick brown fox jumps over the lazy dog. "
    var text = ""
    while text.count < limit * 3 { text += sentence }
    let chunks = TextChunker(maxCharacters: limit).chunks(text)
    guard chunks.count >= 3 else {
      return fail(.cancellation, "could not build a multi-chunk text (\(chunks.count) chunk)")
    }
    let voice = self.voice
    let task = Task { () -> String in
      var done = 0
      do {
        for chunk in chunks {
          _ = try await synth.synthesize(SpeechRequest(text: chunk, voice: voice, seed: 1))
          done += 1
          if done == 1 { withUnsafeCurrentTask { $0?.cancel() } }
        }
        return "all \(chunks.count) chunks completed after cancellation"
      } catch HablareError.cancelled {
        return "cancelled"
      } catch {
        return "threw \(type(of: error)) instead of HablareError.cancelled"
      }
    }
    let outcome = await task.value
    await synth.release(voice)
    if outcome == "cancelled" {
      pass(.cancellation, "HablareError.cancelled thrown between chunks")
    } else {
      fail(.cancellation, outcome)
    }
  }

  /// Requests that a well-behaved plugin rejects (or tolerates). Whatever is thrown is returned.
  private func probeErrors(_ synth: any VoiceSynthesizer) async -> [any Error] {
    var probes: [SpeechRequest] = [
      request(""),
      SpeechRequest(
        text: "Hello.", voice: .catalog(pluginId: "no-such-plugin", voiceId: "no-such-voice")),
    ]
    if let limit = synth.limits.maxCharacters {
      probes.append(request(String(repeating: "word ", count: limit)))
    }
    var thrown: [any Error] = []
    for probe in probes {
      do { _ = try await synth.synthesize(probe) } catch { thrown.append(error) }
    }
    return thrown
  }

  private mutating func errorCategories(_ plugin: some HablarePlugin) async {
    guard let synth = plugin.synthesizer else {
      return skip(.errorCategories, "no synthesizer role")
    }
    let thrown = await probeErrors(synth)
    for error in thrown where !(error is HablareError) {
      return fail(
        .errorCategories, "threw \(type(of: error)), which has no ErrorCategory; use HablareError")
    }
    pass(.errorCategories, "\(thrown.count) probe error(s), all categorised")
  }

  private mutating func secrecyStatus<P: HablarePlugin>(
    _ plugin: P, secrets: [String], type: P.Type
  ) async {
    if !P.credentials.isEmpty && secrets.isEmpty {
      return fail(
        .secrecyStatus, "declares credentials but no key was planted in context.keys to scan for")
    }
    if secrets.isEmpty { return skip(.secrecyStatus, "no credentials; nothing to plant") }
    let status = await plugin.status()
    var surfaces = [
      ("status()", "\(status)"), ("status() reflection", String(reflecting: status)),
    ]
    for requirement in P.credentials {
      if let source = context.keys.keySource(for: requirement.keychainAccount) {
        surfaces.append(("keySource", source))
      }
    }
    for (name, text) in surfaces {
      if secrets.contains(where: { text.contains($0) }) {
        return fail(.secrecyStatus, "a planted key appears in \(name)")
      }
    }
    pass(.secrecyStatus, "no planted key in status() or keySource")
  }

  private mutating func secrecyErrors(_ plugin: some HablarePlugin, secrets: [String]) async {
    guard let synth = plugin.synthesizer else {
      return skip(.secrecyErrors, "no synthesizer role")
    }
    if secrets.isEmpty { return skip(.secrecyErrors, "no credentials; nothing to plant") }
    for error in await probeErrors(synth) {
      let texts = [
        "\(error)", String(describing: error), String(reflecting: error),
        error.localizedDescription,
      ]
      if texts.contains(where: { text in secrets.contains { text.contains($0) } }) {
        return fail(.secrecyErrors, "a planted key appears in a thrown \(type(of: error))")
      }
    }
    pass(.secrecyErrors, "no planted key in any thrown error")
  }

  // MARK: Helpers

  private func collectSecrets(_ credentials: [CredentialRequirement]) -> [String] {
    var found = extraSecrets
    for requirement in credentials {
      if let key = context.keys.apiKey(for: requirement.keychainAccount) { found.append(key) }
    }
    return found.filter { !$0.isEmpty }
  }

  /// Describes an error for a report without ever echoing a planted key.
  private func safe(_ error: any Error) -> String {
    var text = "\(error)"
    for secret in knownSecrets where text.contains(secret) {
      text = text.replacingOccurrences(of: secret, with: "<redacted>")
    }
    return text
  }
}
