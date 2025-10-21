import Foundation
import SwiftData
import SwiftGuion

/// Task that generates SpeakableItems from a screenplay with progress tracking and cancellation support
///
/// This task wraps the ScreenplayToSpeechProcessor and provides:
/// - Progress reporting per element processed
/// - Cancellation support
/// - Periodic saves (every 50 elements) to prevent data loss
/// - Integration with BackgroundTaskManager
@MainActor
public final class SpeakableItemGenerationTask: ScreenplayTask {

    // MARK: - Properties

    public let backgroundTask: BackgroundTask

    private let screenplay: GuionDocumentModel
    private let context: ModelContext
    private let rulesProvider: SpeechLogicRulesV1_0
    private let saveInterval: Int

    // MARK: - Initialization

    /// Initialize the task
    ///
    /// - Parameters:
    ///   - screenplay: The screenplay document to process
    ///   - context: SwiftData context for persistence
    ///   - rulesProvider: Speech logic rules (defaults to v1.0)
    ///   - saveInterval: Number of elements to process before saving (default: 50)
    public init(
        screenplay: GuionDocumentModel,
        context: ModelContext,
        rulesProvider: SpeechLogicRulesV1_0 = SpeechLogicRulesV1_0(),
        saveInterval: Int = 50
    ) {
        self.screenplay = screenplay
        self.context = context
        self.rulesProvider = rulesProvider
        self.saveInterval = saveInterval
        self.backgroundTask = BackgroundTask(
            name: "Generate Speakable Items",
            isBlocking: true
        )

        // Set up executor to call this task's execute method
        self.backgroundTask.executor = { [weak self] in
            try await self?.execute()
        }
    }

    // MARK: - ScreenplayTask Protocol

    public func execute() async throws {
        backgroundTask.state = .running
        backgroundTask.message = "Parsing screenplay..."

        // Parse the screenplay to get elements
        let parser = FountainParser(string: screenplay.rawContent ?? "")
        let elements: [GuionElementModel] = parser.elements.map { guionElement in
            let model = GuionElementModel(
                elementText: guionElement.elementText,
                elementType: guionElement.elementType,
                isCentered: guionElement.isCentered,
                isDualDialogue: guionElement.isDualDialogue
            )
            model.sceneId = guionElement.sceneId
            model.sceneNumber = guionElement.sceneNumber
            return model
        }

        backgroundTask.totalSteps = elements.count
        backgroundTask.currentStep = 0
        backgroundTask.message = "Processing \(elements.count) elements..."

        // Use filename as screenplayID, or a default if not available
        let screenplayID = screenplay.filename ?? "unnamed-screenplay"
        var items: [SpeakableItem] = []
        var sceneContext = SceneContext()
        var index = 0
        var itemsProcessedSinceLastSave = 0

        while index < elements.count {
            // Check for cancellation
            guard backgroundTask.state == .running else {
                backgroundTask.message = "Cancelled after processing \(index) of \(elements.count) elements"
                throw CancellationError()
            }

            let element = elements[index]

            // Update progress
            backgroundTask.currentStep = index + 1
            backgroundTask.message = "Processing element \(index + 1) of \(elements.count)"

            // Scene boundary - reset context
            if element.elementType == .sceneHeading {
                sceneContext = SceneContext(sceneID: element.sceneId ?? "unknown-\(index)")

                // Generate scene heading item
                if let item = rulesProvider.processSceneHeading(element, orderIndex: index, screenplayID: screenplayID) {
                    items.append(item)
                    itemsProcessedSinceLastSave += 1
                }
                index += 1
            }
            // Dialogue block - group Character + Dialogue lines
            else if element.elementType == .character {
                let (dialogueItems, consumed) = rulesProvider.processDialogueBlock(
                    startIndex: index,
                    elements: Array(elements),
                    context: &sceneContext,
                    screenplayID: screenplayID
                )
                items.append(contentsOf: dialogueItems)
                itemsProcessedSinceLastSave += dialogueItems.count
                index += consumed
            }
            // Single element processing (Action, etc.)
            else {
                if let item = rulesProvider.processSingleElement(element, orderIndex: index, screenplayID: screenplayID) {
                    items.append(item)
                    itemsProcessedSinceLastSave += 1
                }
                index += 1
            }

            // Periodic save
            if itemsProcessedSinceLastSave >= saveInterval {
                try await performPeriodicSave(items: items)
                items.removeAll()  // Clear items that have been saved
                itemsProcessedSinceLastSave = 0
                backgroundTask.message = "Saved checkpoint at element \(index) of \(elements.count)"
            }
        }

        // Final save for any remaining items
        if !items.isEmpty {
            try await performPeriodicSave(items: items)
        }

        backgroundTask.state = .completed
        backgroundTask.message = "Completed: \(elements.count) elements processed"
    }

    public func cancel() {
        backgroundTask.cancel()
    }

    // MARK: - Private Methods

    private func performPeriodicSave(items: [SpeakableItem]) async throws {
        // Insert all items into context
        for item in items {
            context.insert(item)
        }

        // Save to persistent store
        try context.save()
    }
}

// MARK: - Error Types

private struct CancellationError: Error {}
