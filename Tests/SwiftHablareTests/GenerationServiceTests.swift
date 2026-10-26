//
//  GenerationServiceTests.swift
//  SwiftHablareTests
//
//  GenerationService over PluginRegistry + VoiceSynthesizer, driven by the fakes: chunking,
//  take validation, normalisation, progress, cancellation, voice listing and persistence.
//

import Foundation
import SwiftCompartido
import SwiftData
import Testing

@testable import SwiftHablare
@testable import SwiftHablareTesting

// MARK: - Test plugins

/// A local plugin that lists voices and synthesizes with no character limit.
final class ListingFakePlugin: HablarePlugin, VoiceListing, @unchecked Sendable {
  static let id = "listing-fake"
  static let displayName = "Listing Fake"
  static let kind = PluginKind.local

  let fake = FakeVoiceSynthesizer(limits: .unlimited)

  init(context: PluginContext) async throws {}

  var synthesizer: (any VoiceSynthesizer)? { fake }

  func status() async -> PluginStatus { .ready }

  func voices(languageCode: String) async throws -> [Voice] {
    [
      Voice(id: "v1", name: "One", description: nil, providerId: Self.id, language: languageCode),
      Voice(id: "v2", name: "Two", description: nil, providerId: Self.id, language: languageCode),
    ]
  }
}

/// A plugin whose listing always fails.
final class FailingListingPlugin: HablarePlugin, VoiceListing, @unchecked Sendable {
  static let id = "failing-listing"
  static let displayName = "Failing Listing"
  static let kind = PluginKind.cloud

  init(context: PluginContext) async throws {}

  var synthesizer: (any VoiceSynthesizer)? { FakeVoiceSynthesizer() }

  func status() async -> PluginStatus { .ready }

  func voices(languageCode: String) async throws -> [Voice] {
    throw HablareError.transient(underlying: URLError(.notConnectedToInternet))
  }
}

/// Collects values from `@Sendable` callbacks.
private final class Recorder<Value>: @unchecked Sendable {
  private let box = FakeLocked<[Value]>([])
  func append(_ value: Value) { box.withValue { $0.append(value) } }
  var values: [Value] { box.current }
}

extension Result {
  fileprivate var failure: Failure? {
    if case .failure(let error) = self { return error }
    return nil
  }
}

// MARK: - Suite

@Suite("GenerationService Tests")
@MainActor
struct GenerationServiceTests {

  // MARK: Helpers

  /// A sentence of exactly 30 characters; a 280-character chunk holds 9 of them.
  private static let sentence = "Sentence of thirty characters."

  private static let text600: String = {
    let long = Array(repeating: sentence, count: 21).joined(separator: " ")
    return String(long.prefix(600))
  }()

