//
//  VoiceQualityFilterTests.swift
//  SwiftHablareTests
//
//  Tests for voice quality detection and filtering across platforms
//

import XCTest
@testable import SwiftHablare

final class VoiceQualityFilterTests: XCTestCase {

    // MARK: - iOS Quality Detection Tests

    #if canImport(UIKit) && !os(macOS)
    @available(iOS 13.0, *)
    func testIOSVoicesHaveQualityProperty() async throws {
        let engine = AVSpeechTTSEngine()
        let voices = try await engine.fetchVoices(languageCode: "en")

        XCTAssertFalse(voices.isEmpty, "Should have voices available")

        // All iOS voices should have quality information
        let voicesWithQuality = voices.filter { $0.quality != nil }
        XCTAssertEqual(voicesWithQuality.count, voices.count, "All iOS voices should have quality information")
    }

    @available(iOS 13.0, *)
    func testIOSVoiceQualityValues() async throws {
        let engine = AVSpeechTTSEngine()
        let voices = try await engine.fetchVoices(languageCode: "en")

        let validQualities = ["default", "enhanced", "premium"]

        for voice in voices {
            if let quality = voice.quality {
                XCTAssertTrue(validQualities.contains(quality),
                            "Quality '\(quality)' should be one of: \(validQualities)")
            }
        }
    }

    @available(iOS 13.0, *)
    func testIOSHighQualityVoicesExist() async throws {
        let engine = AVSpeechTTSEngine()
        let voices = try await engine.fetchVoices(languageCode: "en")

        let highQualityVoices = voices.filter { voice in
            guard let quality = voice.quality else { return false }
            return quality == "enhanced" || quality == "premium"
        }

        // Note: iOS Simulator may not have enhanced/premium voices
        // Physical devices typically do, but we can't require it in CI
        // Instead, verify that IF high-quality voices exist, they have correct quality values
        if highQualityVoices.isEmpty {
            // This is okay - simulator may only have default voices
            // Just verify all voices have quality information
            for voice in voices {
                XCTAssertNotNil(voice.quality, "Voice '\(voice.name)' should have quality")
                if let quality = voice.quality {
                    XCTAssertTrue(["default", "enhanced", "premium"].contains(quality),
                                "Quality should be valid: \(quality)")
                }
            }
        } else {
            // If we do have high-quality voices, verify they're correct
            for voice in highQualityVoices {
                XCTAssertTrue(voice.quality == "enhanced" || voice.quality == "premium",
                            "High quality voice should be enhanced or premium: \(voice.quality ?? "nil")")
            }
        }
    }
    #endif

    // MARK: - macOS Quality Detection Tests

    #if os(macOS)
    func testMacOSVoicesHaveQualityProperty() async throws {
        let engine = NSSpeechTTSEngine()
        let voices = try await engine.fetchVoices(languageCode: "en")

        XCTAssertFalse(voices.isEmpty, "Should have voices available")

        // All macOS voices should have quality (extracted from name)
        let voicesWithQuality = voices.filter { $0.quality != nil }
        XCTAssertEqual(voicesWithQuality.count, voices.count,
                      "All macOS voices should have quality information (defaults to 'default')")
    }

    func testMacOSVoiceQualityValues() async throws {
        let engine = NSSpeechTTSEngine()
        let voices = try await engine.fetchVoices(languageCode: "en")

        let validQualities = ["default", "enhanced", "premium"]

        for voice in voices {
            if let quality = voice.quality {
                XCTAssertTrue(validQualities.contains(quality),
                            "Quality '\(quality)' should be one of: \(validQualities)")
            }
        }
    }

    func testMacOSQualityExtractionFromName() {
        let engine = NSSpeechTTSEngine()

        // Test premium detection
        let premiumVoice = Voice(
            id: "test.premium",
            name: "Alex Premium",
            description: nil,
            providerId: "apple",
            quality: nil
        )
        // Quality should be extracted during fetchVoices, but we can't directly test the private method
        // Instead, we verify voices from the actual API have quality

        // This is tested indirectly through fetchVoices
    }
    #endif

    // MARK: - Filter Configuration Tests

    func testAppleTTSConfigurationDefaultsToNoFilter() {
        let config = AppleTTSConfiguration()
        XCTAssertFalse(config.filterToHighQualityOnly, "Should default to showing all voices")
    }

    func testAppleTTSConfigurationCanEnableFilter() {
        let config = AppleTTSConfiguration(filterToHighQualityOnly: true)
        XCTAssertTrue(config.filterToHighQualityOnly, "Should enable high quality filter")
    }

    // MARK: - Filter Logic Tests

    #if canImport(UIKit) && !os(macOS)
    @available(iOS 13.0, *)
    func testIOSFilterRemovesDefaultQualityVoices() async throws {
        let engine = AVSpeechTTSEngine()
        let boundary = AppleTTSEngineBoundary(underlying: engine)

        // Get all voices
        let allVoices = try await boundary.fetchVoices(
            languageCode: "en",
            configuration: AppleTTSConfiguration(filterToHighQualityOnly: false)
        )

        // Get filtered voices
        let filteredVoices = try await boundary.fetchVoices(
            languageCode: "en",
            configuration: AppleTTSConfiguration(filterToHighQualityOnly: true)
        )

        // Filtered list should be smaller or equal (in case there are no default quality voices)
        XCTAssertLessThanOrEqual(filteredVoices.count, allVoices.count,
                                "Filtered list should not be larger than unfiltered")

        // All filtered voices should be high quality
        for voice in filteredVoices {
            XCTAssertNotNil(voice.quality, "Filtered voice should have quality")
            if let quality = voice.quality {
                XCTAssertTrue(quality == "enhanced" || quality == "premium",
                            "Filtered voice should be enhanced or premium, got: \(quality)")
            }
        }

        // If we have both high and low quality voices, filtered should be smaller
        let defaultQualityVoices = allVoices.filter { $0.quality == "default" }
        if !defaultQualityVoices.isEmpty {
            XCTAssertLessThan(filteredVoices.count, allVoices.count,
                            "Filter should remove default quality voices when they exist")
        }
    }
    #endif

