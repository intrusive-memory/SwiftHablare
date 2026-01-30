// HablareCLI.swift
// hablare CLI: say-like text-to-speech using Qwen3-TTS on Apple Silicon

import ArgumentParser
import Foundation
import QwenTTSEngine

@main
struct HablareCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "hablare",
        abstract: "Text-to-speech using Qwen3-TTS on Apple Silicon via MLX",
        version: "5.5.1",
        subcommands: [Generate.self, Voices.self, Download.self, Info.self],
        defaultSubcommand: Generate.self
    )
}

// MARK: - Generate (default command)

struct Generate: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Generate speech from text (default command)"
    )

    @Argument(help: "Text to speak")
    var text: String

    @Option(name: [.short, .long], help: "Output WAV file path")
    var output: String = "output.wav"

    @Option(name: [.short, .long], help: "Voice name")
    var voice: String?

    @Option(name: [.short, .long], help: "Language (english, chinese, spanish, etc.)")
    var language: String = "english"

    @Option(name: [.short, .long], help: "Maximum audio frames to generate")
    var maxTokens: Int = 2048

    @Option(name: [.short, .long], help: "Sampling temperature (0.0-1.5)")
    var temperature: Float = 0.8

    func run() async throws {
        let engine = QwenTTSEngine()

        print("Loading model...")
        try await engine.loadModel { progress, message in
            print("\r\(message) [\(Int(progress * 100))%]", terminator: "")
            fflush(stdout)
        }
        print()

        print("Generating speech...")
        let outputURL = URL(fileURLWithPath: output)

        try await engine.generateToFile(
            text: text,
            outputURL: outputURL,
            voice: voice,
            language: language,
            maxTokens: maxTokens,
            temperature: temperature
        )

        print("Saved to: \(outputURL.path)")
    }
}

// MARK: - Voices

struct Voices: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "List available voices"
    )

    func run() async throws {
        let engine = QwenTTSEngine()

        try await engine.loadModel { _, message in
            print("\r\(message)", terminator: "")
            fflush(stdout)
        }
        print()

        let voices = await engine.availableVoices()
        let languages = await engine.supportedLanguages()

        if voices.isEmpty {
            print("No named voices available (base model uses speaker conditioning).")
        } else {
            print("Available voices:")
            for voice in voices {
                print("  \(voice.name) (id: \(voice.id), speaker: \(voice.speakerId))")
            }
        }

        print("\nSupported languages:")
        for lang in languages {
            print("  \(lang)")
        }
    }
}

// MARK: - Download

struct Download: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Download model weights from HuggingFace"
    )

    @Option(name: .long, help: "HuggingFace repo ID")
    var repo: String = ModelDownloader.defaultRepoId

    func run() async throws {
        let downloader = ModelDownloader(repoId: repo)

        if await downloader.isModelDownloaded() {
            print("Model already downloaded at: \(await downloader.lmModelDirectory().path)")
            return
        }

        print("Downloading model from: \(repo)")
        try await downloader.downloadIfNeeded { progress, message in
            print("\r\(message) [\(Int(progress * 100))%]", terminator: "")
            fflush(stdout)
        }
        print("\nDownload complete!")
        print("Model stored at: \(await downloader.lmModelDirectory().path)")
    }
}

// MARK: - Info

struct Info: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Show model information"
    )

    func run() async throws {
        let downloader = ModelDownloader()
        let isDownloaded = await downloader.isModelDownloaded()

        print("Qwen3-TTS Speech Synthesis Engine")
        print("==================================")
        print("Model: Qwen3-TTS-12Hz-1.7B-Base (4-bit quantized)")
        print("Architecture: Talker LM (1.7B) + Codec Decoder (114M)")
        print("Audio: 24kHz mono, 16-bit PCM WAV")
        print("Backend: MLX (Apple Silicon GPU)")
        print("Codebooks: 16 @ 12Hz frame rate")
        print("Languages: Chinese, English, French, German, Italian, Japanese, Korean, Portuguese, Russian, Spanish")
        print()
        print("Cache directory: \(ModelDownloader.defaultCacheDirectory.path)")
        print("Model downloaded: \(isDownloaded ? "Yes" : "No")")

        if isDownloaded {
            let lmDir = await downloader.lmModelDirectory()
            let fm = FileManager.default
            if let contents = try? fm.contentsOfDirectory(at: lmDir, includingPropertiesForKeys: [.fileSizeKey]) {
                let totalSize = contents.compactMap { url -> Int? in
                    try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize
                }.reduce(0, +)
                print("Model size: \(ByteCountFormatter.string(fromByteCount: Int64(totalSize), countStyle: .file))")
            }
        }
    }
}
