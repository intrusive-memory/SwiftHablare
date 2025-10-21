# Phase 6: Pre-Implementation Requirements Checklist

**Status**: ✅ COMPLETE (All sub-phases finished)
**Date Started**: 2025-10-12
**Completion Date**: 2025-10-13
**Goal**: Identify and clarify vague/missing specifications before Phase 6 implementation begins

---

## 📊 Phase 6 Implementation Progress

| Sub-Phase | Status | Completion Date | PR | Notes |
|-----------|--------|----------------|-----|-------|
| **Phase 6A** | ✅ Complete | 2025-10-11 | #19 | Core infrastructure, storage system |
| **Phase 6B** | ✅ Complete | 2025-10-11 | #20 | Text requestors (OpenAI, Anthropic) |
| **Phase 6C** | ✅ Complete | 2025-10-12 | #23 | Audio requestors (OpenAI, ElevenLabs) |
| **Phase 6D** | ✅ Complete | 2025-10-12 | #24 | Image requestors (DALL-E 2, DALL-E 3) |
| **Phase 6E** | ✅ Complete | 2025-10-13 | #25 | Embedding requestors (OpenAI 3 models) |
| **Phase 6F** | ✅ Complete | 2025-10-13 | TBD | Integration & refinement |

**Overall Progress**: 100% (6/6 sub-phases complete) ✅

### Phase 6E: Embedding Requestors Summary ✅

**Completion Date**: 2025-10-13
**Branch**: `phase-6e-embedding-requestors`
**Pull Request**: #25
**Test Coverage**: 35 tests, 100% pass rate

**Deliverables**:
- ✅ `GeneratedEmbeddingData.swift` - Embedding typed data with binary serialization
- ✅ `GeneratedEmbeddingRecord.swift` - SwiftData persistence model
- ✅ `OpenAIEmbeddingRequestor.swift` - Three embedding models (v3-small, v3-large, ada-002)
- ✅ `EmbeddingRequestorTests.swift` - Comprehensive test suite
- ✅ OpenAI provider updated with embedding capabilities
- ✅ Storage integration (100KB threshold)
- ✅ Custom binary serialization (4 bytes per float)
- ✅ Alignment-safe deserialization

**Key Features**:
- text-embedding-3-small (1536d, $0.02/1M tokens)
- text-embedding-3-large (3072d, $0.13/1M tokens)
- text-embedding-ada-002 (1536d, $0.10/1M tokens, legacy)
- Custom dimension support for v3 models
- Efficient binary format (~6KB for 1536d)
- Cost estimation per embedding

### Phase 6F: Integration & Refinement Summary ✅

**Completion Date**: 2025-10-13
**Branch**: `phase-6f-integration-refinement`
**Pull Request**: TBD
**Test Status**: 402/402 tests passing

**Deliverables**:
- ✅ All 402 tests verified passing
- ✅ Code review completed (Phase 7 placeholders are intentional)
- ✅ TypedDataBroker pattern verified in existing code
- ✅ File storage workflow confirmed functional
- ✅ Phase 6 completion documentation created

**Status**: Phase 6 complete and ready for Phase 7 (UI implementation)

**Documentation**: See `Docs/PHASE_6_COMPLETION_SUMMARY.md`

### Phase 6D: Image Requestors Summary ✅

**Completion Date**: 2025-10-12
**Branch**: `phase-6d-image-requestors`
**Pull Request**: #24
**Test Coverage**: 40 tests, 100% pass rate

**Deliverables**:
- ✅ `GeneratedImageData.swift` - Image typed data structure with video aspect ratios
- ✅ `GeneratedImageRecord.swift` - SwiftData persistence model
- ✅ `OpenAIImageRequestor.swift` - DALL-E 2 & 3 implementation
- ✅ `ImageRequestorTests.swift` - Comprehensive test suite
- ✅ OpenAI provider updated with image capabilities
- ✅ Storage integration (100KB threshold)
- ✅ Video production aspect ratios (16:9, 9:16, 1:1)
- ✅ Configuration presets (widescreen, portrait, storyboard)

**Key Features**:
- DALL-E 2 support: Square formats (256x256, 512x512, 1024x1024)
- DALL-E 3 support: All formats including widescreen and portrait
- Cost estimation per image
- Automatic storage management (<100KB in-memory, ≥100KB file-based)
- Single image restriction (numberOfImages = 1) to prevent API credit waste

