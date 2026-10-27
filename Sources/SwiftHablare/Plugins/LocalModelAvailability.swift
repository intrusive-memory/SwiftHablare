//
//  LocalModelAvailability.swift
//  SwiftHablare
//
//  Maps a ModelDescriptor to on-disk availability through SwiftAcervo (R9). Status only:
//  no downloader, no cache, no network.
//

import Foundation
import OSLog
import SwiftAcervo

public enum ModelAvailability: Sendable, Hashable {
  case available
  case missing
  /// The descriptor has no `acervoModelId` (e.g. a cloud model); nothing to download.
  case notManaged
}

public struct LocalModelAvailability: Sendable {
  private static let logger = Logger(
    subsystem: "io.intrusive-memory.SwiftHablare", category: "LocalModelAvailability")

  private let probe: @Sendable (String) -> Bool

  /// Uses `Acervo.isModelAvailable`, which is offline and never throws. When no models
  /// directory is configured (no App Group, no `ACERVO_MODELS_DIR`) every model reports
  /// `.missing` instead of trapping.
  public init() {
    self.probe = { modelId in
      guard Acervo.resolvedSharedModelsDirectory != nil else {
        Self.logger.debug("No SwiftAcervo models directory configured; reporting missing")
        return false
      }
      return Acervo.isModelAvailable(modelId)
    }
  }

  /// Test seam: `probe` answers "is this Acervo model id on disk?".
  public init(probe: @escaping @Sendable (String) -> Bool) {
    self.probe = probe
  }

  public func availability(of model: ModelDescriptor) -> ModelAvailability {
    guard let modelId = model.acervoModelId, !modelId.isEmpty else { return .notManaged }
    return probe(modelId) ? .available : .missing
  }

  /// The descriptors that SwiftAcervo reports missing, in input order.
  public func missingModels(_ models: [ModelDescriptor]) -> [ModelDescriptor] {
    models.filter { availability(of: $0) == .missing }
  }
}
