//
//  SpeechRequest.swift
//  SwiftHablare
//
//  Request and response value types (R4).
//

import Foundation

public struct SpeechRequest: Sendable {
  public var text: String
  public var voice: VoiceReference
  public var languageCode: String?
  /// Dropped, and reported, when the plugin does not support `.instruct`.
  public var instruct: String?
  public var settings: VoiceSettings
  public var preferredFormat: AudioFormat?
  public var seed: UInt64?

  public init(
    text: String,
    voice: VoiceReference,
    languageCode: String? = nil,
    instruct: String? = nil,
    settings: VoiceSettings = VoiceSettings(),
    preferredFormat: AudioFormat? = nil,
    seed: UInt64? = nil
  ) {
    self.text = text
    self.voice = voice
    self.languageCode = languageCode
    self.instruct = instruct
    self.settings = settings
    self.preferredFormat = preferredFormat
    self.seed = seed
  }
}

public struct GeneratedAudio: Sendable {
  public var data: Data
  /// The truth, which may differ from `SpeechRequest.preferredFormat`.
  public var format: AudioFormat
  public var duration: TimeInterval
  public var droppedInstruct: Bool
  /// Which `.vox` source conditioned this take.
  public var sourceUsed: VoiceSource?

  public init(
    data: Data,
    format: AudioFormat,
    duration: TimeInterval,
    droppedInstruct: Bool = false,
    sourceUsed: VoiceSource? = nil
  ) {
    self.data = data
    self.format = format
    self.duration = duration
    self.droppedInstruct = droppedInstruct
    self.sourceUsed = sourceUsed
  }
}

// MARK: - Placeholders

/// Minimal placeholder so `GeneratedAudio.sourceUsed` compiles. Sortie 7 replaces this
/// with the full `VoiceSource` (Kind, Freshness) in Voices/VoiceAsset.swift.
///
/// Sortie 5 added `Kind` so the plugin contract can describe which sources a synthesizer
/// consumes and a designer produces (`VoiceSourcePattern`). Sortie 7 keeps `Kind` (and
/// `Hashable`, which `VoiceReadiness` relies on) when it completes the type.
public struct VoiceSource: Sendable, Hashable {
  public enum Kind: String, Sendable, Hashable, Codable, CaseIterable {
    case serverHandle
    case embedding
    case referenceAudio
  }

  public init() {}
}

/// Minimal placeholder so `VoiceDesigner.save(_:into:)` compiles. Sortie 7 replaces this
/// with the full `VoiceAsset` wrapping `VoxFile` in Voices/VoiceAsset.swift.
public struct VoiceAsset: Sendable {
  public init() {}
}
