//
//  ApplePluginConformanceTests.swift
//  SwiftHablareTests
//
//  The conformance kit (R13) run against the real Apple engine. The full-mode suite needs
//  installed voices and audio services, so it is skipped in CITests and run locally through
//  LocalAudioTests. CI runs the hardware-free suite instead.
//

import AVFoundation
import Foundation
import Testing

@testable import SwiftHablare
@testable import SwiftHablareTesting

private func appleContext() -> PluginContext {
  PluginContext(keys: InMemoryAPIKeyStore(), registry: PluginRegistry())
}

/// Full kit: synthesizes with a real installed voice. Local only.
@Suite("ApplePlugin conformance (full)")
struct ApplePluginConformanceTests {
  // CITests sets CI=true. The plan's skippedTests entry alone does not stop a Swift Testing
  // test, so the trait is what keeps this out of CI (as in AVSpeechTTSEngineTests).
  @Test(
    "Full conformance kit passes against the real Apple engine",
    .enabled(if: !ProcessInfo.processInfo.environment.keys.contains("CI")))
  func fullKit() async {
    let installed = await MainActor.run {
      AVSpeechSynthesisVoice.speechVoices().filter { $0.language == "en-US" }.first?.identifier
        ?? AVSpeechSynthesisVoice.speechVoices().first?.identifier
    }
    guard let identifier = installed else {
      Issue.record("No AVSpeechSynthesisVoice is installed; cannot run the full Apple kit")
      return
    }
    let report = await ConformanceKit.run(
      ApplePlugin.self, context: appleContext(),
      voice: .catalog(pluginId: ApplePlugin.id, voiceId: identifier), mode: .full)
    #expect(report.passed, "\(report.summary)")
    // Only the credential-secrecy checks are skipped (Apple has no credentials).
    #expect(
      Set(report.skipped.map(\.check)) == [.secrecyStatus, .secrecyErrors], "\(report.summary)")
  }
}

/// Hardware-free kit: never synthesizes, so it runs in CI.
@Suite("ApplePlugin conformance (hardware-free)")
struct ApplePluginKitHardwareFreeTests {
  @Test("Hardware-free conformance kit passes against ApplePlugin")
  func hardwareFreeKit() async {
    let report = await ConformanceKit.run(
      ApplePlugin.self, context: appleContext(),
      voice: .catalog(pluginId: ApplePlugin.id, voiceId: "com.apple.voice.compact.en-US.Samantha"),
      mode: .hardwareFree)
    #expect(report.passed, "\(report.summary)")
    #expect(report.result(for: .initialization)?.outcome == .passed)
    #expect(report.result(for: .cacheKeyStability)?.outcome == .passed)
  }
}
