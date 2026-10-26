import Foundation
import Testing

@testable import SwiftHablare

@Suite("AudioNormalizer")
struct AudioNormalizerTests {
  /// Segments of tone or silence, in seconds, as float samples per channel.
  enum Segment {
    case tone(Double)
    case silence(Double)
  }

  static func samples(_ segments: [Segment], rate: Int) -> [Float] {
    var out = [Float]()
    var phase = 0
    for segment in segments {
      switch segment {
      case .tone(let seconds):
        for _ in 0..<Int(seconds * Double(rate)) {
          out.append(Float(0.5 * sin(2 * Double.pi * 440 * Double(phase) / Double(rate))))
          phase += 1
        }
      case .silence(let seconds):
        out.append(contentsOf: [Float](repeating: 0, count: Int(seconds * Double(rate))))
      }
    }
    return out
  }

  static func pcm16(_ samples: [Float], channels: Int) -> Data {
    var data = Data()
    for sample in samples {
      let raw = UInt16(bitPattern: Int16((sample * 32_767).rounded()))
      for _ in 0..<channels {
        data.append(UInt8(raw & 0xFF))
        data.append(UInt8(raw >> 8))
      }
    }
    return data
  }

  static func audio(
    _ segments: [Segment], rate: Int, channels: Int, container: AudioFormat.Container = .pcm
  )
    -> GeneratedAudio
  {
    let data = pcm16(samples(segments, rate: rate), channels: channels)
    let format = AudioFormat(container: .pcm, sampleRate: rate, channels: channels, bitDepth: 16)
    return GeneratedAudio(
      data: data, format: format, duration: Double(data.count) / Double(rate * channels * 2))
  }

  @Test("44.1 kHz stereo converts to pcm24kMono16 and trims silence")
  func convertsAndTrims() throws {
    let input = Self.audio(
      [.silence(0.5), .tone(1.0), .silence(0.5)], rate: 44_100, channels: 2)
    let normalizer = AudioNormalizer(
      configuration: .init(edgePaddingSeconds: 0, maxPauseSeconds: nil))
    let out = try normalizer.normalize(input)

    #expect(out.format.sampleRate == 24_000)
    #expect(out.format.channels == 1)
    #expect(out.format.bitDepth == 16)
    #expect(out.format.container == .pcm)
    // Input is 2.0 s with 1.0 s of silence trimmed.
    #expect(abs(out.duration - 1.0) <= 0.010)
    #expect(out.data.count == Int((out.duration * 24_000).rounded()) * 2)
  }

  @Test("An internal 3.0 s silence is capped")
  func capsInternalPause() throws {
    let cap = 0.5
    let input = Self.audio(
      [.tone(0.5), .silence(3.0), .tone(0.5)], rate: 24_000, channels: 1)
    let normalizer = AudioNormalizer(
      configuration: .init(edgePaddingSeconds: 0, maxPauseSeconds: cap))
    let out = try normalizer.normalize(input)

    // 1.0 s of tone plus a pause no longer than the cap.
    #expect(out.duration <= 1.0 + cap + 0.011)
    #expect(out.duration >= 1.0)
    #expect(out.data.count == Int((out.duration * 24_000).rounded()) * 2)
  }

  @Test("Fake-plugin RIFF WAV normalises to header-less pcm24kMono16")
  func riffWavToRawPCM() throws {
    let wav = FakeWAV.make(
      samples: Self.samples([.silence(0.3), .tone(0.5), .silence(0.3)], rate: 24_000),
      rate: 24_000)
    #expect(String(decoding: wav.prefix(4), as: UTF8.self) == "RIFF")
    let input = GeneratedAudio(
      data: wav,
      format: AudioFormat(container: .wav, sampleRate: 24_000, channels: 1, bitDepth: 16),
      duration: 1.1, sourceUsed: nil)
    let out = try AudioNormalizer().normalize(input)

    #expect(out.format == .pcm24kMono16)
    #expect(String(decoding: out.data.prefix(4), as: UTF8.self) != "RIFF")
    #expect(out.duration < 1.1)
    #expect(out.duration > 0.5)
  }

