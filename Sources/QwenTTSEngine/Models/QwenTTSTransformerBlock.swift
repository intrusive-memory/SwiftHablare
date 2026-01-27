// QwenTTSTransformerBlock.swift
// Qwen3-style transformer block: GQA + RoPE + SiLU MLP + RMSNorm
// Shared by both the talker and code predictor models.

import Foundation
import MLX
import MLXNN
import MLXFast

// MARK: - RMSNorm

public class QwenRMSNorm: Module, @unchecked Sendable {
    let weight: MLXArray
    let eps: Float

    public init(hiddenSize: Int, eps: Float = 1e-6) {
        self.weight = MLXArray.ones([hiddenSize])
        self.eps = eps
        super.init()
    }

    public func callAsFunction(_ x: MLXArray) -> MLXArray {
        MLXFast.rmsNorm(x, weight: weight, eps: eps)
    }
}

// MARK: - Rotary Embedding

public class QwenRotaryEmbedding: Module, @unchecked Sendable {
    let dims: Int
    let theta: Float

    public init(dims: Int, theta: Float = 1_000_000) {
        self.dims = dims
        self.theta = theta
        super.init()
    }

    public func callAsFunction(positions: MLXArray) -> MLXArray {
        let halfDim = dims / 2
        let freqs = MLX.exp(
            -MLXArray(stride(from: 0, to: halfDim, by: 1)).asType(.float32)
            * (Foundation.log(theta) / Float(halfDim))
        )
        // positions: [B, T] or [T] → angles: [..., halfDim]
        let angles = positions.expandedDimensions(axis: -1) * freqs
        let cosVal = MLX.cos(angles)
        let sinVal = MLX.sin(angles)
        return MLX.stacked([cosVal, sinVal], axis: -1).reshaped(
            positions.shape + [dims]
        )
    }
}

// MARK: - MLP (SiLU gate)

public class QwenMLP: Module, @unchecked Sendable {
    let gate_proj: Linear
    let up_proj: Linear
    let down_proj: Linear

    public init(hiddenSize: Int, intermediateSize: Int) {
        self.gate_proj = Linear(hiddenSize, intermediateSize, bias: false)
        self.up_proj = Linear(hiddenSize, intermediateSize, bias: false)
        self.down_proj = Linear(intermediateSize, hiddenSize, bias: false)
        super.init()
    }

    public func callAsFunction(_ x: MLXArray) -> MLXArray {
        down_proj(silu(gate_proj(x)) * up_proj(x))
    }
}

// MARK: - Grouped Query Attention

public class QwenAttention: Module, @unchecked Sendable {
    let numHeads: Int
    let numKVHeads: Int
    let headDim: Int
    let scale: Float

    let q_proj: Linear
    let k_proj: Linear
    let v_proj: Linear
    let o_proj: Linear
    let rope: QwenRotaryEmbedding

    public init(
        hiddenSize: Int,
        numHeads: Int,
        numKVHeads: Int,
        headDim: Int,
        ropeTheta: Float = 1_000_000,
        bias: Bool = false
    ) {
        self.numHeads = numHeads
        self.numKVHeads = numKVHeads
        self.headDim = headDim
        self.scale = 1.0 / sqrtf(Float(headDim))

        self.q_proj = Linear(hiddenSize, numHeads * headDim, bias: bias)
        self.k_proj = Linear(hiddenSize, numKVHeads * headDim, bias: bias)
        self.v_proj = Linear(hiddenSize, numKVHeads * headDim, bias: bias)
        self.o_proj = Linear(numHeads * headDim, hiddenSize, bias: bias)
        self.rope = QwenRotaryEmbedding(dims: headDim, theta: ropeTheta)

        super.init()
    }

    public func callAsFunction(
        _ x: MLXArray,
        positions: MLXArray,
        mask: MLXArray? = nil,
        cache: KVCache? = nil
    ) -> MLXArray {
        let B = x.dim(0)
        let L = x.dim(1)

        var queries = q_proj(x).reshaped(B, L, numHeads, headDim).transposed(0, 2, 1, 3)
        var keys = k_proj(x).reshaped(B, L, numKVHeads, headDim).transposed(0, 2, 1, 3)
        let values = v_proj(x).reshaped(B, L, numKVHeads, headDim).transposed(0, 2, 1, 3)

        // Apply RoPE
        let ropeOut = rope(positions: positions)
        let cos = ropeOut[.ellipsis, .stride(from: 0, to: nil, by: 2)]
        let sin = ropeOut[.ellipsis, .stride(from: 1, to: nil, by: 2)]

        queries = applyRotaryEmb(queries, cos: cos, sin: sin)
        keys = applyRotaryEmb(keys, cos: cos, sin: sin)

        // KV cache
        var k = keys
        var v = values
        if let cache = cache {
            (k, v) = cache.update(keys: k, values: v)
        }

        // GQA: expand KV heads
        let repeats = numHeads / numKVHeads
        if repeats > 1 {
            k = expandKVHeads(k, repeats: repeats)
            v = expandKVHeads(v, repeats: repeats)
        }

        // Scaled dot-product attention
        let output = MLXFast.scaledDotProductAttention(
            queries: queries,
            keys: k,
            values: v,
            scale: scale,
            mask: mask
        )

        let merged = output.transposed(0, 2, 1, 3).reshaped(B, L, numHeads * headDim)
        return o_proj(merged)
    }

