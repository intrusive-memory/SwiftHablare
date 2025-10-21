# Phase 6: API Requestor Protocol Interface

**Status**: ✅ DEFINED
**Date**: 2025-10-12
**Priority**: 🔴 CRITICAL
**Requirement**: Resolves PHASE_6_PRE_IMPLEMENTATION_CHECKLIST.md Requirement #1

---

## Overview

The **API Requestor Protocol** defines a standardized interface for requesting typed data from AI providers. This protocol enables a single AI service provider to offer multiple specialized requestors, each returning a specific file type.

### Key Principles

1. **One Requestor = One File Type**: Each requestor generates exactly one type of file
2. **Multiple Requestors per Provider**: A provider can offer many requestors (e.g., ChatGPT offers text, image, audio requestors)
3. **Type-Specific Configuration**: Each requestor has its own configuration widget
4. **Isolated Storage**: Each request gets its own storage area via TypedDataBroker

---

## Protocol Definition

```swift
/// Protocol that all API requestors must conform to.
///
/// An API Requestor is a specialized interface for requesting a specific type
/// of generated content from an AI provider. Providers can implement multiple
/// requestors to support different output types.
///
/// ## Example
/// ```swift
/// // OpenAI provider offers multiple requestors
/// class OpenAITextRequestor: AIRequestor {
///     typealias TypedData = GeneratedText
///     typealias ResponseModel = GeneratedTextRecord
///     // ... implementation
/// }
///
/// class OpenAIImageRequestor: AIRequestor {
///     typealias TypedData = GeneratedImage
///     typealias ResponseModel = GeneratedImageRecord
///     // ... implementation
/// }
/// ```
public protocol AIRequestor: Sendable {

    // MARK: - Associated Types

    /// The Swift Codable type representing the generated data structure.
    associatedtype TypedData: Codable & Sendable

    /// The SwiftData model used to persist this requestor's responses.
    associatedtype ResponseModel: AIGeneratedContent

    /// The configuration type for this requestor's parameters.
    associatedtype Configuration: Codable & Sendable

    // MARK: - Identity

    /// Unique identifier for this requestor.
    ///
    /// Format: "{providerID}.{category}.{variant}"
    /// Examples: "openai.text.gpt4", "openai.image.dalle3", "elevenlabs.audio.tts"
    var requestorID: String { get }

    /// Human-readable display name.
    var displayName: String { get }

    /// The provider that offers this requestor.
    var providerID: String { get }

    /// The category of content this requestor generates.
    var category: ProviderCategory { get }

    // MARK: - Capabilities

    /// File type information for the generated content.
    var outputFileType: OutputFileType { get }

    /// Optional schema for validation (future use).
    var schema: TypedDataSchema? { get }

    /// Maximum expected response size in bytes (for storage planning).
    var estimatedMaxSize: Int64? { get }

    // MARK: - Configuration

    /// Default configuration for this requestor.
    func defaultConfiguration() -> Configuration

    /// Validates a configuration without making a request.
    func validateConfiguration(_ config: Configuration) throws

    // MARK: - Request Execution

    /// Generates typed data based on a prompt and configuration.
    ///
    /// This method is called by AIRequestManager in a background context.
    /// The storage area is provided for writing large files during generation.
    ///
    /// - Parameters:
    ///   - prompt: The input prompt for generation
    ///   - configuration: Requestor-specific configuration
    ///   - storageArea: Request-specific storage area for file writes
    /// - Returns: Result containing either TypedData or error
    func request(
        prompt: String,
        configuration: Configuration,
        storageArea: StorageAreaReference
    ) async -> Result<TypedData, AIServiceError>

    // MARK: - Response Processing

    /// Creates a SwiftData response model from typed data.
    ///
    /// Called on the main actor by AIDataCoordinator after successful generation.
    ///
    /// - Parameters:
    ///   - data: The typed data returned from request
    ///   - fileReference: Optional file reference if data was written to storage
    ///   - requestID: The UUID of the request
    /// - Returns: A populated ResponseModel ready for persistence
    @MainActor
    func makeResponseModel(
        from data: TypedData,
        fileReference: TypedDataFileReference?,
        requestID: UUID
    ) -> ResponseModel

    // MARK: - UI Components (Phase 7)

