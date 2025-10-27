//
//  ElementGenerationButton.swift
//  Hablare
//
//  Smart button that shows either Generate or Generate All based on element type
//

import SwiftUI
import SwiftData
import SwiftCompartido
import SwiftHablare

/// A smart button that automatically selects between GenerateAudioButton and GenerateGroupButton
/// based on the screenplay element type.
///
/// ## Overview
///
/// This view analyzes the element type and displays:
/// - **GenerateGroupButton** for scene headings and section headings (grouped elements)
/// - **GenerateAudioButton** for all other elements (dialogue, action, etc.)
///
/// ## Usage in a List
///
/// ```swift
/// List(document.displayModel.elements) { element in
///     HStack {
///         // Your element display
///         Text(element.elementText)
///             .font(element.displayFont)
///
///         Spacer()
///
///         // Add generation button
///         ElementGenerationButton(
///             element: element,
///             document: document.displayModel,
///             voiceProvider: voiceProvider,
///             defaultVoiceId: defaultVoiceId,
///             service: generationService,
///             modelContext: modelContext
///         )
///     }
/// }
/// ```
///
@MainActor
public struct ElementGenerationButton: View {

    // MARK: - Properties

    /// The screenplay element to generate audio for
    let element: GuionElementModel

    /// The document containing all elements (required for group expansion)
    let document: GuionDocumentModel

    /// Voice provider for audio generation
    let voiceProvider: VoiceProvider

    /// Default voice ID to use
    let defaultVoiceId: String

    /// Generation service
    let service: GenerationService

    /// SwiftData model context
    let modelContext: ModelContext

    /// Speech options for generation
    let options: SpeechOptions

    /// Callback when generation completes
    let onComplete: ((TypedDataStorage) -> Void)?

    // MARK: - Initialization

    /// Create an element generation button
    ///
    /// - Parameters:
    ///   - element: The GuionElementModel to generate audio for
    ///   - document: The GuionDocumentModel containing all elements
    ///   - voiceProvider: Voice provider for audio generation
    ///   - defaultVoiceId: Default voice ID to use
    ///   - service: GenerationService instance
    ///   - modelContext: SwiftData ModelContext
    ///   - options: Speech generation options (default: .default)
    ///   - onComplete: Optional callback when generation completes
    public init(
        element: GuionElementModel,
        document: GuionDocumentModel,
        voiceProvider: VoiceProvider,
        defaultVoiceId: String,
        service: GenerationService,
        modelContext: ModelContext,
        options: SpeechOptions = .default,
        onComplete: ((TypedDataStorage) -> Void)? = nil
    ) {
        self.element = element
        self.document = document
        self.voiceProvider = voiceProvider
        self.defaultVoiceId = defaultVoiceId
        self.service = service
        self.modelContext = modelContext
        self.options = options
        self.onComplete = onComplete
    }

    // MARK: - Body

    public var body: some View {
        Group {
            if isGroupedElement {
                // Show GenerateGroupButton for scene/section headings
                GenerateGroupButton(
                    group: createGroup(),
                    service: service,
                    modelContext: modelContext,
                    onComplete: { records in
                        // Call onComplete for the first record if provided
                        if let first = records.first {
                            onComplete?(first)
                        }
                    }
                )
            } else {
                // Show GenerateAudioButton for regular elements
                GenerateAudioButton(
                    item: element.asSpeakable(
                        voiceProvider: voiceProvider,
                        voiceId: defaultVoiceId,
                        options: options
                    ),
                    service: service,
                    modelContext: modelContext,
                    onPlay: { record in
                        onComplete?(record)
                    }
                )
            }
        }
    }

    // MARK: - Helper Methods

    /// Determine if this element is a grouped element (scene/section heading)
    private var isGroupedElement: Bool {
        switch element.elementType {
        case .sceneHeading:
            return true
        case .sectionHeading:
            return true
        default:
            return false
        }
    }

    /// Create the appropriate SpeakableGroup for this element
    private func createGroup() -> any SpeakableGroup {
        switch element.elementType {
        case .sceneHeading:
            return element.asSceneGroup(
                document: document,
                voiceProvider: voiceProvider,
                defaultVoiceId: defaultVoiceId,
                options: options
            )

        case .sectionHeading:
            return element.asSectionGroup(
                document: document,
                voiceProvider: voiceProvider,
                defaultVoiceId: defaultVoiceId,
                options: options
            )

        default:
            // Fallback - shouldn't reach here due to isGroupedElement check
            // Return a single-item group
            return SingleElementGroup(
                element: element,
                voiceProvider: voiceProvider,
                voiceId: defaultVoiceId,
                options: options
            )
        }
    }
}

// MARK: - Single Element Group (Fallback)

/// A fallback group that contains a single element
private struct SingleElementGroup: SpeakableGroup {
    let element: GuionElementModel
    let voiceProvider: VoiceProvider
    let voiceId: String
    let options: SpeechOptions

    var groupName: String {
        element.elementText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func getGroupedElements() -> [any SpeakableItem] {
        [element.asSpeakable(
            voiceProvider: voiceProvider,
            voiceId: voiceId,
            options: options
        )]
    }
}

// MARK: - List Extension for Convenient Usage

extension GuionElementModel {
    /// Create a generation button for this element
    ///
    /// This is a convenience method for use in SwiftUI Lists.
    ///
    /// ## Example
    ///
    /// ```swift
    /// List(document.displayModel.elements) { element in
    ///     HStack {
    ///         Text(element.elementText)
    ///         Spacer()
    ///         element.generationButton(
    ///             document: document.displayModel,
    ///             voiceProvider: voiceProvider,
    ///             defaultVoiceId: voiceId,
    ///             service: service,
    ///             modelContext: context
    ///         )
    ///     }
    /// }
    /// ```
    @MainActor
    public func generationButton(
        document: GuionDocumentModel,
        voiceProvider: VoiceProvider,
        defaultVoiceId: String,
        service: GenerationService,
        modelContext: ModelContext,
        options: SpeechOptions = .default,
        onComplete: ((TypedDataStorage) -> Void)? = nil
    ) -> some View {
        ElementGenerationButton(
            element: self,
            document: document,
            voiceProvider: voiceProvider,
            defaultVoiceId: defaultVoiceId,
            service: service,
            modelContext: modelContext,
            options: options,
            onComplete: onComplete
        )
    }
}
