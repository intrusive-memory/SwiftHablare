//
//  GenerateAudioButtonExample.swift
//  SwiftHablare
//
//  Complete example demonstrating GenerateAudioButton usage
//

import SwiftUI
import SwiftData
import AVFoundation
import SwiftCompartido

/// Example view demonstrating GenerateAudioButton with multiple items
///
/// This example shows:
/// - Setting up SwiftData with required models
/// - Creating speakable items
/// - Using GenerateAudioButton in a list
/// - Handling audio playback (app responsibility)
///
@MainActor
public struct GenerateAudioButtonExample: View {

    // MARK: - Dependencies

    /// SwiftData model context (required for persistence)
    @Environment(\.modelContext) private var modelContext

    /// Generation service (create once, reuse)
    @State private var service: GenerationService?

    // MARK: - State

    /// List of messages to generate audio for
    @State private var messages: [SimpleMessage] = []

    /// Selected provider ID
    @State private var selectedProviderId: String?

    /// Selected voice ID
    @State private var selectedVoiceId: String?

    /// Audio player (app's responsibility to manage)
    @State private var audioPlayer: AVAudioPlayer?

    /// Currently playing item ID
    @State private var playingItemId: String?

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            Form {
                // Provider Selection
                providerSection

                // Voice Selection
                if let providerId = selectedProviderId {
                    voiceSection(providerId: providerId)
                }

                // Messages List
                if !messages.isEmpty {
                    messagesSection
                }

                // Add Message Button
                addMessageSection
            }
            .navigationTitle("Audio Generation Example")
            .task {
                setupService()
            }
        }
    }

    // MARK: - View Sections

    /// Provider selection section
    private var providerSection: some View {
        Section("1. Select Provider") {
            if let service {
                ProviderPickerView(
                    service: service,
                    selection: $selectedProviderId
                )
            } else {
                Text("Loading providers...")
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Voice selection section
    private func voiceSection(providerId: String) -> some View {
        Section("2. Select Voice") {
            if let service {
                VoicePickerView(
                    service: service,
                    providerId: providerId,
                    selection: $selectedVoiceId
                )
            }
        }
    }

    /// Messages section with generate buttons
    private var messagesSection: some View {
        Section("3. Generated Messages") {
            ForEach(messages, id: \.id) { message in
                messageRow(message)
            }
            .onDelete(perform: deleteMessages)
        }
    }

    /// Add message section
    private var addMessageSection: some View {
        Section("4. Add Message") {
            Button {
                Task {
                    await addMessage()
                }
            } label: {
                Label("Add Random Message", systemImage: "plus.circle.fill")
            }
            .disabled(selectedProviderId == nil || selectedVoiceId == nil)
        }
    }

    /// Individual message row with generate/play button
    private func messageRow(_ message: SimpleMessage) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(message.content)
                    .font(.body)

                Text("Voice: \(message.voiceId)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            if let service {
                GenerateAudioButton(
                    item: message,
                    service: service,
                    modelContext: modelContext,
                    onPlay: { record in
                        playAudio(from: record, for: message.id)
                    }
                )
            }
        }
        .padding(.vertical, 4)
        .background(
            playingItemId == message.id
                ? Color.accentColor.opacity(0.1)
                : Color.clear
        )
    }

    // MARK: - Actions

    /// Setup generation service
    private func setupService() {
        if service == nil {
            service = GenerationService()
        }
    }

    /// Add a new message with random content
    private func addMessage() async {
        guard let providerId = selectedProviderId,
              let voiceId = selectedVoiceId,
              let service = service else {
            return
        }

        guard let provider = service.provider(withId: providerId) else {
            return
        }

        let samples = [
            "Hello, this is a test message.",
            "Welcome to SwiftHablare audio generation!",
            "This is an example of text-to-speech.",
            "Press play to hear this message.",
            "Audio generation is working perfectly.",
            "This demonstrates the GenerateAudioButton component."
        ]

        let randomContent = samples.randomElement() ?? "Test message"

        let message = SimpleMessage(
            content: randomContent,
            voiceProvider: provider,
            voiceId: voiceId
        )

        withAnimation {
            messages.append(message)
        }
    }

    /// Delete messages
    private func deleteMessages(at offsets: IndexSet) {
        withAnimation {
            messages.remove(atOffsets: offsets)
        }
    }

    /// Play audio from a TypedDataStorage record
    ///
    /// **Note**: SwiftHablare does NOT handle playback.
    /// This is the app's responsibility.
    private func playAudio(from record: TypedDataStorage, for itemId: String) {
        guard let audioData = record.binaryValue else {
            print("No audio data in record")
            return
        }

        do {
            // Stop current playback
            audioPlayer?.stop()

            // Create new player
            audioPlayer = try AVAudioPlayer(data: audioData)
            audioPlayer?.prepareToPlay()

            // Update playing state
            playingItemId = itemId

            // Play audio
            audioPlayer?.play()

            // Clear playing state when done
            DispatchQueue.main.asyncAfter(deadline: .now() + (audioPlayer?.duration ?? 0)) {
                if playingItemId == itemId {
                    playingItemId = nil
                }
            }

        } catch {
            print("Failed to play audio: \(error)")
            playingItemId = nil
        }
    }
}

