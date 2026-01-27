// QwenTTSConfig.swift
// Codable config structs for Qwen3 TTS talker + codec decoder

import Foundation

// MARK: - Top-Level Config

public struct QwenTTSModelConfig: Codable, Sendable {
    public let architectures: [String]
    public let assistantTokenId: Int
    public let imEndTokenId: Int
    public let imStartTokenId: Int
    public let ttsBosTokenId: Int
    public let ttsEosTokenId: Int
    public let ttsPadTokenId: Int
    public let modelType: String
    public let ttsModelType: String
    public let talkerConfig: TalkerConfig

    enum CodingKeys: String, CodingKey {
        case architectures
        case assistantTokenId = "assistant_token_id"
        case imEndTokenId = "im_end_token_id"
        case imStartTokenId = "im_start_token_id"
        case ttsBosTokenId = "tts_bos_token_id"
        case ttsEosTokenId = "tts_eos_token_id"
        case ttsPadTokenId = "tts_pad_token_id"
        case modelType = "model_type"
        case ttsModelType = "tts_model_type"
        case talkerConfig = "talker_config"
    }
}

// MARK: - Talker Config

public struct TalkerConfig: Codable, Sendable {
    public let attentionBias: Bool
    public let headDim: Int
    public let hiddenAct: String
    public let hiddenSize: Int
    public let intermediateSize: Int
    public let maxPositionEmbeddings: Int
    public let numAttentionHeads: Int
    public let numCodeGroups: Int
    public let numHiddenLayers: Int
    public let numKeyValueHeads: Int
    public let positionIdPerSeconds: Int
    public let rmsNormEps: Float
    public let ropeTheta: Float
    public let textHiddenSize: Int
    public let textVocabSize: Int
    public let vocabSize: Int
    public let codecBosId: Int
    public let codecEosTokenId: Int
    public let codecThinkId: Int
    public let codecNothinkId: Int
    public let codecPadId: Int
    public let codecThinkBosId: Int
    public let codecThinkEosId: Int
    public let codecLanguageId: [String: Int]
    public let spkId: [String: Int]
    public let ropeScaling: RopeScaling?
    public let codePredictorConfig: CodePredictorConfig

    enum CodingKeys: String, CodingKey {
        case attentionBias = "attention_bias"
        case headDim = "head_dim"
        case hiddenAct = "hidden_act"
        case hiddenSize = "hidden_size"
        case intermediateSize = "intermediate_size"
        case maxPositionEmbeddings = "max_position_embeddings"
        case numAttentionHeads = "num_attention_heads"
        case numCodeGroups = "num_code_groups"
        case numHiddenLayers = "num_hidden_layers"
        case numKeyValueHeads = "num_key_value_heads"
        case positionIdPerSeconds = "position_id_per_seconds"
        case rmsNormEps = "rms_norm_eps"
        case ropeTheta = "rope_theta"
        case textHiddenSize = "text_hidden_size"
        case textVocabSize = "text_vocab_size"
        case vocabSize = "vocab_size"
        case codecBosId = "codec_bos_id"
        case codecEosTokenId = "codec_eos_token_id"
        case codecThinkId = "codec_think_id"
        case codecNothinkId = "codec_nothink_id"
        case codecPadId = "codec_pad_id"
        case codecThinkBosId = "codec_think_bos_id"
        case codecThinkEosId = "codec_think_eos_id"
        case codecLanguageId = "codec_language_id"
        case spkId = "spk_id"
        case ropeScaling = "rope_scaling"
        case codePredictorConfig = "code_predictor_config"
    }
}

// MARK: - RoPE Scaling

public struct RopeScaling: Codable, Sendable {
    public let interleaved: Bool?
    public let mropeSection: [Int]?
    public let ropeType: String?

    enum CodingKeys: String, CodingKey {
        case interleaved
        case mropeSection = "mrope_section"
        case ropeType = "rope_type"
    }
}

// MARK: - Code Predictor Config

