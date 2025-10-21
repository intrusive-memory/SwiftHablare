import SwiftUI

/// Displays a single background task with progress, status, and error information
@MainActor
struct BackgroundTaskRow: View {
    @Bindable var task: BackgroundTask

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Task info
            HStack {
                if task.isBlocking {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.orange)
                        .help("This task blocks other operations")
                }

                Text(task.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                if task.state == .running {
                    Button("Cancel") {
                        task.cancel()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            // Progress
            if task.state == .running {
                ProgressView(value: task.progressFraction) {
                    Text("\(task.currentStep)/\(task.totalSteps) - \(task.message)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Error
            if let error = task.error {
                HStack(alignment: .top, spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.caption)

                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            // Status badge
            StatusBadge(state: task.state)
        }
        .padding()
        .background(Color.systemBackgroundColor)
        .cornerRadius(8)
    }
}

/// Badge showing the current task state
@MainActor
struct StatusBadge: View {
    let state: TaskState

    var body: some View {
        HStack(spacing: 4) {
            stateIcon
            Text(stateText)
                .font(.caption2)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(backgroundColor)
        .foregroundStyle(foregroundColor)
        .cornerRadius(4)
    }

    @ViewBuilder
    private var stateIcon: some View {
        switch state {
        case .queued:
            Image(systemName: "clock.fill")
        case .running:
            Image(systemName: "play.circle.fill")
        case .completed:
            Image(systemName: "checkmark.circle.fill")
        case .failed:
            Image(systemName: "xmark.circle.fill")
        case .cancelled:
            Image(systemName: "stop.circle.fill")
        }
    }

    private var stateText: String {
        switch state {
        case .queued: return "Queued"
        case .running: return "Running"
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        }
    }

    private var backgroundColor: Color {
        switch state {
        case .queued: return Color.gray.opacity(0.2)
        case .running: return Color.blue.opacity(0.2)
        case .completed: return Color.green.opacity(0.2)
        case .failed: return Color.red.opacity(0.2)
        case .cancelled: return Color.orange.opacity(0.2)
        }
    }

    private var foregroundColor: Color {
        switch state {
        case .queued: return .gray
        case .running: return .blue
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .orange
        }
    }
}

#Preview("Running Task") {
    let task = BackgroundTask(name: "Generating SpeakableItems", isBlocking: true)
    task.state = .running
    task.totalSteps = 100
    task.currentStep = 68
    task.message = "Processing Scene Heading..."

    return BackgroundTaskRow(task: task)
        .frame(width: 400)
        .padding()
}

#Preview("Queued Task") {
    let task = BackgroundTask(name: "Generate Audio")
    task.state = .queued

    return BackgroundTaskRow(task: task)
        .frame(width: 400)
        .padding()
}

#Preview("Failed Task") {
    let task = BackgroundTask(name: "Export Audiobook")
    task.state = .failed
    task.error = NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No audio files available"])

    return BackgroundTaskRow(task: task)
        .frame(width: 400)
        .padding()
}

#Preview("Completed Task") {
    let task = BackgroundTask(name: "Generate SpeakableItems")
    task.state = .completed
    task.totalSteps = 100
    task.currentStep = 100
    task.message = "Completed successfully"

    return BackgroundTaskRow(task: task)
        .frame(width: 400)
        .padding()
}
