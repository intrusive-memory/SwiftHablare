// QwenTTSConfigTests.swift

import Testing
import Foundation
@testable import QwenTTSEngine

@Suite("QwenTTSConfig Tests")
struct QwenTTSConfigTests {

    static let sampleConfigJSON = """
    {
      "architectures": ["Qwen3TTSForConditionalGeneration"],
      "assistant_token_id": 77091,
      "im_end_token_id": 151645,
      "im_start_token_id": 151644,
      "tts_bos_token_id": 151672,
      "tts_eos_token_id": 151673,
      "tts_pad_token_id": 151671,
      "model_type": "qwen3_tts",
      "tts_model_type": "base",
      "talker_config": {
        "attention_bias": false,
        "head_dim": 128,
        "hidden_act": "silu",
        "hidden_size": 2048,
        "intermediate_size": 6144,
        "max_position_embeddings": 32768,
        "num_attention_heads": 16,
        "num_code_groups": 16,
        "num_hidden_layers": 28,
        "num_key_value_heads": 8,
        "position_id_per_seconds": 13,
        "rms_norm_eps": 1e-06,
        "rope_theta": 1000000,
        "text_hidden_size": 2048,
        "text_vocab_size": 151936,
        "vocab_size": 3072,
        "codec_bos_id": 2149,
        "codec_eos_token_id": 2150,
        "codec_think_id": 2154,
        "codec_nothink_id": 2155,
        "codec_pad_id": 2148,
        "codec_think_bos_id": 2156,
        "codec_think_eos_id": 2157,
        "codec_language_id": {
          "chinese": 2055,
          "english": 2050,
          "spanish": 2054
        },
        "spk_id": {},
        "code_predictor_config": {
          "attention_bias": false,
          "head_dim": 128,
          "hidden_act": "silu",
          "hidden_size": 1024,
          "intermediate_size": 3072,
          "max_length": 20,
          "max_position_embeddings": 65536,
          "num_attention_heads": 16,
          "num_code_groups": 16,
          "num_hidden_layers": 5,
          "num_key_value_heads": 8,
          "rms_norm_eps": 1e-06,
          "rope_theta": 1000000,
          "vocab_size": 2048
        }
      }
    }
    """

    @Test("Decode top-level config")
    func decodeTopLevelConfig() throws {
        let data = Data(Self.sampleConfigJSON.utf8)
        let config = try JSONDecoder().decode(QwenTTSModelConfig.self, from: data)

        #expect(config.architectures == ["Qwen3TTSForConditionalGeneration"])
        #expect(config.ttsBosTokenId == 151672)
        #expect(config.ttsEosTokenId == 151673)
        #expect(config.modelType == "qwen3_tts")
        #expect(config.ttsModelType == "base")
    }

    @Test("Decode talker config fields")
    func decodeTalkerConfig() throws {
        let data = Data(Self.sampleConfigJSON.utf8)
        let config = try JSONDecoder().decode(QwenTTSModelConfig.self, from: data)
        let talker = config.talkerConfig

        #expect(talker.hiddenSize == 2048)
        #expect(talker.numAttentionHeads == 16)
        #expect(talker.numKeyValueHeads == 8)
        #expect(talker.numCodeGroups == 16)
        #expect(talker.numHiddenLayers == 28)
        #expect(talker.headDim == 128)
        #expect(talker.intermediateSize == 6144)
        #expect(talker.vocabSize == 3072)
        #expect(talker.textVocabSize == 151936)
        #expect(talker.attentionBias == false)
    }

    @Test("Decode codec token IDs")
    func decodeCodecTokenIds() throws {
        let data = Data(Self.sampleConfigJSON.utf8)
        let config = try JSONDecoder().decode(QwenTTSModelConfig.self, from: data)
        let talker = config.talkerConfig

        #expect(talker.codecBosId == 2149)
        #expect(talker.codecEosTokenId == 2150)
        #expect(talker.codecPadId == 2148)
        #expect(talker.codecThinkId == 2154)
        #expect(talker.codecNothinkId == 2155)
        #expect(talker.codecThinkBosId == 2156)
        #expect(talker.codecThinkEosId == 2157)
    }