**Documentation**: See `Docs/PHASE_6D_IMAGE_REQUESTORS_COMPLETION.md`

---

---

## ✅ RESOLVED Requirements

### 1. File Reference Structure ✅
**Resolution**: File operations abstracted through .guion document interface with request-specific storage
- Each request has its own .guion bundle at `Requests/{requestID}.guion/`
- Files stored in request-specific Resources folder with UUID-based unique IDs
- File references contain both requestID and file uniqueID for retrieval
- All I/O through SwiftGuion document interface

**Implementation Pattern**:
```swift
struct TypedDataFileReference: Codable, Sendable {
    let uniqueID: UUID           // Unique identifier for file
    let requestID: UUID          // Associated request ID
    let bundlePath: URL          // Path to request-specific .guion bundle
    let relativePath: String     // Relative path: "Resources/{uniqueID}.{ext}"
    let contentType: String      // MIME type
    let sizeBytes: Int64
    let createdAt: Date

    // Full path to file
    var fullPath: URL {
        bundlePath.appendingPathComponent(relativePath)
    }
}

struct StorageAreaReference: Codable, Sendable {
    let requestID: UUID          // Associated request ID
    let bundleURL: URL           // Path to request-specific .guion bundle
    let createdAt: Date

    var resourcesDirectory: URL {
        bundleURL.appendingPathComponent("Resources")
    }
}
```

**Storage Organization**:
```
Base Storage Directory/
└── Requests/
    ├── {requestID-1}.guion/
    │   ├── info.json
    │   └── Resources/
    │       ├── {fileUUID-1}.png
    │       └── {fileUUID-2}.json
    └── {requestID-2}.guion/
        ├── info.json
        └── Resources/
            └── {fileUUID-3}.mp3
```

### 2. Performance Thresholds ✅
**Resolution**: Record performance metrics, determine thresholds later
- Measure performance for various data sizes (1KB, 10KB, 100KB, 1MB, 10MB, 100MB)
- Record metrics for in-memory vs file-based storage
- Defer threshold decisions until after data collection
- Quality Gate 6.8 updated to performance measurement instead of threshold enforcement

### 3. TypedDataBroker & Storage Initialization ✅
**Resolution**: Broker manages request-specific storage areas on initialization
- Broker establishes base storage directory on init
- Creates `Requests/` directory structure
- For each request, creates isolated `.guion` bundle at `Requests/{requestID}.guion/`
- Maintains mappings: requestID → storageArea, requestID → parentID
- Passes storage area reference to providers during request execution

**Broker Initialization Pattern**:
```swift
actor TypedDataBroker {
    private let baseStorageURL: URL
    private let textPackCoordinator: TextPackCoordinator
    private var storageAreas: [UUID: StorageAreaReference] = [:]
    private var requestParentMapping: [UUID: UUID] = [:]

    init(baseStorageURL: URL) async throws {
        self.baseStorageURL = baseStorageURL
        self.textPackCoordinator = TextPackCoordinator()

        // Create base storage structure
        let requestsDirectory = baseStorageURL.appendingPathComponent("Requests")
        try FileManager.default.createDirectory(
            at: requestsDirectory,
            withIntermediateDirectories: true
        )
    }

    func requestFile(prompt: String, params: [String: Any], parentID: UUID) async throws -> UUID {
        // 1. Generate request ID
        let requestID = UUID()

        // 2. Create storage area for this request
        let storageArea = try await createStorageArea(for: requestID)

        // 3. Store mappings
        storageAreas[requestID] = storageArea
        requestParentMapping[requestID] = parentID

        // 4. Submit to request manager with storage area
        // ... rest of implementation
        return requestID
    }
}
```

**Benefits**:
- Provider has access to isolated storage during execution
- No file name collisions between concurrent requests
- Atomic cleanup of request data
- Easy debugging with organized file structure

---

## ⚠️ CRITICAL - Must Define Before Implementation Begins

### 1. API Requestor Protocol Interface ✅
**Priority**: 🔴 CRITICAL (RESOLVED)
**Status**: ✅ DEFINED
**Impact**: Core architecture - all providers depend on this
**Resolution Document**: `PHASE_6_API_REQUESTOR_PROTOCOL.md`

