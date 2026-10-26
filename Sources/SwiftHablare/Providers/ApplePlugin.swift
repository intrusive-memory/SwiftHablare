//
//  ApplePlugin.swift
//  SwiftHablare
//
//  The built-in Apple text-to-speech engine as a `HablarePlugin` (R1). It provides only a
//  synthesizer role, runs on device, and needs no credentials and no models. It wraps the
//  existing `AppleTTSEngine` / `AVSpeechTTSEngine`.
//

import AVFoundation
import Foundation

public struct ApplePlugin: HablarePlugin {
  /// Matches the `apple://` `VoiceURI` scheme.
  public static let id = "apple"
  public static let displayName = "Apple Text-to-Speech"
  public static let kind = PluginKind.local

  /// The `UserDefaults` key the 6.x provider used for the Enhanced/Premium-only voice filter.
  public static let highQualityFilterKey = "appleVoiceFilterHighQualityOnly"

  private let engine: AppleTTSEngineBoundary
  private let appleSynthesizer: AppleSynthesizer
  // UserDefaults is documented thread-safe.
  nonisolated(unsafe) private let userDefaults: UserDefaults

  public init(context: PluginContext) async throws {
    self.init(engine: AVSpeechTTSEngine(), userDefaults: .standard)
  }

  /// Test seam: build over any engine, with an injectable voice lookup.
  init(
    engine: any AppleTTSEngine,
    userDefaults: UserDefaults = .standard,
    voiceExists: @escaping @Sendable (String) async -> Bool = AppleSynthesizer.systemHasVoice
  ) {
    self.engine = AppleTTSEngineBoundary(underlying: engine)
    self.appleSynthesizer = AppleSynthesizer(engine: engine, voiceExists: voiceExists)
    self.userDefaults = userDefaults
  }

  public var synthesizer: (any VoiceSynthesizer)? { appleSynthesizer }

  /// Always `.ready`: Apple TTS needs no credential and no download.
  public func status() async -> PluginStatus { .ready }

  /// The installed Apple voices for a language, honouring the high-quality-only filter
  /// (`highQualityFilterKey`). The 6.x provider's catalog listing.
  public func voices(languageCode: String) async throws -> [Voice] {
    let configuration = AppleTTSConfiguration(
      filterToHighQualityOnly: userDefaults.bool(forKey: Self.highQualityFilterKey))
    return try await engine.fetchVoices(languageCode: languageCode, configuration: configuration)
  }
}

// MARK: - Synthesizer

/// The Apple synthesizer role. Catalog voices only: `.catalog(pluginId: "apple", voiceId:)`
/// where `voiceId` is an `AVSpeechSynthesisVoice.identifier`.
struct AppleSynthesizer: VoiceSynthesizer {
  let engine: any AppleTTSEngine
  let voiceExists: @Sendable (String) async -> Bool

  init(engine: any AppleTTSEngine, voiceExists: @escaping @Sendable (String) async -> Bool) {
    self.engine = engine
    self.voiceExists = voiceExists
  }

  /// Default lookup: is this identifier an installed `AVSpeechSynthesisVoice`?
  @Sendable
  static func systemHasVoice(_ identifier: String) async -> Bool {
    await MainActor.run { AVSpeechSynthesisVoice(identifier: identifier) != nil }
  }

  var capabilities: SynthesisCapabilities { [.onDevice] }
  var limits: SynthesisLimits { .unlimited }
  var nativeFormats: [AudioFormat] {
    [AudioFormat(container: .aiff, sampleRate: 22_050, channels: 1, bitDepth: 16)]
  }
  var maxConcurrentRequests: Int { 1 }

  private func voiceId(of voice: VoiceReference) throws -> String {
    guard case .catalog(let pluginId, let voiceId) = voice, pluginId == ApplePlugin.id else {
      throw HablareError.unsupportedVoice(
        voice, reason: "ApplePlugin synthesizes only 'apple' catalog voices")
    }
    return voiceId
  }

  func readiness(for voice: VoiceReference) async -> VoiceReadiness {
    guard let identifier = try? voiceId(of: voice) else {
      return .unsupported(reason: "not an 'apple' catalog voice")
    }
    guard await voiceExists(identifier) else {
      return .unsupported(reason: "voice '\(identifier)' is not installed")
    }
    return .ready(source: nil)
  }

  func prepare(_ voice: VoiceReference) async throws {}

  func release(_ voice: VoiceReference) async {}

  func synthesize(_ request: SpeechRequest) async throws -> GeneratedAudio {
    if Task.isCancelled { throw HablareError.cancelled }
    let identifier = try voiceId(of: request.voice)
    guard !request.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw HablareError.invalidRequest(detail: "text cannot be empty")
    }
    guard await voiceExists(identifier) else {
      throw HablareError.unsupportedVoice(
        request.voice, reason: "voice '\(identifier)' is not installed")
    }
    if Task.isCancelled { throw HablareError.cancelled }

    let languageCode =
      request.languageCode ?? Locale.current.language.languageCode?.identifier ?? "en"
    let data: Data
    let duration: TimeInterval
    do {
      (data, duration) = try await engine.generateAudioWithDuration(
        text: request.text, voiceId: identifier, languageCode: languageCode)
    } catch is CancellationError {
      throw HablareError.cancelled
    } catch let error as HablareError {
      throw error
    } catch let error as VoiceProviderError {
      switch error {
      case .invalidRequest(let detail): throw HablareError.invalidRequest(detail: detail)
      default: throw HablareError.transient(underlying: error)
      }
    } catch {
      throw HablareError.transient(underlying: error)
    }
    if Task.isCancelled { throw HablareError.cancelled }

    guard let format = AIFFHeader.format(of: data) else {
      throw HablareError.transient(underlying: VoiceProviderError.invalidResponse)
    }
    return GeneratedAudio(
      data: data, format: format, duration: duration, droppedInstruct: request.instruct != nil)
  }
}

// MARK: - AIFF header

/// Reads the `COMM` chunk of an AIFF/AIFC file so `GeneratedAudio.format` describes the
/// bytes rather than a guess.
enum AIFFHeader {
  static func format(of data: Data) -> AudioFormat? {
    let bytes = [UInt8](data)
    guard bytes.count >= 12, bytes[0..<4].elementsEqual("FORM".utf8) else { return nil }
    let form = String(decoding: bytes[8..<12], as: UTF8.self)
    guard form == "AIFF" || form == "AIFC" else { return nil }

    func u16(_ at: Int) -> Int { Int(bytes[at]) << 8 | Int(bytes[at + 1]) }
    func u32(_ at: Int) -> Int { u16(at) << 16 | u16(at + 2) }

    var offset = 12
    while offset + 8 <= bytes.count {
      let size = u32(offset + 4)
      if bytes[offset..<offset + 4].elementsEqual("COMM".utf8) {
        let body = offset + 8
        guard size >= 18, body + 18 <= bytes.count else { return nil }
        let channels = u16(body)
        let bits = u16(body + 6)
        let exponent = u16(body + 8) & 0x7FFF
        var mantissa: UInt64 = 0
        for index in 0..<8 { mantissa = mantissa << 8 | UInt64(bytes[body + 10 + index]) }
        let rate = Double(mantissa) * pow(2.0, Double(exponent - 16383 - 63))
        guard channels > 0, rate.isFinite, rate >= 1 else { return nil }
        return AudioFormat(
          container: .aiff, sampleRate: Int(rate.rounded()), channels: channels, bitDepth: bits)
      }
      offset += 8 + size + (size & 1)
    }
    return nil
  }
}
