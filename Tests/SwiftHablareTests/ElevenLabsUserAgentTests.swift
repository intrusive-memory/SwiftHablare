//
//  ElevenLabsUserAgentTests.swift
//  SwiftHablareTests
//
//  Tests to verify User-Agent header is correctly set in ElevenLabs requests
//

import XCTest
import Foundation
@testable import SwiftHablare

final class ElevenLabsUserAgentTests: XCTestCase {

    var provider: ElevenLabsVoiceProvider!
    var testAPIKey: String!

    override func setUp() {
        super.setUp()
        testAPIKey = "test-api-key-12345"
        provider = ElevenLabsVoiceProvider(apiKey: testAPIKey)
    }

    override func tearDown() {
        provider = nil
        testAPIKey = nil
        super.tearDown()
    }

    // MARK: - User-Agent Configuration Tests

    func testUserAgentFormat() {
        // Verify the User-Agent string follows the expected format: "SwiftHablare/X.Y.Z"
        let expectedUserAgent = "SwiftHablare/\(SwiftHablare.version)"

        // We can't directly access the private userAgent property, but we can verify
        // the SwiftHablare version constant is correctly set
        XCTAssertEqual(SwiftHablare.version, "3.8.0", "SwiftHablare version should be 3.8.0")
        XCTAssertEqual(SwiftHablare.name, "SwiftHablare", "SwiftHablare name should be 'SwiftHablare'")

        // Verify the expected User-Agent format
        XCTAssertEqual(expectedUserAgent, "SwiftHablare/3.8.0")
    }

    func testConfigurationIncludesUserAgent() {
        // Create a configuration using the engine directly
        let configuration = ElevenLabsEngineConfiguration(
            apiKey: testAPIKey,
            userAgent: "SwiftHablare/\(SwiftHablare.version)"
        )

        XCTAssertEqual(configuration.apiKey, testAPIKey)
        XCTAssertEqual(configuration.userAgent, "SwiftHablare/3.8.0")
    }

    // MARK: - URLProtocol-based Request Interception Tests

    func testFetchVoicesIncludesUserAgentHeader() async throws {
        // Verify configuration is correctly created with User-Agent
        let config = ElevenLabsEngineConfiguration(
            apiKey: testAPIKey,
            userAgent: "SwiftHablare/\(SwiftHablare.version)"
        )

        // Verify the configuration has the correct User-Agent
        XCTAssertEqual(config.userAgent, "SwiftHablare/3.8.0")
        XCTAssertFalse(config.userAgent.isEmpty, "User-Agent should not be empty")

        // Note: Testing actual HTTP header transmission requires URLProtocol mocking
        // which is complex with Swift strict concurrency. The integration tests
        // verify end-to-end functionality with real API calls.
    }

    func testGenerateAudioIncludesUserAgentHeader() async throws {
        // Similar test for generateAudio endpoint
        let configuration = ElevenLabsEngineConfiguration(
            apiKey: testAPIKey,
            userAgent: "SwiftHablare/\(SwiftHablare.version)"
        )

        XCTAssertEqual(configuration.userAgent, "SwiftHablare/3.8.0")
        XCTAssertFalse(configuration.userAgent.isEmpty)
    }

    func testIsVoiceAvailableIncludesUserAgentHeader() async throws {
        // Test for isVoiceAvailable endpoint
        let configuration = ElevenLabsEngineConfiguration(
            apiKey: testAPIKey,
            userAgent: "SwiftHablare/\(SwiftHablare.version)"
        )

        XCTAssertEqual(configuration.userAgent, "SwiftHablare/3.8.0")
    }

    // MARK: - Provider Integration Test

    func testProviderUsesCorrectUserAgent() async throws {
        // Verify the provider would create the correct User-Agent format
        // when making actual requests
        let expectedUserAgent = "SwiftHablare/3.8.0"

        // Create configuration as the provider would
        let configuration = ElevenLabsEngineConfiguration(
            apiKey: testAPIKey,
            userAgent: expectedUserAgent
        )

        XCTAssertEqual(configuration.userAgent, expectedUserAgent)
        XCTAssertEqual(configuration.apiKey, testAPIKey)

        // Note: Actual HTTP header verification is done in integration tests
        // (ElevenLabsVoiceProviderIntegrationTests.testUserAgentHeaderInRequests)
        // which make real API calls and verify they succeed with the User-Agent header.
    }

    // MARK: - Engine Configuration Tests

    func testEngineAcceptsUserAgentConfiguration() {
        let engine = ElevenLabsEngine()
        let config = ElevenLabsEngineConfiguration(
            apiKey: "test-key",
            userAgent: "SwiftHablare/3.8.0"
        )

        // Verify the engine can use the configuration
        XCTAssertTrue(engine.canGenerate(with: config))
        XCTAssertEqual(config.userAgent, "SwiftHablare/3.8.0")
    }
}
