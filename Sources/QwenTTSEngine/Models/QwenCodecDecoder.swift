// QwenCodecDecoder.swift
// Codec decoder: audio codes → waveform
// Architecture: Split RVQ dequant → pre-transformer → causal conv → upsample → Snake + ConvNeXt → waveform

import Foundation
import MLX
import MLXNN
import MLXFast

// MARK: - Snake Activation

/// SnakeBeta(x) = x + (1/beta) * sin²(x * alpha)
public class SnakeActivation: Module, @unchecked Sendable {
    let alpha: MLXArray
    let beta: MLXArray

    public init(channels: Int) {
        self.alpha = MLXArray.ones([1, channels, 1])
        self.beta = MLXArray.ones([1, channels, 1])
        super.init()
    }

    public func callAsFunction(_ x: MLXArray) -> MLXArray {
        // x: [B, C, T]
        let sinPart = MLX.sin(x * alpha)
        return x + (1.0 / beta) * sinPart * sinPart
    }
}

// MARK: - Causal Conv1d

public class CausalConv1d: Module, @unchecked Sendable {
    let weight: MLXArray
    let bias: MLXArray?
    let padding: Int
    let stride: Int
    let dilation: Int
    let groups: Int

    public init(
        inChannels: Int,
        outChannels: Int,
        kernelSize: Int,
        stride: Int = 1,
        dilation: Int = 1,
        groups: Int = 1,
        bias: Bool = true
    ) {
        self.stride = stride
        self.dilation = dilation
        self.groups = groups
        self.padding = (kernelSize - 1) * dilation  // causal: pad left only

        // MLX conv1d weight: [outChannels, kernelSize, inChannels/groups]
        self.weight = MLXArray.zeros([outChannels, kernelSize, inChannels / groups])
        self.bias = bias ? MLXArray.zeros([outChannels]) : nil
        super.init()
    }

    public func callAsFunction(_ x: MLXArray) -> MLXArray {
        // x: [B, C, T] → MLX conv expects [B, T, C]
        var input = x.transposed(0, 2, 1)

        // Left-pad for causality
        if padding > 0 {
            let padArray = MLXArray.zeros([input.dim(0), padding, input.dim(2)])
            input = MLX.concatenated([padArray, input], axis: 1)
        }

        var output = MLX.conv1d(
            input,
            weight,
            stride: stride,
            padding: 0,
            dilation: dilation,
            groups: groups
        )

        if let bias = bias {
            output = output + bias
        }

        // Back to [B, C, T]
        return output.transposed(0, 2, 1)
    }
}

// MARK: - Causal Transpose Conv1d (Upsampling)

public class CausalTransposeConv1d: Module, @unchecked Sendable {
    let weight: MLXArray
    let bias: MLXArray?
    let stride: Int
    let trimRight: Int

    public init(inChannels: Int, outChannels: Int, kernelSize: Int, stride: Int, bias: Bool = true) {
        self.stride = stride
        self.trimRight = kernelSize - stride  // remove right padding for causality

        // Transpose conv weight
        self.weight = MLXArray.zeros([outChannels, kernelSize, inChannels])
        self.bias = bias ? MLXArray.zeros([outChannels]) : nil
        super.init()
    }

    public func callAsFunction(_ x: MLXArray) -> MLXArray {
        // x: [B, C, T] → [B, T, C] for MLX
        let input = x.transposed(0, 2, 1)

        // Transpose convolution via manual upsampling + conv
        // Insert stride-1 zeros between each sample
        let B = input.dim(0)
        let T = input.dim(1)
        let C = input.dim(2)
        let upT = T * stride

        // Upsample by inserting zeros
        var upsampled = MLXArray.zeros([B, upT, C])
        // Place original samples at stride intervals
        for t in 0..<T {
            upsampled[0..., (t * stride)...(t * stride), 0...] = input[0..., t...t, 0...]
        }

        // Apply regular conv
        let kernelSize = weight.dim(1)
        let padAmount = kernelSize - 1
        let padArray = MLXArray.zeros([B, padAmount, C])
        let padded = MLX.concatenated([padArray, upsampled], axis: 1)

        var output = MLX.conv1d(padded, weight, stride: 1, padding: 0)

        if let bias = bias {
            output = output + bias
        }

        // Trim right for causality
        if trimRight > 0 {
            let validLen = output.dim(1) - trimRight
            output = output[0..., 0..<validLen, 0...]
        }

        return output.transposed(0, 2, 1)
    }
}

