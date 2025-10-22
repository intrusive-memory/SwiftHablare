//
//  KeychainManagerTests.swift
//  SwiftHablareTests
//
//  Comprehensive tests for KeychainManager
//

import XCTest
@testable import SwiftHablare

final class KeychainManagerTests: XCTestCase {

    let testAccount = "test-keychain-account"
    let testAPIKey = "test_api_key_12345"

    override func setUp() {
        super.setUp()

        // Clean up any existing test keys
        try? KeychainManager.shared.deleteAPIKey(for: testAccount)
    }

    override func tearDown() {
        // Clean up test keys
        try? KeychainManager.shared.deleteAPIKey(for: testAccount)

        super.tearDown()
    }

    // MARK: - Singleton Tests

    func testSharedInstanceExists() {
        XCTAssertNotNil(KeychainManager.shared)
    }

    func testSharedInstanceIsSingleton() {
        let instance1 = KeychainManager.shared
        let instance2 = KeychainManager.shared

        XCTAssertTrue(instance1 === instance2, "Should return the same instance")
    }

    // MARK: - Save API Key Tests

    func testSaveAPIKeySucceeds() throws {
        try KeychainManager.shared.saveAPIKey(testAPIKey, for: testAccount)

        // Verify it was saved by retrieving it
        let retrieved = try KeychainManager.shared.getAPIKey(for: testAccount)
        XCTAssertEqual(retrieved, testAPIKey)
    }

    func testSaveAPIKeyOverwritesExisting() throws {
        // Save first key
        try KeychainManager.shared.saveAPIKey("first_key", for: testAccount)

        // Save second key (should overwrite)
        try KeychainManager.shared.saveAPIKey(testAPIKey, for: testAccount)

        // Verify the second key was saved
        let retrieved = try KeychainManager.shared.getAPIKey(for: testAccount)
        XCTAssertEqual(retrieved, testAPIKey)
        XCTAssertNotEqual(retrieved, "first_key")
    }

    func testSaveMultipleDifferentKeys() throws {
        let account1 = "test-account-1"
        let account2 = "test-account-2"
        let key1 = "key_1"
        let key2 = "key_2"

        defer {
            try? KeychainManager.shared.deleteAPIKey(for: account1)
            try? KeychainManager.shared.deleteAPIKey(for: account2)
        }

        try KeychainManager.shared.saveAPIKey(key1, for: account1)
        try KeychainManager.shared.saveAPIKey(key2, for: account2)

        let retrieved1 = try KeychainManager.shared.getAPIKey(for: account1)
        let retrieved2 = try KeychainManager.shared.getAPIKey(for: account2)

        XCTAssertEqual(retrieved1, key1)
        XCTAssertEqual(retrieved2, key2)
    }

    func testSaveEmptyStringAsAPIKey() throws {
        // Should be able to save empty string (though not recommended)
        try KeychainManager.shared.saveAPIKey("", for: testAccount)

        let retrieved = try KeychainManager.shared.getAPIKey(for: testAccount)
        XCTAssertEqual(retrieved, "")
    }

    func testSaveLongAPIKey() throws {
        let longKey = String(repeating: "a", count: 1000)

        try KeychainManager.shared.saveAPIKey(longKey, for: testAccount)

        let retrieved = try KeychainManager.shared.getAPIKey(for: testAccount)
        XCTAssertEqual(retrieved, longKey)
    }

    // MARK: - Get API Key Tests

    func testGetAPIKeyThrowsWhenNotFound() {
        XCTAssertThrowsError(try KeychainManager.shared.getAPIKey(for: "nonexistent-account")) { error in
            guard let keychainError = error as? KeychainManager.KeychainError else {
                XCTFail("Expected KeychainError, got \(type(of: error))")
                return
            }

            if case .notFound = keychainError {
                // Expected error
            } else {
                XCTFail("Expected KeychainError.notFound, got \(keychainError)")
            }
        }
    }

