//
//  VoiceURI.swift
//  SwiftHablare
//
//  Voice URI for portable voice references
//  Format: <pluginId>://<voiceId>?lang=<languageCode>   (catalog voice)
//          asset://<absolute file path>?lang=<languageCode>   (voice asset on disk)
//

import Foundation
import SwiftCompartido

/// Voice URI for portable voice references across voice plugins
///
/// Catalog form: `<pluginId>://<voiceId>?lang=<languageCode>`
///
/// Asset form: `asset://<absolute file path>?lang=<languageCode>`, for example
/// `asset:///Users/me/Voices/narrator.vox?lang=en`. The path is percent-encoded, so a
/// file URL round-trips exactly. `asset` is a reserved scheme: a plugin cannot use it as
/// its id. A non-file asset URL is carried whole in a `url` query item
/// (`asset:///?url=<percent-encoded URL>`).
///
/// ## Examples
///
/// ```swift
/// // Create from components
/// let uri = VoiceURI(
///     providerId: "apple",
///     voiceId: "com.apple.voice.compact.en-US.Samantha",
///     languageCode: "en"
/// )
/// // => "apple://com.apple.voice.compact.en-US.Samantha?lang=en"
///
/// // External provider voice (e.g. SwiftHablareOnce)
/// let uri2 = VoiceURI(
///     providerId: "elevenlabs",
///     voiceId: "21m00Tcm4TlvDq8ikWAM",
///     languageCode: "en"
/// )
/// // => "elevenlabs://21m00Tcm4TlvDq8ikWAM?lang=en"
///
/// // Parse from string
/// let uri3 = VoiceURI(uriString: "apple://voice-id?lang=es")
///
/// // A voice asset on disk
/// let asset = VoiceURI.asset(URL(fileURLWithPath: "/Users/me/Voices/narrator.vox"))
/// // => "asset:///Users/me/Voices/narrator.vox"
///
/// // Convert to and from the 7.0 `VoiceReference`
/// let reference = uri.voiceReference          // .catalog(pluginId: "apple", voiceId: ...)
/// let back = VoiceURI(reference, languageCode: "en")
/// ```
public struct VoiceURI: Codable, Hashable, Sendable {

  /// The reserved scheme of the asset form.
  public static let assetScheme = "asset"

  /// Plugin identifier (lowercase, e.g., "apple", "elevenlabs"); `"asset"` for an asset URI.
  public let providerId: String

  /// Voice identifier (case-sensitive, plugin-specific). For an asset URI, the file path
  /// (or, for a non-file URL, the URL's absolute string).
  public let voiceId: String

  /// Language code (optional, e.g., "en", "es", "fr")
  public let languageCode: String?

  // MARK: - Initialization

  /// Create a VoiceURI from components
  ///
  /// - Parameters:
  ///   - providerId: Provider identifier (will be lowercased)
  ///   - voiceId: Voice identifier (case-sensitive)
  ///   - languageCode: Language code (optional)
  public init(providerId: String, voiceId: String, languageCode: String? = nil) {
    self.providerId = providerId.lowercased()  // Normalize provider ID to lowercase
    self.voiceId = voiceId  // Keep voice ID case-sensitive
    self.languageCode = languageCode
  }

  /// Create a VoiceURI from a Voice model
  ///
  /// - Parameters:
  ///   - voice: Voice model from a provider
  ///   - languageCode: Language code (optional, defaults to voice's language)
  public init(from voice: Voice, languageCode: String? = nil) {
    self.providerId = voice.providerId
    self.voiceId = voice.id
    self.languageCode = languageCode ?? voice.language
  }

  /// Create the asset form for a voice asset at `url`.
  ///
  /// - Parameters:
  ///   - url: The voice asset (typically a `.vox` bundle file URL)
  ///   - languageCode: Language code (optional)
  public static func asset(_ url: URL, languageCode: String? = nil) -> VoiceURI {
    VoiceURI(
      providerId: assetScheme,
      voiceId: url.isFileURL ? url.path : url.absoluteString,
      languageCode: languageCode)
  }

  /// Create a VoiceURI from a ``VoiceReference``.
  ///
  /// `.catalog(pluginId:voiceId:)` becomes the catalog form; `.asset(URL)` becomes the
  /// asset form.
  public init(_ reference: VoiceReference, languageCode: String? = nil) {
    switch reference {
    case .catalog(let pluginId, let voiceId):
      self.init(providerId: pluginId, voiceId: voiceId, languageCode: languageCode)
    case .asset(let url):
      self = VoiceURI.asset(url, languageCode: languageCode)
    }
  }

  /// Whether this URI names a voice asset on disk rather than a catalog voice.
  public var isAsset: Bool { providerId == Self.assetScheme }

  /// The asset URL for an asset URI; `nil` for a catalog URI.
  public var assetURL: URL? {
    guard isAsset else { return nil }
    if voiceId.contains("://") { return URL(string: voiceId) }
    return URL(fileURLWithPath: voiceId)
  }

  /// This URI as a ``VoiceReference``.
  public var voiceReference: VoiceReference {
    if let url = assetURL { return .asset(url) }
    return .catalog(pluginId: providerId, voiceId: voiceId)
  }

