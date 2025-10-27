//
//  GenerateGroupButton.swift
//  SwiftHablare
//
//  A button that generates audio for all items in a SpeakableGroup
//

import SwiftUI
import SwiftData
import SwiftCompartido

/// A button that generates audio for all items in a SpeakableGroup with progress tracking
///
/// This view manages batch generation for grouped speakable content:
/// 1. Checks which items already have audio
/// 2. Shows "Generate All" or "Regenerate All" based on existing audio
/// 3. Skips items with existing audio (unless regenerating)
/// 4. Tracks overall progress as percentage of completed items
/// 5. Uses SpeakableItemList internally for batch processing
///
/// ## Features
///
/// - **Smart Detection**: Automatically detects which items need audio
/// - **Skip Existing**: By default, skips items that already have audio
/// - **State-Aware Button**: Shows appropriate action based on audio status
/// - **Progress Tracking**: Displays "X/Y items (Z%)" during generation
/// - **Cancellation**: User can cancel ongoing batch generation
/// - **Error Handling**: Continues on errors, reports failures at end
///
/// ## Usage
///
/// ```swift
/// struct Chapter: SpeakableGroup {
///     let title: String
///     let dialogueLines: [DialogueLine]
///
///     var groupName: String { title }
///
///     func getGroupedElements() -> [any SpeakableItem] {
///         return dialogueLines // Convert to SpeakableItem array
///     }
/// }
///
/// GenerateGroupButton(
///     group: chapter,
///     service: generationService,
///     modelContext: modelContext,
///     onComplete: { records in
///         print("Generated \(records.count) audio files")
///     }
/// )
/// ```
///
/// ## Button States
///
/// - **Checking...**: Scanning items for existing audio
/// - **Generate All (N items)**: Ready to generate (some items need audio)
/// - **Regenerate All (N items)**: All items have audio, can regenerate
/// - **Generating... X/Y (Z%)**: Active generation with progress
/// - **Complete**: All items generated successfully
/// - **Failed**: Some items failed with errors
///
@MainActor
public struct GenerateGroupButton: View {

    // MARK: - Properties

    /// The speakable group to generate audio for
    public let group: any SpeakableGroup

    /// Generation service for audio generation
    public let service: GenerationService

    /// SwiftData model context for persistence
    public let modelContext: ModelContext

    /// Callback when generation completes successfully
    ///
    /// Receives array of TypedDataStorage records for generated audio.
    /// Records may be fewer than total items if some were skipped.
    public let onComplete: (([TypedDataStorage]) -> Void)?

    // MARK: - State

    /// Current state of the button
    @State private var buttonState: ButtonState = .checking

    /// Items that need audio generation
    @State private var pendingItems: [any SpeakableItem] = []

    /// Items that already have audio
    @State private var existingItems: [any SpeakableItem] = []

    /// Current SpeakableItemList for generation
    @State private var itemList: SpeakableItemList?

    /// Task for checking existing audio
    @State private var checkTask: Task<Void, Never>?

    /// Task for generating audio
    @State private var generateTask: Task<Void, Never>?

    /// Generated records
    @State private var generatedRecords: [TypedDataStorage] = []

    /// Error message for display
    @State private var errorMessage: String?

    // MARK: - Button State

    /// Represents the current state of the button
    enum ButtonState {
        /// Checking for existing audio
        case checking

        /// Ready to generate (some items need audio)
        case readyToGenerate(pendingCount: Int, existingCount: Int)

        /// All items have audio, ready to regenerate
        case readyToRegenerate(totalCount: Int)

        /// Currently generating
        case generating

        /// Generation complete
        case completed(generatedCount: Int, skippedCount: Int)

        /// Generation failed with errors
        case failed(Error)
    }

    // MARK: - Initialization

    /// Create a generate group button
    ///
    /// - Parameters:
    ///   - group: SpeakableGroup to generate audio for
    ///   - service: GenerationService for audio generation
    ///   - modelContext: ModelContext for SwiftData persistence
    ///   - onComplete: Optional callback when generation completes
    public init(
        group: any SpeakableGroup,
        service: GenerationService,
        modelContext: ModelContext,
        onComplete: (([TypedDataStorage]) -> Void)? = nil
    ) {
        self.group = group
        self.service = service
        self.modelContext = modelContext
        self.onComplete = onComplete
    }

