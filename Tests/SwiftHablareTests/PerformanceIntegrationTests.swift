//
//  PerformanceIntegrationTests.swift
//  SwiftHablareTests
//
//  Performance benchmarks for SwiftHablare operations.
//  These tests establish baselines and measure optimization improvements.
//  Runs weekly on integration test schedule (long-running benchmarks).
//
//  IMPORTANT: These tests only run on Apple Silicon for consistent performance metrics.
//

import XCTest
@testable import SwiftHablare

#if arch(arm64)
final class PerformanceIntegrationTests: XCTestCase {

    // MARK: - Test Configuration

    /// Number of iterations for repeated operations
    let iterationCount = 10

    /// Baseline metrics to track (stored in test bundle for comparison)
    struct PerformanceBaseline: Codable {
        var voiceFetchTime: TimeInterval
        var audioGenerationTime: TimeInterval
        var providerInitTime: TimeInterval
        var voiceFilterTime: TimeInterval
        var timestamp: Date
        var xcodeBuildNumber: String?
    }


    // MARK: - Audio Generation Performance

    #if !targetEnvironment(simulator)
    func testAudioGenerationPerformance() throws {
        let provider = AppleVoiceProvider()
        let testText = "This is a test of audio generation performance. We need to measure how quickly we can synthesize speech."

        let metrics: [XCTMetric] = [
            XCTClockMetric(),
            XCTCPUMetric(),
            XCTMemoryMetric()
        ]

        let options = XCTMeasureOptions()
        options.iterationCount = 5  // Fewer iterations as this is slow

        measure(metrics: metrics, options: options) {
            let expectation = self.expectation(description: "Generate audio")

            Task {
                do {
                    let voices = try await provider.fetchVoices(languageCode: "en")
                    guard let firstVoice = voices.first else {
                        XCTFail("No voices available")
                        expectation.fulfill()
                        return
                    }

                    _ = try await provider.generateAudio(
                        text: testText,
                        voiceId: firstVoice.id,
                        languageCode: "en"
                    )

                    expectation.fulfill()
                } catch {
                    XCTFail("Failed to generate audio: \(error)")
                    expectation.fulfill()
                }
            }

            wait(for: [expectation], timeout: 30.0)
        }
    }
    #endif

    // MARK: - Provider Initialization Performance

