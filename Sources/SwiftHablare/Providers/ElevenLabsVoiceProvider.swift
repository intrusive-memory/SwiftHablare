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

/// ElevenLabs implementation of VoiceProvider
public final class ElevenLabsVoiceProvider: VoiceProvider {
    public let providerId = "elevenlabs"
    public let displayName = "ElevenLabs"
    public let requiresAPIKey = true
    public let mimeType = "audio/L16"

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
        let request = engine.makeRequest(text: text, voiceId: voiceId, languageCode: languageCode, options: [
            "model_id": "eleven_monolingual_v1",
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
    @State private var isProcessing = false
    @State private var errorMessage: String?

    let provider: ElevenLabsVoiceProvider
    let onConfigured: (Bool) -> Void

    init(provider: ElevenLabsVoiceProvider, onConfigured: @escaping (Bool) -> Void) {
        self.provider = provider
        self.onConfigured = onConfigured
        _apiKey = State(initialValue: provider.currentAPIKey() ?? "")
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