**Resolution Summary**:
- ✅ Complete protocol defined with all required methods and properties
- ✅ AIServiceProvider extended with `availableRequestors()` method
- ✅ Each requestor returns exactly ONE file type
- ✅ Providers can offer MULTIPLE requestors (e.g., OpenAI offers text, image, embedding requestors)
- ✅ Associated types: TypedData, ResponseModel, Configuration
- ✅ Storage area integration: requestors receive StorageAreaReference
- ✅ Swift Codable schema system (JSON Schema deferred to Phase 7)
- ✅ Complete examples provided for text, image, and audio requestors

**Key Design Decisions**:
1. ✅ AIRequestor is a separate protocol; AIServiceProvider offers multiple requestors
2. ✅ Existing providers implement `availableRequestors()` to expose their requestors
3. ✅ Multi-capability providers (like ChatGPT) provide separate requestors for each type:
   - `openai.text.gpt4` for text generation
   - `openai.image.dalle3` for image generation
   - `openai.embedding.ada002` for embeddings

**Implementation Pattern**:
```swift
// Provider offers multiple requestors
public class OpenAIProvider: AIServiceProvider {
    public func availableRequestors() -> [any AIRequestor] {
        return [
            OpenAITextRequestor(provider: self, model: .gpt4),
            OpenAIImageRequestor(provider: self, model: .dalle3),
            OpenAIEmbeddingRequestor(provider: self)
        ]
    }
}

// Each requestor generates one file type
public class OpenAITextRequestor: AIRequestor {
    public typealias TypedData = GeneratedText
    public typealias ResponseModel = GeneratedTextRecord
    public typealias Configuration = TextGenerationConfig

    public let category: ProviderCategory = .text
    public let outputFileType = OutputFileType.plainText

    public func request(
        prompt: String,
        configuration: Configuration,
        storageArea: StorageAreaReference
    ) async -> Result<TypedData, AIServiceError> {
        // Implementation
    }
}
```

**See**: `PHASE_6_API_REQUESTOR_PROTOCOL.md` for complete specification with examples

---

### 2. Schema System Type Support ✅
**Priority**: 🔴 CRITICAL (RESOLVED)
**Status**: ✅ DEFINED
**Impact**: Type validation and serialization architecture

**Resolution**: Each typed data type defines its own serialization strategy

**Key Design Decisions**:
1. ✅ **No Universal Schema System**: No need for JSON Schema, Pydantic, or universal validation
2. ✅ **Type-Specific Serialization**: Each `TypedData` type owns its serialization strategy
3. ✅ **Flexible Format Support**: Types can choose JSON, plist, binary, protobuf, etc.
4. ✅ **Storage Decision**: Export/save thread decides storage location based on type preferences

**Implementation Pattern**:
```swift
/// Protocol for types that can serialize themselves
public protocol SerializableTypedData: Codable, Sendable {
    /// Preferred serialization format
    var preferredFormat: SerializationFormat { get }

    /// Serialize to Data using preferred format
    func serialize() throws -> Data

    /// Deserialize from Data
    static func deserialize(from data: Data, format: SerializationFormat) throws -> Self
}

public enum SerializationFormat: String, Codable {
    case json           // JSON encoding
    case plist          // Property list
    case binary         // Custom binary format
    case protobuf       // Protocol buffers
    case messagepack    // MessagePack

    var fileExtension: String {
        switch self {
        case .json: return "json"
        case .plist: return "plist"
        case .binary: return "bin"
        case .protobuf: return "pb"
        case .messagepack: return "msgpack"
        }
    }

    var mimeType: String {
        switch self {
        case .json: return "application/json"
        case .plist: return "application/x-plist"
        case .binary: return "application/octet-stream"
        case .protobuf: return "application/x-protobuf"
        case .messagepack: return "application/x-msgpack"
        }
    }
}

/// Default implementation using Codable
extension SerializableTypedData {
    public var preferredFormat: SerializationFormat { .json }

    public func serialize() throws -> Data {
        switch preferredFormat {
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            return try encoder.encode(self)

        case .plist:
            let encoder = PropertyListEncoder()
            encoder.outputFormat = .xml
            return try encoder.encode(self)

        case .binary, .protobuf, .messagepack:
            // Custom serialization - type implements this
            fatalError("Type must implement custom serialization for format: \(preferredFormat)")
        }
    }

    public static func deserialize(from data: Data, format: SerializationFormat) throws -> Self {
        switch format {
        case .json:
            let decoder = JSONDecoder()
            return try decoder.decode(Self.self, from: data)

        case .plist:
            let decoder = PropertyListDecoder()
            return try decoder.decode(Self.self, from: data)

        case .binary, .protobuf, .messagepack:
            // Custom deserialization - type implements this
            fatalError("Type must implement custom deserialization for format: \(format)")
        }
    }
}
```

