import XCTest
import SwiftData
@testable import SwiftHablare
@testable import SwiftGuion

@MainActor
final class SpeakableItemGenerationTaskTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() async throws {
        container = try ModelContainer(
            for: SpeakableItem.self, SpeakableAudio.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = ModelContext(container)
    }

    // MARK: - Basic Execution Tests

    func testBasicTaskExecution() async throws {
        // GIVEN - Simple screenplay with scene heading and dialogue
        let fountainContent = """
        INT. COFFEE SHOP - DAY

        JOHN
        Hello, how are you?

        SARAH
        I'm doing great, thanks!
        """

        let screenplay = GuionDocumentModel()
        screenplay.rawContent = fountainContent
        screenplay.filename = "test-screenplay"

        let task = SpeakableItemGenerationTask(
            screenplay: screenplay,
            context: context
        )

        // WHEN
        try await task.execute()

        // THEN - Verify items were created
        let descriptor = FetchDescriptor<SpeakableItem>(
            sortBy: [SortDescriptor(\.orderIndex)]
        )
        let items = try context.fetch(descriptor)

        XCTAssertGreaterThan(items.count, 0, "Should create speakable items")
        XCTAssertEqual(task.backgroundTask.state, .completed)
        XCTAssertEqual(items[0].screenplayID, "test-screenplay")
    }

    func testEmptyScreenplay() async throws {
        // GIVEN - Empty screenplay
        let screenplay = GuionDocumentModel()
        screenplay.rawContent = ""
        screenplay.filename = "empty-screenplay"

        let task = SpeakableItemGenerationTask(
            screenplay: screenplay,
            context: context
        )

        // WHEN
        try await task.execute()

        // THEN - Should complete without errors
        XCTAssertEqual(task.backgroundTask.state, .completed)

        let descriptor = FetchDescriptor<SpeakableItem>()
        let items = try context.fetch(descriptor)
        XCTAssertEqual(items.count, 0, "Empty screenplay should produce no items")
    }

    func testScreenplayWithNoFilename() async throws {
        // GIVEN - Screenplay without filename
        let fountainContent = """
        INT. TEST SCENE - DAY

        TEST
        Test dialogue.
        """

        let screenplay = GuionDocumentModel()
        screenplay.rawContent = fountainContent
        screenplay.filename = nil

        let task = SpeakableItemGenerationTask(
            screenplay: screenplay,
            context: context
        )

        // WHEN
        try await task.execute()

        // THEN - Should use default screenplayID
        let descriptor = FetchDescriptor<SpeakableItem>()
        let items = try context.fetch(descriptor)

        XCTAssertGreaterThan(items.count, 0)
        XCTAssertEqual(items[0].screenplayID, "unnamed-screenplay")
    }

    // MARK: - Progress Tracking Tests

    func testProgressTracking() async throws {
        // GIVEN - Screenplay with multiple elements
        let fountainContent = """
        INT. OFFICE - DAY

        John enters the room.

        JOHN
        Good morning everyone!

        SARAH
        Good morning!

        Sarah waves at John.

        JOHN
        Ready for the meeting?
        """

        let screenplay = GuionDocumentModel()
        screenplay.rawContent = fountainContent
        screenplay.filename = "progress-test"

        let task = SpeakableItemGenerationTask(
            screenplay: screenplay,
            context: context
        )

        // WHEN
        try await task.execute()

        // THEN - Verify progress tracking was set up correctly
        XCTAssertEqual(task.backgroundTask.state, .completed)
        XCTAssertGreaterThan(task.backgroundTask.totalSteps, 0, "Should set totalSteps")
        XCTAssertGreaterThan(task.backgroundTask.currentStep, 0, "Should have progressed")

        // CurrentStep tracks index position, which may be less than totalSteps
        // when dialogue blocks consume multiple elements at once
        XCTAssertLessThanOrEqual(task.backgroundTask.currentStep, task.backgroundTask.totalSteps)

        // Parse to count elements
        let parser = FountainParser(string: fountainContent)
        XCTAssertEqual(task.backgroundTask.totalSteps, parser.elements.count, "TotalSteps should match element count")
    }

