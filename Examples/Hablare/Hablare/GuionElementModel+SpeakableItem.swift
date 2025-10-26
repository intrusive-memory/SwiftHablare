//
//  GuionElementModel+SpeakableItem.swift
//  Hablare
//
//  Extension to make GuionElementModel compatible with SwiftHablare's SpeakableItem protocol
//

import Foundation
import SwiftCompartido
import SwiftHablare

/// A speakable wrapper for GuionElementModel that adapts screenplay elements
/// to the SpeakableItem protocol with element-type-specific text generation rules.
///
/// ## Overview
///
/// This struct wraps a GuionElementModel and provides customized text-to-speech
/// generation based on the element's type:
/// - **Scene Headings**: Spoken with descriptive context
/// - **Action**: Narrated as written
/// - **Character**: Announced before dialogue
/// - **Dialogue**: Spoken in character voice
/// - **Parenthetical**: Optional inline direction
/// - **Transition**: Can be included or omitted
/// - **Section Headings**: Announced as structural markers
/// - **Other elements**: Handled gracefully
///
/// ## Example
///
/// ```swift
/// let provider = AppleVoiceProvider()
/// let voices = try await provider.fetchVoices()
/// let voiceId = voices.first!.id
///
/// // Create from a GuionElementModel
/// let speakableElement = element.asSpeakable(
///     voiceProvider: provider,
///     voiceId: voiceId
/// )
///
/// // Generate audio
/// let audioData = try await speakableElement.speak()
/// ```
public struct SpeakableGuionElement: SpeakableItem {
    // MARK: - Properties

    /// The underlying screenplay element
    public let element: GuionElementModel

    /// The voice provider for speech generation
    public let voiceProvider: VoiceProvider

    /// The voice ID to use for generation
    public let voiceId: String

    /// Configuration options for text generation
    public var options: SpeechOptions

    // MARK: - SpeakableItem Conformance

    /// The text to speak, customized based on element type
    public var textToSpeak: String {
        generateText(for: element, with: options)
    }

    // MARK: - Initialization

    /// Create a speakable element with custom options
    ///
    /// - Parameters:
    ///   - element: The GuionElementModel to make speakable
    ///   - voiceProvider: The voice provider for audio generation
    ///   - voiceId: The voice ID to use
    ///   - options: Speech generation options (default: .default)
    public init(
        element: GuionElementModel,
        voiceProvider: VoiceProvider,
        voiceId: String,
        options: SpeechOptions = .default
    ) {
        self.element = element
        self.voiceProvider = voiceProvider
        self.voiceId = voiceId
        self.options = options
    }

    // MARK: - Text Generation

    /// Generate speech text based on element type and options
    private func generateText(for element: GuionElementModel, with options: SpeechOptions) -> String {
        let text = element.elementText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else {
            return ""
        }

        switch element.elementType {
        case .sceneHeading:
            return generateSceneHeadingText(text, options: options)

        case .action:
            return generateActionText(text, options: options)

        case .character:
            return generateCharacterText(text, options: options)

        case .dialogue:
            return generateDialogueText(text, options: options)

        case .parenthetical:
            return generateParentheticalText(text, options: options)

        case .transition:
            return generateTransitionText(text, options: options)

        case .sectionHeading(let level):
            return generateSectionHeadingText(text, level: level, options: options)

        case .synopsis:
            return generateSynopsisText(text, options: options)

        case .comment:
            // Comments are typically not spoken
            return options.includeComments ? "Note: \(text)" : ""

        case .boneyard:
            // Boneyard (omitted content) is not spoken
            return ""

        case .lyrics:
            return generateLyricsText(text, options: options)

        case .pageBreak:
            // Page breaks are structural, not spoken
            return ""
        }
    }

    // MARK: - Element-Specific Text Generation

