//
//  FakeDesignerPlugin.swift
//  SwiftHablareTesting
//
//  A voice designer that writes a Google-shaped extension and sample into a `.vox` (R13).
//

import Foundation
import SwiftHablare

public final class FakeVoiceDesigner: VoiceDesigner, @unchecked Sendable {
  /// What `save(_:into:)` writes: a Google sample and a Google server handle.
  public let producedSources: [VoiceSourcePattern] = [
    VoiceSourcePattern(engine: "google", kind: .referenceAudio),
    VoiceSourcePattern(engine: "google", kind: .serverHandle),
  ]
  /// How many candidates `design` returns.
  public let candidateCount: Int
  /// The `expire_time` written into the Google extension.
  public let expireTime: String
  /// The preview every candidate carries: a fixed one-second WAV.
  public static let previewWAV = FakeAudio.wav(text: "preview", seed: 0, seconds: 1)

  private let failure = FakeFailure()
  private let counts = FakeLocked<Counts>(Counts())

  private struct Counts {
    var design = 0
    var save = 0
    var delete = 0
    var prompts: [String] = []
    var deleted: [VoiceReference] = []
  }

  public init(candidateCount: Int = 2, expireTime: String = "2999-01-01T00:00:00Z") {
    self.candidateCount = candidateCount
    self.expireTime = expireTime
  }

  /// The next `design`/`save`/`delete` call throws `error`, then behaviour returns to normal.
  public func failNextCall(with error: HablareError) { failure.arm(error) }

  public var designCallCount: Int { counts.current.design }
  public var saveCallCount: Int { counts.current.save }
  public var deleteCallCount: Int { counts.current.delete }
  /// Every `promptSent`, in call order (one per call; the same string sits on each candidate).
  public var promptsSent: [String] { counts.current.prompts }
  public var lastPromptSent: String? { counts.current.prompts.last }
  public var deletedVoices: [VoiceReference] { counts.current.deleted }

  public func design(_ request: VoiceDesignRequest) async throws -> [VoiceCandidate] {
    counts.withValue { $0.design += 1 }
    try failure.throwIfArmed()
    let prompt = "[fake] " + request.description
    counts.withValue { $0.prompts.append(prompt) }
    return (0..<candidateCount).map { index in
      VoiceCandidate(
        preview: GeneratedAudio(
          data: Self.previewWAV, format: .pcm24kMono16, duration: 1),
        handle: VoiceCandidate.Handle(identifier: "voice_fake_\(index)"),
        promptSent: prompt)
    }
  }

  public func save(_ candidate: VoiceCandidate, into asset: inout VoiceAsset) async throws {
    counts.withValue { $0.save += 1 }
    try failure.throwIfArmed()
    try asset.addSampleAudio(
      candidate.preview.data, engine: "google", model: "gemini-3.8-flash-tts")
    try asset.setExtension(
      [
        "voice_id": candidate.handle.identifier,
        "model_id": "gemini-3.8-flash-tts",
        "type": "prompted",
        "expire_time": expireTime,
      ], forEngine: "google")
  }

  public func delete(_ voice: VoiceReference) async throws {
    counts.withValue {
      $0.delete += 1
      $0.deleted.append(voice)
    }
    try failure.throwIfArmed()
  }
}

/// A plugin whose only role is voice design.
public final class FakeDesignerPlugin: HablarePlugin, @unchecked Sendable {
  public static let id = "fake-designer"
  public static let displayName = "Fake Designer"
  public static let kind = PluginKind.local

  public let context: PluginContext
  public let fakeDesigner: FakeVoiceDesigner
  private let statusBox = FakeLocked<PluginStatus>(.ready)

  public init(context: PluginContext) async throws {
    self.context = context
    self.fakeDesigner = FakeVoiceDesigner()
  }

  public var designer: (any VoiceDesigner)? { fakeDesigner }

  public func setStatus(_ status: PluginStatus) { statusBox.withValue { $0 = status } }
  public func failNextCall(with error: HablareError) { fakeDesigner.failNextCall(with: error) }

  public func status() async -> PluginStatus { statusBox.current }
}
