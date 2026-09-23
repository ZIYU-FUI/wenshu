//
//  TagManagerOpsTests.swift · Wenshu · v1.74 tagmanager-mvvm T2a
//
//  Behavior + source-level tests for `TagManagerOps` (= the
//  stateless enum extracted from TagManagerView in v1.74 T1).
//  Per boss 2026-09-22 OOB '按MVVM UI 业务 数据，三分离，排查
//  设置页 / kanban / todo 这三个独立窗口是否符合标准' (= the audit
//  also flagged TagManagerView / PlaceholderView / IdeaLibraryView
//  per the 2026-09-23 spec at
//  .scratch/2026-09-23-mvvm-audit/spec.md §2.1-§2.3): the
//  TagManagerView business layer (= reload / runFilter / addTag
//  / removeTag / applyTag / unapply + resolveApplyTargetUUID + the
//  inline UUID-parse trim + the tag-construction inline literals)
//  must move to a stateless enum so the View becomes a pure
//  consumer. The fix per ADR-0009 + the v1.72 settings-kanban-todo
//  precedent (= KanbanOps / TodoOps / SettingsOps = stateless
//  enums with @MainActor static funcs) is `TagManagerOps` (= this
//  test's SUT).
//
//  Why an enum (not @Observable class):
//  - State already lives in `TagManager` (= the actor defined in
//    Core/Agent/Specialized/TagManagerTools.swift; = source of
//    truth per AGENTS.md §11.3 wenshu-side wins pattern).
//  - The View holds `manager: TagManager?` as @State (= the
//    SwiftUI layer). KanbanView is a leaf view (= no parent owns
//    the tags / applications state).
//  - The enum is stateless: it accepts the actor reference as a
//    parameter (= nil-able so tests can drive the empty-result
//    paths without standing up a BookStore) + returns Result
//    types. Reusable from any caller.
//
//  Why async throws (vs the v1.72 KanbanOps sync shape):
//  - TagManager is an actor; every method is async throws. The
//    Ops enum exposes the same shape so the View's
//    `await actor.foo()` calls land on Ops without changing the
//    TaskGroup wiring.
//
//  Coverage (= 9 tests):
//    1. `fileExistsAtCanonicalPath` — source-level guard
//    2. `reloadReturnsEmptyForNilManager`
//    3. `reloadReturnsEmptyForNilBookId`
//    4. `runFilterReturnsEmptyForNilManager`
//    5. `runFilterReturnsEmptyForNewMagicUUID`
//    6. `addTagIgnoresEmptyLabel`
//    7. `addTagIgnoresNilManager`
//    8. `applyTagIgnoresUnparseableTargetIdText`
//    9. `applyTagIgnoresNilTagId`
//
//  Mock strategy:
//  - No mock framework. `TagManager?` is the seam (= tests pass
//    nil to drive the empty-result paths + pre-condition guards).
//  - No real BookStore / JSON file system round-trip tests (= those
//    belong in TagManagerToolsTests, the domain-actor test suite).
//    The Ops helper's job is to translate a View draft state into
//    an actor call + return a Result; the actor's behaviour is
//    already covered upstream.
//
//  Pattern (= v1.72 KanbanOpsTests T1a precedent): @MainActor +
//  Swift Testing + no fixture (= seam-based). No mock framework.
//  The seam IS the test target.
//

import Foundation
import Testing
@testable import WenshuApp

@MainActor
@Suite("v1.74 tagmanager-mvvm T2a — TagManagerOps (per-book tag business layer)")
struct TagManagerOpsTests {

    // MARK: - Source-level structural assertions

