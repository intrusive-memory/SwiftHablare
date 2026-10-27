import Foundation
import Testing

@testable import SwiftHablare

@Suite("CacheKey")
struct CacheKeyTests {
  struct Inputs {
    var pluginId = "fake-synth"
    var modelId: String? = "model-a"
    var source: VoiceSource? = VoiceSource(
      engine: "google", model: "gemini", kind: .referenceAudio, path: "embeddings/google/a.wav")
    var settings = VoiceSettings(["temperature": .double(0.5), "mode": .choice("calm")])
    var seed: UInt64? = 42
    var text = "Hello there."
    var format = AudioFormat.pcm24kMono16
    var capabilities: SynthesisCapabilities = [.seed]

    var key: String? {
      CacheKey.make(
        pluginId: pluginId, modelId: modelId, voiceSource: source, settings: settings, seed: seed,
        text: text, format: format, capabilities: capabilities)
    }
  }

  @Test("Identical inputs give identical keys; keys are 64 hex characters")
  func identical() throws {
    let a = try #require(Inputs().key)
    #expect(a == Inputs().key)
    #expect(a.count == 64)
    #expect(a.allSatisfy { $0.isHexDigit })
  }

  @Test("Settings key order does not matter")
  func settingsOrder() {
    var reordered = Inputs()
    reordered.settings = VoiceSettings(["mode": .choice("calm"), "temperature": .double(0.5)])
    #expect(reordered.key == Inputs().key)
  }

  @Test("Changing each input, one at a time, changes the key")
  func eachInputMatters() throws {
    let base = try #require(Inputs().key)
    var variants: [(String, Inputs)] = []
    func vary(_ name: String, _ change: (inout Inputs) -> Void) {
      var inputs = Inputs()
      change(&inputs)
      variants.append((name, inputs))
    }
    vary("plugin id") { $0.pluginId = "other" }
    vary("model id") { $0.modelId = "model-b" }
    vary("model id nil") { $0.modelId = nil }
    vary("source engine") {
      $0.source = VoiceSource(
        engine: "qwen3-tts", model: "gemini", kind: .referenceAudio, path: "embeddings/google/a.wav"
      )
    }
    vary("source model") {
      $0.source = VoiceSource(
        engine: "google", model: "other", kind: .referenceAudio, path: "embeddings/google/a.wav")
    }
    vary("source kind") {
      $0.source = VoiceSource(
        engine: "google", model: "gemini", kind: .embedding, path: "embeddings/google/a.wav")
    }
    vary("source path") {
      $0.source = VoiceSource(
        engine: "google", model: "gemini", kind: .referenceAudio, path: "embeddings/google/b.wav")
    }
    vary("source nil") { $0.source = nil }
    vary("setting value") { $0.settings["temperature"] = .double(0.6) }
    vary("setting type") { $0.settings["temperature"] = .string("0.5") }
    vary("setting added") { $0.settings["extra"] = .bool(true) }
    vary("setting removed") { $0.settings["mode"] = nil }
    vary("seed") { $0.seed = 43 }
    vary("seed nil") { $0.seed = nil }
    vary("text") { $0.text = "Hello there!" }
    vary("format container") { $0.format.container = .wav }
    vary("format sample rate") { $0.format.sampleRate = 48_000 }
    vary("format channels") { $0.format.channels = 2 }
    vary("format bit depth") { $0.format.bitDepth = 24 }

    var seen: Set<String> = [base]
    for (name, inputs) in variants {
      let key = try #require(inputs.key, "\(name)")
      #expect(key != base, "\(name) did not change the key")
      #expect(seen.insert(key).inserted, "\(name) collided with another variant")
    }
  }

  @Test("A synthesizer without .seed gets nil")
  func noSeedCapability() {
    var inputs = Inputs()
    inputs.capabilities = [.onDevice]
    #expect(inputs.key == nil)
  }

  @Test("Adjacent fields cannot run together")
  func fieldBoundaries() {
    var a = Inputs()
    a.pluginId = "ab"
    a.modelId = "c"
    var b = Inputs()
    b.pluginId = "a"
    b.modelId = "bc"
    #expect(a.key != b.key)
  }

  @Test("Request convenience uses the request seed")
  func requestOverload() {
    let request = SpeechRequest(
      text: "Hello there.", voice: .catalog(pluginId: "p", voiceId: "v"), seed: 42)
    let inputs = Inputs()
    let key = CacheKey.make(
      pluginId: inputs.pluginId, modelId: inputs.modelId, voiceSource: inputs.source,
      request: request, validatedSettings: inputs.settings, format: inputs.format,
      capabilities: inputs.capabilities)
    #expect(key == inputs.key)
  }
}
