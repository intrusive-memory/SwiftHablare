import Foundation
import SwiftHablareTesting
import Testing

@testable import SwiftHablare

@Suite("Credentials chain")
struct CredentialsTests {
  static let secret = "sk-test-SECRET-VALUE-12345"

  @Test("Environment value wins over a store behind it")
  func environmentWins() {
    let env = EnvironmentAPIKeyStore(environment: ["ELEVENLABS_API_KEY": "from-env"])
    let memory = InMemoryAPIKeyStore(keys: ["elevenlabs": "from-memory"])
    let chain = ChainedAPIKeyStore([env, memory])
    #expect(chain.apiKey(for: "elevenlabs") == "from-env")
    #expect(chain.keySource(for: "elevenlabs") == "environment (ELEVENLABS_API_KEY)")
  }

  @Test("Falls through to the next store when the environment has no key")
  func fallsThrough() {
    let env = EnvironmentAPIKeyStore(environment: [:])
    let memory = InMemoryAPIKeyStore(keys: ["elevenlabs": "from-memory"])
    let chain = ChainedAPIKeyStore([env, memory])
    #expect(chain.apiKey(for: "elevenlabs") == "from-memory")
    #expect(chain.keySource(for: "elevenlabs") == "memory")
  }

  @Test("GEMINI_API_KEY resolves through its GOOGLE_API_KEY alias")
  func aliasResolves() {
    let env = EnvironmentAPIKeyStore(environment: ["GOOGLE_API_KEY": "alias-value"])
    #expect(env.apiKey(for: "google") == "alias-value")
    #expect(env.keySource(for: "google") == "environment (GOOGLE_API_KEY)")
    let both = EnvironmentAPIKeyStore(
      environment: ["GOOGLE_API_KEY": "alias-value", "GEMINI_API_KEY": "primary-value"])
    #expect(both.apiKey(for: "google") == "primary-value")
  }

  @Test("Environment store is read-only and ignores blank values")
  func readOnlyAndBlank() {
    let env = EnvironmentAPIKeyStore(environment: ["ELEVENLABS_API_KEY": "  \n"])
    #expect(env.apiKey(for: "elevenlabs") == nil)
    #expect(throws: CredentialStoreError.readOnly("environment")) {
      try env.setAPIKey("x", for: "elevenlabs")
    }
  }

  @Test("Chain writes skip read-only members")
  func chainWrites() throws {
    let memory = InMemoryAPIKeyStore()
    let chain = ChainedAPIKeyStore([EnvironmentAPIKeyStore(environment: [:]), memory])
    try chain.setAPIKey("abc", for: "elevenlabs")
    #expect(memory.apiKey(for: "elevenlabs") == "abc")
    try chain.removeAPIKey(for: "elevenlabs")
    #expect(memory.apiKey(for: "elevenlabs") == nil)
    #expect(throws: CredentialStoreError.readOnly("chain")) {
      try ChainedAPIKeyStore([EnvironmentAPIKeyStore(environment: [:])])
        .setAPIKey("x", for: "elevenlabs")
    }
  }

  @Test("Descriptions and keySource never contain the key value")
  func noKeyLeaks() throws {
    let secret = Self.secret
    let env = EnvironmentAPIKeyStore(environment: ["ELEVENLABS_API_KEY": secret])
    let memory = InMemoryAPIKeyStore(keys: ["elevenlabs": secret])
    let service = "test.hablare.leak.\(UUID().uuidString)"
    let keychain = KeychainAPIKeyStore(service: service)
    defer { try? keychain.removeAPIKey(for: "elevenlabs") }
    try keychain.setAPIKey(secret, for: "elevenlabs")
    let chain = ChainedAPIKeyStore([env, memory, keychain])

    let stores: [any APIKeyStoring] = [env, memory, keychain, chain]
    for store in stores {
      #expect(!String(describing: store).contains(secret))
      #expect(!String(reflecting: store).contains(secret))
      let source = try #require(store.keySource(for: "elevenlabs"))
      #expect(!source.contains(secret))
    }
    #expect(!String(describing: CredentialStoreError.keychain(-25300)).contains(secret))
  }

  @Test("Keychain round trip under a unique service")
  func keychainRoundTrip() throws {
    let store = KeychainAPIKeyStore(service: "test.hablare.\(UUID().uuidString)", accessGroup: nil)
    defer { try? store.removeAPIKey(for: "elevenlabs") }
    #expect(store.apiKey(for: "elevenlabs") == nil)
    try store.setAPIKey("first", for: "elevenlabs")
    #expect(store.apiKey(for: "elevenlabs") == "first")
    try store.setAPIKey("second", for: "elevenlabs")
    #expect(store.apiKey(for: "elevenlabs") == "second")
    #expect(store.keySource(for: "elevenlabs") == "keychain")
    try store.removeAPIKey(for: "elevenlabs")
    #expect(store.apiKey(for: "elevenlabs") == nil)
    try store.removeAPIKey(for: "elevenlabs")  // no-op
  }

  @Test("intrusiveMemoryVoices constants")
  func sharedConstants() {
    #expect(
      KeychainAPIKeyStore.intrusiveMemoryVoices.service == "io.intrusive-memory.hablare.apiKeys")
    #expect(
      KeychainAPIKeyStore.intrusiveMemoryVoices.accessGroup
        == "H3EJ6Y8VJ6.io.intrusive-memory.hablare")
  }

  @Test("CredentialRequirement fields for built-ins")
  func requirements() {
    let google = CredentialRequirement.google
    #expect(google.primaryEnvironmentVariable == "GEMINI_API_KEY")
    #expect(google.aliases == ["GOOGLE_API_KEY"])
    #expect(google.helpURL != nil)
    let eleven = CredentialRequirement.elevenLabs
    #expect(eleven.primaryEnvironmentVariable == "ELEVENLABS_API_KEY")
    #expect(eleven.displayName == "ElevenLabs API key")
    #expect(eleven.placeholder == "sk_…")
  }

  @Test("Default chain is environment then Keychain")
  func defaultChain() {
    let chain = ChainedAPIKeyStore.default
    #expect(chain.stores.count == 2)
    #expect(chain.stores[0] is EnvironmentAPIKeyStore)
    #expect(chain.stores[1] is KeychainAPIKeyStore)
  }
}
