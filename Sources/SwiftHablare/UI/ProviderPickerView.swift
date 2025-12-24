//
//  ProviderPickerView.swift
//  SwiftHablare
//
//  Simple SwiftUI picker for selecting a voice provider from the registry
//

import SwiftUI

/// Simple picker for selecting a voice provider
///
/// This view fetches all registered providers from the GenerationService
/// and displays them in a picker. It shows the provider's display name
/// and configuration status.
///
/// ## Usage
///
/// ```swift
/// @State private var selectedProvider: VoiceProvider?
///
/// ProviderPickerView(
///     service: generationService,
///     selection: $selectedProvider
/// )
/// ```
public struct ProviderPickerView: View {

    /// The generation service containing the provider registry
    public let service: GenerationService

    /// The currently selected provider ID
    @Binding public var selection: String?

    /// Available providers loaded from the service
    @State private var providers: [RegisteredVoiceProvider] = []

    /// Create a provider picker
    ///
    /// - Parameters:
    ///   - service: GenerationService with the provider registry
    ///   - selection: Binding to the selected provider ID
    public init(service: GenerationService, selection: Binding<String?>) {
        self.service = service
        self._selection = selection
    }

    public var body: some View {
        Picker("Voice Provider", selection: $selection) {
            // CRITICAL: Always provide a tag for the current selection to prevent __SwiftValue wrapping
            // This prevents crashes when selection is set before providers load
            if providers.isEmpty, let selection = selection {
                // Provide a temporary tag for the selected provider ID during loading
                Text(selection)
                    .foregroundStyle(.secondary)
                    .tag(selection as String?)
            }

            // Show loading placeholder if providers aren't loaded yet
            if providers.isEmpty {
                Text("Loading providers...")
                    .foregroundStyle(.secondary)
                    .tag(nil as String?)
            }

            // Continue with normal picker content
            if !providers.isEmpty {
                // CRITICAL: Provide fallback tag for selection if it doesn't match any provider
                // This handles case where a provider was disabled after being saved
                if let selection = selection,
                   !providers.contains(where: { $0.descriptor.id == selection }) {
                    Text(selection + " (unavailable)")
                        .foregroundStyle(.secondary)
                        .tag(selection as String?)
                    Divider()
                }

                Text("Select Provider")
                    .tag(nil as String?)

                ForEach(providers) { provider in
                    HStack {
                        Text(provider.descriptor.displayName)

                        if !provider.isEnabled {
                            Image(systemName: "lock.fill")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        } else if !provider.isConfigured {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .font(.caption)
                        }
                    }
                    .foregroundStyle(provider.isEnabled ? .primary : .secondary)
                    .tag(provider.descriptor.id as String?)
                    .disabled(!provider.isEnabled)
                }
            } // End of if !providers.isEmpty
        }
        .task {
            await loadProviders()
        }
    }

    /// Load providers from the registry
    private func loadProviders() async {
        providers = await service.availableProviderStatuses()

        if let selection,
           providers.first(where: { $0.descriptor.id == selection && !$0.isEnabled }) != nil {
            await MainActor.run {
                self.selection = nil
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
import Foundation
import SwiftData

struct ProviderPickerView_Previews: PreviewProvider {
    @State static var selectedProviderId: String?

    static var previews: some View {
        NavigationStack {
            Form {
                if let service = try? makePreviewService() {
                    ProviderPickerView(
                        service: service,
                        selection: $selectedProviderId
                    )
                } else {
                    Text("Unable to create preview")
                }
            }
            .navigationTitle("Provider Selection")
        }
    }

    @MainActor
    static func makePreviewService() throws -> GenerationService {
        return GenerationService()
    }
}
#endif