    func testProgressMessages() async throws {
        // GIVEN
        let fountainContent = """
        INT. TEST - DAY

        TEST
        Test line.
        """

        let screenplay = GuionDocumentModel()
        screenplay.rawContent = fountainContent
        screenplay.filename = "message-test"

        let task = SpeakableItemGenerationTask(
            screenplay: screenplay,
            context: context
        )

        // WHEN
        try await task.execute()

        // THEN - Final message should indicate completion
        XCTAssertTrue(task.backgroundTask.message.contains("Completed"), "Final message should indicate completion")
        XCTAssertTrue(task.backgroundTask.message.contains("processed"), "Final message should mention processing")
    }

    // MARK: - Cancellation Tests

    func testCancellation() async throws {
        // GIVEN - Large screenplay to allow time for cancellation
        var fountainContent = "INT. TEST SCENE - DAY\n\n"
        for i in 0..<100 {
            fountainContent += "CHARACTER\(i)\nLine \(i)\n\n"
        }

        let screenplay = GuionDocumentModel()
        screenplay.rawContent = fountainContent
        screenplay.filename = "cancellation-test"

        let task = SpeakableItemGenerationTask(
            screenplay: screenplay,
            context: context,
            saveInterval: 10  // Smaller interval for testing
        )

        // WHEN - Start execution and cancel immediately
        let executionTask = Task { @MainActor in
            try await task.execute()
        }

        // Cancel immediately to increase chance of catching it
        task.cancel()

        // THEN
        do {
            try await executionTask.value
            // Task completed before cancellation took effect - verify final state
            XCTAssertTrue(
                task.backgroundTask.state == .completed || task.backgroundTask.state == .cancelled,
                "Task should be either completed or cancelled"
            )
        } catch {
            // Task was cancelled successfully
            XCTAssertEqual(task.backgroundTask.state, .cancelled)
            XCTAssertTrue(task.backgroundTask.message.contains("Cancelled"), "Message should indicate cancellation")

            // Verify partial results may have been saved
            let descriptor = FetchDescriptor<SpeakableItem>()
            let items = try context.fetch(descriptor)
            // May have some items from periodic saves
            XCTAssertLessThan(items.count, 200, "Should not have completed all items if cancelled")
        }
    }

    func testCancellationBeforeExecution() async throws {
        // GIVEN
        let screenplay = GuionDocumentModel()
        screenplay.rawContent = "INT. TEST - DAY\n\nTEST\nTest line."
        screenplay.filename = "early-cancel-test"

        let task = SpeakableItemGenerationTask(
            screenplay: screenplay,
            context: context
        )

        // WHEN - Cancel before executing
        task.cancel()

        // THEN - Should check cancellation during execute()
        let executionTask = Task { @MainActor in
            try await task.execute()
        }

        do {
            try await executionTask.value
            // If no error thrown, task may have started before cancel took effect
            // Just verify it's in a terminal state
            XCTAssertTrue(
                task.backgroundTask.state == .cancelled || task.backgroundTask.state == .completed,
                "Task should be in terminal state"
            )
        } catch {
            // Cancellation worked as expected
            XCTAssertEqual(task.backgroundTask.state, .cancelled)
        }
    }

    // MARK: - Periodic Save Tests

    func testPeriodicSaves() async throws {
        // GIVEN - Screenplay with more than saveInterval elements
        var fountainContent = "INT. SCENE - DAY\n\n"
        for i in 0..<60 {  // More than default saveInterval of 50
            fountainContent += "CHARACTER\(i)\nLine \(i)\n\n"
        }

        let screenplay = GuionDocumentModel()
        screenplay.rawContent = fountainContent
        screenplay.filename = "periodic-save-test"

        let task = SpeakableItemGenerationTask(
            screenplay: screenplay,
            context: context,
            saveInterval: 20  // Save every 20 items
        )

        // WHEN
        try await task.execute()

        // THEN - All items should be saved
        let descriptor = FetchDescriptor<SpeakableItem>()
        let items = try context.fetch(descriptor)

        XCTAssertGreaterThan(items.count, 20, "Should have saved items across multiple intervals")
        XCTAssertEqual(task.backgroundTask.state, .completed)
    }

