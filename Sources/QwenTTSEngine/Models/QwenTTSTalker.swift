// QwenTTSTalker.swift
// Qwen3TTSTalkerForConditionalGeneration: text embed + codec embed + transformer + code predictor

import Foundation
import MLX
import MLXNN
import MLXFast

// MARK: - Code Predictor

/// Predicts codebook tokens 1..15 given the first codebook token and hidden state.
public class QwenCodePredictor: Module, @unchecked Sendable {
    let config: CodePredictorConfig
    let layers: [QwenTransformerBlock]
    let norm: QwenRMSNorm
    let inputProjection: Linear
    let codeEmbeddings: [Embedding]
    let lmHeads: [Linear]

    public init(config: CodePredictorConfig, numCodeGroups: Int) {
        self.config = config

        self.inputProjection = Linear(
            config.hiddenSize * 2,
            config.hiddenSize,
            bias: false
        )

        var layers: [QwenTransformerBlock] = []
        for _ in 0..<config.numHiddenLayers {
            layers.append(QwenTransformerBlock(
                hiddenSize: config.hiddenSize,
                numHeads: config.numAttentionHeads,
                numKVHeads: config.numKeyValueHeads,
                headDim: config.headDim,
                intermediateSize: config.intermediateSize,
                rmsNormEps: config.rmsNormEps,
                ropeTheta: config.ropeTheta,
                bias: config.attentionBias
            ))
        }
        self.layers = layers
        self.norm = QwenRMSNorm(hiddenSize: config.hiddenSize, eps: config.rmsNormEps)

        var embeddings: [Embedding] = []
        var heads: [Linear] = []
        for _ in 0..<numCodeGroups {
            embeddings.append(Embedding(embeddingCount: config.vocabSize, dimensions: config.hiddenSize))
            heads.append(Linear(config.hiddenSize, config.vocabSize, bias: false))
        }
        self.codeEmbeddings = embeddings
        self.lmHeads = heads

        super.init()
    }

    public func predict(
        hiddenState: MLXArray,
        firstCode: MLXArray,
        numCodeGroups: Int,
        temperature: Float = 0.8
    ) -> MLXArray {
        var codes: [MLXArray] = [firstCode]

        let code0Emb = codeEmbeddings[0](firstCode.expandedDimensions(axis: -1))
        let hiddenSlice = hiddenState[.ellipsis, (-1)...]
        let concatenated = MLX.concatenated([hiddenSlice, code0Emb], axis: -1)
        var h = inputProjection(concatenated)

        let positions = MLXArray(Int32(0)).expandedDimensions(axis: 0).expandedDimensions(axis: 0) // [1, 1]
        for layer in layers {
            h = layer(h, positions: positions)
        }
        h = norm(h)

        for i in 1..<numCodeGroups {
            let logits = lmHeads[i](h)
            let nextCode = sampleToken(logits: logits.squeezed(axis: 1), temperature: temperature)
            codes.append(nextCode)
            if i < numCodeGroups - 1 {
                h = codeEmbeddings[i](nextCode.expandedDimensions(axis: -1))
            }
        }

        return MLX.stacked(codes, axis: -1)
    }
}

// MARK: - Talker Model

public class QwenTTSTalker: Module, @unchecked Sendable {
    let config: TalkerConfig

    let textEmbedding: Embedding
    let textProjection: Linear
    let codecEmbedding: [Embedding]
    let languageEmbedding: Embedding
    let speakerEmbedding: Embedding?

    let layers: [QwenTransformerBlock]
    let norm: QwenRMSNorm
    let lmHead: Linear
    let codePredictor: QwenCodePredictor

    public init(config: TalkerConfig) {
        self.config = config

        self.textEmbedding = Embedding(
            embeddingCount: config.textVocabSize,
            dimensions: config.textHiddenSize
        )
        self.textProjection = Linear(config.textHiddenSize, config.hiddenSize, bias: false)

        var codecEmbs: [Embedding] = []
        for _ in 0..<config.numCodeGroups {
            codecEmbs.append(Embedding(
                embeddingCount: config.vocabSize,
                dimensions: config.hiddenSize
            ))
        }
        self.codecEmbedding = codecEmbs

        self.languageEmbedding = Embedding(
            embeddingCount: config.vocabSize,
            dimensions: config.hiddenSize
        )

        if !config.spkId.isEmpty {
            self.speakerEmbedding = Embedding(
                embeddingCount: config.spkId.count + 1,
                dimensions: config.hiddenSize
            )
        } else {
            self.speakerEmbedding = nil
        }

        var layers: [QwenTransformerBlock] = []
        for _ in 0..<config.numHiddenLayers {
            layers.append(QwenTransformerBlock(
                hiddenSize: config.hiddenSize,
                numHeads: config.numAttentionHeads,
                numKVHeads: config.numKeyValueHeads,
                headDim: config.headDim,
                intermediateSize: config.intermediateSize,
                rmsNormEps: config.rmsNormEps,
                ropeTheta: config.ropeTheta,
                bias: config.attentionBias
            ))
        }
        self.layers = layers
        self.norm = QwenRMSNorm(hiddenSize: config.hiddenSize, eps: config.rmsNormEps)
        self.lmHead = Linear(config.hiddenSize, config.vocabSize, bias: false)
        self.codePredictor = QwenCodePredictor(
            config: config.codePredictorConfig,
            numCodeGroups: config.numCodeGroups
        )

        super.init()
    }