    // MARK: - Body

    public var body: some View {
        Group {
            switch buttonState {
            case .checking:
                checkingView
            case .readyToGenerate(let pending, let existing):
                generateButton(pendingCount: pending, existingCount: existing)
            case .readyToRegenerate(let total):
                regenerateButton(totalCount: total)
            case .generating:
                generatingView
            case .completed(let generated, let skipped):
                completedView(generatedCount: generated, skippedCount: skipped)
            case .failed(let error):
                failedView(error: error)
            }
        }
        .task {
            checkTask = Task {
                await checkForExistingAudio()
            }
        }
    }

    // MARK: - View Components

    /// View shown while checking for existing audio
    private var checkingView: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text("Checking...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// Button to generate missing audio
    private func generateButton(pendingCount: Int, existingCount: Int) -> some View {
        Button {
            startGeneration(regenerateAll: false)
        } label: {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Generate All")
                        .font(.body)
                    if existingCount > 0 {
                        Text("\(pendingCount) pending, \(existingCount) complete")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(pendingCount) items")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } icon: {
                Image(systemName: "waveform.circle.fill")
            }
        }
    }

    /// Button to regenerate all audio (all items have audio)
    private func regenerateButton(totalCount: Int) -> some View {
        Button {
            startGeneration(regenerateAll: true)
        } label: {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Regenerate All")
                        .font(.body)
                    Text("\(totalCount) items (all have audio)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "arrow.clockwise.circle.fill")
            }
        }
    }

    /// View shown during generation with progress
    private var generatingView: some View {
        VStack(spacing: 8) {
            if let list = itemList {
                HStack(spacing: 12) {
                    // Progress bar
                    ProgressView(value: list.progress)
                        .progressViewStyle(.linear)

                    // Cancel button
                    Button {
                        cancelGeneration()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                }

                // Progress text
                HStack {
                    Text(String(format: "\(list.currentIndex)/\(list.totalCount) items (%.0f%%)", list.progress * 100))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(list.statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    /// View shown when generation completes
    private func completedView(generatedCount: Int, skippedCount: Int) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Complete")
                        .font(.body)
                    if skippedCount > 0 {
                        Text("\(generatedCount) generated, \(skippedCount) skipped")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(generatedCount) items generated")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Button("Generate Again") {
                startGeneration(regenerateAll: true)
            }
            .font(.caption)
        }
    }

    /// View shown when generation fails
    private func failedView(error: Error) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Failed")
                        .font(.body)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption2)
                            .foregroundStyle(.red)
                            .lineLimit(2)
                    }
                }

                Button("Retry") {
                    startGeneration(regenerateAll: false)
                }
                .font(.caption)
            }
        }
    }

    // MARK: - State Management

    /// Check which items already have audio in SwiftData
    private func checkForExistingAudio() async {
        let allItems = group.getGroupedElements()

        guard !allItems.isEmpty else {
            buttonState = .readyToGenerate(pendingCount: 0, existingCount: 0)
            return
        }

        var pending: [any SpeakableItem] = []
        var existing: [any SpeakableItem] = []

        // Check each item for existing audio
        for item in allItems {
            let hasAudio = await checkItemHasAudio(item)
            if hasAudio {
                existing.append(item)
            } else {
                pending.append(item)
            }
        }

        // Only update state if we're still checking (not generating/cancelled)
        guard case .checking = buttonState else { return }

        self.pendingItems = pending
        self.existingItems = existing

        // Determine button state
        if pending.isEmpty && !existing.isEmpty {
            // All items have audio
            buttonState = .readyToRegenerate(totalCount: existing.count)
        } else {
            // Some or no items have audio
            buttonState = .readyToGenerate(
                pendingCount: pending.count,
                existingCount: existing.count
            )
        }
    }

    /// Check if a single item has existing audio
    private func checkItemHasAudio(_ item: any SpeakableItem) async -> Bool {
        let providerId = item.voiceProvider.providerId
        let voiceId = item.voiceId
        let prompt = item.textToSpeak

        let descriptor = FetchDescriptor<TypedDataStorage>(
            predicate: #Predicate { storage in
                storage.providerId == providerId &&
                storage.voiceID == voiceId &&
                storage.prompt == prompt
            }
        )

        do {
            let results = try modelContext.fetch(descriptor)
            return !results.isEmpty
        } catch {
            return false
        }
    }

    /// Start audio generation
    private func startGeneration(regenerateAll: Bool) {
        // Cancel any existing tasks
        checkTask?.cancel()
        checkTask = nil
        generateTask?.cancel()

        // Determine which items to generate
        let itemsToGenerate: [any SpeakableItem]
        if regenerateAll {
            // Regenerate everything
            itemsToGenerate = group.getGroupedElements()
        } else {
            // Only generate pending items
            itemsToGenerate = pendingItems
        }

        guard !itemsToGenerate.isEmpty else {
            buttonState = .completed(generatedCount: 0, skippedCount: 0)
            return
        }

        // Create SpeakableItemList
        let list = SpeakableItemList(
            name: group.groupName,
            items: itemsToGenerate
        )
        self.itemList = list

        // Update state
        buttonState = .generating
        errorMessage = nil
        generatedRecords = []

        // Create generation task
        generateTask = Task {
            do {
                // Generate all items using SpeakableItemList
                let records = try await service.generateList(
                    list,
                    to: modelContext,
                    saveInterval: 1
                )

                // Check for cancellation
                if Task.isCancelled {
                    buttonState = .readyToGenerate(
                        pendingCount: pendingItems.count,
                        existingCount: existingItems.count
                    )
                    return
                }

                // Store records and update state
                generatedRecords = records
                let skippedCount = regenerateAll ? 0 : existingItems.count
                buttonState = .completed(
                    generatedCount: records.count,
                    skippedCount: skippedCount
                )

                // Call completion handler
                onComplete?(records)

            } catch {
                // Handle error
                if !Task.isCancelled {
                    errorMessage = error.localizedDescription
                    buttonState = .failed(error)
                }
            }
        }
    }

    /// Cancel ongoing generation
    private func cancelGeneration() {
        generateTask?.cancel()
        generateTask = nil
        itemList?.cancel()
        buttonState = .readyToGenerate(
            pendingCount: pendingItems.count,
            existingCount: existingItems.count
        )
    }
}

