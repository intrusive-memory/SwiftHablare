//
//  VoiceListing.swift
//  SwiftHablare
//
//  An optional capability: a plugin (or its synthesizer) that can list its catalog voices.
//  The plugin contract has no listing role, so hosts and `GenerationService` check for this.
//

import Foundation

/// A plugin, or a plugin's synthesizer, that lists the catalog voices it can speak.
///
/// ``ApplePlugin`` adopts it. Each returned ``Voice`` is addressed as
/// `.catalog(pluginId: voice.providerId, voiceId: voice.id)`.
public protocol VoiceListing: Sendable {
  /// The voices available for `languageCode` (an ISO 639-1 code such as "en").
  func voices(languageCode: String) async throws -> [Voice]
}
