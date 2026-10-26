//
//  SpeakableTestTypes.swift
//  SwiftHablareTests
//
//  Test-local speakable item and group types, ported to VoiceReference. They model the
//  shapes the 6.x Examples demonstrated (message, dialogue, article, chapter, scene,
//  Guion elements) so the Speakable protocols are tested without the Examples sources.
//

import Foundation
import SwiftCompartido

@testable import SwiftHablare

// MARK: - Simple Message Example

public struct SimpleMessage: SpeakableItem {
  public let voice: VoiceReference
  public let content: String

  public var textToSpeak: String {
    content
  }

  public init(content: String, voice: VoiceReference) {
    self.content = content
    self.voice = voice
  }
}

// MARK: - Character Dialogue Example

public struct CharacterDialogue: SpeakableItem {
  public let characterName: String
  public let dialogue: String
  public let voice: VoiceReference
  public let includeCharacterName: Bool

  public var textToSpeak: String {
    if includeCharacterName {
      return "\(characterName): \(dialogue)"
    } else {
      return dialogue
    }
  }

  public init(
    characterName: String,
    dialogue: String,
    voice: VoiceReference,
    includeCharacterName: Bool = false
  ) {
    self.characterName = characterName
    self.dialogue = dialogue
    self.voice = voice
    self.includeCharacterName = includeCharacterName
  }
}

// MARK: - Article Example

public struct Article: SpeakableItem {
  public let title: String
  public let author: String
  public let content: String
  public let voice: VoiceReference
  public let includeMeta: Bool

  public var textToSpeak: String {
    if includeMeta {
      return "\(title), by \(author). \(content)"
    } else {
      return content
    }
  }

  public init(
    title: String,
    author: String,
    content: String,
    voice: VoiceReference,
    includeMeta: Bool = true
  ) {
    self.title = title
    self.author = author
    self.content = content
    self.voice = voice
    self.includeMeta = includeMeta
  }
}

// MARK: - Notification Example

public struct Notification: SpeakableItem {
  public let title: String
  public let message: String
  public let timestamp: Date
  public let voice: VoiceReference
  public let includeTimestamp: Bool

  public var textToSpeak: String {
    if includeTimestamp {
      let formatter = DateFormatter()
      formatter.timeStyle = .short
      let timeString = formatter.string(from: timestamp)
      return "\(title) at \(timeString). \(message)"
    } else {
      return "\(title). \(message)"
    }
  }

  public init(
    title: String,
    message: String,
    timestamp: Date = Date(),
    voice: VoiceReference,
    includeTimestamp: Bool = false
  ) {
    self.title = title
    self.message = message
    self.timestamp = timestamp
    self.voice = voice
    self.includeTimestamp = includeTimestamp
  }
}

// MARK: - List Item Example

public struct ListItem: SpeakableItem {
  public let number: Int
  public let content: String
  public let voice: VoiceReference

  public var textToSpeak: String {
    "Step \(number): \(content)"
  }

  public init(
    number: Int,
    content: String,
    voice: VoiceReference
  ) {
    self.number = number
    self.content = content
    self.voice = voice
  }
}

// MARK: - Usage Examples

// MARK: - Chapter Example

public struct Chapter: SpeakableGroup {
  public let number: Int
  public let title: String
  public let dialogueLines: [DialogueLine]
  public let pluginId: String

  public var groupName: String {
    "Chapter \(number): \(title)"
  }

  public var groupDescription: String? {
    "\(dialogueLines.count) dialogue lines"
  }

  public func getGroupedElements() -> [any SpeakableItem] {
    return dialogueLines.map { line in
      CharacterDialogue(
        characterName: line.characterName,
        dialogue: line.text,
        voice: .catalog(pluginId: pluginId, voiceId: line.voiceId),
        includeCharacterName: true
      )
    }
  }

  public init(
    number: Int,
    title: String,
    dialogueLines: [DialogueLine],
    pluginId: String
  ) {
    self.number = number
    self.title = title
    self.dialogueLines = dialogueLines
    self.pluginId = pluginId
  }
}

public struct DialogueLine {
  public let characterName: String
  public let text: String
  public let voiceId: String

  public init(characterName: String, text: String, voiceId: String) {
    self.characterName = characterName
    self.text = text
    self.voiceId = voiceId
  }
}

// MARK: - Scene Example

public struct Scene: SpeakableGroup {
  public let number: Int
  public let location: String
  public let interactions: [Interaction]
  public let pluginId: String
  public let includeSceneHeading: Bool

  public var groupName: String {
    "Scene \(number) - \(location)"
  }

  public var groupDescription: String? {
    "\(interactions.count) interactions at \(location)"
  }

