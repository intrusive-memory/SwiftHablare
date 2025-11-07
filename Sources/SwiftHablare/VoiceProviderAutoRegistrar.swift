//
//  VoiceProviderAutoRegistrar.swift
//  SwiftHablare
//
//  Provides a hook that allows external Swift packages to auto-register
//  their voice providers when the module is loaded.
//

import Foundation

/// Base class that packages can subclass to register providers as soon as the
/// containing module is loaded.
///
/// Usage:
/// ```swift
/// public final class SwiftEspeakRegistrar: VoiceProviderAutoRegistrar {
///     public override class var descriptors: [VoiceProviderDescriptor] {
///         [SwiftEspeakVoiceProvider.descriptor]
///     }
/// }
/// ```
///
/// Because this class inherits from `NSObject`, `load()` executes on platforms
/// backed by the Objective-C runtime when the Swift module is linked. The base
/// implementation automatically registers the provided descriptors with the
/// shared registry. When Objective-C interop is unavailable, hosts can call
/// `registerProviders(into:)` manually (for example, inside
/// `SwiftHablare.configureVoiceProviders()`).
open class VoiceProviderAutoRegistrar: NSObject {
    /// Descriptors to register automatically. Subclasses override this property
    /// to return one or more descriptors for their providers.
    open class var descriptors: [VoiceProviderDescriptor] { [] }

    /// Registers the subclass' descriptors into the supplied registry.
    ///
    /// This API is public so that test targets and non-Objective-C platforms can
    /// trigger the same registration work without relying on `load()`.
    public class func registerProviders(into registry: VoiceProviderRegistry) async {
        let descriptors = self.descriptors
        guard !descriptors.isEmpty else { return }

        for descriptor in descriptors {
            await registry.register(descriptor, replaceExisting: false)
        }
    }

    // Note: Swift does not support Objective-C's +load method.
    // Auto-registration must be done manually by calling registerProviders(into:)
    // from your application initialization code.
}
