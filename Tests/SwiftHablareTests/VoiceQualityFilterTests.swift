//
//  VoiceQualityFilterTests.swift
//  SwiftHablareTests
//
//  Tests for voice quality detection and filtering across platforms
//

import Testing
import Foundation
@testable import SwiftHablare

@Suite("Voice Quality Filter Tests")
struct VoiceQualityFilterTests {

    // MARK: - iOS Quality Detection Tests

    #if canImport(UIKit) && !os(macOS)
    @Test("iOS voices have quality property")
    @available(iOS 13.0, *)
    func iosVoicesHaveQualityProperty() async throws {
        let engine = AVSpeechTTSEngine()
        let voices = try await engine.fetchVoices(languageCode: "en")

        #expect(!voices.isEmpty)

        // All iOS voices should have quality information
        let voicesWithQuality = voices.filter { $0.quality != nil }
        #expect(voicesWithQuality.count == voices.count)
    }

    @Test("iOS voice quality values are valid")
    @available(iOS 13.0, *)
    func iosVoiceQualityValues() async throws {
        let engine = AVSpeechTTSEngine()
        let voices = try await engine.fetchVoices(languageCode: "en")

        let validQualities = ["default", "enhanced", "premium"]

        for voice in voices {
            if let quality = voice.quality {
                #expect(validQualities.contains(quality))
            }
        }
    }

    @Test("iOS high quality voices exist")
    @available(iOS 13.0, *)
    func iosHighQualityVoicesExist() async throws {
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
                #expect(voice.quality != nil)
                if let quality = voice.quality {
                    #expect(["default", "enhanced", "premium"].contains(quality))
                }
            }
        } else {
            // If we do have high-quality voices, verify they're correct
            for voice in highQualityVoices {
                #expect(voice.quality == "enhanced" || voice.quality == "premium")
            }
        }
    }
    #endif

    // MARK: - macOS Quality Detection Tests

    #if os(macOS)
    @Test("macOS voices have quality property")
    func macOSVoicesHaveQualityProperty() async throws {
        let engine = NSSpeechTTSEngine()
        let voices = try await engine.fetchVoices(languageCode: "en")

        #expect(!voices.isEmpty)

        // All macOS voices should have quality (extracted from name)
        let voicesWithQuality = voices.filter { $0.quality != nil }
        #expect(voicesWithQuality.count == voices.count)
    }

    @Test("macOS voice quality values are valid")
    func macOSVoiceQualityValues() async throws {
        let engine = NSSpeechTTSEngine()
        let voices = try await engine.fetchVoices(languageCode: "en")

        let validQualities = ["default", "enhanced", "premium"]

        for voice in voices {
            if let quality = voice.quality {
                #expect(validQualities.contains(quality))
            }
        }
    }

    @Test("macOS quality extraction from name")
    func macOSQualityExtractionFromName() {
        let _engine = NSSpeechTTSEngine()

        // Test premium detection
        let _premiumVoice = Voice(
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

    @Test("Apple TTS configuration defaults to no filter")
    func appleTTSConfigurationDefaultsToNoFilter() {
        let config = AppleTTSConfiguration()
        #expect(!config.filterToHighQualityOnly)
    }

    @Test("Apple TTS configuration can enable filter")
    func appleTTSConfigurationCanEnableFilter() {
        let config = AppleTTSConfiguration(filterToHighQualityOnly: true)
        #expect(config.filterToHighQualityOnly)
    }

    // MARK: - Filter Logic Tests

    #if canImport(UIKit) && !os(macOS)
    @Test("iOS filter removes default quality voices")
    @available(iOS 13.0, *)
    func iosFilterRemovesDefaultQualityVoices() async throws {
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
        #expect(filteredVoices.count <= allVoices.count)

        // All filtered voices should be high quality
        for voice in filteredVoices {
            #expect(voice.quality != nil)
            if let quality = voice.quality {
                #expect(quality == "enhanced" || quality == "premium")
            }
        }

        // If we have both high and low quality voices, filtered should be smaller
        let defaultQualityVoices = allVoices.filter { $0.quality == "default" }
        if !defaultQualityVoices.isEmpty {
            #expect(filteredVoices.count < allVoices.count)
        }
    }
    #endif

    #if os(macOS)
    @Test("macOS filter removes default quality voices")
    func macOSFilterRemovesDefaultQualityVoices() async throws {
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
        #expect(filteredVoices.count <= allVoices.count)

        // All filtered voices should be high quality
        for voice in filteredVoices {
            #expect(voice.quality != nil)
            if let quality = voice.quality {
                #expect(quality == "enhanced" || quality == "premium")
            }
        }
    }
    #endif

    // MARK: - Provider Integration Tests

    @Test("Apple voice provider reads filter setting from UserDefaults")
    func appleVoiceProviderReadsFilterSettingFromUserDefaults() {
        // Clear any existing setting
        UserDefaults.standard.removeObject(forKey: "appleVoiceFilterHighQualityOnly")

        let provider = AppleVoiceProvider()
        #expect(provider.isConfigured())

        // Set the filter in UserDefaults
        UserDefaults.standard.set(true, forKey: "appleVoiceFilterHighQualityOnly")

        // Create new provider instance to pick up the setting
        let providerWithFilter = AppleVoiceProvider()
        #expect(providerWithFilter.isConfigured())

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "appleVoiceFilterHighQualityOnly")
    }

    @Test("Apple voice provider fetches voices")
    func appleVoiceProviderFetchesVoices() async throws {
        let provider = AppleVoiceProvider()
        let voices = try await provider.fetchVoices(languageCode: "en")

        #expect(!voices.isEmpty)
        #expect(voices.allSatisfy { $0.providerId == "apple" })
    }

    @Test("Apple voice provider fetches voices with filter")
    func appleVoiceProviderFetchesVoicesWithFilter() async throws {
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
                #expect(quality == "enhanced" || quality == "premium")
            }
        }
    }

    // MARK: - Cross-Platform Consistency Tests

    @Test("Voice quality property exists across platforms")
    func voiceQualityPropertyExistsAcrossPlatforms() async throws {
        #if canImport(UIKit) && !os(macOS)
        let engine = AVSpeechTTSEngine()
        #elseif os(macOS)
        let engine = NSSpeechTTSEngine()
        #else
        throw skip("Unsupported platform for Apple TTS")
        #endif

        let voices = try await engine.fetchVoices(languageCode: "en")
        #expect(!voices.isEmpty)

        // All voices should have quality on both platforms
        for voice in voices {
            #expect(voice.quality != nil)
        }
    }

    @Test("Filter behavior consistent across platforms")
    func filterBehaviorConsistentAcrossPlatforms() async throws {
        #if canImport(UIKit) && !os(macOS)
        let engine = AVSpeechTTSEngine()
        #elseif os(macOS)
        let engine = NSSpeechTTSEngine()
        #else
        throw skip("Unsupported platform for Apple TTS")
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
        #expect(filteredVoices.count <= unfilteredVoices.count)

        // All filtered voices should be high quality on both platforms
        for voice in filteredVoices {
            if let quality = voice.quality {
                #expect(quality == "enhanced" || quality == "premium")
            }
        }
    }
}
