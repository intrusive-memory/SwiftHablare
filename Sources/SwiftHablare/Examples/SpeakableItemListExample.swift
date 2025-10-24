//
//  SpeakableItemListExample.swift
//  SwiftHablare
//
//  Complete working example of SpeakableItemList with progress tracking
//  and SwiftData persistence integration.
//

#if DEBUG
import SwiftUI
import SwiftData
import SwiftCompartido

/// ViewModel for managing SpeakableItemList generation
///
/// This example demonstrates:
/// - Creating a SpeakableItemList with mixed item types
/// - Generating audio with progress tracking
/// - Persisting to SwiftData via TypedDataStorage
/// - Cancellation support
/// - Error handling
/// - UI updates via @Observable
@Observable
@MainActor
public final class SpeakableItemListExampleViewModel {
    // MARK: - Properties

    /// The current list being processed
    public var list: SpeakableItemList?

    /// Whether generation is currently in progress
    public var isGenerating: Bool = false

    /// Generated records from the last successful run
    public var generatedRecords: [TypedDataStorage] = []

    /// Error message if generation failed
    public var errorMessage: String?

    /// The generation service
    private let service: GenerationService

    /// SwiftData model context
    private let modelContext: ModelContext

    /// Voice provider
    private let provider: VoiceProvider

    // MARK: - Initialization

    public init(provider: VoiceProvider, modelContext: ModelContext) {
        self.provider = provider
        self.service = GenerationService(voiceProvider: provider)
        self.modelContext = modelContext
    }

    // MARK: - Public Methods

    /// Create a sample list with mixed SpeakableItem types
    public func createSampleList() async throws {
        let voices = try await provider.fetchVoices()
        guard let voiceId = voices.first?.id else {
            throw VoiceProviderError.invalidResponse
        }

        let items: [any SpeakableItem] = [
            SimpleMessage(
                content: "Hello! Welcome to the SpeakableItemList example.",
                voiceProvider: provider,
                voiceId: voiceId
            ),
            Article(
                title: "Breaking News",
                author: "Jane Reporter",
                content: "This is an example of an article being converted to speech with metadata.",
                voiceProvider: provider,
                voiceId: voiceId,
                includeMeta: true
            ),
            CharacterDialogue(
                characterName: "Alice",
                dialogue: "How are you doing today?",
                voiceProvider: provider,
                voiceId: voiceId,
                includeCharacterName: true
            ),
            CharacterDialogue(
                characterName: "Bob",
                dialogue: "I'm doing great, thanks for asking!",
                voiceProvider: provider,
                voiceId: voiceId,
                includeCharacterName: true
            ),
            Notification(
                title: "Reminder",
                message: "Don't forget to check your calendar.",
                voiceProvider: provider,
                voiceId: voiceId,
                includeTimestamp: false
            ),
            ListItem(
                number: 1,
                content: "First, gather your ingredients",
                voiceProvider: provider,
                voiceId: voiceId
            ),
            ListItem(
                number: 2,
                content: "Second, preheat the oven to 350 degrees",
                voiceProvider: provider,
                voiceId: voiceId
            ),
            ListItem(
                number: 3,
                content: "Third, mix the dry ingredients",
                voiceProvider: provider,
                voiceId: voiceId
            ),
            SimpleMessage(
                content: "That's all for now. Thank you for trying SwiftHablaré!",
                voiceProvider: provider,
                voiceId: voiceId
            )
        ]

        list = SpeakableItemList(name: "Sample Speech List", items: items)
    }

    /// Generate audio for all items in the list
    public func generate() async {
        guard let list = list else {
            errorMessage = "No list to generate"
            return
        }

        isGenerating = true
        errorMessage = nil
        generatedRecords = []

        do {
            let records = try await service.generateList(list, to: modelContext)
            generatedRecords = records
            print("✅ Successfully generated \(records.count) audio files")

        } catch {
            errorMessage = error.localizedDescription
            print("❌ Generation failed: \(error)")

            // Even on error, we have partial results saved
            if list.currentIndex > 0 {
                print("ℹ️  Saved \(list.currentIndex) items before error")
            }
        }

        isGenerating = false
    }

    /// Cancel the current generation
    public func cancel() {
        list?.cancel()
    }

    /// Reset the list to start over
    public func reset() {
        list?.reset()
        generatedRecords = []
        errorMessage = nil
    }

    /// Fetch all audio records from SwiftData
    public func fetchAllRecords() throws {
        let descriptor = FetchDescriptor<TypedDataStorage>(
            predicate: #Predicate { record in
                record.mimeType.starts(with: "audio/")
            }
        )

        generatedRecords = try modelContext.fetch(descriptor)
    }

    /// Delete all audio records
    public func deleteAllRecords() throws {
        for record in generatedRecords {
            modelContext.delete(record)
        }
        try modelContext.save()
        generatedRecords = []
    }
}

