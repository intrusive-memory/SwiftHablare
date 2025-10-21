import Foundation
import Observation

/// Manages background task queueing and execution
@MainActor
@Observable
public final class BackgroundTaskManager {
    // MARK: - Properties

    public var tasks: [BackgroundTask] = []
    public var runningTask: BackgroundTask?

    private var currentExecutingTask: Task<Void, Never>?

    // MARK: - Initialization

    public init() {}

    // MARK: - Task Management

    /// Add a task to the queue
    public func enqueue(_ task: BackgroundTask) {
        tasks.append(task)
    }

    /// Run the next queued task
    /// This will start processing tasks and automatically run subsequent queued tasks in the background
    public func runNext() async {
        // Avoid starting multiple processing loops
        guard currentExecutingTask == nil else { return }

        currentExecutingTask = Task { @MainActor in
            await self.processQueue()
        }
    }

    /// Process all queued tasks sequentially
    private func processQueue() async {
        while let nextTask = tasks.first(where: { $0.state == .queued }) {
            runningTask = nextTask

            // Transition to running state before execution
            nextTask.state = .running

            // Execute the task if it has an executor
            if let executor = nextTask.executor {
                do {
                    try await executor()
                    // Mark as completed after successful execution
                    // (unless the executor changed the state itself, e.g., to cancelled)
                    if nextTask.state == .running {
                        nextTask.state = .completed
                    }
                } catch {
                    nextTask.state = .failed
                    nextTask.error = error
                }
            } else {
                // No executor - just mark as completed (for testing)
                nextTask.state = .completed
            }
        }

        runningTask = nil
        currentExecutingTask = nil
    }

    /// Cancel a specific task
    public func cancelTask(_ task: BackgroundTask) {
        task.cancel()
    }

    /// Clear all completed tasks from the list
    public func clearCompleted() {
        tasks.removeAll { $0.state == .completed }
    }
}
