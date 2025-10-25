//
//  SpeakableItemExamples.swift
//  SwiftHablare
//
//  Example implementations of SpeakableItem protocol
//

import Foundation

// MARK: - Simple Message Example

/// A simple message that can be spoken
///
/// This example shows the most basic implementation of `SpeakableItem`,
/// where the text to speak is directly stored in a property.
public struct SimpleMessage: SpeakableItem {
    public let voiceProvider: VoiceProvider
    public let voiceId: String
    public let content: String

    public var textToSpeak: String {
        content
    }

    public init(content: String, voiceProvider: VoiceProvider, voiceId: String) {
        self.content = content
        self.voiceProvider = voiceProvider
        self.voiceId = voiceId
    }
}

// MARK: - Character Dialogue Example

/// A dialogue line spoken by a character
///
/// This example shows how to compose speech from multiple properties,
/// adding context like the character name to the spoken text.
public struct CharacterDialogue: SpeakableItem {
    public let characterName: String
    public let dialogue: String
    public let voiceProvider: VoiceProvider
    public let voiceId: String
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
        voiceProvider: VoiceProvider,
        voiceId: String,
        includeCharacterName: Bool = false
    ) {
        self.characterName = characterName
        self.dialogue = dialogue
        self.voiceProvider = voiceProvider
        self.voiceId = voiceId
        self.includeCharacterName = includeCharacterName
    }
}

// MARK: - Article Example

/// A news article or blog post that can be spoken
///
/// This example shows more complex text composition, combining
/// multiple fields into a single speakable narrative.
public struct Article: SpeakableItem {
    public let title: String
    public let author: String
    public let content: String
    public let voiceProvider: VoiceProvider
    public let voiceId: String
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
        voiceProvider: VoiceProvider,
        voiceId: String,
        includeMeta: Bool = true
    ) {
        self.title = title
        self.author = author
        self.content = content
        self.voiceProvider = voiceProvider
        self.voiceId = voiceId
        self.includeMeta = includeMeta
    }
}

// MARK: - Notification Example

/// A system notification that can be spoken
///
/// This example shows how to format structured data for speech,
/// including time-based information.
public struct Notification: SpeakableItem {
    public let title: String
    public let message: String
    public let timestamp: Date
    public let voiceProvider: VoiceProvider
    public let voiceId: String
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
        voiceProvider: VoiceProvider,
        voiceId: String,
        includeTimestamp: Bool = false
    ) {
        self.title = title
        self.message = message
        self.timestamp = timestamp
        self.voiceProvider = voiceProvider
        self.voiceId = voiceId
        self.includeTimestamp = includeTimestamp
    }
}

// MARK: - List Item Example

/// A numbered list item for reading aloud
///
/// Useful for reading lists, steps, or instructions in order.
public struct ListItem: SpeakableItem {
    public let number: Int
    public let content: String
    public let voiceProvider: VoiceProvider
    public let voiceId: String

    public var textToSpeak: String {
        "Step \(number): \(content)"
    }

    public init(
        number: Int,
        content: String,
        voiceProvider: VoiceProvider,
        voiceId: String
    ) {
        self.number = number
        self.content = content
        self.voiceProvider = voiceProvider
        self.voiceId = voiceId
    }
}

// MARK: - Usage Examples

#if DEBUG
/// Example usage patterns for SpeakableItem implementations
public enum SpeakableItemUsageExamples {
    /// Example: Speaking a simple message
    public static func simpleMessageExample() async throws {
        let provider = AppleVoiceProvider()
        let voices = try await provider.fetchVoices()
        guard let voice = voices.first else { return }

        let message = SimpleMessage(
            content: "Hello, world!",
            voiceProvider: provider,
            voiceId: voice.id
        )

        let audioData = try await message.speak()
        print("Generated \(audioData.count) bytes of audio")
    }

    /// Example: Speaking character dialogue
    public static func characterDialogueExample() async throws {
        let provider = AppleVoiceProvider()
        let voices = try await provider.fetchVoices()
        guard let voice = voices.first else { return }

        let dialogue = CharacterDialogue(
            characterName: "Alice",
            dialogue: "The cake is a lie!",
            voiceProvider: provider,
            voiceId: voice.id,
            includeCharacterName: true
        )

        let duration = await dialogue.estimateDuration()
        print("Estimated duration: \(duration) seconds")

        _ = try await dialogue.speak()
        print("Generated audio for character dialogue")
    }

    /// Example: Speaking multiple items in sequence
    public static func batchSpeakingExample() async throws {
        let provider = AppleVoiceProvider()
        let voices = try await provider.fetchVoices()
        guard let voice = voices.first else { return }

        let items: [ListItem] = [
            ListItem(number: 1, content: "Preheat oven to 350 degrees", voiceProvider: provider, voiceId: voice.id),
            ListItem(number: 2, content: "Mix flour and sugar", voiceProvider: provider, voiceId: voice.id),
            ListItem(number: 3, content: "Bake for 30 minutes", voiceProvider: provider, voiceId: voice.id)
        ]

        let totalDuration = await items.estimateTotalDuration()
        print("Total duration: \(totalDuration) seconds")

        let audioFiles = try await items.speakAll()
        print("Generated \(audioFiles.count) audio files")
    }
}
#endif
