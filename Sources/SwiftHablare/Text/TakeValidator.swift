//
//  TakeValidator.swift
//  SwiftHablare
//
//  Take validation (R7): synthesize, check the audio duration against a plausibility window for
//  the text, and retry with a new seed. Defaults come from the prototype (render.py
//  `_plausible`: 0.3x to 2.2x of 14 chars/s, plus 1.5 s; 2 retries = 3 takes).
//

import Foundation

/// The plausibility policy. A take of `text` lasting `seconds` is plausible when
/// `lowerFactor * expected <= seconds <= upperFactor * expected + slack`, where
/// `expected = max(text.count / charactersPerSecond, minimumExpected)`.
public struct TakePolicy: Sendable, Hashable {
  public var charactersPerSecond: Double
  public var lowerFactor: Double
  public var upperFactor: Double
  /// Seconds added to the upper bound.
  public var slack: TimeInterval
  /// Floor for the expected duration, so very short texts have a sane window.
  public var minimumExpected: TimeInterval
  /// Retries after the first take; `maxRetries + 1` takes in total.
  public var maxRetries: Int
  /// Added to the seed per retry (the prototype uses 1000).
  public var seedStride: UInt64

  public init(
    charactersPerSecond: Double = 14,
    lowerFactor: Double = 0.3,
    upperFactor: Double = 2.2,
    slack: TimeInterval = 1.5,
    minimumExpected: TimeInterval = 0.4,
    maxRetries: Int = 2,
    seedStride: UInt64 = 1000
  ) {
    self.charactersPerSecond = charactersPerSecond
    self.lowerFactor = lowerFactor
    self.upperFactor = upperFactor
    self.slack = slack
    self.minimumExpected = minimumExpected
    self.maxRetries = max(0, maxRetries)
    self.seedStride = seedStride
  }

  public static let `default` = TakePolicy()

  public func isPlausible(text: String, duration: TimeInterval) -> Bool {
    let expected = max(Double(text.count) / charactersPerSecond, minimumExpected)
    return lowerFactor * expected <= duration && duration <= upperFactor * expected + slack
  }

  /// The seed for take `attempt` (0-based). Attempt 0 keeps the request's seed unchanged;
  /// later attempts derive `base + seedStride * attempt` (`base` is 0 when the request has none).
  public func seed(forAttempt attempt: Int, base: UInt64?) -> UInt64? {
    attempt == 0 ? base : (base ?? 0) &+ seedStride &* UInt64(attempt)
  }
}

/// A validated take. `suspect` is true when no take within the policy was plausible; `audio` is
/// then the last take.
public struct ValidatedTake: Sendable {
  public var audio: GeneratedAudio
  /// Number of synthesize calls made (1...maxRetries+1).
  public var takes: Int
  public var suspect: Bool
  /// The `SpeechRequest.seed` of the returned take.
  public var seed: UInt64?

  public init(audio: GeneratedAudio, takes: Int, suspect: Bool, seed: UInt64?) {
    self.audio = audio
    self.takes = takes
    self.suspect = suspect
    self.seed = seed
  }
}

public struct TakeValidator: Sendable {
  public var policy: TakePolicy

  public init(policy: TakePolicy = .default) { self.policy = policy }

  /// Synthesizes `request`, retrying with a new `SpeechRequest.seed` per take until a take is
  /// plausible or `policy.maxRetries` retries are spent. Errors thrown by the synthesizer
  /// propagate immediately.
  public func synthesize(
    _ request: SpeechRequest, using synthesizer: any VoiceSynthesizer
  ) async throws -> ValidatedTake {
    var last: ValidatedTake?
    for attempt in 0...policy.maxRetries {
      var take = request
      take.seed = policy.seed(forAttempt: attempt, base: request.seed)
      let audio = try await synthesizer.synthesize(take)
      let plausible = policy.isPlausible(text: request.text, duration: audio.duration)
      let result = ValidatedTake(
        audio: audio, takes: attempt + 1, suspect: !plausible, seed: take.seed)
      if plausible { return result }
      last = result
    }
    return last!  // the loop runs at least once and always assigns
  }
}