    /// Creates a configuration widget for this requestor (SwiftUI).
    ///
    /// This will be implemented in Phase 7, but defined here for completeness.
    @MainActor
    func makeConfigurationView(
        configuration: Binding<Configuration>
    ) -> AnyView

    /// Creates a list item view for displaying a response.
    @MainActor
    func makeListItemView(model: ResponseModel) -> AnyView

    /// Creates a detail view for a response.
    @MainActor
    func makeDetailView(model: ResponseModel) -> AnyView
}
```

---

## Supporting Types

### ProviderCategory

```swift
/// Categories of AI-generated content.
public enum ProviderCategory: String, Codable, Sendable {
    case text
    case image
    case audio
    case video
    case structuredData
    case embedding
    case code

    var displayName: String {
        switch self {
        case .text: return "Text"
        case .image: return "Image"
        case .audio: return "Audio"
        case .video: return "Video"
        case .structuredData: return "Structured Data"
        case .embedding: return "Embedding"
        case .code: return "Code"
        }
    }
}
```

### OutputFileType

```swift
/// Describes the file type generated by a requestor.
public struct OutputFileType: Codable, Sendable {
    /// MIME type (e.g., "image/png", "audio/mpeg", "text/plain")
    let mimeType: String

    /// File extension without dot (e.g., "png", "mp3", "txt")
    let fileExtension: String

    /// Human-readable description
    let description: String

    /// Whether this type is typically stored as a file (vs in-memory)
    let preferFileStorage: Bool

    // Common types
    static let png = OutputFileType(
        mimeType: "image/png",
        fileExtension: "png",
        description: "PNG Image",
        preferFileStorage: true
    )

    static let mp3 = OutputFileType(
        mimeType: "audio/mpeg",
        fileExtension: "mp3",
        description: "MP3 Audio",
        preferFileStorage: true
    )

    static let plainText = OutputFileType(
        mimeType: "text/plain",
        fileExtension: "txt",
        description: "Plain Text",
        preferFileStorage: false
    )

    static let json = OutputFileType(
        mimeType: "application/json",
        fileExtension: "json",
        description: "JSON Data",
        preferFileStorage: false
    )
}
```

### TypedDataSchema

```swift
/// Protocol for typed data validation schemas.
///
/// Phase 6: Swift Codable only
/// Phase 7+: May add JSON Schema support
public protocol TypedDataSchema: Sendable {
    associatedtype DataType: Codable & Sendable

    /// Schema version for migration support
    var version: String { get }

    /// Validates data conforms to this schema
    func validate(_ data: Any) throws -> DataType
}

/// Default schema using Swift Codable type constraints
public struct CodableSchema<T: Codable & Sendable>: TypedDataSchema {
    public typealias DataType = T

    public let version: String

    public init(version: String = "1.0") {
        self.version = version
    }

    public func validate(_ data: Any) throws -> T {
        // Attempt to decode from data
        if let typedData = data as? T {
            return typedData
        }

        // If data is raw Data, attempt JSON decode
        if let rawData = data as? Data {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: rawData)
        }

        throw AIServiceError.dataConversionError(
            "Cannot validate data as \(T.self)"
        )
    }
}
```

---

## Relationship to AIServiceProvider

### Provider Offers Multiple Requestors

```swift
/// Extension to AIServiceProvider for requestor discovery
public extension AIServiceProvider {

    /// Returns all requestors offered by this provider.
    ///
    /// Providers implement this to expose their available requestors.
    /// Each requestor represents a distinct content type the provider can generate.
    func availableRequestors() -> [any AIRequestor] {
        // Default implementation returns empty
        // Providers override to return their requestors
        return []
    }

    /// Finds a requestor by ID.
    func requestor(withID requestorID: String) -> (any AIRequestor)? {
        availableRequestors().first { $0.requestorID == requestorID }
    }

    /// Returns all requestors for a specific category.
    func requestors(for category: ProviderCategory) -> [any AIRequestor] {
        availableRequestors().filter { $0.category == category }
    }
}
```

### Example: OpenAI Provider

```swift
public class OpenAIProvider: AIServiceProvider {
    public let id = "openai"
    public let displayName = "OpenAI"

    // Existing AIServiceProvider properties...

