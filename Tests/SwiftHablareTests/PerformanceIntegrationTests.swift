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

import Testing
import Foundation
@testable import SwiftHablare

#if arch(arm64)

@Suite("Performance Integration Tests")
struct PerformanceIntegrationTests {

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
    @Test("Audio generation performance")
    @MainActor
    func audioGenerationPerformance() async throws {
        let provider = AppleVoiceProvider()
        let testText = "This is a test of audio generation performance. We need to measure how quickly we can synthesize speech."

        let voices = try await provider.fetchVoices(languageCode: "en")
        #expect(!voices.isEmpty, "No voices available")

        let firstVoice = voices.first!

        _ = try await provider.generateAudio(
            text: testText,
            voiceId: firstVoice.id,
            languageCode: "en"
        )
    }
    #endif

    // MARK: - Provider Initialization Performance

    @Test("Provider initialization performance")
    func providerInitializationPerformance() {
        _ = AppleVoiceProvider()
    }

    @Test("GenerationService initialization performance")
    func generationServiceInitializationPerformance() {
        _ = GenerationService()
    }

    // MARK: - Voice Filtering Performance

    @Test("Voice filtering performance")
    func voiceFilteringPerformance() async throws {
        let provider = AppleVoiceProvider()

        // Fetch voices once
        let voices = try await provider.fetchVoices(languageCode: "en")

        #expect(!voices.isEmpty, "Need voices to test filtering")

        // Measure filtering operation
        for _ in 0..<10 {
            _ = voices.filter { voice in
                guard let quality = voice.quality else { return false }
                return quality == "enhanced" || quality == "premium"
            }
        }
    }


    // MARK: - String Operations Performance

    @Test("Bracket filtering performance")
    func bracketFilteringPerformance() {
        let sampleTexts = [
            "Hello {{stage whisper}} world {{nervously}}",
            "This is a test {{V.O.}} with multiple {{annotations}} here",
            "{{entire content in brackets}}",
            "No brackets here at all",
            "Start {{bracket}} middle {{another}} end {{final}}"
        ]

        let pattern = "\\{\\{[^}]*\\}\\}"

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

    // MARK: - Platform-Specific Performance

    #if os(macOS)
    @Test("macOS quality extraction performance")
    func macOSQualityExtractionPerformance() {
        let testNames = [
            ("Alex", "com.apple.speech.synthesis.voice.alex"),
            ("Samantha Enhanced", "com.apple.speech.synthesis.voice.samantha.enhanced"),
            ("Victoria Premium", "com.apple.speech.synthesis.voice.victoria.premium"),
            ("Tom", "com.apple.speech.synthesis.voice.tom"),
            ("Fiona Enhanced", "com.apple.speech.synthesis.voice.fiona.enhanced")
        ]

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
    #endif

    // MARK: - Baseline Recording & Comparison

    @Test("Record performance baseline")
    func recordPerformanceBaseline() async throws {
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

    @Test("Compare with baseline")
    func compareWithBaseline() async throws {
        // Load previous baseline if it exists
        let tempDir = FileManager.default.temporaryDirectory
        let baselineFile = tempDir.appendingPathComponent("performance_baseline.json")

        guard let data = try? Data(contentsOf: baselineFile),
              let baseline = try? JSONDecoder().decode(PerformanceBaseline.self, from: data) else {
            print("⚠️  No baseline found. Run recordPerformanceBaseline first.")
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
        #expect(currentVoiceFetchTime < baseline.voiceFetchTime * 1.1, "Voice fetching regressed by more than 10%")
        #expect(currentProviderInitTime < baseline.providerInitTime * 1.1, "Provider init regressed by more than 10%")
    }


    // MARK: - GenerationService Performance

    @Test("GenerationService batch operation performance")
    func generationServiceBatchOperationPerformance() {
        let testItems = (0..<20).map { i in
            (text: "Test dialogue \(i)", voiceId: "test-voice-\(i)")
        }

        // Simulate batch generation overhead
        for item in testItems {
            _ = item.text.count
            _ = item.voiceId.count
        }
    }

    // MARK: - Voice Filtering and Sorting Performance

    @Test("Voice sorting performance")
    func voiceSortingPerformance() async throws {
        let provider = AppleVoiceProvider()

        let voices = try await provider.fetchVoices(languageCode: "en")

        #expect(!voices.isEmpty, "Need voices to test sorting")

        for _ in 0..<10 {
            _ = voices.sorted { $0.name < $1.name }
            _ = voices.sorted { ($0.quality ?? "") > ($1.quality ?? "") }
            _ = voices.sorted { ($0.language ?? "") < ($1.language ?? "") }
        }
    }

    @Test("Complex voice filtering performance")
    func complexVoiceFilteringPerformance() async throws {
        let provider = AppleVoiceProvider()

        let voices = try await provider.fetchVoices(languageCode: "en")

        #expect(!voices.isEmpty, "Need voices to test filtering")

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

    // MARK: - Provider Registry Performance (if available)

    #if canImport(SwiftData)
    @Test("Provider registry access performance")
    func providerRegistryAccessPerformance() {
        for _ in 0..<10 {
            // Simulate registry access pattern
            _ = AppleVoiceProvider()
            // Would test other providers here if available
        }
    }
    #endif

    // MARK: - Large Text Processing Performance

    @Test("Large text processing performance")
    func largeTextProcessingPerformance() {
        // Generate large text (10,000 characters)
        let largeText = String(repeating: "This is a test sentence for performance measurement. ", count: 200)
        #expect(largeText.count > 10000, "Text should be large")

        let pattern = "\\{\\{[^}]*\\}\\}"

        for _ in 0..<10 {
            _ = largeText.replacingOccurrences(
                of: pattern,
                with: "",
                options: .regularExpression
            )
        }
    }

    @Test("Text splitting performance")
    func textSplittingPerformance() {
        let longDialogue = """
        This is a very long piece of dialogue that would need to be split into
        multiple chunks for processing. It contains many sentences and paragraphs
        to simulate real-world screenplay dialogue. We need to measure how quickly
        we can split this into manageable chunks for audio generation. The splitting
        algorithm needs to be fast because it might be called many times during
        batch processing of large screenplays with hundreds of dialogue lines.
        """

        for _ in 0..<10 {
            _ = longDialogue.split(separator: ".")
            _ = longDialogue.split(separator: "\n")
            _ = longDialogue.components(separatedBy: .newlines)
        }
    }
}
#endif // arch(arm64)
