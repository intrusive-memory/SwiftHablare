//
//  VoiceDownloadHelper.swift
//  SwiftHablare
//
//  Helper for downloading Enhanced and Premium Apple system voices
//

import Foundation
#if canImport(AppKit)
import AppKit

/// Helper for downloading Enhanced and Premium system voices
///
/// This utility uses the native macOS Help system to guide users through System Settings
/// to download high-quality voices for Text-to-Speech.
///
/// Uses NSHelpManager to open Mac User Guide with visual screenshots and UI highlighting,
/// which is much more reliable than AppleScript UI automation.
///
/// Usage:
/// ```swift
/// VoiceDownloadHelper.promptUserToDownloadPremiumVoices { result in
///     switch result {
///     case .success(let launched):
///         print("Voice download helper launched: \(launched)")
///     case .failure(let error):
///         print("Error: \(error)")
///     }
/// }
/// ```
@available(macOS 26.0, *)
public enum VoiceDownloadHelper {

    /// Error types for voice download operations
    public enum VoiceDownloadError: LocalizedError {
        case settingsOpenFailed
        case userCancelled

        public var errorDescription: String? {
            switch self {
            case .settingsOpenFailed:
                return "Failed to open System Settings. Please open it manually and navigate to Accessibility → Read & Speak → System voice."
            case .userCancelled:
                return "User cancelled voice download"
            }
        }
    }

    /// Prompts user to download Enhanced and Premium voices for their system language
    ///
    /// This uses the native macOS Help system to:
    /// 1. Open System Settings → Accessibility (via URL scheme)
    /// 2. Open Mac User Guide with search for "download Siri voices"
    /// 3. User follows visual guide with screenshots and UI highlights
    ///
    /// This is much more reliable than AppleScript UI automation as:
    /// - Help content is maintained by Apple
    /// - Automatically updates with macOS versions
    /// - Provides visual guidance with screenshots
    /// - No fragile UI element paths that break
    ///
    /// - Parameter completion: Called when help and settings are opened
    public static func promptUserToDownloadPremiumVoices(completion: @escaping @Sendable (Result<Bool, VoiceDownloadError>) -> Void) {

        // Open Accessibility Settings using URL scheme
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.universalaccess") {
            NSWorkspace.shared.open(url)
        } else {
            completion(.failure(.settingsOpenFailed))
            return
        }

        // Wait briefly for Settings to open before showing Help
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Search Mac User Guide for voice download instructions
            // This opens Help window with visual guidance and screenshots
            NSHelpManager.shared.find("download Siri voices", inBook: nil)

            // Success - both Settings and Help are now open
            completion(.success(true))
        }
    }

    /// Checks if Premium/Enhanced voices are available for download
    ///
    /// - Returns: true if system supports Premium voices (macOS 26.0+)
    public static func arePremiumVoicesSupported() -> Bool {
        // Already in @available(macOS 26.0, *) scope
        return true
    }

    /// Gets list of currently installed voices
    ///
    /// - Returns: Array of voice identifiers
    public static func getInstalledVoices() -> [String] {
        return NSSpeechSynthesizer.availableVoices.map { $0.rawValue }
    }

    /// Checks if a specific voice is installed
    ///
    /// - Parameter voiceIdentifier: Voice identifier (e.g., "com.apple.voice.premium.en-US.Jamie")
    /// - Returns: true if installed
    public static func isVoiceInstalled(_ voiceIdentifier: String) -> Bool {
        return NSSpeechSynthesizer.availableVoices.contains { $0.rawValue == voiceIdentifier }
    }

    /// Gets the current system voice identifier
    ///
    /// - Returns: Current system voice identifier
    public static func getCurrentSystemVoice() -> String {
        return NSSpeechSynthesizer.defaultVoice.rawValue
    }

    /// Checks if current system voice is Premium or Enhanced
    ///
    /// - Returns: true if current voice is Premium or Enhanced
    public static func isUsingPremiumVoice() -> Bool {
        let currentVoice = getCurrentSystemVoice()
        return currentVoice.contains("premium") || currentVoice.contains("enhanced")
    }

}

// MARK: - SwiftUI Integration

#if canImport(SwiftUI)
import SwiftUI

/// SwiftUI button that prompts user to download Premium voices
@available(macOS 26.0, *)
public struct DownloadPremiumVoicesButton: View {
    @State private var isDownloading = false
    @State private var errorMessage: String?
    @State private var showingAlert = false

    public var label: String
    public var onCompletion: ((Bool) -> Void)?

    public init(
        label: String = "Download Premium Voices",
        onCompletion: ((Bool) -> Void)? = nil
    ) {
        self.label = label
        self.onCompletion = onCompletion
    }

    public var body: some View {
        Button(action: downloadVoices) {
            Label(label, systemImage: "arrow.down.circle")
        }
        .disabled(isDownloading)
        .alert("Voice Download", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            if let error = errorMessage {
                Text(error)
            } else {
                Text("Voice download helper launched successfully.")
            }
        }
    }

    private func downloadVoices() {
        isDownloading = true

        VoiceDownloadHelper.promptUserToDownloadPremiumVoices { result in
            isDownloading = false

            switch result {
            case .success(let launched):
                showingAlert = true
                errorMessage = nil
                onCompletion?(launched)
            case .failure(let error):
                showingAlert = true
                errorMessage = error.localizedDescription
                onCompletion?(false)
            }
        }
    }
}

#endif // SwiftUI

#endif // macOS