  private func makeRegistry(_ plugins: [any HablarePlugin.Type]) -> PluginRegistry {
    let suite = "swifthablare.tests.generation.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return PluginRegistry(
      userDefaults: defaults, environment: [:], fallbackKeys: [], plugins: plugins)
  }

  /// A service over a fresh fake registry, and the fake synthesizer it will use.
  private func makeService(
    targetFormat: AudioFormat = .pcm24kMono16,
    takePolicy: TakePolicy = .default
  ) async throws -> (GenerationService, FakeVoiceSynthesizer, PluginRegistry) {
    let registry = TestFixtures.makeFakeRegistry()
    let plugin = try #require(
      try await registry.plugin(id: FakeSynthesizerPlugin.id) as? FakeSynthesizerPlugin)
    let service = GenerationService(
      registry: registry, targetFormat: targetFormat, takePolicy: takePolicy)
    return (service, plugin.fakeSynthesizer, registry)
  }

  private func request(_ text: String, seed: UInt64? = nil) -> SpeechRequest {
    SpeechRequest(text: text, voice: TestFixtures.fakeVoice, languageCode: "en", seed: seed)
  }

  private func hablareError(_ body: () async throws -> Void) async -> HablareError? {
    do {
      try await body()
      return nil
    } catch let error as HablareError {
      return error
    } catch {
      Issue.record("Expected a HablareError, got \(error)")
      return nil
    }
  }

  private func isInvalidRequest(_ error: HablareError?) -> Bool {
    if case .invalidRequest? = error { return true }
    return false
  }

  private func isCancelled(_ error: (any Error)?) -> Bool {
    if case .cancelled? = error as? HablareError { return true }
    return false
  }

  private func messages(_ texts: [String]) -> [any SpeakableItem] {
    texts.map { SimpleMessage(content: $0, voice: TestFixtures.fakeVoice) }
  }

  // MARK: - Initialization

  @Test("Default service targets pcm24kMono16 with the default policy")
  func testDefaultConfiguration() {
    let service = GenerationService()
    #expect(service.targetFormat == .pcm24kMono16)
    #expect(service.takePolicy == .default)
    #expect(service.fallbackMaxCharacters == TextChunker.defaultMaxCharacters)
    #expect(service.registry === PluginRegistry.default)
  }

  @Test("Initializer stores its configuration")
  func testCustomConfiguration() {
    let registry = TestFixtures.makeFakeRegistry()
    let wav = AudioFormat(container: .wav, sampleRate: 16_000, channels: 1, bitDepth: 16)
    let policy = TakePolicy(maxRetries: 5)
    let service = GenerationService(
      registry: registry, targetFormat: wav, takePolicy: policy, fallbackMaxCharacters: 99)
    #expect(service.registry === registry)
    #expect(service.targetFormat == wav)
    #expect(service.takePolicy == policy)
    #expect(service.fallbackMaxCharacters == 99)
  }

  // MARK: - Chunking and format

  @Test("A 600-character item is synthesized in 3+ chunks and returned as pcm24kMono16")
  func testLongItemIsChunked() async throws {
    let (service, fake, _) = try await makeService()
    #expect(Self.text600.count == 600)

    let outcome = try await service.generateValidated(request(Self.text600))

    #expect(fake.synthesizeCallCount >= 3)
    #expect(outcome.chunkCount >= 3)
    #expect(outcome.chunkCount == fake.synthesizeCallCount)
    #expect(fake.receivedRequests.allSatisfy { $0.text.count <= 280 })
    #expect(outcome.audio.format == .pcm24kMono16)
    #expect(!outcome.isSuspect)
  }

  @Test("Short text is one chunk and one take of headerless PCM")
  func testShortTextSingleChunk() async throws {
    let (service, fake, _) = try await makeService()
    let outcome = try await service.generateValidated(request("Hello there, world."))
    #expect(outcome.chunkCount == 1)
    #expect(outcome.takes == 1)
    #expect(fake.synthesizeCallCount == 1)
    #expect(!outcome.audio.data.isEmpty)
    #expect(outcome.audio.data.prefix(4) != Data("RIFF".utf8))
  }

  @Test("Duration describes the returned samples")
  func testDurationMatchesData() async throws {
    let (service, _, _) = try await makeService()
    let audio = try await service.generate(request(Self.text600))
    let expected = Double(audio.data.count / 2) / 24_000
    #expect(abs(audio.duration - expected) < 0.0001)
    #expect(audio.duration > 20)
  }

  @Test("A .wav target joins chunks under one RIFF header")
  func testWavTargetHeader() async throws {
    let wav = AudioFormat(container: .wav, sampleRate: 24_000, channels: 1, bitDepth: 16)
    let (service, _, _) = try await makeService(targetFormat: wav)
    let audio = try await service.generate(request(Self.text600))
    #expect(audio.format == wav)
    #expect(audio.data.prefix(4) == Data("RIFF".utf8))
    let size = audio.data.subdata(in: 40..<44).withUnsafeBytes {
      $0.loadUnaligned(as: UInt32.self)
    }
    #expect(Int(UInt32(littleEndian: size)) == audio.data.count - 44)
    #expect(abs(audio.duration - Double((audio.data.count - 44) / 2) / 24_000) < 0.0001)
  }

  @Test("A non-PCM target throws invalidRequest before synthesis")
  func testUnsupportedTargetThrows() async throws {
    let aiff = AudioFormat(container: .aiff, sampleRate: 24_000, channels: 1, bitDepth: 16)
    let (service, fake, _) = try await makeService(targetFormat: aiff)
    let speech = request("Hello.")
    let error = await hablareError { _ = try await service.generate(speech) }
    #expect(isInvalidRequest(error))
    #expect(fake.synthesizeCallCount == 0)
  }

  @Test("Empty or whitespace-only text throws invalidRequest")
  func testEmptyTextThrows() async throws {
    let (service, fake, _) = try await makeService()
    let empty = request("")
    let blank = request("  \n ")
    let emptyError = await hablareError { _ = try await service.generate(empty) }
    let blankError = await hablareError { _ = try await service.generate(blank) }
    #expect(isInvalidRequest(emptyError))
    #expect(isInvalidRequest(blankError))
    #expect(fake.synthesizeCallCount == 0)
  }

  @Test("An engine with no character limit is chunked at fallbackMaxCharacters")
  func testFallbackMaxCharacters() async throws {
    let registry = makeRegistry([ListingFakePlugin.self])
    let plugin = try #require(
      try await registry.plugin(id: ListingFakePlugin.id) as? ListingFakePlugin)
    let service = GenerationService(registry: registry, fallbackMaxCharacters: 100)
    let voice = VoiceReference.catalog(pluginId: ListingFakePlugin.id, voiceId: "v1")

    let outcome = try await service.generateValidated(
      SpeechRequest(text: Self.text600, voice: voice))

    #expect(outcome.chunkCount >= 6)
    #expect(plugin.fake.receivedRequests.allSatisfy { $0.text.count <= 100 })
  }

  // MARK: - Request fields

  @Test("The request seed seeds the first take of every chunk")
  func testSeedIsPassedThrough() async throws {
    let (service, fake, _) = try await makeService()
    _ = try await service.generate(request(Self.text600, seed: 42))
    #expect(!fake.receivedRequests.isEmpty)
    #expect(fake.receivedRequests.allSatisfy { $0.seed == 42 })
  }

  @Test("Language code and voice reach the synthesizer")
  func testLanguageCodeAndVoicePassedThrough() async throws {
    let (service, fake, _) = try await makeService()
    _ = try await service.generate(
      text: "Hola, mundo.", voice: TestFixtures.fakeVoice, languageCode: "es")
    let received = try #require(fake.receivedRequests.first)
    #expect(received.languageCode == "es")
    #expect(received.voice == TestFixtures.fakeVoice)
  }

  @Test("A dropped instruct is reported on the joined audio")
  func testDroppedInstructReported() async throws {
    let (service, _, _) = try await makeService()
    var speech = request("Say it softly.")
    speech.instruct = "whisper"
    let audio = try await service.generate(speech)
    #expect(audio.droppedInstruct)
  }

  // MARK: - Take validation

  @Test("Implausible takes are retried with new seeds and flagged suspect")
  func testSuspectTakes() async throws {
    // At 1 char/s the fake's 14 chars/s takes are far too short to be plausible.
    let policy = TakePolicy(charactersPerSecond: 1, maxRetries: 2)
    let (service, fake, _) = try await makeService(takePolicy: policy)

    let outcome = try await service.generateValidated(request("Hello there, world.", seed: 7))

    #expect(outcome.isSuspect)
    #expect(outcome.suspectChunks == [0])
    #expect(outcome.takes == 3)
    #expect(fake.receivedRequests.map(\.seed) == [7, 1007, 2007])
  }

  @Test("Plausible takes are not suspect")
  func testPlausibleTakesNotSuspect() async throws {
    let (service, fake, _) = try await makeService()
    let outcome = try await service.generateValidated(request(Self.text600))
    #expect(outcome.suspectChunks.isEmpty)
    #expect(outcome.takes == fake.synthesizeCallCount)
  }

  @Test("GenerationResult carries the suspect flag")
  func testResultCarriesSuspect() async throws {
    let policy = TakePolicy(charactersPerSecond: 1, maxRetries: 0)
    let (service, _, _) = try await makeService(takePolicy: policy)
    let result = try await service.generate(text: "Hello there.", voice: TestFixtures.fakeVoice)
    #expect(result.isSuspect)
  }

  // MARK: - Progress

  @Test("Synthesizer progress is passed through per chunk")
  func testProgressPassedThrough() async throws {
    let (service, _, _) = try await makeService()
    let recorder = Recorder<GenerationProgress>()

    let outcome = try await service.generateValidated(request(Self.text600)) {
      recorder.append($0)
    }

    let reports = recorder.values
    #expect(reports.count == outcome.chunkCount * 2)
    #expect(reports.allSatisfy { $0.chunkCount == outcome.chunkCount })
    #expect(reports.first?.synthesis == .started)
    #expect(reports.first?.chunk == 0)
    #expect(reports.last?.synthesis == .finished)
    #expect(reports.last?.chunk == outcome.chunkCount - 1)
    #expect(reports.last?.fractionCompleted == 1)
  }

  @Test("fractionCompleted counts finished chunks")
  func testFractionCompleted() {
    let started = GenerationProgress(chunk: 0, chunkCount: 4, synthesis: .started)
    let half = GenerationProgress(chunk: 1, chunkCount: 4, synthesis: .finished)
    let none = GenerationProgress(chunk: 0, chunkCount: 0, synthesis: .started)
    #expect(started.fractionCompleted == 0)
    #expect(half.fractionCompleted == 0.5)
    #expect(none.fractionCompleted == 0)
  }

  // MARK: - Errors and resolution

  @Test("Synthesizer errors propagate unchanged")
  func testSynthesizerErrorPropagates() async throws {
    let (service, fake, _) = try await makeService()
    fake.failNextCall(with: .quotaExceeded)
    let speech = request("Hello.")
    let error = await hablareError { _ = try await service.generate(speech) }
    guard case .quotaExceeded? = error else {
      Issue.record("Expected quotaExceeded, got \(String(describing: error))")
      return
    }
  }

  @Test("An unknown plugin throws invalidRequest")
  func testUnknownPluginThrows() async throws {
    let (service, _, _) = try await makeService()
    let speech = SpeechRequest(text: "Hello.", voice: .catalog(pluginId: "nope", voiceId: "x"))
    let error = await hablareError { _ = try await service.generate(speech) }
    #expect(isInvalidRequest(error))
  }

  @Test("A disabled plugin throws invalidRequest and is not synthesized")
  func testDisabledPluginThrows() async throws {
    let (service, fake, registry) = try await makeService()
    await registry.setEnabled(false, for: FakeSynthesizerPlugin.id)
    let speech = request("Hello.")
    let error = await hablareError { _ = try await service.generate(speech) }
    #expect(isInvalidRequest(error))
    #expect(fake.synthesizeCallCount == 0)
  }

  @Test("An asset voice needs a plugin id")
  func testAssetVoiceNeedsPluginId() async throws {
    let (service, _, _) = try await makeService()
    let voice = VoiceReference.asset(URL(fileURLWithPath: "/tmp/narrator.vox"))
    let speech = SpeechRequest(text: "Hello.", voice: voice)
    let error = await hablareError { _ = try await service.generate(speech) }
    #expect(isInvalidRequest(error))
  }

  @Test("An asset voice synthesizes through the named plugin")
  func testAssetVoiceWithPluginId() async throws {
    let (service, fake, _) = try await makeService()
    let url = URL(fileURLWithPath: "/tmp/narrator.vox")
    let result = try await service.generate(
      text: "Hello there.", voice: .asset(url), pluginId: FakeSynthesizerPlugin.id)
    #expect(fake.synthesizeCallCount == 1)
    #expect(result.providerId == FakeSynthesizerPlugin.id)
    #expect(result.voiceId == url.absoluteString)
  }

  // MARK: - Cancellation

  @Test("A cancelled task throws cancelled before synthesizing")
  func testCancelledBeforeStart() async throws {
    let (service, fake, _) = try await makeService()
    let speech = request("Hello there.")
    let task = Task {
      withUnsafeCurrentTask { $0?.cancel() }
      return try await service.generate(speech)
    }
    let result = await task.result
    #expect(isCancelled(result.failure))
    #expect(fake.synthesizeCallCount == 0)
  }

  @Test("Cancellation between chunks stops before the next chunk")
  func testCancelledBetweenChunks() async throws {
    let (service, fake, _) = try await makeService()
    let speech = request(Self.text600)
    let task = Task {
      try await service.generate(speech) { report in
        if report.synthesis == .finished { withUnsafeCurrentTask { $0?.cancel() } }
      }
    }
    let result = await task.result
    #expect(isCancelled(result.failure))
    #expect(fake.synthesizeCallCount == 1)
  }

  // MARK: - Results and storage

  @Test("generate(text:voice:) fills the result from the generated audio")
  func testGenerateTextResult() async throws {
    let (service, _, _) = try await makeService()
    let result = try await service.generate(
      text: "Hello, this is a test.", voice: TestFixtures.fakeVoice, voiceName: "Fake")
    #expect(!result.audioData.isEmpty)
    #expect(result.originalText == "Hello, this is a test.")
    #expect(result.voiceId == "fake-voice")
    #expect(result.voiceName == "Fake")
    #expect(result.providerId == FakeSynthesizerPlugin.id)
    #expect(result.format == .pcm24kMono16)
    #expect(result.mimeType == "audio/L16")
    #expect(result.estimatedDuration > 0)
    #expect(!result.isSuspect)
  }

  @Test("toTypedDataStorage takes the MIME type and audio metadata from the format")
  func testToTypedDataStorageFromFormat() async throws {
    let (service, _, _) = try await makeService()
    let result = try await service.generate(
      text: "Test conversion.", voice: TestFixtures.fakeVoice, voiceName: "Fake")

    let storage = result.toTypedDataStorage()

    #expect(storage.id == result.requestId)
    #expect(storage.providerId == FakeSynthesizerPlugin.id)
    #expect(storage.requestorID == "\(FakeSynthesizerPlugin.id).audio.tts")
    #expect(storage.mimeType == "audio/L16")
    #expect(storage.audioFormat == "pcm")
    #expect(storage.sampleRate == 24_000)
    #expect(storage.channels == 1)
    #expect(storage.binaryValue == result.audioData)
    #expect(storage.prompt == result.originalText)
    #expect(storage.durationSeconds == result.estimatedDuration)
    #expect(storage.voiceID == "fake-voice")
    #expect(storage.voiceName == "Fake")
  }

  @Test("A .wav target is stored as audio/wav")
  func testWavStoredMimeType() async throws {
    let wav = AudioFormat(container: .wav, sampleRate: 24_000, channels: 1, bitDepth: 16)
    let (service, _, _) = try await makeService(targetFormat: wav)
    let result = try await service.generate(text: "Hello.", voice: TestFixtures.fakeVoice)
    #expect(result.toTypedDataStorage().mimeType == "audio/wav")
  }

  @Test("A result built without a format keeps its own MIME type")
  func testToTypedDataStorageWithoutFormat() {
    let result = GenerationResult(
      audioData: Data([1, 2, 3]), originalText: "Hi", voiceId: "v", voiceName: nil,
      providerId: "p", mimeType: "audio/mpeg", estimatedDuration: 1)
    let storage = result.toTypedDataStorage()
    #expect(storage.mimeType == "audio/mpeg")
    #expect(storage.audioFormat == nil)
    #expect(storage.sampleRate == nil)
  }

  @Test("Each container maps to a stable MIME type")
  func testAudioFormatMimeTypes() {
    func mime(_ container: AudioFormat.Container) -> String {
      AudioFormat(container: container, sampleRate: 24_000, channels: 1).mimeType
    }
    #expect(mime(.wav) == "audio/wav")
    #expect(mime(.aiff) == "audio/x-aiff")
    #expect(mime(.mp3) == "audio/mpeg")
    #expect(mime(.pcm) == "audio/L16")
    #expect(mime(.opus) == "audio/opus")
  }

  // MARK: - Voices

  @Test("fetchVoices lists through the plugin's VoiceListing")
  func testFetchVoicesFromListingPlugin() async throws {
    let service = GenerationService(registry: makeRegistry([ListingFakePlugin.self]))
    let voices = try await service.fetchVoices(from: ListingFakePlugin.id, languageCode: "fr")
    #expect(voices.map(\.id) == ["v1", "v2"])
    #expect(voices.allSatisfy { $0.language == "fr" && $0.providerId == ListingFakePlugin.id })
  }

  @Test("fetchVoices throws for a plugin that cannot list")
  func testFetchVoicesWithoutListingThrows() async throws {
    let (service, _, _) = try await makeService()
    let error = await hablareError {
      _ = try await service.fetchVoices(from: FakeSynthesizerPlugin.id)
    }
    #expect(isInvalidRequest(error))
  }

  @Test("fetchVoices throws for an unknown plugin")
  func testFetchVoicesUnknownPluginThrows() async throws {
    let (service, _, _) = try await makeService()
    let error = await hablareError { _ = try await service.fetchVoices(from: "unknown") }
    #expect(isInvalidRequest(error))
  }

  @Test("fetchAllVoices keeps listing plugins and skips the rest")
  func testFetchAllVoices() async throws {
    let registry = makeRegistry([
      FakeSynthesizerPlugin.self, ListingFakePlugin.self, FailingListingPlugin.self,
    ])
    let service = GenerationService(registry: registry)
    let all = try await service.fetchAllVoices(languageCode: "en")
    #expect(Set(all.keys) == [ListingFakePlugin.id])
    #expect(all[ListingFakePlugin.id]?.count == 2)
  }

  @Test("fetchAllVoices skips disabled plugins")
  func testFetchAllVoicesSkipsDisabled() async throws {
    let registry = makeRegistry([ListingFakePlugin.self])
    await registry.setEnabled(false, for: ListingFakePlugin.id)
    let all = try await GenerationService(registry: registry).fetchAllVoices()
    #expect(all.isEmpty)
  }

  @Test("ApplePlugin adopts VoiceListing")
  func testApplePluginListsVoices() async throws {
    let registry = makeRegistry([ApplePlugin.self])
    let plugin = try await registry.plugin(id: ApplePlugin.id)
    #expect(plugin is any VoiceListing)
  }

  @Test("isVoiceAvailable follows the synthesizer's readiness")
  func testIsVoiceAvailable() async throws {
    let (service, fake, _) = try await makeService()
    let available = await service.isVoiceAvailable("fake-voice", from: FakeSynthesizerPlugin.id)
    let unknown = await service.isVoiceAvailable("fake-voice", from: "unknown")
    fake.setReadiness(.unsupported(reason: "gone"))
    let unsupported = await service.isVoiceAvailable(
      "fake-voice", from: FakeSynthesizerPlugin.id)
    #expect(available)
    #expect(!unknown)
    #expect(!unsupported)
  }

  // MARK: - Lists

  @Test("generateList persists one record per item through the fakes")
  func testGenerateList() async throws {
    let (service, fake, _) = try await makeService()
    let context = try TestFixtures.makeTestContext()
    let list = SpeakableItemList(
      name: "Greetings", items: messages(["Hello.", "Good morning.", "Goodbye."]))

    let records = try await service.generateList(list, to: context)

    #expect(records.count == 3)
    #expect(records.map(\.prompt) == ["Hello.", "Good morning.", "Goodbye."])
    #expect(records.allSatisfy { $0.mimeType == "audio/L16" && $0.binaryValue?.isEmpty == false })
    #expect(fake.synthesizeCallCount == 3)
    #expect(list.isComplete)
    #expect(list.progress == 1)
    let stored = try context.fetch(FetchDescriptor<TypedDataStorage>())
    #expect(stored.count == 3)
  }

  @Test("generateList reports item index with chunk progress")
  func testGenerateListProgress() async throws {
    let (service, _, _) = try await makeService()
    let context = try TestFixtures.makeTestContext()
    let list = SpeakableItemList(name: "Two", items: messages(["One.", "Two."]))
    let recorder = Recorder<Int>()

    _ = try await service.generateList(list, to: context) { index, report in
      if report.synthesis == .finished { recorder.append(index) }
    }

    #expect(recorder.values == [0, 1])
  }

  @Test("Cancelling generateList mid-list throws cancelled and synthesizes no later item")
  func testGenerateListCancelledMidList() async throws {
    let (service, fake, _) = try await makeService()
    let context = try TestFixtures.makeTestContext()
    let list = SpeakableItemList(
      name: "Three", items: messages(["First item.", "Second item.", "Third item."]))

    let task = Task { @MainActor () throws -> Void in
      _ = try await service.generateList(list, to: context) { index, report in
        // Cancel the generating task once the first item has finished.
        if index == 0, report.synthesis == .finished {
          withUnsafeCurrentTask { $0?.cancel() }
        }
      }
    }
    let result = await task.result

    #expect(isCancelled(result.failure))
    #expect(fake.receivedRequests.map(\.text) == ["First item."])
    #expect(list.hasFailed)
    #expect(isCancelled(list.error))
    let stored = try context.fetch(FetchDescriptor<TypedDataStorage>())
    #expect(stored.map(\.prompt) == ["First item."])
  }

  @Test("A list cancelled before it starts makes nothing")
  func testGenerateListCancelledByList() async throws {
    let (service, fake, _) = try await makeService()
    let context = try TestFixtures.makeTestContext()
    let list = SpeakableItemList(name: "Stopped", items: messages(["One.", "Two."]))
    list.cancel()

    let records = try await service.generateList(list, to: context)

    #expect(records.isEmpty)
    #expect(fake.synthesizeCallCount == 0)
  }

  @Test("A failing item fails the list and keeps earlier records")
  func testGenerateListFailureKeepsPartialResults() async throws {
    let (service, fake, _) = try await makeService()
    let context = try TestFixtures.makeTestContext()
    let list = SpeakableItemList(
      name: "Broken", items: messages(["Fine.", "", "Never reached."]))

    let error = await hablareError { _ = try await service.generateList(list, to: context) }

    #expect(isInvalidRequest(error))
    #expect(list.hasFailed)
    #expect(fake.receivedRequests.map(\.text) == ["Fine."])
    let stored = try context.fetch(FetchDescriptor<TypedDataStorage>())
    #expect(stored.map(\.prompt) == ["Fine."])
  }
}
