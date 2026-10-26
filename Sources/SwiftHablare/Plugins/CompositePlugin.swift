//
//  CompositePlugin.swift
//  SwiftHablare
//
//  Hybrid composition (R11): one plugin designs the voice, another renders every line from the
//  sample the design left in the `.vox`. The composite has no engine code of its own; it
//  resolves both components through `PluginContext.registry`.
//

import Foundation
import OSLog

/// A hybrid plugin: `Designer` supplies the design role, `Synthesizer` the synthesis role.
///
/// Rendering never calls the designer. The synthesizer reads the `.vox` named by
/// `SpeechRequest.voice` (`.asset(URL)`) and picks its source with
/// ``VoiceSynthesizer/preferredSource(in:asOf:)``, the same selection ``readiness(for:)`` reports.
///
/// Register it with ``PluginRegistry/register(composite:)`` so the pairing is validated.
public struct CompositePlugin<Designer: HablarePlugin, Synthesizer: HablarePlugin>: HablarePlugin {
  /// `"<designer id>+<synthesizer id>"`.
  public static var id: String { "\(Designer.id)+\(Synthesizer.id)" }
  public static var displayName: String {
    "\(Designer.displayName) + \(Synthesizer.displayName)"
  }
  public static var kind: PluginKind { .hybrid }
  /// The union of both components' requirements (R6), deduplicated by Keychain account.
  public static var credentials: [CredentialRequirement] {
    var seen = Set<String>()
    return (Designer.credentials + Synthesizer.credentials).filter {
      seen.insert($0.keychainAccount).inserted
    }
  }
  /// The synthesizer's local models.
  public static var models: [ModelDescriptor] { Synthesizer.models }
  /// The synthesizer's schema; the composite's configuration is passed on to the synthesizer.
  public static var settingsSchema: SettingsSchema { Synthesizer.settingsSchema }

  public let context: PluginContext
  /// The resolved designer component, or `nil` when it is not registered.
  public let designerPlugin: Designer?
  /// The resolved synthesizer component, or `nil` when it is not registered.
  public let synthesizerPlugin: Synthesizer?
  private let compositeSynthesizer: CompositeSynthesizer?

  /// Resolves both components from `context.registry`. A component that is not registered is
  /// left `nil` and named by ``status()``. Throws `invalidRequest` when a registered component
  /// has the wrong type or the pairing is invalid.
  public init(context: PluginContext) async throws {
    self.context = context
    let registry = context.registry
    self.designerPlugin = try await Self.resolve(Designer.self, configuration: .empty, in: registry)
    self.synthesizerPlugin = try await Self.resolve(
      Synthesizer.self, configuration: context.configuration, in: registry)
    if let designer = designerPlugin?.designer, let synthesizer = synthesizerPlugin?.synthesizer {
      try registry.validatePairing(designer: designer, synthesizer: synthesizer)
    }
    self.compositeSynthesizer = synthesizerPlugin?.synthesizer.map(CompositeSynthesizer.init)
  }

  private static func resolve<Component: HablarePlugin>(
    _ type: Component.Type, configuration: PluginConfiguration, in registry: PluginRegistry
  ) async throws -> Component? {
    guard await registry.isRegistered(Component.id) else {
      Logger.composite.info(
        "\(Self.id, privacy: .public): component '\(Component.id, privacy: .public)' is not registered"
      )
      return nil
    }
    let resolved = try await registry.plugin(id: Component.id, configuration: configuration)
    guard let typed = resolved as? Component else {
      throw HablareError.invalidRequest(
        detail:
          "plugin '\(Component.id)' is registered with a different type than \(Self.id) expects"
      )
    }
    return typed
  }

  public var designer: (any VoiceDesigner)? { designerPlugin?.designer }
  public var synthesizer: (any VoiceSynthesizer)? { compositeSynthesizer }

  // MARK: Status

  /// Names a missing component first. Otherwise reports the synthesizer's status alone: the
  /// design credential is never needed to render from a sample already in a `.vox` (R6).
  public func status() async -> PluginStatus {
    if let missing = missingComponents() { return missing }
    return await synthesisStatus()
  }

  /// Status for rendering `voice`. When the `.vox` already holds a source the synthesizer
  /// consumes, only the synthesizer's status matters. When it does not, the voice must be
  /// designed first, so the designer's status (e.g. its credential) applies.
  public func status(for voice: VoiceReference) async -> PluginStatus {
    if let missing = missingComponents() { return missing }
    guard let compositeSynthesizer else { return .unavailable(reason: "no synthesizer role") }
    if case .unsupported = await compositeSynthesizer.readiness(for: voice) {
      return await designStatus()
    }
    return await synthesisStatus()
  }

