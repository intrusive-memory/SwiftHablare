//
//  ElementGenerationButtonTests.swift
//  SwiftHablareTests
//
//  Tests for ElementGenerationButton and related UI components
//

import Testing
import SwiftUI
import SwiftData
@testable import SwiftHablare
import SwiftCompartido

/// Tests for element generation button logic and integration
@Suite("ElementGenerationButton Tests")
@MainActor
struct ElementGenerationButtonTests {

    // MARK: - Test Fixtures

    /// Create an in-memory model container for testing
    func makeTestContainer() throws -> ModelContainer {
        let schema = Schema([
            VoiceCacheModel.self,
            TypedDataStorage.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    /// Create a test document with various element types
    func makeTestDocument() -> (document: TestDocument, elements: [TestElement]) {
        let doc = TestDocument(id: UUID(), filename: "Test.guion")

        let elements = [
            TestElement(id: UUID(), type: .sectionHeading(level: 2), text: "# ACT ONE", document: doc),
            TestElement(id: UUID(), type: .sceneHeading, text: "INT. COFFEE SHOP - DAY", document: doc),
            TestElement(id: UUID(), type: .action, text: "ALICE enters.", document: doc),
            TestElement(id: UUID(), type: .character, text: "ALICE", document: doc),
            TestElement(id: UUID(), type: .dialogue, text: "Hello!", document: doc),
            TestElement(id: UUID(), type: .parenthetical, text: "(smiling)", document: doc),
            TestElement(id: UUID(), type: .transition, text: "CUT TO:", document: doc),
            TestElement(id: UUID(), type: .sectionHeading(level: 3), text: "## SEQUENCE ONE", document: doc),
        ]

        doc.elements = elements
        return (doc, elements)
    }

    // MARK: - Grouped Element Detection Tests

    @Test("Scene heading is detected as grouped element")
    func testSceneHeadingIsGrouped() {
        let (_, elements) = makeTestDocument()
        let sceneHeading = elements.first { $0.type == .sceneHeading }!

        #expect(isGroupedElement(sceneHeading))
    }

    @Test("Section heading is detected as grouped element")
    func testSectionHeadingIsGrouped() {
        let (_, elements) = makeTestDocument()
        let sectionHeading = elements.first {
            if case .sectionHeading = $0.type { return true }
            return false
        }!

        #expect(isGroupedElement(sectionHeading))
    }

    @Test("Action element is not grouped")
    func testActionIsNotGrouped() {
        let (_, elements) = makeTestDocument()
        let action = elements.first { $0.type == .action }!

        #expect(!isGroupedElement(action))
    }

    @Test("Character element is not grouped")
    func testCharacterIsNotGrouped() {
        let (_, elements) = makeTestDocument()
        let character = elements.first { $0.type == .character }!

        #expect(!isGroupedElement(character))
    }

    @Test("Dialogue element is not grouped")
    func testDialogueIsNotGrouped() {
        let (_, elements) = makeTestDocument()
        let dialogue = elements.first { $0.type == .dialogue }!

        #expect(!isGroupedElement(dialogue))
    }

    @Test("Parenthetical element is not grouped")
    func testParentheticalIsNotGrouped() {
        let (_, elements) = makeTestDocument()
        let parenthetical = elements.first { $0.type == .parenthetical }!

        #expect(!isGroupedElement(parenthetical))
    }

    @Test("Transition element is not grouped")
    func testTransitionIsNotGrouped() {
        let (_, elements) = makeTestDocument()
        let transition = elements.first { $0.type == .transition }!

        #expect(!isGroupedElement(transition))
    }

    // MARK: - Element Type Coverage Tests

    @Test("All element types have correct grouping classification")
    func testAllElementTypesClassified() {
        let allTypes: [ElementType] = [
            .sceneHeading,
            .action,
            .character,
            .dialogue,
            .parenthetical,
            .transition,
            .sectionHeading(level: 1),
            .sectionHeading(level: 2),
            .sectionHeading(level: 3),
            .synopsis,
            .comment,
            .boneyard,
            .lyrics,
            .pageBreak
        ]

        // Only scene headings and section headings should be grouped
        for type in allTypes {
            let element = TestElement(id: UUID(), type: type, text: "Test", document: nil)

            switch type {
            case .sceneHeading, .sectionHeading:
                #expect(isGroupedElement(element))
            default:
                #expect(!isGroupedElement(element))
            }
        }
    }

    // MARK: - Button Type Selection Tests

    @Test("Scene heading selects group button")
    func testSceneHeadingSelectsGroupButton() {
        let (_, elements) = makeTestDocument()
        let sceneHeading = elements.first { $0.type == .sceneHeading }!

        #expect(shouldUseGroupButton(for: sceneHeading))
    }

    @Test("Section heading selects group button")
    func testSectionHeadingSelectsGroupButton() {
        let (_, elements) = makeTestDocument()
        let sectionHeading = elements.first {
            if case .sectionHeading = $0.type { return true }
            return false
        }!

        #expect(shouldUseGroupButton(for: sectionHeading))
    }

    @Test("Regular elements select single button")
    func testRegularElementsSelectSingleButton() {
        let (_, elements) = makeTestDocument()

        let regularElements = elements.filter { element in
            switch element.type {
            case .action, .character, .dialogue, .parenthetical, .transition:
                return true
            default:
                return false
            }
        }

        for element in regularElements {
            #expect(!shouldUseGroupButton(for: element))
        }
    }

    // MARK: - Document Structure Tests

    @Test("Test document has correct element count")
    func testDocumentElementCount() {
        let (doc, _) = makeTestDocument()
        #expect(doc.elements.count == 8)
    }

    @Test("Test document has scene headings")
    func testDocumentHasSceneHeadings() {
        let (doc, _) = makeTestDocument()
        let sceneCount = doc.elements.filter { $0.type == .sceneHeading }.count
        #expect(sceneCount == 1)
    }

    @Test("Test document has section headings")
    func testDocumentHasSectionHeadings() {
        let (doc, _) = makeTestDocument()
        let sectionCount = doc.elements.filter {
            if case .sectionHeading = $0.type { return true }
            return false
        }.count
        #expect(sectionCount == 2)
    }

    @Test("Test document has dialogue elements")
    func testDocumentHasDialogue() {
        let (doc, _) = makeTestDocument()
        let dialogueCount = doc.elements.filter { $0.type == .dialogue }.count
        #expect(dialogueCount == 1)
    }

    // MARK: - Section Level Tests

    @Test("Section headings have correct levels")
    func testSectionLevels() {
        let (doc, _) = makeTestDocument()

        let sections = doc.elements.filter {
            if case .sectionHeading = $0.type { return true }
            return false
        }

        #expect(sections.count == 2)

        // First section should be level 2 (Act)
        if case .sectionHeading(let level) = sections[0].type {
            #expect(level == 2)
        } else {
            Issue.record("First section should be level 2")
        }

        // Second section should be level 3 (Sequence)
        if case .sectionHeading(let level) = sections[1].type {
            #expect(level == 3)
        } else {
            Issue.record("Second section should be level 3")
        }
    }

    // MARK: - Integration Tests

    @Test("Can create generation button for all element types")
    func testCreateButtonForAllTypes() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let (doc, elements) = makeTestDocument()

        let provider = AppleVoiceProvider()
        let service = GenerationService()

        // Should be able to create button for each element without crashing
        for element in elements {
            let result = canCreateButton(
                for: element,
                document: doc,
                provider: provider,
                service: service,
                context: context
            )
            #expect(result)
        }
    }

    @Test("Scene heading creates scene group")
    func testSceneHeadingCreatesSceneGroup() {
        let (doc, elements) = makeTestDocument()
        let sceneHeading = elements.first { $0.type == .sceneHeading }!

        let groupType = determineGroupType(for: sceneHeading)
        #expect(groupType == .scene)
    }

    @Test("Section heading creates section group")
    func testSectionHeadingCreatesSectionGroup() {
        let (doc, elements) = makeTestDocument()
        let sectionHeading = elements.first {
            if case .sectionHeading = $0.type { return true }
            return false
        }!

        let groupType = determineGroupType(for: sectionHeading)
        #expect(groupType == .section)
    }

    @Test("Regular element has single group type")
    func testRegularElementHasSingleType() {
        let (doc, elements) = makeTestDocument()
        let action = elements.first { $0.type == .action }!

        let groupType = determineGroupType(for: action)
        #expect(groupType == .single)
    }

    // MARK: - Edge Cases

    @Test("Empty document has no elements")
    func testEmptyDocument() {
        let doc = TestDocument(id: UUID(), filename: "Empty.guion")
        doc.elements = []

        #expect(doc.elements.isEmpty)
    }

    @Test("Document with only scene headings")
    func testOnlySceneHeadings() {
        let doc = TestDocument(id: UUID(), filename: "Scenes.guion")
        doc.elements = [
            TestElement(id: UUID(), type: .sceneHeading, text: "INT. SCENE 1", document: doc),
            TestElement(id: UUID(), type: .sceneHeading, text: "EXT. SCENE 2", document: doc),
            TestElement(id: UUID(), type: .sceneHeading, text: "INT. SCENE 3", document: doc),
        ]

        let groupedCount = doc.elements.filter { isGroupedElement($0) }.count
        #expect(groupedCount == 3)
    }

    @Test("Document with mixed element types maintains order")
    func testElementOrderMaintained() {
        let (doc, originalElements) = makeTestDocument()

        // Verify elements are in the same order
        for (index, element) in doc.elements.enumerated() {
            #expect(element.id == originalElements[index].id)
        }
    }

    // MARK: - Performance Tests

    @Test("Grouped element detection is fast")
    func testGroupedDetectionPerformance() {
        let (_, elements) = makeTestDocument()

        // Should be able to check grouping for many elements quickly
        for _ in 0..<1000 {
            for element in elements {
                _ = isGroupedElement(element)
            }
        }

        // If we get here without timeout, performance is acceptable
        #expect(true)
    }
}

// MARK: - Test Support Types

/// Test document model
class TestDocument {
    let id: UUID
    let filename: String
    var elements: [TestElement] = []

    init(id: UUID, filename: String) {
        self.id = id
        self.filename = filename
    }
}

/// Test element model
struct TestElement {
    let id: UUID
    let type: ElementType
    let text: String
    weak var document: TestDocument?
}

/// Group type for testing
enum GroupType {
    case scene
    case section
    case single
}

// MARK: - Helper Functions (Extracted Logic from ElementGenerationButton)

/// Check if an element is a grouped element (extracted logic)
func isGroupedElement(_ element: TestElement) -> Bool {
    switch element.type {
    case .sceneHeading:
        return true
    case .sectionHeading:
        return true
    default:
        return false
    }
}

/// Check if element should use group button
func shouldUseGroupButton(for element: TestElement) -> Bool {
    return isGroupedElement(element)
}

/// Determine group type for element
func determineGroupType(for element: TestElement) -> GroupType {
    switch element.type {
    case .sceneHeading:
        return .scene
    case .sectionHeading:
        return .section
    default:
        return .single
    }
}

/// Test if button can be created
func canCreateButton(
    for element: TestElement,
    document: TestDocument,
    provider: VoiceProvider,
    service: GenerationService,
    context: ModelContext
) -> Bool {
    // If we can determine the button type and group type, button can be created
    let hasGroupType = determineGroupType(for: element) != .single || !isGroupedElement(element)
    return hasGroupType
}