    /// OpenAI offers multiple requestors
    public func availableRequestors() -> [any AIRequestor] {
        return [
            OpenAITextRequestor(provider: self, model: .gpt4),
            OpenAITextRequestor(provider: self, model: .gpt35Turbo),
            OpenAIImageRequestor(provider: self, model: .dalle3),
            OpenAIImageRequestor(provider: self, model: .dalle2),
            OpenAIEmbeddingRequestor(provider: self)
        ]
    }
}
```

---

## Example Implementations

### Text Requestor

```swift
public struct GeneratedText: Codable, Sendable {
    let text: String
    let wordCount: Int
    let characterCount: Int
    let languageCode: String?
    let model: String
    let tokenCount: Int?
}

public class OpenAITextRequestor: AIRequestor {
    public typealias TypedData = GeneratedText
    public typealias ResponseModel = GeneratedTextRecord
    public typealias Configuration = TextGenerationConfig

    public let requestorID: String
    public let displayName: String
    public let providerID = "openai"
    public let category: ProviderCategory = .text

    public let outputFileType = OutputFileType.plainText
    public let schema: TypedDataSchema? = CodableSchema<GeneratedText>()
    public let estimatedMaxSize: Int64? = 1_000_000 // ~1MB

    private let provider: OpenAIProvider
    private let model: GPTModel

    init(provider: OpenAIProvider, model: GPTModel) {
        self.provider = provider
        self.model = model
        self.requestorID = "openai.text.\(model.rawValue)"
        self.displayName = "OpenAI \(model.displayName) Text"
    }

    public func defaultConfiguration() -> TextGenerationConfig {
        return TextGenerationConfig(
            temperature: 0.7,
            maxTokens: 2048,
            topP: 1.0,
            frequencyPenalty: 0.0,
            presencePenalty: 0.0
        )
    }

    public func validateConfiguration(_ config: TextGenerationConfig) throws {
        guard config.temperature >= 0 && config.temperature <= 2 else {
            throw AIServiceError.configurationError("Temperature must be between 0 and 2")
        }
        guard config.maxTokens > 0 && config.maxTokens <= 4096 else {
            throw AIServiceError.configurationError("Max tokens must be between 1 and 4096")
        }
    }

    public func request(
        prompt: String,
        configuration: TextGenerationConfig,
        storageArea: StorageAreaReference
    ) async -> Result<GeneratedText, AIServiceError> {
        // Make API call to OpenAI
        do {
            let response = try await provider.chatCompletion(
                messages: [.user(prompt)],
                model: model.apiModel,
                temperature: configuration.temperature,
                maxTokens: configuration.maxTokens
            )

            let text = response.choices.first?.message.content ?? ""
            let typedData = GeneratedText(
                text: text,
                wordCount: text.split(separator: " ").count,
                characterCount: text.count,
                languageCode: "en",
                model: model.rawValue,
                tokenCount: response.usage?.totalTokens
            )

            return .success(typedData)

        } catch {
            return .failure(.networkError(error.localizedDescription))
        }
    }

    @MainActor
    public func makeResponseModel(
        from data: GeneratedText,
        fileReference: TypedDataFileReference?,
        requestID: UUID
    ) -> GeneratedTextRecord {
        return GeneratedTextRecord(
            id: requestID,
            providerId: providerID,
            requestorID: requestorID,
            text: data.text,
            wordCount: data.wordCount,
            characterCount: data.characterCount,
            languageCode: data.languageCode,
            modelIdentifier: data.model,
            tokenCount: data.tokenCount,
            fileReference: fileReference
        )
    }

    // UI methods to be implemented in Phase 7
    @MainActor
    public func makeConfigurationView(configuration: Binding<TextGenerationConfig>) -> AnyView {
        AnyView(TextGenerationConfigView(configuration: configuration))
    }

    @MainActor
    public func makeListItemView(model: GeneratedTextRecord) -> AnyView {
        AnyView(TextListItemView(record: model))
    }

    @MainActor
    public func makeDetailView(model: GeneratedTextRecord) -> AnyView {
        AnyView(TextDetailView(record: model))
    }
}

public struct TextGenerationConfig: Codable, Sendable {
    var temperature: Double
    var maxTokens: Int
    var topP: Double
    var frequencyPenalty: Double
    var presencePenalty: Double
}
```

### Image Requestor

```swift
public struct GeneratedImage: Codable, Sendable {
    let imageData: Data?           // May be nil if file-based storage
    let width: Int
    let height: Int
    let format: String
    let model: String
    let prompt: String
    let revisedPrompt: String?
}

