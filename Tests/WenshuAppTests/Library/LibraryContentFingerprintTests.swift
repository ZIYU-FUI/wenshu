//
//  LibraryContentFingerprintTests.swift · Wenshu
//
//  Behaviour tests for the cached library content fingerprint.
//
//  The fingerprint is the engine's cache key for the wiki-links and the
//  embedded images, and the engine reads it on every `updateNSView` (=
//  every keystroke). The audit measured the previous shape at 277us per
//  editor update (= a disk read per update, = for a value that changes
//  only when the library's contents change), so the value is computed
//  once and reused until the library announces a change.
//
//  What these tests pin:
//    1. the same folder set yields the SAME fingerprint (= the value is
//       stable, = so the engine does not restyle on every update)
//    2. a changed entity file changes the wiki fingerprint (= a rename
//       still refreshes the link display, = the fingerprint's purpose)
//    3. a changed image file changes the image fingerprint
//    4. the library-changed notification drops the cache (= the next
//       read recomputes, = so the app's own writes are seen)
//    5. the cache is keyed by the folders, so two folder sets do not
//       share a value
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("library content fingerprint — the editor's per-update cache key")
struct LibraryContentFingerprintTests {
    /// A temporary folder holding one file.
    private func makeFolder(_ name: String) throws -> URL {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-fingerprint-\(UUID().uuidString)")
        let folder = base.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    private func write(_ contents: String, to url: URL) throws {
        try contents.write(to: url, atomically: true, encoding: .utf8)
    }

    @Test("the same folder set yields the SAME fingerprint")
    func sameFoldersYieldTheSameFingerprint() throws {
        let folder = try makeFolder("entities")
        defer { try? FileManager.default.removeItem(at: folder.deletingLastPathComponent()) }
        try write("{\"id\":\"a\",\"name\":\"A\"}", to: folder.appendingPathComponent("a.json"))

        let first = LibraryContentFingerprint.wikiFingerprint(forEntitiesDirectory: folder)
        let second = LibraryContentFingerprint.wikiFingerprint(forEntitiesDirectory: folder)
        #expect(first == second)
    }

    @Test("reading the fingerprint twice computes it ONCE (= the value is cached)")
    func repeatedReadsComputeTheFingerprintOnce() throws {
        let folder = try makeFolder("entities")
        defer { try? FileManager.default.removeItem(at: folder.deletingLastPathComponent()) }
        try write("{\"id\":\"a\",\"name\":\"A\"}", to: folder.appendingPathComponent("a.json"))

        // The count is per key (= this test's own folder), so no other
        // test's activity can move it (= the suite runs in parallel).
        let key = LibraryContentFingerprint.wikiCacheKey(forEntitiesDirectory: folder)
        LibraryContentFingerprint.invalidate()
        _ = LibraryContentFingerprint.wikiFingerprint(forEntitiesDirectory: folder)
        _ = LibraryContentFingerprint.wikiFingerprint(forEntitiesDirectory: folder)
        _ = LibraryContentFingerprint.wikiFingerprint(forEntitiesDirectory: folder)

        // The engine reads this fingerprint on every update (= every
        // keystroke), so a cache that recomputes pays the disk read
        // every time. Three reads must be ONE computation.
        #expect(LibraryContentFingerprint.computationCount(forKey: key) == 1)
    }

    @Test("the library-changed notification makes the next read recompute")
    func libraryChangeMakesTheNextReadRecompute() throws {
        let folder = try makeFolder("entities")
        defer { try? FileManager.default.removeItem(at: folder.deletingLastPathComponent()) }
        try write("{\"id\":\"a\",\"name\":\"A\"}", to: folder.appendingPathComponent("a.json"))

        let key = LibraryContentFingerprint.wikiCacheKey(forEntitiesDirectory: folder)
        LibraryContentFingerprint.invalidate()
        _ = LibraryContentFingerprint.wikiFingerprint(forEntitiesDirectory: folder)
        #expect(LibraryContentFingerprint.computationCount(forKey: key) == 1)

        NotificationCenter.default.post(name: .wenshuLibraryDidChange, object: nil)
        _ = LibraryContentFingerprint.wikiFingerprint(forEntitiesDirectory: folder)
        #expect(LibraryContentFingerprint.computationCount(forKey: key) == 2)
    }

    @Test("a changed entity file changes the wiki fingerprint")
    func changedEntityChangesTheWikiFingerprint() throws {
        let folder = try makeFolder("entities")
        defer { try? FileManager.default.removeItem(at: folder.deletingLastPathComponent()) }
        let file = folder.appendingPathComponent("a.json")
        try write("{\"id\":\"a\",\"name\":\"A\"}", to: file)
        let before = LibraryContentFingerprint.wikiFingerprint(forEntitiesDirectory: folder)

        // The rename the fingerprint exists for (= a new name in the
        // file, = so the link display refreshes).
        try write("{\"id\":\"a\",\"name\":\"Renamed\"}", to: file)
        LibraryContentFingerprint.invalidate()
        let after = LibraryContentFingerprint.wikiFingerprint(forEntitiesDirectory: folder)

        #expect(before != after)
    }

    @Test("a changed image file changes the image fingerprint")
    func changedImageChangesTheImageFingerprint() throws {
        let folder = try makeFolder("raw")
        defer { try? FileManager.default.removeItem(at: folder.deletingLastPathComponent()) }
        let file = folder.appendingPathComponent("pic.png")
        try write("first", to: file)
        let before = LibraryContentFingerprint.imageFingerprint(forFolders: [folder])

        try write("second-and-longer", to: file)
        LibraryContentFingerprint.invalidate()
        let after = LibraryContentFingerprint.imageFingerprint(forFolders: [folder])

        #expect(before != after)
    }

    @Test("the library-changed notification drops the cache")
    func libraryChangeNotificationDropsTheCache() throws {
        let folder = try makeFolder("entities")
        defer { try? FileManager.default.removeItem(at: folder.deletingLastPathComponent()) }
        let file = folder.appendingPathComponent("a.json")
        try write("{\"id\":\"a\",\"name\":\"A\"}", to: file)
        let before = LibraryContentFingerprint.wikiFingerprint(forEntitiesDirectory: folder)

        try write("{\"id\":\"a\",\"name\":\"Renamed\"}", to: file)
        // The app announces its own writes (= the agent's write, = the
        // import, = the delete). The fingerprint must notice.
        NotificationCenter.default.post(name: .wenshuLibraryDidChange, object: nil)
        let after = LibraryContentFingerprint.wikiFingerprint(forEntitiesDirectory: folder)

        #expect(before != after)
    }

    @Test("two folder sets do not share a fingerprint")
    func twoFolderSetsDoNotShareAFingerprint() throws {
        let one = try makeFolder("one")
        let two = try makeFolder("two")
        defer {
            try? FileManager.default.removeItem(at: one.deletingLastPathComponent())
            try? FileManager.default.removeItem(at: two.deletingLastPathComponent())
        }
        try write("{\"id\":\"a\",\"name\":\"A\"}", to: one.appendingPathComponent("a.json"))

        let first = LibraryContentFingerprint.imageFingerprint(forFolders: [one])
        let second = LibraryContentFingerprint.imageFingerprint(forFolders: [two])

        #expect(first != second)
    }
}
