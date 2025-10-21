import Foundation
@testable import SwiftHablare

@MainActor
class MockScreenplayTask: ScreenplayTask {
    let backgroundTask: BackgroundTask

    var shouldFail = false
    var failureError: Error?
    var executionDelay: Duration = .milliseconds(50)
    var preservePartialResults = false
    var partialResultsPreserved = false

    init(name: String, totalSteps: Int, isBlocking: Bool = false) {
        self.backgroundTask = BackgroundTask(name: name, isBlocking: isBlocking)
        self.backgroundTask.totalSteps = totalSteps

        // Set the executor closure to call this task's execute method
        self.backgroundTask.executor = { [weak self] in
            try await self?.execute()
        }
    }

    func execute() async throws {
        backgroundTask.state = .running

        for step in 1...backgroundTask.totalSteps {
            // Check cancellation
            if backgroundTask.state == .cancelled {
                if preservePartialResults {
                    partialResultsPreserved = true
                }
                return
            }

            backgroundTask.currentStep = step
            backgroundTask.message = "Processing step \(step) of \(backgroundTask.totalSteps)"

            try await Task.sleep(for: executionDelay)

            // Simulate failure midway
            if shouldFail && step == backgroundTask.totalSteps / 2 {
                backgroundTask.state = .failed
                backgroundTask.error = failureError ?? TestError.simulatedFailure
                throw failureError ?? TestError.simulatedFailure
            }
        }

        backgroundTask.state = .completed
        backgroundTask.message = "Completed successfully"
    }

    func cancel() {
        backgroundTask.cancel()
    }
}