public class OpenAIImageRequestor: AIRequestor {
    public typealias TypedData = GeneratedImage
    public typealias ResponseModel = GeneratedImageRecord
    public typealias Configuration = ImageGenerationConfig

    public let requestorID: String
    public let displayName: String
    public let providerID = "openai"
    public let category: ProviderCategory = .image

    public let outputFileType = OutputFileType.png
    public let schema: TypedDataSchema? = CodableSchema<GeneratedImage>()
    public let estimatedMaxSize: Int64? = 10_000_000 // ~10MB

    private let provider: OpenAIProvider
    private let model: DalleModel

    init(provider: OpenAIProvider, model: DalleModel) {
        self.provider = provider
        self.model = model
        self.requestorID = "openai.image.\(model.rawValue)"
        self.displayName = "OpenAI \(model.displayName)"
    }

    public func defaultConfiguration() -> ImageGenerationConfig {
        return ImageGenerationConfig(
            size: .large1024,
            quality: .standard,
            style: .vivid
        )
    }

    public func validateConfiguration(_ config: ImageGenerationConfig) throws {
        // Validation based on model capabilities
        if model == .dalle2 && config.quality == .hd {
            throw AIServiceError.configurationError("DALL-E 2 does not support HD quality")
        }
    }

    public func request(
        prompt: String,
        configuration: ImageGenerationConfig,
        storageArea: StorageAreaReference
    ) async -> Result<GeneratedImage, AIServiceError> {
        do {
            // Make API call to OpenAI
            let response = try await provider.createImage(
                prompt: prompt,
                model: model.apiModel,
                size: configuration.size.apiValue,
                quality: configuration.quality.apiValue,
                style: configuration.style?.apiValue
            )

            guard let imageURLString = response.data.first?.url,
                  let imageURL = URL(string: imageURLString) else {
                return .failure(.unexpectedResponseFormat("No image URL in response"))
            }

            // Download image data
            let (data, _) = try await URLSession.shared.data(from: imageURL)

            // Write to storage area if large
            let fileReference: TypedDataFileReference?
            if data.count > 1_000_000 { // 1MB threshold
                let coordinator = TextPackCoordinator.shared
                let fileID = UUID()
                fileReference = try await coordinator.writeResource(
                    data: data,
                    withID: fileID,
                    contentType: "image/png",
                    to: storageArea
                )
            } else {
                fileReference = nil
            }

            let typedData = GeneratedImage(
                imageData: fileReference == nil ? data : nil,
                width: configuration.size.width,
                height: configuration.size.height,
                format: "png",
                model: model.rawValue,
                prompt: prompt,
                revisedPrompt: response.data.first?.revisedPrompt
            )

            return .success(typedData)

        } catch {
            return .failure(.networkError(error.localizedDescription))
        }
    }

    @MainActor
    public func makeResponseModel(
        from data: GeneratedImage,
        fileReference: TypedDataFileReference?,
        requestID: UUID
    ) -> GeneratedImageRecord {
        return GeneratedImageRecord(
            id: requestID,
            providerId: providerID,
            requestorID: requestorID,
            imageData: data.imageData,
            width: data.width,
            height: data.height,
            format: data.format,
            modelIdentifier: data.model,
            fileReference: fileReference
        )
    }

    // UI methods (Phase 7)
    @MainActor
    public func makeConfigurationView(configuration: Binding<ImageGenerationConfig>) -> AnyView {
        AnyView(ImageGenerationConfigView(configuration: configuration))
    }

    @MainActor
    public func makeListItemView(model: GeneratedImageRecord) -> AnyView {
        AnyView(ImageListItemView(record: model))
    }

    @MainActor
    public func makeDetailView(model: GeneratedImageRecord) -> AnyView {
        AnyView(ImageDetailView(record: model))
    }
}

public struct ImageGenerationConfig: Codable, Sendable {
    var size: ImageSize
    var quality: ImageQuality
    var style: ImageStyle?

    enum ImageSize: String, Codable {
        case square1024 = "1024x1024"
        case portrait1024x1792 = "1024x1792"
        case landscape1792x1024 = "1792x1024"
        case large1024 = "1024x1024"

