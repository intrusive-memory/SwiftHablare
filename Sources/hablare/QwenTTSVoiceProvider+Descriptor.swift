//
//  QwenTTSVoiceProvider+Descriptor.swift
//  SwiftHablare
//
//  Registry descriptor for QwenTTSVoiceProvider.
//

import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif
import SwiftHablare

extension QwenTTSVoiceProvider {
    /// Descriptor for registering with VoiceProviderRegistry.
    /// Disabled by default since model download is required.
    public static var descriptor: VoiceProviderDescriptor {
        #if canImport(SwiftUI)
        VoiceProviderDescriptor(
            id: "qwen-tts",
            displayName: "Qwen TTS (Local)",
            isEnabledByDefault: false,
            isAlwaysEnabled: false,
            requiresConfiguration: true,
            makeProvider: { QwenTTSVoiceProvider() },
            configurationPanel: { provider, onConfigured in
                AnyView(
                    VStack(spacing: 12) {
                        Text("Qwen3-TTS Local Model")
                            .font(.headline)
                        Text("This provider runs entirely on-device using Apple Silicon GPU acceleration. Model weights (~1.7GB) must be downloaded before use.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Run 'hablare download' in Terminal to fetch the model.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                )
            }
        )
        #else
        VoiceProviderDescriptor(
            id: "qwen-tts",
            displayName: "Qwen TTS (Local)",
            isEnabledByDefault: false,
            isAlwaysEnabled: false,
            requiresConfiguration: true,
            makeProvider: { QwenTTSVoiceProvider() }
        )
        #endif
    }
}