    func testGetAPIKeyReturnsCorrectValue() throws {
        try KeychainManager.shared.saveAPIKey(testAPIKey, for: testAccount)

        let retrieved = try KeychainManager.shared.getAPIKey(for: testAccount)
        XCTAssertEqual(retrieved, testAPIKey)
    }

    func testGetAPIKeyWithSpecialCharacters() throws {
        let specialKey = "key_with-special.chars!@#$%^&*()"

        try KeychainManager.shared.saveAPIKey(specialKey, for: testAccount)

        let retrieved = try KeychainManager.shared.getAPIKey(for: testAccount)
        XCTAssertEqual(retrieved, specialKey)
    }

    func testGetAPIKeyWithUnicodeCharacters() throws {
        let unicodeKey = "key_with_unicode_🔑_emoji"

        try KeychainManager.shared.saveAPIKey(unicodeKey, for: testAccount)

        let retrieved = try KeychainManager.shared.getAPIKey(for: testAccount)
        XCTAssertEqual(retrieved, unicodeKey)
    }

    // MARK: - Delete API Key Tests

    func testDeleteAPIKeySucceeds() throws {
        // Save a key
        try KeychainManager.shared.saveAPIKey(testAPIKey, for: testAccount)

        // Delete it
        try KeychainManager.shared.deleteAPIKey(for: testAccount)

        // Verify it's gone
        XCTAssertThrowsError(try KeychainManager.shared.getAPIKey(for: testAccount)) { error in
            guard let keychainError = error as? KeychainManager.KeychainError else {
                XCTFail("Expected KeychainError")
                return
            }

            if case .notFound = keychainError {
                // Expected
            } else {
                XCTFail("Expected notFound error")
            }
        }
    }

    func testDeleteNonexistentKeyDoesNotThrow() throws {
        // Deleting a key that doesn't exist should not throw
        try KeychainManager.shared.deleteAPIKey(for: "nonexistent-account")
    }

    func testDeleteKeyTwiceDoesNotThrow() throws {
        try KeychainManager.shared.saveAPIKey(testAPIKey, for: testAccount)

        try KeychainManager.shared.deleteAPIKey(for: testAccount)
        try KeychainManager.shared.deleteAPIKey(for: testAccount)
    }

    // MARK: - Has API Key Tests

    func testHasAPIKeyReturnsFalseWhenNotFound() {
        let hasKey = KeychainManager.shared.hasAPIKey(for: "nonexistent-account")
        XCTAssertFalse(hasKey)
    }

    func testHasAPIKeyReturnsTrueWhenFound() throws {
        try KeychainManager.shared.saveAPIKey(testAPIKey, for: testAccount)

        let hasKey = KeychainManager.shared.hasAPIKey(for: testAccount)
        XCTAssertTrue(hasKey)
    }

    func testHasAPIKeyReturnsFalseAfterDelete() throws {
        try KeychainManager.shared.saveAPIKey(testAPIKey, for: testAccount)

        XCTAssertTrue(KeychainManager.shared.hasAPIKey(for: testAccount))

        try KeychainManager.shared.deleteAPIKey(for: testAccount)

        XCTAssertFalse(KeychainManager.shared.hasAPIKey(for: testAccount))
    }

    // MARK: - Error Description Tests