        var width: Int {
            switch self {
            case .square1024, .portrait1024x1792, .large1024: return 1024
            case .landscape1792x1024: return 1792
            }
        }

        var height: Int {
            switch self {
            case .square1024, .large1024: return 1024
            case .portrait1024x1792: return 1792
            case .landscape1792x1024: return 1024
            }
        }

        var apiValue: String { rawValue }
    }

    enum ImageQuality: String, Codable {
        case standard
        case hd

        var apiValue: String { rawValue }
    }

    enum ImageStyle: String, Codable {
        case vivid
        case natural

        var apiValue: String { rawValue }
    }
}
```

### Audio Requestor (ElevenLabs)

```swift
public struct GeneratedAudio: Codable, Sendable {
    let audioData: Data?           // May be nil if file-based storage
    let format: String
    let durationSeconds: Double?
    let sampleRate: Int
    let voiceID: String
    let voiceName: String
    let model: String
}

public class ElevenLabsAudioRequestor: AIRequestor {
    public typealias TypedData = GeneratedAudio
    public typealias ResponseModel = GeneratedAudioRecord
    public typealias Configuration = AudioGenerationConfig

    public let requestorID = "elevenlabs.audio.tts"
    public let displayName = "ElevenLabs Text-to-Speech"
    public let providerID = "elevenlabs"
    public let category: ProviderCategory = .audio

    public let outputFileType = OutputFileType.mp3
    public let schema: TypedDataSchema? = CodableSchema<GeneratedAudio>()
    public let estimatedMaxSize: Int64? = 50_000_000 // ~50MB

    private let provider: ElevenLabsProvider

    init(provider: ElevenLabsProvider) {
        self.provider = provider
    }

    public func defaultConfiguration() -> AudioGenerationConfig {
        return AudioGenerationConfig(
            voiceID: "21m00Tcm4TlvDq8ikWAM",
            voiceName: "Rachel",
            stability: 0.5,
            similarityBoost: 0.75,
            model: "eleven_monolingual_v1"
        )
    }

    public func validateConfiguration(_ config: AudioGenerationConfig) throws {
        guard config.stability >= 0 && config.stability <= 1 else {
            throw AIServiceError.configurationError("Stability must be between 0 and 1")
        }
        guard config.similarityBoost >= 0 && config.similarityBoost <= 1 else {
            throw AIServiceError.configurationError("Similarity boost must be between 0 and 1")
        }
    }

    public func request(
        prompt: String,
        configuration: AudioGenerationConfig,
        storageArea: StorageAreaReference
    ) async -> Result<GeneratedAudio, AIServiceError> {
        do {
            // Make API call to ElevenLabs
            let audioData = try await provider.textToSpeech(
                text: prompt,
                voiceID: configuration.voiceID,
                model: configuration.model,
                stability: configuration.stability,
                similarityBoost: configuration.similarityBoost
            )

            // Audio files are typically large, write to storage
            let coordinator = TextPackCoordinator.shared
            let fileID = UUID()
            let fileReference = try await coordinator.writeResource(
                data: audioData,
                withID: fileID,
                contentType: "audio/mpeg",
                to: storageArea
            )

            let typedData = GeneratedAudio(
                audioData: nil, // Stored in file
                format: "mp3",
                durationSeconds: nil, // Could calculate from audio data
                sampleRate: 44100,
                voiceID: configuration.voiceID,
                voiceName: configuration.voiceName,
                model: configuration.model
            )

            return .success(typedData)

        } catch {
            return .failure(.networkError(error.localizedDescription))
        }
    }

    @MainActor
    public func makeResponseModel(
        from data: GeneratedAudio,
        fileReference: TypedDataFileReference?,
        requestID: UUID
    ) -> GeneratedAudioRecord {
        return GeneratedAudioRecord(
            id: requestID,
            providerId: providerID,
            requestorID: requestorID,
            audioData: data.audioData,
            format: data.format,
            durationSeconds: data.durationSeconds,
            sampleRate: data.sampleRate,
            voiceID: data.voiceID,
            voiceName: data.voiceName,
            modelIdentifier: data.model,
            fileReference: fileReference
        )
    }

    // UI methods (Phase 7)
    @MainActor
    public func makeConfigurationView(configuration: Binding<AudioGenerationConfig>) -> AnyView {
        AnyView(AudioGenerationConfigView(configuration: configuration))
    }

