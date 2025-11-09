//
//  GuionElementSpeakableExamples.swift
//  SwiftHablare
//
//  Example implementations of SpeakableItem and SpeakableGroup protocols
//  for SwiftCompartido's GuionElement models (markdown and screenplay elements)
//

import Foundation
import SwiftCompartido

// MARK: - GuionElement SpeakableItem

/// A GuionElement that can be spoken
///
/// This adapter converts any `GuionElement` from SwiftCompartido into a speakable item.
/// Markdown elements parsed by CommonMarkParser are represented as GuionElements,
/// so this provides TTS support for all markdown content.
///
/// **Supported Element Types:**
/// - `.action` - Narrative description, markdown paragraphs, lists, quotes
/// - `.dialogue` - Character speech
/// - `.character` - Character name announcements
/// - `.sectionHeading(level:)` - Markdown headings (# through ######)
/// - `.sceneHeading` - Location sluglines
/// - `.parenthetical` - Brief action/tone indicators
/// - `.transition` - Scene transitions (CUT TO:, FADE OUT, etc.)
/// - `.synopsis` - Scene summaries
/// - `.lyrics` - Song lyrics
///
/// **Example Usage:**
/// ```swift
/// // Parse markdown file
/// let parsed = try GuionParsedElementCollection(file: markdownURL)
/// let elements = parsed.elements
///
/// // Create speakable items
/// let speakableElements = elements.map { element in
///     GuionElementSpeakable(
///         element: element,
///         voiceProvider: provider,
///         voiceId: voiceId
///     )
/// }
///
/// // Generate audio for each element
/// for speakable in speakableElements {
///     let audioData = try await speakable.speak()
///     // Save to TypedDataStorage...
/// }
/// ```
public struct GuionElementSpeakable: SpeakableItem {
    public let element: GuionElement
    public let voiceProvider: VoiceProvider
    public let voiceId: String
    public let languageCode: String

    public var textToSpeak: String {
        element.elementText
    }

    public init(
        element: GuionElement,
        voiceProvider: VoiceProvider,
        voiceId: String,
        languageCode: String = Locale.current.language.languageCode?.identifier ?? "en"
    ) {
        self.element = element
        self.voiceProvider = voiceProvider
        self.voiceId = voiceId
        self.languageCode = languageCode
    }
}

// MARK: - Dialogue Pair SpeakableItem

/// A character-dialogue pair that can be spoken
///
/// This represents a character name followed by their dialogue, which is the most
/// common pattern in screenplays. The character element provides the speaker name,
/// and the dialogue element contains the words they speak.
///
/// **Example Usage:**
/// ```swift
/// // Extract character-dialogue pairs from screenplay
/// var pairs: [DialoguePairSpeakable] = []
/// for i in 0..<elements.count - 1 {
///     if case .character = elements[i].elementType,
///        case .dialogue = elements[i + 1].elementType {
///         let pair = DialoguePairSpeakable(
///             character: elements[i],
///             dialogue: elements[i + 1],
///             voiceProvider: provider,
///             voiceId: getVoiceForCharacter(elements[i].elementText)
///         )
///         pairs.append(pair)
///     }
/// }
/// ```
public struct DialoguePairSpeakable: SpeakableItem {
    public let character: GuionElement  // ElementType.character
    public let dialogue: GuionElement   // ElementType.dialogue
    public let voiceProvider: VoiceProvider
    public let voiceId: String
    public let includeCharacterName: Bool
    public let languageCode: String

    public var textToSpeak: String {
        if includeCharacterName {
            return "\(character.elementText): \(dialogue.elementText)"
        }
        return dialogue.elementText
    }

    public init(
        character: GuionElement,
        dialogue: GuionElement,
        voiceProvider: VoiceProvider,
        voiceId: String,
        includeCharacterName: Bool = false,
        languageCode: String = Locale.current.language.languageCode?.identifier ?? "en"
    ) {
        self.character = character
        self.dialogue = dialogue
        self.voiceProvider = voiceProvider
        self.voiceId = voiceId
        self.includeCharacterName = includeCharacterName
        self.languageCode = languageCode
    }
}

// MARK: - Section Heading SpeakableItem

/// A section heading that can be announced
///
/// Section headings represent the hierarchical structure of a screenplay or markdown document.
/// When spoken, they provide context about document structure.
///
/// **Heading Levels (from Fountain.io spec):**
/// - Level 1 (`#`): Title/Script name
/// - Level 2 (`##`): Act
/// - Level 3 (`###`): Sequence
/// - Level 4 (`####`): Scene group
/// - Level 5 (`#####`): Sub-scene
/// - Level 6 (`######`): Beat
///
/// **Example Usage:**
/// ```swift
/// let heading = GuionElement(
///     elementType: .sectionHeading(level: 2),
///     elementText: "Act One"
/// )
///
/// let speakable = SectionHeadingSpeakable(
///     heading: heading,
///     voiceProvider: provider,
///     voiceId: narratorVoiceId,
///     announceLevel: true  // "Act Two: The Journey Begins"
/// )
/// ```
public struct SectionHeadingSpeakable: SpeakableItem {
    public let heading: GuionElement
    public let voiceProvider: VoiceProvider
    public let voiceId: String
    public let announceLevel: Bool
    public let languageCode: String