// MARK: - SwiftUI Example View

/// Example SwiftUI view demonstrating SpeakableItemList
public struct SpeakableItemListExampleView: View {
    @Bindable var viewModel: SpeakableItemListExampleViewModel

    public init(viewModel: SpeakableItemListExampleViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let list = viewModel.list {
                    // Progress Section
                    listProgressView(for: list)

                    // Action Buttons
                    actionButtons(for: list)

                    // Error Message
                    if let error = viewModel.errorMessage {
                        errorView(error)
                    }

                    // Generated Records
                    if !viewModel.generatedRecords.isEmpty {
                        recordsList
                    }

                } else {
                    emptyStateView
                }
            }
            .padding()
            .navigationTitle("SpeakableItemList Example")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu("Actions") {
                        Button("Create Sample List") {
                            Task {
                                try? await viewModel.createSampleList()
                            }
                        }

                        if viewModel.list != nil {
                            Button("Reset") {
                                viewModel.reset()
                            }

                            Button("Fetch All Records") {
                                try? viewModel.fetchAllRecords()
                            }

                            if !viewModel.generatedRecords.isEmpty {
                                Button("Delete All Records", role: .destructive) {
                                    try? viewModel.deleteAllRecords()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - View Components

    @ViewBuilder
    private func listProgressView(for list: SpeakableItemList) -> some View {
        VStack(spacing: 12) {
            Text(list.name)
                .font(.headline)

            ProgressView(value: list.progress)
                .progressViewStyle(.linear)
                .tint(list.hasFailed ? .red : list.isComplete ? .green : .blue)

            HStack {
                Label("\(list.currentIndex)/\(list.totalCount)", systemImage: "list.number")
                    .font(.caption)

                Spacer()

                Text("\(Int(list.progress * 100))%")
                    .font(.caption)
                    .monospacedDigit()
            }

            Text(list.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if list.isComplete {
                Label("Generation Complete", systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.green)
            } else if list.hasFailed {
                Label("Generation Failed", systemImage: "xmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.red)
            } else if list.isCancelled {
                Label("Generation Cancelled", systemImage: "stop.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.secondary.opacity(0.1))
        )
    }

    @ViewBuilder
    private func actionButtons(for list: SpeakableItemList) -> some View {
        HStack(spacing: 12) {
            if viewModel.isGenerating {
                Button("Cancel", action: viewModel.cancel)
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(list.isCancelled)
            } else if list.isComplete || list.hasFailed || list.isCancelled {
                Button("Reset & Try Again", action: viewModel.reset)
                    .buttonStyle(.bordered)
            } else {
                Button("Generate Audio", action: {
                    Task { await viewModel.generate() }
                })
                .buttonStyle(.borderedProminent)
            }
        }
    }

    @ViewBuilder
    private func errorView(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Error", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.bold())
                .foregroundStyle(.red)

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red.opacity(0.1))
        )
    }

    @ViewBuilder
    private var recordsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Generated Audio (\(viewModel.generatedRecords.count))")
                .font(.headline)

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.generatedRecords, id: \.id) { record in
                        recordRow(for: record)
                    }
                }
            }
            .frame(maxHeight: 300)
        }
    }

    @ViewBuilder
    private func recordRow(for record: TypedDataStorage) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(record.prompt)
                .font(.subheadline)
                .lineLimit(2)

            HStack {
                Label(record.providerId, systemImage: "waveform")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                if let duration = record.durationSeconds {
                    Text(String(format: "%.1fs", duration))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let size = record.binaryValue?.count {
                    Text(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.15))
        )
    }

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform.circle")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("No List Created")
                .font(.headline)

            Text("Tap 'Actions' → 'Create Sample List' to get started")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxHeight: .infinity)
    }
}

// MARK: - Usage Example in App

/// Example usage in a SwiftUI App
///
/// ```swift
/// import SwiftUI
/// import SwiftData
/// import SwiftHablare
/// import SwiftCompartido
///
/// @main
/// struct MyApp: App {
///     var body: some Scene {
///         WindowGroup {
///             SpeakableItemListDemoView()
///                 .modelContainer(for: TypedDataStorage.self)
///         }
///     }
/// }
///
/// struct SpeakableItemListDemoView: View {
///     @Environment(\.modelContext) private var modelContext
///     @State private var viewModel: SpeakableItemListExampleViewModel?
///
///     var body: some View {
///         Group {
///             if let viewModel = viewModel {
///                 SpeakableItemListExampleView(viewModel: viewModel)
///             } else {
///                 ProgressView("Initializing...")
///             }
///         }
///         .task {
///             let provider = AppleVoiceProvider()
///             viewModel = SpeakableItemListExampleViewModel(
///                 provider: provider,
///                 modelContext: modelContext
///             )
///         }
///     }
/// }
/// ```
public enum SpeakableItemListUsageExample {
    // Placeholder for documentation
}

#endif