  public func getGroupedElements() -> [any SpeakableItem] {
    var elements: [any SpeakableItem] = []

    // Optional: Add scene heading
    if includeSceneHeading, let firstInteraction = interactions.first {
      elements.append(
        SimpleMessage(
          content: "Scene \(number), \(location).",
          voice: .catalog(pluginId: pluginId, voiceId: firstInteraction.voiceId)
        )
      )
    }

    // Add all interactions
    elements.append(
      contentsOf: interactions.map { interaction in
        CharacterDialogue(
          characterName: interaction.characterName,
          dialogue: interaction.line,
          voice: .catalog(pluginId: pluginId, voiceId: interaction.voiceId),
          includeCharacterName: true
        )
      })

    return elements
  }

  public init(
    number: Int,
    location: String,
    interactions: [Interaction],
    pluginId: String,
    includeSceneHeading: Bool = false
  ) {
    self.number = number
    self.location = location
    self.interactions = interactions
    self.pluginId = pluginId
    self.includeSceneHeading = includeSceneHeading
  }
}

public struct Interaction {
  public let characterName: String
  public let line: String
  public let voiceId: String

  public init(characterName: String, line: String, voiceId: String) {
    self.characterName = characterName
    self.line = line
    self.voiceId = voiceId
  }
}

// MARK: - Message Playlist Example

public struct MessagePlaylist: SpeakableGroup {
  public let name: String
  public let messages: [PlaylistMessage]
  public let pluginId: String
  public let defaultVoiceId: String
  public let includeMetadata: Bool

  public var groupName: String { name }

  public var groupDescription: String? {
    let highPriority = messages.filter { $0.priority == .high }.count
    if highPriority > 0 {
      return "\(messages.count) messages (\(highPriority) high priority)"
    }
    return "\(messages.count) messages"
  }

  public func getGroupedElements() -> [any SpeakableItem] {
    return messages.map { message in
      let content: String
      if includeMetadata {
        let priorityText = message.priority == .high ? "Important message from" : "Message from"
        content = "\(priorityText) \(message.sender): \(message.content)"
      } else {
        content = "\(message.sender) says: \(message.content)"
      }

      return SimpleMessage(
        content: content,
        voice: .catalog(pluginId: pluginId, voiceId: message.voiceId ?? defaultVoiceId)
      )
    }
  }

  public init(
    name: String,
    messages: [PlaylistMessage],
    pluginId: String,
    defaultVoiceId: String,
    includeMetadata: Bool = true
  ) {
    self.name = name
    self.messages = messages
    self.pluginId = pluginId
    self.defaultVoiceId = defaultVoiceId
    self.includeMetadata = includeMetadata
  }
}

public struct PlaylistMessage {
  public enum Priority {
    case low, normal, high
  }

  public let sender: String
  public let content: String
  public let priority: Priority
  public let voiceId: String?
  public let timestamp: Date

  public init(
    sender: String,
    content: String,
    priority: Priority = .normal,
    voiceId: String? = nil,
    timestamp: Date = Date()
  ) {
    self.sender = sender
    self.content = content
    self.priority = priority
    self.voiceId = voiceId
    self.timestamp = timestamp
  }
}

// MARK: - Article Sections Example

public struct ArticleSections: SpeakableGroup {
  public let title: String
  public let author: String
  public let sections: [ArticleSection]
  public let pluginId: String
  public let voiceId: String
  public let includeHeadings: Bool

  public var groupName: String {
    "\(title) by \(author)"
  }

  public var groupDescription: String? {
    "\(sections.count) sections"
  }

  public func getGroupedElements() -> [any SpeakableItem] {
    var elements: [any SpeakableItem] = []

    // Add title and author
    elements.append(
      Article(
        title: title,
        author: author,
        content: "",
        voice: .catalog(pluginId: pluginId, voiceId: voiceId),
        includeMeta: true
      )
    )

    // Add each section
    for section in sections {
      if includeHeadings {
        elements.append(
          SimpleMessage(
            content: section.heading,
            voice: .catalog(pluginId: pluginId, voiceId: voiceId)
          )
        )
      }

      elements.append(
        SimpleMessage(
          content: section.content,
          voice: .catalog(pluginId: pluginId, voiceId: voiceId)
        )
      )
    }

    return elements
  }

  public init(
    title: String,
    author: String,
    sections: [ArticleSection],
    pluginId: String,
    voiceId: String,
    includeHeadings: Bool = true
  ) {
    self.title = title
    self.author = author
    self.sections = sections
    self.pluginId = pluginId
    self.voiceId = voiceId
    self.includeHeadings = includeHeadings
  }
}

public struct ArticleSection {
  public let heading: String
  public let content: String

  public init(heading: String, content: String) {
    self.heading = heading
    self.content = content
  }
}

// MARK: - Shopping List Example

public struct ShoppingList: SpeakableGroup {
  public let name: String
  public let items: [String]
  public let pluginId: String
  public let voiceId: String
  public let includeNumbers: Bool

  public var groupName: String { name }

  public var groupDescription: String? {
    "\(items.count) items"
  }

  public func getGroupedElements() -> [any SpeakableItem] {
    return items.enumerated().map { (index, item) in
      if includeNumbers {
        return ListItem(
          number: index + 1,
          content: item,
          voice: .catalog(pluginId: pluginId, voiceId: voiceId)
        )
      } else {
        return SimpleMessage(
          content: item,
          voice: .catalog(pluginId: pluginId, voiceId: voiceId)
        )
      }
    }
  }

