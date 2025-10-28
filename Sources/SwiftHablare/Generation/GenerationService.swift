//
//  GenerationService.swift
//  SwiftHablare
//
//  Actor-based service for coordinating audio generation with safe concurrency
//

import Foundation
import SwiftData
import SwiftCompartido

/// Result of audio generation
public struct GenerationResult: Sendable {
    /// Generated audio data
    public let audioData: Data

    /// Original text that was spoken
    public let originalText: String

    /// Voice ID used for generation
    public let voiceId: String

    /// Voice name (if available)
    public let voiceName: String?

    /// Provider ID
    public let providerId: String

    /// MIME type of generated audio
    public let mimeType: String

    /// Estimated duration in seconds
    public let estimatedDuration: TimeInterval

    /// Request ID for tracking
    public let requestId: UUID

    public init(
        audioData: Data,
        originalText: String,
        voiceId: String,
        voiceName: String?,
        providerId: String,
        mimeType: String,
        estimatedDuration: TimeInterval,
        requestId: UUID = UUID()
    ) {
        self.audioData = audioData
        self.originalText = originalText
        self.voiceId = voiceId
        self.voiceName = voiceName
        self.providerId = providerId
        self.mimeType = mimeType
        self.estimatedDuration = estimatedDuration
        self.requestId = requestId
    }
}

