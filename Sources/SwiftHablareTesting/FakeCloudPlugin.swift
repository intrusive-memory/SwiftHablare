//
//  FakeCloudPlugin.swift
//  SwiftHablareTesting
//
//  A cloud plugin that declares one credential (R13).
//

import Foundation
import SwiftHablare

public final class FakeCloudPlugin: HablarePlugin, @unchecked Sendable {
  public static let id = "fake-cloud"
  public static let displayName = "Fake Cloud"
  public static let kind = PluginKind.cloud
  public static let credentials = [
    CredentialRequirement(
      primaryEnvironmentVariable: "FAKE_CLOUD_API_KEY",
      keychainAccount: "fake-cloud",
      displayName: "Fake Cloud API key",
      placeholder: "fake_…")
  ]

  public let context: PluginContext
  public let fakeSynthesizer: FakeVoiceSynthesizer

  /// Synthesis without a key throws `missingCredential`, like a real cloud engine.
  public init(context: PluginContext) async throws {
    self.context = context
    let keys = context.keys
    self.fakeSynthesizer = FakeVoiceSynthesizer(
      capabilities: [.seed], maxConcurrentRequests: 4,
      preflight: {
        guard keys.apiKey(for: "fake-cloud") != nil else {
          throw HablareError.missingCredential(
            pluginId: "fake-cloud", environmentVariable: "FAKE_CLOUD_API_KEY")
        }
      })
  }

  public var synthesizer: (any VoiceSynthesizer)? { fakeSynthesizer }

  public func failNextCall(with error: HablareError) { fakeSynthesizer.failNextCall(with: error) }
  public func setReadiness(_ readiness: VoiceReadiness) { fakeSynthesizer.setReadiness(readiness) }

  /// `.needsCredential` while the key store has no `fake-cloud` key, otherwise `.ready`.
  public func status() async -> PluginStatus {
    PluginStatus.evaluate(credentials: Self.credentials, keys: context.keys, models: [])
  }
}
