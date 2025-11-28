# SwiftHablare Requirements Document

## Overview

SwiftHablare is a Swift package that provides a unified interface for integrating multiple AI services with automatic local data persistence using SwiftData. The library enables developers to send prompts to various AI services and have the results automatically stored in SwiftData models, with secure credential management and a plugin-based architecture.

---

## Core Objectives

1. **Unified AI Service Interface**: Provide a consistent API for interacting with multiple AI service providers (OpenAI, Anthropic, ElevenLabs, Google AI, etc.)
2. **Automatic Data Persistence**: Seamlessly store AI-generated data in SwiftData models without requiring manual data handling
3. **Secure Credential Management**: Store API keys and credentials securely using Keychain
4. **Plugin Architecture**: Enable easy addition of new AI service providers through a protocol-based plugin system
5. **SwiftUI Integration**: Provide pre-built UI components for service configuration and management

---

## Functional Requirements

### 1. AI Service Provider System

#### 1.1 Provider Protocol
- **REQ-1.1.1**: Define an `AIServiceProvider` protocol that all service implementations must conform to
- **REQ-1.1.2**: Protocol must specify:
  - Unique provider identifier
  - Display name for UI purposes
  - API key requirements
  - Supported data generation capabilities (text, audio, image, video, structured data, etc.)
  - Configuration validation method
  - Request execution method with prompt and return type specification
  - Error handling interface

#### 1.2 Provider Registration
- **REQ-1.2.1**: Implement a provider registry system that maintains available providers
- **REQ-1.2.2**: Support dynamic provider registration at runtime
- **REQ-1.2.3**: Allow querying providers by capability type (e.g., "which providers can generate audio?")
- **REQ-1.2.4**: Support multiple instances of the same provider with different configurations

#### 1.3 Provider Capabilities
- **REQ-1.3.1**: Each provider must declare which data types it can generate:
  - Text (plain text, markdown, code, etc.)
  - Audio (speech, music, sound effects)
  - Images (generation, editing, analysis)
  - Video (generation, editing)
  - Structured data (JSON, CSV, XML)
  - Embeddings/vectors
  - Other custom types
- **REQ-1.3.2**: Providers must specify input requirements (prompt format, file uploads, etc.)
- **REQ-1.3.3**: Providers must define output schema for generated data

#### 1.4 SwiftData Structure Declaration
- **REQ-1.4.1**: Providers must declaratively define the SwiftData structures they can generate data for
- **REQ-1.4.2**: Each provider must specify a mapping between its capabilities and target SwiftData model types
- **REQ-1.4.3**: Providers must declare which properties of a SwiftData model they can populate
- **REQ-1.4.4**: The declaration mechanism must support:
  - Property-level mapping (e.g., "I can generate the `description` property of `Product` model")
  - Type constraints (e.g., "I only generate String, Data, or URL types")
  - Relationship handling (e.g., "I can populate related entities")
  - Validation rules for generated data
- **REQ-1.4.5**: Providers must specify the destination SwiftData object where generated data will be written
- **REQ-1.4.6**: The framework must validate that a provider's declared capabilities match the requested generation target before execution
- **REQ-1.4.7**: Support for provider-defined custom model attributes or protocols that SwiftData models can adopt to indicate AI-generation support

### 2. Data Storage and Persistence

#### 2.1 SwiftData Integration
- **REQ-2.1.1**: Automatically persist AI-generated responses to SwiftData models
- **REQ-2.1.2**: Support mapping provider responses to user-defined SwiftData models
- **REQ-2.1.3**: Store metadata with each generated response:
  - Provider identifier
  - Prompt used
  - Generation timestamp
  - Token usage/cost information (if available)
  - Model/voice/engine identifier
  - Request parameters
- **REQ-2.1.4**: Support caching of responses to avoid duplicate API calls

#### 2.2 Data Model Requirements
- **REQ-2.2.1**: Define base `AIGeneratedContent` model with common fields
- **REQ-2.2.2**: Support type-specific models that extend the base:
  - `GeneratedText`
  - `GeneratedAudio`
  - `GeneratedImage`
  - `GeneratedVideo`
  - `GeneratedStructuredData`
- **REQ-2.2.3**: Support user-defined custom models that conform to storage protocol
- **REQ-2.2.4**: Include relationship support between prompts and generated content
- **REQ-2.2.5**: SwiftData models must be able to declare AI-generation metadata:
  - Which properties can be AI-generated
  - Which providers are authorized to populate specific properties
  - Property generation constraints (min/max length, format requirements, etc.)
  - Whether property is required or optional for generation
- **REQ-2.2.6**: Support protocol-based model registration (e.g., `AIGeneratable` protocol) that models can adopt to expose generation capabilities
- **REQ-2.2.7**: Enable models to specify custom transformation logic when receiving provider-generated data
- **REQ-2.2.8**: Support partial model population where providers fill only specific properties

