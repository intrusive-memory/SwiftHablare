//
//  SpeechRequest.swift
//  SwiftHablare
//
//  Request and response value types (R4).
//

import Foundation

public struct SpeechRequest: Sendable, Hashable {
  public var text: String
  public var voice: VoiceReference
  public var languageCode: String?
  /// Dropped, and reported, when the plugin does not support `.instruct`.
  public var instruct: String?
  public var settings: VoiceSettings
  public var preferredFormat: AudioFormat?
  public var seed: UInt64?
  /// Text that precedes `text` in the surrounding script, for engines that use
  /// continuity context (EL-1.7). Plugins may ignore it; it never changes the
  /// 7.0 cache key or behavior.
  public var previousText: String?
  /// Text that follows `text` in the surrounding script, for engines that use
  /// continuity context (EL-1.7). Plugins may ignore it.
  public var nextText: String?

  public init(
    text: String,
    voice: VoiceReference,
    languageCode: String? = nil,
    instruct: String? = nil,
    settings: VoiceSettings = VoiceSettings(),
    preferredFormat: AudioFormat? = nil,
    seed: UInt64? = nil,
    previousText: String? = nil,
    nextText: String? = nil
  ) {
    self.text = text
    self.voice = voice
    self.languageCode = languageCode
    self.instruct = instruct
    self.settings = settings
    self.preferredFormat = preferredFormat
    self.seed = seed
    self.previousText = previousText
    self.nextText = nextText
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
