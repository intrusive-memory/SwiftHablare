//
//  VoiceReference.swift
//  SwiftHablare
//
//  Names a voice either by catalog entry or by a voice asset on disk (R3/R4).
//

import Foundation

public enum VoiceReference: Sendable, Hashable {
  /// A voice offered by a plugin's catalog.
  case catalog(pluginId: String, voiceId: String)
  /// A voice asset (for example a `.vox` bundle) at a URL.
  case asset(URL)
}
