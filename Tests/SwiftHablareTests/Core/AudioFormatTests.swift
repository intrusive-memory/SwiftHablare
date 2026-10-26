import Foundation
import Testing

@testable import SwiftHablare

@Suite("AudioFormat")
struct AudioFormatTests {
  @Test("pcm24kMono16 is 24 kHz mono 16-bit PCM")
  func pcm24kMono16Constant() {
    let f = AudioFormat.pcm24kMono16
    #expect(f.sampleRate == 24_000)
    #expect(f.channels == 1)
    #expect(f.bitDepth == 16)
    #expect(f.container == .pcm)
  }

  @Test("Formats are Hashable by value")
  func hashable() {
    let a = AudioFormat(container: .wav, sampleRate: 44_100, channels: 2, bitDepth: 16)
    let b = AudioFormat(container: .wav, sampleRate: 44_100, channels: 2, bitDepth: 16)
    #expect(a == b)
    #expect(Set([a, b]).count == 1)
    #expect(a != AudioFormat.pcm24kMono16)
  }

  @Test("Container raw values")
  func containers() {
    #expect(AudioFormat.Container.opus.rawValue == "opus")
    #expect(AudioFormat.Container.mp3.rawValue == "mp3")
  }
}
