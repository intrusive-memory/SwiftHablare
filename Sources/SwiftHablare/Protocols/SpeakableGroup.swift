//
//  SpeakableGroup.swift
//  SwiftHablare
//
//  Protocol for groups of SpeakableItems that can be batch generated
//

import Foundation

/// A protocol for representing a group of SpeakableItems that can be generated together
///
/// `SpeakableGroup` enables batch audio generation for collections of related speakable content.
/// Any type can conform to this protocol to provide grouped generation capabilities.
///
/// ## Overview
///
/// While `SpeakableItem` represents a single piece of speakable content, `SpeakableGroup`
/// represents a collection of items that should be processed together. This is useful for:
/// - Chapters with multiple dialogue lines
/// - Scenes with character interactions
/// - Playlists of messages
/// - Document sections with multiple paragraphs
///
/// ## Features
///
/// - **Batch Generation**: Generate all items with one action
/// - **Progress Tracking**: Overall progress shows completion percentage
/// - **Smart Detection**: Skips items that already have audio
/// - **State-Aware UI**: Button shows "Generate All" or "Regenerate All" based on existing audio
///
/// ## Usage
///
/// ```swift
/// struct Chapter: SpeakableGroup {
///     let id: UUID
///     let title: String
///     let dialogueLines: [DialogueLine]
///
///     var groupName: String { title }
///
///     func getGroupedElements() -> [any SpeakableItem] {
///         return dialogueLines.map { line in
///             CharacterDialogue(
///                 characterName: line.character,
///                 dialogue: line.text,
///                 voiceProvider: line.voiceProvider,
///                 voiceId: line.voiceId,
///                 includeCharacterName: true
///             )
///         }
///     }
/// }
///
/// // In your SwiftUI view:
/// GenerateGroupButton(
///     group: chapter,
///     service: generationService,
///     modelContext: modelContext
/// )
/// ```
///
/// ## Implementation Notes
///
/// - `getGroupedElements()` can be computed dynamically or return a stored collection
/// - The order of items returned determines generation order
/// - Items are generated sequentially, not in parallel
/// - Progress is tracked as "X/Y items complete"
///
public protocol SpeakableGroup {
    /// The name of this group, used for display and logging
    ///
    /// This name appears in progress messages and logs during generation.
    /// Examples: "Chapter 1", "Scene 5", "Morning Messages"
    var groupName: String { get }

    /// Returns all speakable items in this group
    ///
    /// Items are generated in the order returned by this method.
    /// The implementation can return a stored array or compute it dynamically.
    ///
    /// - Returns: Array of SpeakableItem objects to be generated
    func getGroupedElements() -> [any SpeakableItem]

    /// Optional description of this group for UI display
    ///
    /// Provides additional context about the group. If nil, only the name is shown.
    /// Examples: "15 dialogue lines", "3 characters", "5 minutes estimated"
    var groupDescription: String? { get }
}

// MARK: - Default Implementations

extension SpeakableGroup {
    /// Default: No description
    public var groupDescription: String? { nil }

    /// Total count of items in this group
    public var itemCount: Int {
        getGroupedElements().count
    }
}
