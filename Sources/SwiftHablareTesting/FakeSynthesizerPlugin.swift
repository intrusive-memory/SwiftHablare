//
//  FakeSynthesizerPlugin.swift
//  SwiftHablareTesting
//
//  A local, deterministic, seedable synthesizer for tests (R13).
//

import Foundation
import SwiftHablare

/// The synthesizer role of ``FakeSynthesizerPlugin`` (and ``FakeCloudPlugin``).
///
/// Output bytes are a pure function of `request.text` and `request.seed` (nil counts as 0):
/// a 44-byte WAV header followed by 24 kHz mono 16-bit samples, reported as
/// ``AudioFormat/pcm24kMono16``. Duration is `text.count / charactersPerSecond`, so a
/// default take passes the 14 chars/s plausibility window.
public final class FakeVoiceSynthesizer: VoiceSynthesizer, @unchecked Sendable {
  public let capabilities: SynthesisCapabilities
  public let limits: SynthesisLimits
  public let nativeFormats: [AudioFormat] = [.pcm24kMono16]
  public let maxConcurrentRequests: Int
  /// `google` reference audio, then `qwen3-tts`, then any source.
  public let consumedSources: [VoiceSourcePattern] = [
    VoiceSourcePattern(engine: "google", kind: .referenceAudio),
    VoiceSourcePattern(engine: "qwen3-tts"),
    VoiceSourcePattern(),
  ]
  /// Speaking rate used to derive the duration of each take.
  public let charactersPerSecond: Double

  private let failure = FakeFailure()
  /// `nil` until ``setReadiness(_:)`` pins an answer; until then readiness is derived.
  private let readinessBox = FakeLocked<VoiceReadiness?>(nil)
  private let counts = FakeLocked<Counts>(Counts())
  private let requests = FakeLocked<[SpeechRequest]>([])
  private let preflight: (@Sendable () throws -> Void)?

  private struct Counts {
    var synthesize = 0
    var prepare = 0
    var release = 0
  }

  public init(
    capabilities: SynthesisCapabilities = [.seed, .onDevice],
    limits: SynthesisLimits = SynthesisLimits(maxCharacters: 280),
    maxConcurrentRequests: Int = 1,
    charactersPerSecond: Double = 14
  ) {
    self.capabilities = capabilities
    self.limits = limits
    self.maxConcurrentRequests = maxConcurrentRequests
    self.charactersPerSecond = charactersPerSecond
    self.preflight = nil
  }

  init(
    capabilities: SynthesisCapabilities = [.seed, .onDevice],
    limits: SynthesisLimits = SynthesisLimits(maxCharacters: 280),
    maxConcurrentRequests: Int = 1,
    charactersPerSecond: Double = 14,
    preflight: @escaping @Sendable () throws -> Void
  ) {
    self.capabilities = capabilities
    self.limits = limits
    self.maxConcurrentRequests = maxConcurrentRequests
    self.charactersPerSecond = charactersPerSecond
    self.preflight = preflight
  }

  // MARK: Knobs

  /// The next `synthesize`/`prepare` call throws `error`, then behaviour returns to normal.
  public func failNextCall(with error: HablareError) { failure.arm(error) }

  /// What ``readiness(for:)`` reports from now on, overriding the derived answer.
  public func setReadiness(_ readiness: VoiceReadiness) {
    readinessBox.withValue { $0 = readiness }
  }

  // MARK: Counters

  public var synthesizeCallCount: Int { counts.current.synthesize }
  public var prepareCallCount: Int { counts.current.prepare }
  public var releaseCallCount: Int { counts.current.release }
  /// Every request passed to `synthesize`, in call order.
  public var receivedRequests: [SpeechRequest] { requests.current }

  // MARK: VoiceSynthesizer

  /// The pinned readiness when ``setReadiness(_:)`` was called. Otherwise derived like a real
  /// `.vox` engine: for `.asset(URL)`, the source ``consumedSources`` selects from that file
  /// (``VoiceSynthesizer/sourceReadiness(for:asOf:)``); for a catalog voice, `.ready(source: nil)`.
  public func readiness(for voice: VoiceReference) async -> VoiceReadiness {
    readinessBox.current ?? sourceReadiness(for: voice)
  }

  public func prepare(_ voice: VoiceReference) async throws {
    counts.withValue { $0.prepare += 1 }
    try failure.throwIfArmed()
  }

  public func release(_ voice: VoiceReference) async {
    counts.withValue { $0.release += 1 }
  }

  /// `sourceUsed` is the source ``readiness(for:)`` names for `request.voice`.
  public func synthesize(_ request: SpeechRequest) async throws -> GeneratedAudio {
    counts.withValue { $0.synthesize += 1 }
    requests.withValue { $0.append(request) }
    try failure.throwIfArmed()
    try preflight?()
    let source = await readiness(for: request.voice).source
    let seconds = max(0.05, Double(request.text.count) / charactersPerSecond)
    return GeneratedAudio(
      data: FakeAudio.wav(text: request.text, seed: request.seed ?? 0, seconds: seconds),
      format: .pcm24kMono16,
      duration: seconds,
      droppedInstruct: request.instruct != nil && !capabilities.contains(.instruct),
      sourceUsed: source)
  }

  public func cacheKey(for request: SpeechRequest) -> String? {
    guard capabilities.contains(.seed) else { return nil }
    return "fake|\(request.text)|\(request.seed ?? 0)"
  }
}

/// A local plugin with a deterministic, seedable synthesizer.
public final class FakeSynthesizerPlugin: HablarePlugin, @unchecked Sendable {
  public static let id = "fake-synth"
  public static let displayName = "Fake Synthesizer"
  public static let kind = PluginKind.local

  private static let initializations = FakeLocked<Int>(0)

  /// How many instances have been created since the last ``resetInitCount()``. Process-wide:
  /// tests that read it should not run in parallel with other tests that build this plugin.
  public static var initCount: Int { initializations.current }
  public static func resetInitCount() { initializations.withValue { $0 = 0 } }

  public let context: PluginContext
  /// The synthesizer this plugin hands out; drive its knobs and counters directly.
  public let fakeSynthesizer: FakeVoiceSynthesizer
  private let statusBox = FakeLocked<PluginStatus>(.ready)

  public init(context: PluginContext) async throws {
    Self.initializations.withValue { $0 += 1 }
    self.context = context
    self.fakeSynthesizer = FakeVoiceSynthesizer()
  }

  public var synthesizer: (any VoiceSynthesizer)? { fakeSynthesizer }

  /// What ``status()`` reports from now on (default `.ready`).
  public func setStatus(_ status: PluginStatus) { statusBox.withValue { $0 = status } }
  public func failNextCall(with error: HablareError) { fakeSynthesizer.failNextCall(with: error) }
  public func setReadiness(_ readiness: VoiceReadiness) { fakeSynthesizer.setReadiness(readiness) }

  public func status() async -> PluginStatus { statusBox.current }
}
