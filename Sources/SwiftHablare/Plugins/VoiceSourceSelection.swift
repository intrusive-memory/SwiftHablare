//
//  VoiceSourceSelection.swift
//  SwiftHablare
//
//  Picks the `.vox` source a synthesizer will use, from its ordered preference list (R3).
//  Every synthesizer that reads `.vox` assets, and every hybrid that reports readiness for
//  one, selects through this so readiness and `GeneratedAudio.sourceUsed` agree.
//

import Foundation

extension VoiceSourcePattern {
  /// True when `source` is matched by this pattern (a `nil` engine or kind matches anything).
  public func matches(_ source: VoiceSource) -> Bool {
    if let engine, source.engine != engine { return false }
    if let kind, source.kind != kind { return false }
    return true
  }
}

extension VoiceAsset {
  /// The source a synthesizer consuming `preferences` (most preferred first) will use, or `nil`
  /// when nothing in this asset is usable.
  ///
  /// - The first pattern with a usable match wins; later patterns are fallbacks.
  /// - A stale source (a `.serverHandle` past its expiry) is skipped, so an expired server voice
  ///   never blocks a synthesizer that can use a stored sample instead.
  /// - Within one pattern, reference audio is preferred over embeddings, then server handles;
  ///   ties keep ``sources(asOf:)`` order.
  public func preferredSource(
    for preferences: [VoiceSourcePattern], asOf now: Date = Date()
  ) -> VoiceSource? {
    let usable = sources(asOf: now).filter { source in
      if case .stale = source.freshness { return false }
      return true
    }
    for pattern in preferences {
      let matches = usable.filter { pattern.matches($0) }
      if let best = matches.min(by: { Self.kindRank($0.kind) < Self.kindRank($1.kind) }) {
        return best
      }
    }
    return nil
  }

  private static func kindRank(_ kind: VoiceSource.Kind) -> Int {
    switch kind {
    case .referenceAudio: return 0
    case .embedding: return 1
    case .serverHandle: return 2
    }
  }
}

extension VoiceSynthesizer {
  /// The source this synthesizer will use from `asset`, following ``consumedSources``.
  public func preferredSource(in asset: VoiceAsset, asOf now: Date = Date()) -> VoiceSource? {
    asset.preferredSource(for: consumedSources, asOf: now)
  }

  /// Readiness for a `.vox` voice computed from ``consumedSources`` alone: `.ready` naming the
  /// preferred source, or `.unsupported` when the file cannot be read or has nothing usable.
  /// Catalog voices report `.ready(source: nil)`.
  public func sourceReadiness(for voice: VoiceReference, asOf now: Date = Date()) -> VoiceReadiness
  {
    guard case .asset(let url) = voice else { return .ready(source: nil) }
    let asset: VoiceAsset
    do {
      asset = try VoiceAsset(contentsOf: url)
    } catch {
      return .unsupported(reason: "cannot read \(url.lastPathComponent)")
    }
    guard let source = preferredSource(in: asset, asOf: now) else {
      return .unsupported(
        reason: "\(url.lastPathComponent) has no source this synthesizer consumes")
    }
    return .ready(source: source)
  }
}
