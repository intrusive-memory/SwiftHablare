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
/// into spoken audio using voice providers (Apple TTS and ElevenLabs).
///
/// ## Features
///
/// - Two voice providers: Apple TTS (built-in) and ElevenLabs (API-based)
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
/// let schema = Schema([VoiceCacheModel.self, TypedDataStorage.self])
/// let container = try ModelContainer(for: schema)
/// let modelContext = ModelContext(container)
///
/// // 2. Create generation service
/// let service = GenerationService(modelContext: modelContext)
///
/// // 3. Generate audio for an element
/// let result = try await service.generate(
///     forElement: element,
///     providerId: "elevenlabs",
///     voiceId: "voice123",
///     voiceName: "Rachel"
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
/// The only SwiftData model is VoiceCacheModel for caching provider voices.
///
/// Generated audio is saved using TypedDataStorage from SwiftCompartido,
/// which provides:
/// - Automatic file-based storage for large audio files
/// - CloudKit sync support
/// - Relationship to GuionElementModel
///
/// ## Thread Safety
///
/// All generation happens on background threads using Swift actors:
/// - GenerationService (actor) coordinates generation
/// - VoiceProvider generates audio off the main thread
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
    public static let version = "5.2.0"

    /// Library name
    public static let name = "SwiftHablare"

    private init() {}
}