/// Actor-based service for coordinating audio generation with safe concurrency
///
/// This service ensures thread-safe audio generation by:
/// 1. Generating audio on background thread (via actor isolation)
/// 2. Returning Sendable results to main thread
/// 3. Main thread saves to TypedDataStorage and links to GuionElementModel
///
/// ## Usage
///
/// ```swift
/// // Create service with voice provider
/// let service = GenerationService(voiceProvider: ElevenLabsVoiceProvider())
///
/// // Generate audio (happens on background thread)
/// let result = try await service.generate(
///     text: element.elementText,
///     voiceId: "voice123",
///     voiceName: "Rachel"
/// )
///
/// // Save to SwiftData (on main thread)
/// await MainActor.run {
///     let audioRecord = result.toTypedDataStorage()
///     element.generatedContent?.append(audioRecord)
///     modelContext.insert(audioRecord)
///     try? modelContext.save()
/// }
/// ```
public actor GenerationService {

    // MARK: - Properties

    /// Registry of available voice providers
    ///
    /// Note: Marked nonisolated(unsafe) to allow access from MainActor methods.
    /// Safe because: registry is only modified during init and via actor-isolated registerProvider.
    nonisolated(unsafe) private var providerRegistry: [String: VoiceProvider]

    /// Cache lifetime (default: 24 hours)
    private let cacheLifetime: TimeInterval

    // MARK: - Initialization

    /// Create a generation service
    ///
    /// ## Example
    ///
    /// ```swift
    /// let service = GenerationService()
    /// ```
    ///
    /// ## Voice Caching
    ///
    /// To enable voice caching, pass a ModelContext when calling voice fetch methods.
    /// The ModelContext must be configured with `VoiceCacheModel` in its schema:
    ///
    /// ```swift
    /// @MainActor
    /// let schema = Schema([VoiceCacheModel.self, TypedDataStorage.self])
    /// let container = try ModelContainer(for: schema)
    /// let context = ModelContext(container)
    ///
    /// // Fetch with caching
    /// let voices = try await service.fetchVoices(from: "apple", using: context)
    /// ```
    ///
    /// - Parameter cacheLifetime: How long to cache voices before refetching (default: 24 hours)
    public init(cacheLifetime: TimeInterval = 24 * 60 * 60) {
        self.cacheLifetime = cacheLifetime

        // Initialize registry with default providers
        let appleProvider = AppleVoiceProvider()
        let elevenLabsProvider = ElevenLabsVoiceProvider()

        self.providerRegistry = [
            appleProvider.providerId: appleProvider,
            elevenLabsProvider.providerId: elevenLabsProvider
        ]
    }

    // MARK: - Generation

    /// Generate audio from text using a specific provider
    ///
    /// This method runs on a background thread (actor-isolated) and is non-blocking.
    /// The result is Sendable and can be safely transferred to the main thread.
    ///
    /// - Parameters:
    ///   - text: Text to convert to speech
    ///   - providerId: Provider identifier (e.g., "apple", "elevenlabs")
    ///   - voiceId: Voice identifier from provider
    ///   - voiceName: Voice name for metadata (optional)
    ///   - mimeType: MIME type for audio (optional, derived from provider if not specified)
    /// - Returns: GenerationResult with audio data and metadata
    /// - Throws: VoiceProviderError if generation fails or provider not found
    public func generate(
        text: String,
        providerId: String,
        voiceId: String,
        voiceName: String? = nil,
        mimeType: String? = nil
    ) async throws -> GenerationResult {
        // Get provider from registry
        guard let provider = providerRegistry[providerId] else {
            throw VoiceProviderError.notConfigured
        }

        // Ensure provider is configured
        guard provider.isConfigured() else {
            throw VoiceProviderError.notConfigured
        }

        // Estimate duration before generation
        let estimatedDuration = await provider.estimateDuration(text: text, voiceId: voiceId)

        // Generate audio (this happens on background thread via actor isolation)
        let audioData = try await provider.generateAudio(text: text, voiceId: voiceId)

        // Determine MIME type from provider if not specified
        let finalMimeType: String
        if let mimeType {
            finalMimeType = mimeType
        } else {
            switch providerId {
            case "apple":
                finalMimeType = "audio/x-aiff"
            case "elevenlabs":
                finalMimeType = "audio/mpeg"
            default:
                finalMimeType = "audio/mpeg"
            }
        }

        // Create result (Sendable, can be transferred to main thread)
        return GenerationResult(
            audioData: audioData,
            originalText: text,
            voiceId: voiceId,
            voiceName: voiceName,
            providerId: providerId,
            mimeType: finalMimeType,
            estimatedDuration: estimatedDuration
        )
    }

    /// Generate audio for a GuionElementModel
    ///
    /// This is a convenience method that extracts text from the element
    /// and generates audio. The result must be saved to SwiftData on the main thread.
    ///
    /// - Parameters:
    ///   - element: GuionElementModel to generate audio for
    ///   - providerId: Provider identifier (e.g., "apple", "elevenlabs")
    ///   - voiceId: Voice identifier from provider
    ///   - voiceName: Voice name for metadata (optional)
    ///   - mimeType: MIME type for audio (optional)
    /// - Returns: GenerationResult that can be converted to TypedDataStorage
    /// - Throws: VoiceProviderError if generation fails
    public func generate(
        forElement element: GuionElementModel,
        providerId: String,
        voiceId: String,
        voiceName: String? = nil,
        mimeType: String? = nil
    ) async throws -> GenerationResult {
        return try await generate(
            text: element.elementText,
            providerId: providerId,
            voiceId: voiceId,
            voiceName: voiceName,
            mimeType: mimeType
        )
    }

    /// Check if a voice is available from a specific provider
    ///
    /// - Parameters:
    ///   - voiceId: Voice identifier to check
    ///   - providerId: Provider identifier
    /// - Returns: True if voice is available
    public func isVoiceAvailable(_ voiceId: String, from providerId: String) async -> Bool {
        guard let provider = providerRegistry[providerId] else {
            return false
        }
        return await provider.isVoiceAvailable(voiceId: voiceId)
    }

    // MARK: - Provider Registry

    /// Get all registered voice providers
    ///
    /// Returns a list of all voice providers in the registry.
    /// The default providers (Apple and ElevenLabs) are always included.
    ///
    /// - Returns: Array of registered voice providers
    nonisolated public func registeredProviders() -> [VoiceProvider] {
        return Array(providerRegistry.values)
    }

    /// Register a custom voice provider
    ///
    /// Adds a voice provider to the registry. If a provider with the same
    /// providerId already exists, it will be replaced.
    ///
    /// - Parameter provider: Voice provider to register
    public func registerProvider(_ provider: VoiceProvider) {
        providerRegistry[provider.providerId] = provider
    }

    /// Get a voice provider by its ID
    ///
    /// - Parameter providerId: Provider identifier (e.g., "apple", "elevenlabs")
    /// - Returns: Voice provider if found, nil otherwise
    nonisolated public func provider(withId providerId: String) -> VoiceProvider? {
        return providerRegistry[providerId]
    }

    /// Check if a provider is registered
    ///
    /// - Parameter providerId: Provider identifier to check
    /// - Returns: True if provider is registered
    nonisolated public func isProviderRegistered(_ providerId: String) -> Bool {
        return providerRegistry[providerId] != nil
    }

    /// Fetch voices from a specific provider by ID
    ///
    /// This method uses SwiftData caching to avoid repeatedly polling the voice provider.
    /// The cache expires after 24 hours (or the configured cacheLifetime).
    ///
    /// **Cache Behavior:**
    /// - First call: Fetches from provider and caches to SwiftData
    /// - Subsequent calls: Returns cached voices from SwiftData if valid
    /// - After expiration: Fetches fresh voices and updates SwiftData cache
    /// - Manual refresh: Use `refreshVoices(from:)` to force a refresh
    /// - No ModelContext: Always fetches fresh voices (no caching)
    ///
    /// ## Example
    ///
    /// ```swift
    /// @MainActor
    /// let service = GenerationService(
    ///     voiceProvider: AppleVoiceProvider(),
    ///     modelContext: modelContext
    /// )
    ///
    /// // First call - fetches from provider and caches
    /// let appleVoices = try await service.fetchVoices(from: "apple")
    ///
    /// // Second call - returns cached voices (fast)
    /// let cachedVoices = try await service.fetchVoices(from: "apple")
    ///
    /// // Force refresh
    /// let freshVoices = try await service.refreshVoices(from: "apple")
    /// ```
    ///
    /// - Parameters:
    ///   - providerId: Provider identifier (e.g., "apple", "elevenlabs")
    /// - Returns: Array of available voices from that provider
    /// - Throws: VoiceProviderError.notConfigured if provider not found or not configured
    public func fetchVoices(from providerId: String) async throws -> [Voice] {
        guard let provider = providerRegistry[providerId] else {
            throw VoiceProviderError.notConfigured
        }

        guard provider.isConfigured() else {
            throw VoiceProviderError.notConfigured
        }

        // Fetch voices from provider
        return try await provider.fetchVoices()
    }

    /// Fetch voices with caching support (MainActor-isolated)
    ///
    /// - Parameters:
    ///   - providerId: Provider identifier (e.g., "apple", "elevenlabs")
    ///   - modelContext: ModelContext for voice caching (must be on MainActor)
    /// - Returns: Array of available voices from that provider
    /// - Throws: VoiceProviderError.notConfigured if provider not found or not configured
    @MainActor
    public func fetchVoices(from providerId: String, using modelContext: ModelContext) async throws -> [Voice] {
        guard let provider = providerRegistry[providerId] else {
            throw VoiceProviderError.notConfigured
        }

        guard provider.isConfigured() else {
            throw VoiceProviderError.notConfigured
        }

        // Check SwiftData cache first
        let cachedVoices = try fetchCachedVoices(for: providerId, using: modelContext)
        if !cachedVoices.isEmpty {
            return cachedVoices
        }

        // Cache miss - fetch fresh voices
        let voices = try await provider.fetchVoices()

        // Save to cache
        try saveCachedVoices(voices, for: providerId, using: modelContext)

        return voices
    }

    /// Fetch cached voices from SwiftData
    @MainActor
    private func fetchCachedVoices(for providerId: String, using modelContext: ModelContext) throws -> [Voice] {
        let descriptor = VoiceCacheModel.fetchDescriptor(forProvider: providerId)
        let cachedModels = try modelContext.fetch(descriptor)

        // Filter out stale entries
        let validModels = cachedModels.filter { !$0.isStale(after: cacheLifetime) }

        // Convert to Voice objects
        return validModels.map { $0.toVoice() }
    }

    /// Save voices to SwiftData cache
    @MainActor
    private func saveCachedVoices(_ voices: [Voice], for providerId: String, using modelContext: ModelContext) throws {
        // First, remove old cached voices for this provider
        let descriptor = VoiceCacheModel.fetchDescriptor(forProvider: providerId)
        let oldCached = try modelContext.fetch(descriptor)
        for old in oldCached {
            modelContext.delete(old)
        }

        // Insert new cached voices
        for voice in voices {
            let cacheModel = VoiceCacheModel(from: voice)
            modelContext.insert(cacheModel)
        }

        // Save changes
        try modelContext.save()
    }

    /// Fetch voices from all registered and configured providers
    ///
    /// Returns a dictionary mapping provider IDs to their available voices.
    /// Only includes providers that are properly configured.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let service = GenerationService(voiceProvider: AppleVoiceProvider())
    /// let allVoices = try await service.fetchAllVoices()
    ///
    /// // Access voices by provider
    /// if let appleVoices = allVoices["apple"] {
    ///     print("Apple has \(appleVoices.count) voices")
    /// }
    /// ```
    ///
    /// - Returns: Dictionary mapping provider IDs to voice arrays
    public func fetchAllVoices() async throws -> [String: [Voice]] {
        var voicesByProvider: [String: [Voice]] = [:]

        for (providerId, provider) in providerRegistry {
            guard provider.isConfigured() else {
                continue // Skip unconfigured providers
            }

            do {
                let voices = try await fetchVoices(from: providerId)
                voicesByProvider[providerId] = voices
            } catch {
                // Skip providers that fail to fetch voices
                continue
            }
        }

        return voicesByProvider
    }

    /// Fetch voices from all providers with caching support (MainActor-isolated)
    ///
    /// - Parameter modelContext: ModelContext for voice caching (must be on MainActor)
    /// - Returns: Dictionary mapping provider IDs to voice arrays
    @MainActor
    public func fetchAllVoices(using modelContext: ModelContext) async throws -> [String: [Voice]] {
        var voicesByProvider: [String: [Voice]] = [:]

        for (providerId, provider) in providerRegistry {
            guard provider.isConfigured() else {
                continue // Skip unconfigured providers
            }

            do {
                let voices = try await fetchVoices(from: providerId, using: modelContext)
                voicesByProvider[providerId] = voices
            } catch {
                // Skip providers that fail to fetch voices
                continue
            }
        }

        return voicesByProvider
    }

    // MARK: - Cache Management

    /// Manually refresh voices for a specific provider
    ///
    /// This method bypasses the cache and fetches fresh voices from the provider,
    /// then updates the SwiftData cache with the new results.
    ///
    /// Use this when you need to force a refresh before the cache expires,
    /// such as after installing new voices or when you know the voice list has changed.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // User installed new voices
    /// let freshVoices = try await service.refreshVoices(from: "apple", using: context)
    /// ```
    ///
    /// - Parameter providerId: Provider identifier (e.g., "apple", "elevenlabs")
    /// - Returns: Freshly fetched array of voices
    /// - Throws: VoiceProviderError.notConfigured if provider not found or not configured
    public func refreshVoices(from providerId: String) async throws -> [Voice] {
        guard let provider = providerRegistry[providerId] else {
            throw VoiceProviderError.notConfigured
        }

        guard provider.isConfigured() else {
            throw VoiceProviderError.notConfigured
        }

        // Fetch fresh voices
        return try await provider.fetchVoices()
    }

    /// Refresh voices with cache update (MainActor-isolated)
    ///
    /// - Parameters:
    ///   - providerId: Provider identifier (e.g., "apple", "elevenlabs")
    ///   - modelContext: ModelContext to update cache (must be on MainActor)
    /// - Returns: Freshly fetched array of voices
    /// - Throws: VoiceProviderError.notConfigured if provider not found or not configured
    @MainActor
    public func refreshVoices(from providerId: String, using modelContext: ModelContext) async throws -> [Voice] {
        guard let provider = providerRegistry[providerId] else {
            throw VoiceProviderError.notConfigured
        }

        guard provider.isConfigured() else {
            throw VoiceProviderError.notConfigured
        }

        // Fetch fresh voices
        let voices = try await provider.fetchVoices()

        // Update SwiftData cache
        try saveCachedVoices(voices, for: providerId, using: modelContext)

        return voices
    }

    /// Clear the voice cache for a specific provider
    ///
    /// Removes all cached voices for the specified provider from SwiftData.
    /// The next call to `fetchVoices(from:using:)` will fetch fresh voices from the provider.
    ///
    /// - Parameters:
    ///   - providerId: Provider identifier to clear cache for
    ///   - modelContext: ModelContext to clear cache from (must be on MainActor)
    @MainActor
    public func clearVoiceCache(for providerId: String, using modelContext: ModelContext) throws {
        let descriptor = VoiceCacheModel.fetchDescriptor(forProvider: providerId)
        let cachedModels = try modelContext.fetch(descriptor)
        for model in cachedModels {
            modelContext.delete(model)
        }
        try modelContext.save()
    }

    /// Clear all voice caches
    ///
    /// Removes all cached voices from SwiftData.
    /// The next call to `fetchVoices(from:using:)` for any provider will fetch fresh voices.
    ///
    /// - Parameter modelContext: ModelContext to clear cache from (must be on MainActor)
    @MainActor
    public func clearAllVoiceCaches(using modelContext: ModelContext) throws {
        let descriptor = FetchDescriptor<VoiceCacheModel>()
        let allCached = try modelContext.fetch(descriptor)
        for model in allCached {
            modelContext.delete(model)
        }
        try modelContext.save()
    }

    /// Check if a provider's voice cache is valid
    ///
    /// Returns true if the provider has cached voices in SwiftData that haven't expired.
    ///
    /// - Parameters:
    ///   - providerId: Provider identifier to check
    ///   - modelContext: ModelContext to check cache in (must be on MainActor)
    /// - Returns: True if cache exists and is still valid
    @MainActor
    public func hasValidCache(for providerId: String, using modelContext: ModelContext) -> Bool {
        do {
            let cachedVoices = try fetchCachedVoices(for: providerId, using: modelContext)
            return !cachedVoices.isEmpty
        } catch {
            return false
        }
    }

    /// Generate audio for all items in a SpeakableItemList
    ///
    /// This method processes a list of speakable items sequentially:
    /// 1. Generates audio on background thread (actor-isolated)
    /// 2. Creates TypedDataStorage records on main thread
    /// 3. Saves to SwiftData after each item
    /// 4. Updates progress in real-time
    /// 5. Handles cancellation gracefully
    /// 6. Preserves partial results on error/cancellation
    ///
    /// ## Example
    ///
    /// ```swift
    /// @MainActor
    /// func generateList() async throws {
    ///     let provider = AppleVoiceProvider()
    ///     let service = GenerationService(voiceProvider: provider)
    ///
    ///     let items: [any SpeakableItem] = [
    ///         SimpleMessage(content: "Hello", voiceProvider: provider, voiceId: voiceId),
    ///         SimpleMessage(content: "World", voiceProvider: provider, voiceId: voiceId)
    ///     ]
    ///
    ///     let list = SpeakableItemList(name: "Greetings", items: items)
    ///     let records = try await service.generateList(list, to: modelContext)
    ///
    ///     print("Generated \(records.count) audio files")
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - list: SpeakableItemList to process
    ///   - context: SwiftData ModelContext for persistence
    ///   - saveInterval: How often to save (default: after each item)
    /// - Returns: Array of TypedDataStorage records that were created
    /// - Throws: VoiceProviderError if generation fails (after saving partial results)
    @MainActor
    public func generateList(
        _ list: SpeakableItemList,
        to context: ModelContext,
        saveInterval: Int = 1
    ) async throws -> [TypedDataStorage] {
        // Mark list as processing
        list.startProcessing()

        var savedRecords: [TypedDataStorage] = []

        // Process each item sequentially
        for index in 0..<list.totalCount {
            // Check for cancellation
            if list.isCancelled {
                list.completeProcessing()
                break
            }

            // Get the item
            guard let item = list.item(at: index) else {
                continue
            }

            do {
                // Extract data we need (all Sendable)
                let text = item.textToSpeak
                let voiceId = item.voiceId
                let provider = item.voiceProvider
                let providerId = provider.providerId

                // Ensure provider is configured
                guard provider.isConfigured() else {
                    throw VoiceProviderError.notConfigured
                }

                // Generate audio using the item's own voice provider
                // (not a different instance from the registry)
                let audioData = try await provider.generateAudio(
                    text: text,
                    voiceId: voiceId
                )

                // Estimate duration using the item's own voice provider
                let duration = await provider.estimateDuration(
                    text: text,
                    voiceId: voiceId
                )

                // Determine MIME type
                let mimeType: String
                switch providerId {
                case "apple":
                    mimeType = "audio/x-aiff"
                case "elevenlabs":
                    mimeType = "audio/mpeg"
                default:
                    mimeType = "audio/mpeg"
                }

                // Create TypedDataStorage record (already on main thread)
                let storage = TypedDataStorage(
                    id: UUID(),
                    providerId: providerId,
                    requestorID: "\(providerId).audio.tts",
                    mimeType: mimeType,
                    textValue: nil,
                    binaryValue: audioData,
                    prompt: text,
                    durationSeconds: duration,
                    voiceID: voiceId,
                    voiceName: nil
                )

                // Insert into SwiftData
                context.insert(storage)

                // Save at interval with proper error handling
                if (index + 1) % saveInterval == 0 || (index + 1) == list.totalCount {
                    do {
                        try context.save()
                    } catch {
                        print("Error saving audio at interval (item \(index + 1)): \(error.localizedDescription)")
                        // Don't throw yet - try to save partial results below
                        throw error
                    }
                }

                savedRecords.append(storage)

                // Update progress
                list.advanceProgress(
                    message: "Generated \(index + 1) of \(list.totalCount)"
                )

            } catch {
                // Save partial results before failing
                do {
                    try context.save()
                    print("Saved \(savedRecords.count) partial results before failure")
                } catch let saveError {
                    print("Error saving partial results: \(saveError.localizedDescription)")
                }
                list.failProcessing(with: error)
                throw error
            }
        }

        // Mark as complete - final save
        do {
            try context.save()
        } catch {
            print("Error in final save of generation list: \(error.localizedDescription)")
            list.failProcessing(with: error)
            throw error
        }

        list.completeProcessing()

        return savedRecords
    }
}

// MARK: - GenerationResult Extensions

extension GenerationResult {

    /// Convert result to TypedDataStorage for SwiftData persistence
    ///
    /// This method creates a TypedDataStorage instance from SwiftCompartido
    /// that can be inserted into SwiftData and linked to GuionElementModel.
    ///
    /// **Must be called on @MainActor**
    ///
    /// - Returns: TypedDataStorage instance ready for SwiftData
    @MainActor
    public func toTypedDataStorage() -> TypedDataStorage {
        return TypedDataStorage(
            id: requestId,
            providerId: providerId,
            requestorID: "\(providerId).audio.tts",
            mimeType: mimeType,
            textValue: nil,  // Audio is binary
            binaryValue: audioData,
            prompt: originalText,
            durationSeconds: estimatedDuration,
            voiceID: voiceId,
            voiceName: voiceName
        )
    }
}
