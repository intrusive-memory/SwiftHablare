import Foundation
import Testing

@testable import SwiftHablare
@testable import SwiftHablareTesting

@Suite("TakeValidator")
struct TakeValidatorTests {
  private func request(seed: UInt64? = 7) -> SpeechRequest {
    SpeechRequest(
      text: String(repeating: "word ", count: 20), voice: .catalog(pluginId: "fake", voiceId: "v"),
      seed: seed)
  }

  @Test("Plausible first take: one call, not suspect")
  func plausible() async throws {
    let fake = FakeVoiceSynthesizer()
    let take = try await TakeValidator().synthesize(request(), using: fake)
    #expect(fake.synthesizeCallCount == 1)
    #expect(take.takes == 1)
    #expect(!take.suspect)
    #expect(take.seed == 7)
  }

  @Test("Implausibly short audio every time: exactly 3 synthesize calls and suspect")
  func alwaysShort() async throws {
    let fake = FakeVoiceSynthesizer(charactersPerSecond: 100_000)
    let take = try await TakeValidator().synthesize(request(), using: fake)
    #expect(fake.synthesizeCallCount == 3)
    #expect(take.takes == 3)
    #expect(take.suspect == true)
  }

  @Test("Retries use new, deterministic seeds")
  func seeds() async throws {
    let fake = FakeVoiceSynthesizer(charactersPerSecond: 100_000)
    _ = try await TakeValidator().synthesize(request(seed: 7), using: fake)
    #expect(fake.receivedRequests.map(\.seed) == [7, 1007, 2007])
    let none = FakeVoiceSynthesizer(charactersPerSecond: 100_000)
    _ = try await TakeValidator().synthesize(request(seed: nil), using: none)
    #expect(none.receivedRequests.map(\.seed) == [nil, 1000, 2000])
  }

  @Test("Policy is configurable")
  func configurable() async throws {
    let fake = FakeVoiceSynthesizer(charactersPerSecond: 100_000)
    let validator = TakeValidator(policy: TakePolicy(maxRetries: 0))
    let take = try await validator.synthesize(request(), using: fake)
    #expect(fake.synthesizeCallCount == 1)
    #expect(take.suspect)
  }

  @Test("Implausibly long audio is rejected too")
  func tooLong() async throws {
    let fake = FakeVoiceSynthesizer(charactersPerSecond: 1)
    let take = try await TakeValidator().synthesize(request(), using: fake)
    #expect(take.suspect)
    #expect(fake.synthesizeCallCount == 3)
  }

  @Test("Window matches the prototype")
  func window() {
    let policy = TakePolicy.default
    let text = String(repeating: "x", count: 140)  // expected 10 s
    #expect(policy.isPlausible(text: text, duration: 3.0))
    #expect(!policy.isPlausible(text: text, duration: 2.9))
    #expect(policy.isPlausible(text: text, duration: 23.5))
    #expect(!policy.isPlausible(text: text, duration: 23.6))
  }

  @Test("Synthesizer errors propagate without retry")
  func errors() async {
    let fake = FakeVoiceSynthesizer()
    fake.failNextCall(with: .invalidRequest(detail: "boom"))
    await #expect(throws: HablareError.self) {
      _ = try await TakeValidator().synthesize(request(), using: fake)
    }
    #expect(fake.synthesizeCallCount == 1)
  }
}
