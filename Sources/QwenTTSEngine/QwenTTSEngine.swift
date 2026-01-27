// QwenTTSEngine.swift
// Public actor: orchestrates tokenize → generate → decode → WAV

import Foundation
import MLX
import MLXNN
import Tokenizers

/// Main TTS engine for Qwen3-TTS speech synthesis on Apple Silicon via MLX.
public actor QwenTTSEngine {

    /// Engine state
    public enum State: Sendable {
        case unloaded
        case loading
        case ready
        case generating
    }

    public private(set) var state: State = .unloaded

    private var talker: QwenTTSTalker?
    private var codecDecoder: QwenCodecDecoder?
    private var tokenizer: (any Tokenizer)?
    private var modelConfig: QwenTTSModelConfig?
    private var voiceCatalog: VoiceCatalog?

    private let downloader: ModelDownloader

    public init(cacheDirectory: URL? = nil) {
        if let dir = cacheDirectory {
            self.downloader = ModelDownloader(cacheDirectory: dir)
        } else {
            self.downloader = ModelDownloader()
        }
    }

    // MARK: - Public API

    /// Load the model. Downloads weights if not cached.
    public func loadModel(
        progress: (@Sendable (Double, String) -> Void)? = nil
    ) async throws {
        guard state == .unloaded else { return }
        state = .loading

        // Download if needed
        try await downloader.downloadIfNeeded(progress: progress)

        let lmDir = await downloader.lmModelDirectory()

        // Load config
        let configURL = lmDir.appendingPathComponent("config.json")
        let configData = try Data(contentsOf: configURL)
        let config = try JSONDecoder().decode(QwenTTSModelConfig.self, from: configData)
        self.modelConfig = config

        // Build voice catalog
        self.voiceCatalog = VoiceCatalog(from: config.talkerConfig)

        // Load tokenizer
        let tokenizerConfig = lmDir.appendingPathComponent("tokenizer_config.json")
        if FileManager.default.fileExists(atPath: tokenizerConfig.path) {
            self.tokenizer = try await AutoTokenizer.from(modelFolder: lmDir)
        }

        // Build talker model
        let talker = QwenTTSTalker(config: config.talkerConfig)
        let talkerWeights = try SafetensorsLoader.loadWeights(from: lmDir)

        // Filter and remap weight keys for talker
        let talkerPrefix = "talker."
        var mappedWeights: [String: MLXArray] = [:]
        for (key, value) in talkerWeights {
            if key.hasPrefix(talkerPrefix) {
                let shortKey = String(key.dropFirst(talkerPrefix.count))
                mappedWeights[shortKey] = value
            } else if !key.hasPrefix("speech_tokenizer.") && !key.hasPrefix("speaker_encoder.") {
                mappedWeights[key] = value
            }
        }

        // Load weights into model
        let parameters = ModuleParameters.unflattened(mappedWeights)
        talker.update(parameters: parameters)
        self.talker = talker

        // Load codec decoder if available
        try loadCodecDecoder(from: lmDir, allWeights: talkerWeights)

        MLX.GPU.set(cacheLimit: 2 * 1024 * 1024 * 1024) // 2GB cache
        state = .ready
    }

    /// Generate speech from text.
    /// - Parameters:
    ///   - text: The text to speak
    ///   - voice: Optional voice name
    ///   - language: Language name (default: "english")
    ///   - maxTokens: Maximum audio frames
    ///   - temperature: Sampling temperature
    /// - Returns: Float32 audio samples as MLXArray
    public func generate(
        text: String,
        voice: String? = nil,
        language: String = "english",
        maxTokens: Int = 2048,
        temperature: Float = 0.8
    ) async throws -> MLXArray {
        guard state == .ready, let talker, let codecDecoder, let tokenizer, let config = modelConfig else {
            throw QwenTTSError.modelNotDownloaded
        }

        state = .generating
        defer { state = .ready }

        // 1. Tokenize text
        let chatText = "<|im_start|>assistant\n\(text)<|im_end|>\n<|im_start|>assistant\n"
        let tokenIds = tokenizer.encode(text: chatText)
        guard !tokenIds.isEmpty else {
            throw QwenTTSError.tokenizationFailed("Empty token sequence")
        }

        let tokens = MLXArray(tokenIds.map { Int32($0) }).expandedDimensions(axis: 0) // [1, T]

        // 2. Resolve language
        let catalog = voiceCatalog ?? VoiceCatalog(from: config.talkerConfig)
        let langId = catalog.languageId(for: language) ?? catalog.defaultLanguageId

        // 3. Resolve voice
        var speakerId: Int? = nil
        if let voiceName = voice {
            guard let v = catalog.voice(named: voiceName) else {
                throw QwenTTSError.voiceNotFound(voiceName)
            }
            speakerId = v.speakerId
        }

        // 4. Generate audio codes
        let codes = talker.generate(
            textTokens: tokens,
            languageId: langId,
            speakerId: speakerId,
            maxTokens: maxTokens,
            temperature: temperature
        )

        guard codes.dim(1) > 0 else {
            throw QwenTTSError.generationFailed("No audio codes generated")
        }

        // 5. Decode to waveform
        let waveform = codecDecoder.decode(codes: codes) // [1, T_audio]

        return waveform.squeezed(axis: 0) // [T_audio]
    }

    /// Generate speech and write directly to a WAV file.
    public func generateToFile(
        text: String,
        outputURL: URL,
        voice: String? = nil,
        language: String = "english",
        maxTokens: Int = 2048,
        temperature: Float = 0.8
    ) async throws {
        let samples = try await generate(
            text: text,
            voice: voice,
            language: language,
            maxTokens: maxTokens,
            temperature: temperature
        )
        try AudioWriter.writeWAV(samples: samples, to: outputURL)
    }

    /// Generate speech and return WAV data.
    public func generateToData(
        text: String,
        voice: String? = nil,
        language: String = "english",
        maxTokens: Int = 2048,
        temperature: Float = 0.8
    ) async throws -> Data {
        let samples = try await generate(
            text: text,
            voice: voice,
            language: language,
            maxTokens: maxTokens,
            temperature: temperature
        )
        return AudioWriter.wavData(from: samples)
    }

    /// Get available voices.
    public func availableVoices() -> [QwenTTSVoice] {
        voiceCatalog?.voices ?? []
    }

    /// Get supported languages.
    public func supportedLanguages() -> [String] {
        voiceCatalog?.supportedLanguages.keys.sorted() ?? []
    }

    /// Check if model is downloaded.
    public func isModelDownloaded() async -> Bool {
        await downloader.isModelDownloaded()
    }

    // MARK: - Private

    private func loadCodecDecoder(from lmDir: URL, allWeights: [String: MLXArray]) throws {
        // Try loading codec decoder config from speech_tokenizer subdirectory
        let codecConfigPaths = [
            lmDir.appendingPathComponent("speech_tokenizer/config.json"),
            lmDir.appendingPathComponent("codec_decoder_config.json"),
        ]

        var codecConfig: SpeechTokenizerConfig? = nil
        for path in codecConfigPaths {
            if FileManager.default.fileExists(atPath: path.path) {
                let data = try Data(contentsOf: path)
                codecConfig = try JSONDecoder().decode(SpeechTokenizerConfig.self, from: data)
                break
            }
        }

        guard let config = codecConfig else {
            // Codec decoder config not found — will fail at decode time
            // This is expected for quantized LM-only repos
            return
        }

        let decoder = QwenCodecDecoder(config: config)

        // Load codec decoder weights
        let prefix = "speech_tokenizer.decoder."
        var decoderWeights: [String: MLXArray] = [:]
        for (key, value) in allWeights {
            if key.hasPrefix(prefix) {
                decoderWeights[String(key.dropFirst(prefix.count))] = value
            }
        }

        // Also try loading from separate safetensors
        let codecWeightPaths = [
            lmDir.appendingPathComponent("speech_tokenizer/model.safetensors"),
        ]
        for path in codecWeightPaths {
            if FileManager.default.fileExists(atPath: path.path) {
                let weights = try SafetensorsLoader.loadWeights(from: path)
                for (key, value) in weights {
                    if key.hasPrefix("decoder.") {
                        decoderWeights[String(key.dropFirst("decoder.".count))] = value
                    } else {
                        decoderWeights[key] = value
                    }
                }
                break
            }
        }

        if !decoderWeights.isEmpty {
            let parameters = ModuleParameters.unflattened(decoderWeights)
            decoder.update(parameters: parameters)
        }

        self.codecDecoder = decoder
    }
}