#### 2.3 Response Field Binding
- **REQ-2.3.1**: Enable binding of provider responses directly to SwiftData model properties
- **REQ-2.3.2**: Support automatic type conversion between provider response formats and Swift types
- **REQ-2.3.3**: Handle partial responses and streaming updates to data models
- **REQ-2.3.4**: Support validation of returned data before persistence

### 3. Request Management

#### 3.1 Request Execution
- **REQ-3.1.1**: Provide async/await interface for making AI service requests
- **REQ-3.1.2**: Support prompt templates with variable substitution
- **REQ-3.1.3**: Enable request configuration (temperature, max tokens, voice selection, etc.)
- **REQ-3.1.4**: Support batch requests to multiple providers
- **REQ-3.1.5**: Implement request queuing and rate limiting

#### 3.2 Response Handling
- **REQ-3.2.1**: Return strongly-typed responses based on expected data type
- **REQ-3.2.2**: Provide access to raw response data if needed
- **REQ-3.2.3**: Support streaming responses with progressive updates
- **REQ-3.2.4**: Handle partial failures gracefully (e.g., one provider fails in batch)

#### 3.3 Error Management
- **REQ-3.3.1**: Define comprehensive error types:
  - Configuration errors (missing API key, invalid settings)
  - Network errors (timeout, connection failed)
  - Provider errors (rate limit, invalid request, authentication failure)
  - Data validation errors (unexpected response format)
  - Storage errors (SwiftData persistence failure)
- **REQ-3.3.2**: Provide user-friendly error messages
- **REQ-3.3.3**: Support error recovery strategies (retry logic, fallback providers)
- **REQ-3.3.4**: Log errors for debugging purposes

### 4. Security and Credentials

#### 4.1 API Key Management
- **REQ-4.1.1**: Store API keys securely in Keychain
- **REQ-4.1.2**: Support per-provider API key storage and retrieval
- **REQ-4.1.3**: Never store API keys in UserDefaults or plain text
- **REQ-4.1.4**: Provide methods to validate API key format before storage
- **REQ-4.1.5**: Support multiple credential types (API keys, OAuth tokens, certificates)

#### 4.2 Credential Lifecycle
- **REQ-4.2.1**: Implement add/update/delete operations for credentials
- **REQ-4.2.2**: Support credential expiration and refresh workflows
- **REQ-4.2.3**: Provide credential validation check without making API calls
- **REQ-4.2.4**: Clear sensitive data from memory after use

### 5. User Interface Components

#### 5.1 Provider Configuration UI
- **REQ-5.1.1**: Provide SwiftUI widget for provider selection
- **REQ-5.1.2**: Each provider must supply its own configuration panel view
- **REQ-5.1.3**: Aggregate individual provider panels into a tabbed interface
- **REQ-5.1.4**: Show provider status (configured/not configured) in UI
- **REQ-5.1.5**: Support provider-specific settings (model selection, voice picker, etc.)

#### 5.2 Settings Interface
- **REQ-5.2.1**: Create a unified settings view with tabs for each available provider
- **REQ-5.2.2**: Display configuration state for each provider
- **REQ-5.2.3**: Provide secure text entry for API keys (masked input)
- **REQ-5.2.4**: Support test/validation button to verify credentials
- **REQ-5.2.5**: Show usage statistics and cost tracking per provider (if available)

#### 5.3 Request Interface
- **REQ-5.3.1**: Provide optional UI components for making requests
- **REQ-5.3.2**: Support prompt input with syntax highlighting/formatting
- **REQ-5.3.3**: Display generation progress indicators
- **REQ-5.3.4**: Show generated results with appropriate preview (text, audio player, image viewer, etc.)

#### 5.4 Field-Level Generation State
- **REQ-5.4.1**: Provide SwiftUI property wrappers or view modifiers for binding AI generation to form fields
- **REQ-5.4.2**: Display inline loading state while API request is in progress:
  - Show animated indicator (spinner, shimmer, pulsing, etc.)
  - Optionally display estimated completion time
  - Indicate which provider is being used
  - Support customizable loading UI
- **REQ-5.4.3**: Update field value automatically when generation completes successfully
- **REQ-5.4.4**: Display in-context error messages when request fails:
  - Show error inline near the field (not as separate alert/modal)
  - Provide clear, actionable error description
  - Include retry button/action when applicable
  - Distinguish between different error types (network, auth, rate limit, validation)
  - Support custom error presentation styles
- **REQ-5.4.5**: Support streaming updates for fields that can display partial results
- **REQ-5.4.6**: Maintain field editability during generation (allow user cancellation)
- **REQ-5.4.7**: Provide hooks for custom UI state transitions (idle → loading → success/error)
- **REQ-5.4.8**: Support progress indicators for multi-step generation processes
- **REQ-5.4.9**: Enable field-level generation metadata display (time taken, tokens used, cost)

### 6. Provider Plugin System

#### 6.1 Plugin Architecture
- **REQ-6.1.1**: Define clear protocol requirements for creating new provider plugins
- **REQ-6.1.2**: Support loading providers from separate Swift packages
- **REQ-6.1.3**: Enable third-party provider development without modifying core library
- **REQ-6.1.4**: Provide plugin discovery mechanism

