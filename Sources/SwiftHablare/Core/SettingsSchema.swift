//
//  SettingsSchema.swift
//  SwiftHablare
//
//  Typed settings metadata (R5, D-1). A host draws controls from this; core validates with it.
//

import Foundation

/// A single typed setting value (D-1).
public enum SettingValue: Codable, Hashable, Sendable {
  case bool(Bool)
  case int(Int)
  case double(Double)
  case string(String)
  case choice(String)
}

/// Whether a setting belongs to one voice or to the whole plugin.
public enum SettingScope: String, Codable, Hashable, Sendable {
  case perVoice
  case perPlugin
}

public struct SettingDefinition: Hashable, Sendable {
  public enum ValueType: String, Codable, Hashable, Sendable {
    case bool, int, double, string, choice
  }

  public var key: String
  public var valueType: ValueType
  /// Inclusive bounds for `.int` and `.double` values.
  public var range: ClosedRange<Double>?
  /// Allowed values for `.choice`.
  public var choices: [String]
  public var defaultValue: SettingValue?
  public var scope: SettingScope
  public var label: String
  public var help: String
  /// Suggested increment for a slider or stepper.
  public var step: Double?

  public init(
    key: String,
    valueType: ValueType,
    range: ClosedRange<Double>? = nil,
    choices: [String] = [],
    defaultValue: SettingValue? = nil,
    scope: SettingScope = .perVoice,
    label: String,
    help: String = "",
    step: Double? = nil
  ) {
    self.key = key
    self.valueType = valueType
    self.range = range
    self.choices = choices
    self.defaultValue = defaultValue
    self.scope = scope
    self.label = label
    self.help = help
    self.step = step
  }

  /// Checks type, range and choices; returns the value normalized to the declared type
  /// (an `.int` given for a `.double` setting becomes `.double`).
  func validate(_ value: SettingValue) throws -> SettingValue {
    func bad(_ why: String) -> HablareError {
      .invalidRequest(detail: "setting '\(key)' \(why)")
    }
    switch (valueType, value) {
    case (.bool, .bool):
      return value
    case (.string, .string):
      return value
    case (.choice, .choice(let c)):
      guard choices.isEmpty || choices.contains(c) else {
        throw bad("must be one of \(choices.joined(separator: ", ")), got '\(c)'")
      }
      return value
    case (.int, .int(let i)):
      try checkRange(Double(i), bad)
      return value
    case (.double, .double(let d)):
      guard d.isFinite else { throw bad("must be finite") }
      try checkRange(d, bad)
      return value
    case (.double, .int(let i)):
      try checkRange(Double(i), bad)
      return .double(Double(i))
    default:
      throw bad("expects a \(valueType.rawValue) value")
    }
  }

  private func checkRange(_ x: Double, _ bad: (String) -> HablareError) throws {
    if let range, !range.contains(x) {
      throw bad("value \(x) is outside \(range.lowerBound)...\(range.upperBound)")
    }
  }
}

public struct SettingsSchema: Hashable, Sendable {
  public var definitions: [SettingDefinition]

  public init(_ definitions: [SettingDefinition] = []) {
    self.definitions = definitions
  }

  public static let empty = SettingsSchema()

  public func definition(for key: String) -> SettingDefinition? {
    definitions.first { $0.key == key }
  }

  public func definitions(in scope: SettingScope) -> [SettingDefinition] {
    definitions.filter { $0.scope == scope }
  }
}
