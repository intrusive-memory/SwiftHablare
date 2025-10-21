//
//  VoicePickerWidget.swift
//  SwiftHablare
//
//  Voice picker widget for selecting available voices from the current provider
//

import SwiftUI

/// Voice picker widget that displays available voices from the currently selected provider
public struct VoicePickerWidget: View {
    @ObservedObject var providerManager: VoiceProviderManager
    @State private var voices: [Voice] = []
    @State private var selectedVoice: Voice?
    @State private var isLoading = false
    @State private var errorMessage: String?

    public init(providerManager: VoiceProviderManager) {
        self.providerManager = providerManager
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Voice Selection")
                    .font(.headline)

                Spacer()

                // Refresh button
                Button {
                    Task {
                        await loadVoices(forceRefresh: true)
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14))
                }
                .disabled(isLoading)
            }

            // Provider info
            HStack(spacing: 6) {
                Image(systemName: "building.2")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Provider: \(providerManager.currentProviderType.displayName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Voice picker
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.8)
                    Text("Loading voices...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.vertical, 20)
            } else if let error = errorMessage {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else if voices.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "speaker.slash")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("No voices available")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                // Voice list
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(voices) { voice in
                            VoiceRow(
                                voice: voice,
                                isSelected: selectedVoice?.id == voice.id
                            )
                            .onTapGesture {
                                selectedVoice = voice
                            }
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.systemBackgroundColor)
                .shadow(color: .black.opacity(0.1), radius: 10, y: 4)
        )
        .task {
            await loadVoices()
        }
        .onChange(of: providerManager.currentProviderType) { _, _ in
            Task {
                await loadVoices(forceRefresh: true)
            }
        }
    }

    /// Load voices from the current provider
    private func loadVoices(forceRefresh: Bool = false) async {
        isLoading = true
        errorMessage = nil

        do {
            voices = try await providerManager.getVoices(forceRefresh: forceRefresh)
            // Auto-select first voice if none selected
            if selectedVoice == nil, let firstVoice = voices.first {
                selectedVoice = firstVoice
            }
        } catch {
            errorMessage = "Failed to load voices: \(error.localizedDescription)"
            voices = []
            selectedVoice = nil
        }

        isLoading = false
    }
}

/// Row view for displaying a voice in the picker
public struct VoiceRow: View {
    public let voice: Voice
    public let isSelected: Bool

    public var body: some View {
        HStack(spacing: 12) {
            // Selection indicator
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 16))
                .foregroundStyle(isSelected ? .blue : .secondary)
                .frame(width: 20)

            // Voice info
            VStack(alignment: .leading, spacing: 2) {
                Text(voice.name)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .medium : .regular)

                HStack(spacing: 4) {
                    if let language = voice.language {
                        Text(language)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    if let gender = voice.gender {
                        if voice.language != nil {
                            Text("•")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Text(gender.capitalized)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    if let description = voice.description, !description.isEmpty {
                        if voice.language != nil || voice.gender != nil {
                            Text("•")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Text(description)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.blue.opacity(0.1) : Color.systemBackgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}

/// Convenience extension for creating voice picker with bindings
public extension VoicePickerWidget {
    /// Create a voice picker with a binding to the selected voice
    static func withBinding(
        providerManager: VoiceProviderManager,
        selection: Binding<Voice?>
    ) -> some View {
        VoicePickerWithBinding(
            providerManager: providerManager,
            selection: selection
        )
    }
}

/// Voice picker widget with external selection binding
private struct VoicePickerWithBinding: View {
    @ObservedObject var providerManager: VoiceProviderManager
    @Binding var selection: Voice?
    @State private var voices: [Voice] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Voice Selection")
                    .font(.headline)

                Spacer()

                // Refresh button
                Button {
                    Task {
                        await loadVoices(forceRefresh: true)
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14))
                }
                .disabled(isLoading)
            }

            // Provider info
            HStack(spacing: 6) {
                Image(systemName: "building.2")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Provider: \(providerManager.currentProviderType.displayName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Voice picker
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.8)
                    Text("Loading voices...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.vertical, 20)
            } else if let error = errorMessage {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else if voices.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "speaker.slash")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("No voices available")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                // Voice list
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(voices) { voice in
                            VoiceRow(
                                voice: voice,
                                isSelected: selection?.id == voice.id
                            )
                            .onTapGesture {
                                selection = voice
                            }
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.systemBackgroundColor)
                .shadow(color: .black.opacity(0.1), radius: 10, y: 4)
        )
        .task {
            await loadVoices()
        }
        .onChange(of: providerManager.currentProviderType) { _, _ in
            Task {
                await loadVoices(forceRefresh: true)
            }
        }
    }

    /// Load voices from the current provider
    private func loadVoices(forceRefresh: Bool = false) async {
        isLoading = true
        errorMessage = nil

        do {
            voices = try await providerManager.getVoices(forceRefresh: forceRefresh)
            // Auto-select first voice if none selected
            if selection == nil, let firstVoice = voices.first {
                selection = firstVoice
            }
        } catch {
            errorMessage = "Failed to load voices: \(error.localizedDescription)"
            voices = []
            selection = nil
        }

        isLoading = false
    }
}
