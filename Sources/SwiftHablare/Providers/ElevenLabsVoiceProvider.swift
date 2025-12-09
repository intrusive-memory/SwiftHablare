//
//  ElevenLabsVoiceProvider.swift
//  SwiftHablare
//
//  ElevenLabs implementation of VoiceProvider
//

import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

/// ElevenLabs TTS model options
public enum ElevenLabsModel: String, CaseIterable, Identifiable {
    /// Latest multilingual model (v2) - Highest quality, emotionally-aware, 29 languages
    case multilingualV2 = "eleven_multilingual_v2"

    /// Turbo model (v2.5) - Fastest, optimized for low latency
    case turboV2_5 = "eleven_turbo_v2_5"

    /// Turbo model (v2) - Fast, lower latency
    case turboV2 = "eleven_turbo_v2"

    /// First multilingual model (v1) - Legacy, supports multiple languages
    case multilingualV1 = "eleven_multilingual_v1"

    /// Original English-only model (v1) - Legacy, English only
    case monolingualV1 = "eleven_monolingual_v1"

    public var id: String { rawValue }

    /// Display name for the model
    public var displayName: String {
        switch self {
        case .multilingualV2:
            return "Multilingual v2 (Highest Quality)"
        case .turboV2_5:
            return "Turbo v2.5 (Fastest)"
        case .turboV2:
            return "Turbo v2 (Fast)"
        case .multilingualV1:
            return "Multilingual v1 (Legacy)"
        case .monolingualV1:
            return "Monolingual v1 (English Only, Legacy)"
        }
    }

    /// Description of the model's capabilities
    public var description: String {
        switch self {
        case .multilingualV2:
            return "Latest model with highest quality, emotionally-aware output, supports 29 languages. Best for production use."
        case .turboV2_5:
            return "Fastest model with optimized latency. Good balance of quality and speed."
        case .turboV2:
            return "Fast model with lower latency. Good for real-time applications."
        case .multilingualV1:
            return "First-generation multilingual model. Supports multiple languages but lower quality than v2."
        case .monolingualV1:
            return "Original English-only model. Legacy support only."
        }
    }

    /// Default model (highest quality)
    public static var `default`: ElevenLabsModel {
        .multilingualV2
    }
}

/// ElevenLabs implementation of VoiceProvider
public final class ElevenLabsVoiceProvider: VoiceProvider {
    public let providerId = "elevenlabs"
    public let displayName = "ElevenLabs"
    public let requiresAPIKey = true
    public let mimeType = "audio/mpeg"  // MP3 format from API (processed to M4A by AudioProcessor)

    private let keychainManager = KeychainManager.shared
    private let apiKeyAccount = "elevenlabs-api-key"
    private let ephemeralAPIKey: String?
    private let engine = ElevenLabsEngine()

    /// Initialize with optional ephemeral API key (for testing)
    /// - Parameter apiKey: Optional API key to use instead of keychain (primarily for testing)
    public init(apiKey: String? = nil) {
        self.ephemeralAPIKey = apiKey
    }

    /// User-Agent string for HTTP requests
    private var userAgent: String {
        "\(SwiftHablare.name)/\(SwiftHablare.version)"
    }

    /// Get API key from ephemeral storage (test) or keychain (production)
    private func getAPIKey() throws -> String {
        if let ephemeralKey = ephemeralAPIKey {
            return ephemeralKey
        }
        return try keychainManager.getAPIKey(for: apiKeyAccount)
    }

    public func isConfigured() -> Bool {
        guard let apiKey = try? getAPIKey() else {
            return false
        }
        let configuration = ElevenLabsEngineConfiguration(apiKey: apiKey, userAgent: userAgent)
        return engine.canGenerate(with: configuration)
    }

    public func fetchVoices(languageCode: String) async throws -> [Voice] {
        let configuration = ElevenLabsEngineConfiguration(apiKey: try getAPIKey(), userAgent: userAgent)
        return try await engine.fetchVoices(languageCode: languageCode, configuration: configuration)
    }

    public func generateAudio(text: String, voiceId: String, languageCode: String) async throws -> Data {
        let configuration = ElevenLabsEngineConfiguration(apiKey: try getAPIKey(), userAgent: userAgent)
        let selectedModel = selectedModel()
        let request = engine.makeRequest(text: text, voiceId: voiceId, languageCode: languageCode, options: [
            "model_id": selectedModel.rawValue,
            "stability": "0.5",
            "similarity_boost": "0.5"
        ])
        let output = try await engine.generateAudio(request: request, configuration: configuration)
        return output.audioData
    }

    public func estimateDuration(text: String, voiceId: String) async -> TimeInterval {
        let configuration = ElevenLabsEngineConfiguration(apiKey: (try? getAPIKey()) ?? "", userAgent: userAgent)
        let request = engine.makeRequest(text: text, voiceId: voiceId, languageCode: LanguageCodeResolver.systemLanguageCode, options: [
            "stability": "0.5"
        ])
        return engine.estimateDuration(request: request, configuration: configuration)
    }

