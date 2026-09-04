//
//  BookProjectConfigStoreTests.swift · Wenshu (文枢) · B-07 ticket 015.015
//
//  Round-trip persistence tests for the per-book project-config JSON
//  store added in B-07 015.015.
//
//  Tests covered:
//    1. testLoadConfig_missing_returnsNil     — load on a fresh dir = nil
//    2. testSaveConfig_createsFile            — save writes project-config.json
//    3. testLoadConfig_afterSave_returnsPersisted — round-trip preserves all 5 fields
//    4. testDeleteConfig_removesFile          — delete removes the JSON file
//    5. testAutosaveCadence_default           — default cadence is 60
//    6. testUpdateConfig_overwritesExisting   — second save overwrites the first
//
//  Test scaffolding mirrors BookTodoStoreTests / BookKanbanStoreTests
//  (= makeRoot / makeStore helpers, a temp dir per test).

import Testing
import Foundation
@testable import WenshuApp

@Suite("BookProjectConfigStore (B-07 015.015)")
struct BookProjectConfigStoreTests {

    /// Build a fresh temp root shaped like a .ws library:
    ///   <root>/shelves/<shelf>/books/<book-id>/
    /// Returns (root, shelf, bookDir, bookId). Each test gets its
    /// own root so they can run in parallel without collision.
    private func makeRoot() throws -> (URL, URL, URL, UUID) {
        let root = URL(fileURLWithPath: "/tmp/wenshu-project-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let shelf = root.appendingPathComponent("shelves/test-shelf", isDirectory: true)
        let bookId = UUID()
        let bookDir = shelf.appendingPathComponent("books/\(bookId.uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: bookDir, withIntermediateDirectories: true)
        return (root, shelf, bookDir, bookId)
    }

    // MARK: - Test 1: load missing = nil

    @Test("loadConfig on a fresh book directory returns nil")
    func testLoadConfig_missing_returnsNil() async throws {
        let (root, _, _, bookId) = try makeRoot()
        let store = BookProjectConfigStore(projectRoot: root)
        let loaded = try await store.loadConfig(bookId: bookId)
        #expect(loaded == nil)
    }

    // MARK: - Test 2: save creates file

    @Test("saveConfig creates project-config.json inside the book directory")
    func testSaveConfig_createsFile() async throws {
        let (root, _, bookDir, bookId) = try makeRoot()
        let store = BookProjectConfigStore(projectRoot: root)
        let config = BookProjectConfig(bookId: bookId, autosaveCadenceSeconds: 30)
        try await store.saveConfig(config)

        let expectedURL = bookDir.appendingPathComponent("project-config.json")
        #expect(FileManager.default.fileExists(atPath: expectedURL.path))
    }

    // MARK: - Test 3: round-trip preserves all 5 fields

    @Test("loadConfig after save returns the persisted BookProjectConfig")
    func testLoadConfig_afterSave_returnsPersisted() async throws {
        let (root, _, _, bookId) = try makeRoot()
        let store = BookProjectConfigStore(projectRoot: root)
        let original = BookProjectConfig(
            bookId: bookId,
            autosaveCadenceSeconds: 120,
            defaultChapterTemplate: "# Chapter %n\n\n",
            kanbanEnabled: false,
            todoEnabled: false,
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        try await store.saveConfig(original)

        let loaded = try await store.loadConfig(bookId: bookId)
        #expect(loaded?.bookId == bookId)
        #expect(loaded?.autosaveCadenceSeconds == 120)
        #expect(loaded?.defaultChapterTemplate == "# Chapter %n\n\n")
        #expect(loaded?.kanbanEnabled == false)
        #expect(loaded?.todoEnabled == false)
        // updatedAt is bumped by saveConfig (= always = Date()) so
        // we don't assert equality — just that it's recent.
        #expect(loaded?.updatedAt != nil)
    }

    // MARK: - Test 4: delete removes file

    @Test("deleteConfig removes the project-config.json file")
    func testDeleteConfig_removesFile() async throws {
        let (root, _, bookDir, bookId) = try makeRoot()
        let store = BookProjectConfigStore(projectRoot: root)
        let config = BookProjectConfig(bookId: bookId)
        try await store.saveConfig(config)

        let url = bookDir.appendingPathComponent("project-config.json")
        #expect(FileManager.default.fileExists(atPath: url.path))

        try await store.deleteConfig(bookId: bookId)
        #expect(!FileManager.default.fileExists(atPath: url.path))

        // After delete, load returns nil (= file is gone).
        let loaded = try await store.loadConfig(bookId: bookId)
        #expect(loaded == nil)
    }

    // MARK: - Test 5: default autosave cadence

    @Test("BookProjectConfig autosaveCadenceSeconds defaults to 60 seconds")
    func testAutosaveCadence_default() throws {
        let bookId = UUID()
        let config = BookProjectConfig(bookId: bookId)
        #expect(config.autosaveCadenceSeconds == 60)
        // Default kanban / todo toggles both = true (= ship-stance).
        #expect(config.kanbanEnabled == true)
        #expect(config.todoEnabled == true)
        #expect(config.defaultChapterTemplate == "")
    }

    // MARK: - Test 6: update overwrites existing

    @Test("saveConfig called twice overwrites the first config (last write wins)")
    func testUpdateConfig_overwritesExisting() async throws {
        let (root, _, _, bookId) = try makeRoot()
        let store = BookProjectConfigStore(projectRoot: root)

        let first = BookProjectConfig(
            bookId: bookId,
            autosaveCadenceSeconds: 10,
            defaultChapterTemplate: "first template",
            kanbanEnabled: true,
            todoEnabled: true
        )
        try await store.saveConfig(first)

        let second = BookProjectConfig(
            bookId: bookId,
            autosaveCadenceSeconds: 300,
            defaultChapterTemplate: "second template",
            kanbanEnabled: false,
            todoEnabled: false
        )
        try await store.saveConfig(second)

        let loaded = try await store.loadConfig(bookId: bookId)
        #expect(loaded?.autosaveCadenceSeconds == 300)
        #expect(loaded?.defaultChapterTemplate == "second template")
        #expect(loaded?.kanbanEnabled == false)
        #expect(loaded?.todoEnabled == false)
    }
}