  /// The synthesizer component's status (its own credentials and models only).
  public func synthesisStatus() async -> PluginStatus {
    guard let synthesizerPlugin else { return Self.missing(Synthesizer.id, role: "synthesizer") }
    guard synthesizerPlugin.synthesizer != nil else {
      return .unavailable(reason: "plugin '\(Synthesizer.id)' has no synthesizer role")
    }
    return await synthesizerPlugin.status()
  }

  /// The designer component's status (its own credentials and models only).
  public func designStatus() async -> PluginStatus {
    guard let designerPlugin else { return Self.missing(Designer.id, role: "designer") }
    guard designerPlugin.designer != nil else {
      return .unavailable(reason: "plugin '\(Designer.id)' has no designer role")
    }
    return await designerPlugin.status()
  }

  private func missingComponents() -> PluginStatus? {
    var missing: [String] = []
    if designerPlugin == nil { missing.append("designer '\(Designer.id)'") }
    if synthesizerPlugin == nil { missing.append("synthesizer '\(Synthesizer.id)'") }
    guard !missing.isEmpty else { return nil }
    return .unavailable(
      reason: "\(Self.id) needs component plugin \(missing.joined(separator: " and ")) registered")
  }

  private static func missing(_ id: String, role: String) -> PluginStatus {
    .unavailable(reason: "\(Self.id) needs component plugin \(role) '\(id)' registered")
  }
}

// MARK: - Synthesis role

/// The composite's synthesis role: forwards to the synthesizer component, and reports the
/// `.vox` source it will use following the component's preference list (R3).
struct CompositeSynthesizer: StreamingVoiceSynthesizer {
  let inner: any VoiceSynthesizer

  var capabilities: SynthesisCapabilities { inner.capabilities }
  var limits: SynthesisLimits { inner.limits }
  var nativeFormats: [AudioFormat] { inner.nativeFormats }
  var maxConcurrentRequests: Int { inner.maxConcurrentRequests }
  var consumedSources: [VoiceSourcePattern] { inner.consumedSources }

  /// For a `.vox` voice: the preferred usable source (stale server handles skipped), or
  /// `.unsupported` when there is none. The component's own readiness still decides between
  /// `.ready` and `.needsPreparation`, and can veto with `.unsupported`.
  func readiness(for voice: VoiceReference) async -> VoiceReadiness {
    guard case .asset = voice else { return await inner.readiness(for: voice) }
    let selected = inner.sourceReadiness(for: voice)
    guard let source = selected.source else { return selected }
    switch await inner.readiness(for: voice) {
    case .ready: return .ready(source: source)
    case .needsPreparation: return .needsPreparation(source: source)
    case .unsupported(let reason): return .unsupported(reason: reason)
    }
  }

  func prepare(_ voice: VoiceReference) async throws { try await inner.prepare(voice) }
  func release(_ voice: VoiceReference) async { await inner.release(voice) }

  func synthesize(_ request: SpeechRequest) async throws -> GeneratedAudio {
    try await inner.synthesize(request)
  }

  func synthesize(
    _ request: SpeechRequest,
    progress: @escaping @Sendable (SynthesisProgress) -> Void
  ) async throws -> GeneratedAudio {
    try await inner.synthesize(request, progress: progress)
  }

  func cacheKey(for request: SpeechRequest) -> String? { inner.cacheKey(for: request) }
  func estimateCost(_ request: SpeechRequest) -> CostEstimate? { inner.estimateCost(request) }

  /// Forwards to a streaming component; otherwise yields the whole take as one final chunk.
  func stream(_ request: SpeechRequest) -> AsyncThrowingStream<AudioChunk, Error> {
    if let streaming = inner as? any StreamingVoiceSynthesizer {
      return streaming.stream(request)
    }
    let inner = self.inner
    return AsyncThrowingStream { continuation in
      let task = Task {
        do {
          let audio = try await inner.synthesize(request)
          continuation.yield(
            AudioChunk(
              data: audio.data, format: audio.format, duration: audio.duration, isFinal: true))
          continuation.finish()
        } catch {
          continuation.finish(throwing: error)
        }
      }
      continuation.onTermination = { _ in task.cancel() }
    }
  }
}

// MARK: - Registration

extension PluginRegistry {
  /// Registers a composite after validating its pairing (R11): every source the designer
  /// produces must be consumed by the synthesizer, otherwise this throws `invalidRequest` and
  /// nothing is registered. Register the components first; a component that is not registered
  /// yet is not an error here, and the composite's `status()` names it.
  public func register<Designer, Synthesizer>(
    composite type: CompositePlugin<Designer, Synthesizer>.Type
  ) async throws {
    if isRegistered(Designer.id), isRegistered(Synthesizer.id) {
      try await validatePairing(designerId: Designer.id, synthesizerId: Synthesizer.id)
    }
    register(type)
  }
}

extension Logger {
  fileprivate static let composite = Logger(
    subsystem: "io.intrusive-memory.SwiftHablare", category: "CompositePlugin")
}
