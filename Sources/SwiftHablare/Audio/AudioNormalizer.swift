//
//  AudioNormalizer.swift
//  SwiftHablare
//
//  Converts any `GeneratedAudio` to one target `AudioFormat`, trims leading and
//  trailing silence and caps internal pauses (R4). The trim and pause-cap algorithms
//  are ported from the gemini-chatterbox-hybrid prototype (`render.py` `_trim`,
//  `_cap_pauses`): RMS over 10 ms hops against a threshold relative to the loudest hop.
//

import AVFoundation
import Foundation

/// Normalises synthesized audio to a single output format with consistent silence.
///
/// Accepted inputs: `.wav` (RIFF), `.aiff`/AIFC, and raw `.pcm` (interpreted with the
/// format's sample rate, channel count and bit depth: 8-bit unsigned or 16/24/32-bit
/// little-endian signed). `.mp3` and `.opus` inputs throw `HablareError.invalidRequest`.
///
/// Accepted outputs: `.pcm` (raw little-endian 16-bit, no header) and `.wav`
/// (RIFF header matching the data). Other containers or bit depths throw.
public struct AudioNormalizer: Sendable {
  /// Tunable parameters. Defaults are taken from the prototype.
  public struct Configuration: Sendable, Hashable {
    /// Analysis window in seconds (prototype: 10 ms).
    public var hopSeconds: Double
    /// A hop is silent at or below `max(peakRMS * ratio, floor)` when trimming (prototype: 0.02).
    public var trimThresholdRatio: Double
    /// A hop is quiet at or below `max(peakRMS * ratio, floor)` when capping pauses (prototype: 0.05).
    public var pauseThresholdRatio: Double
    /// Absolute RMS floor on a -1...1 scale (prototype: 1e-4).
    public var silenceFloor: Double
    /// Audio kept before the first and after the last voiced hop (prototype: 0.04 s).
    public var edgePaddingSeconds: Double
    /// Longest internal silence kept. `nil` or a value `<= 0` disables capping.
    public var maxPauseSeconds: Double?
    /// Whether leading and trailing silence is removed.
    public var trimsEdges: Bool

    public init(
      hopSeconds: Double = 0.01,
      trimThresholdRatio: Double = 0.02,
      pauseThresholdRatio: Double = 0.05,
      silenceFloor: Double = 1e-4,
      edgePaddingSeconds: Double = 0.04,
      maxPauseSeconds: Double? = 0.6,
      trimsEdges: Bool = true
    ) {
      self.hopSeconds = hopSeconds
      self.trimThresholdRatio = trimThresholdRatio
      self.pauseThresholdRatio = pauseThresholdRatio
      self.silenceFloor = silenceFloor
      self.edgePaddingSeconds = edgePaddingSeconds
      self.maxPauseSeconds = maxPauseSeconds
      self.trimsEdges = trimsEdges
    }

    public static let `default` = Configuration()
  }

  public var targetFormat: AudioFormat
  public var configuration: Configuration

  public init(
    targetFormat: AudioFormat = .pcm24kMono16,
    configuration: Configuration = .default
  ) {
    self.targetFormat = targetFormat
    self.configuration = configuration
  }

  /// Returns audio in `targetFormat` with silence normalised. `format` and `duration`
  /// describe the output; every other field is carried over.
  public func normalize(_ audio: GeneratedAudio) throws -> GeneratedAudio {
    try validateTarget()
    let source = try Self.decode(audio)
    var channels = try convert(source)

    let rate = Double(targetFormat.sampleRate)
    let hop = max(Int(configuration.hopSeconds * rate), 1)
    if configuration.trimsEdges {
      channels = Self.trim(
        channels, hop: hop, ratio: configuration.trimThresholdRatio,
        floor: configuration.silenceFloor,
        pad: Int(configuration.edgePaddingSeconds * rate))
    }
    if let cap = configuration.maxPauseSeconds, cap > 0 {
      channels = Self.capPauses(
        channels, hop: hop, ratio: configuration.pauseThresholdRatio,
        floor: configuration.silenceFloor,
        limit: Int((cap / configuration.hopSeconds).rounded(.down)))
    }

    let frames = channels.first?.count ?? 0
    let pcm = Self.encodeInt16(channels)
    let data: Data
    switch targetFormat.container {
    case .wav:
      data =
        Self.riffHeader(
          dataBytes: pcm.count, sampleRate: targetFormat.sampleRate,
          channels: targetFormat.channels) + pcm
    default:
      data = pcm
    }

    var result = audio
    result.data = data
    result.format = targetFormat
    result.format.bitDepth = 16
    result.duration = Double(frames) / rate
    return result
  }

  // MARK: - Validation

