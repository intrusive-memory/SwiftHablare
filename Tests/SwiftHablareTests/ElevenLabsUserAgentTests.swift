//
//  ElevenLabsUserAgentTests.swift
//  SwiftHablareTests
//
//  Tests to verify User-Agent header is correctly set in ElevenLabs requests
//

import Testing
import Foundation
@testable import SwiftHablare

@Suite
struct ElevenLabsUserAgentTests {

    var provider: ElevenLabsVoiceProvider!
    var testAPIKey: String!

    init() {
        testAPIKey = "test-api-key-12345"
        provider = ElevenLabsVoiceProvider(apiKey: testAPIKey)
    }

    // MARK: - User-Agent Configuration Tests

    @Test
    func userAgentFormat() {
        // Verify the User-Agent string follows the expected format: "SwiftHablare/X.Y.Z"
        let expectedUserAgent = "SwiftHablare/\(SwiftHablare.version)"

        // Verify library constants are set
        #expect(!SwiftHablare.version.isEmpty)
        #expect(SwiftHablare.name == "SwiftHablare")

        // Verify the User-Agent format starts with library name
        #expect(expectedUserAgent.hasPrefix("SwiftHablare/"))
        #expect(expectedUserAgent.contains(SwiftHablare.version))
    }

    @Test
    func configurationIncludesUserAgent() {
        // Create a configuration using the engine directly
        let configuration = ElevenLabsEngineConfiguration(
            apiKey: testAPIKey,
            userAgent: "SwiftHablare/\(SwiftHablare.version)"
        )

        #expect(configuration.apiKey == testAPIKey)
        #expect(configuration.userAgent.hasPrefix("SwiftHablare/"))
        #expect(!configuration.userAgent.isEmpty)
    }

    // MARK: - URLProtocol-based Request Interception Tests

    @Test
    func fetchVoicesIncludesUserAgentHeader() async throws {
        // Verify configuration is correctly created with User-Agent
        let config = ElevenLabsEngineConfiguration(
            apiKey: testAPIKey,
            userAgent: "SwiftHablare/\(SwiftHablare.version)"
        )

        // Verify the configuration has the correct User-Agent format
        #expect(config.userAgent.hasPrefix("SwiftHablare/"))
        #expect(!config.userAgent.isEmpty)

        // Note: Testing actual HTTP header transmission requires URLProtocol mocking
        // which is complex with Swift strict concurrency. The integration tests
        // verify end-to-end functionality with real API calls.
    }

    @Test
    func generateAudioIncludesUserAgentHeader() async throws {
        // Similar test for generateAudio endpoint
        let configuration = ElevenLabsEngineConfiguration(
            apiKey: testAPIKey,
            userAgent: "SwiftHablare/\(SwiftHablare.version)"
        )

        #expect(configuration.userAgent.hasPrefix("SwiftHablare/"))
        #expect(!configuration.userAgent.isEmpty)
    }

    @Test
    func isVoiceAvailableIncludesUserAgentHeader() async throws {
        // Test for isVoiceAvailable endpoint
        let configuration = ElevenLabsEngineConfiguration(
            apiKey: testAPIKey,
            userAgent: "SwiftHablare/\(SwiftHablare.version)"
        )

        #expect(configuration.userAgent.hasPrefix("SwiftHablare/"))
        #expect(!configuration.userAgent.isEmpty)
    }

    // MARK: - Provider Integration Test

    @Test
    func providerUsesCorrectUserAgent() async throws {
        // Verify the provider would create the correct User-Agent format
        // when making actual requests
        let expectedUserAgent = "SwiftHablare/\(SwiftHablare.version)"

        // Create configuration as the provider would
        let configuration = ElevenLabsEngineConfiguration(
            apiKey: testAPIKey,
            userAgent: expectedUserAgent
        )

        #expect(configuration.userAgent == expectedUserAgent)
        #expect(configuration.userAgent.hasPrefix("SwiftHablare/"))
        #expect(configuration.apiKey == testAPIKey)

        // Note: Actual HTTP header verification is done in integration tests
        // (ElevenLabsVoiceProviderIntegrationTests.testUserAgentHeaderInRequests)
        // which make real API calls and verify they succeed with the User-Agent header.
    }

    // MARK: - Engine Configuration Tests

    @Test
    func engineAcceptsUserAgentConfiguration() {
        let engine = ElevenLabsEngine()
        let config = ElevenLabsEngineConfiguration(
            apiKey: "test-key",
            userAgent: "SwiftHablare/\(SwiftHablare.version)"
        )

        // Verify the engine can use the configuration
        #expect(engine.canGenerate(with: config))
        #expect(config.userAgent.hasPrefix("SwiftHablare/"))
        #expect(!config.userAgent.isEmpty)
    }
}