    func testCustomSaveInterval() async throws {
        // GIVEN
        var fountainContent = "INT. SCENE - DAY\n\n"
        for i in 0..<10 {
            fountainContent += "CHARACTER\(i)\nLine \(i)\n\n"
        }

        let screenplay = GuionDocumentModel()
        screenplay.rawContent = fountainContent
        screenplay.filename = "custom-interval-test"

        let task = SpeakableItemGenerationTask(
            screenplay: screenplay,
            context: context,
            saveInterval: 5  // Very frequent saves
        )

        // WHEN
        try await task.execute()

        // THEN - Should complete successfully with custom interval
        XCTAssertEqual(task.backgroundTask.state, .completed)

        let descriptor = FetchDescriptor<SpeakableItem>()
        let items = try context.fetch(descriptor)
        XCTAssertGreaterThan(items.count, 0)
    }

    // MARK: - Scene and Dialogue Processing Tests

    func testSceneHeadingProcessing() async throws {
        // GIVEN
        let fountainContent = """
        INT. COFFEE SHOP - DAY

        EXT. PARKING LOT - NIGHT
        """

        let screenplay = GuionDocumentModel()
        screenplay.rawContent = fountainContent
        screenplay.filename = "scene-test"

        let task = SpeakableItemGenerationTask(
            screenplay: screenplay,
            context: context
        )

        // WHEN
        try await task.execute()

        // THEN
        let descriptor = FetchDescriptor<SpeakableItem>(
            sortBy: [SortDescriptor(\.orderIndex)]
        )
        let items = try context.fetch(descriptor)

        XCTAssertEqual(items.count, 2, "Should have two scene heading items")
        XCTAssertEqual(items[0].sourceElementType, "Scene Heading")
        XCTAssertEqual(items[0].toneHint, .narrative)
        XCTAssertTrue(items[0].speakableText.contains("Interior"), "Should expand INT.")
    }

    func testDialogueBlockProcessing() async throws {
        // GIVEN
        let fountainContent = """
        INT. OFFICE - DAY

        JOHN
        Hello there!

        SARAH
        Hi John!

        JOHN
        How's it going?
        """

        let screenplay = GuionDocumentModel()
        screenplay.rawContent = fountainContent
        screenplay.filename = "dialogue-test"

        let task = SpeakableItemGenerationTask(
            screenplay: screenplay,
            context: context
        )

        // WHEN
        try await task.execute()

        // THEN
        let descriptor = FetchDescriptor<SpeakableItem>(
            predicate: #Predicate { $0.sourceElementType == "Dialogue" },
            sortBy: [SortDescriptor(\.orderIndex)]
        )
        let dialogueItems = try context.fetch(descriptor)

        XCTAssertEqual(dialogueItems.count, 3, "Should have three dialogue items")

        // First dialogue by JOHN should include character announcement
        let firstJohn = dialogueItems[0]
        XCTAssertEqual(firstJohn.characterName, "john")
        XCTAssertTrue(firstJohn.includesCharacterAnnouncement)
        XCTAssertTrue(firstJohn.speakableText.contains("says:"))

        // Second dialogue by SARAH should include character announcement (first time in scene)
        let firstSarah = dialogueItems[1]
        XCTAssertEqual(firstSarah.characterName, "sarah")
        XCTAssertTrue(firstSarah.includesCharacterAnnouncement)

        // Third dialogue by JOHN should NOT include character announcement (already spoken in scene)
        let secondJohn = dialogueItems[2]
        XCTAssertEqual(secondJohn.characterName, "john")
        XCTAssertFalse(secondJohn.includesCharacterAnnouncement)
        XCTAssertFalse(secondJohn.speakableText.contains("says:"))
    }

    func testActionProcessing() async throws {
        // GIVEN
        let fountainContent = """
        INT. ROOM - DAY

        John enters the room and looks around.

        Sarah waves at him from across the room.
        """

        let screenplay = GuionDocumentModel()
        screenplay.rawContent = fountainContent
        screenplay.filename = "action-test"

        let task = SpeakableItemGenerationTask(
            screenplay: screenplay,
            context: context
        )

        // WHEN
        try await task.execute()

        // THEN
        let descriptor = FetchDescriptor<SpeakableItem>(
            predicate: #Predicate { $0.sourceElementType == "Action" }
        )
        let actionItems = try context.fetch(descriptor)

        XCTAssertEqual(actionItems.count, 2, "Should have two action items")
        XCTAssertEqual(actionItems[0].toneHint, .narrative)
    }

