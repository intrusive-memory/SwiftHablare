//
//  GuionElement+SpeakableGroup.swift
//  Hablare
//
//  Extensions to make screenplay elements conform to SpeakableGroup for batch audio generation
//

import Foundation
import SwiftCompartido
import SwiftHablare

// MARK: - GuionElementModel + SpeakableGroup for Scene Headings

extension GuionElementModel {
    /// Make a scene heading element into a SpeakableGroup containing all elements in the scene
    ///
    /// This extension allows you to generate audio for an entire scene with one action.
    /// It includes all elements from this scene heading until the next scene heading.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Find a scene heading element
    /// let sceneHeading = document.displayModel.elements.first { $0.elementType == .sceneHeading }
    ///
    /// // Use it as a SpeakableGroup
    /// GenerateGroupButton(
    ///     group: sceneHeading.asSceneGroup(
    ///         document: document.displayModel,
    ///         voiceProvider: provider,
    ///         defaultVoiceId: voiceId
    ///     ),
    ///     service: service,
    ///     modelContext: context
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - document: The GuionDocumentModel containing all elements
    ///   - voiceProvider: The voice provider for audio generation
    ///   - defaultVoiceId: Default voice ID for elements without character-specific voices
    ///   - options: Speech generation options (default: .default)
    /// - Returns: A SpeakableGroup representing the entire scene
    public func asSceneGroup(
        document: GuionDocumentModel,
        voiceProvider: VoiceProvider,
        defaultVoiceId: String,
        options: SpeechOptions = .default
    ) -> SceneGroup {
        SceneGroup(
            sceneHeading: self,
            document: document,
            voiceProvider: voiceProvider,
            defaultVoiceId: defaultVoiceId,
            options: options
        )
    }

    /// Make a section heading element into a SpeakableGroup containing all elements in the section
    ///
    /// This extension allows you to generate audio for an entire section (Act, Sequence, etc.)
    /// with one action. It includes all elements from this section heading until the next
    /// section heading of the same or higher level.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Find a section heading element (e.g., Act 1)
    /// let actHeading = document.displayModel.elements.first {
    ///     if case .sectionHeading(let level) = $0.elementType, level == 2 {
    ///         return true
    ///     }
    ///     return false
    /// }
    ///
    /// // Use it as a SpeakableGroup
    /// GenerateGroupButton(
    ///     group: actHeading.asSectionGroup(
    ///         document: document.displayModel,
    ///         voiceProvider: provider,
    ///         defaultVoiceId: voiceId
    ///     ),
    ///     service: service,
    ///     modelContext: context
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - document: The GuionDocumentModel containing all elements
    ///   - voiceProvider: The voice provider for audio generation
    ///   - defaultVoiceId: Default voice ID for elements without character-specific voices
    ///   - options: Speech generation options (default: .default)
    /// - Returns: A SpeakableGroup representing the entire section
    public func asSectionGroup(
        document: GuionDocumentModel,
        voiceProvider: VoiceProvider,
        defaultVoiceId: String,
        options: SpeechOptions = .default
    ) -> SectionGroup {
        SectionGroup(
            sectionHeading: self,
            document: document,
            voiceProvider: voiceProvider,
            defaultVoiceId: defaultVoiceId,
            options: options
        )
    }
}

// MARK: - SceneGroup

/// A SpeakableGroup representing all elements in a scene
///
/// Includes all elements from a scene heading until the next scene heading (or end of document).
public struct SceneGroup: SpeakableGroup {
    let sceneHeading: GuionElementModel
    let document: GuionDocumentModel
    let voiceProvider: VoiceProvider
    let defaultVoiceId: String
    let options: SpeechOptions

    public var groupName: String {
        // Extract scene heading text for display
        let text = sceneHeading.elementText.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? "Scene" : text
    }

    public var groupDescription: String? {
        let elements = getGroupedElements()
        return "\(elements.count) elements in scene"
    }

