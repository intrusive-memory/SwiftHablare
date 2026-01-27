// AudioWriterTests.swift

import Testing
import Foundation
@testable import QwenTTSEngine
import MLX

@Suite("AudioWriter Tests",
       .enabled(if: ProcessInfo.processInfo.environment["CI"] == nil,
                "MLX requires Metal GPU — skip on CI"))
struct AudioWriterTests {

    @Test("WAV header is 44 bytes")
    func wavHeaderSize() {
        let samples = MLXArray([Float](repeating: 0.0, count: 100))
        let data = AudioWriter.wavData(from: samples)

        // 44-byte header + 100 samples * 2 bytes = 244 bytes
        #expect(data.count == 244)
    }

    @Test("WAV header RIFF magic")
    func wavRIFFMagic() {
        let samples = MLXArray([Float](repeating: 0.0, count: 10))
        let data = AudioWriter.wavData(from: samples)

        #expect(String(data: data[0..<4], encoding: .ascii) == "RIFF")
        #expect(String(data: data[8..<12], encoding: .ascii) == "WAVE")
        #expect(String(data: data[12..<16], encoding: .ascii) == "fmt ")
        #expect(String(data: data[36..<40], encoding: .ascii) == "data")
    }

    @Test("WAV format fields")
    func wavFormatFields() {
        let samples = MLXArray([Float](repeating: 0.0, count: 48000))
        let data = AudioWriter.wavData(from: samples)

        // PCM format = 1
        let format = UInt16(data[20]) | (UInt16(data[21]) << 8)
        #expect(format == 1)

        // Mono = 1 channel
        let channels = UInt16(data[22]) | (UInt16(data[23]) << 8)
        #expect(channels == 1)

        // Sample rate = 24000
        let sampleRate = UInt32(data[24]) | (UInt32(data[25]) << 8) | (UInt32(data[26]) << 16) | (UInt32(data[27]) << 24)
        #expect(sampleRate == 24000)

        // Bits per sample = 16
        let bitsPerSample = UInt16(data[34]) | (UInt16(data[35]) << 8)
        #expect(bitsPerSample == 16)
    }

    @Test("WAV data chunk size")
    func wavDataChunkSize() {
        let numSamples = 1000
        let samples = MLXArray([Float](repeating: 0.5, count: numSamples))
        let data = AudioWriter.wavData(from: samples)

        let dataSize = UInt32(data[40]) | (UInt32(data[41]) << 8) | (UInt32(data[42]) << 16) | (UInt32(data[43]) << 24)
        #expect(dataSize == UInt32(numSamples * 2)) // 16-bit = 2 bytes per sample
    }

    @Test("Clamping clips values outside [-1, 1]")
    func clampingBehavior() {
        let samples = MLXArray([-2.0, -1.0, 0.0, 1.0, 2.0] as [Float])
        let data = AudioWriter.wavData(from: samples)

        // Extract Int16 samples from data (after 44-byte header)
        let audioData = data[44...]
        let int16Samples: [Int16] = audioData.withUnsafeBytes { buffer in
            Array(buffer.bindMemory(to: Int16.self))
        }

        // -2.0 clamped to -1.0 → -32767
        #expect(int16Samples[0] == -32767)
        // -1.0 → -32767
        #expect(int16Samples[1] == -32767)
        // 0.0 → 0
        #expect(int16Samples[2] == 0)
        // 1.0 → 32767
        #expect(int16Samples[3] == 32767)
        // 2.0 clamped to 1.0 → 32767
        #expect(int16Samples[4] == 32767)
    }

    @Test("Write WAV to file")
    func writeWAVToFile() throws {
        let samples = MLXArray([Float](repeating: 0.25, count: 2400))
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_audio_\(UUID().uuidString).wav")

        try AudioWriter.writeWAV(samples: samples, to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let fileData = try Data(contentsOf: tempURL)
        #expect(fileData.count == 44 + 2400 * 2)

        // Verify RIFF header
        #expect(String(data: fileData[0..<4], encoding: .ascii) == "RIFF")
    }

    @Test("Empty audio produces header-only WAV")
    func emptyAudio() {
        let samples = MLXArray([Float]())
        let data = AudioWriter.wavData(from: samples)

        // Just the 44-byte header + 0 data bytes
        #expect(data.count == 44)
    }

    @Test("Sample rate is 24kHz")
    func sampleRateConstant() {
        #expect(AudioWriter.sampleRate == 24000)
    }
}
