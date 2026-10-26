//
//  AudioFormat.swift
//  SwiftHablare
//
//  The concrete shape of an audio payload (R4).
//

import Foundation

/// Describes the container, sample rate, channel count and bit depth of audio data.
public struct AudioFormat: Sendable, Hashable {
  public enum Container: String, Sendable, Hashable {
    case wav, aiff, mp3, pcm, opus
  }

  public var container: Container
  public var sampleRate: Int
  public var channels: Int
  public var bitDepth: Int?

  public init(container: Container, sampleRate: Int, channels: Int, bitDepth: Int? = nil) {
    self.container = container
    self.sampleRate = sampleRate
    self.channels = channels
    self.bitDepth = bitDepth
  }

  /// Produciesta pipeline format; Gemini 3.8 and Chatterbox are native 24 kHz.
  public static let pcm24kMono16 = AudioFormat(
    container: .pcm, sampleRate: 24_000, channels: 1, bitDepth: 16)
}