    public func getGroupedElements() -> [any SpeakableItem] {
        // Find the index of this scene heading
        guard let sceneIndex = document.elements.firstIndex(where: { $0.id == sceneHeading.id }) else {
            return []
        }

        // Find the next scene heading (or end of document)
        let nextSceneIndex = document.elements[(sceneIndex + 1)...].firstIndex { element in
            element.elementType == .sceneHeading
        } ?? document.elements.endIndex

        // Get all elements in this scene
        let sceneElements = Array(document.elements[sceneIndex..<nextSceneIndex])

        // Convert to SpeakableItem
        return sceneElements.map { element in
            element.asSpeakable(
                voiceProvider: voiceProvider,
                voiceId: defaultVoiceId, // TODO: Support character-specific voices
                options: options
            )
        }
    }
}

// MARK: - SectionGroup

/// A SpeakableGroup representing all elements in a section (Act, Sequence, etc.)
///
/// Includes all elements from a section heading until the next section heading of the same
/// or higher level (or end of document).
public struct SectionGroup: SpeakableGroup {
    let sectionHeading: GuionElementModel
    let document: GuionDocumentModel
    let voiceProvider: VoiceProvider
    let defaultVoiceId: String
    let options: SpeechOptions

    public var groupName: String {
        // Extract section heading text and level
        let text = sectionHeading.elementText.trimmingCharacters(in: CharacterSet(charactersIn: "# \n"))

        // Get the section level for display
        if case .sectionHeading(let level) = sectionHeading.elementType {
            let prefix = switch level {
            case 1: "Title"
            case 2: "Act"
            case 3: "Sequence"
            case 4: "Scene Group"
            case 5: "Subscene"
            case 6: "Beat"
            default: "Section"
            }
            return text.isEmpty ? prefix : "\(prefix): \(text)"
        }

        return text.isEmpty ? "Section" : text
    }

    public var groupDescription: String? {
        let elements = getGroupedElements()
        return "\(elements.count) elements in section"
    }

    public func getGroupedElements() -> [any SpeakableItem] {
        // Find the index of this section heading
        guard let sectionIndex = document.elements.firstIndex(where: { $0.id == sectionHeading.id }) else {
            return []
        }

        // Get the level of this section heading
        guard case .sectionHeading(let currentLevel) = sectionHeading.elementType else {
            return []
        }

        // Find the next section heading of same or higher level (or end of document)
        let nextSectionIndex = document.elements[(sectionIndex + 1)...].firstIndex { element in
            if case .sectionHeading(let level) = element.elementType {
                return level <= currentLevel  // Same or higher level (lower number)
            }
            return false
        } ?? document.elements.endIndex

        // Get all elements in this section
        let sectionElements = Array(document.elements[sectionIndex..<nextSectionIndex])

        // Recursively expand nested groups (scenes and lower-level sections)
        var speakableItems: [any SpeakableItem] = []

        for element in sectionElements {
            // Check if this element is a scene heading - expand it as a SceneGroup
            if element.elementType == .sceneHeading {
                let sceneGroup = element.asSceneGroup(
                    document: document,
                    voiceProvider: voiceProvider,
                    defaultVoiceId: defaultVoiceId,
                    options: options
                )
                speakableItems.append(contentsOf: sceneGroup.getGroupedElements())
            }
            // Check if this element is a lower-level section heading - expand it recursively
            else if case .sectionHeading(let elementLevel) = element.elementType,
                    elementLevel > currentLevel {
                let nestedSectionGroup = element.asSectionGroup(
                    document: document,
                    voiceProvider: voiceProvider,
                    defaultVoiceId: defaultVoiceId,
                    options: options
                )
                speakableItems.append(contentsOf: nestedSectionGroup.getGroupedElements())
            }
            // Regular element - convert to SpeakableItem
            else {
                speakableItems.append(
                    element.asSpeakable(
                        voiceProvider: voiceProvider,
                        voiceId: defaultVoiceId,
                        options: options
                    )
                )
            }
        }

        return speakableItems
    }
}

// MARK: - GuionDocumentModel + SpeakableGroup for Full Screenplay