  private func validateTarget() throws {
    guard targetFormat.container == .pcm || targetFormat.container == .wav else {
      throw HablareError.invalidRequest(
        detail: "AudioNormalizer cannot write \(targetFormat.container.rawValue); use .pcm or .wav")
    }
    guard (targetFormat.bitDepth ?? 16) == 16 else {
      throw HablareError.invalidRequest(detail: "AudioNormalizer writes 16-bit output only")
    }
    guard targetFormat.sampleRate > 0, targetFormat.channels > 0 else {
      throw HablareError.invalidRequest(
        detail: "Target format needs a positive rate and channel count")
    }
  }

  // MARK: - Decode

  private static func decode(_ audio: GeneratedAudio) throws -> AVAudioPCMBuffer {
    switch audio.format.container {
    case .pcm:
      return try decodeRaw(audio.data, format: audio.format)
    case .wav, .aiff:
      return try decodeContainer(audio.data, container: audio.format.container)
    case .mp3, .opus:
      throw HablareError.invalidRequest(
        detail: "AudioNormalizer does not decode \(audio.format.container.rawValue) input")
    }
  }

  private static func decodeContainer(
    _ data: Data, container: AudioFormat.Container
  ) throws -> AVAudioPCMBuffer {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("hablare-normalize-\(UUID().uuidString).\(container.rawValue)")
    defer { try? FileManager.default.removeItem(at: url) }
    do {
      try data.write(to: url)
      let file = try AVAudioFile(forReading: url)
      guard file.length > 0 else {
        return try makeBuffer(
          sampleRate: file.processingFormat.sampleRate,
          channels: Int(file.processingFormat.channelCount), frames: 0)
      }
      guard
        let buffer = AVAudioPCMBuffer(
          pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length))
      else {
        throw HablareError.invalidRequest(detail: "Could not allocate decode buffer")
      }
      try file.read(into: buffer)
      return buffer
    } catch let error as HablareError {
      throw error
    } catch {
      throw HablareError.invalidRequest(
        detail: "Could not decode \(container.rawValue) audio: \(error.localizedDescription)")
    }
  }

  private static func decodeRaw(_ data: Data, format: AudioFormat) throws -> AVAudioPCMBuffer {
    let depth = format.bitDepth ?? 16
    guard [8, 16, 24, 32].contains(depth), format.channels > 0, format.sampleRate > 0 else {
      throw HablareError.invalidRequest(
        detail:
          "Unsupported raw PCM layout: \(format.sampleRate) Hz, \(format.channels) ch, \(depth)-bit"
      )
    }
    let bytesPerSample = depth / 8
    let frames = data.count / (bytesPerSample * format.channels)
    let buffer = try makeBuffer(
      sampleRate: Double(format.sampleRate), channels: format.channels, frames: frames)
    guard frames > 0, let out = buffer.floatChannelData else { return buffer }
    let bytes = [UInt8](data)
    for frame in 0..<frames {
      for channel in 0..<format.channels {
        let at = (frame * format.channels + channel) * bytesPerSample
        let value: Float
        switch depth {
        case 8:
          value = (Float(bytes[at]) - 128) / 128
        case 16:
          let raw = Int16(bitPattern: UInt16(bytes[at]) | UInt16(bytes[at + 1]) << 8)
          value = Float(raw) / 32_768
        case 24:
          var raw = Int32(bytes[at]) | Int32(bytes[at + 1]) << 8 | Int32(bytes[at + 2]) << 16
          if raw & 0x80_0000 != 0 { raw -= 0x100_0000 }
          value = Float(raw) / 8_388_608
        default:
          let raw = Int32(
            bitPattern: UInt32(bytes[at]) | UInt32(bytes[at + 1]) << 8
              | UInt32(bytes[at + 2]) << 16 | UInt32(bytes[at + 3]) << 24)
          value = Float(raw) / 2_147_483_648
        }
        out[channel][frame] = value
      }
    }
    return buffer
  }

  private static func makeBuffer(sampleRate: Double, channels: Int, frames: Int) throws
    -> AVAudioPCMBuffer
  {
    guard
      let format = AVAudioFormat(
        commonFormat: .pcmFormatFloat32, sampleRate: sampleRate,
        channels: AVAudioChannelCount(channels), interleaved: false),
      let buffer = AVAudioPCMBuffer(
        pcmFormat: format, frameCapacity: AVAudioFrameCount(max(frames, 1)))
    else {
      throw HablareError.invalidRequest(detail: "Could not create a PCM buffer")
    }
    buffer.frameLength = AVAudioFrameCount(frames)
    return buffer
  }

  // MARK: - Convert

  /// Resamples and remixes to the target rate and channel count as float channels.
  private func convert(_ input: AVAudioPCMBuffer) throws -> [[Float]] {
    let outChannels = targetFormat.channels
    guard
      let outFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32, sampleRate: Double(targetFormat.sampleRate),
        channels: AVAudioChannelCount(outChannels), interleaved: false)
    else {
      throw HablareError.invalidRequest(detail: "Unsupported target format")
    }
    guard input.frameLength > 0 else { return Array(repeating: [], count: outChannels) }
    guard let converter = AVAudioConverter(from: input.format, to: outFormat) else {
      throw HablareError.invalidRequest(detail: "No conversion available to the target format")
    }

    let ratio = outFormat.sampleRate / input.format.sampleRate
    let capacity = AVAudioFrameCount(Double(input.frameLength) * ratio) + 4_096
    guard let output = AVAudioPCMBuffer(pcmFormat: outFormat, frameCapacity: capacity) else {
      throw HablareError.invalidRequest(detail: "Could not allocate conversion buffer")
    }

    var supplied = false
    var conversionError: NSError?
    let status = converter.convert(to: output, error: &conversionError) { _, inputStatus in
      if supplied {
        inputStatus.pointee = .endOfStream
        return nil
      }
      supplied = true
      inputStatus.pointee = .haveData
      return input
    }
    if status == .error {
      throw HablareError.invalidRequest(
        detail: "Audio conversion failed: \(conversionError?.localizedDescription ?? "unknown")")
    }

    let frames = Int(output.frameLength)
    guard let data = output.floatChannelData else {
      return Array(repeating: [], count: outChannels)
    }
    return (0..<outChannels).map { Array(UnsafeBufferPointer(start: data[$0], count: frames)) }
  }

  // MARK: - Silence handling

  /// RMS per hop across all channels.
  private static func hopRMS(_ channels: [[Float]], hop: Int) -> [Double] {
    let frames = channels.first?.count ?? 0
    let count = frames / hop
    guard count > 0 else { return [] }
    return (0..<count).map { index in
      var sum = 0.0
      for channel in channels {
        for i in (index * hop)..<((index + 1) * hop) {
          sum += Double(channel[i]) * Double(channel[i])
        }
      }
      return (sum / Double(hop * channels.count)).squareRoot()
    }
  }

  static func trim(_ channels: [[Float]], hop: Int, ratio: Double, floor: Double, pad: Int)
    -> [[Float]]
  {
    let rms = hopRMS(channels, hop: hop)
    guard let peak = rms.max() else { return channels }
    let threshold = max(peak * ratio, floor)
    guard let first = rms.firstIndex(where: { $0 > threshold }),
      let last = rms.lastIndex(where: { $0 > threshold })
    else { return channels.map { _ in [] } }
    let frames = channels[0].count
    let start = max(first * hop - pad, 0)
    let end = min((last + 1) * hop + pad, frames)
    return channels.map { Array($0[start..<end]) }
  }

  /// Shortens every internal silence longer than `limit` hops to `limit` hops, dropping
  /// the middle so both word edges keep their natural tails.
  static func capPauses(_ channels: [[Float]], hop: Int, ratio: Double, floor: Double, limit: Int)
    -> [[Float]]
  {
    let rms = hopRMS(channels, hop: hop)
    guard let peak = rms.max() else { return channels }
    let threshold = max(peak * ratio, floor)
    let frames = channels[0].count
    var keep = [Bool](repeating: true, count: frames)
    var i = 0
    while i < rms.count {
      if rms[i] <= threshold {
        var j = i
        while j < rms.count && rms[j] <= threshold { j += 1 }
        let run = j - i
        if run > limit {
          let mid = (i + j) / 2
          let excess = run - limit
          let from = (mid - excess / 2) * hop
          let to = (mid + (excess + 1) / 2) * hop
          for k in from..<min(to, frames) { keep[k] = false }
        }
        i = j
      } else {
        i += 1
      }
    }
    return channels.map { channel in
      var out = [Float]()
      out.reserveCapacity(channel.count)
      for (k, sample) in channel.enumerated() where keep[k] { out.append(sample) }
      return out
    }
  }

  // MARK: - Encode

  private static func encodeInt16(_ channels: [[Float]]) -> Data {
    let frames = channels.first?.count ?? 0
    var data = Data(capacity: frames * channels.count * 2)
    for frame in 0..<frames {
      for channel in channels {
        let clamped = max(-1, min(1, channel[frame]))
        let value = Int16((clamped * 32_767).rounded())
        let raw = UInt16(bitPattern: value)
        data.append(UInt8(raw & 0xFF))
        data.append(UInt8(raw >> 8))
      }
    }
    return data
  }

  static func riffHeader(dataBytes: Int, sampleRate: Int, channels: Int) -> Data {
    var header = Data()
    func u32(_ value: Int) {
      for shift in stride(from: 0, to: 32, by: 8) { header.append(UInt8((value >> shift) & 0xFF)) }
    }
    func u16(_ value: Int) {
      header.append(UInt8(value & 0xFF))
      header.append(UInt8((value >> 8) & 0xFF))
    }
    header.append(contentsOf: Array("RIFF".utf8))
    u32(36 + dataBytes)
    header.append(contentsOf: Array("WAVEfmt ".utf8))
    u32(16)
    u16(1)
    u16(channels)
    u32(sampleRate)
    u32(sampleRate * channels * 2)
    u16(channels * 2)
    u16(16)
    header.append(contentsOf: Array("data".utf8))
    u32(dataBytes)
    return header
  }
}
