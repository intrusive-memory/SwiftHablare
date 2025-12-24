//
//  VoiceProviderRegistry.swift
//  SwiftHablare
//
//  Central registry for discovering and configuring voice providers.
//

@preconcurrency import Foundation
#if canImport(SwiftUI)
@preconcurrency import SwiftUI
#endif

/// Describes a voice provider that can be registered with the registry.
public struct VoiceProviderDescriptor: Identifiable, @unchecked Sendable {
    public typealias ProviderFactory = @Sendable () -> VoiceProvider

#if canImport(SwiftUI)
    public typealias ConfigurationPanelBuilder = @MainActor @Sendable (_ provider: VoiceProvider, _ onConfigured: @escaping (Bool) -> Void) -> AnyView
#endif

    public let id: String
    public let displayName: String
    public let isEnabledByDefault: Bool
    public let isAlwaysEnabled: Bool
    public let requiresConfiguration: Bool
    public let makeProvider: ProviderFactory
#if canImport(SwiftUI)
    public let configurationPanel: ConfigurationPanelBuilder
#endif

#if canImport(SwiftUI)
    public init(
        id: String,
        displayName: String,
        isEnabledByDefault: Bool,
        isAlwaysEnabled: Bool = false,
        requiresConfiguration: Bool,
        makeProvider: @escaping ProviderFactory,
        configurationPanel: ConfigurationPanelBuilder? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.isEnabledByDefault = isEnabledByDefault
        self.isAlwaysEnabled = isAlwaysEnabled
        self.requiresConfiguration = requiresConfiguration
        self.makeProvider = makeProvider
        self.configurationPanel = configurationPanel ?? { provider, onConfigured in
            provider.makeConfigurationView(onConfigured: onConfigured)
        }
    }
#else
    public init(
        id: String,
        displayName: String,
        isEnabledByDefault: Bool,
        isAlwaysEnabled: Bool = false,
        requiresConfiguration: Bool,
        makeProvider: @escaping ProviderFactory
    ) {
        self.id = id
        self.displayName = displayName
        self.isEnabledByDefault = isEnabledByDefault
        self.isAlwaysEnabled = isAlwaysEnabled
        self.requiresConfiguration = requiresConfiguration
        self.makeProvider = makeProvider
    }
#endif
}

/// Metadata describing a registered provider and its current state.
public struct RegisteredVoiceProvider: Identifiable, Sendable {
    public let descriptor: VoiceProviderDescriptor
    public let isEnabled: Bool
    public let isConfigured: Bool

    public var id: String { descriptor.id }

    public init(descriptor: VoiceProviderDescriptor, isEnabled: Bool, isConfigured: Bool) {
        self.descriptor = descriptor
        self.isEnabled = isEnabled
        self.isConfigured = isConfigured
    }
}

/// Errors thrown by the voice provider registry.
public enum VoiceProviderRegistryError: Error, LocalizedError, Sendable {
    case providerNotRegistered(String)
    case providerDisabled(String)
    case providerNotConfigured(String)

    public var errorDescription: String? {
        switch self {
        case .providerNotRegistered(let id):
            return "Voice provider \(id) is not registered."
        case .providerDisabled(let id):
            return "Voice provider \(id) is currently disabled."
        case .providerNotConfigured(let id):
            return "Voice provider \(id) is not configured."
        }
    }
}

