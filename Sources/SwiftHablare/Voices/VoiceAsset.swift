//
//  VoiceAsset.swift
//  SwiftHablare
//
//  Voices are portable `.vox` assets (R3). Core is the single reader and writer of `.vox`;
//  a plugin touches only its own namespace: `embeddings/<engine>/...` and
//  `manifest.extensions.<engine>`. The layout matches vox-python (`engines.py`
//  `embedding_path`, `providers/gemini.py`) so the Python tools and Swift interoperate.
//

import Foundation
import VoxFormat

// MARK: - VoiceSource

/// One usable thing inside a `.vox`: a server-side handle, a local embedding, or a reference clip.
public struct VoiceSource: Sendable, Hashable {
  public enum Kind: String, Sendable, Hashable, Codable, CaseIterable {
    case serverHandle
    case embedding
    case referenceAudio
  }

  public enum Freshness: Sendable, Hashable {
    case current
    case expiresAt(Date)
    case stale(reason: String)
  }

  /// "google", "qwen3-tts", "elevenlabs".
  public let engine: String
  /// "gemini-3.8-flash-tts", "1.7b". `nil` when the file does not say.
  public let model: String?
  public let kind: Kind
  public let freshness: Freshness
  /// Archive path of the backing entry; `nil` for server handles (they live in the manifest).
  public let path: String?

  public init(
    engine: String, model: String? = nil, kind: Kind, freshness: Freshness = .current,
    path: String? = nil
  ) {
    self.engine = engine
    self.model = model
    self.kind = kind
    self.freshness = freshness
    self.path = path
  }
}

// MARK: - VoiceAsset

/// A `.vox` voice identity. Wraps `VoxFile`.
///
/// `VoxFile` is a reference type, so copies of a `VoiceAsset` share storage. Treat an asset as
/// owned by one writer at a time (the designer's `save(_:into:)` takes it `inout`).
public struct VoiceAsset: @unchecked Sendable {
  private let file: VoxFile

  /// A new, empty asset. `description` needs at least 10 characters to be valid `.vox`.
  public init(name: String, description: String) {
    self.file = VoxFile(name: name, description: description)
  }

  /// Opens a `.vox` archive.
  public init(contentsOf url: URL) throws {
    do {
      self.file = try VoxFile(contentsOf: url)
    } catch {
      throw HablareError.invalidRequest(
        detail: "cannot open .vox at \(url.lastPathComponent): \(error)")
    }
  }

  /// Writes the archive to `url`, replacing any file there.
  public func write(to url: URL) throws {
    do {
      try file.write(to: url)
    } catch {
      throw HablareError.invalidRequest(
        detail: "cannot write .vox to \(url.lastPathComponent): \(error)")
    }
  }

  public var name: String { file.manifest.voice.name }
  public var voiceDescription: String { file.manifest.voice.description }

  /// Archive paths of every entry except `manifest.json`, sorted.
  public var entryPaths: [String] { file.entries.map(\.path).sorted() }

  public func entryData(at path: String) -> Data? { file[path]?.data }

  // MARK: Sources

  /// Everything usable in this asset, as of now.
  public var sources: [VoiceSource] { sources(asOf: Date()) }

  /// Everything usable in this asset, with freshness judged at `now`.
  ///
  /// - `manifest.embeddings` entries become `.referenceAudio` (engine sample audio) or
  ///   `.embedding` (clone prompts and other binaries). They never go stale from a server expiry:
  ///   a stored sample keeps working offline.
  /// - `manifest.reference_audio` entries become `.referenceAudio`.
  /// - `manifest.extensions.<engine>` becomes a `.serverHandle`; its `expire_time` sets freshness.
  public func sources(asOf now: Date) -> [VoiceSource] {
    var result: [VoiceSource] = []
    let manifest = file.manifest

    for (_, entry) in manifest.embeddingEntries ?? [:] {
      let parts = entry.file.split(separator: "/").map(String.init)
      let engine =
        entry.engine ?? (parts.count > 1 && parts[0] == "embeddings" ? parts[1] : "unknown")
      let model = parts.count >= 4 && parts[0] == "embeddings" ? parts[2] : entry.model
      let kind: VoiceSource.Kind =
        Self.isAudio(path: entry.file, format: entry.format) ? .referenceAudio : .embedding
      result.append(VoiceSource(engine: engine, model: model, kind: kind, path: entry.file))
    }
    for reference in manifest.referenceAudio ?? [] {
      result.append(
        VoiceSource(
          engine: reference.engine ?? "vox", model: reference.model, kind: .referenceAudio,
          path: reference.file))
    }
    for (engine, wrapped) in manifest.extensions ?? [:] {
      guard let fields = wrapped.value as? [String: Any] else { continue }
      result.append(
        VoiceSource(
          engine: engine, model: fields["model_id"] as? String, kind: .serverHandle,
          freshness: Self.freshness(ofExpireTime: fields["expire_time"], at: now)))
    }
    return result.sorted {
      ($0.engine, $0.kind.rawValue, $0.model ?? "", $0.path ?? "")
        < ($1.engine, $1.kind.rawValue, $1.model ?? "", $1.path ?? "")
    }
  }

