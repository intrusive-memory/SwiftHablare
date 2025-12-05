import Testing
import SwiftUI
@testable import SwiftHablare

@Suite("VoiceProviderRegistry")
struct VoiceProviderRegistryTests {
    private let suiteName = "VoiceProviderRegistryTests_\(UUID().uuidString)"

    @Test("Default descriptors are loaded")
    func testDefaultDescriptorsLoaded() async {
        let registry = TestFixtures.makeVoiceProviderRegistry(suiteName: suiteName)
        let providers = await registry.availableProviders()
        let identifiers = Set(providers.map { $0.descriptor.id })

        #expect(identifiers.contains("apple"))
        #expect(identifiers.contains("elevenlabs"))

        let apple = providers.first { $0.descriptor.id == "apple" }
        #expect(apple != nil)
        #expect(apple?.descriptor.displayName == "Apple Text-to-Speech")
        #expect(apple?.isEnabled ?? false)
        #expect(apple?.isConfigured ?? false)

        let eleven = providers.first { $0.descriptor.id == "elevenlabs" }
        #expect(eleven != nil)
        #expect(eleven?.descriptor.displayName == "ElevenLabs")
        #expect(!(eleven?.isEnabled ?? true))
        #expect(!(eleven?.isConfigured ?? true))
    }

    @Test("Configured provider retrieval")
    func testConfiguredProviderRetrieval() async throws {
        let registry = TestFixtures.makeVoiceProviderRegistry(suiteName: suiteName)
        let apple = try await registry.configuredProvider(for: "apple")
        #expect(apple.displayName == "Apple Text-to-Speech")
        #expect(apple.isConfigured())
    }

    @Test("Configured provider requires enablement")
    func testConfiguredProviderRequiresEnablement() async {
        let registry = TestFixtures.makeVoiceProviderRegistry(suiteName: suiteName)
        await registry.setEnabled(false, for: "elevenlabs")

        do {
            _ = try await registry.configuredProvider(for: "elevenlabs")
            #expect(Bool(false), "Expected provider to be disabled")
        } catch {
            // Expected path
        }
    }

    @Test("Replacing descriptor supports custom configuration")
    func testReplacingDescriptorSupportsCustomConfiguration() async throws {
        let registry = TestFixtures.makeVoiceProviderRegistry(suiteName: suiteName)
        let descriptor = VoiceProviderDescriptor(
            id: "elevenlabs",
            displayName: "ElevenLabs",
            isEnabledByDefault: true,
            requiresConfiguration: false,
            makeProvider: { ElevenLabsVoiceProvider(apiKey: "test-key") }
        )

        await registry.register(descriptor)
        await registry.setEnabled(true, for: "elevenlabs")

        let provider = try await registry.configuredProvider(for: "elevenlabs")
        #expect(provider.isConfigured())
    }

    @Test("Provider with ID returns provider without configuration check")
    func testProviderWithIdReturnsProviderWithoutConfigurationCheck() async {
        let registry = TestFixtures.makeVoiceProviderRegistry(suiteName: suiteName)
        let provider = await registry.provider(for: "elevenlabs")
        #expect(provider != nil)
        #expect(provider?.providerId == "elevenlabs")
    }

    @Test("Provider with ID returns nil for unregistered")
    func testProviderWithIdReturnsNilForUnregistered() async {
        let registry = TestFixtures.makeVoiceProviderRegistry(suiteName: suiteName)
        let provider = await registry.provider(for: "nonexistent")
        #expect(provider == nil)
    }

    @Test("isEnabled returns true for Apple")
    func testIsEnabledReturnsTrueForApple() async {
        let registry = TestFixtures.makeVoiceProviderRegistry(suiteName: suiteName)
        let enabled = await registry.isEnabled(providerId: "apple")
        #expect(enabled)
    }