    @MainActor
    public func makeListItemView(model: GeneratedAudioRecord) -> AnyView {
        AnyView(AudioListItemView(record: model))
    }

    @MainActor
    public func makeDetailView(model: GeneratedAudioRecord) -> AnyView {
        AnyView(AudioDetailView(record: model))
    }
}

public struct AudioGenerationConfig: Codable, Sendable {
    var voiceID: String
    var voiceName: String
    var stability: Double
    var similarityBoost: Double
    var model: String
}
```

---

## SwiftData Response Models

### Base Response Model

```swift
@Model
public class TypedAIResponse: AIGeneratedContent {
    /// The requestor that generated this response
    public var requestorID: String

    /// Optional file reference if data is stored in .guion bundle
    public var fileReference: TypedDataFileReference?

    /// Schema version for migration support
    public var schemaVersion: String

    /// Validation status
    public var validationStatus: ValidationStatus

    public init(
        id: UUID = UUID(),
        providerId: String,
        requestorID: String,
        prompt: String,
        schemaVersion: String = "1.0",
        fileReference: TypedDataFileReference? = nil
    ) {
        self.requestorID = requestorID
        self.fileReference = fileReference
        self.schemaVersion = schemaVersion
        self.validationStatus = .pending

        super.init(
            id: id,
            providerId: providerId,
            prompt: prompt
        )
    }
}

public enum ValidationStatus: Codable {
    case pending
    case valid
    case invalid(errors: [String])
}
```

### Specific Response Models

```swift
@Model
public final class GeneratedTextRecord: TypedAIResponse {
    public var text: String
    public var wordCount: Int
    public var characterCount: Int
    public var languageCode: String?

    public init(
        id: UUID = UUID(),
        providerId: String,
        requestorID: String,
        text: String,
        wordCount: Int,
        characterCount: Int,
        languageCode: String? = nil,
        modelIdentifier: String? = nil,
        tokenCount: Int? = nil,
        fileReference: TypedDataFileReference? = nil
    ) {
        self.text = text
        self.wordCount = wordCount
        self.characterCount = characterCount
        self.languageCode = languageCode

        super.init(
            id: id,
            providerId: providerId,
            requestorID: requestorID,
            prompt: text.prefix(100) + "...",
            fileReference: fileReference
        )

        self.modelIdentifier = modelIdentifier
        self.tokenCount = tokenCount
    }
}

@Model
public final class GeneratedImageRecord: TypedAIResponse {
    public var imageData: Data?
    public var width: Int
    public var height: Int
    public var format: String

    public init(
        id: UUID = UUID(),
        providerId: String,
        requestorID: String,
        imageData: Data?,
        width: Int,
        height: Int,
        format: String,
        modelIdentifier: String? = nil,
        fileReference: TypedDataFileReference? = nil
    ) {
        self.imageData = imageData
        self.width = width
        self.height = height
        self.format = format

        super.init(
            id: id,
            providerId: providerId,
            requestorID: requestorID,
            prompt: "",
            fileReference: fileReference
        )

        self.modelIdentifier = modelIdentifier
    }
}

@Model
public final class GeneratedAudioRecord: TypedAIResponse {
    public var audioData: Data?
    public var format: String
    public var durationSeconds: Double?
    public var sampleRate: Int
    public var voiceID: String
    public var voiceName: String

