import XCTest
import SwiftUI
@testable import SwiftHablare

final class VoiceProviderRegistryTests: XCTestCase {
    private var cleanupDefaults: (() -> Void)?
    private var registry: VoiceProviderRegistry!

    override func setUp() async throws {
        try await super.setUp()

        let setup = makeTestUserDefaults(suiteName: "VoiceProviderRegistryTests")
        cleanupDefaults = setup.cleanup

        // UserDefaults is thread-safe, suppress the concurrency warning
        let defaults = setup.defaults
        registry = VoiceProviderRegistry(userDefaults: defaults)
    }

    override func tearDown() async throws {
        registry = nil

        cleanupDefaults?()
        cleanupDefaults = nil

        try await super.tearDown()
    }

    func testDefaultDescriptorsLoaded() async {
        let providers = await registry.availableProviders()
        let identifiers = Set(providers.map { $0.descriptor.id })

        XCTAssertTrue(identifiers.contains("apple"))
        XCTAssertTrue(identifiers.contains("elevenlabs"))

        let apple = providers.first { $0.descriptor.id == "apple" }
        XCTAssertNotNil(apple)
        XCTAssertEqual(apple?.descriptor.displayName, "Apple Text-to-Speech")
        XCTAssertTrue(apple?.isEnabled ?? false)
        XCTAssertTrue(apple?.isConfigured ?? false)

        let eleven = providers.first { $0.descriptor.id == "elevenlabs" }
        XCTAssertNotNil(eleven)
        XCTAssertEqual(eleven?.descriptor.displayName, "ElevenLabs")
        XCTAssertFalse(eleven?.isEnabled ?? true)
        XCTAssertFalse(eleven?.isConfigured ?? true)
    }

    func testConfiguredProviderRetrieval() async throws {
        let apple = try await registry.configuredProvider(for: "apple")
        XCTAssertEqual(apple.displayName, "Apple Text-to-Speech")
        XCTAssertTrue(apple.isConfigured())
    }

    func testConfiguredProviderRequiresEnablement() async {
        await registry.setEnabled(false, for: "elevenlabs")

        do {
            _ = try await registry.configuredProvider(for: "elevenlabs")
            XCTFail("Expected provider to be disabled")
        } catch {
            // Expected path
        }
    }

    func testReplacingDescriptorSupportsCustomConfiguration() async throws {
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
        XCTAssertTrue(provider.isConfigured())
    }

    func testProviderWithIdReturnsProviderWithoutConfigurationCheck() async {
        let provider = await registry.provider(for: "elevenlabs")
        XCTAssertNotNil(provider)
        XCTAssertEqual(provider?.providerId, "elevenlabs")
    }

    func testProviderWithIdReturnsNilForUnregistered() async {
        let provider = await registry.provider(for: "nonexistent")
        XCTAssertNil(provider)
    }

    func testIsEnabledReturnsTrueForApple() async {
        let enabled = await registry.isEnabled(providerId: "apple")
        XCTAssertTrue(enabled)
    }

    func testIsEnabledReturnsFalseForElevenLabs() async {
        let enabled = await registry.isEnabled(providerId: "elevenlabs")
        XCTAssertFalse(enabled)
    }

    func testSetEnabledUpdatesState() async {
        await registry.setEnabled(true, for: "elevenlabs")
        let enabled = await registry.isEnabled(providerId: "elevenlabs")
        XCTAssertTrue(enabled)

        await registry.setEnabled(false, for: "elevenlabs")
        let disabled = await registry.isEnabled(providerId: "elevenlabs")
        XCTAssertFalse(disabled)
    }

    func testContainsReturnsTrueForRegisteredProvider() async {
        let contains = await registry.contains(providerId: "apple")
        XCTAssertTrue(contains)
    }

    func testContainsReturnsFalseForUnregisteredProvider() async {
        let contains = await registry.contains(providerId: "nonexistent")
        XCTAssertFalse(contains)
    }

    func testInstantiateAllProvidersReturnsAllProviders() async {
        let providers = await registry.instantiateAllProviders()
        XCTAssertGreaterThanOrEqual(providers.count, 2)

        let ids = Set(providers.map { $0.providerId })
        XCTAssertTrue(ids.contains("apple"))
        XCTAssertTrue(ids.contains("elevenlabs"))
    }

    func testRegisterWithoutReplaceDoesNotOverwriteExisting() async {
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
        XCTAssertEqual(apple?.descriptor.displayName, "Apple Text-to-Speech")
    }

    func testConfiguredProviderThrowsForNotRegistered() async {
        do {
            _ = try await registry.configuredProvider(for: "nonexistent")
            XCTFail("Expected error for unregistered provider")
        } catch {
            // Expected
        }
    }

    func testConfiguredProviderThrowsForNotConfigured() async {
        await registry.setEnabled(true, for: "elevenlabs")

        do {
            _ = try await registry.configuredProvider(for: "elevenlabs")
            XCTFail("Expected error for unconfigured provider")
        } catch {
            // Expected
        }
    }

    func testIsAlwaysEnabledProviderCannotBeDisabled() async {
        // Apple is always enabled
        await registry.setEnabled(false, for: "apple")
        let enabled = await registry.isEnabled(providerId: "apple")
        XCTAssertTrue(enabled, "Always-enabled providers cannot be disabled")
    }
}
