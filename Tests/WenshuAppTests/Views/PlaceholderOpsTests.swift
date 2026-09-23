//
//  PlaceholderOpsTests.swift · Wenshu · v1.74 placeholder-mvvm T2a
//
//  Behavior + source-level tests for `PlaceholderOps` (= the
//  stateless enum extracted from PlaceholderView in v1.74 T1).
//  Per boss 2026-09-22 OOB '按MVVM UI 业务 数据，三分离' (= the
//  audit also flagged PlaceholderView per the 2026-09-23 spec
//  at .scratch/2026-09-23-mvvm-audit/spec.md §2.2): the
//  PlaceholderView business layer (= reload / addPlaceholder /
//  resolvePlaceholder / abandonPlaceholder / reopenPlaceholder /
//  removePlaceholder / runScan + the inline UUID-parse trim + the
//  Placeholder(...) construction literals) must move to a
//  stateless enum so the View becomes a pure consumer. The fix
//  per ADR-0009 + the v1.72 settings-kanban-todo precedent (=
//  KanbanOps / TodoOps / SettingsOps = stateless enums with
//  @MainActor static funcs) + the v1.74 tagmanager-mvvm
//  precedent (= TagManagerOps = nil-able actor reference seam)
//  is `PlaceholderOps` (= this test's SUT).
//
//  Why an enum (not @Observable class):
//  - State already lives in `PlaceholderScanner` (= the actor
//    defined in Core/Agent/Specialized/PlaceholderScannerTools.swift;
//    = source of truth per AGENTS.md §11.3 wenshu-side wins
//    pattern).
//  - The View holds `scanner: PlaceholderScanner?` as @State (=
//    the SwiftUI layer). PlaceholderView is a leaf view.
//  - The enum is stateless: it accepts the actor reference as a
//    parameter (= nil-able so tests can drive the empty-result
//    paths without standing up a BookStore) + returns Result
//    types.
//
//  Why async throws (vs the v1.72 KanbanOps sync shape):
//  - PlaceholderScanner is an actor; every method is async
//    throws. The Ops enum exposes the same shape so the View's
//    `await actor.foo()` calls land on Ops without changing the
//    TaskGroup wiring.
//
//  Coverage (= 10 tests):
//    1. `fileExistsAtCanonicalPath` — source-level guard
//    2. `reloadReturnsEmptyForNilScanner`
//    3. `reloadReturnsEmptyForNilBookId`
//    4. `addPlaceholderIgnoresNilScanner`
//    5. `addPlaceholderIgnoresEmptyPattern`
//    6. `addPlaceholderIgnoresUnparseableChapterIdText`
//    7. `resolvePlaceholderIgnoresNilScanner`
//    8. `abandonPlaceholderIgnoresNilScanner`
//    9. `reopenPlaceholderIgnoresNilScanner`
//   10. `removePlaceholderIgnoresNilScanner`
//   11. `runScanIgnoresNilScanner`
//
//  Mock strategy (= same as TagManagerOpsTests):
//  - No mock framework. `PlaceholderScanner?` is the seam (=
//    tests pass nil to drive the empty-result paths +
//    pre-condition guards).
//  - No real BookStore / JSON round-trip tests (= those belong
//    in PlaceholderScannerToolsTests, the domain-actor test
//    suite). The Ops helper's job is to translate View draft
//    state into an actor call + return a Result; the actor's
//    behaviour is already covered upstream.
//
//  Pattern (= v1.72 KanbanOpsTests T1a precedent): @MainActor +
//  Swift Testing + no fixture (= seam-based).
//

import Foundation
import Testing
@testable import WenshuApp

@MainActor
@Suite("v1.74 placeholder-mvvm T2a — PlaceholderOps (per-book placeholder business layer)")
struct PlaceholderOpsTests {

    // MARK: - Source-level structural assertions

    @Test("PlaceholderOps.swift exists at the canonical path under Views/Tools/")
    func fileExistsAtCanonicalPath() throws {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let repoRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourcePath = repoRoot
            .appendingPathComponent("Sources/WenshuApp/Views/Tools/PlaceholderOps.swift")
        let exists = FileManager.default.fileExists(atPath: sourcePath.path)
        #expect(exists, "PlaceholderOps.swift must exist at \(sourcePath.path)")
    }

    // MARK: - reload

    @Test("reload returns empty LoadResult when scanner is nil")
    func reloadReturnsEmptyForNilScanner() async {
        let result = await PlaceholderOps.reload(
            scanner: nil,
            bookId: UUID(),
            filterStatus: .open
        )
        #expect(result.didLoad == false)
        #expect(result.rows.isEmpty)
        #expect(result.error == nil)
    }

