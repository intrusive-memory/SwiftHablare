import XCTest
@testable import SwiftHablare

@MainActor
final class BackgroundTaskTests: XCTestCase {

    // MARK: - Initialization Tests

    func testBackgroundTask_InitializesInQueuedState() {
        // GIVEN/WHEN
        let task = BackgroundTask(name: "Test Task", isBlocking: false)

        // THEN
        XCTAssertEqual(task.state, .queued)
        XCTAssertEqual(task.currentStep, 0)
        XCTAssertEqual(task.totalSteps, 0)
        XCTAssertNil(task.error)
        XCTAssertFalse(task.isBlocking)
    }

    func testBackgroundTask_BlockingTaskFlagSet() {
        // GIVEN/WHEN
        let task = BackgroundTask(name: "Blocking Task", isBlocking: true)

        // THEN
        XCTAssertTrue(task.isBlocking)
    }

    // MARK: - State Transition Tests

    func testBackgroundTask_TransitionsQueuedToRunning() {
        // GIVEN
        let task = BackgroundTask(name: "Test Task")

        // WHEN
        task.state = .running

        // THEN
        XCTAssertEqual(task.state, .running)
    }

    func testBackgroundTask_TransitionsRunningToCompleted() {
        // GIVEN
        let task = BackgroundTask(name: "Test Task")
        task.state = .running

        // WHEN
        task.state = .completed

        // THEN
        XCTAssertEqual(task.state, .completed)
        XCTAssertNil(task.error)
    }

    func testBackgroundTask_TransitionsRunningToFailed() {
        // GIVEN
        let task = BackgroundTask(name: "Test Task")
        task.state = .running
        let testError = TestError.simulatedFailure

        // WHEN
        task.state = .failed
        task.error = testError

        // THEN
        XCTAssertEqual(task.state, .failed)
        XCTAssertNotNil(task.error)
    }

    func testBackgroundTask_TransitionsRunningToCancelled() {
        // GIVEN
        let task = BackgroundTask(name: "Test Task")
        task.state = .running

        // WHEN
        task.cancel()

        // THEN
        XCTAssertEqual(task.state, .cancelled)
    }

    // MARK: - Progress Calculation Tests

    func testBackgroundTask_ProgressFractionZeroWhenNoSteps() {
        // GIVEN
        let task = BackgroundTask(name: "Test Task")

        // THEN
        XCTAssertEqual(task.progressFraction, 0.0)
    }

    func testBackgroundTask_ProgressFractionCorrectMidway() {
        // GIVEN
        let task = BackgroundTask(name: "Test Task")

        // WHEN
        task.totalSteps = 100
        task.currentStep = 50

        // THEN
        XCTAssertEqual(task.progressFraction, 0.5, accuracy: 0.001)
    }

    func testBackgroundTask_ProgressPercentageCorrect() {
        // GIVEN
        let task = BackgroundTask(name: "Test Task")
        task.totalSteps = 100
        task.currentStep = 75

        // WHEN
        let percentage = task.progressPercentage

        // THEN
        XCTAssertEqual(percentage, 75)
    }

    func testBackgroundTask_ProgressFractionCapsAt100Percent() {
        // GIVEN
        let task = BackgroundTask(name: "Test Task")
        task.totalSteps = 100

        // WHEN - Overshoot (should not happen, but test defensively)
        task.currentStep = 150

        // THEN
        XCTAssertLessThanOrEqual(task.progressFraction, 1.0)
    }

    // MARK: - Cancellation Tests

    func testBackgroundTask_CancellationSetsState() {
        // GIVEN
        let task = BackgroundTask(name: "Test Task")
        task.state = .running

        // WHEN
        task.cancel()

        // THEN
        XCTAssertEqual(task.state, .cancelled)
    }

    func testBackgroundTask_CanCancelQueuedTask() {
        // GIVEN
        let task = BackgroundTask(name: "Test Task")
        XCTAssertEqual(task.state, .queued)

        // WHEN
        task.cancel()

        // THEN
        XCTAssertEqual(task.state, .cancelled)
    }

    func testBackgroundTask_CannotCancelCompletedTask() {
        // GIVEN
        let task = BackgroundTask(name: "Test Task")
        task.state = .completed

        // WHEN
        task.cancel()

        // THEN - Should remain completed
        XCTAssertEqual(task.state, .completed)
    }
}

enum TestError: Error, LocalizedError {
    case simulatedFailure
    case networkError
    case invalidInput

    var errorDescription: String? {
        switch self {
        case .simulatedFailure: return "Simulated test failure"
        case .networkError: return "Network connection failed"
        case .invalidInput: return "Invalid input provided"
        }
    }
}
