import XCTest
@testable import SwiftHablare

final class VoiceProviderAutoRegistrarTests: XCTestCase {
    func testRegisterProvidersAddsDescriptors() async throws {
        let setup = makeTestUserDefaults(suiteName: "VoiceProviderAutoRegistrarTests")
        let userDefaults = setup.defaults
        defer { setup.cleanup() }

        let registry = VoiceProviderRegistry(userDefaults: userDefaults)

        final class SampleRegistrar: VoiceProviderAutoRegistrar {
            override class var descriptors: [VoiceProviderDescriptor] {
                [
                    VoiceProviderDescriptor(
                        id: "sample",
                        displayName: "Sample Provider",
                        isEnabledByDefault: false,
                        requiresConfiguration: false,
                        makeProvider: { AppleVoiceProvider() }
                    )
                ]
            }
        }

        await SampleRegistrar.registerProviders(into: registry)

        let providers = await registry.availableProviders()
        let identifiers = providers.map { $0.descriptor.id }
        XCTAssertTrue(identifiers.contains("sample"))
    }
}