/// Registry responsible for discovering, enabling, and instantiating voice providers.
public actor VoiceProviderRegistry {
    public static let shared = VoiceProviderRegistry()

    private let userDefaults: UserDefaults
    private var descriptors: [String: VoiceProviderDescriptor]

    internal init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        var tempDescriptors: [String: VoiceProviderDescriptor] = [:]

        for descriptor in VoiceProviderRegistry.defaultDescriptors {
            tempDescriptors[descriptor.id] = descriptor
            Self.ensureDefaultStateSync(for: descriptor, in: userDefaults)
        }

        self.descriptors = tempDescriptors
    }

    /// Register an additional provider descriptor.
    ///
    /// - Parameters:
    ///   - descriptor: Descriptor to register.
    ///   - replaceExisting: Whether to replace an existing descriptor with the same identifier.
    public func register(_ descriptor: VoiceProviderDescriptor, replaceExisting: Bool = true) {
        if !replaceExisting, descriptors[descriptor.id] != nil {
            return
        }

        descriptors[descriptor.id] = descriptor
        ensureDefaultState(for: descriptor)
    }

    /// Retrieve the configured provider for the supplied identifier.
    ///
    /// - Parameter providerId: Identifier of the provider.
    /// - Returns: Configured provider ready for use.
    /// - Throws: `VoiceProviderRegistryError` if the provider is missing, disabled, or not configured.
    public func configuredProvider(for providerId: String) async throws -> VoiceProvider {
        guard let descriptor = descriptors[providerId] else {
            throw VoiceProviderRegistryError.providerNotRegistered(providerId)
        }

        guard isEnabled(descriptor: descriptor) else {
            throw VoiceProviderRegistryError.providerDisabled(providerId)
        }

        let provider = descriptor.makeProvider()
        guard await provider.isConfigured() else {
            throw VoiceProviderRegistryError.providerNotConfigured(providerId)
        }

        return provider
    }

    /// Instantiate a provider without checking enablement or configuration.
    public func provider(for providerId: String) -> VoiceProvider? {
        guard let descriptor = descriptors[providerId] else {
            return nil
        }
        return descriptor.makeProvider()
    }

    /// Check whether a provider is currently enabled.
    public func isEnabled(providerId: String) -> Bool {
        guard let descriptor = descriptors[providerId] else {
            return false
        }
        return isEnabled(descriptor: descriptor)
    }

    /// Enable or disable a provider.
    public func setEnabled(_ isEnabled: Bool, for providerId: String) {
        guard let descriptor = descriptors[providerId] else {
            return
        }

        setEnabledIfNeeded(isEnabled, descriptor: descriptor)
    }

    /// Retrieve all registered providers with their enablement and configuration status.
    public func availableProviders() async -> [RegisteredVoiceProvider] {
        let sortedDescriptors = descriptors.values
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }

        var result: [RegisteredVoiceProvider] = []
        for descriptor in sortedDescriptors {
            let provider = descriptor.makeProvider()
            let enabled = isEnabled(descriptor: descriptor)
            let configured = await provider.isConfigured()
            result.append(RegisteredVoiceProvider(
                descriptor: descriptor,
                isEnabled: enabled,
                isConfigured: configured
            ))
        }
        return result
    }

    /// Instantiate all registered providers regardless of configuration state.
    public func instantiateAllProviders() -> [VoiceProvider] {
        descriptors.values.map { $0.makeProvider() }
    }

    /// Determine if a provider descriptor exists for the supplied identifier.
    public func contains(providerId: String) -> Bool {
        descriptors[providerId] != nil
    }

#if canImport(SwiftUI)
    /// Build the configuration view for a provider, if one is available.
    @MainActor
    public func configurationPanel(for providerId: String, onConfigured: @escaping @MainActor (Bool) -> Void) async -> AnyView? {
        // Get descriptor from actor
        guard let descriptor = await getDescriptor(for: providerId) else {
            return nil
        }

        let provider = descriptor.makeProvider()

        return descriptor.configurationPanel(provider) { [weak self] success in
            guard let self else {
                Task { @MainActor in
                    onConfigured(success)
                }
                return
            }

            Task {
                await self.handleConfigurationResult(for: descriptor, provider: provider, success: success)
                await MainActor.run {
                    onConfigured(success)
                }
            }
        }
    }

    /// Internal helper to get descriptor from actor context
    private func getDescriptor(for providerId: String) -> VoiceProviderDescriptor? {
        descriptors[providerId]
    }
#endif

    // MARK: - Private helpers

    private static func ensureDefaultStateSync(for descriptor: VoiceProviderDescriptor, in userDefaults: UserDefaults) {
        let key = "voiceProvider.enabled.\(descriptor.id)"
        if descriptor.isAlwaysEnabled {
            userDefaults.set(true, forKey: key)
        } else if userDefaults.object(forKey: key) == nil {
            userDefaults.set(descriptor.isEnabledByDefault, forKey: key)
        }
    }

    private func ensureDefaultState(for descriptor: VoiceProviderDescriptor) {
        Self.ensureDefaultStateSync(for: descriptor, in: userDefaults)
    }

    private func isEnabled(descriptor: VoiceProviderDescriptor) -> Bool {
        if descriptor.isAlwaysEnabled {
            return true
        }

        if let stored = userDefaults.object(forKey: enabledKey(for: descriptor.id)) as? Bool {
            return stored
        }

        return descriptor.isEnabledByDefault
    }

    private func enabledKey(for providerId: String) -> String {
        "voiceProvider.enabled.\(providerId)"
    }

    private func handleConfigurationResult(for descriptor: VoiceProviderDescriptor, provider: VoiceProvider, success: Bool) async {
        let isConfigured = await provider.isConfigured()
        let shouldEnable = success && isConfigured
        setEnabledIfNeeded(shouldEnable, descriptor: descriptor)
    }

    private func setEnabledIfNeeded(_ enabled: Bool, descriptor: VoiceProviderDescriptor) {
        guard !descriptor.isAlwaysEnabled else {
            return
        }

        userDefaults.set(enabled, forKey: enabledKey(for: descriptor.id))
    }

    private static let defaultDescriptors: [VoiceProviderDescriptor] = [
        AppleVoiceProvider.descriptor,
        ElevenLabsVoiceProvider.descriptor
    ]
}

