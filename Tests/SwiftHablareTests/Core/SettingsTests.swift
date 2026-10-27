import Foundation
import Testing

@testable import SwiftHablare

@Suite("Settings")
struct SettingsTests {
  static let schema = SettingsSchema([
    SettingDefinition(
      key: "exaggeration", valueType: .double, range: 0...2, defaultValue: .double(0.5),
      label: "Exaggeration", step: 0.05),
    SettingDefinition(
      key: "cfg_weight", valueType: .double, range: 0...1, defaultValue: .double(0.5),
      label: "CFG weight", step: 0.05),
    SettingDefinition(
      key: "temperature", valueType: .double, range: 0...2, defaultValue: .double(0.8),
      label: "Temperature", step: 0.05),
    SettingDefinition(key: "seed", valueType: .int, range: 0...4_294_967_295, label: "Seed"),
    SettingDefinition(
      key: "ref_start", valueType: .double, range: 0...600, defaultValue: .double(0),
      label: "Reference start (s)"),
    SettingDefinition(
      key: "max_pause", valueType: .double, range: 0...10, label: "Max pause (s)"),
    SettingDefinition(
      key: "model_size", valueType: .choice, choices: ["0.6b", "1.7b"],
      defaultValue: .choice("1.7b"), scope: .perPlugin, label: "Model size"),
  ])

  @Test("Unknown key is rejected and named")
  func unknownKey() {
    let settings: VoiceSettings = ["bogus": .int(1)]
    do {
      _ = try settings.validated(against: Self.schema, scope: .perVoice)
      Issue.record("expected throw")
    } catch let error as HablareError {
      #expect(error.description.contains("bogus"))
      #expect(error.category == .permanent)
    } catch {
      Issue.record("wrong error \(error)")
    }
  }

  @Test("Out-of-range value throws")
  func outOfRange() {
    let settings: VoiceSettings = ["exaggeration": .double(3.0)]
    #expect(throws: HablareError.self) {
      try settings.validated(against: Self.schema, scope: .perVoice)
    }
  }

  @Test("Wrong type throws")
  func wrongType() {
    let settings: VoiceSettings = ["temperature": .string("hot")]
    #expect(throws: HablareError.self) {
      try settings.validated(against: Self.schema, scope: .perVoice)
    }
  }

  @Test("Defaults are filled and ints coerce to doubles")
  func defaults() throws {
    let settings: VoiceSettings = ["cfg_weight": .int(1)]
    let v = try settings.validated(against: Self.schema, scope: .perVoice)
    #expect(v["cfg_weight"] == .double(1))
    #expect(v["exaggeration"] == .double(0.5))
    #expect(v["temperature"] == .double(0.8))
    #expect(v["seed"] == nil)
    #expect(v["model_size"] == nil)
  }

  @Test("Scopes are separate")
  func scopes() {
    let settings: VoiceSettings = ["model_size": .choice("1.7b")]
    #expect(throws: HablareError.self) {
      try settings.validated(against: Self.schema, scope: .perVoice)
    }
  }

  @Test("JSON round trip")
  func jsonRoundTrip() throws {
    let settings: VoiceSettings = [
      "exaggeration": .double(0.7), "seed": .int(42), "flag": .bool(true),
      "name": .string("x"), "model_size": .choice("0.6b"),
    ]
    let data = try JSONEncoder().encode(settings)
    let decoded = try JSONDecoder().decode(VoiceSettings.self, from: data)
    #expect(decoded == settings)
  }

  @Test("Equal PluginConfigurations collapse in a Set")
  func pluginConfigurationHashable() {
    let a = PluginConfiguration(settings: ["model_size": .choice("1.7b")])
    let b = PluginConfiguration(settings: ["model_size": .choice("1.7b")])
    #expect(Set([a, b]).count == 1)
    #expect(PluginConfiguration.empty == PluginConfiguration())
  }

  @Test("PluginConfiguration validates perPlugin keys only")
  func pluginConfigurationValidation() throws {
    let filled = try PluginConfiguration.empty.validated(against: Self.schema)
    #expect(filled.settings["model_size"] == .choice("1.7b"))
    #expect(filled.settings["exaggeration"] == nil)
    let bad = PluginConfiguration(settings: ["model_size": .choice("9b")])
    #expect(throws: HablareError.self) { try bad.validated(against: Self.schema) }
  }
}