#### 6.2 Plugin Metadata
- **REQ-6.2.1**: Each plugin must declare:
  - Provider name and version
  - Supported capabilities
  - Required credentials
  - Cost structure (if applicable)
  - Platform availability (iOS)
  - Minimum iOS version
- **REQ-6.2.2**: Support plugin documentation and help text

#### 6.3 Configuration Panel Protocol
- **REQ-6.3.1**: Define `AIServiceConfigurationView` protocol for provider settings UI
- **REQ-6.3.2**: Plugins must provide SwiftUI view conforming to configuration protocol
- **REQ-6.3.3**: Configuration views must handle their own state management
- **REQ-6.3.4**: Support dynamic form generation based on provider requirements

---

## Non-Functional Requirements

### 7. Performance

- **REQ-7.1**: API requests should execute asynchronously without blocking the main thread
- **REQ-7.2**: SwiftData persistence should not impact UI responsiveness
- **REQ-7.3**: Support concurrent requests to multiple providers
- **REQ-7.4**: Implement caching to minimize redundant API calls
- **REQ-7.5**: Optimize memory usage for large binary data (audio, images, video)

### 8. Reliability

- **REQ-8.1**: Handle network failures gracefully with appropriate retry logic
- **REQ-8.2**: Prevent data loss if app terminates during request
- **REQ-8.3**: Validate all data before persistence
- **REQ-8.4**: Ensure thread-safe access to shared resources
- **REQ-8.5**: Support data migration between library versions

### 9. Usability

- **REQ-9.1**: Provide comprehensive documentation with code examples
- **REQ-9.2**: Include sample projects demonstrating common use cases
- **REQ-9.3**: Use clear, descriptive error messages
- **REQ-9.4**: Follow Swift API design guidelines
- **REQ-9.5**: Provide sensible defaults for all configuration options

### 10. Compatibility

- **REQ-10.1**: Support iOS 26.0+ and macOS 26.0+ (or latest SwiftData requirements)
- **REQ-10.2**: Require Swift 6.0+
- **REQ-10.3**: Ensure strict concurrency checking compliance
- **REQ-10.4**: Support both Swift Package Manager installation
- **REQ-10.5**: Maintain backward compatibility within major versions
- **REQ-10.6**: UIKit-only (no macOS native support)

### 11. Testability

- **REQ-11.1**: All core functionality must be unit testable
- **REQ-11.2**: Provide mock implementations for testing without API calls
- **REQ-11.3**: Support dependency injection for all external dependencies
- **REQ-11.4**: Include integration tests for provider implementations
- **REQ-11.5**: Achieve minimum 80% code coverage

### 12. Extensibility

- **REQ-12.1**: Design for easy addition of new providers
- **REQ-12.2**: Support custom data types and transformations
- **REQ-12.3**: Allow middleware/interceptor pattern for request/response processing
- **REQ-12.4**: Enable custom error handling strategies
- **REQ-12.5**: Support plugin lifecycle hooks (initialization, configuration, cleanup)

### 13. Documentation and Developer Experience

#### 13.1 Extension Documentation
- **REQ-13.1.1**: Provide comprehensive guide for creating new AI service providers
- **REQ-13.1.2**: Include step-by-step tutorial for adding custom data types
- **REQ-13.1.3**: Document all protocol requirements with detailed explanations
- **REQ-13.1.4**: Provide decision trees for choosing which protocols to implement
- **REQ-13.1.5**: Include troubleshooting guide for common integration issues

#### 13.2 AI Code Builder Optimization
- **REQ-13.2.1**: Structure documentation in a format easily parseable by AI assistants (clear sections, consistent formatting)
- **REQ-13.2.2**: Include complete, runnable code examples for every major extension point
- **REQ-13.2.3**: Provide template files for new providers, data types, and configuration panels
- **REQ-13.2.4**: Document naming conventions and file organization patterns
- **REQ-13.2.5**: Include inline code comments explaining the "why" behind architectural decisions
- **REQ-13.2.6**: Provide checklists for implementing new components (what must be included)
- **REQ-13.2.7**: Document testing requirements and patterns for extensions

#### 13.3 Provider Development Guide
- **REQ-13.3.1**: Create dedicated guide: "Adding a New AI Service Provider"
  - Protocol conformance requirements
  - Credential management patterns
  - Error handling best practices
  - Response transformation strategies
  - Testing provider implementations
- **REQ-13.3.2**: Provide annotated example of a complete provider implementation
- **REQ-13.3.3**: Document how to declare SwiftData structure capabilities
- **REQ-13.3.4**: Include guide for creating provider-specific configuration UI
- **REQ-13.3.5**: Explain provider registration and lifecycle
- **REQ-13.3.6**: Document versioning and backward compatibility considerations

#### 13.4 Custom Data Type Guide
- **REQ-13.4.1**: Create dedicated guide: "Supporting New Data Types"
  - How to extend type system
  - SwiftData model patterns for custom types
  - Serialization/deserialization requirements
  - UI component recommendations