    private func applyRotaryEmb(_ x: MLXArray, cos: MLXArray, sin: MLXArray) -> MLXArray {
        let halfDim = headDim / 2
        let x1 = x[.ellipsis, 0..<halfDim]
        let x2 = x[.ellipsis, halfDim...]
        let cosB = cos.expandedDimensions(axis: 1)
        let sinB = sin.expandedDimensions(axis: 1)
        let rotated = MLX.concatenated([
            x1 * cosB - x2 * sinB,
            x2 * cosB + x1 * sinB
        ], axis: -1)
        return rotated
    }

    private func expandKVHeads(_ x: MLXArray, repeats: Int) -> MLXArray {
        // x: [B, numKVHeads, T, headDim] → [B, numHeads, T, headDim]
        let B = x.dim(0)
        let T = x.dim(2)
        let expanded = x.expandedDimensions(axis: 2) // [B, numKVHeads, 1, T, headDim]
        let tiled = tiled(expanded, repetitions: [1, 1, repeats, 1, 1])
        return tiled.reshaped(B, numHeads, T, headDim)
    }
}

// MARK: - Transformer Block

public class QwenTransformerBlock: Module, @unchecked Sendable {
    let selfAttn: QwenAttention
    let mlp: QwenMLP
    let inputLayernorm: QwenRMSNorm
    let postAttentionLayernorm: QwenRMSNorm

    public init(
        hiddenSize: Int,
        numHeads: Int,
        numKVHeads: Int,
        headDim: Int,
        intermediateSize: Int,
        rmsNormEps: Float,
        ropeTheta: Float,
        bias: Bool = false
    ) {
        self.selfAttn = QwenAttention(
            hiddenSize: hiddenSize,
            numHeads: numHeads,
            numKVHeads: numKVHeads,
            headDim: headDim,
            ropeTheta: ropeTheta,
            bias: bias
        )
        self.mlp = QwenMLP(hiddenSize: hiddenSize, intermediateSize: intermediateSize)
        self.inputLayernorm = QwenRMSNorm(hiddenSize: hiddenSize, eps: rmsNormEps)
        self.postAttentionLayernorm = QwenRMSNorm(hiddenSize: hiddenSize, eps: rmsNormEps)
        super.init()
    }

    public func callAsFunction(
        _ x: MLXArray,
        positions: MLXArray,
        mask: MLXArray? = nil,
        cache: KVCache? = nil
    ) -> MLXArray {
        // Pre-norm attention
        let residual = x
        let normed = inputLayernorm(x)
        let attnOut = selfAttn(normed, positions: positions, mask: mask, cache: cache)
        let h = residual + attnOut

        // Pre-norm MLP
        let residual2 = h
        let normed2 = postAttentionLayernorm(h)
        let mlpOut = mlp(normed2)
        return residual2 + mlpOut
    }
}

// MARK: - KV Cache

public class KVCache: @unchecked Sendable {
    var keys: MLXArray?
    var values: MLXArray?

    public init() {}

    public func update(keys newKeys: MLXArray, values newValues: MLXArray) -> (MLXArray, MLXArray) {
        if let existingKeys = keys, let existingValues = values {
            let k = MLX.concatenated([existingKeys, newKeys], axis: 2)
            let v = MLX.concatenated([existingValues, newValues], axis: 2)
            self.keys = k
            self.values = v
            return (k, v)
        } else {
            self.keys = newKeys
            self.values = newValues
            return (newKeys, newValues)
        }
    }

    public var sequenceLength: Int {
        keys?.dim(2) ?? 0
    }

    public func reset() {
        keys = nil
        values = nil
    }
}

// MARK: - Helpers

private func silu(_ x: MLXArray) -> MLXArray {
    x * MLX.sigmoid(x)
}
