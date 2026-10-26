//
//  VoiceURITests.swift
//  SwiftHablareTests
//
//  VoiceURI string form and its conversion to and from VoiceReference
//

import Foundation
import SwiftHablareTesting
import Testing

@testable import SwiftHablare

@Suite("VoiceURI Tests")
struct VoiceURITests {

  @Test("Parses an Apple catalog URI")
  func parsesAppleCatalogURI() throws {
    let uri = try #require(
      VoiceURI(uriString: "apple://com.apple.voice.compact.en-US.Samantha?lang=en"))

    #expect(uri.providerId == "apple")
    #expect(uri.voiceId == "com.apple.voice.compact.en-US.Samantha")
    #expect(uri.languageCode == "en")
    #expect(!uri.isAsset)
    #expect(uri.assetURL == nil)
    #expect(
      uri.voiceReference
        == .catalog(pluginId: "apple", voiceId: "com.apple.voice.compact.en-US.Samantha"))
    #expect(uri.uriString == "apple://com.apple.voice.compact.en-US.Samantha?lang=en")
  }

  @Test("Catalog reference round-trips through VoiceURI")
  func catalogRoundTrip() throws {
    let reference = VoiceReference.catalog(pluginId: "elevenlabs", voiceId: "21m00Tcm4TlvDq8ikWAM")

    let uri = VoiceURI(reference, languageCode: "en")
    #expect(uri.uriString == "elevenlabs://21m00Tcm4TlvDq8ikWAM?lang=en")
    #expect(uri.voiceReference == reference)

    let reparsed = try #require(VoiceURI(uriString: uri.uriString))
    #expect(reparsed == uri)
    #expect(reparsed.voiceReference == reference)
  }

  @Test("Asset reference round-trips through VoiceURI")
  func assetRoundTrip() throws {
    let url = URL(fileURLWithPath: "/Users/me/Voices/narrator.vox")
    let reference = VoiceReference.asset(url)

    let uri = VoiceURI(reference, languageCode: "en")
    #expect(uri.isAsset)
    #expect(uri.assetURL == url)
    #expect(uri.uriString == "asset:///Users/me/Voices/narrator.vox?lang=en")
    #expect(uri.voiceReference == reference)

    let reparsed = try #require(VoiceURI(uriString: uri.uriString))
    #expect(reparsed == uri)
    #expect(reparsed.voiceReference == reference)
    #expect(reparsed.languageCode == "en")
  }

  @Test("Asset URI without a language")
  func assetWithoutLanguage() throws {
    let url = URL(fileURLWithPath: "/Voices/narrator.vox")
    let uri = VoiceURI.asset(url)

    #expect(uri.uriString == "asset:///Voices/narrator.vox")
    let reparsed = try #require(VoiceURI(uriString: uri.uriString))
    #expect(reparsed.languageCode == nil)
    #expect(reparsed.voiceReference == .asset(url))
  }

  @Test("Asset path with spaces and special characters round-trips")
  func assetPathEncoding() throws {
    let url = URL(fileURLWithPath: "/Users/me/My Voices/Ana María #1.vox")
    let uri = VoiceURI.asset(url, languageCode: "es")

    let reparsed = try #require(VoiceURI(uriString: uri.uriString))
    #expect(reparsed.voiceReference == .asset(url))
    #expect(reparsed.languageCode == "es")
    #expect(!uri.uriString.contains(" "))
  }

  @Test("Non-file asset URL round-trips")
  func nonFileAssetRoundTrip() throws {
    let url = try #require(URL(string: "https://example.com/voices/narrator.vox"))
    let uri = VoiceURI.asset(url, languageCode: "en")

    let reparsed = try #require(VoiceURI(uriString: uri.uriString))
    #expect(reparsed.voiceReference == .asset(url))
    #expect(reparsed.languageCode == "en")
  }

  @Test("Asset URI without a path is invalid")
  func assetWithoutPathIsInvalid() {
    #expect(VoiceURI(uriString: "asset://") == nil)
    #expect(VoiceURI(uriString: "asset:///") == nil)
  }

  @Test("Codable round-trips an asset URI")
  func codableAssetRoundTrip() throws {
    let uri = VoiceURI.asset(URL(fileURLWithPath: "/Voices/narrator.vox"), languageCode: "en")
    let data = try JSONEncoder().encode(uri)
    let decoded = try JSONDecoder().decode(VoiceURI.self, from: data)
    #expect(decoded == uri)
    #expect(decoded.voiceReference == uri.voiceReference)
  }

  @Test("Availability resolves through the plugin registry")
  func availabilityThroughRegistry() async {
    let registry = TestFixtures.makeFakeRegistry()

    let catalog = VoiceURI(TestFixtures.fakeVoice)
    #expect(await catalog.isAvailable(in: registry))

    let unknown = VoiceURI(.catalog(pluginId: "no-such-plugin", voiceId: "x"))
    #expect(await unknown.isAvailable(in: registry) == false)

    let asset = VoiceURI.asset(URL(fileURLWithPath: "/Voices/narrator.vox"))
    #expect(await asset.isAvailable(in: registry) == false)  // asset needs a plugin id

    // The plugin resolves, but the asset file does not exist, so the fake reports it unsupported.
    #expect(await asset.isAvailable(in: registry, pluginId: FakeSynthesizerPlugin.id) == false)

    let plugin = try? await registry.plugin(id: FakeSynthesizerPlugin.id)
    (plugin as? FakeSynthesizerPlugin)?.setReadiness(.ready(source: nil))
    #expect(await asset.isAvailable(in: registry, pluginId: FakeSynthesizerPlugin.id))
  }
}
