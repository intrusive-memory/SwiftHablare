import XCTest
@testable import SwiftHablare

@MainActor
final class BackgroundTaskManagerTests: XCTestCase {
    var manager: BackgroundTaskManager!

    override func setUp() async throws {
        manager = BackgroundTaskManager()
    }

    override func tearDown() async throws {
        manager = nil
    }

    // MARK: - Initialization Tests

    func testManager_InitializesEmpty() {
        XCTAssertTrue(manager.tasks.isEmpty)
        XCTAssertNil(manager.runningTask)
    }

    // MARK: - Task Queueing Tests

    func testManager_EnqueueAddsTask() {
        // GIVEN
        let task = BackgroundTask(name: "Test Task")

        // WHEN
        manager.enqueue(task)

        // THEN
        XCTAssertEqual(manager.tasks.count, 1)
        XCTAssertEqual(manager.tasks.first?.name, "Test Task")
        XCTAssertEqual(manager.tasks.first?.state, .queued)
    }

    func testManager_EnqueueMultipleTasks() {
        // GIVEN
        let task1 = BackgroundTask(name: "Task 1")
        let task2 = BackgroundTask(name: "Task 2")
        let task3 = BackgroundTask(name: "Task 3")

        // WHEN
        manager.enqueue(task1)
        manager.enqueue(task2)
        manager.enqueue(task3)

        // THEN
        XCTAssertEqual(manager.tasks.count, 3)
        XCTAssertEqual(manager.tasks[0].name, "Task 1")
        XCTAssertEqual(manager.tasks[1].name, "Task 2")
        XCTAssertEqual(manager.tasks[2].name, "Task 3")
    }

    // MARK: - Task Execution Tests

    func testManager_ExecutesTask() async throws {
        // GIVEN
        let mockTask = MockScreenplayTask(name: "Test Task", totalSteps: 5)
        let backgroundTask = mockTask.backgroundTask

        // WHEN
        manager.enqueue(backgroundTask)
        await manager.runNext()

        // Wait for completion
        try await Task.sleep(for: .milliseconds(600))

        // THEN
        XCTAssertEqual(backgroundTask.state, .completed)
        XCTAssertEqual(backgroundTask.currentStep, 5)
    }

    func testManager_ExecutesTasksSequentially() async throws {
        // GIVEN
        let task1 = MockScreenplayTask(name: "Task 1", totalSteps: 3)
        let task2 = MockScreenplayTask(name: "Task 2", totalSteps: 3)

        // WHEN
        manager.enqueue(task1.backgroundTask)
        manager.enqueue(task2.backgroundTask)

        await manager.runNext()

        // Check early state - task1 running, task2 still queued
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(task1.backgroundTask.state, .running)
        XCTAssertEqual(task2.backgroundTask.state, .queued)

        // THEN - After sufficient time, both complete in sequence
        // Increased timeout for CI reliability (was 400ms, now 1000ms)
        try await Task.sleep(for: .milliseconds(1000))
        XCTAssertEqual(task1.backgroundTask.state, .completed)
        XCTAssertEqual(task2.backgroundTask.state, .completed)
    }

    func testManager_AutoRunsNextAfterCompletion() async throws {
        // GIVEN
        let task1 = MockScreenplayTask(name: "Task 1", totalSteps: 2)
        let task2 = MockScreenplayTask(name: "Task 2", totalSteps: 2)

        manager.enqueue(task1.backgroundTask)
        manager.enqueue(task2.backgroundTask)

        // WHEN - Run first task, should auto-start second
        await manager.runNext()

        // Wait for both to complete
        try await Task.sleep(for: .milliseconds(600))

        // THEN
        XCTAssertEqual(task1.backgroundTask.state, .completed)
        XCTAssertEqual(task2.backgroundTask.state, .completed)
    }

    // MARK: - Cancellation Tests

    func testManager_CancelsRunningTask() async throws {
        // GIVEN
        let mockTask = MockScreenplayTask(name: "Long Task", totalSteps: 100)
        manager.enqueue(mockTask.backgroundTask)

        // WHEN - Start task then cancel immediately
        Task {
            await manager.runNext()
        }
        try await Task.sleep(for: .milliseconds(100))

        manager.cancelTask(mockTask.backgroundTask)

        // Wait a bit more
        try await Task.sleep(for: .milliseconds(200))

        // THEN
        XCTAssertEqual(mockTask.backgroundTask.state, .cancelled)
        XCTAssertLessThan(mockTask.backgroundTask.currentStep, 100)
    }

    func testManager_CancelsQueuedTask() {
        // GIVEN
        let task = BackgroundTask(name: "Queued Task")
        manager.enqueue(task)

        // WHEN
        manager.cancelTask(task)

        // THEN
        XCTAssertEqual(task.state, .cancelled)
    }

    // MARK: - Error Handling Tests

    func testManager_HandlesTaskFailure() async throws {
        // GIVEN
        let mockTask = MockScreenplayTask(name: "Failing Task", totalSteps: 5)
        mockTask.shouldFail = true
        mockTask.failureError = TestError.simulatedFailure

        // WHEN
        manager.enqueue(mockTask.backgroundTask)
        await manager.runNext()

        try await Task.sleep(for: .milliseconds(600))

        // THEN
        XCTAssertEqual(mockTask.backgroundTask.state, .failed)
        XCTAssertNotNil(mockTask.backgroundTask.error)
    }

    func testManager_ContinuesAfterTaskFailure() async throws {
        // GIVEN
        let failingTask = MockScreenplayTask(name: "Failing Task", totalSteps: 3)
        failingTask.shouldFail = true

        let successTask = MockScreenplayTask(name: "Success Task", totalSteps: 3)

        manager.enqueue(failingTask.backgroundTask)
        manager.enqueue(successTask.backgroundTask)

        // WHEN
        await manager.runNext()

        try await Task.sleep(for: .milliseconds(800))

        // THEN
        XCTAssertEqual(failingTask.backgroundTask.state, .failed)
        XCTAssertEqual(successTask.backgroundTask.state, .completed)
    }

    // MARK: - Clear Completed Tests

    func testManager_ClearsCompletedTasks() async throws {
        // GIVEN
        let task1 = MockScreenplayTask(name: "Task 1", totalSteps: 2)
        let task2 = MockScreenplayTask(name: "Queued Task", totalSteps: 5)

        manager.enqueue(task1.backgroundTask)
        manager.enqueue(task2.backgroundTask)

        await manager.runNext()

        // Wait for task1 to complete but not task2
        // Increased timeout for CI reliability (was 200ms, now 300ms)
        // Task1: 2 steps × 50ms = 100ms, Task2: 5 steps × 50ms = 250ms (starts after task1)
        // Total for task2: 100ms + 250ms = 350ms, so 300ms should catch task1 done, task2 running
        try await Task.sleep(for: .milliseconds(300))

        // WHEN
        manager.clearCompleted()

        // THEN - Task1 should be removed, task2 still in progress
        XCTAssertEqual(manager.tasks.count, 1)
        XCTAssertEqual(manager.tasks.first?.name, "Queued Task")
    }

    func testManager_ClearsFailedTasks() {
        // GIVEN
        let failedTask = BackgroundTask(name: "Failed Task")
        failedTask.state = .failed
        failedTask.error = TestError.simulatedFailure

        let queuedTask = BackgroundTask(name: "Queued Task")

        manager.tasks = [failedTask, queuedTask]

        // WHEN
        manager.clearCompleted()

        // THEN - Failed tasks should NOT be cleared (user needs to see error)
        XCTAssertEqual(manager.tasks.count, 2)
    }
}
