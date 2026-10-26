//
//  FakeSupport.swift
//  SwiftHablareTesting
//
//  Shared helpers for the fake plugins: a lock box, deterministic WAV bytes, and the
//  one-shot failure and readiness knobs every fake exposes.
//

import Foundation
import SwiftHablare

/// A tiny lock-guarded value, so fakes stay `Sendable` without an actor hop.
final class FakeLocked<Value>: @unchecked Sendable {
  private let lock = NSLock()
  private var value: Value

  init(_ value: Value) { self.value = value }

  func withValue<R>(_ body: (inout Value) throws -> R) rethrows -> R {
    try lock.withLock { try body(&value) }
  }

  var current: Value { lock.withLock { value } }
}

/// Deterministic audio synthesis for the fakes.
enum FakeAudio {
  /// The bytes carry a RIFF/WAVE header, so the honest label is container `.wav` (not `.pcm`).
  static let format = AudioFormat(container: .wav, sampleRate: 24_000, channels: 1, bitDepth: 16)

  /// Same input, same bytes: a splitmix64 stream seeded from FNV-1a over the text, mixed with the seed.
  static func wav(text: String, seed: UInt64, seconds: TimeInterval) -> Data {
    var hash: UInt64 = 0xcbf2_9ce4_8422_2325
    for byte in text.utf8 {
      hash ^= UInt64(byte)
      hash = hash &* 0x0000_0100_0000_01b3
    }
    var state = hash ^ (seed &* 0x9e37_79b9_7f4a_7c15)
    let sampleCount = max(1, Int((seconds * Double(format.sampleRate)).rounded()))
    var pcm = Data(capacity: sampleCount * 2)
    for _ in 0..<sampleCount {
      state = state &+ 0x9e37_79b9_7f4a_7c15
      var z = state
      z = (z ^ (z >> 30)) &* 0xbf58_476d_1ce4_e5b9
      z = (z ^ (z >> 27)) &* 0x94d0_49bb_1331_11eb
      z ^= z >> 31
      let sample = Int16(truncatingIfNeeded: z >> 48) / 8
      withUnsafeBytes(of: sample.littleEndian) { pcm.append(contentsOf: $0) }
    }
    return header(pcmByteCount: pcm.count) + pcm
  }

  /// A 44-byte canonical RIFF/WAVE header for 24 kHz mono 16-bit PCM.
  static func header(pcmByteCount: Int) -> Data {
    var data = Data()
    func append32(_ value: UInt32) {
      withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
    }
    func append16(_ value: UInt16) {
      withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
    }
    let rate = UInt32(format.sampleRate)
    data.append(contentsOf: Array("RIFF".utf8))
    append32(UInt32(36 + pcmByteCount))
    data.append(contentsOf: Array("WAVE".utf8))
    data.append(contentsOf: Array("fmt ".utf8))
    append32(16)
    append16(1)
    append16(UInt16(format.channels))
    append32(rate)
    append32(rate * UInt32(format.channels) * 2)
    append16(UInt16(format.channels * 2))
    append16(16)
    data.append(contentsOf: Array("data".utf8))
    append32(UInt32(pcmByteCount))
    return data
  }
}

/// One-shot failure knob: the next call throws, then behaviour returns to normal.
final class FakeFailure: @unchecked Sendable {
  private let pending = FakeLocked<HablareError?>(nil)

  func arm(_ error: HablareError?) { pending.withValue { $0 = error } }

  /// Throws the armed error once and disarms.
  func throwIfArmed() throws {
    if let error = pending.withValue({ state -> HablareError? in
      defer { state = nil }
      return state
    }) {
      throw error
    }
  }
}