    func testNotFoundErrorDescription() {
        let error = KeychainManager.KeychainError.notFound
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("not found"))
    }

    func testSaveFailedErrorDescription() {
        let error = KeychainManager.KeychainError.saveFailed(-1234)
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("save"))
        XCTAssertTrue(error.errorDescription!.contains("-1234"))
    }

    func testDeleteFailedErrorDescription() {
        let error = KeychainManager.KeychainError.deleteFailed(-5678)
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("delete"))
        XCTAssertTrue(error.errorDescription!.contains("-5678"))
    }

    func testInvalidDataErrorDescription() {
        let error = KeychainManager.KeychainError.invalidData
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("Invalid"))
    }

    // MARK: - Thread Safety Tests

    func testConcurrentSaveAndRetrieve() async throws {
        let accounts = (0..<10).map { "test-account-\($0)" }
        let keys = (0..<10).map { "test-key-\($0)" }

        defer {
            for account in accounts {
                try? KeychainManager.shared.deleteAPIKey(for: account)
            }
        }

        // Save keys concurrently
        await withTaskGroup(of: Void.self) { group in
            for (account, key) in zip(accounts, keys) {
                group.addTask {
                    try? KeychainManager.shared.saveAPIKey(key, for: account)
                }
            }
        }

        // Retrieve and verify
        for (account, expectedKey) in zip(accounts, keys) {
            let retrieved = try KeychainManager.shared.getAPIKey(for: account)
            XCTAssertEqual(retrieved, expectedKey)
        }
    }

    func testConcurrentDeleteOperations() async throws {
        let accounts = (0..<5).map { "test-delete-\($0)" }

        // Save keys first
        for (index, account) in accounts.enumerated() {
            try KeychainManager.shared.saveAPIKey("key-\(index)", for: account)
        }

        // Delete concurrently
        await withTaskGroup(of: Void.self) { group in
            for account in accounts {
                group.addTask {
                    try? KeychainManager.shared.deleteAPIKey(for: account)
                }
            }
        }

        // Verify all are deleted
        for account in accounts {
            XCTAssertFalse(KeychainManager.shared.hasAPIKey(for: account))
        }
    }

    // MARK: - Edge Case Tests

    func testAccountNameWithSpaces() throws {
        let accountWithSpaces = "account with spaces"
        let key = "test_key"

        defer {
            try? KeychainManager.shared.deleteAPIKey(for: accountWithSpaces)
        }

        try KeychainManager.shared.saveAPIKey(key, for: accountWithSpaces)

        let retrieved = try KeychainManager.shared.getAPIKey(for: accountWithSpaces)
        XCTAssertEqual(retrieved, key)
    }

    func testAccountNameWithSpecialCharacters() throws {
        let specialAccount = "account.with-special_chars@test"
        let key = "test_key"

        defer {
            try? KeychainManager.shared.deleteAPIKey(for: specialAccount)
        }

        try KeychainManager.shared.saveAPIKey(key, for: specialAccount)

        let retrieved = try KeychainManager.shared.getAPIKey(for: specialAccount)
        XCTAssertEqual(retrieved, key)
    }

    func testVeryLongAccountName() throws {
        let longAccount = String(repeating: "a", count: 500)
        let key = "test_key"

        defer {
            try? KeychainManager.shared.deleteAPIKey(for: longAccount)
        }

        try KeychainManager.shared.saveAPIKey(key, for: longAccount)

        let retrieved = try KeychainManager.shared.getAPIKey(for: longAccount)
        XCTAssertEqual(retrieved, key)
    }

    // MARK: - Integration Tests

    func testSaveRetrieveDeleteCycle() throws {
        let cycles = 5

        for i in 0..<cycles {
            let key = "key-\(i)"

            // Save
            try KeychainManager.shared.saveAPIKey(key, for: testAccount)

            // Retrieve
            let retrieved = try KeychainManager.shared.getAPIKey(for: testAccount)
            XCTAssertEqual(retrieved, key)

            // Has key
            XCTAssertTrue(KeychainManager.shared.hasAPIKey(for: testAccount))

            // Delete
            try KeychainManager.shared.deleteAPIKey(for: testAccount)

            // Verify deleted
            XCTAssertFalse(KeychainManager.shared.hasAPIKey(for: testAccount))
        }
    }

    // MARK: - Performance Tests

    func testSavePerformance() {
        measure {
            try? KeychainManager.shared.saveAPIKey(testAPIKey, for: testAccount)
        }
    }

    func testRetrievePerformance() throws {
        try KeychainManager.shared.saveAPIKey(testAPIKey, for: testAccount)

        measure {
            _ = try? KeychainManager.shared.getAPIKey(for: testAccount)
        }
    }

    func testDeletePerformance() throws {
        measure {
            try? KeychainManager.shared.saveAPIKey(testAPIKey, for: testAccount)
            try? KeychainManager.shared.deleteAPIKey(for: testAccount)
        }
    }
}