  private static func isAudio(path: String, format: String?) -> Bool {
    let audio: Set<String> = ["wav", "mp3", "flac", "m4a", "aac", "ogg", "caf", "aiff"]
    let ext = (path as NSString).pathExtension.lowercased()
    let stem = ((path as NSString).lastPathComponent as NSString).deletingPathExtension
    return stem == "sample-audio" || audio.contains(ext)
      || audio.contains((format ?? "").lowercased())
  }

  private static func freshness(ofExpireTime raw: Any?, at now: Date) -> VoiceSource.Freshness {
    guard let text = raw as? String, let date = parseTimestamp(text) else { return .current }
    if date <= now {
      return .stale(reason: "server voice expired at \(text)")
    }
    return .expiresAt(date)
  }

  /// Parses RFC 3339 timestamps, including the nanosecond fractions Google returns
  /// (`2027-10-20T23:42:25.396513861Z`), which `ISO8601DateFormatter` rejects.
  static func parseTimestamp(_ text: String) -> Date? {
    let trimmed = text.replacingOccurrences(
      of: #"(\.\d{3})\d+"#, with: "$1", options: .regularExpression)
    let fractional = ISO8601DateFormatter()
    fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = fractional.date(from: trimmed) { return date }
    let plain = ISO8601DateFormatter()
    plain.formatOptions = [.withInternetDateTime]
    return plain.date(from: trimmed)
  }

  // MARK: Path builder (vox-python `engines.embedding_path`)

  /// `embeddings/<engine>/<slug>/[<language>/]<name>`, validated like vox-python.
  public static func embeddingPath(
    engine: String, modelSlug: String, name: String, language: String? = nil
  ) throws -> String {
    var parts = [
      "embeddings", try checkSegment(engine, "engine"), try checkSegment(modelSlug, "model slug"),
    ]
    if let language, !language.isEmpty {
      parts.append(try checkSegment(try checkLanguage(language), "language"))
    }
    parts.append(try checkSegment(name, "file name"))
    return parts.joined(separator: "/")
  }

  /// vox-python `derive_model_slug`: last `/` component, lowercased, sanitized.
  /// `"Qwen/Qwen3-TTS-12Hz-0.6B"` -> `"qwen3-tts-12hz-0.6b"`.
  public static func modelSlug(for model: String) throws -> String {
    let last = model.split(separator: "/").last.map(String.init)?.lowercased() ?? ""
    let slug = last.replacingOccurrences(
      of: #"[^a-z0-9._+-]+"#, with: "-", options: .regularExpression
    ).trimmingCharacters(in: CharacterSet(charactersIn: "-."))
    guard !slug.isEmpty else {
      throw HablareError.invalidRequest(detail: "cannot derive a path slug from model '\(model)'")
    }
    return slug
  }

  private static func checkSegment(_ value: String, _ what: String) throws -> String {
    if value.range(of: #"^[A-Za-z0-9][A-Za-z0-9._+-]*$"#, options: .regularExpression) == nil
      || value == "." || value == ".."
    {
      throw HablareError.invalidRequest(detail: "invalid \(what) path segment '\(value)'")
    }
    return value
  }

  private static func checkLanguage(_ value: String) throws -> String {
    if value.lowercased() == "default" {
      throw HablareError.invalidRequest(
        detail: "'default' is reserved; omit language for the language-neutral entry")
    }
    if value.range(of: #"^[A-Za-z]{2,8}(-[A-Za-z0-9]{1,8})*$"#, options: .regularExpression) == nil
    {
      throw HablareError.invalidRequest(detail: "'\(value)' is not a BCP 47 language tag")
    }
    return value
  }

  // MARK: Namespaced writes

  /// Stores an engine binary (clone prompt, safetensors, ...) and its `embeddings` manifest entry
  /// at `embeddings/<engine>/<slug>/[<language>/]<name>`. Returns the entry path.
  @discardableResult
  public mutating func addEmbedding(
    _ data: Data, engine: String, model: String, name: String = "clone-prompt.bin",
    modelSlug: String? = nil, language: String? = nil, format: String? = nil,
    description: String? = nil
  ) throws -> String {
    let slug = try modelSlug ?? Self.modelSlug(for: model)
    let path = try Self.embeddingPath(
      engine: engine, modelSlug: slug, name: name, language: language)
    var metadata: [String: Any] = ["model": model, "engine": engine]
    let ext = (name as NSString).pathExtension.lowercased()
    if let format = format ?? (ext.isEmpty ? nil : ext) { metadata["format"] = format }
    if let description { metadata["description"] = description }
    if let language, !language.isEmpty { metadata["language"] = language }
    try addEntry(data, at: path, forEngine: engine, metadata: metadata)
    return path
  }

  /// Stores engine-generated sample audio at `.../sample-audio.wav` (language-neutral unless
  /// `language` is given). For Google this is
  /// `embeddings/google/gemini-3.8-flash-tts/sample-audio.wav`.
  @discardableResult
  public mutating func addSampleAudio(
    _ wav: Data, engine: String, model: String, modelSlug: String? = nil,
    language: String? = nil, description: String? = nil
  ) throws -> String {
    try addEmbedding(
      wav, engine: engine, model: model, name: "sample-audio.wav", modelSlug: modelSlug,
      language: language, format: "wav",
      description: description ?? "Engine-generated voice sample (\(model))")
  }

  /// Low-level write. `path` must sit under `embeddings/<engine>/`; anything else (another
  /// engine's folder, `reference/`, `manifest.json`, `..`) throws `invalidRequest`.
  /// `metadata` must include `model` (VoxFormat requires it for embeddings).
  public mutating func addEntry(
    _ data: Data, at path: String, forEngine engine: String, metadata: [String: Any]
  ) throws {
    try Self.requireNamespace(path: path, engine: engine)
    var metadata = metadata
    metadata["engine"] = engine
    guard metadata["model"] is String else {
      throw HablareError.invalidRequest(
        detail: "embedding '\(path)' needs a 'model' metadata value")
    }
    do {
      try file.add(data, at: path, metadata: metadata)
    } catch {
      throw HablareError.invalidRequest(detail: "cannot add '\(path)': \(error)")
    }
  }

  /// Removes an entry from the calling engine's namespace. Returns whether one existed.
  @discardableResult
  public mutating func removeEntry(at path: String, forEngine engine: String) throws -> Bool {
    try Self.requireNamespace(path: path, engine: engine)
    return file.remove(at: path) != nil
  }

  /// Replaces `manifest.extensions.<engine>`. Values must be JSON types (String, Int, Double,
  /// Bool, arrays, dictionaries). Order is not preserved by VoxFormat 0.4.1's `[String: AnyCodable]`.
  public mutating func setExtension(_ fields: [String: Any], forEngine engine: String) throws {
    _ = try Self.checkSegment(engine, "engine")
    var extensions = file.manifest.extensions ?? [:]
    extensions[engine] = AnyCodable(fields)
    file.manifest.extensions = extensions
  }

  /// `manifest.extensions.<engine>`, if present.
  public func extensionFields(forEngine engine: String) -> [String: Any]? {
    file.manifest.extensions?[engine]?.value as? [String: Any]
  }

  /// Removes `manifest.extensions.<engine>`. Returns whether one existed.
  @discardableResult
  public mutating func removeExtension(forEngine engine: String) throws -> Bool {
    _ = try Self.checkSegment(engine, "engine")
    guard var extensions = file.manifest.extensions, extensions.removeValue(forKey: engine) != nil
    else { return false }
    file.manifest.extensions = extensions.isEmpty ? nil : extensions
    return true
  }

  /// vox-python's Google extension key order (`providers/gemini.py` `EXTENSION_ORDER`).
  public static let googleExtensionOrder = [
    "voice_id", "model_id", "type", "display_name", "gender", "language_code",
    "prompted_input", "created", "expire_time", "refreshed",
  ]

  private static func requireNamespace(path: String, engine: String) throws {
    _ = try checkSegment(engine, "engine")
    let parts = path.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
    let inside =
      parts.count >= 4 && parts[0] == "embeddings" && parts[1] == engine
      && !parts.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." })
    guard inside else {
      throw HablareError.invalidRequest(
        detail: "engine '\(engine)' may only write under embeddings/\(engine)/, not '\(path)'")
    }
  }
}