**Example Usage**:
```swift
// Text uses JSON (human-readable, debuggable)
public struct GeneratedText: SerializableTypedData {
    let text: String
    let wordCount: Int
    let metadata: [String: String]

    public var preferredFormat: SerializationFormat { .json }
}

// Audio metadata uses plist (native Apple format)
public struct GeneratedAudio: SerializableTypedData {
    let audioData: Data?  // Actual audio stored separately
    let format: String
    let sampleRate: Int
    let duration: Double

    public var preferredFormat: SerializationFormat { .plist }
}

// Large structured data uses binary (compact, efficient)
public struct GeneratedEmbedding: SerializableTypedData {
    let vectors: [Float]
    let dimensions: Int
    let model: String

    public var preferredFormat: SerializationFormat { .binary }

    // Custom binary serialization for efficiency
    public func serialize() throws -> Data {
        var data = Data()
        data.append(contentsOf: withUnsafeBytes(of: dimensions) { Data($0) })
        data.append(contentsOf: vectors.withUnsafeBytes { Data($0) })
        // ... encode model string
        return data
    }

    public static func deserialize(from data: Data, format: SerializationFormat) throws -> Self {
        // Custom binary deserialization
        // ...
    }
}
```

**Benefits**:
- **Type Autonomy**: Each type knows how to serialize itself
- **Format Flexibility**: JSON for text, binary for embeddings, plist for metadata
- **Performance**: Types can optimize their own serialization
- **No Dependencies**: No need for external schema libraries
- **Swift Native**: Uses standard Codable where possible
- **Extensible**: Easy to add new formats (protobuf, msgpack, etc.)

**Storage Integration**:
```swift
// TextPackCoordinator handles storage
actor TextPackCoordinator {
    func writeTypedData<T: SerializableTypedData>(
        _ data: T,
        withID id: UUID,
        to storageArea: StorageAreaReference
    ) async throws -> TypedDataFileReference {
        // Type decides format
        let format = data.preferredFormat
        let serialized = try data.serialize()

        // Write with appropriate extension
        let filename = "\(id.uuidString).\(format.fileExtension)"
        let fileURL = storageArea.resourcesDirectory.appendingPathComponent(filename)

        try serialized.write(to: fileURL)

        return TypedDataFileReference(
            uniqueID: id,
            requestID: storageArea.requestID,
            bundlePath: storageArea.bundleURL,
            relativePath: "Resources/\(filename)",
            contentType: format.mimeType,
            sizeBytes: Int64(serialized.count),
            createdAt: Date()
        )
    }

    func readTypedData<T: SerializableTypedData>(
        from reference: TypedDataFileReference,
        as type: T.Type
    ) async throws -> T {
        let data = try Data(contentsOf: reference.fullPath)

        // Infer format from file extension
        let format = SerializationFormat.from(extension: reference.relativePath)

        return try T.deserialize(from: data, format: format)
    }
}
```

**Validation**:
- Types validate themselves during deserialization
- Codable provides automatic validation
- Custom types can implement additional validation in their deserialize method
- No separate schema validation layer needed

**See Also**: `PHASE_6_API_REQUESTOR_PROTOCOL.md` for integration with AIRequestor protocol

---

### 3. TextPack Coordinator / Document Integration ✅
**Priority**: 🔴 CRITICAL (RESOLVED)
**Status**: ✅ DEFINED
**Impact**: File operations and document management

**Resolution**: Document-based approach - the TextPack document owns file operations

**Key Design Decisions**:
1. ✅ **Document is the .guion Bundle**: The app operates on the actual TextPack document
2. ✅ **No Separate Coordinator Actor**: Document itself manages file operations (thread-safe via SwiftGuion)
3. ✅ **File Broker Pattern**: TypedDataBroker queries and returns file info on save
4. ✅ **Document Controls Storage**: Document decides what to do with files it receives