    public func generate(
        textTokens: MLXArray,
        languageId: Int,
        speakerId: Int? = nil,
        maxTokens: Int = 2048,
        temperature: Float = 0.8
    ) -> MLXArray {
        let B = textTokens.dim(0)
        let hiddenSize = config.hiddenSize

        // 1. Embed text tokens and project to hidden size
        let textEmb = textProjection(textEmbedding(textTokens))

        // 2. Language embedding [1, 1, hidden] → broadcast to [B, 1, hidden]
        let langTokens = MLXArray([Int32(languageId)])
        let langEmb = broadcast(
            languageEmbedding(langTokens).expandedDimensions(axis: 0),
            to: [B, 1, hiddenSize]
        )

        var prefix: [MLXArray] = [textEmb, langEmb]

        if let spkEmb = speakerEmbedding, let spkId = speakerId {
            let sTokens = MLXArray([Int32(spkId)])
            let sEmb = broadcast(
                spkEmb(sTokens).expandedDimensions(axis: 0),
                to: [B, 1, hiddenSize]
            )
            prefix.append(sEmb)
        }

        // 3. BOS token
        let bosTokens = MLXArray([Int32(config.codecBosId)])
        let bosEmb = broadcast(
            codecEmbedding[0](bosTokens).expandedDimensions(axis: 0),
            to: [B, 1, hiddenSize]
        )
        prefix.append(bosEmb)

        let inputEmbeddings = MLX.concatenated(prefix, axis: 1)
        let prefixLen = inputEmbeddings.dim(1)

        // 4. KV caches
        var caches = layers.map { _ in KVCache() }

        // 5. Prefill
        let posArray = MLXArray(Array(stride(from: Int32(0), to: Int32(prefixLen), by: 1)))
        let positions = broadcast(
            posArray.expandedDimensions(axis: 0),
            to: [B, prefixLen]
        )

        var h = inputEmbeddings
        for (i, layer) in layers.enumerated() {
            h = layer(h, positions: positions, cache: caches[i])
        }
        h = norm(h)

        var logits = lmHead(h[.ellipsis, (-1)...])
        var allCodes: [MLXArray] = []
        var currentPos = Int32(prefixLen)

        // 6. Autoregressive generation loop
        for _ in 0..<maxTokens {
            let samplingLogits = logits.squeezed(axis: 1)
            let firstCode = sampleToken(logits: samplingLogits, temperature: temperature)

            if firstCode.item(Int.self) == config.codecEosTokenId {
                break
            }

            let hiddenForPredictor = h[.ellipsis, (-1)...]
            let frameCodes = codePredictor.predict(
                hiddenState: hiddenForPredictor,
                firstCode: firstCode,
                numCodeGroups: config.numCodeGroups,
                temperature: temperature
            )
            allCodes.append(frameCodes)

            // Prepare next input: sum of all codec embeddings for this frame
            var nextEmb = MLXArray.zeros([B, 1, hiddenSize])
            for g in 0..<config.numCodeGroups {
                let codeForGroup = frameCodes[.ellipsis, g]
                nextEmb = nextEmb + codecEmbedding[g](codeForGroup.expandedDimensions(axis: -1))
            }

            let stepPos = broadcast(
                MLXArray([currentPos]).expandedDimensions(axis: 0),
                to: [B, 1]
            )
            h = nextEmb
            for (i, layer) in layers.enumerated() {
                h = layer(h, positions: stepPos, cache: caches[i])
            }
            h = norm(h)
            logits = lmHead(h)
            currentPos += 1
        }

        guard !allCodes.isEmpty else {
            return MLXArray.zeros([B, 0, config.numCodeGroups]).asType(.int32)
        }

        return MLX.stacked(allCodes, axis: 1)
    }
}

// MARK: - Sampling

func sampleToken(logits: MLXArray, temperature: Float = 0.8, topK: Int = 50) -> MLXArray {
    if temperature <= 0 {
        return MLX.argMax(logits, axis: -1)
    }

    let scaled = logits / temperature

    // Top-k filtering
    let k = min(topK, scaled.dim(-1))
    let topKValues = MLX.top(scaled, k: k, axis: -1)
    let threshold = topKValues.min(axis: -1, keepDims: true)
    let filtered = MLX.which(scaled .>= threshold, scaled, MLXArray(Float(-1e9)))

    // Softmax + categorical sample
    let probs = MLX.softmax(filtered, axis: -1)
    return MLXRandom.categorical(MLX.log(probs + 1e-10))
}
