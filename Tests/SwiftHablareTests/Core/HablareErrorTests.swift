import Foundation
import Testing

@testable import SwiftHablare

@Suite("HablareError")
struct HablareErrorTests {
  private struct Boom: Error {}
  private let voice = VoiceReference.catalog(pluginId: "p", voiceId: "v")

  @Test("missingCredential is permanent")
  func missingCredential() {
    let e = HablareError.missingCredential(
      pluginId: "google", environmentVariable: "GEMINI_API_KEY")
    #expect(e.category == .permanent)
    #expect(e.description.contains("GEMINI_API_KEY"))
  }

  @Test("safetyBlocked is permanent")
  func safetyBlocked() {
    #expect(HablareError.safetyBlocked(reason: "x").category == .permanent)
  }

  @Test("invalidRequest is permanent")
  func invalidRequest() {
    #expect(HablareError.invalidRequest(detail: "x").category == .permanent)
  }

  @Test("unsupportedVoice is permanent")
  func unsupportedVoice() {
    #expect(HablareError.unsupportedVoice(voice, reason: "x").category == .permanent)
  }

  @Test("modelNotAvailable is permanent until downloaded")
  func modelNotAvailable() {
    #expect(
      HablareError.modelNotAvailable(ModelDescriptor(id: "m")).category
        == .permanentUntilDownloaded)
  }

  @Test("rateLimited is transient")
  func rateLimited() {
    #expect(HablareError.rateLimited(retryAfter: 5).category == .transient)
    #expect(HablareError.rateLimited(retryAfter: nil).category == .transient)
  }

  @Test("quotaExceeded is permanent")
  func quotaExceeded() {
    #expect(HablareError.quotaExceeded.category == .permanent)
  }

  @Test("transient is transient")
  func transient() {
    #expect(HablareError.transient(underlying: Boom()).category == .transient)
  }

  @Test("cancelled is cancelled")
  func cancelled() {
    #expect(HablareError.cancelled.category == .cancelled)
  }

  @Test("description names the variable, never a key value")
  func descriptionHasNoSecret() {
    let secret = "sk_super_secret_value"
    let e = HablareError.missingCredential(
      pluginId: "elevenlabs", environmentVariable: "ELEVENLABS_API_KEY")
    #expect(!e.description.contains(secret))
  }
}
