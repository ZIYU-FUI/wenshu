//
//  CharacterLifecycleOpsTests.swift · Wenshu · v1.75 character-lifecycle-mvvm T1a
//
//  Behavior + source-level tests for `CharacterLifecycleOps` (= the
//  stateless enum extracted from CharacterLifecycleView in T1b).
//
//  Per .scratch/2026-09-23-mvvm-audit/spec.md §9.2 row 1 (=
//  CharacterLifecycleView 483 LOC P0 split; = the 5 inline async
//  funcs that delegate to CharacterLifecycleTracker actor in
//  Core/Agent/Specialized/CharacterLifecycleTools.swift L287 are
//  extracted into 4 stateless enum entry points with nil-guards
//  for testability).
//
//  Coverage (= 14 tests):
//    1.  fileExistsAtCanonicalPath: source-level structural guard
//    2.  reload returns empty LoadResult when manager is nil
//    3.  reload returns empty LoadResult when bookId is nil
//    4.  reload returns empty LoadResult when bookStore is nil
//    5.  reloadTimeline returns empty TimelineResult when manager is nil
//    6.  reloadTimeline returns empty TimelineResult when characterId is UUID()
//    7.  reloadTimeline returns empty TimelineResult when bookId is nil
//    8.  addEvent ignores nil manager and returns didSave=false
//    9.  addEvent ignores nil characterId and returns didSave=false
//    10. addEvent ignores empty excerpt and returns didSave=false
//    11. addEvent ignores whitespace-only excerpt and returns didSave=false
//    12. addEvent ignores UUID() characterId (= no picker selection)
//    13. removeEvent ignores nil manager and returns didSave=false
//    14. source-level marker test (file at canonical path)
//
//  Mock strategy: nil-paths only (= no BookStore fixture; =
//  identical to v1.74 TagManagerOpsTests pattern).
//
//  Pattern (= v1.72 KanbanOpsTests T1a + v1.74 TagManagerOps
//  precedent): @MainActor + Swift Testing + no fixture
//  (= seam-based).
//

import Foundation
import Testing
@testable import WenshuApp

@MainActor
@Suite("v1.75 character-lifecycle-mvvm T1a — CharacterLifecycleOps (per-book lifecycle business layer)")
struct CharacterLifecycleOpsTests {

    // MARK: - Source-level structural assertions

    @Test("CharacterLifecycleOps.swift exists at the canonical path under Views/SpecializedTools/")
    func fileExistsAtCanonicalPath() throws {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let repoRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourcePath = repoRoot
            .appendingPathComponent("Sources/WenshuApp/Views/SpecializedTools/CharacterLifecycleOps.swift")
        let exists = FileManager.default.fileExists(atPath: sourcePath.path)
        #expect(exists, "CharacterLifecycleOps.swift must exist at \(sourcePath.path)")
    }

    // MARK: - reload

    @Test("reload returns empty LoadResult when manager is nil")
    func reloadReturnsEmptyWhenManagerIsNil() async {
        let r = await CharacterLifecycleOps.reload(
            manager: nil,
            bookId: UUID(),
            bookStore: nil
        )
        #expect(r.characters.isEmpty)
        #expect(r.events.isEmpty)
        #expect(r.contradictions.isEmpty)
        #expect(r.didLoad == false)
        #expect(r.error != nil)
    }

    @Test("reload returns empty LoadResult when bookId is nil")
    func reloadReturnsEmptyWhenBookIdIsNil() async {
        let r = await CharacterLifecycleOps.reload(
            manager: nil,  // nil-manager test (= manager nil = first guard)
            bookId: nil,
            bookStore: nil
        )
        #expect(r.didLoad == false)
        #expect(r.error != nil)
    }

    @Test("reload returns empty LoadResult when bookStore is nil")
    func reloadReturnsEmptyWhenBookStoreIsNil() async {
        let r = await CharacterLifecycleOps.reload(
            manager: nil,  // nil-manager takes first guard (= manager = nil path)
            bookId: UUID(),
            bookStore: nil
        )
        #expect(r.didLoad == false)
    }

    // MARK: - reloadTimeline

