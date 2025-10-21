//
//  VoiceSettingsWidget.swift
//  SwiftHablare
//
//  Settings widget for configuring API keys and provider settings
//

import SwiftUI
import AVFoundation

/// Settings widget for configuring voice provider API keys
public struct VoiceSettingsWidget: View {
    @State private var elevenLabsAPIKey: String = ""
    @State private var isAPIKeySaved = false
    @State private var errorMessage: String?
    @State private var appleVoices: [Voice] = []
    @State private var isLoadingVoices = false

    public init() {}

    public var body: some View {
        Form {
            Section(header: Text("Apple Text-to-Speech")) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("System Voices")
                            .font(.headline)

                        Spacer()

                        if isLoadingVoices {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Text("\(appleVoices.count) available")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if !appleVoices.isEmpty {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(appleVoices.prefix(5)) { voice in
                                    HStack(spacing: 8) {
                                        Image(systemName: "waveform.circle.fill")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(voice.name)
                                            .font(.caption)
                                        if let description = voice.description {
                                            Text("•")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            Text(description)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }

                                if appleVoices.count > 5 {
                                    Text("+ \(appleVoices.count - 5) more voices")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                        .padding(.leading, 24)
                                }
                            }
                        }
                        .frame(maxHeight: 120)
                    }

                    Button(action: openSystemVoiceSettings) {
                        Label("Manage System Voices", systemImage: "gearshape")
                    }

                    Text("Download additional voices in System Settings to use with this app")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }

            Section(header: Text("ElevenLabs Configuration")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("API Key")
                        .font(.headline)

                    SecureField("Enter your ElevenLabs API key", text: $elevenLabsAPIKey)
                        .textFieldStyle(.roundedBorder)

                    HStack {
                        Button(action: saveAPIKey) {
                            Label("Save", systemImage: "checkmark.circle")
                        }
                        .disabled(elevenLabsAPIKey.isEmpty)

                        Button(action: clearAPIKey) {
                            Label("Clear", systemImage: "trash")
                        }
                        .disabled(!KeychainManager.shared.hasAPIKey(for: "elevenlabs"))

                        Spacer()

                        if isAPIKeySaved {
                            Label("Saved", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }

                    Text("Current: \(KeychainManager.shared.getObfuscatedAPIKey(for: "elevenlabs"))")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                .padding(.vertical, 8)

                Text("Get your API key from [ElevenLabs Dashboard](https://elevenlabs.io/app/settings/api-keys)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section(header: Text("About")) {
                LabeledContent("Library", value: "SwiftHablare")
                LabeledContent("Version", value: SwiftHablare.version)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 400, minHeight: 400)
        .onAppear {
            // Check if API key exists on appear
            if KeychainManager.shared.hasAPIKey(for: "elevenlabs") {
                isAPIKeySaved = true
            }

            // Load Apple voices
            Task {
                await loadAppleVoices()
            }
        }
    }

    private func saveAPIKey() {
        do {
            try KeychainManager.shared.saveAPIKey(elevenLabsAPIKey, for: "elevenlabs")
            isAPIKeySaved = true
            errorMessage = nil

            // Clear the text field after saving
            elevenLabsAPIKey = ""

            // Reset the saved indicator after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                isAPIKeySaved = false
            }
        } catch {
            errorMessage = "Failed to save API key: \(error.localizedDescription)"
            isAPIKeySaved = false
        }
    }

    private func clearAPIKey() {
        do {
            try KeychainManager.shared.deleteAPIKey(for: "elevenlabs")
            elevenLabsAPIKey = ""
            isAPIKeySaved = false
            errorMessage = nil
        } catch {
            errorMessage = "Failed to clear API key: \(error.localizedDescription)"
        }
    }

    private func loadAppleVoices() async {
        isLoadingVoices = true
        defer { isLoadingVoices = false }

        do {
            let provider = AppleVoiceProvider()
            appleVoices = try await provider.fetchVoices()
        } catch {
            // Silently fail - voices will show as empty
            appleVoices = []
        }
    }

    private func openSystemVoiceSettings() {
        #if os(macOS)
        // Open System Settings > Accessibility > Spoken Content
        // This is where users can download and manage high-quality voices
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.speech") {
            #if canImport(AppKit)
            NSWorkspace.shared.open(url)
            #endif
        }
        #elseif os(iOS)
        // On iOS/Catalyst, open Settings app to Accessibility > Spoken Content
        if let url = URL(string: "App-prefs:root=ACCESSIBILITY&path=SPEECH") {
            #if canImport(UIKit)
            UIApplication.shared.open(url)
            #endif
        }
        #endif
    }
}

#Preview {
    VoiceSettingsWidget()
}
