// VoiceCatalogTests.swift

import Testing
import Foundation
@testable import QwenTTSEngine

@Suite("VoiceCatalog Tests")
struct VoiceCatalogTests {

    /// Helper to make a TalkerConfig for testing
    private func makeTalkerConfig(
        spkId: [String: Int] = [:],
        codecLanguageId: [String: Int] = ["english": 2050, "chinese": 2055, "spanish": 2054]
    ) throws -> TalkerConfig {
        // Build JSON and decode to get a valid TalkerConfig
        let spkIdJSON = try String(data: JSONEncoder().encode(spkId), encoding: .utf8)!
        let langJSON = try String(data: JSONEncoder().encode(codecLanguageId), encoding: .utf8)!

        let json = """
        {
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
          "codec_language_id": \(langJSON),
          "spk_id": \(spkIdJSON),
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
        """
        return try JSONDecoder().decode(TalkerConfig.self, from: Data(json.utf8))
    }

    @Test("Empty speaker list produces empty voice catalog")
    func emptyVoices() throws {
        let config = try makeTalkerConfig()
        let catalog = VoiceCatalog(from: config)

        #expect(catalog.voices.isEmpty)
    }

    @Test("Voices from spk_id")
    func voicesFromSpkId() throws {
        let config = try makeTalkerConfig(spkId: [
            "Aiden": 0,
            "Bella": 1,
            "Carlos": 2,
        ])
        let catalog = VoiceCatalog(from: config)

        #expect(catalog.voices.count == 3)
        // Sorted alphabetically
        #expect(catalog.voices[0].name == "Aiden")
        #expect(catalog.voices[1].name == "Bella")
        #expect(catalog.voices[2].name == "Carlos")
    }

    @Test("Voice lookup by name is case-insensitive")
    func voiceLookupCaseInsensitive() throws {
        let config = try makeTalkerConfig(spkId: ["Aiden": 0])
        let catalog = VoiceCatalog(from: config)

        #expect(catalog.voice(named: "Aiden") != nil)
        #expect(catalog.voice(named: "aiden") != nil)
        #expect(catalog.voice(named: "AIDEN") != nil)
        #expect(catalog.voice(named: "nonexistent") == nil)
    }

    @Test("Voice lookup by ID")
    func voiceLookupById() throws {
        let config = try makeTalkerConfig(spkId: ["Aiden Voice": 0])
        let catalog = VoiceCatalog(from: config)

        // ID is lowercased with spaces replaced by hyphens
        let voice = catalog.voice(named: "aiden-voice")
        #expect(voice != nil)
        #expect(voice?.id == "aiden-voice")
        #expect(voice?.name == "Aiden Voice")
        #expect(voice?.speakerId == 0)
    }

    @Test("Language ID lookup")
    func languageIdLookup() throws {
        let config = try makeTalkerConfig()
        let catalog = VoiceCatalog(from: config)

        #expect(catalog.languageId(for: "english") == 2050)
        #expect(catalog.languageId(for: "chinese") == 2055)
        #expect(catalog.languageId(for: "spanish") == 2054)
        #expect(catalog.languageId(for: "klingon") == nil)
    }

    @Test("Default language ID is English")
    func defaultLanguageId() throws {
        let config = try makeTalkerConfig()
        let catalog = VoiceCatalog(from: config)

        #expect(catalog.defaultLanguageId == 2050)
    }

    @Test("Supported languages list")
    func supportedLanguages() throws {
        let config = try makeTalkerConfig()
        let catalog = VoiceCatalog(from: config)

        #expect(catalog.supportedLanguages.count == 3)
        #expect(catalog.supportedLanguages.keys.contains("english"))
        #expect(catalog.supportedLanguages.keys.contains("chinese"))
        #expect(catalog.supportedLanguages.keys.contains("spanish"))
    }

    @Test("QwenTTSVoice is Codable")
    func voiceCodable() throws {
        let voice = QwenTTSVoice(id: "test", name: "Test", speakerId: 42, language: "english")
        let data = try JSONEncoder().encode(voice)
        let decoded = try JSONDecoder().decode(QwenTTSVoice.self, from: data)

        #expect(decoded.id == "test")
        #expect(decoded.name == "Test")
        #expect(decoded.speakerId == 42)
        #expect(decoded.language == "english")
    }
}