**Implementation Pattern**:
```swift
/// The main document (SwiftUI Document-based app)
class HablareDocument: ReferenceFileDocument {
    static var readableContentTypes: [UTType] { [.guionBundle] }

    /// The .guion bundle this document represents
    private var bundle: TextPackBundle

    /// File broker for managing generated files
    private let fileBroker: TypedDataBroker

    init() {
        self.bundle = TextPackBundle()
        self.fileBroker = TypedDataBroker(documentBundle: bundle)
    }

    // MARK: - Document Save

    func snapshot(contentType: UTType) throws -> Data {
        // Ask file broker for all attached files
        let attachedFiles = await fileBroker.getAttachedFiles()

        // Write each file to document bundle
        for attachment in attachedFiles {
            try bundle.writeResource(
                attachment.data,
                at: attachment.path,
                metadata: attachment.metadata
            )
        }

        // Return document snapshot
        return try bundle.serialize()
    }

    func fileWrapper(snapshot: Data, configuration: WriteConfiguration) throws -> FileWrapper {
        // SwiftGuion handles .guion bundle structure
        return try bundle.fileWrapper()
    }
}

/// TypedDataBroker provides file attachment interface
actor TypedDataBroker {
    private weak var documentBundle: TextPackBundle?
    private var fileAttachments: [UUID: FileAttachment] = [:]

    /// Query files attached to specific parent IDs
    func getAttachedFiles(forParents parentIDs: [UUID]? = nil) -> [FileAttachment] {
        if let parentIDs = parentIDs {
            return fileAttachments.values.filter { parentIDs.contains($0.parentID) }
        }
        return Array(fileAttachments.values)
    }

    /// Register a generated file attachment
    func attachFile(
        _ data: Data,
        serializedObject: any SerializableTypedData,
        path: String,
        parentID: UUID,
        requestID: UUID
    ) {
        let attachment = FileAttachment(
            id: UUID(),
            data: data,
            serializedObject: serializedObject,
            path: path,
            parentID: parentID,
            requestID: requestID,
            createdAt: Date()
        )
        fileAttachments[attachment.id] = attachment
    }

    /// Remove attachments for a parent
    func removeAttachments(forParent parentID: UUID) {
        fileAttachments = fileAttachments.filter { $0.value.parentID != parentID }
    }
}

/// File attachment returned to document
struct FileAttachment: Sendable {
    let id: UUID
    let data: Data                          // Serialized typed data
    let serializedObject: any SerializableTypedData  // Original object
    let path: String                        // Relative path in bundle
    let parentID: UUID                      // Parent element that owns this
    let requestID: UUID                     // Original request
    let createdAt: Date

    var metadata: [String: String] {
        [
            "parentID": parentID.uuidString,
            "requestID": requestID.uuidString,
            "createdAt": createdAt.ISO8601Format()
        ]
    }
}
```

**Document Save Flow**:
```swift
// User triggers Save in document
document.save() {
    // 1. Document asks broker for attached files
    let files = await fileBroker.getAttachedFiles()

    // 2. Broker returns file info for all parent IDs
    // - File data (serialized)
    // - Path in bundle (e.g., "Resources/{parentID}/{requestID}.json")
    // - Metadata (parentID, requestID, timestamps)

    // 3. Document writes files to .guion bundle
    for file in files {
        try bundle.writeResource(file.data, at: file.path)
    }

    // 4. SwiftGuion serializes the complete bundle
    return try bundle.fileWrapper()
}
```

**File Organization in .guion Bundle**:
```
MyProject.guion/
├── info.json                          # Bundle metadata
├── text.md or text.html               # Main document content
└── Resources/
    ├── {parentID-1}/
    │   ├── {requestID-1}.json         # Generated text metadata
    │   ├── {requestID-2}.png          # Generated image
    │   └── {requestID-3}.json         # Image metadata
    └── {parentID-2}/
        ├── {requestID-4}.mp3          # Generated audio
        └── {requestID-4}.plist        # Audio metadata
```

**Broker Query Interface**:
```swift
actor TypedDataBroker {

    /// Get all attachments (for full document save)
    func getAttachedFiles() -> [FileAttachment] {
        Array(fileAttachments.values)
    }

    /// Get attachments for specific parent(s)
    func getAttachedFiles(forParents parentIDs: [UUID]) -> [FileAttachment] {
        fileAttachments.values.filter { parentIDs.contains($0.parentID) }
    }

    /// Get attachments for a specific request
    func getAttachedFiles(forRequest requestID: UUID) -> [FileAttachment] {
        fileAttachments.values.filter { $0.requestID == requestID }
    }

    /// Check if parent has attachments
    func hasAttachments(forParent parentID: UUID) -> Bool {
        fileAttachments.values.contains { $0.parentID == parentID }
    }
}
```