  @Test("WAV output carries a RIFF header matching the data")
  func wavOutput() throws {
    let input = Self.audio([.tone(0.5)], rate: 24_000, channels: 1)
    let target = AudioFormat(container: .wav, sampleRate: 16_000, channels: 1, bitDepth: 16)
    let out = try AudioNormalizer(targetFormat: target).normalize(input)
    #expect(out.format == target)
    #expect(String(decoding: out.data.prefix(4), as: UTF8.self) == "RIFF")
    let declared = out.data.subdata(in: 40..<44).enumerated().reduce(0) {
      $0 | Int($1.element) << (8 * $1.offset)
    }
    #expect(declared == out.data.count - 44)
  }

  @Test("AIFF input decodes")
  func aiffInput() throws {
    let samples = Self.samples([.tone(0.5)], rate: 24_000)
    let aiff = FakeAIFF.make(samples: samples, rate: 24_000)
    let input = GeneratedAudio(
      data: aiff,
      format: AudioFormat(container: .aiff, sampleRate: 24_000, channels: 1, bitDepth: 16),
      duration: 0.5)
    let out = try AudioNormalizer(configuration: .init(edgePaddingSeconds: 0)).normalize(input)
    #expect(abs(out.duration - 0.5) <= 0.02)
  }

  @Test("Other fields survive and unsupported containers throw")
  func preservesFieldsAndRejects() throws {
    var input = Self.audio([.tone(0.3)], rate: 24_000, channels: 1)
    input.droppedInstruct = true
    let out = try AudioNormalizer().normalize(input)
    #expect(out.droppedInstruct)

    let mp3 = GeneratedAudio(
      data: Data([1, 2, 3]), format: AudioFormat(container: .mp3, sampleRate: 24_000, channels: 1),
      duration: 1)
    #expect(throws: HablareError.self) { try AudioNormalizer().normalize(mp3) }

    let badTarget = AudioFormat(container: .mp3, sampleRate: 24_000, channels: 1, bitDepth: 16)
    #expect(throws: HablareError.self) {
      try AudioNormalizer(targetFormat: badTarget).normalize(input)
    }
  }

  @Test("All-silent audio normalises to empty output")
  func allSilence() throws {
    let input = Self.audio([.silence(1.0)], rate: 24_000, channels: 1)
    let out = try AudioNormalizer().normalize(input)
    #expect(out.duration == 0)
    #expect(out.data.isEmpty)
  }
}

private enum FakeWAV {
  static func make(samples: [Float], rate: Int) -> Data {
    let pcm = AudioNormalizerTests.pcm16(samples, channels: 1)
    var d = Data("RIFF".utf8)
    func u32(_ v: Int) {
      for s in stride(from: 0, to: 32, by: 8) { d.append(UInt8((v >> s) & 0xFF)) }
    }
    func u16(_ v: Int) {
      d.append(UInt8(v & 0xFF))
      d.append(UInt8((v >> 8) & 0xFF))
    }
    u32(36 + pcm.count)
    d.append(Data("WAVEfmt ".utf8))
    u32(16)
    u16(1)
    u16(1)
    u32(rate)
    u32(rate * 2)
    u16(2)
    u16(16)
    d.append(Data("data".utf8))
    u32(pcm.count)
    d.append(pcm)
    return d
  }
}

private enum FakeAIFF {
  static func make(samples: [Float], rate: Int) -> Data {
    var ssnd = Data()
    for sample in samples {
      let raw = UInt16(bitPattern: Int16((sample * 32_767).rounded()))
      ssnd.append(UInt8(raw >> 8))
      ssnd.append(UInt8(raw & 0xFF))
    }
    var d = Data("FORM".utf8)
    func u32(_ v: Int) {
      for s in stride(from: 24, through: 0, by: -8) { d.append(UInt8((v >> s) & 0xFF)) }
    }
    func u16(_ v: Int) {
      d.append(UInt8((v >> 8) & 0xFF))
      d.append(UInt8(v & 0xFF))
    }
    u32(4 + 26 + 16 + ssnd.count)
    d.append(Data("AIFF".utf8))
    d.append(Data("COMM".utf8))
    u32(18)
    u16(1)
    u32(samples.count)
    u16(16)
    // 80-bit extended sample rate
    let exponent = 16383 + Int(floor(log2(Double(rate))))
    let mantissa = UInt64(Double(rate) * pow(2, Double(63 - Int(floor(log2(Double(rate)))))))
    u16(exponent)
    for s in stride(from: 56, through: 0, by: -8) {
      d.append(UInt8((mantissa >> UInt64(s)) & 0xFF))
    }
    d.append(Data("SSND".utf8))
    u32(8 + ssnd.count)
    u32(0)
    u32(0)
    d.append(ssnd)
    return d
  }
}