    @Test("Decode language IDs")
    func decodeLanguageIds() throws {
        let data = Data(Self.sampleConfigJSON.utf8)
        let config = try JSONDecoder().decode(QwenTTSModelConfig.self, from: data)
        let langs = config.talkerConfig.codecLanguageId

        #expect(langs["english"] == 2050)
        #expect(langs["chinese"] == 2055)
        #expect(langs["spanish"] == 2054)
        #expect(langs.count == 3)
    }

    @Test("Decode code predictor config")
    func decodeCodePredictorConfig() throws {
        let data = Data(Self.sampleConfigJSON.utf8)
        let config = try JSONDecoder().decode(QwenTTSModelConfig.self, from: data)
        let predictor = config.talkerConfig.codePredictorConfig

        #expect(predictor.hiddenSize == 1024)
        #expect(predictor.numHiddenLayers == 5)
        #expect(predictor.vocabSize == 2048)
        #expect(predictor.maxLength == 20)
        #expect(predictor.numAttentionHeads == 16)
        #expect(predictor.numKeyValueHeads == 8)
    }

    @Test("Empty spk_id decodes correctly")
    func decodeEmptySpkId() throws {
        let data = Data(Self.sampleConfigJSON.utf8)
        let config = try JSONDecoder().decode(QwenTTSModelConfig.self, from: data)

        #expect(config.talkerConfig.spkId.isEmpty)
    }

    // MARK: - Speech Tokenizer Config

    static let codecConfigJSON = """
    {
      "architectures": ["Qwen3TTSTokenizerV2Model"],
      "model_type": "qwen3_tts_tokenizer_12hz",
      "encoder_valid_num_quantizers": 16,
      "input_sample_rate": 24000,
      "output_sample_rate": 24000,
      "decode_upsample_rate": 1920,
      "decoder_config": {
        "attention_bias": false,
        "latent_dim": 1024,
        "codebook_dim": 512,
        "codebook_size": 2048,
        "decoder_dim": 1536,
        "hidden_act": "silu",
        "hidden_size": 512,
        "intermediate_size": 1024,
        "layer_scale_initial_scale": 0.01,
        "max_position_embeddings": 8000,
        "head_dim": 64,
        "num_attention_heads": 16,
        "num_hidden_layers": 8,
        "num_key_value_heads": 16,
        "num_quantizers": 16,
        "num_semantic_quantizers": 1,
        "rms_norm_eps": 1e-05,
        "rope_theta": 10000,
        "semantic_codebook_size": 4096,
        "sliding_window": 72,
        "upsample_rates": [8, 5, 4, 3],
        "upsampling_ratios": [2, 2],
        "vector_quantization_hidden_dimension": 512
      }
    }
    """

    @Test("Decode speech tokenizer config")
    func decodeSpeechTokenizerConfig() throws {
        let data = Data(Self.codecConfigJSON.utf8)
        let config = try JSONDecoder().decode(SpeechTokenizerConfig.self, from: data)

        #expect(config.inputSampleRate == 24000)
        #expect(config.outputSampleRate == 24000)
        #expect(config.decodeUpsampleRate == 1920)
        #expect(config.modelType == "qwen3_tts_tokenizer_12hz")
    }

    @Test("Decode decoder config fields")
    func decodeDecoderConfig() throws {
        let data = Data(Self.codecConfigJSON.utf8)
        let config = try JSONDecoder().decode(SpeechTokenizerConfig.self, from: data)
        let decoder = config.decoderConfig

        #expect(decoder.latentDim == 1024)
        #expect(decoder.codebookDim == 512)
        #expect(decoder.codebookSize == 2048)
        #expect(decoder.decoderDim == 1536)
        #expect(decoder.numQuantizers == 16)
        #expect(decoder.numSemanticQuantizers == 1)
        #expect(decoder.semanticCodebookSize == 4096)
        #expect(decoder.upsampleRates == [8, 5, 4, 3])
        #expect(decoder.upsamplingRatios == [2, 2])
        #expect(decoder.numHiddenLayers == 8)
        #expect(decoder.numAttentionHeads == 16)
        #expect(decoder.headDim == 64)
    }
}