- **REQ-13.4.2**: Provide examples for common custom types:
  - 3D models
  - Complex structured data
  - Multi-modal outputs
  - Streaming data
- **REQ-13.4.3**: Document constraint system for custom types
- **REQ-13.4.4**: Explain validation and transformation pipelines

#### 13.5 Code Examples and Templates
- **REQ-13.5.1**: Include complete, working example providers for:
  - Text generation service
  - Audio generation service
  - Image generation service
  - Multi-modal service
- **REQ-13.5.2**: Provide starter templates with TODO comments:
  - `ProviderTemplate.swift` - Skeleton provider implementation
  - `DataTypeTemplate.swift` - Custom data type structure
  - `ConfigPanelTemplate.swift` - SwiftUI configuration view
  - `TestsTemplate.swift` - Unit test structure
- **REQ-13.5.3**: Include sample apps demonstrating:
  - Basic integration
  - Custom provider addition
  - Complex multi-provider workflow
  - SwiftData model customization
- **REQ-13.5.4**: Provide migration guides for upgrading between versions

#### 13.6 API Reference Documentation
- **REQ-13.6.1**: Generate comprehensive API documentation using DocC
- **REQ-13.6.2**: Document all public protocols, classes, and methods
- **REQ-13.6.3**: Include code snippets in API documentation
- **REQ-13.6.4**: Provide "See Also" references between related APIs
- **REQ-13.6.5**: Document parameter constraints and return value expectations
- **REQ-13.6.6**: Include common pitfalls and best practices in documentation

#### 13.7 Architecture Documentation
- **REQ-13.7.1**: Provide architecture overview diagram
- **REQ-13.7.2**: Explain component relationships and data flow
- **REQ-13.7.3**: Document design patterns used throughout the framework
- **REQ-13.7.4**: Explain extension points and plugin architecture
- **REQ-13.7.5**: Document threading and concurrency model
- **REQ-13.7.6**: Explain SwiftData integration architecture

#### 13.8 Interactive Documentation
- **REQ-13.8.1**: Provide interactive Swift Playgrounds for learning the API
- **REQ-13.8.2**: Include DocC tutorial with multiple articles
- **REQ-13.8.3**: Create video tutorials for common tasks
- **REQ-13.8.4**: Maintain up-to-date FAQ based on community questions

#### 13.9 Documentation Standards
- **REQ-13.9.1**: All public APIs must have documentation comments
- **REQ-13.9.2**: All examples must be tested and verified to work
- **REQ-13.9.3**: Documentation must be updated in same PR as code changes
- **REQ-13.9.4**: Maintain documentation versioning aligned with releases
- **REQ-13.9.5**: Use consistent terminology throughout all documentation

### 14. Contribution Process and GitHub Artifacts

#### 14.1 Contribution Documentation
- **REQ-14.1.1**: Provide comprehensive `CONTRIBUTING.md` file with:
  - Getting started guide for contributors
  - Development environment setup instructions
  - Code style guidelines and conventions
  - Testing requirements and procedures
  - Pull request process and expectations
  - Review criteria and timelines
- **REQ-14.1.2**: Include `CODE_OF_CONDUCT.md` establishing community standards
- **REQ-14.1.3**: Create provider implementation checklist for contributors
- **REQ-14.1.4**: Document git workflow (branching strategy, commit message format)
- **REQ-14.1.5**: Provide contribution quick-start guide for AI code builders

#### 14.2 GitHub Issue Templates
- **REQ-14.2.1**: Create issue template for bug reports including:
  - Swift/Xcode version
  - Platform and OS version
  - Steps to reproduce
  - Expected vs actual behavior
  - Code sample demonstrating issue
  - Error messages and logs
- **REQ-14.2.2**: Create issue template for feature requests including:
  - Use case description
  - Proposed solution
  - Alternative approaches considered
  - Breaking change assessment
- **REQ-14.2.3**: Create issue template for new provider proposals including:
  - Provider service details
  - Capabilities to be supported
  - API documentation links
  - Authentication requirements
  - Volunteer status (who will implement)
- **REQ-14.2.4**: Create issue template for documentation improvements
- **REQ-14.2.5**: Create issue template for AI code builder issues

#### 14.3 GitHub Pull Request Templates
- **REQ-14.3.1**: Create PR template for new providers including:
  - Provider name and description
  - Checklist of required protocol implementations
  - Configuration UI screenshot/demo
  - Test coverage verification
  - Documentation updates
  - Breaking changes assessment
- **REQ-14.3.2**: Create PR template for general changes including:
  - Summary of changes
  - Related issues
  - Testing performed
  - Documentation updates
  - Breaking changes checklist
- **REQ-14.3.3**: Create PR template for documentation-only changes
- **REQ-14.3.4**: Auto-assign reviewers based on changed files