**Benefits**:
- **Document-Centric**: Natural fit with SwiftUI document architecture
- **SwiftGuion Integration**: Document uses SwiftGuion for .guion operations (thread-safe)
- **Simple Interface**: Broker provides query API, document decides storage
- **No Separate Coordinator**: Document IS the coordinator for its bundle
- **Flexible Storage**: Document can organize files however it wants
- **Atomic Saves**: All file writes happen during document save
- **Parent-Based Organization**: Files grouped by parent element for easy management

**SwiftGuion Thread Safety**:
- SwiftGuion's TextPackBundle is already designed for thread-safe operations
- Document can safely write from save operation
- No additional actor isolation needed beyond broker

**See Also**:
- `PHASE_6_GENERATED_FILE_FLOW.md` for complete workflow
- SwiftGuion library: https://github.com/intrusive-memory/SwiftGuion

---

### 4. Error Object Structure for Missing/Invalid Typed Data
**Priority**: 🟡 HIGH
**Status**: ⚠️ NEEDS DEFINITION
**Impact**: Error handling and debugging experience

**Current State**: General requirement
> "Error handling for missing typed data" and "Error handling for invalid/malformed typed data"

**Missing Specifications**:
- [ ] Error type hierarchy for typed data errors
- [ ] Information included in error objects
- [ ] Error propagation to UI
- [ ] Recovery suggestions
- [ ] Localization support

**Suggested Error Hierarchy**:
```swift
enum TypedDataError: Error, LocalizedError {
    case missingRequiredField(fieldName: String, expectedType: String)
    case typeMismatch(fieldName: String, expected: String, received: String)
    case validationFailed(fieldName: String, reason: String)
    case schemaViolation(description: String, path: String)
    case fileTooLarge(sizeBytes: Int64, fileName: String)
    case fileAccessFailed(fileID: UUID, reason: String)
    case bundleCorrupted(bundlePath: URL, reason: String)

    var errorDescription: String? {
        switch self {
        case .missingRequiredField(let field, let type):
            return "Required field '\(field)' of type '\(type)' is missing from the response"
        // ... other cases
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .missingRequiredField:
            return "Check the provider's response format or update the schema definition"
        // ... other cases
        }
    }
}
```

**Questions to Resolve**:
1. Should errors include the full response for debugging?
2. How do we handle partial success (some fields valid, others invalid)?
3. What level of detail should be logged vs shown to users?

**Action Required**: Define complete error type hierarchy with localization

---

### 5. Three-View Pattern Protocol/Interface
**Priority**: 🟡 HIGH
**Status**: ⚠️ NEEDS DEFINITION
**Impact**: UI consistency across providers

**Current State**: High-level description
> "Three-view pattern for displaying AI responses: List View, Detail View, Combined View"

**Missing Specifications**:
- [ ] Protocol requirements for each view type
- [ ] How filtering works (filterable properties)
- [ ] State management for click-to-reveal
- [ ] Data binding patterns
- [ ] Common filtering predicates

**Suggested Pattern**:
```swift
// List View Protocol
protocol AIResponseListView: View {
    associatedtype Item: AIGeneratedContent

    var items: [Item] { get }
    var filterPredicate: NSPredicate? { get set }

    func filtered() -> [Item]
}

// Detail View Protocol
protocol AIResponseDetailView: View {
    associatedtype Item: AIGeneratedContent

    init(item: Item)
}

// Combined View Protocol
protocol AIResponseCombinedView: View {
    associatedtype Item: AIGeneratedContent
    associatedtype ListView: AIResponseListView where ListView.Item == Item
    associatedtype DetailView: AIResponseDetailView where DetailView.Item == Item

    var selectedItem: Item? { get set }

    func makeListView() -> ListView
    func makeDetailView(for item: Item) -> DetailView
}

// Standard filtering support
protocol Filterable {
    var filterableProperties: [String: Any] { get }
}
```

**Questions to Resolve**:
1. Should filtering be type-safe (enums) or dynamic (predicates)?
2. How do providers specify which fields are filterable?
3. Is click-to-reveal state managed by the view or view model?
4. Should we provide default implementations?

