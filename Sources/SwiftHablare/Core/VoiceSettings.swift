//
//  VoiceSettings.swift
//  SwiftHablare
//
//  Typed, persisted settings values (R5, D-1). Core provides Codable round-tripping;
//  where they are stored is the consumer's choice.
//

import Foundation

public struct VoiceSettings: Codable, Hashable, Sendable, ExpressibleByDictionaryLiteral {
  public var values: [String: SettingValue]

  public init() { self.values = [:] }

  public init(_ values: [String: SettingValue]) { self.values = values }

  public init(dictionaryLiteral elements: (String, SettingValue)...) {
    self.values = Dictionary(elements, uniquingKeysWith: { _, last in last })
  }

  public init(from decoder: Decoder) throws {
    self.values = try decoder.singleValueContainer().decode([String: SettingValue].self)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(values)
  }

  public subscript(key: String) -> SettingValue? {
    get { values[key] }
    set { values[key] = newValue }
  }

  public var isEmpty: Bool { values.isEmpty }

  /// Returns settings with every key checked against `schema` for `scope` and defaults filled in.
  /// Throws `HablareError.invalidRequest` naming an unknown key, a wrongly typed value or an
  /// out-of-range value.
  public func validated(against schema: SettingsSchema, scope: SettingScope) throws -> VoiceSettings
  {
    let inScope = Dictionary(
      schema.definitions(in: scope).map { ($0.key, $0) }, uniquingKeysWith: { first, _ in first })
    var result: [String: SettingValue] = [:]
    for key in values.keys.sorted() {
      guard let definition = inScope[key], let value = values[key] else {
        throw HablareError.invalidRequest(
          detail: "unknown \(scope.rawValue) setting '\(key)'")
      }
      result[key] = try definition.validate(value)
    }
    for (key, definition) in inScope where result[key] == nil {
      if let fallback = definition.defaultValue { result[key] = fallback }
    }
    return VoiceSettings(result)
  }
}