  /// Parse a VoiceURI from a string
  ///
  /// Parses URIs in the format: `<providerId>://<voiceId>?lang=<languageCode>`
  ///
  /// ## Examples
  ///
  /// ```swift
  /// let uri1 = VoiceURI(uriString: "apple://voice-id?lang=en")
  /// let uri2 = VoiceURI(uriString: "elevenlabs://21m00Tcm4TlvDq8ikWAM")
  /// ```
  ///
  /// - Parameter uriString: URI string to parse
  /// - Returns: Parsed VoiceURI, or nil if invalid
  public init?(uriString: String) {
    if let components = URLComponents(string: uriString),
      components.scheme?.lowercased() == Self.assetScheme
    {
      // Asset form: asset://<path> or asset:///?url=<url>
      let items = components.queryItems ?? []
      let language = items.first(where: { $0.name == "lang" })?.value
      if let whole = items.first(where: { $0.name == "url" })?.value, !whole.isEmpty {
        self.init(providerId: Self.assetScheme, voiceId: whole, languageCode: language)
        return
      }
      let path = components.path
      guard path.hasPrefix("/"), path.count > 1 else { return nil }
      self.init(providerId: Self.assetScheme, voiceId: path, languageCode: language)
      return
    }

    guard let url = URL(string: uriString),
      let scheme = url.scheme,
      !scheme.isEmpty,
      let host = url.host,
      !host.isEmpty
    else {
      return nil
    }

    // Parse query parameters for language code
    var language: String?
    if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
      let langItem = components.queryItems?.first(where: { $0.name == "lang" })
    {
      language = langItem.value
    }
    self.init(providerId: scheme, voiceId: host, languageCode: language)
  }

  // MARK: - Default Voice

  /// Create a default voice URI
  ///
  /// Creates a URI pointing to the system's default voice provider and voice.
  /// Uses Apple provider with system language as default.
  ///
  /// - Returns: Default VoiceURI for system voice
  public static func defaultVoice() -> VoiceURI {
    return VoiceURI(
      providerId: "apple",
      voiceId: "com.apple.voice.compact.\(LanguageCodeResolver.systemLanguageCode)-US.Default",
      languageCode: LanguageCodeResolver.systemLanguageCode
    )
  }

  /// Check if this URI represents the default voice
  ///
  /// - Returns: True if this is a default voice URI
  public var isDefaultVoice: Bool {
    return providerId == "apple" && voiceId.hasSuffix(".Default")
  }

  // MARK: - String Conversion

  /// Convert to URI string
  ///
  /// Generates the canonical URI string representation using URLComponents
  /// for proper percent-encoding of special characters.
  ///
  /// ## Format
  ///
  /// - Without language: `<providerId>://<voiceId>`
  /// - With language: `<providerId>://<voiceId>?lang=<languageCode>`
  ///
  /// - Returns: URI string with properly encoded components
  public var uriString: String {
    var components = URLComponents()
    components.scheme = providerId

    if isAsset {
      components.host = ""
      var items: [URLQueryItem] = []
      if voiceId.contains("://") {
        components.path = "/"
        items.append(URLQueryItem(name: "url", value: voiceId))
      } else {
        components.path = voiceId
      }
      if let lang = languageCode { items.append(URLQueryItem(name: "lang", value: lang)) }
      if !items.isEmpty { components.queryItems = items }
      return components.string ?? "\(providerId)://\(voiceId)"
    }

    components.host = voiceId

    if let lang = languageCode {
      components.queryItems = [URLQueryItem(name: "lang", value: lang)]
    }

    return components.string ?? "\(providerId)://\(voiceId)"
  }

  /// CustomStringConvertible conformance
  public var description: String {
    return uriString
  }

  // MARK: - Availability

  /// Check whether this voice can be synthesized now.
  ///
  /// Resolves the plugin through `registry` and asks its synthesizer for readiness.
  /// An asset URI needs `pluginId`, the plugin that will synthesize it.
  ///
  /// - Parameters:
  ///   - registry: The plugin registry to resolve through
  ///   - pluginId: The synthesizing plugin; required for an asset URI, ignored otherwise
  /// - Returns: `false` when the plugin is unknown, has no synthesizer, or reports the voice
  ///   unsupported
  public func isAvailable(in registry: PluginRegistry, pluginId: String? = nil) async -> Bool {
    do {
      let synthesizer = try await registry.synthesizer(for: voiceReference, pluginId: pluginId)
      if case .unsupported = await synthesizer.readiness(for: voiceReference) { return false }
      return true
    } catch {
      return false
    }
  }

  // MARK: - Codable

  enum CodingKeys: String, CodingKey {
    case providerId
    case voiceId
    case languageCode
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.providerId = try container.decode(String.self, forKey: .providerId).lowercased()
    self.voiceId = try container.decode(String.self, forKey: .voiceId)
    self.languageCode = try container.decodeIfPresent(String.self, forKey: .languageCode)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(providerId, forKey: .providerId)
    try container.encode(voiceId, forKey: .voiceId)
    try container.encodeIfPresent(languageCode, forKey: .languageCode)
  }
}
