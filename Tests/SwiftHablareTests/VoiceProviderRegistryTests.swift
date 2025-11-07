import XCTest
import SwiftUI
@testable import SwiftHablare

@MainActor
final class VoiceProviderRegistryTests: XCTestCase {
    private var userDefaults: UserDefaults!
    private var registry: VoiceProviderRegistry!

    override func setUp() async throws {
        try await super.setUp()

        userDefaults = try XCTUnwrap(UserDefaults(suiteName: "VoiceProviderRegistryTests"))
        userDefaults.removePersistentDomain(forName: "VoiceProviderRegistryTests")

        registry = VoiceProviderRegistry(userDefaults: userDefaults)
    }

    override func tearDown() async throws {
        registry = nil

        userDefaults.removePersistentDomain(forName: "VoiceProviderRegistryTests")
        userDefaults = nil

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
}
