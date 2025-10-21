import Foundation
import SwiftData
import SwiftGuion

/// Speech Logic Rules Version 1.0
///
/// Processes GuionElementModel instances and generates SpeakableItem models
/// according to the v1.0 speech logic specification.
public final class SpeechLogicRulesV1_0 {

    /// Version identifier for these rules
    public let version = "1.0"

    /// Character announcement format template
    private let characterAnnouncementFormat = "%@ says:"  // "JOHN says:"

    /// Element types to skip (not speakable)
    private let nonSpeakableTypes: Set<ElementType> = [
        .parenthetical,
        .transition,
        .comment,
        .boneyard,
        .synopsis,
        .pageBreak
    ]

    /// Check if element type is a section heading (special handling due to associated value)
    private func isNonSpeakable(_ type: ElementType) -> Bool {
        if case .sectionHeading = type {
            return true
        }
        return nonSpeakableTypes.contains(type)
    }

    /// Character normalizer for consistent character name handling
    private let normalizer = CharacterNormalizer()

    public init() {}

    // MARK: - Public Processing Methods

    /// Process a scene heading element into a SpeakableItem
    public func processSceneHeading(_ element: GuionElementModel, orderIndex: Int, screenplayID: String = "unknown") -> SpeakableItem? {
        // Use cached location data if available
        var text = element.elementText

        if let lighting = element.locationLighting,
           let scene = element.locationScene {
            // Transform "INT." -> "Interior"
            let lightingText = lighting == "INT" ? "Interior" : (lighting == "EXT" ? "Exterior" : lighting)
            let timeOfDay = element.locationTimeOfDay ?? ""
            text = "\(lightingText). \(scene). \(timeOfDay)."
        } else {
            // Fallback: basic transformation
            text = text
                .replacingOccurrences(of: "INT.", with: "Interior.")
                .replacingOccurrences(of: "EXT.", with: "Exterior.")
        }

        return SpeakableItem(
            orderIndex: orderIndex,
            screenplayID: screenplayID,
            sourceElementID: element.sceneId ?? "unknown",
            sourceElementType: "Scene Heading",
            sceneID: element.sceneId,
            speakableText: text,
            ruleVersion: version,
            toneHint: .narrative
        )
    }

    /// Process a dialogue block (Character + optional Parenthetical + Dialogue lines)
    ///
    /// - Parameters:
    ///   - startIndex: Index of the Character element
    ///   - elements: Array of all elements
    ///   - context: Scene context for tracking character announcements
    ///   - screenplayID: ID of the screenplay document
    /// - Returns: Tuple of (generated items, number of elements consumed)
    public func processDialogueBlock(
        startIndex: Int,
        elements: [GuionElementModel],
        context: inout SceneContext,
        screenplayID: String = "unknown"
    ) -> (items: [SpeakableItem], consumed: Int) {
        var index = startIndex

        // 1. Character element
        guard index < elements.count,
              elements[index].elementType == .character else {
            return ([], 1)
        }

        let characterElement = elements[index]
        let rawCharacterName = characterElement.elementText
        let normalizedName = normalizer.normalize(rawCharacterName)
        index += 1

        // 2. Skip optional parenthetical (per rules - not spoken)
        if index < elements.count && elements[index].elementType == .parenthetical {
            index += 1
        }

        // 3. Collect all consecutive dialogue lines
        var dialogueLines: [String] = []
        while index < elements.count && elements[index].elementType == .dialogue {
            dialogueLines.append(elements[index].elementText)
            index += 1
        }

        guard !dialogueLines.isEmpty else {
            return ([], index - startIndex)
        }

        // 4. Combine dialogue lines
        let combinedDialogue = dialogueLines.joined(separator: " ")

        // 5. Determine if character announcement needed
        let isFirstTimeInScene = !context.hasCharacterSpoken(normalizedName)

        // 6. Build speakable text
        let speakableText: String
        if isFirstTimeInScene {
            speakableText = String(format: characterAnnouncementFormat, rawCharacterName) + " " + combinedDialogue
        } else {
            speakableText = combinedDialogue
        }

        // 7. Create SpeakableItem
        let item = SpeakableItem(
            orderIndex: startIndex,
            screenplayID: screenplayID,
            sourceElementID: characterElement.sceneId ?? "unknown",
            sourceElementType: "Dialogue",
            sceneID: context.sceneID,
            speakableText: speakableText,
            characterName: normalizedName,
            rawCharacterName: rawCharacterName,
            ruleVersion: version,
            includesCharacterAnnouncement: isFirstTimeInScene,
            toneHint: .character
        )

        // 8. Update context
        context.markCharacterSpoken(normalizedName)
        context.lastSpeaker = normalizedName

        return ([item], index - startIndex)
    }

    /// Process a single element (Action, etc.)
    public func processSingleElement(_ element: GuionElementModel, orderIndex: Int, screenplayID: String = "unknown") -> SpeakableItem? {
        // Skip non-speakable types
        guard !isNonSpeakable(element.elementType) else {
            return nil
        }

        // Only process Action for now
        guard element.elementType == .action else {
            return nil
        }

        return SpeakableItem(
            orderIndex: orderIndex,
            screenplayID: screenplayID,
            sourceElementID: element.sceneId ?? "unknown",
            sourceElementType: element.elementType.description,
            sceneID: element.sceneId,
            speakableText: element.elementText,
            ruleVersion: version,
            toneHint: .narrative
        )
    }
}
