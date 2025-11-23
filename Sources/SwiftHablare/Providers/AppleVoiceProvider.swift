//
//  AppleVoiceProvider.swift
//  SwiftHablare
//
//  Apple Text-to-Speech implementation of VoiceProvider
//

import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

/// Apple Text-to-Speech implementation of VoiceProvider
///
/// **Platform Support:**
/// - **iOS 13+**: Full TTS support with real audio generation using `AVSpeechSynthesizer.write()`
/// - **macOS 10.13+**: Full TTS support with real audio generation using `NSSpeechSynthesizer`
///
/// **Audio Output:**
/// - **iOS**: AIFC format with actual synthesized speech (physical device), AIFF placeholder (simulator)
/// - **macOS**: AIFF format with actual synthesized speech
///
/// **Implementation:**
/// This provider delegates to platform-specific engines:
/// - iOS: `AVSpeechTTSEngine` (using AVSpeechSynthesizer)
/// - macOS: `NSSpeechTTSEngine` (using NSSpeechSynthesizer)
public final class AppleVoiceProvider: VoiceProvider {
    public let providerId = "apple"
    public let displayName = "Apple Text-to-Speech"
    public let requiresAPIKey = false
    public let mimeType = "audio/x-aiff"

    // Engine boundary adapter for platform-specific implementations
    private let engine: AppleTTSEngineBoundary
    private var configuration: AppleTTSConfiguration {
        // Load filter setting from UserDefaults
        let filterEnabled = UserDefaults.standard.bool(forKey: "appleVoiceFilterHighQualityOnly")
        return AppleTTSConfiguration(filterToHighQualityOnly: filterEnabled)
    }

    public init() {
        #if os(iOS) || targetEnvironment(macCatalyst)
        self.engine = AppleTTSEngineBoundary(underlying: AVSpeechTTSEngine())
        #elseif os(macOS)
        self.engine = AppleTTSEngineBoundary(underlying: NSSpeechTTSEngine())
        #else
        fatalError("Unsupported platform for Apple TTS")
        #endif
    }

    public func isConfigured() -> Bool {
        // Apple TTS is always available on supported platforms
        return engine.canGenerate(with: configuration)
    }

    public func fetchVoices(languageCode: String) async throws -> [Voice] {
        return try await engine.fetchVoices(languageCode: languageCode, configuration: configuration)
    }

    public func generateAudio(text: String, voiceId: String, languageCode: String) async throws -> Data {
        let request = engine.makeRequest(text: text, voiceId: voiceId, languageCode: languageCode)
        let output = try await engine.generateAudio(request: request, configuration: configuration)
        return output.audioData
    }

    public func estimateDuration(text: String, voiceId: String) async -> TimeInterval {
        let request = engine.makeRequest(text: text, voiceId: voiceId, languageCode: LanguageCodeResolver.systemLanguageCode)
        return engine.estimateDuration(request: request, configuration: configuration)
    }

    public func isVoiceAvailable(voiceId: String) async -> Bool {
        return await engine.isVoiceAvailable(voiceId: voiceId, configuration: configuration)
    }

#if canImport(SwiftUI)
    @MainActor
    public func makeConfigurationView(onConfigured: @escaping (Bool) -> Void) -> AnyView {
        AnyView(AppleVoiceProviderConfigurationView(provider: self, onConfigured: onConfigured))
    }
#endif
}

#if canImport(SwiftUI)
@MainActor
private struct AppleVoiceProviderConfigurationView: View {
    let provider: AppleVoiceProvider
    let onConfigured: (Bool) -> Void

    @AppStorage("appleVoiceFilterHighQualityOnly") private var filterHighQualityOnly: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "waveform")
                    .font(.largeTitle)
                    .foregroundStyle(Color.accentColor)

                Spacer()
            }

            Text("\(provider.displayName) is ready to use.")
                .font(.headline)

            Text("This provider uses on-device speech synthesis and does not require additional configuration.")
                .font(.callout)
                .foregroundStyle(.secondary)

            Divider()

            // Quality filter toggle
            VStack(alignment: .leading, spacing: 8) {
                Text("Voice Quality Filter")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Toggle(isOn: $filterHighQualityOnly) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Show only Enhanced and Premium voices")
                            .font(.body)

                        Text("Filters out Standard Quality voices to show only higher quality options. Note: Some languages may have limited high-quality voices available.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onChange(of: filterHighQualityOnly) { _, _ in
                    // Notify that configuration changed (triggers voice list refresh)
                    onConfigured(true)
                }
            }
            .padding()
            .background {
                #if os(macOS)
                Color(nsColor: .controlBackgroundColor)
                #else
                Color(uiColor: .secondarySystemGroupedBackground)
                #endif
            }
            .cornerRadius(8)
        }
        .padding()
    }
}
#endif

extension AppleVoiceProvider {
    public static var descriptor: VoiceProviderDescriptor {
        VoiceProviderDescriptor(
            id: "apple",
            displayName: "Apple Text-to-Speech",
            isEnabledByDefault: true,
            isAlwaysEnabled: true,
            requiresConfiguration: false,
            makeProvider: { AppleVoiceProvider() }
        )
    }
}
