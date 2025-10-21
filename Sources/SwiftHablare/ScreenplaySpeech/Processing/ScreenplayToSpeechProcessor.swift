import Foundation
import SwiftData
import SwiftGuion

/// Processes a screenplay (GuionDocumentModel) into SpeakableItem instances
///
/// This class implements the full screenplay-to-speech pipeline:
/// - Iterates through GuionElementModel elements
/// - Applies speech logic rules (v1.0)
/// - Tracks scene context for character announcements
/// - Persists SpeakableItem models to SwiftData
@MainActor
public final class ScreenplayToSpeechProcessor {

    /// SwiftData context for persistence
    private let context: ModelContext

    /// Speech logic rules provider
    private let rulesProvider: SpeechLogicRulesV1_0

    /// Initialize the processor
    ///
    /// - Parameters:
    ///   - context: ModelContext for persisting SpeakableItems
    ///   - rulesProvider: Speech logic rules (default: v1.0)
    public init(
        context: ModelContext,
        rulesProvider: SpeechLogicRulesV1_0 = SpeechLogicRulesV1_0()
    ) {
        self.context = context
        self.rulesProvider = rulesProvider
    }

    /// Process a complete screenplay into SpeakableItems
    ///
    /// - Parameter screenplay: The GuionDocumentModel to process
    /// - Returns: Array of generated SpeakableItems (also persisted to context)
    /// - Throws: SwiftData errors during persistence
    public func processScreenplay(_ screenplay: GuionDocumentModel) async throws -> [SpeakableItem] {
        var items: [SpeakableItem] = []
        var sceneContext = SceneContext()
        var index = 0

        // Parse the screenplay rawContent to get properly ordered elements
        // SwiftData relationships don't maintain insertion order
        let parser = FountainParser(string: screenplay.rawContent ?? "")

        // Convert GuionElements to GuionElementModel for processing
        let elements: [GuionElementModel] = parser.elements.map { guionElement in
            let model = GuionElementModel(
                elementText: guionElement.elementText,
                elementType: guionElement.elementType,
                isCentered: guionElement.isCentered,
                isDualDialogue: guionElement.isDualDialogue
            )
            model.sceneId = guionElement.sceneId
            model.sceneNumber = guionElement.sceneNumber
            // Location data will be parsed from elementText by GuionElementModel
            return model
        }

        // Use filename as screenplayID, or a default if not available
        let screenplayID = screenplay.filename ?? "unnamed-screenplay"

        while index < elements.count {
            let element = elements[index]

            // Scene boundary - reset context
            if element.elementType == .sceneHeading {
                sceneContext = SceneContext(sceneID: element.sceneId ?? "unknown-\(index)")

                // Generate scene heading item
                if let item = rulesProvider.processSceneHeading(element, orderIndex: index, screenplayID: screenplayID) {
                    items.append(item)
                }
                index += 1
                continue
            }

            // Dialogue block - group Character + Dialogue lines
            if element.elementType == .character {
                let (dialogueItems, consumed) = rulesProvider.processDialogueBlock(
                    startIndex: index,
                    elements: Array(elements),
                    context: &sceneContext,
                    screenplayID: screenplayID
                )
                items.append(contentsOf: dialogueItems)
                index += consumed
                continue
            }

            // Single element processing (Action, etc.)
            if let item = rulesProvider.processSingleElement(element, orderIndex: index, screenplayID: screenplayID) {
                items.append(item)
            }

            index += 1
        }

        // Persist all items to SwiftData
        for item in items {
            context.insert(item)
        }

        try context.save()

        return items
    }
}
