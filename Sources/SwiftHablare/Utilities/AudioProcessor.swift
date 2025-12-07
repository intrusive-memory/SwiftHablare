//
//  AudioProcessor.swift
//  SwiftHablare
//
//  Audio processing utilities for trimming silence and measuring duration
//

import Foundation
import AVFoundation

/// Result of audio processing including trimmed data and metadata
public struct ProcessedAudio: Sendable {
    /// The processed audio data (trimmed)
    public let audioData: Data

    /// The measured duration of the processed audio in seconds
    public let durationSeconds: Double

    /// Amount of silence trimmed from the start in seconds
    public let trimmedStart: Double

    /// Amount of silence trimmed from the end in seconds
    public let trimmedEnd: Double

    public init(audioData: Data, durationSeconds: Double, trimmedStart: Double, trimmedEnd: Double) {
        self.audioData = audioData
        self.durationSeconds = durationSeconds
        self.trimmedStart = trimmedStart
        self.trimmedEnd = trimmedEnd
    }
}

/// Audio processing utilities
public enum AudioProcessor {

    /// Process audio data by trimming silence and measuring duration
    ///
    /// - Parameters:
    ///   - audioData: Raw audio data from provider
    ///   - threshold: Silence detection threshold in dB (default: -50dB for vocal audio)
    /// - Returns: Processed audio with trimmed silence and accurate duration
    /// - Throws: Audio processing errors
    public static func process(audioData: Data, threshold: Float = -50.0) async throws -> ProcessedAudio {
        // Create temporary file to load into AVAsset
        let tempInputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("audio")

        try audioData.write(to: tempInputURL)
        defer { try? FileManager.default.removeItem(at: tempInputURL) }

        let asset = AVURLAsset(url: tempInputURL)

        // Detect silence at start and end
        let (trimStart, trimEnd) = try await detectSilence(in: asset, threshold: threshold)

        // Get total duration
        let totalDuration = try await asset.load(.duration).seconds

        // If no trimming needed, just measure and return
        guard trimStart > 0 || trimEnd > 0 else {
            return ProcessedAudio(
                audioData: audioData,
                durationSeconds: totalDuration,
                trimmedStart: 0,
                trimmedEnd: 0
            )
        }

        // Trim the audio
        let trimmedData = try await trimAudio(
            asset: asset,
            trimStart: trimStart,
            trimEnd: trimEnd
        )

        let trimmedDuration = totalDuration - trimStart - trimEnd

        return ProcessedAudio(
            audioData: trimmedData,
            durationSeconds: trimmedDuration,
            trimmedStart: trimStart,
            trimmedEnd: trimEnd
        )
    }

    /// Detect silence at the beginning and end of audio
    private static func detectSilence(in asset: AVAsset, threshold: Float) async throws -> (trimStart: Double, trimEnd: Double) {
        guard let audioTrack = try await asset.loadTracks(withMediaType: .audio).first else {
            return (0, 0)
        }

        let duration = try await asset.load(.duration).seconds

        guard let reader = try? AVAssetReader(asset: asset) else {
            return (0, 0)
        }

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]

        let output = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: settings)
        reader.add(output)

        guard reader.startReading() else {
            return (0, 0)
        }

        defer {
            reader.cancelReading()
        }

        // Read samples in chunks
        let chunkDuration: Double = 0.1 // 100ms chunks
        var samples: [(time: Double, rms: Float)] = []

        while let sampleBuffer = output.copyNextSampleBuffer() {
            let timeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
            let rms = calculateRMS(sampleBuffer: sampleBuffer)
            samples.append((time: timeStamp, rms: rms))
        }

        guard !samples.isEmpty else {
            return (0, 0)
        }

        // Convert threshold from dB to linear
        let linearThreshold = pow(10, threshold / 20)

        // Find first non-silent sample
        var trimStart: Double = 0
        for sample in samples {
            if sample.rms > linearThreshold {
                trimStart = sample.time
                break
            }
        }

        // Find last non-silent sample
        var trimEnd: Double = 0
        for sample in samples.reversed() {
            if sample.rms > linearThreshold {
                let endTime = sample.time
                trimEnd = max(0, duration - endTime - chunkDuration)
                break
            }
        }

        return (trimStart, trimEnd)
    }

    /// Calculate RMS (Root Mean Square) amplitude from sample buffer
    private static func calculateRMS(sampleBuffer: CMSampleBuffer) -> Float {
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
            return 0
        }

        var length: Int = 0
        var dataPointer: UnsafeMutablePointer<Int8>?

        guard CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &dataPointer) == kCMBlockBufferNoErr else {
            return 0
        }

        guard let data = dataPointer else {
            return 0
        }

        // Interpret as Int16 samples
        let samples = UnsafeBufferPointer(start: data.withMemoryRebound(to: Int16.self, capacity: length / 2) { $0 }, count: length / 2)

        var sum: Float = 0
        for sample in samples {
            let normalized = Float(sample) / Float(Int16.max)
            sum += normalized * normalized
        }

        let mean = sum / Float(samples.count)
        return sqrt(mean)
    }

    /// Trim audio by exporting a time range
    private static func trimAudio(asset: AVAsset, trimStart: Double, trimEnd: Double) async throws -> Data {
        let duration = try await asset.load(.duration)
        let totalDuration = duration.seconds

        // Calculate output time range
        let startTime = CMTime(seconds: trimStart, preferredTimescale: duration.timescale)
        let endDuration = totalDuration - trimStart - trimEnd
        let outputDuration = CMTime(seconds: endDuration, preferredTimescale: duration.timescale)
        let timeRange = CMTimeRange(start: startTime, duration: outputDuration)

        // Export to temporary file
        let tempOutputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")

        defer { try? FileManager.default.removeItem(at: tempOutputURL) }

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw AudioProcessingError.exportFailed("Could not create export session")
        }

        exportSession.outputURL = tempOutputURL
        exportSession.outputFileType = .m4a
        exportSession.timeRange = timeRange

        await exportSession.export()

        if let error = exportSession.error {
            throw AudioProcessingError.exportFailed(error.localizedDescription)
        }

        return try Data(contentsOf: tempOutputURL)
    }
}

/// Audio processing errors
public enum AudioProcessingError: LocalizedError, Sendable {
    case exportFailed(String)
    case invalidAudioData

    public var errorDescription: String? {
        switch self {
        case .exportFailed(let message):
            return "Audio export failed: \(message)"
        case .invalidAudioData:
            return "Invalid audio data"
        }
    }
}
