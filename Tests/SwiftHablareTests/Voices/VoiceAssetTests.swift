import Foundation
import SwiftFijos
import Testing

@testable import SwiftHablare

@Suite("VoiceAsset over VoxFormat")
struct VoiceAssetTests {
  static let googleSamplePath = "embeddings/google/gemini-3.8-flash-tts/sample-audio.wav"

  /// Resolves `Fixtures/voices/<name>` at the repo root. `Tests/SwiftHablareTests/Fixtures` also
  /// exists and is nearer to this file, so start the Fijos search from the repo root instead.
  static func fixture(_ name: String, file: String = #filePath) throws -> URL {
    let root = URL(fileURLWithPath: file).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    return try Fijos.getFixture(
      "voices/\(name)", from: root.appendingPathComponent("Package.swift").path)
  }

  /// Copies a repo fixture into a fresh temp directory so no test writes into Fixtures/.
  private func tempCopy(of fixture: String) throws -> (url: URL, directory: URL) {
    let source = try Self.fixture(fixture)
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("VoiceAssetTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let copy = directory.appendingPathComponent(fixture)
    try FileManager.default.copyItem(at: source, to: copy)
    return (copy, directory)
  }

  private func isInvalidRequest(_ body: () throws -> Void) -> Bool {
    do {
      try body()
      return false
    } catch HablareError.invalidRequest {
      return true
    } catch {
      return false
    }
  }

  @Test("CLARK has Google reference audio and a Google server handle")
  func clarkSources() throws {
    let asset = try VoiceAsset(contentsOf: Self.fixture("CLARK.vox"))
    let google = asset.sources.filter { $0.engine == "google" }
    #expect(google.contains { $0.kind == .referenceAudio && $0.path == Self.googleSamplePath })
    #expect(google.contains { $0.kind == .serverHandle && $0.model == "gemini-3.8-flash-tts" })
    #expect(asset.sources.contains { $0.engine == "qwen3-tts" && $0.kind == .embedding })
    // Clone prompts are embeddings; sample audio is reference audio.
    #expect(
      asset.sources.contains {
        $0.engine == "qwen3-tts" && $0.kind == .referenceAudio && $0.model == "1.7b"
      })
  }

  @Test("TOBY falls back to Qwen3 sources and has no Google source")
  func tobySources() throws {
    let asset = try VoiceAsset(contentsOf: Self.fixture("TOBY.vox"))
    #expect(!asset.sources.isEmpty)
    #expect(asset.sources.allSatisfy { $0.engine == "qwen3-tts" })
    #expect(!asset.sources.contains { $0.engine == "google" })
    #expect(Set(asset.sources.compactMap(\.model)) == ["0.6b", "1.7b"])
  }

