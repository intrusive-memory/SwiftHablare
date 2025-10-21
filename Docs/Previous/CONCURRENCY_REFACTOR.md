# SwiftHablare Concurrency Refactor Requirements

## Overview

This document outlines the refactoring of SwiftHablare's concurrency architecture to eliminate Swift Data race conditions by separating API request execution from SwiftData persistence operations.

## Goals

1. **Eliminate Race Conditions**: All SwiftData ModelContext operations must occur on the main actor
2. **Background API Execution**: API requests execute as background processes without blocking the main thread
3. **Type Safety**: Each provider must declare its expected return type or error
4. **Request Tracking**: All requests are tracked by UUID throughout their lifecycle
5. **Immutable Responses**: API responses are immutable value types that safely cross actor boundaries

## Architecture

### Request Lifecycle

```
┌─────────────────┐
│  Any Context    │ Create request with UUID
│  (UI/Tests/etc) │
└────────┬────────┘
         │
         v
┌─────────────────┐
│ AIRequestManager│ Track request, execute in background
│   (Actor)       │
└────────┬────────┘
         │
         v
┌─────────────────┐
│ AIServiceProvider│ Execute API call, return typed data
│   (Background)   │
└────────┬────────┘
         │
         v
┌─────────────────┐
│ Immutable       │ Sendable response with UUID + data
│ AIResponseData  │
└────────┬────────┘
         │
         v
┌─────────────────┐
│ AIDataCoordinator│ Merge into SwiftData by request UUID
│  (@MainActor)    │
└─────────────────┘
```

## Core Components

### 1. AIResponseData (New)

**Location**: `Sources/SwiftHablare/Request/AIResponseData.swift`

**Purpose**: Immutable, Sendable container for API responses

**Requirements**:
- Must be `Sendable` and thread-safe
- Contains request UUID for correlation
- Includes typed data OR error (Result type)
- No SwiftData models or non-Sendable types
- Supports all provider capability types (text, audio, image, etc.)

```swift
public struct AIResponseData: Sendable {
    let requestID: UUID
    let providerID: String
    let result: Result<ResponseContent, AIServiceError>
    let metadata: [String: String]
    let receivedAt: Date
}

public enum ResponseContent: Sendable {
    case text(String)
    case data(Data)
    case audio(Data, format: AudioFormat)
    case image(Data, format: ImageFormat)
    case structured([String: Any]) // JSON-like structure
}
```

### 2. AIRequestManager (New)

**Location**: `Sources/SwiftHablare/Request/AIRequestManager.swift`

**Purpose**: Background actor that manages request lifecycle and execution

**Requirements**:
- Actor isolation for thread safety
- Tracks requests by UUID: pending → executing → completed/failed
- Executes API calls on background actors/tasks
- Stores completed responses indexed by request ID
- Provides async streams for status updates
- Does NOT interact with ModelContext directly

**Key Methods**:
```swift
public actor AIRequestManager {
    func submit(request: AIRequest, provider: any AIServiceProvider) async -> UUID
    func execute(requestID: UUID) async throws -> AIResponseData
    func response(for requestID: UUID) async -> AIResponseData?
    func status(for requestID: UUID) async -> RequestStatus
    func cancelRequest(_ requestID: UUID) async
}
```

### 3. AIDataCoordinator (New)

**Location**: `Sources/SwiftHablare/Core/AIDataCoordinator.swift`

**Purpose**: Main actor coordinator for SwiftData operations

**Requirements**:
- `@MainActor` isolated class
- Receives completed `AIResponseData`
- Merges/updates SwiftData models by request UUID
- Handles all ModelContext operations
- Validates data before persistence
- Provides callbacks/streams for UI updates

**Key Methods**:
```swift
@MainActor
public class AIDataCoordinator {
    func mergeResponse<T: PersistentModel>(
        _ response: AIResponseData,
        into model: T,
        property: ReferenceWritableKeyPath<T, V>,
        context: ModelContext
    ) throws

    func persistResponse(
        _ response: AIResponseData,
        context: ModelContext
    ) throws
}
```

### 4. AIServiceProvider Updates

**Location**: `Sources/SwiftHablare/Core/AIServiceProvider.swift`

**Requirements**:
- **Remove** `ModelContext` parameter from `generate()` method
- **Change** return type to `Result<ResponseContent, AIServiceError>`
- Each provider declares expected response type
- Providers are `Sendable` and can execute on background actors
- Errors must be typed and Sendable

