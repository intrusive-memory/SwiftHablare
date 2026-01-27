// ModelDownloader.swift
// Download LM weights from HuggingFace, cache locally

import Foundation

public actor ModelDownloader {

    public static let defaultCacheDirectory: URL = {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return caches.appendingPathComponent("SwiftHablare/QwenTTS", isDirectory: true)
    }()

    /// HuggingFace repo for quantized weights
    public static let defaultRepoId = "mlx-community/Qwen3-TTS-12Hz-1.7B-Base-4bit"

    /// Files required from the LM repo
    private static let requiredFiles = [
        "config.json",
        "tokenizer_config.json",
        "vocab.json",
        "merges.txt",
    ]

    /// Safetensors pattern — we discover these dynamically
    private static let safetensorsPattern = "model"

    private let cacheDirectory: URL
    private let repoId: String

    public init(
        cacheDirectory: URL = ModelDownloader.defaultCacheDirectory,
        repoId: String = ModelDownloader.defaultRepoId
    ) {
        self.cacheDirectory = cacheDirectory
        self.repoId = repoId
    }

    // MARK: - Public API

    /// Check if LM model is already downloaded
    public func isModelDownloaded() -> Bool {
        let configPath = cacheDirectory
            .appendingPathComponent("lm")
            .appendingPathComponent("config.json")
        return FileManager.default.fileExists(atPath: configPath.path)
    }

    /// Get path to the LM model directory
    public func lmModelDirectory() -> URL {
        cacheDirectory.appendingPathComponent("lm", isDirectory: true)
    }

    /// Get path to the codec decoder directory
    public func codecDecoderDirectory() -> URL {
        cacheDirectory.appendingPathComponent("codec_decoder", isDirectory: true)
    }

    /// Download the LM model from HuggingFace if not already cached.
    /// Reports progress via the callback (0.0 to 1.0).
    public func downloadIfNeeded(
        progress: (@Sendable (Double, String) -> Void)? = nil
    ) async throws {
        let lmDir = lmModelDirectory()

        if isModelDownloaded() {
            progress?(1.0, "Model already downloaded")
            return
        }

        try FileManager.default.createDirectory(at: lmDir, withIntermediateDirectories: true)

        // Discover files in the repo
        let fileList = try await listRepoFiles()
        let totalFiles = fileList.count
        var downloaded = 0

        for filename in fileList {
            let localPath = lmDir.appendingPathComponent(filename)

            // Skip if already exists
            if FileManager.default.fileExists(atPath: localPath.path) {
                downloaded += 1
                progress?(Double(downloaded) / Double(totalFiles), "Cached: \(filename)")
                continue
            }

            // Create subdirectories if needed
            let parentDir = localPath.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)

            let url = hfFileURL(filename)
            progress?(Double(downloaded) / Double(totalFiles), "Downloading: \(filename)")

            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw QwenTTSError.downloadFailed("Failed to download \(filename)")
            }

            try data.write(to: localPath)
            downloaded += 1
            progress?(Double(downloaded) / Double(totalFiles), "Downloaded: \(filename)")
        }

        progress?(1.0, "Download complete")
    }

    // MARK: - Private

    private func hfFileURL(_ filename: String) -> URL {
        URL(string: "https://huggingface.co/\(repoId)/resolve/main/\(filename)")!
    }

    /// List files in the HuggingFace repo via the API
    private func listRepoFiles() async throws -> [String] {
        let apiURL = URL(string: "https://huggingface.co/api/models/\(repoId)")!
        let (data, response) = try await URLSession.shared.data(from: apiURL)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw QwenTTSError.downloadFailed("Failed to list repo files")
        }

        struct RepoInfo: Decodable {
            let siblings: [Sibling]
            struct Sibling: Decodable {
                let rfilename: String
            }
        }

        let repoInfo = try JSONDecoder().decode(RepoInfo.self, from: data)
        return repoInfo.siblings.map(\.rfilename).filter { filename in
            // Download config, tokenizer, vocab, merges, and safetensors
            Self.requiredFiles.contains(filename) ||
            filename.hasSuffix(".safetensors") ||
            filename == "generation_config.json"
        }
    }
}