    @Test("reload returns empty LoadResult when bookId is nil")
    func reloadReturnsEmptyForNilBookId() async {
        let result = await PlaceholderOps.reload(
            scanner: nil,
            bookId: nil,
            filterStatus: nil
        )
        #expect(result.didLoad == false)
        #expect(result.rows.isEmpty)
    }

    // MARK: - addPlaceholder

    @Test("addPlaceholder ignores nil scanner and returns didSave=false")
    func addPlaceholderIgnoresNilScanner() async {
        let result = await PlaceholderOps.addPlaceholder(
            scanner: nil,
            bookId: UUID(),
            chapterIdText: UUID().uuidString,
            lineText: "1",
            context: "ctx",
            pattern: "{TODO}",
            status: .open
        )
        #expect(result.didSave == false)
        #expect(result.error == nil)
    }

    @Test("addPlaceholder ignores empty pattern and returns didSave=false")
    func addPlaceholderIgnoresEmptyPattern() async {
        let result = await PlaceholderOps.addPlaceholder(
            scanner: nil,
            bookId: UUID(),
            chapterIdText: UUID().uuidString,
            lineText: "1",
            context: "ctx",
            pattern: "",
            status: .open
        )
        #expect(result.didSave == false)
        #expect(result.error == nil)
    }

    @Test("addPlaceholder ignores whitespace-only pattern and returns didSave=false")
    func addPlaceholderIgnoresWhitespacePattern() async {
        let result = await PlaceholderOps.addPlaceholder(
            scanner: nil,
            bookId: UUID(),
            chapterIdText: UUID().uuidString,
            lineText: "1",
            context: "ctx",
            pattern: "   \n\t  ",
            status: .open
        )
        #expect(result.didSave == false)
        #expect(result.error == nil)
    }

    @Test("addPlaceholder ignores unparseable chapterIdText and returns didSave=false")
    func addPlaceholderIgnoresUnparseableChapterIdText() async {
        let result = await PlaceholderOps.addPlaceholder(
            scanner: nil,
            bookId: UUID(),
            chapterIdText: "not-a-uuid",
            lineText: "1",
            context: "ctx",
            pattern: "{TODO}",
            status: .open
        )
        #expect(result.didSave == false)
        #expect(result.error == nil)
    }

    // MARK: - resolve / abandon / reopen / remove

    @Test("resolvePlaceholder ignores nil scanner and returns didSave=false")
    func resolvePlaceholderIgnoresNilScanner() async {
        let result = await PlaceholderOps.resolvePlaceholder(
            scanner: nil,
            row: Placeholder(
                bookId: UUID(),
                chapterId: UUID(),
                lineNumber: 1,
                context: "ctx",
                pattern: "{TODO}",
                status: .open
            )
        )
        #expect(result.didSave == false)
        #expect(result.error == nil)
    }

    @Test("abandonPlaceholder ignores nil scanner and returns didSave=false")
    func abandonPlaceholderIgnoresNilScanner() async {
        let result = await PlaceholderOps.abandonPlaceholder(
            scanner: nil,
            row: Placeholder(
                bookId: UUID(),
                chapterId: UUID(),
                lineNumber: 1,
                context: "ctx",
                pattern: "{TODO}",
                status: .open
            )
        )
        #expect(result.didSave == false)
        #expect(result.error == nil)
    }

    @Test("reopenPlaceholder ignores nil scanner and returns didSave=false")
    func reopenPlaceholderIgnoresNilScanner() async {
        let result = await PlaceholderOps.reopenPlaceholder(
            scanner: nil,
            row: Placeholder(
                bookId: UUID(),
                chapterId: UUID(),
                lineNumber: 1,
                context: "ctx",
                pattern: "{TODO}",
                status: .abandoned
            )
        )
        #expect(result.didSave == false)
        #expect(result.error == nil)
    }

    @Test("removePlaceholder ignores nil scanner and returns didSave=false")
    func removePlaceholderIgnoresNilScanner() async {
        let result = await PlaceholderOps.removePlaceholder(
            scanner: nil,
            row: Placeholder(
                bookId: UUID(),
                chapterId: UUID(),
                lineNumber: 1,
                context: "ctx",
                pattern: "{TODO}",
                status: .open
            )
        )
        #expect(result.didSave == false)
        #expect(result.error == nil)
    }

    // MARK: - runScan

    @Test("runScan ignores nil scanner and returns addedCount=0")
    func runScanIgnoresNilScanner() async {
        let result = await PlaceholderOps.runScan(
            scanner: nil,
            bookId: UUID(),
            chapterText: "Some chapter text with {TODO} and {REVIEW}",
            chapterId: UUID()
        )
        #expect(result.didScan == false)
        #expect(result.addedCount == 0)
        #expect(result.error == nil)
    }
}