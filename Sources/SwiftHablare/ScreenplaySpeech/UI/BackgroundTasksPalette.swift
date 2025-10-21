import SwiftUI

/// Floating palette that displays and manages background tasks
@MainActor
public struct BackgroundTasksPalette: View {
    @Bindable var manager: BackgroundTaskManager

    public init(manager: BackgroundTaskManager) {
        self.manager = manager
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Label("Background Tasks", systemImage: "list.bullet.rectangle")
                    .font(.headline)
                Spacer()
                Button("Clear Completed") {
                    manager.clearCompleted()
                }
                .disabled(!hasCompletedTasks)
            }

            // Task list
            if manager.tasks.isEmpty {
                emptyState
            } else {
                ForEach(manager.tasks) { task in
                    BackgroundTaskRow(task: task)
                }
            }
        }
        .padding()
        .frame(minWidth: 400, maxWidth: 500)
        .background(.regularMaterial)
        .cornerRadius(12)
        .shadow(radius: 8)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Tasks")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Background tasks will appear here")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private var hasCompletedTasks: Bool {
        manager.tasks.contains { $0.state == .completed }
    }
}

// MARK: - Previews

#Preview("Empty") {
    BackgroundTasksPalette(manager: BackgroundTaskManager())
        .frame(width: 500, height: 300)
}

#Preview("Running Task") {
    let manager = BackgroundTaskManager()
    let task = BackgroundTask(name: "Generating SpeakableItems", isBlocking: true)
    task.state = .running
    task.totalSteps = 100
    task.currentStep = 68
    task.message = "Processing Scene Heading..."
    manager.tasks = [task]

    return BackgroundTasksPalette(manager: manager)
        .frame(width: 500, height: 300)
}

#Preview("Multiple States") {
    let manager = BackgroundTaskManager()

    let running = BackgroundTask(name: "Generate SpeakableItems", isBlocking: true)
    running.state = .running
    running.totalSteps = 100
    running.currentStep = 75
    running.message = "Processing dialogue..."

    let queued = BackgroundTask(name: "Generate Audio")
    queued.state = .queued

    let failed = BackgroundTask(name: "Export Audiobook")
    failed.state = .failed
    failed.error = NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No audio files available"])

    manager.tasks = [running, queued, failed]

    return BackgroundTasksPalette(manager: manager)
        .frame(width: 500, height: 400)
}

#Preview("Blocking Task") {
    let manager = BackgroundTaskManager()
    let task = BackgroundTask(name: "Critical Task", isBlocking: true)
    task.state = .running
    task.totalSteps = 50
    task.currentStep = 25
    task.message = "Processing..."
    manager.tasks = [task]

    return BackgroundTasksPalette(manager: manager)
        .frame(width: 500, height: 300)
}
