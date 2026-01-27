// SafetensorsLoader.swift
// Load safetensors via MLX, handle sharded files

import Foundation
import MLX

public enum SafetensorsLoader: Sendable {

    /// Load all weight arrays from a directory containing safetensors files.
    /// Handles both single `model.safetensors` and sharded `model-00001-of-00005.safetensors` patterns.
    public static func loadWeights(from directory: URL) throws -> [String: MLXArray] {
        let fm = FileManager.default
        let contents = try fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        let safetensorsFiles = contents
            .filter { $0.pathExtension == "safetensors" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        guard !safetensorsFiles.isEmpty else {
            throw QwenTTSError.noWeightsFound(directory.path)
        }

        var allWeights: [String: MLXArray] = [:]
        for file in safetensorsFiles {
            let weights = try loadArrays(url: file)
            for (key, value) in weights {
                allWeights[key] = value
            }
        }
        return allWeights
    }

    /// Load a single safetensors file.
    public static func loadWeightsFromFile(_ file: URL) throws -> [String: MLXArray] {
        try loadArrays(url: file)
    }
}

public enum QwenTTSError: Error, LocalizedError, Sendable {
    case noWeightsFound(String)
    case configNotFound(String)
    case downloadFailed(String)
    case tokenizationFailed(String)
    case generationFailed(String)
    case decodingFailed(String)
    case voiceNotFound(String)
    case modelNotDownloaded

    public var errorDescription: String? {
        switch self {
        case .noWeightsFound(let path):
            return "No safetensors files found in: \(path)"
        case .configNotFound(let path):
            return "Config file not found: \(path)"
        case .downloadFailed(let reason):
            return "Download failed: \(reason)"
        case .tokenizationFailed(let reason):
            return "Tokenization failed: \(reason)"
        case .generationFailed(let reason):
            return "Generation failed: \(reason)"
        case .decodingFailed(let reason):
            return "Decoding failed: \(reason)"
        case .voiceNotFound(let name):
            return "Voice not found: \(name)"
        case .modelNotDownloaded:
            return "Model not downloaded. Run 'hablare download' first."
        }
    }
}
