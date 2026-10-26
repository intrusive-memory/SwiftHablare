//
//  CacheKey.swift
//  SwiftHablare
//
//  Content-addressed cache keys (R8): SHA-256 over every input that changes the audio.
//

import CryptoKit
import Foundation

public enum CacheKey {
  /// A stable one-line description of the voice source that conditions a take (engine, model,
  /// kind, archive path). `nil` for catalog voices. Freshness is deliberately excluded.
  public static func fingerprint(of source: VoiceSource?) -> String {
    guard let source else { return "none" }
    return [source.engine, source.model ?? "", source.kind.rawValue, source.path ?? ""]
      .joined(separator: "|")
  }

  /// The key for one take, hex-encoded SHA-256. Returns `nil` when `capabilities` lacks `.seed`
  /// (output is not reproducible). `settings` should already be validated against the plugin's
  /// schema so defaults are filled in; keys are sorted. `seed` is `SpeechRequest.seed`.
  public static func make(
    pluginId: String,
    modelId: String?,
    voiceSource: VoiceSource?,
    settings: VoiceSettings,
    seed: UInt64?,
    text: String,
    format: AudioFormat,
    capabilities: SynthesisCapabilities
  ) -> String? {
    guard capabilities.contains(.seed) else { return nil }
    var hasher = SHA256()
    func field(_ label: String, _ value: String) {
      // Length-prefixed so adjacent fields cannot run together.
      let bytes = Array(value.utf8)
      hasher.update(data: Data("\(label):\(bytes.count):".utf8))
      hasher.update(data: Data(bytes))
      hasher.update(data: Data("\n".utf8))
    }
    field("plugin", pluginId)
    field("model", modelId ?? "")
    field("source", fingerprint(of: voiceSource))
    for key in settings.values.keys.sorted() {
      field("setting.\(key)", describe(settings.values[key]!))
    }
    field("seed", seed.map(String.init) ?? "none")
    field("text", text)
    field(
      "format",
      "\(format.container.rawValue)|\(format.sampleRate)|\(format.channels)|\(format.bitDepth.map(String.init) ?? "")"
    )
    return hasher.finalize().map { String(format: "%02x", $0) }.joined()
  }

  /// Convenience for a synthesizer: the key for `request` with `settings` already validated.
  public static func make(
    pluginId: String,
    modelId: String?,
    voiceSource: VoiceSource?,
    request: SpeechRequest,
    validatedSettings: VoiceSettings,
    format: AudioFormat,
    capabilities: SynthesisCapabilities
  ) -> String? {
    make(
      pluginId: pluginId, modelId: modelId, voiceSource: voiceSource, settings: validatedSettings,
      seed: request.seed, text: request.text, format: format, capabilities: capabilities)
  }

  private static func describe(_ value: SettingValue) -> String {
    switch value {
    case .bool(let v): return "bool:\(v)"
    case .int(let v): return "int:\(v)"
    case .double(let v): return "double:\(v)"
    case .string(let v): return "string:\(v)"
    case .choice(let v): return "choice:\(v)"
    }
  }
}