public struct CodePredictorConfig: Codable, Sendable {
    public let attentionBias: Bool
    public let headDim: Int
    public let hiddenAct: String
    public let hiddenSize: Int
    public let intermediateSize: Int
    public let maxLength: Int
    public let maxPositionEmbeddings: Int
    public let numAttentionHeads: Int
    public let numCodeGroups: Int
    public let numHiddenLayers: Int
    public let numKeyValueHeads: Int
    public let rmsNormEps: Float
    public let ropeTheta: Float
    public let vocabSize: Int

    enum CodingKeys: String, CodingKey {
        case attentionBias = "attention_bias"
        case headDim = "head_dim"
        case hiddenAct = "hidden_act"
        case hiddenSize = "hidden_size"
        case intermediateSize = "intermediate_size"
        case maxLength = "max_length"
        case maxPositionEmbeddings = "max_position_embeddings"
        case numAttentionHeads = "num_attention_heads"
        case numCodeGroups = "num_code_groups"
        case numHiddenLayers = "num_hidden_layers"
        case numKeyValueHeads = "num_key_value_heads"
        case rmsNormEps = "rms_norm_eps"
        case ropeTheta = "rope_theta"
        case vocabSize = "vocab_size"
    }
}

// MARK: - Speech Tokenizer (Codec Decoder) Config

public struct SpeechTokenizerConfig: Codable, Sendable {
    public let architectures: [String]
    public let modelType: String
    public let encoderValidNumQuantizers: Int
    public let inputSampleRate: Int
    public let outputSampleRate: Int
    public let decodeUpsampleRate: Int
    public let decoderConfig: DecoderConfig

    enum CodingKeys: String, CodingKey {
        case architectures
        case modelType = "model_type"
        case encoderValidNumQuantizers = "encoder_valid_num_quantizers"
        case inputSampleRate = "input_sample_rate"
        case outputSampleRate = "output_sample_rate"
        case decodeUpsampleRate = "decode_upsample_rate"
        case decoderConfig = "decoder_config"
    }
}

public struct DecoderConfig: Codable, Sendable {
    public let attentionBias: Bool
    public let latentDim: Int
    public let codebookDim: Int
    public let codebookSize: Int
    public let decoderDim: Int
    public let hiddenAct: String
    public let hiddenSize: Int
    public let intermediateSize: Int
    public let layerScaleInitialScale: Float
    public let maxPositionEmbeddings: Int
    public let headDim: Int
    public let numAttentionHeads: Int
    public let numHiddenLayers: Int
    public let numKeyValueHeads: Int
    public let numQuantizers: Int
    public let numSemanticQuantizers: Int
    public let rmsNormEps: Float
    public let ropeTheta: Float
    public let semanticCodebookSize: Int
    public let slidingWindow: Int?
    public let upsampleRates: [Int]
    public let upsamplingRatios: [Int]
    public let vectorQuantizationHiddenDimension: Int

    enum CodingKeys: String, CodingKey {
        case attentionBias = "attention_bias"
        case latentDim = "latent_dim"
        case codebookDim = "codebook_dim"
        case codebookSize = "codebook_size"
        case decoderDim = "decoder_dim"
        case hiddenAct = "hidden_act"
        case hiddenSize = "hidden_size"
        case intermediateSize = "intermediate_size"
        case layerScaleInitialScale = "layer_scale_initial_scale"
        case maxPositionEmbeddings = "max_position_embeddings"
        case headDim = "head_dim"
        case numAttentionHeads = "num_attention_heads"
        case numHiddenLayers = "num_hidden_layers"
        case numKeyValueHeads = "num_key_value_heads"
        case numQuantizers = "num_quantizers"
        case numSemanticQuantizers = "num_semantic_quantizers"
        case rmsNormEps = "rms_norm_eps"
        case ropeTheta = "rope_theta"
        case semanticCodebookSize = "semantic_codebook_size"
        case slidingWindow = "sliding_window"
        case upsampleRates = "upsample_rates"
        case upsamplingRatios = "upsampling_ratios"
        case vectorQuantizationHiddenDimension = "vector_quantization_hidden_dimension"
    }
}
