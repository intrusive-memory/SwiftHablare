import Foundation
import Observation

/// Represents the execution state of a background task
public enum TaskState: Equatable {
    case queued
    case running
    case completed
    case failed
    case cancelled
}

/// Observable model representing a background task with progress tracking and state management
@MainActor
@Observable
public final class BackgroundTask: Identifiable {
    // MARK: - Properties

    public let id: UUID
    public let name: String
    public let isBlocking: Bool

    public var state: TaskState
    public var currentStep: Int
    public var totalSteps: Int
    public var message: String
    public var error: Error?

    /// Optional executor closure for tasks with associated work
    var executor: (@MainActor () async throws -> Void)?

    // MARK: - Computed Properties

    /// Progress as a fraction (0.0 to 1.0)
    public var progressFraction: Double {
        guard totalSteps > 0 else { return 0.0 }
        let fraction = Double(currentStep) / Double(totalSteps)
        return min(fraction, 1.0)  // Cap at 100%
    }

    /// Progress as a percentage (0 to 100)
    public var progressPercentage: Int {
        Int(progressFraction * 100)
    }

    // MARK: - Initialization

    public init(name: String, isBlocking: Bool = false) {
        self.id = UUID()
        self.name = name
        self.isBlocking = isBlocking
        self.state = .queued
        self.currentStep = 0
        self.totalSteps = 0
        self.message = ""
    }

    // MARK: - Methods

    /// Cancel the task
    /// - Note: Cannot cancel tasks that are already completed
    public func cancel() {
        // Cannot cancel completed tasks
        guard state != .completed else { return }

        state = .cancelled
    }
}
