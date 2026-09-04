// WorldStoringContractTests.swift · Wenshu (文枢) · v0.26 (FCP library replica)
//
// Contract tests for the WorldStoring protocol (= ticket 023). Mirrors
// the LibraryStoringContractTests pattern at LibraryStoringContractTests.swift
// (= per-implementation factory + behavioral assertions on the contract).
//
// v0.26 FCP library replica spec at
// `.scratch/2026-08-26-fcp-library-replica/spec.md` ticket 023.

import Testing
import Foundation
@testable import WenshuApp

@Suite("WorldStoring contract")
struct WorldStoringContractTests {

    private func makeStore() throws -> (any WorldStoring, URL) {
        let root = URL(fileURLWithPath: "/tmp/wenshu-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let bookDir = root.appendingPathComponent("books/test-book", isDirectory: true)
        try FileManager.default.createDirectory(at: bookDir, withIntermediateDirectories: true)
        return (FileSystemWorldStore(bookDirectory: bookDir), bookDir)
    }

    @Test("empty world returns []")
    func emptyReturnsEmpty() throws {
        let (store, _) = try makeStore()
        let entries = try store.loadWorld()
        #expect(entries.isEmpty)
    }

    @Test("saveEntry + loadWorld roundtrips")
    func saveLoadRoundtrips() throws {
        let (store, _) = try makeStore()
        let entry = WorldEntry(bookId: UUID(), type: .geography, name: "Beijing", summary: "Capital of China")
        try store.saveEntry(entry, bodyMarkdown: "# Beijing\n\nThe capital of China.\n")
        let loaded = try store.loadWorld()
        #expect(loaded.count == 1)
        #expect(loaded[0].id == entry.id)
        #expect(loaded[0].name == "Beijing")
        #expect(loaded[0].type == .geography)
        #expect(loaded[0].summary == "Capital of China")
    }

    @Test("entryExists returns true after save, false before")
    func entryExistsCheck() throws {
        let (store, _) = try makeStore()
        let entry = WorldEntry(bookId: UUID(), type: .lore, name: "Dragon", summary: "")
        #expect(store.entryExists(id: entry.id) == false)
        try store.saveEntry(entry, bodyMarkdown: "# Dragon\n")
        #expect(store.entryExists(id: entry.id) == true)
    }

    @Test("deleteEntry removes from index and disk")
    func deleteRemovesBoth() throws {
        let (store, _) = try makeStore()
        let entry = WorldEntry(bookId: UUID(), type: .object, name: "Sword", summary: "")
        try store.saveEntry(entry, bodyMarkdown: "# Sword\n")
        #expect(store.entryExists(id: entry.id) == true)
        try store.deleteEntry(id: entry.id)
        #expect(store.entryExists(id: entry.id) == false)
        #expect(try store.loadWorld().isEmpty)
    }

    @Test("replaceEntry updates in place")
    func replaceUpdatesInPlace() throws {
        let (store, _) = try makeStore()
        let entry = WorldEntry(bookId: UUID(), type: .event, name: "Battle", summary: "Original")
        try store.saveEntry(entry, bodyMarkdown: "# Battle\n")
        let updated = WorldEntry(
            id: entry.id, bookId: entry.bookId, type: entry.type,
            name: entry.name, summary: "Updated"
        )
        try store.replaceEntry(updated, bodyMarkdown: "# Battle v2\n")
        let loaded = try store.loadWorld()
        #expect(loaded.count == 1)
        #expect(loaded[0].summary == "Updated")
    }
}