//
//  GenerateAudioButton.swift
//  SwiftHablare
//
//  Standardized button for generating and playing audio from SpeakableItems
//

import SwiftUI
import SwiftData
import SwiftCompartido

/// A standardized button that generates audio for a SpeakableItem and transitions to a play button
///
/// This view manages the complete lifecycle of audio generation:
/// 1. Checks if audio already exists in SwiftData
/// 2. Generates audio on background thread with progress tracking
/// 3. Saves to TypedDataStorage automatically
/// 4. Transitions to Play button when audio is ready
///
/// ## Features
///
/// - **State Management**: Automatically checks for existing audio on appear
/// - **Background Generation**: Uses GenerationService actor for thread-safe generation
/// - **Progress Tracking**: Real-time progress updates during generation
/// - **Cancellation**: User can cancel ongoing generation
/// - **Error Handling**: Shows error state with retry option
/// - **Play Delegation**: Calls onPlay callback (app handles actual playback)
///
/// ## Usage
///
/// ```swift
/// @State private var selectedItem: SpeakableItem
///
/// GenerateAudioButton(
///     item: selectedItem,
///     service: generationService,
///     modelContext: modelContext,
///     onPlay: { audioRecord in
///         // App handles playback
///         playAudio(audioRecord.binaryValue)
///     }
/// )
/// ```
///
/// ## Important Notes
///
/// - SwiftHablare does NOT handle audio playback
/// - Apps are responsible for playing audio via the onPlay callback
/// - Audio is persisted to TypedDataStorage in SwiftData
/// - Generation happens on background thread (actor-isolated)
///
@MainActor
public struct GenerateAudioButton: View {

    // MARK: - Properties

    /// The speakable item to generate audio for
    public let item: any SpeakableItem

    /// Generation service for audio generation
    public let service: GenerationService

    /// SwiftData model context for persistence
    public let modelContext: ModelContext

    /// Optional GuionElementModel to link generated audio to
    ///
    /// When provided, the generated TypedDataStorage will be added to
    /// element.generatedContent to establish the relationship.
    public let element: GuionElementModel?

    /// Callback when play button is tapped
    ///
    /// SwiftHablare does NOT handle playback - the app is responsible.
    /// This callback receives the TypedDataStorage record containing the audio.
    public let onPlay: ((TypedDataStorage) -> Void)?

    // MARK: - State

    /// Current state of the audio
    @State private var audioState: AudioState = .checking

    /// Current generation progress (0.0 to 1.0)
    @State private var progress: Double = 0.0

    /// Current generation task (for cancellation)
    @State private var generationTask: Task<Void, Never>?

    /// Current check task (for cancellation)
    @State private var checkTask: Task<Void, Never>?

    /// Error message for display
    @State private var errorMessage: String?

    // MARK: - Audio State

    /// Represents the current state of audio for the item
    enum AudioState {
        /// Checking if audio already exists in SwiftData
        case checking

        /// No audio exists - ready to generate
        case idle

        /// Currently generating audio
        case generating

        /// Audio exists and is ready to play
        case completed(TypedDataStorage)

        /// Generation failed with error
        case failed(Error)
    }

    // MARK: - Computed Properties