// MARK: - SimpleMessage Extension

extension SimpleMessage {
    /// Unique identifier for SwiftUI list
    var id: String {
        "\(voiceId)-\(content)".hashValue.description
    }
}

// MARK: - Preview

#if DEBUG
struct GenerateAudioButtonExample_Previews: PreviewProvider {
    static var previews: some View {
        if let container = try? makePreviewContainer() {
            GenerateAudioButtonExample()
                .modelContainer(container)
        } else {
            Text("Unable to create preview")
        }
    }

    @MainActor
    static func makePreviewContainer() throws -> ModelContainer {
        let schema = Schema([
            VoiceCacheModel.self,
            TypedDataStorage.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
#endif

// MARK: - Usage Documentation

/*

## Complete Setup Example

To use GenerateAudioButton in your app, follow these steps:

### 1. Configure SwiftData Schema

```swift
import SwiftUI
import SwiftData
import SwiftHablare
import SwiftCompartido

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            VoiceCacheModel.self,      // Required for voice caching
            TypedDataStorage.self      // Required for audio persistence
        ])
    }
}
```

### 2. Create Your View

```swift
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var service = GenerationService()

    var body: some View {
        let provider = AppleVoiceProvider()
        let message = SimpleMessage(
            content: "Hello, world!",
            voiceProvider: provider,
            voiceId: "com.apple.ttsbundle.Samantha-compact"
        )

        GenerateAudioButton(
            item: message,
            service: service,
            modelContext: modelContext,
            onPlay: { record in
                // Handle playback (your responsibility)
                playAudio(record.binaryValue)
            }
        )
    }

    func playAudio(_ data: Data?) {
        // Implement your audio playback logic
        // Example: Use AVAudioPlayer, AVPlayer, etc.
    }
}
```

### 3. Custom SpeakableItem Types

```swift
struct Article: SpeakableItem {
    let title: String
    let content: String
    let voiceProvider: VoiceProvider
    let voiceId: String

    var textToSpeak: String {
        "\(title). \(content)"
    }
}

// Use it
let article = Article(
    title: "Breaking News",
    content: "This is the article content.",
    voiceProvider: AppleVoiceProvider(),
    voiceId: "voice-id"
)

GenerateAudioButton(
    item: article,
    service: service,
    modelContext: modelContext,
    onPlay: { record in
        playAudio(record.binaryValue)
    }
)
```

### 4. Batch Generation with List

```swift
struct MessagesView: View {
    @Environment(\.modelContext) private var modelContext
    let messages: [SimpleMessage]
    let service = GenerationService()

    var body: some View {
        List(messages, id: \.id) { message in
            HStack {
                Text(message.content)
                Spacer()
                GenerateAudioButton(
                    item: message,
                    service: service,
                    modelContext: modelContext,
                    onPlay: { record in
                        playAudio(record.binaryValue)
                    }
                )
            }
        }
    }
}
```

### Key Points

- ✅ GenerateAudioButton handles generation and persistence automatically
- ✅ Audio is saved to TypedDataStorage in SwiftData
- ✅ Button automatically checks for existing audio on appear
- ✅ Progress is shown during generation
- ✅ User can cancel ongoing generation
- ✅ Play button appears when audio is ready
- ❌ SwiftHablare does NOT handle playback (app's responsibility)

*/