// MARK: - ConvNeXt Block

public class ConvNeXtBlock: Module, @unchecked Sendable {
    let dwConv: CausalConv1d
    let norm: LayerNorm
    let pwConv1: Linear
    let pwConv2: Linear
    let gamma: MLXArray?

    public init(dim: Int, intermediateDim: Int, layerScaleInit: Float = 0.01, kernelSize: Int = 7) {
        self.dwConv = CausalConv1d(
            inChannels: dim,
            outChannels: dim,
            kernelSize: kernelSize,
            groups: dim
        )
        self.norm = LayerNorm(dimensions: dim)
        self.pwConv1 = Linear(dim, intermediateDim)
        self.pwConv2 = Linear(intermediateDim, dim)
        self.gamma = MLXArray([Float](repeating: layerScaleInit, count: dim))
        super.init()
    }

    public func callAsFunction(_ x: MLXArray) -> MLXArray {
        // x: [B, C, T]
        let residual = x
        var h = dwConv(x) // [B, C, T]

        // LayerNorm expects last dim → transpose
        h = h.transposed(0, 2, 1) // [B, T, C]
        h = norm(h)
        h = pwConv1(h)
        h = gelu(h)
        h = pwConv2(h)
        if let gamma = gamma {
            h = h * gamma
        }
        h = h.transposed(0, 2, 1) // [B, C, T]

        return residual + h
    }
}

// MARK: - Split Residual Vector Quantizer (Dequantization)

public class SplitRVQDequantizer: Module, @unchecked Sendable {
    let semanticCodebook: Embedding
    let acousticCodebooks: [Embedding]
    let semanticProjection: Linear
    let acousticProjection: Linear
    let numSemanticQuantizers: Int

    public init(config: DecoderConfig) {
        self.numSemanticQuantizers = config.numSemanticQuantizers

        // Semantic codebook (typically 1, with size 4096)
        self.semanticCodebook = Embedding(
            embeddingCount: config.semanticCodebookSize,
            dimensions: config.codebookDim
        )

        // Acoustic codebooks (15, with size 2048 each)
        var acousticCBs: [Embedding] = []
        let numAcoustic = config.numQuantizers - config.numSemanticQuantizers
        for _ in 0..<numAcoustic {
            acousticCBs.append(Embedding(
                embeddingCount: config.codebookSize,
                dimensions: config.codebookDim
            ))
        }
        self.acousticCodebooks = acousticCBs

        // Projections from codebook dim to latent dim
        self.semanticProjection = Linear(
            config.codebookDim,
            config.vectorQuantizationHiddenDimension,
            bias: false
        )
        self.acousticProjection = Linear(
            config.codebookDim,
            config.vectorQuantizationHiddenDimension,
            bias: false
        )

        super.init()
    }

    /// Dequantize codes to continuous features.
    /// - Parameter codes: [B, T, numQuantizers] — integer code indices
    /// - Returns: [B, T, vqHiddenDim] — continuous features
    public func callAsFunction(_ codes: MLXArray) -> MLXArray {
        // Semantic codes
        let semanticCodes = codes[.ellipsis, 0..<numSemanticQuantizers]
        var semanticFeatures = semanticCodebook(semanticCodes[.ellipsis, 0])
        semanticFeatures = semanticProjection(semanticFeatures)

        // Acoustic codes
        var acousticSum = MLXArray.zeros(semanticFeatures.shape)
        let numAcoustic = codes.dim(-1) - numSemanticQuantizers
        for i in 0..<numAcoustic {
            let code = codes[.ellipsis, numSemanticQuantizers + i]
            acousticSum = acousticSum + acousticCodebooks[i](code)
        }
        let acousticFeatures = acousticProjection(acousticSum)

        return semanticFeatures + acousticFeatures
    }
}

// MARK: - Decoder Transformer

public class DecoderTransformer: Module, @unchecked Sendable {
    let layers: [QwenTransformerBlock]
    let norm: QwenRMSNorm
    let inputProjection: Linear
    let outputProjection: Linear

