//
//  SwiftEspeakVoiceProviderTests.swift
//  SwiftHablareTests
//
//  Unit tests covering metadata and fallback behaviour for SwiftEspeakVoiceProvider
//

import XCTest
@testable import SwiftHablare

final class SwiftEspeakVoiceProviderTests: XCTestCase {

    func testProviderMetadata() {
        let provider = SwiftEspeakVoiceProvider()

        XCTAssertEqual(provider.providerId, "swift-espeak")
        XCTAssertEqual(provider.displayName, "SwiftEspeak")
        XCTAssertFalse(provider.requiresAPIKey)
    }

    func testConfigurationReflectsLibraryAvailability() {
        let provider = SwiftEspeakVoiceProvider()

        #if canImport(SwiftEspeak)
        XCTAssertTrue(provider.isConfigured(), "SwiftEspeak should report configured when the library is linked")
        #else
        XCTAssertFalse(provider.isConfigured(), "SwiftEspeak should report not configured when the library is unavailable")
        #endif
    }

    func testFetchVoicesWhenLibraryUnavailableThrowsNotSupported() async {
        #if !canImport(SwiftEspeak)
        let provider = SwiftEspeakVoiceProvider()

        do {
            _ = try await provider.fetchVoices(languageCode: "en")
            XCTFail("Expected notSupported error when SwiftEspeak is unavailable")
        } catch {
            guard case VoiceProviderError.notSupported = error else {
                XCTFail("Expected VoiceProviderError.notSupported, got \(error)")
                return
            }
        }
        #endif
    }

    func testGenerateAudioWhenLibraryUnavailableThrowsNotSupported() async {
        #if !canImport(SwiftEspeak)
        let provider = SwiftEspeakVoiceProvider()

        do {
            _ = try await provider.generateAudio(text: "Hello", voiceId: "en-us", languageCode: "en")
            XCTFail("Expected notSupported error when SwiftEspeak is unavailable")
        } catch {
            guard case VoiceProviderError.notSupported = error else {
                XCTFail("Expected VoiceProviderError.notSupported, got \(error)")
                return
            }
        }
        #endif
    }

    func testEstimateDurationDefaultsToZeroWhenUnavailable() async {
        #if !canImport(SwiftEspeak)
        let provider = SwiftEspeakVoiceProvider()
        let duration = await provider.estimateDuration(text: "Hello", voiceId: "en-us")
        XCTAssertEqual(duration, 0)
        #endif
    }
}