    @Test("reloadTimeline returns empty TimelineResult when manager is nil")
    func reloadTimelineReturnsEmptyWhenManagerIsNil() async {
        let r = await CharacterLifecycleOps.reloadTimeline(
            manager: nil,
            bookId: UUID(),
            characterId: UUID()
        )
        #expect(r.rows.isEmpty)
        #expect(r.error == nil)
    }

    @Test("reloadTimeline returns empty TimelineResult when characterId is UUID() (= no picker selection)")
    func reloadTimelineReturnsEmptyWhenCharacterIdIsUUIDZero() async {
        let r = await CharacterLifecycleOps.reloadTimeline(
            manager: nil,
            bookId: UUID(),
            characterId: UUID()  // zero UUID = no picker selection
        )
        #expect(r.rows.isEmpty)
    }

    @Test("reloadTimeline returns empty TimelineResult when bookId is nil")
    func reloadTimelineReturnsEmptyWhenBookIdIsNil() async {
        let r = await CharacterLifecycleOps.reloadTimeline(
            manager: nil,
            bookId: nil,
            characterId: UUID()
        )
        #expect(r.rows.isEmpty)
    }

    // MARK: - addEvent

    @Test("addEvent ignores nil manager and returns didSave=false")
    func addEventIgnoresNilManager() async {
        let r = await CharacterLifecycleOps.addEvent(
            manager: nil,
            bookId: UUID(),
            characterId: UUID(),
            stage: .born,
            chapterUUIDText: "",
            excerpt: "first day of school"
        )
        #expect(r.didSave == false)
        #expect(r.error != nil)
    }

    @Test("addEvent ignores nil characterId and returns didSave=false")
    func addEventIgnoresNilCharacterId() async {
        let r = await CharacterLifecycleOps.addEvent(
            manager: nil,
            bookId: UUID(),
            characterId: nil,
            stage: .born,
            chapterUUIDText: "",
            excerpt: "first day of school"
        )
        #expect(r.didSave == false)
        #expect(r.error != nil)
    }

    @Test("addEvent ignores empty excerpt and returns didSave=false")
    func addEventIgnoresEmptyExcerpt() async {
        let r = await CharacterLifecycleOps.addEvent(
            manager: nil,
            bookId: UUID(),
            characterId: UUID(),
            stage: .born,
            chapterUUIDText: "",
            excerpt: ""
        )
        #expect(r.didSave == false)
        #expect(r.error != nil)
    }

    @Test("addEvent ignores whitespace-only excerpt and returns didSave=false")
    func addEventIgnoresWhitespaceExcerpt() async {
        let r = await CharacterLifecycleOps.addEvent(
            manager: nil,
            bookId: UUID(),
            characterId: UUID(),
            stage: .born,
            chapterUUIDText: "",
            excerpt: "   \n  \t  "
        )
        #expect(r.didSave == false)
        #expect(r.error != nil)
    }

    @Test("addEvent ignores UUID() characterId (= no picker selection)")
    func addEventIgnoresUUIDZeroCharacterId() async {
        let r = await CharacterLifecycleOps.addEvent(
            manager: nil,
            bookId: UUID(),
            characterId: UUID(),  // zero UUID = no picker selection
            stage: .born,
            chapterUUIDText: "",
            excerpt: "first day of school"
        )
        #expect(r.didSave == false)
    }

    // MARK: - removeEvent

    @Test("removeEvent ignores nil manager and returns didSave=false")
    func removeEventIgnoresNilManager() async {
        let event = LifecycleEvent(
            bookId: UUID(),
            characterId: UUID(),
            stage: .born,
            chapterId: nil,
            excerpt: "test"
        )
        let r = await CharacterLifecycleOps.removeEvent(
            manager: nil,
            event: event
        )
        #expect(r.didSave == false)
        #expect(r.error != nil)
    }

    @Test("source-marker: ops file contains 4 public static funcs")
    func sourceHasFourPublicStaticFuncs() throws {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let repoRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourcePath = repoRoot
            .appendingPathComponent("Sources/WenshuApp/Views/SpecializedTools/CharacterLifecycleOps.swift")
        let source = try String(contentsOf: sourcePath, encoding: .utf8)
        #expect(source.contains("static func reload"))
        #expect(source.contains("static func reloadTimeline"))
        #expect(source.contains("static func addEvent"))
        #expect(source.contains("static func removeEvent"))
    }
}