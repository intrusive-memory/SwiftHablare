# TypedDataStorage - Unified Storage Model

## Overview

`TypedDataStorage` is a consolidated SwiftData model that replaces separate models for text, audio, image, video, and embedding content. It uses MIME types to determine the appropriate storage field.

## Design Principles

### Single Model for All Content Types

Instead of separate `GeneratedTextRecord`, `GeneratedAudioRecord`, `GeneratedImageRecord`, and `GeneratedEmbeddingRecord` models, there is now one unified model:

```swift
@Model
public final class TypedDataStorage {
    public var mimeType: String
    public var textValue: String?      // For text/* MIME types
    public var binaryValue: Data?      // For audio/*, video/*, image/*
    public var fileReference: TypedDataFileReference?
    // ... metadata and other fields
}
```

### MIME Type Determines Storage

The `mimeType` field determines which storage field contains the actual content:

- **Text MIME types** → `textValue` field
  - `text/plain`
  - `text/html`
  - `text/css`
  - `text/csv`
  - `text/markdown`
  - etc.

- **Binary MIME types** → `binaryValue` field
  - `audio/*` (mpeg, wav, ogg, etc.)
  - `video/*` (mp4, webm, etc.)
  - `image/*` (png, jpeg, gif, webp, etc.)

### Out of Scope MIME Types

The following MIME types are **explicitly rejected** with `TypedDataError.unsupportedMimeType`:

- **`application/*`** - Out of scope, storage unavailable
- **`multipart/*`** - Out of scope, storage unavailable

Any MIME type that doesn't fit into `text/*` or the supported binary types (`audio/*`, `video/*`, `image/*`) will be rejected.

## MIME Type Validation

Use `MimeTypeHelper` to validate and determine storage type:

```swift
// Validate a MIME type
try MimeTypeHelper.validate("text/plain")  // ✅ OK
try MimeTypeHelper.validate("audio/mpeg")  // ✅ OK
try MimeTypeHelper.validate("application/json")  // ❌ Throws unsupportedMimeType

// Determine storage type
let storageType = try MimeTypeHelper.storageType(for: "text/plain")
// Returns: .text

let storageType = try MimeTypeHelper.storageType(for: "audio/mpeg")
// Returns: .binary
```

## Usage Examples

### Storing Text Content

```swift
let textRecord = TypedDataStorage(
    providerId: "openai",
    requestorID: "openai.text.gpt4",
    mimeType: "text/plain",
    textValue: "Generated text content here...",
    prompt: "Write a story about AI"
)

modelContext.insert(textRecord)
try modelContext.save()
```

### Storing Audio Content

```swift
let audioRecord = TypedDataStorage(
    providerId: "elevenlabs",
    requestorID: "elevenlabs.audio.tts",
    mimeType: "audio/mpeg",
    binaryValue: audioData,
    prompt: "Speak this text"
)

modelContext.insert(audioRecord)
try modelContext.save()
```

### Storing with File Reference (Large Content)

```swift
// For large content, store in external file
let fileRef = TypedDataFileReference(
    requestID: requestID,
    fileName: "audio_output.mp3",
    mimeType: "audio/mpeg",
    fileSize: Int64(audioData.count),
    checksum: calculateChecksum(audioData)
)

let audioRecord = TypedDataStorage(
    providerId: "elevenlabs",
    requestorID: "elevenlabs.audio.tts",
    mimeType: "audio/mpeg",
    binaryValue: nil,  // Data is in file
    fileReference: fileRef,
    prompt: "Speak this text"
)

modelContext.insert(audioRecord)
```

### Type-Specific Metadata

Use the `metadata` field to store type-specific information as JSON:

```swift
// Audio metadata
let audioMetadata: [String: Any] = [
    "durationSeconds": 10.5,
    "sampleRate": 44100,
    "bitRate": 128000,
    "channels": 2,
    "voiceID": "21m00Tcm4TlvDq8ikWAM",
    "voiceName": "Rachel"
]
try record.encodeMetadata(audioMetadata)

// Image metadata
let imageMetadata: [String: Any] = [
    "width": 1024,
    "height": 1024,
    "format": "png"
]
try record.encodeMetadata(imageMetadata)

// Text metadata
let textMetadata: [String: Any] = [
    "wordCount": 150,
    "characterCount": 750,
    "languageCode": "en",
    "tokenCount": 200
]
try record.encodeMetadata(textMetadata)
```

### Retrieving Content

```swift
// Get text content (validates MIME type is text/*)
let text = try record.getText()

// Get binary content
let data = try record.getBinary()

// Get content as Data (works for both text and binary)
let data = try record.getContent()

// Retrieve metadata
if let metadata = try record.decodeMetadata() {
    let duration = metadata["durationSeconds"] as? Double
    let width = metadata["width"] as? Int
}
```

## Storage Strategy

### In-Memory Storage

For small content:
- **Text**: Store directly in `textValue`
- **Binary**: Store directly in `binaryValue`

### File-Based Storage

For large content:
- Set `textValue` or `binaryValue` to `nil`
- Store content in external file
- Set `fileReference` to point to the file
- Use `getContent(from: storageArea)` to load from file

### Thresholds