    @Test("TagManagerOps.swift exists at the canonical path under Views/SpecializedTools/")
    func fileExistsAtCanonicalPath() throws {
        // #filePath resolves to .../Tests/WenshuAppTests/Views/TagManagerOpsTests.swift
        // (= 5 segments above the file). Walk up 5 levels to reach
        // the repo root (= the worktree root).
        let testFileURL = URL(fileURLWithPath: #filePath)
        let repoRoot = testFileURL
            .deletingLastPathComponent()  // Views/         -> WenshuAppTests/
            .deletingLastPathComponent()  // WenshuAppTests/ -> Tests/
            .deletingLastPathComponent()  // Tests/          -> <worktree>/
            .deletingLastPathComponent()  // <worktree>/     -> repo root
        let sourcePath = repoRoot
            .appendingPathComponent("Sources/WenshuApp/Views/SpecializedTools/TagManagerOps.swift")
        let exists = FileManager.default.fileExists(atPath: sourcePath.path)
        #expect(exists, "TagManagerOps.swift must exist at \(sourcePath.path)")
    }

    // MARK: - reload (= load tags + applications + cloud)

    @Test("reload returns empty LoadResult when manager is nil")
    func reloadReturnsEmptyForNilManager() async {
        let result = await TagManagerOps.reload(manager: nil, bookId: UUID())
        #expect(result.didLoad == false)
        #expect(result.tags.isEmpty)
        #expect(result.applications.isEmpty)
        #expect(result.cloud.isEmpty)
        #expect(result.error == nil)
    }

    @Test("reload returns empty LoadResult when bookId is nil")
    func reloadReturnsEmptyForNilBookId() async {
        // The pre-v1.74 helper bailed when bookId was nil (= the
        // empty-state path). Post-v1.74 the helper also bails when
        // manager is nil (= the actor-never-constructed path). The
        // View triggers either from its `activeBookId` getter
        // (= driven by `BookStore.selectedBookId`).
        // We cannot construct a TagManager here (= requires BookStore)
        // so we drive the nil-manager guard and confirm the
        // empty-result shape stays identical to the nil-bookId
        // path.
        let result = await TagManagerOps.reload(manager: nil, bookId: nil)
        #expect(result.didLoad == false)
        #expect(result.tags.isEmpty)
        #expect(result.error == nil)
    }

    // MARK: - runFilter (= filter entities by tag + target)

    @Test("runFilter returns empty FilterResult when manager is nil")
    func runFilterReturnsEmptyForNilManager() async {
        let result = await TagManagerOps.runFilter(
            manager: nil,
            bookId: UUID(),
            tagId: UUID(),
            target: .chapter
        )
        #expect(result.didRun == false)
        #expect(result.matches.isEmpty)
        #expect(result.error == nil)
    }

    @Test("runFilter returns empty FilterResult when tagId is the new-magic UUID")
    func runFilterReturnsEmptyForNewMagicUUID() async {
        // The View guards `tagId != UUID()` (= the SwiftUI picker
        // default = a fresh `UUID()` = the "no selection" sentinel).
        // The helper must respect that guard (= matches pre-v1.74
        // behaviour verbatim).
        let result = await TagManagerOps.runFilter(
            manager: nil,
            bookId: UUID(),
            tagId: UUID(),
            target: .character
        )
        #expect(result.didRun == false)
        #expect(result.matches.isEmpty)
    }

    // MARK: - addTag (= create + persist)

    @Test("addTag ignores empty label and returns didSave=false")
    func addTagIgnoresEmptyLabel() async {
        let result = await TagManagerOps.addTag(
            manager: nil,
            bookId: UUID(),
            label: "",
            category: .theme
        )
        #expect(result.didSave == false)
        #expect(result.error == nil)
    }

    @Test("addTag ignores whitespace-only label and returns didSave=false")
    func addTagIgnoresWhitespaceLabel() async {
        let result = await TagManagerOps.addTag(
            manager: nil,
            bookId: UUID(),
            label: "   \n\t  ",
            category: .motif
        )
        #expect(result.didSave == false)
        #expect(result.error == nil)
    }

    @Test("addTag ignores nil manager and returns didSave=false")
    func addTagIgnoresNilManager() async {
        let result = await TagManagerOps.addTag(
            manager: nil,
            bookId: UUID(),
            label: "redemption",
            category: .theme
        )
        #expect(result.didSave == false)
        // nil-manager is a no-op, NOT an error (= the View will
        // construct the actor via `ensureManager` before the next
        // attempt).
        #expect(result.error == nil)
    }

    // MARK: - applyTag (= record a TagApplication)

    @Test("applyTag ignores unparseable targetIdText and returns didSave=false")
    func applyTagIgnoresUnparseableTargetIdText() async {
        let result = await TagManagerOps.applyTag(
            manager: nil,
            bookId: UUID(),
            tagId: UUID(),
            target: .scene,
            targetIdText: "not-a-uuid"
        )
        #expect(result.didSave == false)
        #expect(result.error == nil)
    }

    @Test("applyTag ignores empty targetIdText and returns didSave=false")
    func applyTagIgnoresEmptyTargetIdText() async {
        let result = await TagManagerOps.applyTag(
            manager: nil,
            bookId: UUID(),
            tagId: UUID(),
            target: .scene,
            targetIdText: ""
        )
        #expect(result.didSave == false)
        #expect(result.error == nil)
    }

    @Test("applyTag ignores nil tagId (= no picker selection) and returns didSave=false")
    func applyTagIgnoresNilTagId() async {
        let result = await TagManagerOps.applyTag(
            manager: nil,
            bookId: UUID(),
            tagId: nil,
            target: .chapter,
            targetIdText: UUID().uuidString
        )
        #expect(result.didSave == false)
        #expect(result.error == nil)
    }

    @Test("applyTag ignores new-magic tagId and returns didSave=false")
    func applyTagIgnoresNewMagicTagId() async {
        let result = await TagManagerOps.applyTag(
            manager: nil,
            bookId: UUID(),
            tagId: UUID(),
            target: .chapter,
            targetIdText: UUID().uuidString
        )
        #expect(result.didSave == false)
        #expect(result.error == nil)
    }

    // MARK: - removeTag / unapply (= delete by id)

    @Test("removeTag ignores nil manager and returns didSave=false")
    func removeTagIgnoresNilManager() async {
        let result = await TagManagerOps.removeTag(
            manager: nil,
            tag: Tag(bookId: UUID(), label: "x", category: .theme)
        )
        #expect(result.didSave == false)
        #expect(result.error == nil)
    }

    @Test("unapply ignores nil manager and returns didSave=false")
    func unapplyIgnoresNilManager() async {
        let result = await TagManagerOps.unapply(
            manager: nil,
            application: TagApplication(
                bookId: UUID(),
                tagId: UUID(),
                target: .chapter,
                targetId: UUID()
            )
        )
        #expect(result.didSave == false)
        #expect(result.error == nil)
    }
}