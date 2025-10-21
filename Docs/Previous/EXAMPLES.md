# SwiftHablaré Code Examples

Comprehensive, copy-paste ready examples for common SwiftHablaré use cases.

## Table of Contents

1. [Basic Examples](#basic-examples)
2. [Provider Management](#provider-management)
3. [Content Generation](#content-generation)
4. [SwiftData Integration](#swiftdata-integration)
5. [Credential Management](#credential-management)
6. [Error Handling](#error-handling)
7. [Advanced Patterns](#advanced-patterns)
8. [SwiftUI Integration](#swiftui-integration)

---

## Basic Examples

### Minimal Text Generation

```swift
import SwiftData
import SwiftHablare

// Setup
let container = try ModelContainer(for: MyModel.self)
let context = ModelContext(container)

// Get provider
let manager = AIServiceManager.shared
let provider = manager.provider(for: "openai")!

// Generate
let result = try await provider.generate(
    prompt: "Write a greeting",
    parameters: ["model": "gpt-4"],
    context: context
)

// Handle result
if case .success(let content) = result {
    print(content.text ?? "")
}
```

### Using Typed Requestor

```swift
let requestor = OpenAITextRequestor(
    provider: openAIProvider,
    modelContext: context
)

let response = try await requestor.generate(
    prompt: "Explain Swift concurrency",
    parameters: [
        "model": "gpt-4",
        "temperature": 0.7,
        "max_tokens": 500
    ]
)

print(response.content)        // Generated text
print(response.model)          // Model used
print(response.finishReason)   // Why it stopped
print(response.usage)          // Token usage
```

---

## Provider Management

### List All Providers

```swift
let manager = AIServiceManager.shared

for provider in manager.getAvailableProviders() {
    print("Provider: \(provider.displayName)")
    print("  ID: \(provider.providerId)")
    print("  Configured: \(provider.isConfigured())")
    print("  Requires Key: \(provider.requiresAPIKey)")
    print("  Capabilities: \(provider.capabilities)")
}
```

### Query Providers by Capability

```swift
// Find text generation providers
let textProviders = manager.providers(
    withCapability: .textGeneration(models: [])
)

// Find image generation providers
let imageProviders = manager.providers(
    withCapability: .imageGeneration(sizes: [])
)

// Find embedding providers
let embeddingProviders = manager.providers(
    withCapability: .embedding(dimensions: [])
)
```

### Find Provider for Specific Model

```swift
// Find provider that supports GPT-4
if let provider = manager.provider(
    supportingModel: "gpt-4",
    capability: .textGeneration(models: [])
) {
    print("Found: \(provider.displayName)")
}

// Find provider that supports Claude
if let provider = manager.provider(
    supportingModel: "claude-3-opus",
    capability: .textGeneration(models: [])
) {
    print("Found: \(provider.displayName)")
}
```

### Register Custom Provider

```swift
final class MyCustomProvider: AIServiceProvider {
    let providerId = "my-custom"
    let displayName = "My Custom AI"
    let capabilities: Set<AICapability> = [
        .textGeneration(models: ["custom-model-1"])
    ]
    let requiresAPIKey = true

    func generate(
        prompt: String,
        parameters: [String: Any],
        context: ModelContext
    ) async throws -> Result<ResponseContent, AIServiceError> {
        // Your implementation
        return .success(.text("Custom response"))
    }

    func isConfigured() -> Bool {
        SecureKeychainManager.shared.hasCredential(
            for: providerId,
            type: .apiKey
        )
    }

    func supportsCapability(_ capability: AICapability) -> Bool {
        capabilities.contains(capability)
    }
}

// Register
AIServiceManager.shared.register(MyCustomProvider())
```

---

## Content Generation

### Text Generation (OpenAI)

```swift
let requestor = OpenAITextRequestor(
    provider: openAIProvider,
    modelContext: context
)

let response = try await requestor.generate(
    prompt: "Write a function to reverse a string in Swift",
    parameters: [
        "model": "gpt-4",
        "temperature": 0.3,       // Lower for code
        "max_tokens": 300,
        "top_p": 0.9
    ]
)

print(response.content)
```

### Text Generation (Anthropic)

```swift
let requestor = AnthropicTextRequestor(
    provider: anthropicProvider,
    modelContext: context
)

let response = try await requestor.generate(
    prompt: "Explain the actor model in Swift",
    parameters: [
        "model": "claude-3-opus-20240229",
        "max_tokens": 1000,
        "temperature": 0.7,
        "system": "You are a Swift programming expert"
    ]
)

print(response.content)
```

### Image Generation (DALL-E)

```swift
let requestor = OpenAIImageRequestor(
    provider: openAIProvider,
    modelContext: context
)

let image = try await requestor.generate(
    prompt: "A futuristic Swift logo with neon effects",
    parameters: [
        "model": "dall-e-3",
        "size": "1024x1024",
        "quality": "hd",
        "style": "vivid"
    ]
)

// Save image
let url = URL(fileURLWithPath: "/tmp/swift_logo.png")
try image.imageData.write(to: url)
```

### Audio Generation (ElevenLabs)

```swift
let requestor = ElevenLabsAudioRequestor(
    provider: elevenLabsProvider,
    modelContext: context
)

let audio = try await requestor.generate(
    prompt: "Welcome to SwiftHablaré, the unified AI framework for Swift",
    parameters: [
        "voice_id": "21m00Tcm4TlvDq8ikWAM",  // Rachel
        "model_id": "eleven_monolingual_v1",
        "stability": 0.5,
        "similarity_boost": 0.75
    ]
)

// Save audio
let url = URL(fileURLWithPath: "/tmp/welcome.mp3")
try audio.audioData.write(to: url)
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
        "model": "text-embedding-3-small",
        "dimensions": 512  // Optional dimension reduction
    ]
)

print("Dimensions: \(embedding.dimensions)")
print("Vector: \(embedding.values.prefix(10))...")  // First 10 values
```

### Batch Embeddings

```swift
let texts = [
    "Swift is a modern programming language",
    "SwiftUI makes building UIs easy",
    "Actors provide safe concurrency"
]

var embeddings: [OpenAIEmbeddingResponse] = []

for text in texts {
    let embedding = try await requestor.generate(
        prompt: text,
        parameters: ["model": "text-embedding-3-small"]
    )
    embeddings.append(embedding)
}

// Calculate similarity (cosine)
func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
    let dot = zip(a, b).map(*).reduce(0, +)
    let magA = sqrt(a.map { $0 * $0 }.reduce(0, +))
    let magB = sqrt(b.map { $0 * $0 }.reduce(0, +))
    return dot / (magA * magB)
}

let similarity = cosineSimilarity(
    embeddings[0].values,
    embeddings[1].values
)
```

---

## SwiftData Integration

### Auto-Persist Text to Model

```swift
@Model
final class Article {
    var id: UUID
    var title: String
    var summary: String = ""
    var tags: [String] = []

    init(title: String) {
        self.id = UUID()
        self.title = title
    }
}

// Create article
let article = Article(title: "Swift Concurrency Best Practices")
context.insert(article)

// Generate and persist summary
let coordinator = AIPersistenceCoordinator()
try await coordinator.generateAndPersist(
    provider: provider,
    prompt: "Summarize in 2-3 sentences: \(article.title)",
    model: article,
    property: \Article.summary,
    context: context
)

// article.summary is now populated and saved
```

### With Validation

```swift
try await coordinator.generateAndPersist(
    provider: provider,
    prompt: "Generate 3 relevant tags for: \(article.title)",
    model: article,
    property: \Article.tags,
    context: context,
    constraints: [
        "minLength": "3",
        "maxLength": "100"
    ]
)
```

### With Transformation

```swift
try await coordinator.generateAndPersist(
    provider: provider,
    prompt: "Generate title",
    model: article,
    property: \Article.title,
    context: context,
    transform: { value in
        // Ensure title is capitalized
        if let title = value as? String {
            return title.capitalized
        }
        return value
    }
)
```

### With Caching

```swift
// Enable caching
try await coordinator.generateAndPersist(
    provider: provider,
    prompt: "Common intro text",
    model: article,
    property: \Article.summary,
    context: context,
    useCache: true  // Reuse if same prompt was used before
)
```

### Batch Generation

```swift
let articles = [
    Article(title: "Swift 6"),
    Article(title: "SwiftUI"),
    Article(title: "Concurrency")
]

for article in articles {
    context.insert(article)
    try await coordinator.generateAndPersist(
        provider: provider,
        prompt: "Write intro for: \(article.title)",
        model: article,
        property: \Article.summary,
        context: context
    )
}
```

---

## Credential Management

### Save API Key

```swift
let keychain = SecureKeychainManager.shared

// With validation
try keychain.saveAPIKey(
    "sk-proj-abc123...",
    for: "openai",
    validate: true  // Validates format
)

// Without validation (faster)
try keychain.saveAPIKey(
    "sk-proj-abc123...",
    for: "openai",
    validate: false
)
```

### Retrieve and Use API Key

```swift
// Get key (returns SecureString)
let secureKey = try keychain.getAPIKey(for: "openai")
defer { secureKey.clear() }  // Always clear when done

// Use key
let apiKey = secureKey.value
let request = URLRequest(/* use apiKey */)
```

### Safe Pattern for API Keys

```swift
func makeAPICall() async throws {
    let secureKey = try SecureKeychainManager.shared.getAPIKey(for: "openai")
    defer { secureKey.clear() }

    var request = URLRequest(url: apiURL)
    request.setValue("Bearer \(secureKey.value)", forHTTPHeaderField: "Authorization")

    // Make request
    let (data, _) = try await URLSession.shared.data(for: request)
    // Process data
}
```

### Check Before Using

```swift
let keychain = SecureKeychainManager.shared

// Check existence
guard keychain.hasCredential(for: "openai", type: .apiKey) else {
    // Prompt user to add key
    return
}

// Now safe to retrieve
let key = try keychain.getAPIKey(for: "openai")
```

### List and Manage Credentials

```swift
// List all API key accounts
let accounts = keychain.listAccounts(for: .apiKey)
print("Configured providers: \(accounts)")

// Delete specific credential
try keychain.deleteAPIKey(for: "openai")

// Delete all credentials (dangerous!)
try keychain.deleteAllCredentials()
```

### OAuth Tokens

```swift
// Save OAuth token
try keychain.saveOAuthToken(
    "oauth2_token_here",
    for: "anthropic",
    validate: true
)

// Retrieve
let token = try keychain.getOAuthToken(for: "anthropic")
defer { token.clear() }
```

---

## Error Handling

### Comprehensive Error Handling

```swift
func generateContent() async {
    do {
        let response = try await provider.generate(...)
        // Handle success
    } catch let error as AIServiceError {
        switch error {
        case .invalidAPIKey:
            print("Invalid API key. Please check your credentials.")

        case .missingCredentials:
            print("No API key found. Please add one.")

        case .rateLimitExceeded(let retryAfter):
            if let delay = retryAfter {
                print("Rate limited. Retry after \(delay) seconds.")
                try? await Task.sleep(for: .seconds(delay))
                // Retry
            }

        case .modelNotFound(let model):
            print("Model '\(model)' not available. Try: gpt-4, gpt-3.5-turbo")

        case .invalidRequest(let reason):
            print("Invalid request: \(reason)")

        case .networkError(let underlying):
            print("Network error: \(underlying.localizedDescription)")

        case .unexpectedResponseFormat(let details):
            print("Unexpected response: \(details)")

        case .dataConversionError(let details):
            print("Data conversion failed: \(details)")

        case .validationError(let reason):
            print("Validation failed: \(reason)")

        case .providerError(let message):
            print("Provider error: \(message)")

        case .configurationError(let reason):
            print("Configuration error: \(reason)")

        case .unsupportedOperation(let operation):
            print("Operation not supported: \(operation)")

        case .authenticationFailed:
            print("Authentication failed. Check credentials.")

        case .dataBindingError(let details):
            print("Data binding failed: \(details)")

        case .cacheError(let details):
            print("Cache error: \(details)")

        @unknown default:
            print("Unknown error: \(error)")
        }
    } catch {
        print("Unexpected error: \(error)")
    }
}
```

### Retry Logic

```swift
func generateWithRetry(
    maxAttempts: Int = 3,
    backoffMultiplier: Double = 2.0
) async throws -> ResponseContent {
    var attempt = 0

    while attempt < maxAttempts {
        do {
            let result = try await provider.generate(...)
            guard case .success(let content) = result else {
                throw AIServiceError.providerError("Failed")
            }
            return content
        } catch AIServiceError.rateLimitExceeded(let retryAfter) {
            let delay = retryAfter ?? pow(backoffMultiplier, Double(attempt))
            try await Task.sleep(for: .seconds(delay))
            attempt += 1
        } catch {
            if attempt == maxAttempts - 1 {
                throw error
            }
            attempt += 1
            try await Task.sleep(for: .seconds(pow(backoffMultiplier, Double(attempt))))
        }
    }

    throw AIServiceError.providerError("Max retry attempts reached")
}
```

### Fallback Pattern

```swift
func generateWithFallback(prompt: String) async throws -> String {
    // Try primary provider
    do {
        let result = try await openAIProvider.generate(
            prompt: prompt,
            parameters: ["model": "gpt-4"],
            context: context
        )
        if case .success(let content) = result, let text = content.text {
            return text
        }
    } catch {
        print("Primary provider failed: \(error)")
    }

    // Fallback to secondary
    do {
        let result = try await anthropicProvider.generate(
            prompt: prompt,
            parameters: ["model": "claude-3-sonnet"],
            context: context
        )
        if case .success(let content) = result, let text = content.text {
            return text
        }
    } catch {
        print("Fallback provider failed: \(error)")
    }

    throw AIServiceError.providerError("All providers failed")
}
```

---

## Advanced Patterns

### Streaming (When Supported)

```swift
// Check if provider supports streaming
guard provider.supportsCapability(.streaming) else {
    print("Provider doesn't support streaming")
    return
}

// Stream response (provider-specific implementation)
for try await chunk in provider.generateStream(...) {
    print(chunk, terminator: "")
}
```

### Concurrent Requests

```swift
async let response1 = requestor1.generate(prompt: "Question 1")
async let response2 = requestor2.generate(prompt: "Question 2")
async let response3 = requestor3.generate(prompt: "Question 3")

let (r1, r2, r3) = try await (response1, response2, response3)
```

### Progress Tracking

```swift
actor ProgressTracker {
    private var completed = 0
    private var total: Int

    init(total: Int) {
        self.total = total
    }

    func increment() {
        completed += 1
        print("Progress: \(completed)/\(total)")
    }
}

let tracker = ProgressTracker(total: items.count)

try await withThrowingTaskGroup(of: Void.self) { group in
    for item in items {
        group.addTask {
            try await processItem(item)
            await tracker.increment()
        }
    }
    try await group.waitForAll()
}
```

### Caching Strategy

```swift
actor ResponseCache {
    private var cache: [String: ResponseContent] = [:]

    func get(_ key: String) -> ResponseContent? {
        cache[key]
    }

    func set(_ key: String, _ value: ResponseContent) {
        cache[key] = value
    }
}

let cache = ResponseCache()

func generate(prompt: String) async throws -> ResponseContent {
    // Check cache
    if let cached = await cache.get(prompt) {
        return cached
    }

    // Generate
    let result = try await provider.generate(...)
    guard case .success(let content) = result else {
        throw AIServiceError.providerError("Failed")
    }

    // Cache
    await cache.set(prompt, content)
    return content
}
```

---

## SwiftUI Integration

### Simple Generation View

```swift
struct GenerateView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var prompt = ""
    @State private var response = ""
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        VStack {
            TextField("Enter prompt", text: $prompt)
                .textFieldStyle(.roundedBorder)

            Button("Generate") {
                Task { await generate() }
            }
            .disabled(isLoading || prompt.isEmpty)

            if isLoading {
                ProgressView()
            }

            if let error {
                Text("Error: \(error)")
                    .foregroundColor(.red)
            }

            ScrollView {
                Text(response)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
    }

    func generate() async {
        isLoading = true
        error = nil
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
            self.error = error.localizedDescription
        }
    }
}
```

### Provider Selector

```swift
struct ProviderSelector: View {
    let manager = AIServiceManager.shared
    @State private var selectedProviderId = "openai"

    var body: some View {
        Picker("Provider", selection: $selectedProviderId) {
            ForEach(manager.getAvailableProviders(), id: \.providerId) { provider in
                HStack {
                    Text(provider.displayName)
                    if !provider.isConfigured() {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                    }
                }
                .tag(provider.providerId)
            }
        }
    }
}
```

### Article Generator with SwiftData

```swift
struct ArticleGeneratorView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var articles: [Article]
    @State private var title = ""
    @State private var isGenerating = false

    var body: some View {
        VStack {
            TextField("Article Title", text: $title)
            Button("Generate Article") {
                Task { await generateArticle() }
            }
            .disabled(isGenerating)

            List(articles) { article in
                VStack(alignment: .leading) {
                    Text(article.title).font(.headline)
                    Text(article.summary).font(.caption)
                }
            }
        }
    }

    func generateArticle() async {
        isGenerating = true
        defer { isGenerating = false }

        let article = Article(title: title)
        modelContext.insert(article)

        let coordinator = AIPersistenceCoordinator()
        let manager = AIServiceManager.shared
        let provider = manager.provider(for: "openai")!

        do {
            try await coordinator.generateAndPersist(
                provider: provider,
                prompt: "Write a comprehensive summary for: \(title)",
                model: article,
                property: \Article.summary,
                context: modelContext
            )
        } catch {
            print("Error: \(error)")
        }
    }
}
```

---

## Complete Example App

```swift
import SwiftUI
import SwiftData
import SwiftHablare

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: Article.self)
    }
}

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

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var articles: [Article]
    @State private var title = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(articles) { article in
                    VStack(alignment: .leading) {
                        Text(article.title).font(.headline)
                        Text(article.summary).font(.caption)
                    }
                }
            }
            .navigationTitle("Articles")
            .toolbar {
                Button("Add") {
                    Task { await addArticle() }
                }
            }
            .alert("New Article", isPresented: .constant(true)) {
                TextField("Title", text: $title)
                Button("Generate") {
                    Task { await addArticle() }
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    func addArticle() async {
        guard !title.isEmpty else { return }

        let article = Article(title: title)
        modelContext.insert(article)

        let coordinator = AIPersistenceCoordinator()
        let manager = AIServiceManager.shared
        let provider = manager.provider(for: "openai")!

        try? await coordinator.generateAndPersist(
            provider: provider,
            prompt: "Write a summary for: \(title)",
            model: article,
            property: \Article.summary,
            context: modelContext
        )

        title = ""
    }
}
```

---

**Version:** 2.0 (Phase 7 Complete)
**Last Updated:** October 13, 2025

For more examples and documentation, see:
- [Quick Start Guide](QUICK_START.md)
- [AI Development Guide](Docs/AI_DEVELOPMENT_GUIDE.md)
- [API Reference](API.md)
