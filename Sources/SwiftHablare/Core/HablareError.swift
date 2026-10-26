//
//  HablareError.swift
//  SwiftHablare
//
//  Errors with a stable category on every case (R10). Consumers decide fallback
//  from the category; core never silently substitutes a voice.
//

import Foundation

public enum ErrorCategory: String, Sendable, Hashable {
  case transient
  case permanent
  case permanentUntilDownloaded
  case cancelled
}

public enum HablareError: Error, Sendable {
  case missingCredential(pluginId: String, environmentVariable: String)
  case safetyBlocked(reason: String)
  case invalidRequest(detail: String)
  case unsupportedVoice(VoiceReference, reason: String)
  case modelNotAvailable(ModelDescriptor)
  case rateLimited(retryAfter: TimeInterval?)
  case quotaExceeded
  case transient(underlying: any Error)
  case cancelled

  public var category: ErrorCategory {
    switch self {
    case .missingCredential, .safetyBlocked, .invalidRequest, .unsupportedVoice, .quotaExceeded:
      return .permanent
    case .modelNotAvailable:
      return .permanentUntilDownloaded
    case .rateLimited, .transient:
      return .transient
    case .cancelled:
      return .cancelled
    }
  }
}

extension HablareError: CustomStringConvertible {
  /// Never includes a credential value; only the name of the environment variable.
  public var description: String {
    switch self {
    case .missingCredential(let pluginId, let environmentVariable):
      return "Missing credential for plugin '\(pluginId)': set \(environmentVariable)"
    case .safetyBlocked(let reason):
      return "Request blocked by safety policy: \(reason)"
    case .invalidRequest(let detail):
      return "Invalid request: \(detail)"
    case .unsupportedVoice(let voice, let reason):
      return "Unsupported voice \(voice): \(reason)"
    case .modelNotAvailable(let model):
      return "Model not available: \(model.id)"
    case .rateLimited(let retryAfter):
      if let retryAfter {
        return "Rate limited; retry after \(retryAfter) seconds"
      }
      return "Rate limited"
    case .quotaExceeded:
      return "Quota exceeded"
    case .transient(let underlying):
      return "Transient failure: \(underlying)"
    case .cancelled:
      return "Cancelled"
    }
  }
}

// MARK: - Placeholder

/// Minimal placeholder so R10's `modelNotAvailable` compiles. Sortie 5 replaces this
/// with the full R1 `ModelDescriptor` (move it to Plugins/ and complete it).
public struct ModelDescriptor: Sendable, Hashable {
  public var id: String
  public init(id: String) { self.id = id }
}