**Action Required**: Define complete three-view protocol with filtering patterns

---

## 🟢 IMPORTANT - Should Define Before or During Phase 6

### 6. Provider Capability Declarations for Typed Responses
**Priority**: 🟢 MEDIUM
**Status**: ⚠️ NEEDS CLARIFICATION

**Current State**: General statement
> "Provider capability declarations for supported return types"

**Missing Specifications**:
- [ ] Extension to existing `AICapability` enum
- [ ] How to query providers by typed data capability
- [ ] Version information for schema evolution

**Suggested Approach**:
```swift
extension AICapability {
    case typedResponse(schema: TypedDataSchema, version: String)
    case multipleTypedResponses([TypedDataSchema])
}

extension AIServiceManager {
    func providers(supporting schema: TypedDataSchema) -> [any AIServiceProvider]
}
```

**Action Required**: Extend `AICapability` enum with typed response support

---

### 7. Type Conversion and Validation Middleware
**Priority**: 🟢 MEDIUM
**Status**: ⚠️ NEEDS ARCHITECTURE DECISION

**Current State**: Single requirement line
> "Type conversion and validation middleware"

**Missing Specifications**:
- [ ] Middleware architecture (chain? pipeline?)
- [ ] Custom middleware support
- [ ] Built-in validators
- [ ] Error accumulation vs fail-fast

**Suggested Middleware Pattern**:
```swift
protocol TypeValidationMiddleware {
    func validate(
        _ data: Any,
        against schema: TypedDataSchema
    ) async throws -> ValidationResult
}

struct ValidationPipeline {
    var middleware: [TypeValidationMiddleware]

    func process(
        _ data: Any,
        against schema: TypedDataSchema
    ) async throws -> Any {
        var result = data
        for validator in middleware {
            result = try await validator.validate(result, against: schema)
        }
        return result
    }
}

// Built-in validators
struct TypeCheckValidator: TypeValidationMiddleware { }
struct RangeValidator: TypeValidationMiddleware { }
struct FormatValidator: TypeValidationMiddleware { }
struct CustomValidator: TypeValidationMiddleware {
    let validateBlock: (Any) throws -> Bool
}
```

**Questions to Resolve**:
1. Should validation be synchronous or asynchronous?
2. Error accumulation (collect all errors) or fail-fast (stop at first)?
3. How do providers add custom validators?

**Action Required**: Design middleware architecture and built-in validators

---

### 8. SwiftData Model Requirements Detail
**Priority**: 🟢 MEDIUM
**Status**: ⚠️ NEEDS SPECIFICATION

**Current State**: General requirement
> "Each API requestor must provide its own SwiftData table/model for storing typed data"

**Missing Specifications**:
- [ ] Base class or protocol all models must conform to
- [ ] Required properties
- [ ] Relationship to `AIGeneratedContent`
- [ ] Index requirements
- [ ] Migration strategy

**Suggested Pattern**:
```swift
@Model
class TypedAIResponse: AIGeneratedContent {
    // Existing AIGeneratedContent properties
    // + typed data additions

    var typedDataJSON: Data?                    // In-memory typed data (if small)
    var fileReference: TypedDataFileReference?  // File reference (if large)
    var schemaVersion: String
    var validationStatus: ValidationStatus

    // Providers extend with specific properties
}

enum ValidationStatus: Codable {
    case pending
    case valid
    case invalid(errors: [TypedDataError])
}

// Example: Audio provider's typed response model
@Model
class AudioTypedResponse: TypedAIResponse {
    var audioFormat: String
    var durationSeconds: Double
    var voiceID: String?
    var transcript: String?
}
```

**Questions to Resolve**:
1. Should all typed responses inherit from a base class?
2. How do we handle schema migrations?
3. Should file references be nullable (optional)?

**Action Required**: Define base model structure and requirements

---

### 9. Configuration Widget State Persistence
**Priority**: 🟢 MEDIUM
**Status**: ⚠️ NEEDS DECISION

**Current State**: Configuration widget pattern described, persistence not specified

**Missing Specifications**:
- [ ] Where are configuration values persisted?
- [ ] Per-provider or global configuration?
- [ ] Sensitive values in Keychain?

