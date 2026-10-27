//
//  SpeakableItem.swift
//  SwiftHablare
//
//  Protocol for any type that can be converted to speech
//

import Foundation

// MARK: - Language Code Utilities

/// Get the system's current language code
///
/// Returns the user's preferred language code (e.g., "en", "es", "fr").
/// Falls back to "en" if the language code cannot be determined.
public func systemLanguageCode() -> String {
  return LanguageCodeResolver.systemLanguageCode
}

/// A protocol that defines the requirements for any type that can be spoken.
///
/// Conforming types provide a ``VoiceReference`` (a catalog voice or a voice asset), the
/// text to speak, and optionally a language code. The synthesizer is resolved through a
/// ``PluginRegistry``, so any object in your application becomes speakable by implementing
/// these requirements.
///
/// ## Example Usage
///
/// ```swift
/// struct Message: SpeakableItem {
///     let sender: String
///     let content: String
///     let voice: VoiceReference
///
///     var textToSpeak: String {
///         "\(sender) says: \(content)"
///     }
/// }
///
/// // Generate audio
/// let message = Message(
///     sender: "Alice",
///     content: "Hello, world!",
///     voice: .catalog(pluginId: "apple", voiceId: "com.apple.voice.enhanced.en-US.Samantha")
/// )
///
/// let audio = try await message.speak()   // GeneratedAudio
/// ```
///
/// ## Design Philosophy
///
/// SwiftHablaré follows a protocol-oriented approach where any type can become
/// speakable by conforming to `SpeakableItem`. This allows:
///
/// - **Flexibility**: Any struct, class, or enum can be spoken
/// - **Reusability**: Voice configuration travels with the object
/// - **Testability**: Resolve through a test registry holding `FakeSynthesizerPlugin`
/// - **Composability**: Combine with other protocols as needed
///
/// ## Thread Safety
///
/// The `speak()` method is async and thread-safe. It uses the resolved plugin's own
/// concurrency model.
///
public protocol SpeakableItem {
  /// The voice to speak with
  ///
  /// - `.catalog(pluginId:voiceId:)` names a voice in a plugin's catalog. For Apple the
  ///   `voiceId` is an `AVSpeechSynthesisVoice` identifier.
  /// - `.asset(URL)` names a voice asset (for example a `.vox` bundle). The synthesizing
  ///   plugin is then supplied to ``speak(using:pluginId:)``.
  ///
  /// ## Example
  /// ```swift
  /// // Apple voice
  /// voice = .catalog(pluginId: "apple", voiceId: "com.apple.voice.enhanced.en-US.Samantha")
  ///
  /// // Voice asset
  /// voice = .asset(URL(fileURLWithPath: "/Voices/narrator.vox"))
  /// ```
  var voice: VoiceReference { get }

  /// The text that should be spoken
  ///
  /// This can be computed based on the object's properties, allowing
  /// you to compose speech from multiple fields or apply formatting.
  ///
  /// ## Example
  /// ```swift
  /// struct Article: SpeakableItem {
  ///     let title: String
  ///     let author: String
  ///     let content: String
  ///     let voice: VoiceReference
  ///
  ///     var textToSpeak: String {
  ///         "\(title), by \(author). \(content)"
  ///     }
  /// }
  /// ```
  var textToSpeak: String { get }

  /// The language code for speech synthesis
  ///
  /// This is the ISO 639-1 language code (e.g., "en", "es", "fr") used
  /// for voice selection and generation. Defaults to the system's current
  /// language if not explicitly provided.
  ///
  /// ## Example
  /// ```swift
  /// // Use system language (default)
  /// var languageCode: String { systemLanguageCode() }
  ///
  /// // Use specific language
  /// var languageCode: String { "es" }
  /// ```
  var languageCode: String { get }
}

// MARK: - Default Implementation

extension SpeakableItem {
  /// Default language code returns the system's current language
  public var languageCode: String {
    systemLanguageCode()
  }

  /// The ``SpeechRequest`` this item produces.
  public var speechRequest: SpeechRequest {
    SpeechRequest(text: textToSpeak, voice: voice, languageCode: languageCode)
  }
}

