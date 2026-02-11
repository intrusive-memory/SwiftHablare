// HablareCLI.swift
// hablare CLI: text-to-speech using registered voice providers

import ArgumentParser
import Foundation
import SwiftHablare

@main
struct HablareCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "hablare",
        abstract: "Text-to-speech using registered voice providers",
        version: "6.0.0",
        subcommands: [Providers.self],
        defaultSubcommand: Providers.self
    )
}

// MARK: - Providers

struct Providers: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "List registered voice providers and their status"
    )

    func run() async throws {
        let registry = VoiceProviderRegistry.shared
        let providers = await registry.availableProviders()

        if providers.isEmpty {
            print("No voice providers registered.")
            return
        }

        print("Registered voice providers:")
        print("===========================")
        for provider in providers {
            let status: String
            if provider.isEnabled && provider.isConfigured {
                status = "ready"
            } else if provider.isEnabled {
                status = "enabled (not configured)"
            } else {
                status = "disabled"
            }
            print("  \(provider.descriptor.displayName) [\(provider.descriptor.id)] — \(status)")
        }
    }
}