  @Test("Writing a Google sample and extension into a TOBY copy round-trips")
  func writeGoogleIntoToby() throws {
    let (url, directory) = try tempCopy(of: "TOBY.vox")
    defer { try? FileManager.default.removeItem(at: directory) }

    var asset = try VoiceAsset(contentsOf: url)
    let wav = Data("RIFF-test-sample".utf8)
    let path = try asset.addSampleAudio(wav, engine: "google", model: "gemini-3.8-flash-tts")
    try asset.setExtension(
      [
        "voice_id": "voice_test123", "model_id": "gemini-3.8-flash-tts", "type": "prompted",
        "expire_time": "2999-01-01T00:00:00Z",
      ], forEngine: "google")
    try asset.write(to: url)

    #expect(path == Self.googleSamplePath)
    let reopened = try VoiceAsset(contentsOf: url)
    #expect(reopened.entryPaths.contains(Self.googleSamplePath))
    #expect(reopened.entryData(at: Self.googleSamplePath) == wav)
    #expect(
      reopened.extensionFields(forEngine: "google")?["voice_id"] as? String == "voice_test123")
    let google = reopened.sources.filter { $0.engine == "google" }
    #expect(google.contains { $0.kind == .referenceAudio && $0.path == Self.googleSamplePath })
    #expect(google.contains { $0.kind == .serverHandle })
    // Qwen3 data survived the rewrite.
    #expect(reopened.sources.contains { $0.engine == "qwen3-tts" && $0.kind == .embedding })
  }

  @Test("Writing into another engine's namespace throws invalidRequest")
  func foreignNamespaceThrows() throws {
    var asset = VoiceAsset(name: "Scratch", description: "A scratch voice for namespace tests.")
    let data = Data([1, 2, 3])
    let meta: [String: Any] = ["model": "m"]
    #expect(
      isInvalidRequest {
        try asset.addEntry(
          data, at: "embeddings/qwen3-tts/1.7b/clone-prompt.bin", forEngine: "google",
          metadata: meta)
      })
    #expect(
      isInvalidRequest {
        try asset.addEntry(
          data, at: "embeddings/google/../qwen3-tts/x/y.bin", forEngine: "google", metadata: meta)
      })
    #expect(
      isInvalidRequest {
        try asset.addEntry(data, at: "reference/a.wav", forEngine: "google", metadata: meta)
      })
    #expect(
      isInvalidRequest {
        try asset.addEntry(data, at: "manifest.json", forEngine: "google", metadata: meta)
      })
    #expect(
      isInvalidRequest {
        try asset.removeEntry(at: "embeddings/qwen3-tts/1.7b/clone-prompt.bin", forEngine: "google")
      })
    #expect(isInvalidRequest { try asset.setExtension([:], forEngine: "../google") })
    #expect(asset.entryPaths.isEmpty)
    #expect(asset.sources.isEmpty)
  }

  @Test("An expired Google voice id is stale; its sample stays current")
  func expiryStaleness() throws {
    var asset = VoiceAsset(name: "Scratch", description: "A scratch voice for expiry tests.")
    try asset.addSampleAudio(Data([0]), engine: "google", model: "gemini-3.8-flash-tts")
    try asset.setExtension(
      [
        "voice_id": "voice_old", "model_id": "gemini-3.8-flash-tts",
        "expire_time": "2020-01-01T00:00:00.123456789Z",
      ], forEngine: "google")

    let google = asset.sources.filter { $0.engine == "google" }
    let handle = try #require(google.first { $0.kind == .serverHandle })
    let sample = try #require(google.first { $0.kind == .referenceAudio })
    guard case .stale = handle.freshness else {
      Issue.record("expected stale, got \(handle.freshness)")
      return
    }
    #expect(sample.freshness == .current)

    // Judged before the expiry the same handle is merely expiring.
    let earlier = try #require(VoiceAsset.parseTimestamp("2019-06-01T00:00:00Z"))
    let before = try #require(asset.sources(asOf: earlier).first { $0.kind == .serverHandle })
    #expect(
      before.freshness
        == .expiresAt(try #require(VoiceAsset.parseTimestamp("2020-01-01T00:00:00.123Z"))))
  }

  @Test("CLARK's real expire_time parses (nanosecond fractions)")
  func clarkExpiryParses() throws {
    let asset = try VoiceAsset(contentsOf: Self.fixture("CLARK.vox"))
    let handle = try #require(
      asset.sources.first { $0.engine == "google" && $0.kind == .serverHandle })
    switch handle.freshness {
    case .expiresAt, .stale: break
    case .current: Issue.record("expire_time was not parsed")
    }
  }

  @Test("embeddingPath matches vox-python embedding_path")
  func pathBuilder() throws {
    #expect(
      try VoiceAsset.embeddingPath(
        engine: "google", modelSlug: "gemini-3.8-flash-tts", name: "sample-audio.wav")
        == Self.googleSamplePath)
    #expect(
      try VoiceAsset.embeddingPath(
        engine: "qwen3-tts", modelSlug: "0.6b", name: "clone-prompt.bin", language: "es")
        == "embeddings/qwen3-tts/0.6b/es/clone-prompt.bin")
    #expect(try VoiceAsset.modelSlug(for: "Qwen/Qwen3-TTS-12Hz-0.6B") == "qwen3-tts-12hz-0.6b")
    #expect(try VoiceAsset.modelSlug(for: "gemini-3.8-flash-tts") == "gemini-3.8-flash-tts")
    #expect(
      isInvalidRequest {
        _ = try VoiceAsset.embeddingPath(engine: "g/x", modelSlug: "m", name: "a.bin")
      })
    #expect(
      isInvalidRequest {
        _ = try VoiceAsset.embeddingPath(engine: "g", modelSlug: "..", name: "a.bin")
      })
    #expect(
      isInvalidRequest {
        _ = try VoiceAsset.embeddingPath(
          engine: "g", modelSlug: "m", name: "a.bin", language: "default")
      })
    #expect(
      isInvalidRequest {
        _ = try VoiceAsset.embeddingPath(
          engine: "g", modelSlug: "m", name: "a.bin", language: "not a tag")
      })
  }
}
