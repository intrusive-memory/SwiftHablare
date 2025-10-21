import SwiftData
import Foundation

@Model
public final class SpeakableItem {
    // MARK: - Identity

    /// Unique identifier for this speakable item
    public var id: UUID

    /// Position in the screenplay (array index in original elements)
    public var orderIndex: Int

    /// Timestamp when this item was created
    public var createdAt: Date

    // MARK: - Source Reference

    /// Reference to the source screenplay document
    /// Links to GuionDocumentModel.id.uuidString for filtering items by screenplay
    public var screenplayID: String

    /// Reference to the source SwiftGuion element(s)
    /// For dialogue blocks, this points to the Character element
    public var sourceElementID: String  // GuionElementModel.sceneId or custom ID

    /// Type of source element (for filtering/debugging)
    public var sourceElementType: String  // "Dialogue", "Action", "Scene Heading"

    /// Scene ID this item belongs to (from GuionElementModel.sceneId)
    public var sceneID: String?

    // MARK: - Speakable Content

    /// The text to be spoken (after applying speech logic rules)
    /// This is the filtered/transformed text, not the raw screenplay text
    public var speakableText: String

    /// Character name if this is dialogue (normalized)
    /// Used for tracking who has spoken and for voice assignment
    public var characterName: String?

    /// Raw character name as it appears in screenplay (e.g., "JOHN (V.O.)")
    public var rawCharacterName: String?

    // MARK: - Speech Logic Metadata

    /// Version of speech logic rules that generated this item
    /// Format: "1.0", "1.1", etc.
    public var ruleVersion: String

    /// Whether character name was included in speakableText
    /// True if this is first dialogue from character in scene
    public var includesCharacterAnnouncement: Bool

    /// Tone hint for TTS (narrative, character, emphasis)
    public var toneHint: ToneHint?

    // MARK: - Audio Generation

    /// Relationship to generated audio (one or more versions)
    @Relationship(deleteRule: .cascade, inverse: \SpeakableAudio.speakableItem)
    public var audioVersions: [SpeakableAudio]

    /// Currently active/preferred audio version
    public var activeAudioID: UUID?

    // MARK: - Status Tracking

    /// Processing status
    public var status: ProcessingStatus

    /// Last updated timestamp
    public var updatedAt: Date

    // MARK: - Initialization

    public init(
        id: UUID = UUID(),
        orderIndex: Int,
        screenplayID: String,
        sourceElementID: String,
        sourceElementType: String,
        sceneID: String? = nil,
        speakableText: String,
        characterName: String? = nil,
        rawCharacterName: String? = nil,
        ruleVersion: String,
        includesCharacterAnnouncement: Bool = false,
        toneHint: ToneHint? = nil,
        status: ProcessingStatus = .textGenerated,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.orderIndex = orderIndex
        self.screenplayID = screenplayID
        self.sourceElementID = sourceElementID
        self.sourceElementType = sourceElementType
        self.sceneID = sceneID
        self.speakableText = speakableText
        self.characterName = characterName
        self.rawCharacterName = rawCharacterName
        self.ruleVersion = ruleVersion
        self.includesCharacterAnnouncement = includesCharacterAnnouncement
        self.toneHint = toneHint
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.audioVersions = []
        self.activeAudioID = nil
    }
}

// MARK: - Supporting Types

public enum ToneHint: String, Codable {
    case narrative      // Scene headings, action lines
    case character      // Dialogue
    case emphasis       // Special emphasis needed
    case parenthetical  // If we decide to speak parentheticals
}

public enum ProcessingStatus: String, Codable {
    case textGenerated      // SpeakableItem created, no audio yet
    case audioQueued        // Queued for audio generation
    case audioGenerating    // Currently generating audio
    case audioComplete      // Audio successfully generated
    case audioFailed        // Audio generation failed
}
