//
//  SpeakableItemList.swift
//  SwiftHablare
//
//  A collection of SpeakableItem instances for sequential audio generation
//  with progress tracking and SwiftData persistence integration.
//

import Foundation
import Observation

/// A collection of SpeakableItem instances for sequential audio generation.
///
/// `SpeakableItemList` provides a structured way to manage multiple speakable items
/// that need to be processed sequentially with progress tracking. It's designed to
/// work with `GenerationService` for actor-based audio generation and automatic
/// persistence to SwiftData via SwiftCompartido's `TypedDataStorage`.
///
/// ## Features
///
/// - **Sequential Processing**: Items are processed one by one in order
/// - **Progress Tracking**: Real-time progress updates (current index, percentage)
/// - **Observable**: SwiftUI-compatible with `@Observable` macro
/// - **Cancellation Support**: Can be cancelled mid-processing
/// - **Error Handling**: Captures and reports errors during processing
/// - **Thread-Safe**: Designed to work with actor-based generation
///
/// ## Usage Example
///
/// ```swift
/// @MainActor
/// func generateSpeechList() async throws {
///     // Create your speakable items
///     let provider = AppleVoiceProvider()
///     let voices = try await provider.fetchVoices()
///     let voiceId = voices.first!.id
///
///     let items: [any SpeakableItem] = [
///         SimpleMessage(content: "Hello", voiceProvider: provider, voiceId: voiceId),
///         SimpleMessage(content: "World", voiceProvider: provider, voiceId: voiceId)
///     ]
///
///     // Create list
///     let list = SpeakableItemList(name: "Greetings", items: items)
///
///     // Generate with progress tracking
///     let service = GenerationService(voiceProvider: provider)
///     try await service.generateList(list, to: modelContext)
///
///     print("Progress: \(list.progress * 100)%")
/// }
/// ```
///
/// ## Integration Flow
///
/// ```
/// SpeakableItemList
///       ↓
/// GenerationService (actor - background processing)
///       ↓
/// VoiceProvider.generateAudio() (background)
///       ↓
/// @MainActor - TypedDataStorage creation
///       ↓
/// SwiftData persistence
/// ```
///
@Observable
@MainActor
public final class SpeakableItemList {
    // MARK: - Properties

    /// Unique identifier for this list
    public let id: UUID

    /// Display name for this list
    public let name: String

    /// When this list was created
    public let createdAt: Date

    /// Total number of items in the list
    public let totalCount: Int

    /// Current processing index (0-based)
    public private(set) var currentIndex: Int = 0

    /// Whether the list is currently being processed
    public private(set) var isProcessing: Bool = false

    /// Whether processing has been cancelled
    public private(set) var isCancelled: Bool = false

    /// Error that occurred during processing (if any)
    public private(set) var error: Error?

    /// Current status message
    public private(set) var statusMessage: String = "Ready"

    /// The items to be processed
    private let items: [any SpeakableItem]

    // MARK: - Computed Properties

    /// Current progress as a value from 0.0 to 1.0
    public var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(currentIndex) / Double(totalCount)
    }

    /// Whether all items have been processed
    public var isComplete: Bool {
        currentIndex >= totalCount && !isProcessing
    }

    /// Whether processing failed
    public var hasFailed: Bool {
        error != nil
    }

    // MARK: - Initialization

    /// Create a new SpeakableItemList
    ///
    /// - Parameters:
    ///   - name: Display name for this list
    ///   - items: Array of SpeakableItem instances to process
    public init(name: String, items: [any SpeakableItem]) {
        self.id = UUID()
        self.name = name
        self.items = items
        self.totalCount = items.count
        self.createdAt = Date()
    }

    // MARK: - Public Methods

    /// Get the item at the specified index
    ///
    /// - Parameter index: Zero-based index
    /// - Returns: The SpeakableItem at that index, or nil if out of bounds
    public func item(at index: Int) -> (any SpeakableItem)? {
        guard index >= 0 && index < items.count else { return nil }
        return items[index]
    }

    /// Get all items in the list
    ///
    /// - Returns: Array of all SpeakableItem instances
    public func allItems() -> [any SpeakableItem] {
        return items
    }

    /// Cancel processing of this list
    ///
    /// This sets the cancellation flag. The GenerationService checks this flag
    /// between items and will stop processing gracefully.
    public func cancel() {
        isCancelled = true
        statusMessage = "Cancelled"
    }

    /// Reset the list to its initial state
    ///
    /// This allows the list to be processed again from the beginning.
    /// Only callable when not currently processing.
    public func reset() {
        guard !isProcessing else { return }
        currentIndex = 0
        isCancelled = false
        error = nil
        statusMessage = "Ready"
    }

    // MARK: - Internal Methods (called by GenerationService)

    /// Mark processing as started
    internal func startProcessing() {
        isProcessing = true
        statusMessage = "Processing..."
    }

    /// Update progress to the next item
    ///
    /// - Parameter message: Optional status message
    internal func advanceProgress(message: String? = nil) {
        currentIndex += 1
        if let message = message {
            statusMessage = message
        } else {
            statusMessage = "Processing item \(currentIndex) of \(totalCount)"
        }
    }

    /// Mark processing as complete
    internal func completeProcessing() {
        isProcessing = false
        statusMessage = "Complete"
    }

    /// Mark processing as failed
    ///
    /// - Parameter error: The error that occurred
    internal func failProcessing(with error: Error) {
        self.error = error
        isProcessing = false
        statusMessage = "Failed: \(error.localizedDescription)"
    }
}