// MARK: - Preview

#if DEBUG
struct GenerateGroupButton_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            Form {
                if let service = try? makePreviewService(),
                   let context = try? makePreviewContext() {

                    let group = makePreviewGroup()

                    Section("Generate Group") {
                        GenerateGroupButton(
                            group: group,
                            service: service,
                            modelContext: context,
                            onComplete: { records in
                                print("Generated \(records.count) audio files")
                            }
                        )
                    }
                }
            }
            .navigationTitle("Generate Group")
        }
    }

    @MainActor
    static func makePreviewService() throws -> GenerationService {
        return GenerationService()
    }

    @MainActor
    static func makePreviewContext() throws -> ModelContext {
        let schema = Schema([VoiceCacheModel.self, TypedDataStorage.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    static func makePreviewGroup() -> any SpeakableGroup {
        struct PreviewGroup: SpeakableGroup {
            let groupName = "Test Group"
            let items: [SimpleMessage]

            func getGroupedElements() -> [any SpeakableItem] {
                return items
            }
        }

        let provider = AppleVoiceProvider()
        let items = [
            SimpleMessage(
                content: "Hello, world!",
                voiceProvider: provider,
                voiceId: "com.apple.ttsbundle.Samantha-compact"
            ),
            SimpleMessage(
                content: "This is a test.",
                voiceProvider: provider,
                voiceId: "com.apple.ttsbundle.Samantha-compact"
            ),
            SimpleMessage(
                content: "Batch generation works!",
                voiceProvider: provider,
                voiceId: "com.apple.ttsbundle.Samantha-compact"
            )
        ]

        return PreviewGroup(items: items)
    }
}
#endif