// MARK: - Plugin Resolution

extension PluginRegistry {
  /// The synthesizer that speaks `voice`.
  ///
  /// A catalog voice resolves to the plugin named in the reference. A voice asset names no
  /// plugin, so `pluginId` must say which one synthesizes it.
  ///
  /// - Throws: `HablareError.invalidRequest` when the plugin is not registered, has no
  ///   synthesizer role, or an asset voice came without a `pluginId`.
  public func synthesizer(
    for voice: VoiceReference, pluginId: String? = nil
  ) async throws -> any VoiceSynthesizer {
    let id: String
    switch voice {
    case .catalog(let catalogPluginId, _):
      id = pluginId ?? catalogPluginId
    case .asset:
      guard let pluginId else {
        throw HablareError.invalidRequest(
          detail: "a voice asset needs the id of the plugin that synthesizes it")
      }
      id = pluginId
    }
    let resolved = try await plugin(id: id)
    guard let synthesizer = resolved.synthesizer else {
      throw HablareError.invalidRequest(detail: "plugin '\(id)' has no synthesizer role")
    }
    return synthesizer
  }
}

// MARK: - Convenience Methods

extension SpeakableItem {
  /// Generate audio for this speakable item
  ///
  /// Resolves the synthesizer for ``voice`` through `registry` and synthesizes
  /// ``textToSpeak`` in ``languageCode``.
  ///
  /// - Parameters:
  ///   - registry: The plugin registry to resolve through (default: the shared one)
  ///   - pluginId: The synthesizing plugin; required when ``voice`` is an asset
  /// - Returns: The generated audio, with its true format and duration
  /// - Throws: `HablareError` if the plugin cannot be resolved or synthesis fails
  ///
  /// ## Example
  /// ```swift
  /// let item = MyItem(...)
  /// let audio = try await item.speak()
  /// // Play or save audio.data (audio.format says how it is encoded)
  /// ```
  ///
  /// ## Thread Safety
  /// This method is async and thread-safe. Multiple items can be spoken
  /// concurrently without data races.
  public func speak(
    using registry: PluginRegistry = .default, pluginId: String? = nil
  ) async throws -> GeneratedAudio {
    let synthesizer = try await registry.synthesizer(for: voice, pluginId: pluginId)
    return try await synthesizer.synthesize(speechRequest)
  }

  /// Check if the specified voice is available
  ///
  /// - Returns: `true` unless the plugin cannot be resolved or reports the voice unsupported
  ///
  /// ## Example
  /// ```swift
  /// if await item.isVoiceAvailable() {
  ///     let audio = try await item.speak()
  /// } else {
  ///     // choose another voice
  /// }
  /// ```
  public func isVoiceAvailable(
    in registry: PluginRegistry = .default, pluginId: String? = nil
  ) async -> Bool {
    guard let synthesizer = try? await registry.synthesizer(for: voice, pluginId: pluginId)
    else { return false }
    if case .unsupported = await synthesizer.readiness(for: voice) { return false }
    return true
  }
}

// MARK: - Batch Operations

extension Collection where Element: SpeakableItem {
  /// Speak all items in the collection sequentially
  ///
  /// This generates audio for each item in order, returning an array
  /// of generated audio in the same order as the items.
  ///
  /// - Returns: Array of generated audio for each item
  /// - Throws: `HablareError` if any generation fails
  ///
  /// ## Example
  /// ```swift
  /// let messages: [Message] = [...]
  /// let audioFiles = try await messages.speakAll()
  /// // Play each audio file in sequence
  /// ```
  ///
  /// ## Performance Note
  /// Items are spoken sequentially. For parallel generation, use
  /// `TaskGroup` or similar concurrency patterns.
  public func speakAll(
    using registry: PluginRegistry = .default, pluginId: String? = nil
  ) async throws -> [GeneratedAudio] {
    var results: [GeneratedAudio] = []
    for item in self {
      let audio = try await item.speak(using: registry, pluginId: pluginId)
      results.append(audio)
    }
    return results
  }
}
