import XCTest
import SwiftData
@testable import SwiftHablare

@MainActor
final class SpeakableItemTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() async throws {
        container = try ModelContainer(
            for: SpeakableItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = ModelContext(container)
    }

    // MARK: - Initialization Tests

    func testSpeakableItemCreation() throws {
        // GIVEN
        let item = SpeakableItem(
            orderIndex: 0,
            screenplayID: "test-screenplay",
            sourceElementID: "scene-1",
            sourceElementType: "Dialogue",
            sceneID: "scene-1",
            speakableText: "JOHN says: Hello there",
            characterName: "john",
            rawCharacterName: "JOHN",
            ruleVersion: "1.0",
            includesCharacterAnnouncement: true,
            toneHint: .character
        )

        // WHEN
        context.insert(item)
        try context.save()

        // THEN
        XCTAssertNotNil(item.id)
        XCTAssertEqual(item.orderIndex, 0)
        XCTAssertEqual(item.speakableText, "JOHN says: Hello there")
        XCTAssertEqual(item.characterName, "john")
        XCTAssertEqual(item.status, .textGenerated)
        XCTAssertTrue(item.includesCharacterAnnouncement)
    }

    func testSpeakableItemPersistence() throws {
        // GIVEN
        let item = SpeakableItem(
            orderIndex: 1,
            screenplayID: "test-screenplay",
            sourceElementID: "scene-1",
            sourceElementType: "Action",
            sceneID: "scene-1",
            speakableText: "John enters the room.",
            ruleVersion: "1.0",
            toneHint: .narrative
        )

        context.insert(item)
        try context.save()
        let itemID = item.id

        // WHEN - Fetch in new context
        let newContext = ModelContext(container)
        let descriptor = FetchDescriptor<SpeakableItem>(
            predicate: #Predicate { $0.id == itemID }
        )
        let fetched = try newContext.fetch(descriptor).first

        // THEN
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.speakableText, "John enters the room.")
        XCTAssertEqual(fetched?.toneHint, .narrative)
    }

    func testSpeakableItemOrdering() throws {
        // GIVEN
        let items = [
            SpeakableItem(orderIndex: 2, screenplayID: "test-screenplay", sourceElementID: "s1", sourceElementType: "Action", speakableText: "Third", ruleVersion: "1.0"),
            SpeakableItem(orderIndex: 0, screenplayID: "test-screenplay", sourceElementID: "s1", sourceElementType: "Action", speakableText: "First", ruleVersion: "1.0"),
            SpeakableItem(orderIndex: 1, screenplayID: "test-screenplay", sourceElementID: "s1", sourceElementType: "Action", speakableText: "Second", ruleVersion: "1.0")
        ]

        for item in items {
            context.insert(item)
        }
        try context.save()

        // WHEN
        let descriptor = FetchDescriptor<SpeakableItem>(
            sortBy: [SortDescriptor(\.orderIndex)]
        )
        let sorted = try context.fetch(descriptor)

        // THEN
        XCTAssertEqual(sorted.count, 3)
        XCTAssertEqual(sorted[0].speakableText, "First")
        XCTAssertEqual(sorted[1].speakableText, "Second")
        XCTAssertEqual(sorted[2].speakableText, "Third")
    }

    func testSpeakableItemStatusTransitions() throws {
        // GIVEN
        let item = SpeakableItem(
            orderIndex: 0,
            screenplayID: "test-screenplay",
            sourceElementID: "s1",
            sourceElementType: "Dialogue",
            speakableText: "Test",
            ruleVersion: "1.0"
        )
        context.insert(item)

        // WHEN/THEN - Status progression
        XCTAssertEqual(item.status, .textGenerated)

        item.status = .audioQueued
        XCTAssertEqual(item.status, .audioQueued)

        item.status = .audioGenerating
        XCTAssertEqual(item.status, .audioGenerating)

        item.status = .audioComplete
        XCTAssertEqual(item.status, .audioComplete)
    }

    func testSpeakableItemQueryByRuleVersion() throws {
        // GIVEN
        let v1Item = SpeakableItem(orderIndex: 0, screenplayID: "test-screenplay", sourceElementID: "s1", sourceElementType: "Action", speakableText: "V1", ruleVersion: "1.0")
        let v2Item = SpeakableItem(orderIndex: 1, screenplayID: "test-screenplay", sourceElementID: "s1", sourceElementType: "Action", speakableText: "V2", ruleVersion: "2.0")

        context.insert(v1Item)
        context.insert(v2Item)
        try context.save()

        // WHEN
        let descriptor = FetchDescriptor<SpeakableItem>(
            predicate: #Predicate { $0.ruleVersion == "1.0" }
        )
        let v1Items = try context.fetch(descriptor)

        // THEN
        XCTAssertEqual(v1Items.count, 1)
        XCTAssertEqual(v1Items[0].speakableText, "V1")
    }

    func testSpeakableItemQueryByStatus() throws {
        // GIVEN
        let pending = SpeakableItem(orderIndex: 0, screenplayID: "test-screenplay", sourceElementID: "s1", sourceElementType: "Action", speakableText: "Pending", ruleVersion: "1.0")
        let complete = SpeakableItem(orderIndex: 1, screenplayID: "test-screenplay", sourceElementID: "s1", sourceElementType: "Action", speakableText: "Complete", ruleVersion: "1.0")
        complete.status = .audioComplete

        context.insert(pending)
        context.insert(complete)
        try context.save()

        // WHEN
        let descriptor = FetchDescriptor<SpeakableItem>()
        let allItems = try context.fetch(descriptor)
        let pendingItems = allItems.filter { $0.status == .textGenerated }

        // THEN
        XCTAssertEqual(pendingItems.count, 1)
        XCTAssertEqual(pendingItems[0].speakableText, "Pending")
    }
}