    public var textToSpeak: String {
        guard case .sectionHeading(let level) = heading.elementType else {
            return heading.elementText
        }

        if announceLevel {
            let levelName = levelName(for: level)
            return "\(levelName): \(heading.elementText)"
        }

        return heading.elementText
    }

    private func levelName(for level: Int) -> String {
        switch level {
        case 1: return "Title"
        case 2: return "Act"
        case 3: return "Sequence"
        case 4: return "Scene Group"
        case 5: return "Sub-scene"
        case 6: return "Beat"
        default: return "Section"
        }
    }

    public init(
        heading: GuionElement,
        voiceProvider: VoiceProvider,
        voiceId: String,
        announceLevel: Bool = false,
        languageCode: String = Locale.current.language.languageCode?.identifier ?? "en"
    ) {
        self.heading = heading
        self.voiceProvider = voiceProvider
        self.voiceId = voiceId
        self.announceLevel = announceLevel
        self.languageCode = languageCode
    }
}

// MARK: - Scene SpeakableGroup

/// A scene that can be spoken as a group
///
/// A scene is a logical grouping of screenplay elements that occur in the same location.
/// It starts with a scene heading (slugline) and includes all subsequent elements until
/// the next scene heading.
///
/// **Scene Detection:**
/// - Starts with `ElementType.sceneHeading`
/// - Includes all subsequent elements until next scene heading
/// - Common elements: action, character, dialogue, parenthetical
///
/// **Example Usage:**
/// ```swift
/// // Group elements by scene
/// var scenes: [SceneSpeakable] = []
/// var currentScene: [GuionElement] = []
/// var currentHeading: GuionElement?
///
/// for element in elements {
///     if case .sceneHeading = element.elementType {
///         if let heading = currentHeading, !currentScene.isEmpty {
///             scenes.append(SceneSpeakable(
///                 sceneHeading: heading,
///                 elements: currentScene,
///                 voiceMapping: voiceMapping,
///                 provider: provider
///             ))
///         }
///         currentHeading = element
///         currentScene = []
///     } else {
///         currentScene.append(element)
///     }
/// }
/// ```
public struct SceneSpeakable: SpeakableGroup {
    public let sceneHeading: GuionElement
    public let elements: [GuionElement]
    public let voiceMapping: (GuionElement) -> String  // Maps element to voiceId
    public let voiceProvider: VoiceProvider
    public let languageCode: String

    public var groupName: String {
        sceneHeading.elementText
    }

    public var groupDescription: String? {
        "\(elements.count) elements"
    }

    public func getGroupedElements() -> [any SpeakableItem] {
        return elements.map { element in
            GuionElementSpeakable(
                element: element,
                voiceProvider: voiceProvider,
                voiceId: voiceMapping(element),
                languageCode: languageCode
            )
        }
    }

    public init(
        sceneHeading: GuionElement,
        elements: [GuionElement],
        voiceMapping: @escaping (GuionElement) -> String,
        voiceProvider: VoiceProvider,
        languageCode: String = Locale.current.language.languageCode?.identifier ?? "en"
    ) {
        self.sceneHeading = sceneHeading
        self.elements = elements
        self.voiceMapping = voiceMapping
        self.voiceProvider = voiceProvider
        self.languageCode = languageCode
    }
}

// MARK: - Chapter SpeakableGroup

/// A chapter that can be spoken as a group
///
/// Chapters are defined by Level 2 section headings (`##`) in markdown or Fountain format.
/// SwiftCompartido uses chapters for organizing screenplay elements with composite key
/// ordering: `(chapterIndex, orderIndex)`.
///
/// **Chapter Detection:**
/// - Starts with `.sectionHeading(level: 2)` (Act level)
/// - Includes all elements until next level 2 heading
/// - May contain scenes, dialogue, action, and other elements
///
/// **Example Usage:**
/// ```swift
/// // Group elements by chapter
/// var chapters: [ChapterSpeakable] = []
/// var currentChapter: [GuionElement] = []
/// var currentHeading: GuionElement?
///
/// for element in elements {
///     if case .sectionHeading(level: 2) = element.elementType {
///         if let heading = currentHeading, !currentChapter.isEmpty {
///             chapters.append(ChapterSpeakable(
///                 chapterHeading: heading,
///                 elements: currentChapter,
///                 voiceMapping: voiceMapping,
///                 provider: provider
///             ))
///         }
///         currentHeading = element
///         currentChapter = []
///     } else {
///         currentChapter.append(element)
///     }
/// }
/// ```
public struct ChapterSpeakable: SpeakableGroup {
    public let chapterHeading: GuionElement?
    public let elements: [GuionElement]
    public let voiceMapping: (GuionElement) -> String  // Maps element to voiceId
    public let voiceProvider: VoiceProvider
    public let languageCode: String

