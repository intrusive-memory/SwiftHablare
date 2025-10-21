import XCTest
@testable import SwiftHablare

@MainActor
final class TaskExecutionIntegrationTests: XCTestCase {
    var manager: BackgroundTaskManager!

    override func setUp() async throws {
        manager = BackgroundTaskManager()
    }

    // MARK: - Full Lifecycle Tests

    func testFullLifecycle_QueueExecuteComplete() async throws {
        // GIVEN
        let task = MockScreenplayTask(name: "Integration Test", totalSteps: 10)

        // WHEN - Queue
        manager.enqueue(task.backgroundTask)
        XCTAssertEqual(task.backgroundTask.state, .queued)

        // WHEN - Execute
        Task {
            await manager.runNext()
        }
        try await Task.sleep(for: .milliseconds(100))

        // THEN - Running with progress
        XCTAssertEqual(task.backgroundTask.state, .running)
        XCTAssertGreaterThan(task.backgroundTask.currentStep, 0)

        // WHEN - Wait for completion
        try await Task.sleep(for: .seconds(1))

        // THEN - Completed
        XCTAssertEqual(task.backgroundTask.state, .completed)
        XCTAssertEqual(task.backgroundTask.currentStep, 10)
    }

    func testFullLifecycle_MultipleTasksInSequence() async throws {
        // GIVEN
        let tasks = (1...5).map { MockScreenplayTask(name: "Task \($0)", totalSteps: 3) }

        // WHEN - Enqueue all
        tasks.forEach { manager.enqueue($0.backgroundTask) }

        // Start execution
        await manager.runNext()

        // Wait for all to complete
        try await Task.sleep(for: .seconds(2))

        // THEN - All completed in order
        for (index, task) in tasks.enumerated() {
            XCTAssertEqual(task.backgroundTask.state, .completed,
                          "Task \(index + 1) should be completed")
        }
    }

    func testFullLifecycle_CancellationPreservesPartialResults() async throws {
        // GIVEN
        let task = MockScreenplayTask(name: "Cancellable Task", totalSteps: 100)
        task.preservePartialResults = true

        // WHEN - Start execution
        manager.enqueue(task.backgroundTask)
        Task {
            await manager.runNext()
        }

        // Wait for some progress
        try await Task.sleep(for: .milliseconds(300))

        let stepBeforeCancel = task.backgroundTask.currentStep
        XCTAssertGreaterThan(stepBeforeCancel, 0)

        // Cancel
        manager.cancelTask(task.backgroundTask)
        try await Task.sleep(for: .milliseconds(100))

        // THEN
        XCTAssertEqual(task.backgroundTask.state, .cancelled)
        XCTAssertGreaterThan(task.backgroundTask.currentStep, 0,
                            "Should preserve progress")
        XCTAssertTrue(task.partialResultsPreserved,
                     "Task should have preserved partial results")
    }
}