**Updated Protocol**:
```swift
public protocol AIServiceProvider: Sendable {
    // ... existing identity and capability properties ...

    /// The type of response content this provider generates
    var responseType: ResponseContent.ContentType { get }

    /// Generates data based on a prompt and parameters
    /// Returns a Result with either typed content or a descriptive error
    func generate(
        prompt: String,
        parameters: [String: Any]
    ) async -> Result<ResponseContent, AIServiceError>
}
```

### 5. Request Status Tracking

**Location**: `Sources/SwiftHablare/Request/AIRequestStatus.swift`

**Purpose**: Track request state throughout lifecycle

```swift
public enum RequestStatus: Sendable {
    case pending
    case executing(progress: Double?)
    case completed(AIResponseData)
    case failed(AIServiceError)
    case cancelled
}
```

## Migration Path

### Phase 1: Create New Infrastructure
1. Create `AIResponseData` types
2. Create `AIRequestManager` actor
3. Create `AIDataCoordinator` main actor class
4. Create `RequestStatus` tracking types

### Phase 2: Update Provider Protocol
1. Add `responseType` property to `AIServiceProvider`
2. Create new `generate()` method without ModelContext
3. Keep old method as deprecated for backward compatibility
4. Update error handling to use Result types

### Phase 3: Update Existing Providers
1. Update `MockAIServiceProvider`
2. Update `ElevenLabsVoiceProvider`
3. Update `AppleVoiceProvider`
4. Each returns typed `ResponseContent`

### Phase 4: Update Request Execution
1. Modify `AIRequestExecutor` to use `AIRequestManager`
2. Update `AIPersistenceCoordinator` to use `AIDataCoordinator`
3. Update caching to work with new types

### Phase 5: Update Tests
1. Update concurrency tests
2. Update integration tests
3. Update provider tests
4. Add new tests for request lifecycle tracking

### Phase 6: Update Sample App (Future)
1. Update UI to observe request status
2. Use `AIRequestManager` for background requests
3. Use `AIDataCoordinator` for SwiftData updates
4. Add progress indicators

## Benefits

### Race Condition Prevention
- ModelContext only accessed from main actor
- No more `UnsafeModelContextWrapper` hacks
- Clear actor boundaries

### Performance
- API calls don't block main thread
- Parallel request execution without data races
- Efficient request tracking by UUID

### Type Safety
- Providers declare expected return types
- Compile-time validation of response handling
- Clear error propagation

### Testing
- Easy to test request lifecycle
- Mock responses without ModelContext
- Parallel test execution without interference

### Observability
- Track request status throughout lifecycle
- Progress updates for long-running requests
- Clear error reporting with context

## Breaking Changes

### For Provider Implementers
- Must implement new `generate()` method signature
- Must declare `responseType`
- Must return `Result<ResponseContent, AIServiceError>`

### For Library Users
- `AIRequestExecutor.execute()` signature changes
- New `AIRequestManager` and `AIDataCoordinator` APIs
- ModelContext only needed at persistence time, not during generation

## Backward Compatibility

Old APIs will be marked as deprecated with migration guides:
```swift
@available(*, deprecated, message: "Use AIRequestManager.submit() and AIDataCoordinator.mergeResponse() instead")
public func execute(request: AIRequest, provider: any AIServiceProvider, context: ModelContext) async throws -> AIResponse
```

## Performance Considerations

### Real-World Testing Required
- Initial assumption: returned data will be small enough to not bottleneck main actor
- Must measure actual performance with sample app
- May need optimization for large responses (chunking, streaming, etc.)

### Monitoring Points
1. Main actor queue depth during merges
2. Response size distribution
3. Time spent in merge operations
4. Memory usage during concurrent requests

### Optimization Strategies (if needed)
1. Batch merge operations
2. Stream large responses in chunks
3. Use background ModelContext for initial processing, then merge minimal diff on main actor
4. Prioritize UI-visible updates

## Success Criteria

1. Zero Swift Data race condition warnings in tests
2. Zero Swift Data race condition crashes in runtime
3. All tests pass with parallel execution enabled
4. No performance regression in common use cases
5. Clear migration path for existing providers
6. Comprehensive test coverage for new concurrency model

## Timeline

- Phase 1-2: Core infrastructure and protocol updates (this session)
- Phase 3-4: Provider updates and executor integration (this session)
- Phase 5: Test updates (this session)
- Phase 6: Sample app updates (future, after real-world testing)

## Open Questions

1. Should we support streaming responses for large data?
2. Do we need request prioritization?
3. Should responses be persisted to disk for crash recovery?
4. How long should completed responses be cached in AIRequestManager?
