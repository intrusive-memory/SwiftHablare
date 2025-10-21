import Foundation

/// Protocol for tasks that can be executed in the background
@MainActor
public protocol ScreenplayTask {
    /// The background task tracking this work
    var backgroundTask: BackgroundTask { get }

    /// Execute the task
    /// - Throws: Any error that occurs during execution
    func execute() async throws

    /// Cancel the task
    func cancel()
}