    public func isVoiceAvailable(voiceId: String) async -> Bool {
        guard let apiKey = try? getAPIKey() else {
            return false
        }
        let configuration = ElevenLabsEngineConfiguration(apiKey: apiKey, userAgent: userAgent)
        return await engine.isVoiceAvailable(voiceId: voiceId, configuration: configuration)
    }

    /// Retrieve the current API key if one exists.
    public func currentAPIKey() -> String? {
        if let ephemeralAPIKey {
            return ephemeralAPIKey
        }
        return try? keychainManager.getAPIKey(for: apiKeyAccount)
    }

    /// Persist a new API key for ElevenLabs usage.
    public func updateAPIKey(_ apiKey: String) throws {
        guard ephemeralAPIKey == nil else {
            return
        }
        try keychainManager.saveAPIKey(apiKey, for: apiKeyAccount)
    }

    /// Remove the stored API key from secure storage.
    public func clearAPIKey() throws {
        guard ephemeralAPIKey == nil else {
            return
        }
        try keychainManager.deleteAPIKey(for: apiKeyAccount)
    }

    /// Get the currently selected ElevenLabs model
    public func selectedModel() -> ElevenLabsModel {
        guard let modelString = UserDefaults.standard.string(forKey: "elevenlabs-selected-model"),
              let model = ElevenLabsModel(rawValue: modelString) else {
            return .default
        }
        return model
    }

    /// Update the selected ElevenLabs model
    public func updateSelectedModel(_ model: ElevenLabsModel) {
        UserDefaults.standard.set(model.rawValue, forKey: "elevenlabs-selected-model")
    }

#if canImport(SwiftUI)
    @MainActor
    public func makeConfigurationView(onConfigured: @escaping (Bool) -> Void) -> AnyView {
        AnyView(ElevenLabsVoiceProviderConfigurationView(provider: self, onConfigured: onConfigured))
    }
#endif
}

#if canImport(SwiftUI)
@MainActor
private struct ElevenLabsVoiceProviderConfigurationView: View {
    @State private var apiKey: String
    @State private var selectedModel: ElevenLabsModel
    @State private var isProcessing = false
    @State private var errorMessage: String?

    let provider: ElevenLabsVoiceProvider
    let onConfigured: (Bool) -> Void

    init(provider: ElevenLabsVoiceProvider, onConfigured: @escaping (Bool) -> Void) {
        self.provider = provider
        self.onConfigured = onConfigured
        _apiKey = State(initialValue: provider.currentAPIKey() ?? "")
        _selectedModel = State(initialValue: provider.selectedModel())
    }

    var body: some View {
        Form {
            Section(header: Text("API Key")) {
                SecureField("Enter ElevenLabs API Key", text: $apiKey)
                    .textContentType(.password)
                    .disabled(isProcessing)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Picker("Model", selection: $selectedModel) {
                    ForEach(ElevenLabsModel.allCases) { model in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(model.displayName)
                                .font(.body)
                            Text(model.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(model)
                    }
                }
                .onChange(of: selectedModel) { _, newModel in
                    provider.updateSelectedModel(newModel)
                }

                Link(destination: URL(string: "https://elevenlabs.io/docs/speech-synthesis/models")!) {
                    Label("View Model Documentation", systemImage: "book.fill")
                }
            } header: {
                Text("Voice Model")
            } footer: {
                Text(selectedModel.description)
                    .font(.footnote)
            }

            Section {
                Button {
                    saveAPIKey()
                } label: {
                    if isProcessing {
                        ProgressView()
                    } else {
                        Text("Save API Key")
                    }
                }
                .disabled(apiKey.isEmpty || isProcessing)

                Button(role: .destructive) {
                    removeAPIKey()
                } label: {
                    Text("Remove API Key")
                }
                .disabled(isProcessing || provider.currentAPIKey() == nil)
            }
        }
        .navigationTitle(provider.displayName)
    }

    private func saveAPIKey() {
        guard !apiKey.isEmpty else { return }
        isProcessing = true
        errorMessage = nil

        Task { @MainActor in
            do {
                try provider.updateAPIKey(apiKey)
                onConfigured(true)
            } catch {
                errorMessage = error.localizedDescription
                onConfigured(false)
            }

            isProcessing = false
        }
    }

    private func removeAPIKey() {
        isProcessing = true
        errorMessage = nil

        Task { @MainActor in
            do {
                try provider.clearAPIKey()
                apiKey = ""
                onConfigured(false)
            } catch {
                errorMessage = error.localizedDescription
            }

            isProcessing = false
        }
    }
}
#endif

extension ElevenLabsVoiceProvider {
    public static var descriptor: VoiceProviderDescriptor {
        VoiceProviderDescriptor(
            id: "elevenlabs",
            displayName: "ElevenLabs",
            isEnabledByDefault: false,
            requiresConfiguration: true,
            makeProvider: { ElevenLabsVoiceProvider() }
        )
    }
}