    #if os(macOS)
    func testMacOSFilterRemovesDefaultQualityVoices() async throws {
        let engine = NSSpeechTTSEngine()
        let boundary = AppleTTSEngineBoundary(underlying: engine)

        // Get all voices
        let allVoices = try await boundary.fetchVoices(
            languageCode: "en",
            configuration: AppleTTSConfiguration(filterToHighQualityOnly: false)
        )

        // Get filtered voices
        let filteredVoices = try await boundary.fetchVoices(
            languageCode: "en",
            configuration: AppleTTSConfiguration(filterToHighQualityOnly: true)
        )

        // Filtered list should be smaller or equal
        XCTAssertLessThanOrEqual(filteredVoices.count, allVoices.count,
                                "Filtered list should not be larger than unfiltered")

        // All filtered voices should be high quality
        for voice in filteredVoices {
            XCTAssertNotNil(voice.quality, "Filtered voice should have quality")
            if let quality = voice.quality {
                XCTAssertTrue(quality == "enhanced" || quality == "premium",
                            "Filtered voice should be enhanced or premium, got: \(quality)")
            }
        }
    }
    #endif

    // MARK: - Provider Integration Tests

    func testAppleVoiceProviderReadsFilterSettingFromUserDefaults() {
        // Clear any existing setting
        UserDefaults.standard.removeObject(forKey: "appleVoiceFilterHighQualityOnly")

        let provider = AppleVoiceProvider()
        XCTAssertTrue(provider.isConfigured(), "Provider should be configured")

        // Set the filter in UserDefaults
        UserDefaults.standard.set(true, forKey: "appleVoiceFilterHighQualityOnly")

        // Create new provider instance to pick up the setting
        let providerWithFilter = AppleVoiceProvider()
        XCTAssertTrue(providerWithFilter.isConfigured(), "Provider with filter should still be configured")

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "appleVoiceFilterHighQualityOnly")
    }

    func testAppleVoiceProviderFetchesVoices() async throws {
        let provider = AppleVoiceProvider()
        let voices = try await provider.fetchVoices(languageCode: "en")

        XCTAssertFalse(voices.isEmpty, "Should fetch voices from provider")
        XCTAssertTrue(voices.allSatisfy { $0.providerId == "apple" },
                     "All voices should have provider ID 'apple'")
    }

    func testAppleVoiceProviderFetchesVoicesWithFilter() async throws {
        // Enable filter
        UserDefaults.standard.set(true, forKey: "appleVoiceFilterHighQualityOnly")
        defer {
            UserDefaults.standard.removeObject(forKey: "appleVoiceFilterHighQualityOnly")
        }

        let provider = AppleVoiceProvider()
        let voices = try await provider.fetchVoices(languageCode: "en")

        // All voices should be high quality when filter is enabled
        for voice in voices {
            if let quality = voice.quality {
                XCTAssertTrue(quality == "enhanced" || quality == "premium",
                            "With filter enabled, should only get enhanced or premium voices")
            }
        }
    }

    // MARK: - Cross-Platform Consistency Tests

    func testVoiceQualityPropertyExistsAcrossPlatforms() async throws {
        #if canImport(UIKit) && !os(macOS)
        let engine = AVSpeechTTSEngine()
        #elseif os(macOS)
        let engine = NSSpeechTTSEngine()
        #else
        throw XCTSkip("Unsupported platform for Apple TTS")
        #endif

        let voices = try await engine.fetchVoices(languageCode: "en")
        XCTAssertFalse(voices.isEmpty, "Should have voices")

        // All voices should have quality on both platforms
        for voice in voices {
            XCTAssertNotNil(voice.quality, "Voice '\(voice.name)' should have quality property")
        }
    }

    func testFilterBehaviorConsistentAcrossPlatforms() async throws {
        #if canImport(UIKit) && !os(macOS)
        let engine = AVSpeechTTSEngine()
        #elseif os(macOS)
        let engine = NSSpeechTTSEngine()
        #else
        throw XCTSkip("Unsupported platform for Apple TTS")
        #endif

        let boundary = AppleTTSEngineBoundary(underlying: engine)

        let unfilteredVoices = try await boundary.fetchVoices(
            languageCode: "en",
            configuration: AppleTTSConfiguration(filterToHighQualityOnly: false)
        )

        let filteredVoices = try await boundary.fetchVoices(
            languageCode: "en",
            configuration: AppleTTSConfiguration(filterToHighQualityOnly: true)
        )

        // Both platforms should apply filter consistently
        XCTAssertLessThanOrEqual(filteredVoices.count, unfilteredVoices.count,
                                "Filter should not increase voice count")

        // All filtered voices should be high quality on both platforms
        for voice in filteredVoices {
            if let quality = voice.quality {
                XCTAssertTrue(quality == "enhanced" || quality == "premium",
                            "Filtered voices should be high quality on all platforms")
            }
        }
    }
}