    private func generateSceneHeadingText(_ text: String, options: SpeechOptions) -> String {
        if options.announceSceneHeadings {
            // Parse and make it more natural for speech
            let cleaned = text
                .replacingOccurrences(of: "INT.", with: "Interior")
                .replacingOccurrences(of: "EXT.", with: "Exterior")
                .replacingOccurrences(of: "INT/EXT", with: "Interior Exterior")
                .replacingOccurrences(of: "I/E", with: "Interior Exterior")
            return "Scene: \(cleaned)"
        }
        return ""
    }

    private func generateActionText(_ text: String, options: SpeechOptions) -> String {
        if options.includeAction {
            return options.announceAction ? "Action: \(text)" : text
        }
        return ""
    }

    private func generateCharacterText(_ text: String, options: SpeechOptions) -> String {
        if options.announceCharacterNames {
            // Remove any (V.O.), (O.S.), etc. for cleaner speech
            let cleanName = text
                .replacingOccurrences(of: #"\s*\([^)]+\)"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
            return cleanName
        }
        return ""
    }

    private func generateDialogueText(_ text: String, options: SpeechOptions) -> String {
        // Dialogue is almost always included
        return text
    }

    private func generateParentheticalText(_ text: String, options: SpeechOptions) -> String {
        if options.includeParentheticals {
            // Remove parentheses for more natural speech
            let cleaned = text
                .replacingOccurrences(of: "(", with: "")
                .replacingOccurrences(of: ")", with: "")
                .trimmingCharacters(in: .whitespaces)
            return cleaned
        }
        return ""
    }

    private func generateTransitionText(_ text: String, options: SpeechOptions) -> String {
        if options.includeTransitions {
            // Make transitions sound more natural
            let cleaned = text
                .replacingOccurrences(of: ":", with: "")
                .replacingOccurrences(of: "CUT TO", with: "Cut to")
                .replacingOccurrences(of: "FADE OUT", with: "Fade out")
                .replacingOccurrences(of: "FADE IN", with: "Fade in")
                .replacingOccurrences(of: "DISSOLVE TO", with: "Dissolve to")
            return cleaned
        }
        return ""
    }

    private func generateSectionHeadingText(_ text: String, level: Int, options: SpeechOptions) -> String {
        if options.announceSectionHeadings {
            let prefix = switch level {
            case 1: "Title"
            case 2: "Act"
            case 3: "Sequence"
            case 4: "Scene Group"
            case 5: "Subscene"
            case 6: "Beat"
            default: "Section"
            }

            // Remove the leading # characters if present
            let cleaned = text.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
            return "\(prefix): \(cleaned)"
        }
        return ""
    }

    private func generateSynopsisText(_ text: String, options: SpeechOptions) -> String {
        if options.includeSynopsis {
            return "Synopsis: \(text)"
        }
        return ""
    }

    private func generateLyricsText(_ text: String, options: SpeechOptions) -> String {
        if options.includeLyrics {
            return options.announceLyrics ? "Singing: \(text)" : text
        }
        return ""
    }
}

// MARK: - Speech Options

/// Configuration options for generating speech from screenplay elements
public struct SpeechOptions {
    /// Whether to announce scene headings (e.g., "Scene: Interior Coffee Shop - Day")
    public var announceSceneHeadings: Bool

    /// Whether to include action/description elements
    public var includeAction: Bool

    /// Whether to announce action with a prefix (e.g., "Action: ...")
    public var announceAction: Bool

    /// Whether to announce character names before dialogue
    public var announceCharacterNames: Bool

    /// Whether to include parenthetical directions
    public var includeParentheticals: Bool

    /// Whether to include scene transitions
    public var includeTransitions: Bool

    /// Whether to announce section headings
    public var announceSectionHeadings: Bool

    /// Whether to include synopsis/outline summaries
    public var includeSynopsis: Bool

    /// Whether to include inline comments
    public var includeComments: Bool

    /// Whether to include lyrics
    public var includeLyrics: Bool

    /// Whether to announce lyrics with a prefix
    public var announceLyrics: Bool