    public var groupName: String {
        chapterHeading?.elementText ?? "Chapter"
    }

    public var groupDescription: String? {
        let sceneCount = elements.filter { element in
            if case .sceneHeading = element.elementType { return true }
            return false
        }.count

        let dialogueCount = elements.filter { element in
            if case .dialogue = element.elementType { return true }
            return false
        }.count

        return "\(elements.count) elements (\(sceneCount) scenes, \(dialogueCount) dialogue lines)"
    }

    public func getGroupedElements() -> [any SpeakableItem] {
        return elements.map { element in
            GuionElementSpeakable(
                element: element,
                voiceProvider: voiceProvider,
                voiceId: voiceMapping(element),
                languageCode: languageCode
            )
        }
    }

    public init(
        chapterHeading: GuionElement?,
        elements: [GuionElement],
        voiceMapping: @escaping (GuionElement) -> String,
        voiceProvider: VoiceProvider,
        languageCode: String = Locale.current.language.languageCode?.identifier ?? "en"
    ) {
        self.chapterHeading = chapterHeading
        self.elements = elements
        self.voiceMapping = voiceMapping
        self.voiceProvider = voiceProvider
        self.languageCode = languageCode
    }
}

// MARK: - Markdown Document SpeakableGroup

/// A complete markdown document that can be spoken as a group
///
/// This represents an entire markdown file parsed into GuionElements by CommonMarkParser.
/// It provides batch audio generation for all markdown content.
///
/// **Markdown Element Mapping:**
/// - Headings (`#`, `##`, etc.) → `.sectionHeading(level:)`
/// - Paragraphs → `.action`
/// - Block quotes → `.action` (prefixed with `>`)
/// - Code blocks → `.action` (indented)
/// - Lists → `.action` (prefixed with `•` or numbered)
/// - Thematic breaks (`---`) → `.pageBreak`
///
/// **Example Usage:**
/// ```swift
/// // Parse markdown file
/// let markdownURL = URL(fileURLWithPath: "article.md")
/// let parsed = try GuionParsedElementCollection(file: markdownURL)
///
/// // Create speakable document
/// let document = MarkdownDocumentSpeakable(
///     filename: "article.md",
///     elements: parsed.elements,
///     voiceProvider: provider,
///     defaultVoiceId: narratorVoiceId
/// )
///
/// // Generate all audio
/// let audioFiles = try await document.getGroupedElements().speakAll()
/// ```
public struct MarkdownDocumentSpeakable: SpeakableGroup {
    public let filename: String
    public let elements: [GuionElement]
    public let voiceProvider: VoiceProvider
    public let defaultVoiceId: String
    public let languageCode: String

    public var groupName: String {
        filename
    }

    public var groupDescription: String? {
        let headingCount = elements.filter { element in
            if case .sectionHeading = element.elementType { return true }
            return false
        }.count

        let paragraphCount = elements.filter { element in
            if case .action = element.elementType { return true }
            return false
        }.count

        return "\(elements.count) elements (\(headingCount) headings, \(paragraphCount) paragraphs)"
    }

    public func getGroupedElements() -> [any SpeakableItem] {
        return elements.map { element in
            GuionElementSpeakable(
                element: element,
                voiceProvider: voiceProvider,
                voiceId: defaultVoiceId,
                languageCode: languageCode
            )
        }
    }

    public init(
        filename: String,
        elements: [GuionElement],
        voiceProvider: VoiceProvider,
        defaultVoiceId: String,
        languageCode: String = Locale.current.language.languageCode?.identifier ?? "en"
    ) {
        self.filename = filename
        self.elements = elements
        self.voiceProvider = voiceProvider
        self.defaultVoiceId = defaultVoiceId
        self.languageCode = languageCode
    }
}

// MARK: - Helper Extensions

extension GuionElement {
    /// Returns true if this element should be spoken (has non-empty text)
    public var isSpeakable: Bool {
        !elementText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Returns the recommended voice type for this element
    public var recommendedVoiceType: VoiceType {
        switch elementType {
        case .dialogue, .character:
            return .character
        case .action, .sceneHeading, .transition:
            return .narrator
        case .sectionHeading:
            return .narrator
        case .parenthetical:
            return .narrator
        case .synopsis:
            return .narrator
        case .lyrics:
            return .character
        default:
            return .narrator
        }
    }
}

/// Voice type classification for screenplay elements
public enum VoiceType {
    case character  // Character dialogue
    case narrator   // Action, scene headings, etc.
}
