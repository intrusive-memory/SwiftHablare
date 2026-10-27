//
//  SwiftHablare.swift
//  SwiftHablare
//
//  Main entry point and public API for SwiftHablare
//

import Foundation

/// SwiftHablare - Audio generation library for screenplays
///
/// SwiftHablare focuses purely on generation - converting screenplay elements
/// into spoken audio through pluggable `HablarePlugin` types resolved by a
/// `PluginRegistry`. The on-device `ApplePlugin` ships built-in; other plugins
/// (e.g. `SwiftHablareOnce` for ElevenLabs) are added by depending on companion packages.
///
/// ## Features
///
/// - Built-in `ApplePlugin`; external plugins via `PluginRegistry`
/// - Voice caching to reduce API calls
/// - Thread-safe generation using actor isolation
/// - Saves audio to TypedDataStorage from SwiftCompartido
/// - Links generated audio to GuionElementModel instances
///
/// ## Usage
///
/// ```swift
/// import SwiftHablare
/// import SwiftCompartido
/// import SwiftData
///
/// // 1. Create SwiftData model context
/// let schema = Schema([TypedDataStorage.self])
/// let container = try ModelContainer(for: schema)
/// let modelContext = ModelContext(container)
///
/// // 2. Create generation service
/// let service = GenerationService()
///
/// // 3. Generate audio for an element
/// let voice = VoiceReference.catalog(
///     pluginId: "apple", voiceId: "com.apple.voice.compact.en-US.Samantha")
/// let result = try await service.generate(
///     forElement: element,
///     voice: voice,
///     voiceName: "Samantha"
/// )
///
/// // 4. Save to SwiftData (on main thread)
/// await MainActor.run {
///     let audioRecord = result.toTypedDataStorage()
///     element.generatedContent?.append(audioRecord)
///     modelContext.insert(audioRecord)
///     try? modelContext.save()
/// }
/// ```
///
/// ## Architecture
///
/// SwiftHablare has no UI components - it's purely a generation library.
///
/// Generated audio is saved using TypedDataStorage from SwiftCompartido,
/// which provides:
/// - Automatic file-based storage for large audio files
/// - Relationship to GuionElementModel
///
/// ## Thread Safety
///
/// All generation happens on background threads using Swift actors:
/// - GenerationService (actor) coordinates generation
/// - Plugins synthesize audio off the main thread
/// - Results are Sendable and can be transferred to main thread
/// - SwiftData saves happen on @MainActor
///
/// ## Dependencies
///
/// SwiftHablare depends on SwiftCompartido for:
/// - GuionElementModel (screenplay elements)
/// - TypedDataStorage (audio storage)
/// - SwiftData model context
///
/// There are NO circular dependencies - SwiftCompartido does not depend on SwiftHablare.
public struct SwiftHablare {
  /// Library version
  public static let version = "7.0.0-dev"

  /// Library name
  public static let name = "SwiftHablare"

  private init() {}
}