  public init(
    name: String,
    items: [String],
    pluginId: String,
    voiceId: String,
    includeNumbers: Bool = true
  ) {
    self.name = name
    self.items = items
    self.pluginId = pluginId
    self.voiceId = voiceId
    self.includeNumbers = includeNumbers
  }
}

// MARK: - GuionElement SpeakableItem

public struct GuionElementSpeakable: SpeakableItem {
  public let element: GuionElement
  public let voice: VoiceReference
  public let languageCode: String

  public var textToSpeak: String {
    element.elementText
  }

  public init(
    element: GuionElement,
    voice: VoiceReference,
    languageCode: String = Locale.current.language.languageCode?.identifier ?? "en"
  ) {
    self.element = element
    self.voice = voice
    self.languageCode = languageCode
  }
}

// MARK: - Dialogue Pair SpeakableItem

public struct DialoguePairSpeakable: SpeakableItem {
  public let character: GuionElement  // ElementType.character
  public let dialogue: GuionElement  // ElementType.dialogue
  public let voice: VoiceReference
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
    voice: VoiceReference,
    includeCharacterName: Bool = false,
    languageCode: String = Locale.current.language.languageCode?.identifier ?? "en"
  ) {
    self.character = character
    self.dialogue = dialogue
    self.voice = voice
    self.includeCharacterName = includeCharacterName
    self.languageCode = languageCode
  }
}

// MARK: - Section Heading SpeakableItem

public struct SectionHeadingSpeakable: SpeakableItem {
  public let heading: GuionElement
  public let voice: VoiceReference
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
    voice: VoiceReference,
    announceLevel: Bool = false,
    languageCode: String = Locale.current.language.languageCode?.identifier ?? "en"
  ) {
    self.heading = heading
    self.voice = voice
    self.announceLevel = announceLevel
    self.languageCode = languageCode
  }
}

// MARK: - Scene SpeakableGroup

public struct SceneSpeakable: SpeakableGroup {
  public let sceneHeading: GuionElement
  public let elements: [GuionElement]
  public let voiceMapping: (GuionElement) -> String  // Maps element to voiceId
  public let pluginId: String
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
        voice: .catalog(pluginId: pluginId, voiceId: voiceMapping(element)),
        languageCode: languageCode
      )
    }
  }

  public init(
    sceneHeading: GuionElement,
    elements: [GuionElement],
    voiceMapping: @escaping (GuionElement) -> String,
    pluginId: String,
    languageCode: String = Locale.current.language.languageCode?.identifier ?? "en"
  ) {
    self.sceneHeading = sceneHeading
    self.elements = elements
    self.voiceMapping = voiceMapping
    self.pluginId = pluginId
    self.languageCode = languageCode
  }
}

// MARK: - Chapter SpeakableGroup

public struct ChapterSpeakable: SpeakableGroup {
  public let chapterHeading: GuionElement?
  public let elements: [GuionElement]
  public let voiceMapping: (GuionElement) -> String  // Maps element to voiceId
  public let pluginId: String
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
        voice: .catalog(pluginId: pluginId, voiceId: voiceMapping(element)),
        languageCode: languageCode
      )
    }
  }

  public init(
    chapterHeading: GuionElement?,
    elements: [GuionElement],
    voiceMapping: @escaping (GuionElement) -> String,
    pluginId: String,
    languageCode: String = Locale.current.language.languageCode?.identifier ?? "en"
  ) {
    self.chapterHeading = chapterHeading
    self.elements = elements
    self.voiceMapping = voiceMapping
    self.pluginId = pluginId
    self.languageCode = languageCode
  }
}

// MARK: - Markdown Document SpeakableGroup

public struct MarkdownDocumentSpeakable: SpeakableGroup {
  public let filename: String
  public let elements: [GuionElement]
  public let pluginId: String
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
        voice: .catalog(pluginId: pluginId, voiceId: defaultVoiceId),
        languageCode: languageCode
      )
    }
  }

  public init(
    filename: String,
    elements: [GuionElement],
    pluginId: String,
    defaultVoiceId: String,
    languageCode: String = Locale.current.language.languageCode?.identifier ?? "en"
  ) {
    self.filename = filename
    self.elements = elements
    self.pluginId = pluginId
    self.defaultVoiceId = defaultVoiceId
    self.languageCode = languageCode
  }
}

// MARK: - GuionElement helpers

extension GuionElement {
  /// True when the element has non-empty text.
  var isSpeakable: Bool {
    !elementText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  /// Narrator or character voice for this element type.
  var recommendedVoiceType: VoiceType {
    switch elementType {
    case .dialogue, .character, .lyrics:
      return .character
    default:
      return .narrator
    }
  }
}

/// Voice type classification for screenplay elements.
enum VoiceType {
  case character
  case narrator
}