    public init(
        id: UUID = UUID(),
        providerId: String,
        requestorID: String,
        audioData: Data?,
        format: String,
        durationSeconds: Double?,
        sampleRate: Int,
        voiceID: String,
        voiceName: String,
        modelIdentifier: String? = nil,
        fileReference: TypedDataFileReference? = nil
    ) {
        self.audioData = audioData
        self.format = format
        self.durationSeconds = durationSeconds
        self.sampleRate = sampleRate
        self.voiceID = voiceID
        self.voiceName = voiceName

        super.init(
            id: id,
            providerId: providerId,
            requestorID: requestorID,
            prompt: "",
            fileReference: fileReference
        )

        self.modelIdentifier = modelIdentifier
    }
}
```

---

## Integration with TypedDataBroker

```swift
actor TypedDataBroker {

    /// Request file generation using a specific requestor.
    ///
    /// - Parameters:
    ///   - prompt: The generation prompt
    ///   - requestor: The specific requestor to use
    ///   - configuration: Requestor-specific configuration
    ///   - parentID: The parent element requesting generation
    /// - Returns: Request ID for tracking
    public func requestFile<R: AIRequestor>(
        prompt: String,
        requestor: R,
        configuration: R.Configuration,
        parentID: UUID
    ) async throws -> UUID {
        // 1. Generate request ID
        let requestID = UUID()

        // 2. Create storage area for this request
        let storageArea = try await createStorageArea(for: requestID)

        // 3. Store mappings
        storageAreas[requestID] = storageArea
        requestParentMapping[requestID] = parentID
        requestorMapping[requestID] = requestor.requestorID

        // 4. Execute request
        let result = await requestor.request(
            prompt: prompt,
            configuration: configuration,
            storageArea: storageArea
        )

        // 5. Handle result
        switch result {
        case .success(let typedData):
            // Create response model on main actor
            await MainActor.run {
                let responseModel = requestor.makeResponseModel(
                    from: typedData,
                    fileReference: storageArea.fileReferences.first,
                    requestID: requestID
                )
                // Persist via AIDataCoordinator
                // ...
            }

        case .failure(let error):
            // Handle error
            // ...
        }

        return requestID
    }
}
```

---

## Requestor Discovery

```swift
/// Manager for discovering and accessing requestors across all providers.
public class AIRequestorManager {

    private let serviceManager: AIServiceManager

    public init(serviceManager: AIServiceManager) {
        self.serviceManager = serviceManager
    }

    /// Gets all available requestors across all providers.
    public func allRequestors() -> [any AIRequestor] {
        serviceManager.allProviders().flatMap { $0.availableRequestors() }
    }

    /// Finds a requestor by ID.
    public func requestor(withID id: String) -> (any AIRequestor)? {
        allRequestors().first { $0.requestorID == id }
    }

    /// Gets all requestors for a category.
    public func requestors(for category: ProviderCategory) -> [any AIRequestor] {
        allRequestors().filter { $0.category == category }
    }

    /// Gets all requestors from a specific provider.
    public func requestors(fromProvider providerID: String) -> [any AIRequestor] {
        guard let provider = serviceManager.provider(withID: providerID) else {
            return []
        }
        return provider.availableRequestors()
    }

    /// Groups requestors by provider.
    public func requestorsByProvider() -> [String: [any AIRequestor]] {
        Dictionary(grouping: allRequestors(), by: { $0.providerID })
    }

    /// Groups requestors by category.
    public func requestorsByCategory() -> [ProviderCategory: [any AIRequestor]] {
        Dictionary(grouping: allRequestors(), by: { $0.category })
    }
}
```

---

## Summary

### Key Design Decisions

1. ✅ **One File Type per Requestor**: Each requestor generates exactly one type
2. ✅ **Multiple Requestors per Provider**: Providers can offer many specialized requestors
3. ✅ **Type-Specific Configuration**: Each requestor has its own `Configuration` associated type
4. ✅ **Storage Area Access**: Requestors receive a `StorageAreaReference` for writing files
5. ✅ **Swift Codable Schema**: Phase 6 uses Swift's native type system (defer JSON Schema to Phase 7)
6. ✅ **SwiftData Models**: Each requestor defines its own response model type
7. ✅ **UI Components Defined**: Protocol includes view methods for Phase 7 implementation

### Benefits

- **Type Safety**: Associated types ensure type-safe interactions
- **Extensibility**: Easy to add new requestors to existing providers
- **Isolation**: Each request gets its own storage area
- **Flexibility**: Providers can support multiple content types independently
- **Discovery**: Centralized requestor discovery and management
- **Testability**: Each requestor can be tested independently

---

## References

- **Phase 6 Pre-Implementation Checklist**: `PHASE_6_PRE_IMPLEMENTATION_CHECKLIST.md`
- **Generated File Flow**: `PHASE_6_GENERATED_FILE_FLOW.md`
- **AIServiceProvider Protocol**: `/Sources/SwiftHablare/Core/AIServiceProvider.swift`
- **AIGeneratedContent Models**: `/Sources/SwiftHablare/Models/AIGeneratedContent.swift`

---

**Document Version**: 1.0
**Created**: 2025-10-12
**Status**: ✅ DEFINED - Ready for Implementation
**Resolves**: Pre-Implementation Checklist Requirement #1
