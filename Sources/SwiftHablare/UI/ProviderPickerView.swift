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
    @State private var providers: [VoiceProvider] = []

    /// Whether providers are currently being loaded
    @State private var isLoading = false

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
            Text("Select Provider")
                .tag(nil as String?)

            ForEach(providers, id: \.providerId) { provider in
                HStack {
                    Text(provider.displayName)

                    if !provider.isConfigured() {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                    }
                }
                .tag(provider.providerId as String?)
            }
        }
        .task {
            await loadProviders()
        }
    }

    /// Load providers from the registry
    private func loadProviders() async {
        isLoading = true
        providers = await service.registeredProviders()
        isLoading = false
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