    public init(config: DecoderConfig) {
        self.inputProjection = Linear(
            config.vectorQuantizationHiddenDimension,
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
        self.outputProjection = Linear(config.hiddenSize, config.latentDim, bias: false)

        super.init()
    }

    public func callAsFunction(_ x: MLXArray) -> MLXArray {
        var h = inputProjection(x) // [B, T, hiddenSize]
        let T = h.dim(1)
        let positions = MLXArray(0..<Int32(T)).expandedDimensions(axis: 0)

        for layer in layers {
            h = layer(h, positions: positions)
        }
        h = norm(h)
        return outputProjection(h) // [B, T, latentDim]
    }
}

// MARK: - Waveform Decoder

/// Final decoder: latent features → waveform via upsampling + ConvNeXt + Snake
public class WaveformDecoder: Module, @unchecked Sendable {
    let preConv: CausalConv1d
    let upsampleLayers: [(CausalTransposeConv1d, ConvNeXtBlock)]
    let postConv: CausalConv1d

    public init(config: DecoderConfig) {
        let latentDim = config.latentDim
        let decoderDim = config.decoderDim
        let upsampleRates = config.upsampleRates  // [8, 5, 4, 3]

        // Pre-conv: project from latent to decoder dim
        self.preConv = CausalConv1d(
            inChannels: latentDim,
            outChannels: decoderDim,
            kernelSize: 7
        )

        // Upsampling stages
        var layers: [(CausalTransposeConv1d, ConvNeXtBlock)] = []
        var currentDim = decoderDim
        for (i, rate) in upsampleRates.enumerated() {
            let outDim = currentDim / 2
            let upconv = CausalTransposeConv1d(
                inChannels: currentDim,
                outChannels: outDim,
                kernelSize: rate * 2,
                stride: rate
            )
            let convnext = ConvNeXtBlock(
                dim: outDim,
                intermediateDim: outDim * 4,
                layerScaleInit: config.layerScaleInitialScale
            )
            layers.append((upconv, convnext))
            currentDim = outDim
        }
        self.upsampleLayers = layers

        // Post-conv: to 1 channel (mono audio)
        self.postConv = CausalConv1d(
            inChannels: currentDim,
            outChannels: 1,
            kernelSize: 7
        )

        super.init()
    }

    public func callAsFunction(_ x: MLXArray) -> MLXArray {
        // x: [B, T, latentDim] → [B, latentDim, T]
        var h = x.transposed(0, 2, 1)
        h = preConv(h)

        for (upconv, convnext) in upsampleLayers {
            h = upconv(h)
            h = convnext(h)
        }

        h = postConv(h) // [B, 1, T_audio]
        return MLX.tanh(h).squeezed(axis: 1) // [B, T_audio]
    }
}

// MARK: - Full Codec Decoder

public class QwenCodecDecoder: Module, @unchecked Sendable {
    let config: SpeechTokenizerConfig
    let dequantizer: SplitRVQDequantizer
    let transformer: DecoderTransformer
    let waveformDecoder: WaveformDecoder

    public init(config: SpeechTokenizerConfig) {
        self.config = config
        self.dequantizer = SplitRVQDequantizer(config: config.decoderConfig)
        self.transformer = DecoderTransformer(config: config.decoderConfig)
        self.waveformDecoder = WaveformDecoder(config: config.decoderConfig)
        super.init()
    }

    /// Decode audio codes to waveform.
    /// - Parameter codes: [B, T, numCodeGroups] — integer audio codes
    /// - Returns: [B, T_audio] — float32 waveform samples at 24kHz
    public func decode(codes: MLXArray) -> MLXArray {
        // 1. Dequantize: codes → continuous features
        let features = dequantizer(codes) // [B, T, vqDim]

        // 2. Transformer refinement
        let refined = transformer(features) // [B, T, latentDim]

        // 3. Upsample to waveform
        let waveform = waveformDecoder(refined) // [B, T_audio]

        return waveform
    }
}

// MARK: - Helpers

private func gelu(_ x: MLXArray) -> MLXArray {
    x * 0.5 * (1.0 + MLX.erf(x / sqrtf(2.0)))
}
