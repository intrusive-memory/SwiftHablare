//
//  VoicePickerView.swift
//  SwiftHablare
//
//  Simple SwiftUI picker for selecting a voice from a specific provider
//

import SwiftUI

/// Simple picker for selecting a voice from a provider
///
/// This view fetches voices from a specific provider using the GenerationService
/// and displays them in a picker with voice details (language, gender).
///
/// ## Usage
///
/// ```swift
/// @State private var selectedVoice: Voice?
///
/// VoicePickerView(
///     service: generationService,
///     providerId: "apple",
///     selection: $selectedVoice
/// )
/// ```
public struct VoicePickerView: View {

    /// The generation service for fetching voices
    public let service: GenerationService

    /// The provider ID to fetch voices from
    public let providerId: String

    /// The currently selected voice ID
    @Binding public var selection: String?

    /// Available voices loaded from the provider
    @State private var voices: [Voice] = []

    /// Whether voices are currently being loaded
    @State private var isLoading = false

    /// Error message if voice loading fails
    @State private var errorMessage: String?

    /// Create a voice picker for a specific provider
    ///
    /// - Parameters:
    ///   - service: GenerationService for fetching voices
    ///   - providerId: Provider ID (e.g., "apple", "elevenlabs")
    ///   - selection: Binding to the selected voice ID
    public init(
        service: GenerationService,
        providerId: String,
        selection: Binding<String?>
    ) {
        self.service = service
        self.providerId = providerId
        self._selection = selection
    }

    public var body: some View {
        Group {
            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.caption)
            } else {
                Picker("Voice", selection: $selection) {
                    Text("Select Voice")
                        .tag(nil as String?)

                    ForEach(voices, id: \.id) { voice in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(voice.name)
                                .font(.body)

                            HStack(spacing: 4) {
                                if let language = voice.language {
                                    Text(language)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                if let gender = voice.gender {
                                    Text("•")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    Text(gender)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                if let locality = voice.locality {
                                    Text("•")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    Text(locality)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .tag(voice.id as String?)
                    }
                }
                .disabled(isLoading)
            }
        }
        .task(id: providerId) {
            await loadVoices()
        }
    }

    /// Load voices from the specified provider
    private func loadVoices() async {
        isLoading = true
        errorMessage = nil

        do {
            voices = try await service.fetchVoices(from: providerId)
        } catch {
            errorMessage = "Failed to load voices: \(error.localizedDescription)"
            voices = []
        }

        isLoading = false
    }
}

// MARK: - Preview

#if DEBUG
import Foundation
import SwiftData

struct VoicePickerView_Previews: PreviewProvider {
    @State static var selectedVoiceId: String?

    static var previews: some View {
        NavigationStack {
            Form {
                if let service = try? makePreviewService() {
                    VoicePickerView(
                        service: service,
                        providerId: "apple",
                        selection: $selectedVoiceId
                    )
                } else {
                    Text("Unable to create preview")
                }
            }
            .navigationTitle("Voice Selection")
        }
    }

    @MainActor
    static func makePreviewService() throws -> GenerationService {
        return GenerationService()
    }
}
#endif
