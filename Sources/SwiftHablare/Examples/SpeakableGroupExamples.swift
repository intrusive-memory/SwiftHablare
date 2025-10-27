//
//  SpeakableGroupExamples.swift
//  SwiftHablare
//
//  Example implementations of the SpeakableGroup protocol
//

import Foundation

// MARK: - Chapter Example

/// Example: A chapter containing multiple dialogue lines
///
/// Useful for books, scripts, or any content with sequential dialogue.
///
/// ```swift
/// let chapter = Chapter(
///     number: 1,
///     title: "The Beginning",
///     dialogueLines: [
///         DialogueLine(character: "Alice", text: "Hello!", voiceId: "voice-1"),
///         DialogueLine(character: "Bob", text: "Hi there!", voiceId: "voice-2")
///     ],
///     provider: AppleVoiceProvider()
/// )
///
/// GenerateGroupButton(group: chapter, service: service, modelContext: context)
/// ```
public struct Chapter: SpeakableGroup {
    public let number: Int
    public let title: String
    public let dialogueLines: [DialogueLine]
    public let provider: VoiceProvider

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
                voiceProvider: provider,
                voiceId: line.voiceId,
                includeCharacterName: true
            )
        }
    }

    public init(
        number: Int,
        title: String,
        dialogueLines: [DialogueLine],
        provider: VoiceProvider
    ) {
        self.number = number
        self.title = title
        self.dialogueLines = dialogueLines
        self.provider = provider
    }
}

/// Supporting structure for dialogue lines
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

/// Example: A scene with multiple character interactions
///
/// Useful for theatrical scripts, movie scenes, or interactive dialogues.
///
/// ```swift
/// let scene = Scene(
///     number: 5,
///     location: "Coffee Shop",
///     interactions: [
///         Interaction(character: "Waiter", line: "Welcome!", voiceId: "voice-1"),
///         Interaction(character: "Customer", line: "One coffee, please.", voiceId: "voice-2")
///     ],
///     provider: ElevenLabsVoiceProvider()
/// )
/// ```
public struct Scene: SpeakableGroup {
    public let number: Int
    public let location: String
    public let interactions: [Interaction]
    public let provider: VoiceProvider
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
                    voiceProvider: provider,
                    voiceId: firstInteraction.voiceId
                )
            )
        }

        // Add all interactions
        elements.append(contentsOf: interactions.map { interaction in
            CharacterDialogue(
                characterName: interaction.characterName,
                dialogue: interaction.line,
                voiceProvider: provider,
                voiceId: interaction.voiceId,
                includeCharacterName: true
            )
        })

        return elements
    }

    public init(
        number: Int,
        location: String,
        interactions: [Interaction],
        provider: VoiceProvider,
        includeSceneHeading: Bool = false
    ) {
        self.number = number
        self.location = location
        self.interactions = interactions
        self.provider = provider
        self.includeSceneHeading = includeSceneHeading
    }
}

/// Supporting structure for scene interactions
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

/// Example: A playlist of messages to be read aloud
///
/// Useful for notification systems, email readers, or message queues.
///
/// ```swift
/// let playlist = MessagePlaylist(
///     name: "Morning Messages",
///     messages: [
///         PlaylistMessage(from: "Alice", content: "Good morning!", priority: .high),
///         PlaylistMessage(from: "Bob", content: "Meeting at 10am", priority: .normal)
///     ],
///     provider: AppleVoiceProvider(),
///     defaultVoiceId: "voice-1"
/// )
/// ```
public struct MessagePlaylist: SpeakableGroup {
    public let name: String
    public let messages: [PlaylistMessage]
    public let provider: VoiceProvider
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
                voiceProvider: provider,
                voiceId: message.voiceId ?? defaultVoiceId
            )
        }
    }

    public init(
        name: String,
        messages: [PlaylistMessage],
        provider: VoiceProvider,
        defaultVoiceId: String,
        includeMetadata: Bool = true
    ) {
        self.name = name
        self.messages = messages
        self.provider = provider
        self.defaultVoiceId = defaultVoiceId
        self.includeMetadata = includeMetadata
    }
}

/// Supporting structure for playlist messages
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

/// Example: An article with multiple sections
///
/// Useful for blog posts, documentation, or long-form content.
///
/// ```swift
/// let article = ArticleSections(
///     title: "Introduction to SwiftUI",
///     author: "Jane Doe",
///     sections: [
///         Section(heading: "What is SwiftUI?", content: "SwiftUI is..."),
///         Section(heading: "Getting Started", content: "First, create...")
///     ],
///     provider: AppleVoiceProvider(),
///     voiceId: "voice-1"
/// )
/// ```
public struct ArticleSections: SpeakableGroup {
    public let title: String
    public let author: String
    public let sections: [ArticleSection]
    public let provider: VoiceProvider
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
                voiceProvider: provider,
                voiceId: voiceId,
                includeMeta: true
            )
        )

        // Add each section
        for section in sections {
            if includeHeadings {
                elements.append(
                    SimpleMessage(
                        content: section.heading,
                        voiceProvider: provider,
                        voiceId: voiceId
                    )
                )
            }

            elements.append(
                SimpleMessage(
                    content: section.content,
                    voiceProvider: provider,
                    voiceId: voiceId
                )
            )
        }

        return elements
    }

    public init(
        title: String,
        author: String,
        sections: [ArticleSection],
        provider: VoiceProvider,
        voiceId: String,
        includeHeadings: Bool = true
    ) {
        self.title = title
        self.author = author
        self.sections = sections
        self.provider = provider
        self.voiceId = voiceId
        self.includeHeadings = includeHeadings
    }
}

/// Supporting structure for article sections
public struct ArticleSection {
    public let heading: String
    public let content: String

    public init(heading: String, content: String) {
        self.heading = heading
        self.content = content
    }
}

// MARK: - Shopping List Example

/// Example: A shopping list to be read aloud
///
/// Useful for task lists, checklists, or enumerated items.
///
/// ```swift
/// let shoppingList = ShoppingList(
///     name: "Grocery Run",
///     items: ["Milk", "Eggs", "Bread", "Apples"],
///     provider: AppleVoiceProvider(),
///     voiceId: "voice-1"
/// )
/// ```
public struct ShoppingList: SpeakableGroup {
    public let name: String
    public let items: [String]
    public let provider: VoiceProvider
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
                    voiceProvider: provider,
                    voiceId: voiceId
                )
            } else {
                return SimpleMessage(
                    content: item,
                    voiceProvider: provider,
                    voiceId: voiceId
                )
            }
        }
    }

    public init(
        name: String,
        items: [String],
        provider: VoiceProvider,
        voiceId: String,
        includeNumbers: Bool = true
    ) {
        self.name = name
        self.items = items
        self.provider = provider
        self.voiceId = voiceId
        self.includeNumbers = includeNumbers
    }
}