    /// Fetch descriptor for querying existing audio for this item
    private var audioFetchDescriptor: FetchDescriptor<TypedDataStorage> {
        let providerId = item.voiceProvider.providerId
        let voiceId = item.voiceId
        let prompt = item.textToSpeak

        return FetchDescriptor<TypedDataStorage>(
            predicate: #Predicate { storage in
                storage.providerId == providerId &&
                storage.voiceID == voiceId &&
                storage.prompt == prompt
            }
        )
    }

    // MARK: - Initialization

    /// Create a generate audio button
    ///
    /// - Parameters:
    ///   - item: SpeakableItem to generate audio for
    ///   - service: GenerationService for audio generation
    ///   - modelContext: ModelContext for SwiftData persistence
    ///   - element: Optional GuionElementModel to link generated audio to
    ///   - onPlay: Optional callback when play button is tapped
    public init(
        item: any SpeakableItem,
        service: GenerationService,
        modelContext: ModelContext,
        element: GuionElementModel? = nil,
        onPlay: ((TypedDataStorage) -> Void)? = nil
    ) {
        self.item = item
        self.service = service
        self.modelContext = modelContext
        self.element = element
        self.onPlay = onPlay
    }

    // MARK: - Body

    public var body: some View {
        Group {
            switch audioState {
            case .checking:
                checkingView
            case .idle:
                generateButton
            case .generating:
                generatingView
            case .completed(let record):
                playButton(record: record)
            case .failed(let error):
                failedView(error: error)
            }
        }
        .task {
            checkTask = Task { @MainActor in
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

    /// Button to generate audio
    private var generateButton: some View {
        Button {
            startGeneration()
        } label: {
            Label("Generate", systemImage: "waveform.circle")
        }
    }

    /// View shown during generation with progress
    private var generatingView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)

                Button {
                    cancelGeneration()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }

            Text(String(format: "Generating... %.0f%%", progress * 100))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// Play button shown when audio is ready
    private func playButton(record: TypedDataStorage) -> some View {
        Button {
            onPlay?(record)
        } label: {
            Label("Play", systemImage: "play.circle.fill")
        }
    }

    /// View shown when generation fails
    private func failedView(error: Error) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)

                Text("Failed")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    startGeneration()
                } label: {
                    Text("Retry")
                        .font(.caption)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
        }
    }

    // MARK: - State Management

    /// Check if audio already exists in SwiftData
    private func checkForExistingAudio() async {
        do {
            let results = try modelContext.fetch(audioFetchDescriptor)

            // Only update state if we're still checking (not generating/cancelled)
            guard case .checking = audioState else { return }

            if let existingRecord = results.first {
                audioState = .completed(existingRecord)
            } else {
                audioState = .idle
            }
        } catch {
            // Only update state if we're still checking (not generating/cancelled)
            guard case .checking = audioState else { return }

            // If query fails, assume no audio exists
            audioState = .idle
        }
    }

    /// Start audio generation
    private func startGeneration() {
        // Cancel any existing tasks
        checkTask?.cancel()
        checkTask = nil
        generationTask?.cancel()

        // Reset state
        audioState = .generating
        progress = 0.0
        errorMessage = nil

        // Create generation task with explicit MainActor context
        generationTask = Task { @MainActor in
            do {
                // Extract Sendable data from item
                let text = item.textToSpeak
                let voiceId = item.voiceId
                let provider = item.voiceProvider
                let providerId = provider.providerId

                // Re-check for existing audio to prevent race condition
                // Another process might have created it between our initial check and now
                if let existingRecord = try? modelContext.fetch(audioFetchDescriptor).first {
                    // Audio was created by another process - use it
                    audioState = .completed(existingRecord)
                    progress = 1.0
                    return
                }

                // Ensure provider is configured
                guard provider.isConfigured() else {
                    throw VoiceProviderError.notConfigured
                }

                // Update progress to show we've started
                progress = 0.1

                // Generate audio (background thread via provider)
                let audioData = try await provider.generateAudio(
                    text: text,
                    voiceId: voiceId
                )

                // Check for cancellation
                if Task.isCancelled {
                    audioState = .idle
                    return
                }

                // Update progress
                progress = 0.7

                // Estimate duration
                let duration = await provider.estimateDuration(
                    text: text,
                    voiceId: voiceId
                )

                // Update progress
                progress = 0.9

                // Create TypedDataStorage record (on main thread)
                let storage = TypedDataStorage(
                    id: UUID(),
                    providerId: providerId,
                    requestorID: "\(providerId).audio.tts",
                    mimeType: provider.mimeType,
                    textValue: nil,
                    binaryValue: audioData,
                    prompt: text,
                    durationSeconds: duration,
                    voiceID: voiceId,
                    voiceName: nil
                )

                // Insert into SwiftData
                modelContext.insert(storage)

                // Link to GuionElementModel if provided
                if let element = element {
                    if element.generatedContent == nil {
                        element.generatedContent = []
                    }
                    element.generatedContent?.append(storage)
                }

                // Save changes with proper error handling
                do {
                    try modelContext.save()
                } catch {
                    #if DEBUG
                    print("Error saving audio to SwiftData: \(error.localizedDescription)")
                    #endif
                    throw error
                }

                // Update progress to complete
                progress = 1.0

                // Transition to completed state
                audioState = .completed(storage)

            } catch {
                // Handle error
                if !Task.isCancelled {
                    errorMessage = error.localizedDescription
                    audioState = .failed(error)
                }
            }
        }
    }

    /// Cancel ongoing generation
    private func cancelGeneration() {
        generationTask?.cancel()
        generationTask = nil
        audioState = .idle
        progress = 0.0
    }
}

// MARK: - Preview

#if DEBUG
import Foundation

struct GenerateAudioButton_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            Form {
                if let service = try? makePreviewService(),
                   let context = try? makePreviewContext(),
                   let item = try? makePreviewItem() {

                    Section("Generate Audio") {
                        GenerateAudioButton(
                            item: item,
                            service: service,
                            modelContext: context,
                            onPlay: { record in
                                print("Play audio: \(record.id)")
                            }
                        )
                    }
                } else {
                    Text("Unable to create preview")
                }
            }
            .navigationTitle("Generate Audio")
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

    static func makePreviewItem() throws -> any SpeakableItem {
        let provider = AppleVoiceProvider()
        return SimpleMessage(
            content: "Hello, world!",
            voiceProvider: provider,
            voiceId: "com.apple.ttsbundle.Samantha-compact"
        )
    }
}
#endif