#### 14.4 GitHub Actions and CI/CD
- **REQ-14.4.1**: Automated test suite runs on all PRs
- **REQ-14.4.2**: Swift 6.0 strict concurrency checking in CI
- **REQ-14.4.3**: Code coverage reporting on PRs
- **REQ-14.4.4**: Automated documentation generation and deployment
- **REQ-14.4.5**: Automated linting and code style checking
- **REQ-14.4.6**: Matrix testing across supported platforms (iOS, macOS)
- **REQ-14.4.7**: Security scanning for dependencies
- **REQ-14.4.8**: Automated example app building and testing
- **REQ-14.4.9**: PR size checking with warnings for large PRs
- **REQ-14.4.10**: Automated labeling based on changed files

#### 14.5 Repository Labels
- **REQ-14.5.1**: Standard labels for issue categorization:
  - `bug`, `feature`, `documentation`, `enhancement`
  - `provider: new`, `provider: enhancement`
  - `good first issue`, `help wanted`
  - `breaking change`, `needs discussion`
  - `ai-friendly` - Issues suitable for AI code builders
- **REQ-14.5.2**: Priority labels: `priority: high`, `priority: medium`, `priority: low`
- **REQ-14.5.3**: Status labels: `in progress`, `needs review`, `blocked`
- **REQ-14.5.4**: Provider-specific labels: `provider: openai`, `provider: anthropic`, etc.

#### 14.6 Branch Protection and Review Requirements
- **REQ-14.6.1**: Require at least one approval before merging
- **REQ-14.6.2**: Require passing CI checks before merge
- **REQ-14.6.3**: Require up-to-date branches before merge
- **REQ-14.6.4**: Prevent force pushes to `main` branch
- **REQ-14.6.5**: Require signed commits (optional but recommended)

#### 14.7 Release Process
- **REQ-14.7.1**: Document semantic versioning strategy
- **REQ-14.7.2**: Maintain `CHANGELOG.md` with all notable changes
- **REQ-14.7.3**: Create GitHub releases with release notes
- **REQ-14.7.4**: Tag releases following semver (e.g., `v2.0.0`)
- **REQ-14.7.5**: Automated release notes generation from commits/PRs
- **REQ-14.7.6**: Migration guides for major version updates

#### 14.8 Community Management
- **REQ-14.8.1**: Enable GitHub Discussions for:
  - General questions and help
  - Provider implementation discussions
  - Feature brainstorming
  - Show and tell (community projects)
- **REQ-14.8.2**: Create discussion categories:
  - Q&A, Ideas, Show and Tell, Announcements, Provider Development
- **REQ-14.8.3**: Pin important discussions (getting started, roadmap, etc.)
- **REQ-14.8.4**: Provide issue triage guidelines for maintainers
- **REQ-14.8.5**: Document maintainer response time expectations

#### 14.9 Provider Registry
- **REQ-14.9.1**: Maintain `PROVIDERS.md` listing all supported providers
- **REQ-14.9.2**: Include provider status: official, community, experimental
- **REQ-14.9.3**: Link to provider-specific documentation
- **REQ-14.9.4**: Track provider maintainers and contributors
- **REQ-14.9.5**: Document provider deprecation process

#### 14.10 Templates Directory Structure
- **REQ-14.10.1**: Provide `/Templates` directory containing:
  - `ProviderTemplate.swift` - Annotated provider implementation
  - `DataTypeTemplate.swift` - Custom data type template
  - `ConfigPanelTemplate.swift` - SwiftUI configuration view
  - `TestsTemplate.swift` - Test suite structure
  - `README.md` - Instructions for using templates
- **REQ-14.10.2**: Templates must include:
  - Clear TODO markers for required implementations
  - Inline documentation explaining each section
  - Example implementations for common scenarios
  - Links to relevant documentation

---

## Default Provider Implementations

The following providers are **required** to be included as default implementations bundled with the library. Each provider must include its own settings panel conforming to the `AIServiceConfigurationView` protocol.

### Required Default Providers

#### Apple Intelligence
- **Provider ID**: `apple-intelligence`
- **Display Name**: Apple Intelligence
- **Capabilities**: Text generation, text summarization, writing tools integration
- **API Key Required**: No (system-level integration)
- **Platform Availability**: iOS 26+, macOS 26+
- **Settings Panel Requirements**:
  - Model selection (when applicable)
  - Privacy settings (on-device vs cloud)
  - Writing tools preferences
  - System integration toggles

#### OpenAI
- **Provider ID**: `openai`
- **Display Name**: OpenAI
- **Capabilities**: Text generation (GPT-4, GPT-3.5), text-to-speech, speech-to-text, image generation (DALL-E), embeddings, structured outputs
- **API Key Required**: Yes
- **Platform Availability**: iOS 26+, macOS 26+
- **Settings Panel Requirements**:
  - API key management (secure input)
  - Model selection dropdown (GPT-4, GPT-3.5-turbo, etc.)
  - Organization ID (optional)
  - Default parameters (temperature, max tokens, top_p)
  - API base URL override (for compatible services)
  - Test connection button