**Suggested Approach**:
```swift
// Per-provider configuration storage
@Model
class ProviderConfiguration {
    let providerID: String
    var settingsJSON: Data  // Non-sensitive settings
    var lastUsed: Date

    // Sensitive values (API keys) already in Keychain via Phase 4
}

// Configuration widget protocol
protocol ConfigurationWidget: View {
    associatedtype ConfigurationType: Codable

    @Binding var configuration: ConfigurationType

    func save() async throws
    func load() async throws
}
```

**Action Required**: Decide on configuration persistence strategy

---

### 10. Multi-Type Provider Dynamic Configuration
**Priority**: 🟢 MEDIUM
**Status**: ⚠️ NEEDS UI PATTERN

**Current State**: Requirement stated
> "Multi-type providers: type selection dropdown + dynamic type-specific configuration"

**Missing Specifications**:
- [ ] SwiftUI pattern for dynamic configuration
- [ ] State management for type switching

**Suggested Pattern**:
```swift
struct MultiTypeConfigurationView: View {
    @State private var selectedType: ProviderCategory

    var body: some View {
        VStack {
            Picker("Type", selection: $selectedType) {
                ForEach(provider.supportedTypes, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }

            configurationView(for: selectedType)
        }
    }

    @ViewBuilder
    func configurationView(for type: ProviderCategory) -> some View {
        switch type {
        case .audio:
            AudioConfigurationView(...)
        case .text:
            TextConfigurationView(...)
        case .image:
            ImageConfigurationView(...)
        // ...
        }
    }
}
```

**Action Required**: Define dynamic UI pattern for multi-type providers

---

## 🔵 NICE TO HAVE - Can Define During Implementation

### 11. Workflow Pattern State Machine
**Priority**: 🔵 LOW
**Status**: 🟢 CAN BE REFINED DURING IMPLEMENTATION

**Current State**: Linear workflow described
> "background request → background file write → file reference to main → SwiftData persistence"

**Could Be Enhanced With**:
- State transitions and error handling
- Rollback mechanisms
- Progress reporting
- Cancellation handling

**Note**: Current linear workflow is sufficient for Phase 6 start. State machine can be added if complexity demands it during implementation.

---

## Summary Statistics

| Priority | Count | Status |
|----------|-------|--------|
| 🔴 **CRITICAL** (Must Define Before) | 0 | ✅ ALL RESOLVED |
| 🟡 **HIGH** (Must Define Before/Early) | 2 | Blocking |
| 🟢 **MEDIUM** (Should Define Before/During) | 5 | Non-blocking |
| 🔵 **LOW** (Can Define During) | 1 | Non-blocking |
| ✅ **RESOLVED** | 6 | Complete |
| **TOTAL** | 14 | |

---

## Recommended Pre-Implementation Phase

### Week 1: Critical Definitions (Blocking Issues)
**Goal**: Resolve all 🔴 CRITICAL and 🟡 HIGH priority items

**Tasks**:
1. **API Requestor Protocol** (2 days)
   - Define complete protocol interface
   - Create example implementations for 2-3 provider types
   - Document relationship to `AIServiceProvider`

2. **Schema System Decision** (1 day)
   - Decide: Swift Codable only for Phase 6, or include JSON Schema?
   - Document scope and rationale

3. **TextPack Coordinator Actor** (2 days)
   - Define complete actor interface
   - Research SwiftGuion API integration
   - Design thread-safe bundle management

4. **Error Hierarchy** (1 day)
   - Define complete error types
   - Add localization support
   - Document error handling patterns

5. **Three-View Pattern** (1 day)
   - Define protocols for all three views
   - Design filtering patterns
   - Create basic example implementation

### Week 2: Important Definitions (Non-blocking, High Value)
**Goal**: Resolve 🟢 MEDIUM priority items that provide clarity

**Tasks**:
1. Provider capability extensions
2. Validation middleware architecture
3. SwiftData model base structure
4. Configuration persistence strategy
5. Multi-type provider UI pattern

### After Definitions: Phase 6 Implementation (3 weeks)
Proceed with Phase 6 implementation once critical definitions are complete.

---

## Next Steps

1. **Review this document** with the team/user
2. **Prioritize** which items to tackle first
3. **Schedule** definition meetings/sessions
4. **Document** decisions in corresponding files
5. **Update** METHODOLOGY.md with concrete specifications
6. **Begin** Phase 6 implementation

---

**Document Version**: 1.0
**Last Updated**: 2025-10-12
**Next Review**: After critical definitions are complete