    @Test("isEnabled returns false for ElevenLabs")
    func testIsEnabledReturnsFalseForElevenLabs() async {
        let registry = TestFixtures.makeVoiceProviderRegistry(suiteName: suiteName)
        let enabled = await registry.isEnabled(providerId: "elevenlabs")
        #expect(!enabled)
    }

    @Test("setEnabled updates state")
    func testSetEnabledUpdatesState() async {
        let registry = TestFixtures.makeVoiceProviderRegistry(suiteName: suiteName)
        await registry.setEnabled(true, for: "elevenlabs")
        let enabled = await registry.isEnabled(providerId: "elevenlabs")
        #expect(enabled)

        await registry.setEnabled(false, for: "elevenlabs")
        let disabled = await registry.isEnabled(providerId: "elevenlabs")
        #expect(!disabled)
    }

    @Test("contains returns true for registered provider")
    func testContainsReturnsTrueForRegisteredProvider() async {
        let registry = TestFixtures.makeVoiceProviderRegistry(suiteName: suiteName)
        let contains = await registry.contains(providerId: "apple")
        #expect(contains)
    }

    @Test("contains returns false for unregistered provider")
    func testContainsReturnsFalseForUnregisteredProvider() async {
        let registry = TestFixtures.makeVoiceProviderRegistry(suiteName: suiteName)
        let contains = await registry.contains(providerId: "nonexistent")
        #expect(!contains)
    }

    @Test("instantiateAllProviders returns all providers")
    func testInstantiateAllProvidersReturnsAllProviders() async {
        let registry = TestFixtures.makeVoiceProviderRegistry(suiteName: suiteName)
        let providers = await registry.instantiateAllProviders()
        #expect(providers.count >= 2)

        let ids = Set(providers.map { $0.providerId })
        #expect(ids.contains("apple"))
        #expect(ids.contains("elevenlabs"))
    }

    @Test("register without replace does not overwrite existing")
    func testRegisterWithoutReplaceDoesNotOverwriteExisting() async {
        let registry = TestFixtures.makeVoiceProviderRegistry(suiteName: suiteName)
        let originalDescriptor = VoiceProviderDescriptor(
            id: "apple",
            displayName: "Modified Apple",
            isEnabledByDefault: false,
            requiresConfiguration: true,
            makeProvider: { AppleVoiceProvider() }
        )

        await registry.register(originalDescriptor, replaceExisting: false)

        let providers = await registry.availableProviders()
        let apple = providers.first { $0.descriptor.id == "apple" }
        // Should still be "Apple Text-to-Speech", not "Modified Apple"
        #expect(apple?.descriptor.displayName == "Apple Text-to-Speech")
    }

    @Test("configuredProvider throws for not registered")
    func testConfiguredProviderThrowsForNotRegistered() async {
        let registry = TestFixtures.makeVoiceProviderRegistry(suiteName: suiteName)
        do {
            _ = try await registry.configuredProvider(for: "nonexistent")
            #expect(Bool(false), "Expected error for unregistered provider")
        } catch {
            // Expected
        }
    }

    @Test("configuredProvider throws for not configured")
    func testConfiguredProviderThrowsForNotConfigured() async {
        let registry = TestFixtures.makeVoiceProviderRegistry(suiteName: suiteName)
        await registry.setEnabled(true, for: "elevenlabs")

        do {
            _ = try await registry.configuredProvider(for: "elevenlabs")
            Issue.record("Expected error for unconfigured provider")
        } catch {
            // Expected - should throw VoiceProviderRegistryError.providerNotConfigured
        }
    }

    @Test("always-enabled provider cannot be disabled")
    func testIsAlwaysEnabledProviderCannotBeDisabled() async {
        let registry = TestFixtures.makeVoiceProviderRegistry(suiteName: suiteName)
        // Apple is always enabled
        await registry.setEnabled(false, for: "apple")
        let enabled = await registry.isEnabled(providerId: "apple")
        #expect(enabled, "Always-enabled providers cannot be disabled")
    }
}
