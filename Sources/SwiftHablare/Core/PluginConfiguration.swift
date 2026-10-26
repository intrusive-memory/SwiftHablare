//
//  PluginConfiguration.swift
//  SwiftHablare
//
//  Plugin-wide settings, e.g. VoxAlta model size `.choice("1.7b")` (D-1).
//

import Foundation

public struct PluginConfiguration: Codable, Hashable, Sendable {
  public var settings: VoiceSettings

  public init(settings: VoiceSettings = VoiceSettings()) {
    self.settings = settings
  }

  public static let empty = PluginConfiguration()

  /// Validates against the `perPlugin` keys of `schema`.
  public func validated(against schema: SettingsSchema) throws -> PluginConfiguration {
    PluginConfiguration(settings: try settings.validated(against: schema, scope: .perPlugin))
  }
}
