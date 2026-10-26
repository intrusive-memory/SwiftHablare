//
//  ModelDescriptor.swift
//  SwiftHablare
//
//  Static description of a model a plugin can run (R1, R9). Hosts render model pickers and
//  download prompts from this plus SwiftAcervo's availability state; plugins ship no views.
//

import Foundation

public struct ModelDescriptor: Sendable, Hashable {
  /// Where the model runs.
  public enum Kind: String, Sendable, Hashable, Codable {
    case local
    case cloud
  }

  /// Stable id within the plugin, e.g. "1.7b" or "gemini-3.8-flash-tts".
  public var id: String
  public var displayName: String
  public var kind: Kind
  /// BCP-47 language codes the model supports. Empty means unspecified.
  public var languages: [String]
  public var capabilities: SynthesisCapabilities
  /// Approximate download size, for local models.
  public var approximateBytes: Int64?
  /// Approximate memory needed while resident, for local models.
  public var minimumMemoryBytes: Int64?
  /// The SwiftAcervo model id ("org/repo") for local models (R9). Availability comes from
  /// ``LocalModelAvailability``; plugins never implement their own downloader or cache.
  public var acervoModelId: String?

  public init(
    id: String,
    displayName: String? = nil,
    kind: Kind = .local,
    languages: [String] = [],
    capabilities: SynthesisCapabilities = [],
    approximateBytes: Int64? = nil,
    minimumMemoryBytes: Int64? = nil,
    acervoModelId: String? = nil
  ) {
    self.id = id
    self.displayName = displayName ?? id
    self.kind = kind
    self.languages = languages
    self.capabilities = capabilities
    self.approximateBytes = approximateBytes
    self.minimumMemoryBytes = minimumMemoryBytes
    self.acervoModelId = acervoModelId
  }
}
