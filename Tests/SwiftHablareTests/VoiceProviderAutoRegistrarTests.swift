import Testing
@testable import SwiftHablare

@Suite struct VoiceProviderAutoRegistrarTests {
    @Test func registerProvidersAddsDescriptors() async throws {
        let setup = makeTestUserDefaults(suiteName: "VoiceProviderAutoRegistrarTests")
        let defaults = setup.defaults
        defer { setup.cleanup() }

        let registry = VoiceProviderRegistry(userDefaults: defaults)

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
        #expect(identifiers.contains("sample"))
    }
}