#### Anthropic
- **Provider ID**: `anthropic`
- **Display Name**: Anthropic
- **Capabilities**: Text generation (Claude models), structured outputs, tool use/function calling, vision
- **API Key Required**: Yes
- **Platform Availability**: iOS 26+, macOS 26+
- **Settings Panel Requirements**:
  - API key management (secure input)
  - Model selection (Claude 3.5 Sonnet, Claude 3 Opus, etc.)
  - Default parameters (temperature, max tokens, top_p, top_k)
  - System prompt configuration
  - Test connection button

#### ElevenLabs
- **Provider ID**: `elevenlabs`
- **Display Name**: ElevenLabs
- **Capabilities**: Text-to-speech, voice cloning, speech-to-speech
- **API Key Required**: Yes
- **Platform Availability**: iOS 26+, macOS 26+
- **Settings Panel Requirements**:
  - API key management (secure input)
  - Voice picker with preview playback
  - Voice settings (stability, similarity boost, style)
  - Model selection (multilingual, turbo, etc.)
  - Audio format selection (mp3, pcm)
  - Usage quota display
  - Test voice button with sample text

### Additional Providers (Optional/Future)

The following providers may be included in later releases or as optional plugins:

#### Text Generation
- **Google AI** (Gemini)
- **Local models** (via Ollama or similar)
- **Mistral AI**
- **Cohere**

#### Image Generation
- **Stability AI** (Stable Diffusion)
- **Midjourney** (when API available)
- **Replicate** (various models)

#### Audio Generation
- **Apple AVSpeechSynthesizer** (built-in TTS fallback)

### Provider Settings Panel Requirements

All default providers must implement:

- **REQ-PROVIDER-1**: Conform to `AIServiceConfigurationView` protocol
- **REQ-PROVIDER-2**: Provide consistent visual design following Apple's Human Interface Guidelines
- **REQ-PROVIDER-3**: Include form validation with inline error messages
- **REQ-PROVIDER-4**: Support real-time validation of API keys and credentials
- **REQ-PROVIDER-5**: Display connection status indicator (connected, disconnected, error)
- **REQ-PROVIDER-6**: Provide "Test Connection" functionality to verify configuration
- **REQ-PROVIDER-7**: Show provider-specific documentation links
- **REQ-PROVIDER-8**: Support light and dark mode
- **REQ-PROVIDER-9**: Include accessibility labels and VoiceOver support
- **REQ-PROVIDER-10**: Handle loading states during validation/testing

---

## Usage Example (Conceptual)

```swift
import SwiftHablare
import SwiftData

// Initialize the service manager
let manager = AIServiceManager(modelContext: modelContext)

// Configure a provider (stored securely)
try await manager.configureProvider(
    id: "openai",
    credentials: ["api_key": "sk-..."]
)

// Define the expected response model
@Model
class GeneratedStory {
    var title: String = ""
    var content: String = ""
    var genre: String = ""
    var generatedAt: Date = Date()
    var provider: String = ""
}

// Make a request with automatic persistence
let story = try await manager.generate(
    provider: "openai",
    prompt: "Write a short sci-fi story about AI",
    responseModel: GeneratedStory.self,
    parameters: [
        "model": "gpt-4",
        "temperature": 0.7,
        "max_tokens": 1000
    ]
)

// The story is automatically saved to SwiftData
print(story.title)
print(story.content)

// Query stored responses
let allStories = try modelContext.fetch(
    FetchDescriptor<GeneratedStory>(
        sortBy: [SortDescriptor(\.generatedAt, order: .reverse)]
    )
)
```

### Field-Level UI Integration Example

```swift
import SwiftUI
import SwiftHablare
import SwiftData

struct ProductDescriptionForm: View {
    @Bindable var product: Product
    @Environment(AIServiceManager.self) private var aiManager

    var body: some View {
        Form {
            TextField("Product Name", text: $product.name)

            // AI-generated description field with inline state
            VStack(alignment: .leading, spacing: 8) {
                Text("Description")
                    .font(.headline)

                TextEditor(text: $product.description)
                    .frame(minHeight: 100)
                    .aiGenerated(
                        manager: aiManager,
                        provider: "openai",
                        prompt: "Write a compelling product description for: \(product.name)",
                        field: $product.description
                    )
            }

            // The .aiGenerated modifier handles:
            // - Shows spinner overlay during generation
            // - Updates field when response arrives
            // - Displays inline error if request fails
            // - Allows user to cancel/retry
        }
    }
}

// Alternative approach with explicit state management
struct AdvancedProductForm: View {
    @Bindable var product: Product
    @State private var generationState: AIGenerationState<String> = .idle

    var body: some View {
        Form {
            TextField("Product Name", text: $product.name)

            AIGeneratedTextField(
                prompt: "Write a description for: \(product.name)",
                value: $product.description,
                state: $generationState,
                provider: "openai",
                parameters: [
                    "model": "gpt-4",
                    "temperature": 0.7
                ]
            )

            // Display generation metadata
            switch generationState {
            case .idle:
                EmptyView()
            case .generating(let provider, let startTime):
                HStack {
                    ProgressView()
                    Text("Generating with \(provider)...")
                    Text("(\(Date().timeIntervalSince(startTime), specifier: "%.1f")s)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            case .success(let value, let metadata):
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Generated in \(metadata.duration, specifier: "%.1f")s")
                        .font(.caption)
                    if let cost = metadata.cost {
                        Text("($\(cost, specifier: "%.4f"))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            case .error(let error):
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.red)
                    Button("Retry") {
                        Task {
                            await retryGeneration()
                        }
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                }
            }
        }
    }

    private func retryGeneration() async {
        // Retry logic
    }
}

// Custom view modifier for AI generation
extension View {
    func aiGenerated<T>(
        manager: AIServiceManager,
        provider: String,
        prompt: String,
        field: Binding<T>
    ) -> some View {
        self.modifier(
            AIGenerationModifier(
                manager: manager,
                provider: provider,
                prompt: prompt,
                field: field
            )
        )
    }
}
```