Recommended thresholds for file storage:
- **Text**: >= 50KB
- **Audio**: >= 1MB
- **Image**: >= 100KB
- **Video**: Always use file storage

## Model Fields

### Identity
- `id: UUID` - Unique identifier (matches request ID)
- `providerId: String` - Provider that generated the content
- `requestorID: String` - Specific requestor identifier

### MIME Type & Content
- `mimeType: String` - MIME type determining storage field
- `textValue: String?` - Text content (for text/* MIME types)
- `binaryValue: Data?` - Binary content (for binary MIME types)
- `fileReference: TypedDataFileReference?` - External file reference

### Generation Metadata
- `prompt: String` - Generation prompt
- `modelIdentifier: String?` - Model that generated the content
- `metadata: Data?` - Type-specific metadata as JSON

### Timestamps & Cost
- `generatedAt: Date` - Generation timestamp
- `modifiedAt: Date` - Last modification timestamp
- `estimatedCost: Double?` - Estimated cost in USD

## Helper Methods

### Content Retrieval
- `getContent(from:)` - Get content as Data
- `getText(from:)` - Get text content (validates text MIME type)
- `getBinary(from:)` - Get binary content

### Metadata Management
- `encodeMetadata(_:)` - Store metadata dictionary as JSON
- `decodeMetadata()` - Retrieve metadata dictionary from JSON

### Properties
- `isFileStored: Bool` - Whether content is in external file
- `isTextContent: Bool` - Whether MIME type is text/*
- `isBinaryContent: Bool` - Whether MIME type is binary
- `contentSize: Int` - Size of stored content in bytes

### Utility
- `touch()` - Update modification timestamp

## Querying

### Find All Text Content

```swift
let descriptor = FetchDescriptor<TypedDataStorage>()
let allRecords = try modelContext.fetch(descriptor)

let textRecords = allRecords.filter { record in
    MimeTypeHelper.isTextMimeType(record.mimeType)
}
```

### Find by MIME Type

```swift
let audioRecords = allRecords.filter { record in
    record.mimeType.hasPrefix("audio/")
}
```

### Find by Provider

```swift
let openAIRecords = allRecords.filter { record in
    record.providerId == "openai"
}
```

## Error Handling

### Unsupported MIME Types

```swift
do {
    let record = TypedDataStorage(
        providerId: "test",
        requestorID: "test",
        mimeType: "application/json",  // ❌ Not supported
        textValue: "test"
    )
} catch TypedDataError.unsupportedMimeType(let mimeType, let reason) {
    print("Cannot store \(mimeType): \(reason)")
    // Output: "Cannot store application/json: application/* types are out of scope"
}
```

### File Loading Errors

```swift
do {
    let content = try record.getContent(from: storageArea)
} catch TypedDataError.fileNotFound(let path) {
    print("File not found: \(path)")
} catch TypedDataError.fileReadFailed(let path, let reason) {
    print("Failed to read \(path): \(reason)")
}
```

## Migration from Old Models

### Before (Separate Models)

```swift
// Old approach - different model for each type
let textRecord = GeneratedTextRecord(
    providerId: "openai",
    requestorID: "openai.text.gpt4",
    text: "Generated text",
    wordCount: 10,
    characterCount: 50,
    prompt: "Write"
)

let audioRecord = GeneratedAudioRecord(
    providerId: "elevenlabs",
    requestorID: "elevenlabs.audio.tts",
    audioData: data,
    format: "mp3",
    voiceID: "voice123",
    voiceName: "Rachel",
    prompt: "Speak"
)
```

### After (Unified Model)

```swift
// New approach - single model with MIME type
let textRecord = TypedDataStorage(
    providerId: "openai",
    requestorID: "openai.text.gpt4",
    mimeType: "text/plain",
    textValue: "Generated text",
    prompt: "Write",
    metadata: try? JSONSerialization.data(withJSONObject: [
        "wordCount": 10,
        "characterCount": 50
    ])
)

let audioRecord = TypedDataStorage(
    providerId: "elevenlabs",
    requestorID: "elevenlabs.audio.tts",
    mimeType: "audio/mpeg",
    binaryValue: data,
    prompt: "Speak",
    metadata: try? JSONSerialization.data(withJSONObject: [
        "format": "mp3",
        "voiceID": "voice123",
        "voiceName": "Rachel"
    ])
)
```

## Benefits

### Simplified Architecture
- One model instead of four separate models
- Consistent interface for all content types
- Easier to maintain and extend

### Flexible Storage
- MIME type-based routing to appropriate field
- Support for any text/* or binary type
- Explicit rejection of unsupported types

### Type Safety
- Validation at creation time
- Helper methods enforce correct usage
- Clear error messages for unsupported types

### Metadata Flexibility
- Type-specific metadata in JSON
- No schema changes needed for new metadata fields
- Easy to add custom metadata per content type

---

**See Also**:
- [MimeTypeHelper.swift](../Sources/SwiftHablare/TypedData/MimeTypeHelper.swift) - MIME type utilities
- [TypedDataError.swift](../Sources/SwiftHablare/TypedData/TypedDataError.swift) - Error types
- [TypedDataStorage.swift](../Sources/SwiftHablare/SwiftDataModels/TypedDataStorage.swift) - Model implementation
