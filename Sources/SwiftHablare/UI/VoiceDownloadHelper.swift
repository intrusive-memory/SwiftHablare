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
/// This utility launches an AppleScript that guides users through System Settings
/// to download high-quality voices for Text-to-Speech.
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
        case scriptNotFound
        case scriptExecutionFailed(String)
        case userCancelled

        public var errorDescription: String? {
            switch self {
            case .scriptNotFound:
                return "Voice download script not found. Please ensure download-premium-voices.applescript is in the Scripts directory."
            case .scriptExecutionFailed(let message):
                return "Failed to execute voice download script: \(message)"
            case .userCancelled:
                return "User cancelled voice download"
            }
        }
    }

    /// Prompts user to download Enhanced and Premium voices for their system language
    ///
    /// This launches an interactive AppleScript that:
    /// 1. Opens System Settings → Accessibility → Read & Speak
    /// 2. Opens the voice selection panel
    /// 3. Guides user to download Enhanced/Premium voices
    /// 4. Optionally attempts automatic download
    ///
    /// - Parameter completion: Called when script completes or fails
    public static func promptUserToDownloadPremiumVoices(completion: @escaping (Result<Bool, VoiceDownloadError>) -> Void) {

        // Find the script path
        guard let scriptPath = findScriptPath() else {
            completion(.failure(.scriptNotFound))
            return
        }

        // Execute the AppleScript
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = [scriptPath]

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            do {
                try process.run()
                process.waitUntilExit()

                let exitCode = process.terminationStatus

                if exitCode == 0 {
                    DispatchQueue.main.async {
                        completion(.success(true))
                    }
                } else {
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"

                    DispatchQueue.main.async {
                        if errorMessage.contains("User canceled") || errorMessage.contains("Cancel") {
                            completion(.failure(.userCancelled))
                        } else {
                            completion(.failure(.scriptExecutionFailed(errorMessage)))
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(.scriptExecutionFailed(error.localizedDescription)))
                }
            }
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

    // MARK: - Private Helpers

    private static func findScriptPath() -> String? {
        // Try multiple search paths
        let searchPaths = [
            // Same directory as executable (app bundle)
            Bundle.main.bundlePath + "/Contents/Resources/Scripts/download-premium-voices.applescript",
            // SPM package path (development)
            #file.replacingOccurrences(of: "VoiceDownloadHelper.swift", with: "../../Scripts/download-premium-voices.applescript"),
            // Relative to current working directory
            FileManager.default.currentDirectoryPath + "/Scripts/download-premium-voices.applescript",
            // User's home directory Scripts folder
            NSHomeDirectory() + "/Scripts/download-premium-voices.applescript"
        ]

        for path in searchPaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        return nil
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
