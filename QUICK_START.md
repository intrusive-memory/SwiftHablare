# SwiftHablaré Quick Start Guide

Get up and running with SwiftHablaré in 5 minutes.

## Prerequisites

- iOS 26.0+ or macCatalyst 15.0+ (UIKit-based, no macOS)
- Swift 6.0+
- Xcode 15+
- SwiftData framework

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/intrusive-memory/SwiftHablare", from: "1.0.0")
]
```

Or in Xcode: File → Add Package Dependencies → Enter repository URL

## Your First AI Request (60 seconds)

### Step 1: Import and Setup (10 seconds)

```swift
import SwiftData
import SwiftHablare

// Create SwiftData container
let container = try ModelContainer(for: /* your models */)
let context = ModelContext(container)
```

### Step 2: Configure Provider (20 seconds)

```swift
// Get provider
let manager = AIServiceManager.shared
let provider = manager.provider(for: "openai")!

// Add API key
try SecureKeychainManager.shared.saveAPIKey(
    "sk-your-key-here",
    for: "openai",
    validate: false
)
```

### Step 3: Generate Content (30 seconds)

```swift
// Make request
let result = try await provider.generate(
    prompt: "Write a haiku about Swift programming",
    parameters: [
        "model": "gpt-4",
        "temperature": 0.7
    ],
    context: context
)

// Use result
switch result {
case .success(let content):
    print(content.text ?? "No text")
case .failure(let error):
    print("Error: \(error)")
}
```

**Done!** You just made your first AI request.

---

## Common Use Cases

### Text Generation

```swift
let requestor = OpenAITextRequestor(
    provider: openAIProvider,
    modelContext: context
)

let response = try await requestor.generate(
    prompt: "Explain async/await in Swift",
    parameters: ["model": "gpt-4"]
)

print(response.content)
```

### Image Generation

```swift
let requestor = OpenAIImageRequestor(
    provider: openAIProvider,
    modelContext: context
)

let image = try await requestor.generate(
    prompt: "A serene mountain landscape",
    parameters: [
        "model": "dall-e-3",
        "size": "1024x1024"
    ]
)

// image.imageData contains PNG data
```

### Audio Generation

```swift
let requestor = ElevenLabsAudioRequestor(
    provider: elevenLabsProvider,
    modelContext: context
)

let audio = try await requestor.generate(
    prompt: "Welcome to SwiftHablaré",
    parameters: [
        "voice_id": "21m00Tcm4TlvDq8ikWAM",
        "model_id": "eleven_monolingual_v1"
    ]
)

// audio.audioData contains MP3 data
```

### Embeddings

```swift
let requestor = OpenAIEmbeddingRequestor(
    provider: openAIProvider,
    modelContext: context
)

let embedding = try await requestor.generate(
    prompt: "Machine learning with Swift",
    parameters: [
        "model": "text-embedding-3-small"
    ]
)

// embedding.values contains [Float] vector
```

---

## SwiftData Integration

### Automatic Persistence

```swift
@Model
final class Article {
    var id: UUID
    var title: String
    var summary: String = ""

    init(title: String) {
        self.id = UUID()
        self.title = title
    }
}

// Create article
let article = Article(title: "Swift Concurrency")
context.insert(article)

// Auto-generate and save summary
let coordinator = AIPersistenceCoordinator()
try await coordinator.generateAndPersist(
    provider: provider,
    prompt: "Write a summary about: \(article.title)",
    model: article,
    property: \Article.summary,
    context: context
)

// article.summary is now populated and saved
```

---

## Provider Configuration

### Check Provider Status

```swift
let manager = AIServiceManager.shared

// List all providers
let providers = manager.getAvailableProviders()

// Check specific provider
if let openAI = manager.provider(for: "openai") {
    print("Configured: \(openAI.isConfigured())")
    print("Capabilities: \(openAI.capabilities)")
}
```

### Multiple Providers

```swift
// Register custom provider
let customProvider = CustomProvider()
manager.register(customProvider)

// Query by capability
let textProviders = manager.providers(
    withCapability: .textGeneration(models: [])
)