### Declarative SwiftData Structure Definition Example

```swift
import SwiftHablare
import SwiftData

// EXAMPLE 1: Provider declares which SwiftData structures it supports

class OpenAIProvider: AIServiceProvider {
    var id: String { "openai" }
    var displayName: String { "OpenAI" }

    // Declarative capability registration
    var supportedDataStructures: [DataStructureCapability] {
        [
            // Register capability to generate Product descriptions
            .model(Product.self, properties: [
                .property(\.description,
                    constraints: .init(minLength: 50, maxLength: 500)),
                .property(\.marketingCopy,
                    constraints: .init(tone: "professional"))
            ]),

            // Register capability to generate BlogPost content
            .model(BlogPost.self, properties: [
                .property(\.title,
                    constraints: .init(maxLength: 100)),
                .property(\.content,
                    constraints: .init(minLength: 500)),
                .property(\.excerpt,
                    constraints: .init(maxLength: 200))
            ]),

            // Register capability for any model conforming to AIGeneratable
            .protocol(AIGeneratable.self, typeConstraints: [
                .canGenerate(.string),
                .canGenerate(.data),
                .canGenerate(.url)
            ])
        ]
    }

    // Implementation of data generation
    func generate<T: PersistentModel>(
        for model: T,
        property: PartialKeyPath<T>,
        prompt: String,
        context: ModelContext
    ) async throws -> Any {
        // Provider-specific logic to generate data
        // Returns value that will be written to the specified property
    }
}

// EXAMPLE 2: SwiftData model declares AI-generation support

@Model
class Product: AIGeneratable {
    var name: String = ""
    var description: String = ""
    var marketingCopy: String = ""
    var price: Decimal = 0

    // Declarative AI generation metadata
    static var aiGenerationSchema: AIGenerationSchema {
        AIGenerationSchema {
            // Description can be generated by text providers
            AIProperty(\.description)
                .providers(["openai", "anthropic", "google-ai"])
                .constraints(minLength: 50, maxLength: 500)
                .promptTemplate("Write a product description for {name}")
                .required()

            // Marketing copy can be generated by text providers
            AIProperty(\.marketingCopy)
                .providers(["openai", "anthropic"])
                .constraints(tone: "persuasive", maxLength: 300)
                .promptTemplate("Write marketing copy for {name}: {description}")
                .optional()

            // Name and price are NOT AI-generated (not declared)
        }
    }
}

@Model
class VoiceNarration: AIGeneratable {
    var scriptText: String = ""
    var audioData: Data?
    var audioURL: URL?
    var duration: TimeInterval = 0

    static var aiGenerationSchema: AIGenerationSchema {
        AIGenerationSchema {
            // Script can be generated by text providers
            AIProperty(\.scriptText)
                .providers(["openai", "anthropic"])
                .constraints(minLength: 100, maxLength: 2000)

            // Audio can be generated by TTS providers
            AIProperty(\.audioData)
                .providers(["elevenlabs", "apple-intelligence"])
                .inputProperty(\.scriptText) // Uses scriptText as input
                .constraints(format: "mp3", sampleRate: 44100)
                .resultTransform { data, model in
                    // Custom logic when audio is generated
                    model.duration = try extractAudioDuration(from: data)
                    return data
                }

            // Audio URL is computed from audioData (not directly generated)
        }
    }
}

// EXAMPLE 3: Protocol-based generation support

protocol AIGeneratable: PersistentModel {
    static var aiGenerationSchema: AIGenerationSchema { get }
}

// EXAMPLE 4: Using the declarative system

let manager = AIServiceManager(modelContext: modelContext)

// Create a product
let product = Product()
product.name = "Smart Coffee Maker Pro"

// Generate description using declared schema
try await manager.generateProperty(
    for: product,
    property: \.description,
    context: [
        "name": product.name,
        "category": "Kitchen Appliances"
    ]
)
// The framework:
// 1. Checks Product.aiGenerationSchema for \.description
// 2. Finds allowed providers: ["openai", "anthropic", "google-ai"]
// 3. Uses the promptTemplate with substituted values
// 4. Validates constraints (50-500 chars)
// 5. Writes result to product.description
// 6. Saves to SwiftData

// Generate marketing copy
try await manager.generateProperty(
    for: product,
    property: \.marketingCopy
)

// Generate audio narration in two steps
let narration = VoiceNarration()

// Step 1: Generate script
try await manager.generateProperty(
    for: narration,
    property: \.scriptText,
    prompt: "Write a 30-second radio ad script for \(product.name)"
)

// Step 2: Generate audio from script (uses scriptText as input)
try await manager.generateProperty(
    for: narration,
    property: \.audioData
)
// The framework knows to use narration.scriptText as input

// EXAMPLE 5: Validation before generation

// This would fail at compile-time or runtime validation
try await manager.generateProperty(
    for: product,
    property: \.price // ERROR: price is not in aiGenerationSchema
)

// This would fail if provider doesn't support the model
let unsupportedProvider = CustomProvider() // Doesn't declare Product support
try await manager.generateProperty(
    for: product,
    property: \.description,
    provider: unsupportedProvider // ERROR: Provider can't generate Product.description
)

// EXAMPLE 6: Batch generation with schema

try await manager.generateAllProperties(
    for: product,
    using: ["openai"] // Only use OpenAI provider
)
// Generates all declared AI properties: description and marketingCopy

// EXAMPLE 7: Provider queries based on capability

// Find providers that can generate Product descriptions
let capableProviders = manager.providersCapable(
    of: Product.self,
    property: \.description
)
// Returns: ["openai", "anthropic", "google-ai"]

// Find providers that can generate audio
let audioProviders = manager.providersCapable(ofType: Data.self)
    .filter { $0.supports(format: "audio/mpeg") }
// Returns: ["elevenlabs", "apple-intelligence"]
```

