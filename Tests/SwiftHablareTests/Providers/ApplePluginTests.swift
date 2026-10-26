//
//  ApplePluginTests.swift
//  SwiftHablareTests
//
//  ApplePlugin's adapter, over a fake engine: no voices, no audio hardware.
//

import Foundation
import Testing

@testable import SwiftHablare
@testable import SwiftHablareTesting

/// An AIFF with a COMM chunk for `rate`/`channels`/`bits` and a little silence.
private func aiff(rate: Int, channels: Int, bits: Int) -> Data {
  func be16(_ v: Int) -> [UInt8] { [UInt8(v >> 8 & 0xFF), UInt8(v & 0xFF)] }
  func be32(_ v: Int) -> [UInt8] { be16(v >> 16) + be16(v & 0xFFFF) }
  let exponent = Int(floor(log2(Double(rate))))
  let mantissa = UInt64(rate) << UInt64(63 - exponent)
  var extended = be16(16383 + exponent)
  for shift in stride(from: 56, through: 0, by: -8) {
    extended.append(UInt8(mantissa >> UInt64(shift) & 0xFF))
  }
  let frames = 100
  let comm = be16(channels) + be32(frames) + be16(bits) + extended
  let sound = be32(0) + be32(0) + [UInt8](repeating: 0, count: frames * channels * bits / 8)
  var body = Array("AIFF".utf8)
  body += Array("COMM".utf8) + be32(comm.count) + comm
  body += Array("SSND".utf8) + be32(sound.count) + sound
  return Data(Array("FORM".utf8) + be32(body.count) + body)
}

private struct FakeEngine: AppleTTSEngine {
  var data: Data = aiff(rate: 22_050, channels: 1, bits: 16)
  var failure: (any Error)?

  func generateAudio(text: String, voiceId: String, languageCode: String) async throws -> Data {
    try await generateAudioWithDuration(text: text, voiceId: voiceId, languageCode: languageCode).0
  }
  func generateAudioWithDuration(text: String, voiceId: String, languageCode: String) async throws
    -> (Data, TimeInterval)
  {
    if let failure { throw failure }
    return (data, 1.5)
  }
  func fetchVoices(languageCode: String) async throws -> [Voice] { [] }
  func estimateDuration(text: String, voiceId: String) -> TimeInterval { 1 }
}

@Suite("ApplePlugin adapter")
struct ApplePluginTests {
  private let voice = VoiceReference.catalog(pluginId: "apple", voiceId: "v1")

  private func synthesizer(
    _ engine: FakeEngine = FakeEngine(), installed: Bool = true
  ) -> any VoiceSynthesizer {
    ApplePlugin(engine: engine, voiceExists: { _ in installed }).synthesizer!
  }

  @Test("Declares a local, credential-free, synthesizer-only plugin")
  func shape() async throws {
    let plugin = try await ApplePlugin(
      context: PluginContext(keys: InMemoryAPIKeyStore(), registry: PluginRegistry()))
    #expect(ApplePlugin.id == "apple")
    #expect(ApplePlugin.kind == .local)
    #expect(ApplePlugin.credentials.isEmpty)
    #expect(ApplePlugin.models.isEmpty)
    #expect(plugin.designer == nil)
    #expect(plugin.converter == nil)
    #expect(await plugin.status() == .ready)
    let synth = try #require(plugin.synthesizer)
    #expect(synth.capabilities == [.onDevice])
    #expect(synth.maxConcurrentRequests == 1)
    #expect(synth.cacheKey(for: SpeechRequest(text: "x", voice: voice, seed: 1)) == nil)
  }

  @Test("GeneratedAudio.format is read from the AIFF header")
  func formatFromHeader() async throws {
    let engine = FakeEngine(data: aiff(rate: 44_100, channels: 2, bits: 16))
    let audio = try await synthesizer(engine).synthesize(SpeechRequest(text: "Hi", voice: voice))
    #expect(
      audio.format == AudioFormat(container: .aiff, sampleRate: 44_100, channels: 2, bitDepth: 16))
    #expect(audio.duration == 1.5)
  }

  @Test("Cancelled task throws HablareError.cancelled")
  func cancellation() async {
    let synth = synthesizer()
    let voice = self.voice
    let task = Task { () -> Bool in
      withUnsafeCurrentTask { $0?.cancel() }
      do {
        _ = try await synth.synthesize(SpeechRequest(text: "Hi", voice: voice))
      } catch HablareError.cancelled {
        return true
      } catch { return false }
      return false
    }
    #expect(await task.value)
  }

  @Test("Bad requests throw HablareError")
  func errors() async {
    let synth = synthesizer()
    await #expect(throws: HablareError.self) {
      _ = try await synth.synthesize(SpeechRequest(text: "  ", voice: voice))
    }
    await #expect(throws: HablareError.self) {
      _ = try await synth.synthesize(
        SpeechRequest(text: "Hi", voice: .catalog(pluginId: "other", voiceId: "v")))
    }
    await #expect(throws: HablareError.self) {
      _ = try await synthesizer(installed: false).synthesize(
        SpeechRequest(text: "Hi", voice: voice))
    }
    await #expect(throws: HablareError.self) {
      _ = try await synthesizer(FakeEngine(failure: VoiceProviderError.invalidResponse))
        .synthesize(SpeechRequest(text: "Hi", voice: voice))
    }
  }

  @Test("Readiness: installed catalog voice is ready, others unsupported")
  func readiness() async {
    #expect(await synthesizer().readiness(for: voice) == .ready(source: nil))
    if case .unsupported = await synthesizer(installed: false).readiness(for: voice) {
    } else {
      Issue.record("missing voice should be unsupported")
    }
    if case .unsupported = await synthesizer().readiness(
      for: .asset(URL(fileURLWithPath: "/x.vox")))
    {
    } else {
      Issue.record("asset voice should be unsupported")
    }
  }
}