// Query by model
let gpt4Provider = manager.provider(
    supportingModel: "gpt-4",
    capability: .textGeneration(models: [])
)
```

---

## Credential Management

### Save Credentials

```swift
let keychain = SecureKeychainManager.shared

// API Key
try keychain.saveAPIKey("sk-...", for: "openai")

// OAuth Token
try keychain.saveOAuthToken("oauth-...", for: "anthropic")

// Certificate
try keychain.saveCertificate(certData, for: "custom")
```

### Retrieve Credentials

```swift
// Get key (returns SecureString)
let key = try keychain.getAPIKey(for: "openai")
defer { key.clear() } // Auto-clears on scope exit

// Use key
let apiKey = key.value

// Check existence
if keychain.hasCredential(for: "openai", type: .apiKey) {
    // Proceed
}
```

### List Credentials

```swift
// List all accounts with API keys
let accounts = keychain.listAccounts(for: .apiKey)

// Delete specific credential
try keychain.deleteAPIKey(for: "openai")

// Delete all credentials
try keychain.deleteAllCredentials()
```

---

## Error Handling

### Basic Pattern

```swift
do {
    let response = try await provider.generate(...)
    // Handle success
} catch let error as AIServiceError {
    switch error {
    case .invalidAPIKey:
        print("Please check your API key")
    case .rateLimitExceeded(let retryAfter):
        print("Rate limited. Retry after: \(retryAfter ?? 0)s")
    case .modelNotFound(let model):
        print("Model '\(model)' not found")
    default:
        print("Error: \(error.localizedDescription)")
    }
}
```

### Validation Pattern

```swift
// Validate before calling
guard provider.isConfigured() else {
    throw AIServiceError.missingCredentials
}

guard provider.supportsCapability(.textGeneration(models: ["gpt-4"])) else {
    throw AIServiceError.unsupportedOperation("Provider doesn't support GPT-4")
}

// Proceed with confidence
let response = try await provider.generate(...)
```

---

## SwiftUI Integration

### Simple View

```swift
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var prompt = ""
    @State private var response = ""
    @State private var isLoading = false

    var body: some View {
        VStack {
            TextField("Enter prompt", text: $prompt)
            Button("Generate") {
                Task {
                    await generate()
                }
            }
            .disabled(isLoading)

            Text(response)
        }
    }

    func generate() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let manager = AIServiceManager.shared
            let provider = manager.provider(for: "openai")!

            let result = try await provider.generate(
                prompt: prompt,
                parameters: ["model": "gpt-4"],
                context: modelContext
            )

            if case .success(let content) = result {
                response = content.text ?? ""
            }
        } catch {
            response = "Error: \(error.localizedDescription)"
        }
    }
}
```

---

## Testing

### Basic Test

```swift
import XCTest
@testable import SwiftHablare

final class MyTests: XCTestCase {
    func testTextGeneration() async throws {
        // Setup in-memory SwiftData
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: TestModel.self,
            configurations: config
        )
        let context = ModelContext(container)

        // Create mock provider
        let provider = MockAIServiceProvider(
            id: "mock",
            displayName: "Mock",
            capabilities: [.textGeneration(models: ["mock"])],
            requiresAPIKey: false
        )

        // Configure response
        provider.mockResponse = .success(
            ResponseContent.text("Test response")
        )

        // Test
        let result = try await provider.generate(
            prompt: "test",
            parameters: [:],
            context: context
        )

        guard case .success(let content) = result,
              let text = content.text else {
            XCTFail("Expected text response")
            return
        }

        XCTAssertEqual(text, "Test response")
    }
}
```

---

## Next Steps

1. **Read the Full Guide:** [AI Development Guide](Docs/AI_DEVELOPMENT_GUIDE.md)
2. **See More Examples:** [Examples Guide](EXAMPLES.md)
3. **API Reference:** [API.md](API.md)
4. **Browse Source:** Explore `Sources/SwiftHablare/`

## Need Help?

- **Issues:** [GitHub Issues](https://github.com/intrusive-memory/SwiftHablare/issues)
- **Discussions:** [GitHub Discussions](https://github.com/intrusive-memory/SwiftHablare/discussions)
- **Documentation:** Check `Docs/` directory

---

**Version:** 2.0 (Phase 7 Complete)
**Last Updated:** October 13, 2025
