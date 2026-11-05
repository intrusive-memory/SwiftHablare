import Testing

@testable import SwiftHablare

@Suite("SpeechRequest continuity text")
struct SpeechRequestContinuityTests {
  private let voice = VoiceReference.catalog(pluginId: "p", voiceId: "v")

  @Test("7.0-style init compiles and leaves continuity text nil")
  func legacyInit() {
    let r = SpeechRequest(text: "Hi", voice: voice, languageCode: "en", seed: 1)
    #expect(r.previousText == nil)
    #expect(r.nextText == nil)
  }

  @Test("construction stores previous and next text")
  func construction() {
    let r = SpeechRequest(text: "Hi", voice: voice, previousText: "Before.", nextText: "After.")
    #expect(r.previousText == "Before.")
    #expect(r.nextText == "After.")
  }

  @Test("equality and hashing include continuity text")
  func equalityHashing() {
    let a = SpeechRequest(text: "Hi", voice: voice, previousText: "A")
    let b = SpeechRequest(text: "Hi", voice: voice, previousText: "A")
    let c = SpeechRequest(text: "Hi", voice: voice, previousText: "B")
    #expect(a == b)
    #expect(a.hashValue == b.hashValue)
    #expect(a != c)
    #expect(Set([a, b, c]).count == 2)
  }
}