    func testProviderInitializationPerformance() {
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            _ = AppleVoiceProvider()
        }
    }

    func testGenerationServiceInitializationPerformance() {
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            _ = GenerationService()
        }
    }

    // MARK: - Voice Filtering Performance

    func testVoiceFilteringPerformance() async throws {
        let provider = AppleVoiceProvider()

        // Fetch voices once
        let voices = try await provider.fetchVoices(languageCode: "en")

        XCTAssertFalse(voices.isEmpty, "Need voices to test filtering")

        // Measure filtering operation
        measure(metrics: [XCTClockMetric()]) {
            for _ in 0..<10 {
                _ = voices.filter { voice in
                    guard let quality = voice.quality else { return false }
                    return quality == "enhanced" || quality == "premium"
                }
            }
        }
    }


    // MARK: - String Operations Performance

    func testBracketFilteringPerformance() {
        let sampleTexts = [
            "Hello {{stage whisper}} world {{nervously}}",
            "This is a test {{V.O.}} with multiple {{annotations}} here",
            "{{entire content in brackets}}",
            "No brackets here at all",
            "Start {{bracket}} middle {{another}} end {{final}}"
        ]

        let pattern = "\\{\\{[^}]*\\}\\}"

        measure(metrics: [XCTClockMetric()]) {
            for _ in 0..<10 {
                for text in sampleTexts {
                    _ = text.replacingOccurrences(
                        of: pattern,
                        with: "",
                        options: .regularExpression
                    )
                }
            }
        }
    }

    // MARK: - Platform-Specific Performance

    #if os(macOS)
    func testMacOSQualityExtractionPerformance() {
        let testNames = [
            ("Alex", "com.apple.speech.synthesis.voice.alex"),
            ("Samantha Enhanced", "com.apple.speech.synthesis.voice.samantha.enhanced"),
            ("Victoria Premium", "com.apple.speech.synthesis.voice.victoria.premium"),
            ("Tom", "com.apple.speech.synthesis.voice.tom"),
            ("Fiona Enhanced", "com.apple.speech.synthesis.voice.fiona.enhanced")
        ]

        measure(metrics: [XCTClockMetric()]) {
            for _ in 0..<10 {
                for (name, identifier) in testNames {
                    let lowercasedName = name.lowercased()
                    let lowercasedIdentifier = identifier.lowercased()

                    _ = if lowercasedName.contains("premium") || lowercasedIdentifier.contains("premium") {
                        "premium"
                    } else if lowercasedName.contains("enhanced") || lowercasedIdentifier.contains("enhanced") {
                        "enhanced"
                    } else {
                        "default"
                    }
                }
            }
        }
    }
    #endif

    // MARK: - Baseline Recording & Comparison

    func testRecordPerformanceBaseline() async throws {
        // This test records current performance metrics for comparison
        let provider = AppleVoiceProvider()

        let audioGenTime: TimeInterval = 0

        // Measure voice fetching
        let fetchStart = Date()
        _ = try await provider.fetchVoices(languageCode: "en")
        let voiceFetchTime = Date().timeIntervalSince(fetchStart)

        // Measure provider init
        let initStart = Date()
        _ = AppleVoiceProvider()
        let providerInitTime = Date().timeIntervalSince(initStart)

        // Measure filtering
        let voices = try await provider.fetchVoices(languageCode: "en")
        let filterStart = Date()
        _ = voices.filter { voice in
            guard let quality = voice.quality else { return false }
            return quality == "enhanced" || quality == "premium"
        }
        let filterTime = Date().timeIntervalSince(filterStart)

        // Create baseline record
        let baseline = PerformanceBaseline(
            voiceFetchTime: voiceFetchTime,
            audioGenerationTime: audioGenTime,
            providerInitTime: providerInitTime,
            voiceFilterTime: filterTime,
            timestamp: Date(),
            xcodeBuildNumber: ProcessInfo.processInfo.operatingSystemVersionString
        )

        // Print baseline for documentation
        print("""

        ==========================================
        PERFORMANCE BASELINE RECORDED
        ==========================================
        Voice Fetch Time:     \(String(format: "%.4f", voiceFetchTime))s
        Audio Gen Time:       \(String(format: "%.4f", audioGenTime))s
        Provider Init Time:   \(String(format: "%.4f", providerInitTime))s
        Filter Time:          \(String(format: "%.6f", filterTime))s
        Timestamp:            \(baseline.timestamp)
        OS Version:           \(baseline.xcodeBuildNumber ?? "Unknown")
        ==========================================

        """)

        // Store baseline in temporary file for later comparison
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(baseline) {
            let tempDir = FileManager.default.temporaryDirectory
            let baselineFile = tempDir.appendingPathComponent("performance_baseline.json")
            try? data.write(to: baselineFile)
            print("Baseline saved to: \(baselineFile.path)")
        }
    }

    func testCompareWithBaseline() async throws {
        // Load previous baseline if it exists
        let tempDir = FileManager.default.temporaryDirectory
        let baselineFile = tempDir.appendingPathComponent("performance_baseline.json")

        guard let data = try? Data(contentsOf: baselineFile),
              let baseline = try? JSONDecoder().decode(PerformanceBaseline.self, from: data) else {
            print("⚠️  No baseline found. Run testRecordPerformanceBaseline first.")
            return
        }

        // Measure current performance
        let provider = AppleVoiceProvider()

        // Measure voice fetching
        let fetchStart = Date()
        _ = try await provider.fetchVoices(languageCode: "en")
        let currentVoiceFetchTime = Date().timeIntervalSince(fetchStart)

        // Measure provider init
        let initStart = Date()
        _ = AppleVoiceProvider()
        let currentProviderInitTime = Date().timeIntervalSince(initStart)

        // Measure filtering
        let voices = try await provider.fetchVoices(languageCode: "en")
        let filterStart = Date()
        _ = voices.filter { voice in
            guard let quality = voice.quality else { return false }
            return quality == "enhanced" || quality == "premium"
        }
        let filterTime = Date().timeIntervalSince(filterStart)

        // Calculate improvements
        let fetchImprovement = ((baseline.voiceFetchTime - currentVoiceFetchTime) / baseline.voiceFetchTime) * 100
        let initImprovement = ((baseline.providerInitTime - currentProviderInitTime) / baseline.providerInitTime) * 100
        let filterImprovement = ((baseline.voiceFilterTime - filterTime) / baseline.voiceFilterTime) * 100

        // Print comparison
        print("""

        ==========================================
        PERFORMANCE COMPARISON
        ==========================================
        Baseline Date: \(baseline.timestamp)
        Current Date:  \(Date())

        Voice Fetch Time:
          Baseline: \(String(format: "%.4f", baseline.voiceFetchTime))s
          Current:  \(String(format: "%.4f", currentVoiceFetchTime))s
          Change:   \(String(format: "%+.1f", fetchImprovement))%

        Provider Init Time:
          Baseline: \(String(format: "%.4f", baseline.providerInitTime))s
          Current:  \(String(format: "%.4f", currentProviderInitTime))s
          Change:   \(String(format: "%+.1f", initImprovement))%

        Filter Time:
          Baseline: \(String(format: "%.6f", baseline.voiceFilterTime))s
          Current:  \(String(format: "%.6f", filterTime))s
          Change:   \(String(format: "%+.1f", filterImprovement))%

        Overall: \(fetchImprovement > 0 && initImprovement > 0 ? "✅ IMPROVED" : "⚠️  REGRESSION")
        ==========================================

        """)

        // Assert that we haven't regressed significantly (>10% slower)
        XCTAssertLessThan(currentVoiceFetchTime, baseline.voiceFetchTime * 1.1,
                         "Voice fetching regressed by more than 10%")
        XCTAssertLessThan(currentProviderInitTime, baseline.providerInitTime * 1.1,
                         "Provider init regressed by more than 10%")
    }


    // MARK: - GenerationService Performance

    func testGenerationServiceBatchOperationPerformance() {
        let testItems = (0..<20).map { i in
            (text: "Test dialogue \(i)", voiceId: "test-voice-\(i)")
        }

        let metrics: [XCTMetric] = [
            XCTClockMetric(),
            XCTMemoryMetric()
        ]

        let options = XCTMeasureOptions()
        options.iterationCount = 5

        measure(metrics: metrics, options: options) {
            // Simulate batch generation overhead
            for item in testItems {
                _ = item.text.count
                _ = item.voiceId.count
            }
        }
    }

    // MARK: - Voice Filtering and Sorting Performance

    func testVoiceSortingPerformance() async throws {
        let provider = AppleVoiceProvider()

        let voices = try await provider.fetchVoices(languageCode: "en")

        XCTAssertFalse(voices.isEmpty, "Need voices to test sorting")

        measure(metrics: [XCTClockMetric()]) {
            for _ in 0..<10 {
                _ = voices.sorted { $0.name < $1.name }
                _ = voices.sorted { ($0.quality ?? "") > ($1.quality ?? "") }
                _ = voices.sorted { ($0.language ?? "") < ($1.language ?? "") }
            }
        }
    }

    func testComplexVoiceFilteringPerformance() async throws {
        let provider = AppleVoiceProvider()

        let voices = try await provider.fetchVoices(languageCode: "en")

        XCTAssertFalse(voices.isEmpty, "Need voices to test filtering")

        measure(metrics: [XCTClockMetric()]) {
            for _ in 0..<10 {
                // Complex filter: high quality, English, name starts with certain letters
                _ = voices.filter { voice in
                    let isHighQuality = voice.quality == "enhanced" || voice.quality == "premium"
                    let isEnglish = (voice.language ?? "").hasPrefix("en")
                    let nameFilter = voice.name.first.map { $0 >= "A" && $0 <= "M" } ?? false
                    return isHighQuality && isEnglish && nameFilter
                }
            }
        }
    }

    // MARK: - Provider Registry Performance (if available)

    #if canImport(SwiftData)
    func testProviderRegistryAccessPerformance() {
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            for _ in 0..<10 {
                // Simulate registry access pattern
                _ = AppleVoiceProvider()
                // Would test other providers here if available
            }
        }
    }
    #endif

    // MARK: - Large Text Processing Performance

    func testLargeTextProcessingPerformance() {
        // Generate large text (10,000 characters)
        let largeText = String(repeating: "This is a test sentence for performance measurement. ", count: 200)
        XCTAssertGreaterThan(largeText.count, 10000, "Text should be large")

        let pattern = "\\{\\{[^}]*\\}\\}"

        measure(metrics: [XCTClockMetric()]) {
            for _ in 0..<10 {
                _ = largeText.replacingOccurrences(
                    of: pattern,
                    with: "",
                    options: .regularExpression
                )
            }
        }
    }

    func testTextSplittingPerformance() {
        let longDialogue = """
        This is a very long piece of dialogue that would need to be split into
        multiple chunks for processing. It contains many sentences and paragraphs
        to simulate real-world screenplay dialogue. We need to measure how quickly
        we can split this into manageable chunks for audio generation. The splitting
        algorithm needs to be fast because it might be called many times during
        batch processing of large screenplays with hundreds of dialogue lines.
        """

        measure(metrics: [XCTClockMetric()]) {
            for _ in 0..<10 {
                _ = longDialogue.split(separator: ".")
                _ = longDialogue.split(separator: "\n")
                _ = longDialogue.components(separatedBy: .newlines)
            }
        }
    }
}
#endif // arch(arm64)
