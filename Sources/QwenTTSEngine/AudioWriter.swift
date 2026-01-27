// AudioWriter.swift
// float32 24kHz → 16-bit PCM WAV (manual header, no AVFoundation dependency)

import Foundation
import MLX

public enum AudioWriter: Sendable {

    /// Sample rate for Qwen3 TTS output
    public static let sampleRate: Int = 24000

    /// Write float32 audio samples to a 16-bit PCM WAV file.
    /// - Parameters:
    ///   - samples: MLXArray of float32 samples in [-1, 1], shape [T] or [1, T]
    ///   - url: destination file URL
    public static func writeWAV(samples: MLXArray, to url: URL) throws {
        let flat = samples.reshaped(-1)
        let count = flat.dim(0)

        // Clamp to [-1, 1] and convert to Int16
        let clamped = MLX.clip(flat, min: -1.0, max: 1.0)
        let scaled = (clamped * 32767.0).asType(.int16)

        // Extract raw bytes
        let int16Array: [Int16] = (0..<count).map { i in
            scaled[i].item(Int16.self)
        }

        // Build WAV file
        let audioData = int16Array.withUnsafeBufferPointer { buffer in
            Data(buffer: buffer)
        }

        let wavData = buildWAVHeader(
            dataSize: audioData.count,
            sampleRate: sampleRate,
            bitsPerSample: 16,
            numChannels: 1
        ) + audioData

        try wavData.write(to: url)
    }

    /// Convert float32 samples to WAV Data (in-memory).
    public static func wavData(from samples: MLXArray) -> Data {
        let flat = samples.reshaped(-1)
        let count = flat.dim(0)

        let clamped = MLX.clip(flat, min: -1.0, max: 1.0)
        let scaled = (clamped * 32767.0).asType(.int16)

        let int16Array: [Int16] = (0..<count).map { i in
            scaled[i].item(Int16.self)
        }

        let audioData = int16Array.withUnsafeBufferPointer { buffer in
            Data(buffer: buffer)
        }

        return buildWAVHeader(
            dataSize: audioData.count,
            sampleRate: sampleRate,
            bitsPerSample: 16,
            numChannels: 1
        ) + audioData
    }

    /// Build a standard 44-byte WAV header.
    private static func buildWAVHeader(
        dataSize: Int,
        sampleRate: Int,
        bitsPerSample: Int,
        numChannels: Int
    ) -> Data {
        var header = Data(count: 44)
        let byteRate = sampleRate * numChannels * bitsPerSample / 8
        let blockAlign = numChannels * bitsPerSample / 8
        let fileSize = 36 + dataSize

        // RIFF header
        header[0...3] = Data("RIFF".utf8)
        writeUInt32LE(&header, offset: 4, value: UInt32(fileSize))
        header[8...11] = Data("WAVE".utf8)

        // fmt chunk
        header[12...15] = Data("fmt ".utf8)
        writeUInt32LE(&header, offset: 16, value: 16) // chunk size
        writeUInt16LE(&header, offset: 20, value: 1)  // PCM format
        writeUInt16LE(&header, offset: 22, value: UInt16(numChannels))
        writeUInt32LE(&header, offset: 24, value: UInt32(sampleRate))
        writeUInt32LE(&header, offset: 28, value: UInt32(byteRate))
        writeUInt16LE(&header, offset: 32, value: UInt16(blockAlign))
        writeUInt16LE(&header, offset: 34, value: UInt16(bitsPerSample))

        // data chunk
        header[36...39] = Data("data".utf8)
        writeUInt32LE(&header, offset: 40, value: UInt32(dataSize))

        return header
    }

    private static func writeUInt32LE(_ data: inout Data, offset: Int, value: UInt32) {
        data[offset] = UInt8(value & 0xFF)
        data[offset + 1] = UInt8((value >> 8) & 0xFF)
        data[offset + 2] = UInt8((value >> 16) & 0xFF)
        data[offset + 3] = UInt8((value >> 24) & 0xFF)
    }

    private static func writeUInt16LE(_ data: inout Data, offset: Int, value: UInt16) {
        data[offset] = UInt8(value & 0xFF)
        data[offset + 1] = UInt8((value >> 8) & 0xFF)
    }
}
