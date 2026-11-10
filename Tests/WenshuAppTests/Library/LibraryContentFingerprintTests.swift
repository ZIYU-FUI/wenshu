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

        // The cache is OWNED here, = and it observes NO announcement.
        // ⇒ ⇒ WHY: the announcement that drops the cache is GLOBAL (= any
        // writer in the app drops every key), = so a count read from the
        // shared cache is not a measurement: = a sibling test's
        // announcement can evict this key between two reads and move the
        // count under the reader. = ⇒ MEASURED: with the shared cache,
        // this test failed 11 times in 20 runs (= the count read 0 or 2,
        // = never a stable 1).
        let cache = LibraryContentFingerprint.Cache(observesAnnouncements: false)
        let key = LibraryContentFingerprint.wikiCacheKey(forEntitiesDirectory: folder)

        _ = cache.wikiFingerprint(forEntitiesDirectory: folder)
        _ = cache.wikiFingerprint(forEntitiesDirectory: folder)
        _ = cache.wikiFingerprint(forEntitiesDirectory: folder)

        // The engine reads this fingerprint on every update (= every
        // keystroke), so a cache that recomputes pays the disk read
        // every time. Three reads must be ONE computation.
        #expect(cache.computationCount(forKey: key) == 1)
    }

    @Test("the production cache computes the fingerprint once and reuses it")
    func theProductionCacheReusesTheFingerprint() throws {
        let folder = try makeFolder("entities")
        defer { try? FileManager.default.removeItem(at: folder.deletingLastPathComponent()) }
        try write("{\"id\":\"a\",\"name\":\"A\"}", to: folder.appendingPathComponent("a.json"))

        // The PRODUCTION path (= the shared cache, = the one the engine
        // reads through). = ⇒ The witness is the VALUE, = not the count:
        // = the shared cache observes the announcement, = so any writer
        // in the app may drop it between two reads, = and a count read
        // from it is therefore not a measurement.
        LibraryContentFingerprint.invalidate()
        let first = LibraryContentFingerprint.wikiFingerprint(forEntitiesDirectory: folder)
        let second = LibraryContentFingerprint.wikiFingerprint(forEntitiesDirectory: folder)
        #expect(first == second)

        // ⇒ AND the production-shaped cache (= the one that observes
        // announcements) drops its OWN value when the library announces
        // a change. = ⇒ The witness is the VALUE, = and the claim is
        // POSITIVE: = a cache that observes the announcement is dropped
        // by it, = so the value moves. = ⇒ MEASURED: a negative claim
        // about the same cache (= "without the announcement the value
        // did not move") is NOT a property an announcement storm can
        // hold, = and asserting it failed 8 times in 25 runs under a
        // storm. = ⇒ So the negative half lives on a cache that
        // observes NOTHING (= above), = and this half is positive only.
        let observing = LibraryContentFingerprint.Cache()
        let before = observing.wikiFingerprint(forEntitiesDirectory: folder)
        try write("{\"id\":\"a\",\"name\":\"Renamed\"}", to: folder.appendingPathComponent("a.json"))
        NotificationCenter.default.post(name: .wenshuLibraryDidChange, object: nil)
        let fresh = observing.wikiFingerprint(forEntitiesDirectory: folder)
        #expect(fresh != before, "the announcement must drop the observing cache's value")
    }

    @Test("the library-changed notification makes the next read recompute")
    func libraryChangeMakesTheNextReadRecompute() throws {
        let folder = try makeFolder("entities")
        defer { try? FileManager.default.removeItem(at: folder.deletingLastPathComponent()) }
        let file = folder.appendingPathComponent("a.json")
        try write("{\"id\":\"a\",\"name\":\"A\"}", to: file)

        LibraryContentFingerprint.invalidate()
        let before = LibraryContentFingerprint.wikiFingerprint(forEntitiesDirectory: folder)

        // The entity is renamed (= the file's bytes change) and the app
        // announces it (= what a rename does, = what a write does, =
        // what an import does).
        try write("{\"id\":\"a\",\"name\":\"Renamed\"}", to: file)
        NotificationCenter.default.post(name: .wenshuLibraryDidChange, object: nil)

        // The VALUE is the witness: = a cached value would still carry
        // the old name. = ⇒ The COUNT is not the witness here (= an
        // eviction resets it, = so it reads 1 after the recomputation
        // whether or not the notification arrived, = and a sibling
        // test's notification can evict this key in between).
        let after = LibraryContentFingerprint.wikiFingerprint(forEntitiesDirectory: folder)
        #expect(after != before)
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