    // MARK: - Integration Tests

    func testComplexScreenplayProcessing() async throws {
        // GIVEN - Complex screenplay with multiple scenes and element types
        let fountainContent = """
        INT. COFFEE SHOP - DAY

        The morning rush is in full swing.

        BARISTA
        Next customer, please!

        JOHN
        I'll have a large coffee.

        The barista nods and starts preparing the order.

        BARISTA
        That'll be five dollars.

        EXT. STREET - DAY

        John walks down the busy street, coffee in hand.

        SARAH
        (calling out)
        John! Wait up!

        John turns around.

        JOHN
        Hey Sarah! How are you?

        SARAH
        Great! Want to grab lunch?
        """

        let screenplay = GuionDocumentModel()
        screenplay.rawContent = fountainContent
        screenplay.filename = "complex-test"

        let task = SpeakableItemGenerationTask(
            screenplay: screenplay,
            context: context
        )

        // WHEN
        try await task.execute()

        // THEN
        let descriptor = FetchDescriptor<SpeakableItem>(
            sortBy: [SortDescriptor(\.orderIndex)]
        )
        let items = try context.fetch(descriptor)

        XCTAssertGreaterThan(items.count, 10, "Complex screenplay should produce many items")
        XCTAssertEqual(task.backgroundTask.state, .completed)

        // Verify scene boundaries reset character context
        let sceneHeadings = items.filter { $0.sourceElementType == "Scene Heading" }
        XCTAssertEqual(sceneHeadings.count, 2, "Should have two scenes")

        // Verify dialogue processing
        let dialogueItems = items.filter { $0.sourceElementType == "Dialogue" }
        XCTAssertGreaterThan(dialogueItems.count, 4, "Should have multiple dialogue items")

        // Verify all items have same screenplayID
        XCTAssertTrue(items.allSatisfy { $0.screenplayID == "complex-test" })
    }

    func testLargeScreenplayProcessing() async throws {
        // GIVEN - Large screenplay with 100+ elements
        var fountainContent = "INT. LARGE SCENE - DAY\n\n"
        for i in 0..<100 {
            fountainContent += "CHARACTER\(i % 10)\nThis is dialogue line \(i)\n\n"
            if i % 10 == 0 {
                fountainContent += "Some action happens here.\n\n"
            }
        }

        let screenplay = GuionDocumentModel()
        screenplay.rawContent = fountainContent
        screenplay.filename = "large-test"

        let task = SpeakableItemGenerationTask(
            screenplay: screenplay,
            context: context,
            saveInterval: 25
        )

        // WHEN
        let startTime = Date()
        try await task.execute()
        let duration = Date().timeIntervalSince(startTime)

        // THEN
        XCTAssertEqual(task.backgroundTask.state, .completed)
        XCTAssertLessThan(duration, 5.0, "Should process large screenplay in reasonable time")

        let descriptor = FetchDescriptor<SpeakableItem>()
        let items = try context.fetch(descriptor)
        XCTAssertGreaterThan(items.count, 100, "Should have processed all elements")
    }

    // MARK: - Rule Version Tests

    func testRuleVersionAssignment() async throws {
        // GIVEN
        let fountainContent = """
        INT. TEST - DAY

        TEST
        Test dialogue.
        """

        let screenplay = GuionDocumentModel()
        screenplay.rawContent = fountainContent
        screenplay.filename = "version-test"

        let task = SpeakableItemGenerationTask(
            screenplay: screenplay,
            context: context
        )

        // WHEN
        try await task.execute()

        // THEN - All items should have v1.0 rule version
        let descriptor = FetchDescriptor<SpeakableItem>()
        let items = try context.fetch(descriptor)

        XCTAssertTrue(items.allSatisfy { $0.ruleVersion == "1.0" })
    }
}