    /// Default options: include most elements without excessive announcements
    public static let `default` = SpeechOptions(
        announceSceneHeadings: true,
        includeAction: true,
        announceAction: false,
        announceCharacterNames: true,
        includeParentheticals: false,
        includeTransitions: false,
        announceSectionHeadings: true,
        includeSynopsis: false,
        includeComments: false,
        includeLyrics: true,
        announceLyrics: false
    )

    /// Dialogue-only mode: only character names and dialogue
    public static let dialogueOnly = SpeechOptions(
        announceSceneHeadings: false,
        includeAction: false,
        announceAction: false,
        announceCharacterNames: true,
        includeParentheticals: false,
        includeTransitions: false,
        announceSectionHeadings: false,
        includeSynopsis: false,
        includeComments: false,
        includeLyrics: false,
        announceLyrics: false
    )

    /// Narration mode: all narrative elements, minimal announcements
    public static let narration = SpeechOptions(
        announceSceneHeadings: false,
        includeAction: true,
        announceAction: false,
        announceCharacterNames: false,
        includeParentheticals: false,
        includeTransitions: false,
        announceSectionHeadings: false,
        includeSynopsis: false,
        includeComments: false,
        includeLyrics: true,
        announceLyrics: false
    )

    /// Full screenplay mode: everything with announcements
    public static let full = SpeechOptions(
        announceSceneHeadings: true,
        includeAction: true,
        announceAction: true,
        announceCharacterNames: true,
        includeParentheticals: true,
        includeTransitions: true,
        announceSectionHeadings: true,
        includeSynopsis: true,
        includeComments: false,
        includeLyrics: true,
        announceLyrics: true
    )
}

// MARK: - GuionElementModel Extension

extension GuionElementModel {
    /// Create a SpeakableItem from this element
    ///
    /// - Parameters:
    ///   - voiceProvider: The voice provider for audio generation
    ///   - voiceId: The voice ID to use
    ///   - options: Speech generation options (default: .default)
    /// - Returns: A SpeakableGuionElement that can generate audio
    ///
    /// ## Example
    ///
    /// ```swift
    /// let provider = AppleVoiceProvider()
    /// let voices = try await provider.fetchVoices()
    ///
    /// let speakable = element.asSpeakable(
    ///     voiceProvider: provider,
    ///     voiceId: voices.first!.id,
    ///     options: .dialogueOnly
    /// )
    ///
    /// let audio = try await speakable.speak()
    /// ```
    public func asSpeakable(
        voiceProvider: VoiceProvider,
        voiceId: String,
        options: SpeechOptions = .default
    ) -> SpeakableGuionElement {
        SpeakableGuionElement(
            element: self,
            voiceProvider: voiceProvider,
            voiceId: voiceId,
            options: options
        )
    }
}

// MARK: - Collection Extension

extension Collection where Element == GuionElementModel {
    /// Convert all elements to speakable items
    ///
    /// - Parameters:
    ///   - voiceProvider: The voice provider for audio generation
    ///   - voiceId: The voice ID to use
    ///   - options: Speech generation options (default: .default)
    /// - Returns: An array of SpeakableGuionElement items
    ///
    /// ## Example
    ///
    /// ```swift
    /// let elements = document.displayModel.elements
    /// let speakableElements = elements.asSpeakable(
    ///     voiceProvider: provider,
    ///     voiceId: voiceId,
    ///     options: .dialogueOnly
    /// )
    ///
    /// // Generate audio for all dialogue
    /// let audioFiles = try await speakableElements.speakAll()
    /// ```
    public func asSpeakable(
        voiceProvider: VoiceProvider,
        voiceId: String,
        options: SpeechOptions = .default
    ) -> [SpeakableGuionElement] {
        map { element in
            element.asSpeakable(
                voiceProvider: voiceProvider,
                voiceId: voiceId,
                options: options
            )
        }
    }
}