---

## Future Considerations

The following features are out of scope for the initial release but should be considered for future versions:

### Feature Enhancements
1. **Cost Tracking**: Track API usage costs across providers
2. **Response Comparison**: Compare outputs from multiple providers for the same prompt
3. **Fine-tuning Management**: Support for managing fine-tuned models
4. **Collaborative Features**: Share prompts and responses across devices via CloudKit
5. **Analytics Dashboard**: Visualize usage patterns and response quality
6. **Prompt Library**: Built-in collection of useful prompts
7. **Version Control**: Track changes to prompts and responses over time
8. **Export/Import**: Backup and restore generated content
9. **Multi-modal Requests**: Single requests that combine multiple data types
10. **Workflow Automation**: Chain multiple AI requests together

### Documentation Enhancements
11. **AI-Powered Documentation Assistant**: Chatbot trained on framework documentation to help developers
12. **Code Generation CLI**: Command-line tool to scaffold new providers from templates
13. **Visual Provider Builder**: GUI tool for creating providers without writing code
14. **Community Provider Registry**: Centralized repository of third-party providers
15. **Automated Documentation Testing**: Verify all documentation code examples compile and run
16. **Multi-language Documentation**: Translate documentation to other languages
17. **Video Tutorial Series**: Comprehensive video course on framework usage and extension
18. **Interactive API Explorer**: Web-based tool to test provider implementations

---

## Success Criteria

The library will be considered successful if:

### Core Functionality
1. Developers can add support for a new AI provider in under 100 lines of code
2. Making a request and persisting the result requires fewer than 10 lines of code
3. The configuration UI can be integrated into an app with a single SwiftUI view
4. API keys are stored securely with zero-configuration required from developers
5. The library supports at least 4 different AI service providers
6. All core functionality has automated tests
7. The library can be integrated into an existing SwiftData app without conflicts

### Documentation and Extensibility
8. Complete documentation and example projects are available
9. **AI code builders (Claude, ChatGPT, etc.) can successfully create working provider implementations from documentation alone**
10. **Template files enable 80%+ code generation for new providers**
11. **Documentation includes runnable examples that pass CI tests**
12. **Extension points are discoverable through inline documentation and DocC**

### Contribution Process
13. **CONTRIBUTING.md provides clear, actionable guidance for all contribution types**
14. **Issue and PR templates streamline the contribution workflow**
15. **CI/CD pipeline catches issues before merge (tests, linting, coverage)**
16. **First-time contributors can successfully add a provider using templates and documentation**
17. **AI-generated contributions meet quality standards with minimal human intervention**
18. **Community members can discover and contribute to "good first issue" tasks**

---

## Migration Path from Current Implementation

Since SwiftHablare currently focuses on TTS, the migration should:

1. Extract and generalize the provider protocol concept
2. Rename `VoiceProvider` → `AIServiceProvider`
3. Extract audio-specific logic into an `AudioGenerationProvider` subprotocol
4. Generalize the configuration UI system to support any provider type
5. Maintain backward compatibility for existing TTS functionality
6. Gradually expand to support text and image generation providers
7. Update documentation to reflect the broader scope

---

## Version History

- **v2.0.0** (Planned): Complete rewrite as general AI service integration library
- **v1.x.x** (Current): Text-to-speech focused library with Apple and ElevenLabs support