extension GuionDocumentModel {
    /// Make the entire screenplay into a SpeakableGroup
    ///
    /// This extension allows you to generate audio for the entire screenplay with one action.
    /// It includes all elements from the document.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Use the entire document as a SpeakableGroup
    /// GenerateGroupButton(
    ///     group: document.displayModel.asFullScreenplayGroup(
    ///         voiceProvider: provider,
    ///         defaultVoiceId: voiceId,
    ///         options: .dialogueOnly
    ///     ),
    ///     service: service,
    ///     modelContext: context
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - voiceProvider: The voice provider for audio generation
    ///   - defaultVoiceId: Default voice ID for elements without character-specific voices
    ///   - options: Speech generation options (default: .default)
    /// - Returns: A SpeakableGroup representing the entire screenplay
    public func asFullScreenplayGroup(
        voiceProvider: VoiceProvider,
        defaultVoiceId: String,
        options: SpeechOptions = .default
    ) -> FullScreenplayGroup {
        FullScreenplayGroup(
            document: self,
            voiceProvider: voiceProvider,
            defaultVoiceId: defaultVoiceId,
            options: options
        )
    }
}

// MARK: - FullScreenplayGroup

/// A SpeakableGroup representing all elements in the screenplay
///
/// Includes every element in the document.
public struct FullScreenplayGroup: SpeakableGroup {
    let document: GuionDocumentModel
    let voiceProvider: VoiceProvider
    let defaultVoiceId: String
    let options: SpeechOptions

    public var groupName: String {
        // Try to get title from title page
        if let titleEntry = document.titlePage.first(where: { $0.key.lowercased() == "title" }),
           let titleValue = titleEntry.values.first, !titleValue.isEmpty {
            return titleValue
        }

        // Fall back to filename
        return document.filename ?? "Screenplay"
    }

    public var groupDescription: String? {
        let sceneCount = document.elements.filter { $0.elementType == .sceneHeading }.count
        return "\(document.elements.count) elements, \(sceneCount) scenes"
    }

    public func getGroupedElements() -> [any SpeakableItem] {
        // Recursively expand nested groups (top-level sections and scenes)
        var speakableItems: [any SpeakableItem] = []

        for element in document.elements {
            // Check if this element is a top-level section heading (e.g., Act, Title)
            // Expand it as a SectionGroup which will recursively expand its contents
            if case .sectionHeading(let level) = element.elementType, level <= 2 {
                let sectionGroup = element.asSectionGroup(
                    document: document,
                    voiceProvider: voiceProvider,
                    defaultVoiceId: defaultVoiceId,
                    options: options
                )
                speakableItems.append(contentsOf: sectionGroup.getGroupedElements())
            }
            // Check if this element is a scene heading - expand it as a SceneGroup
            else if element.elementType == .sceneHeading {
                let sceneGroup = element.asSceneGroup(
                    document: document,
                    voiceProvider: voiceProvider,
                    defaultVoiceId: defaultVoiceId,
                    options: options
                )
                speakableItems.append(contentsOf: sceneGroup.getGroupedElements())
            }
            // Regular element - convert to SpeakableItem
            else {
                speakableItems.append(
                    element.asSpeakable(
                        voiceProvider: voiceProvider,
                        voiceId: defaultVoiceId,
                        options: options
                    )
                )
            }
        }

        return speakableItems
    }
}

// MARK: - Helper Extensions

extension GuionDocumentModel {
    /// Get all scene headings in the document
    ///
    /// Useful for displaying a list of scenes that can be individually generated.
    ///
    /// - Returns: Array of GuionElementModel scene headings
    public var sceneHeadings: [GuionElementModel] {
        elements.filter { $0.elementType == .sceneHeading }
    }

    /// Get all section headings in the document
    ///
    /// Useful for displaying a hierarchical list of sections.
    ///
    /// - Returns: Array of GuionElementModel section headings
    public var sectionHeadings: [GuionElementModel] {
        elements.filter {
            if case .sectionHeading = $0.elementType {
                return true
            }
            return false
        }
    }

    /// Get all section headings of a specific level
    ///
    /// - Parameter level: The section level (1=Title, 2=Act, 3=Sequence, etc.)
    /// - Returns: Array of GuionElementModel section headings at that level
    public func sectionHeadings(atLevel level: Int) -> [GuionElementModel] {
        elements.filter {
            if case .sectionHeading(let headingLevel) = $0.elementType {
                return headingLevel == level
            }
            return false
        }
    }
}
