//
//  IdeaLibraryOpsTests.swift · Wenshu · v1.74 idealibrary-mvvm T2a
//
//  Behavior + source-level tests for `IdeaLibraryOps` (= the
//  stateless enum extracted from IdeaLibraryView in v1.74 T1).
//  Per boss 2026-09-22 OOB '按MVVM UI 业务 数据，三分离' (= the
//  audit also flagged IdeaLibraryView per the 2026-09-23 spec
//  at .scratch/2026-09-23-mvvm-audit/spec.md §2.3): the
//  IdeaLibraryView business layer (= reload / addIdea /
//  removeIdea / linkIdea / unlinkIdea / runSuggest + the inline
//  Idea(...) construction + the tag comma-split parsing) must
//  move to a stateless enum so the View becomes a pure consumer.
//  The fix per ADR-0009 + the v1.72 settings-kanban-todo
//  precedent (= KanbanOps / TodoOps / SettingsOps = stateless
//  enums with @MainActor static funcs) + the v1.74 tagmanager-
//  mvvm precedent (= TagManagerOps = nil-able actor reference
//  seam) is `IdeaLibraryOps` (= this test's SUT).
//
//  Why an enum (not @Observable class):
//  - State already lives in `IdeaLibrary` (= the actor defined in
//    Core/Agent/Specialized/IdeaLibraryTools.swift; = source of
//    truth per AGENTS.md §11.3 wenshu-side wins pattern).
//  - The View holds `library: IdeaLibrary?` as @State (= the
//    SwiftUI layer).
//  - The enum is stateless: it accepts the actor reference as a
//    parameter (= nil-able so tests can drive the empty-result
//    paths without standing up a BookStore) + returns Result
//    types.
//
//  Why async throws (vs the v1.72 KanbanOps sync shape):
//  - IdeaLibrary is an actor; every method is async throws. The
//    Ops enum exposes the same shape so the View's
//    `await actor.foo()` calls land on Ops without changing the
//    TaskGroup wiring.
//
//  Coverage (= 11 tests):
//    1. `fileExistsAtCanonicalPath` — source-level guard
//    2. `reloadReturnsEmptyForNilLibrary`
//    3. `reloadReturnsEmptyForNilBookId`
//    4. `addIdeaIgnoresNilLibrary`
//    5. `addIdeaIgnoresEmptyTitle`
//    6. `addIdeaIgnoresWhitespaceTitle`
//    7. `removeIdeaIgnoresNilLibrary`
//    8. `linkIdeaIgnoresUnparseableTargetIdText`
//    9. `linkIdeaIgnoresNilIdeaId`
//   10. `unlinkIdeaIgnoresNilLibrary`
//   11. `runSuggestIgnoresNilLibrary`
//
//  Mock strategy (= same as TagManagerOpsTests /
//  PlaceholderOpsTests):
//  - No mock framework. `IdeaLibrary?` is the seam.
//  - No real BookStore / JSON round-trip tests (= those belong
//    in IdeaLibraryToolsTests, the domain-actor test suite).
//
//  Pattern (= v1.72 KanbanOpsTests T1a precedent): @MainActor +
//  Swift Testing + no fixture (= seam-based).
//

import Foundation
import Testing
@testable import WenshuApp

@MainActor
@Suite("v1.74 idealibrary-mvvm T2a — IdeaLibraryOps (per-book idea library business layer)")
struct IdeaLibraryOpsTests {

    // MARK: - Source-level structural assertions

    @Test("IdeaLibraryOps.swift exists at the canonical path under Views/SpecializedTools/")
    func fileExistsAtCanonicalPath() throws {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let repoRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourcePath = repoRoot
            .appendingPathComponent("Sources/WenshuApp/Views/SpecializedTools/IdeaLibraryOps.swift")
        let exists = FileManager.default.fileExists(atPath: sourcePath.path)
        #expect(exists, "IdeaLibraryOps.swift must exist at \(sourcePath.path)")
    }

    // MARK: - reload

    @Test("reload returns empty LoadResult when library is nil")
    func reloadReturnsEmptyForNilLibrary() async {
        let result = await IdeaLibraryOps.reload(
            library: nil,
            bookId: UUID(),
            searchText: "",
            filterStatus: nil,
            filterTag: ""
        )
        #expect(result.didLoad == false)
        #expect(result.ideas.isEmpty)
        #expect(result.error == nil)
    }

    @Test("reload returns empty LoadResult when bookId is nil")
    func reloadReturnsEmptyForNilBookId() async {
        let result = await IdeaLibraryOps.reload(
            library: nil,
            bookId: nil,
            searchText: "needle",
            filterStatus: .seedling,
            filterTag: "magic"
        )
        #expect(result.didLoad == false)
        #expect(result.ideas.isEmpty)
    }

    // MARK: - addIdea

    @Test("addIdea ignores nil library and returns didSave=false")
    func addIdeaIgnoresNilLibrary() async {
        let result = await IdeaLibraryOps.addIdea(
            library: nil,
            bookId: UUID(),
            title: "The red lantern",
            description: "",
            status: .seedling,
            tagsText: ""
        )
        #expect(result.didSave == false)
        #expect(result.error == nil)
    }

    @Test("addIdea ignores empty title and returns didSave=false")
    func addIdeaIgnoresEmptyTitle() async {
        let result = await IdeaLibraryOps.addIdea(
            library: nil,
            bookId: UUID(),
            title: "",
            description: "A scene where the lantern appears.",
            status: .seedling,
            tagsText: "imagery"
        )
        #expect(result.didSave == false)
        #expect(result.error == nil)
    }

    @Test("addIdea ignores whitespace-only title and returns didSave=false")
    func addIdeaIgnoresWhitespaceTitle() async {
        let result = await IdeaLibraryOps.addIdea(
            library: nil,
            bookId: UUID(),
            title: "   \n\t  ",
            description: "",
            status: .seedling,
            tagsText: ""
        )
        #expect(result.didSave == false)
        #expect(result.error == nil)
    }

    // MARK: - removeIdea

    @Test("removeIdea ignores nil library and returns didSave=false")
    func removeIdeaIgnoresNilLibrary() async {
        let result = await IdeaLibraryOps.removeIdea(
            library: nil,
            idea: Idea(bookId: UUID(), title: "x", description: "", status: .seedling, tags: [])
        )
        #expect(result.didSave == false)
        #expect(result.error == nil)
    }

    // MARK: - linkIdea / unlinkIdea

    @Test("linkIdea ignores unparseable targetIdText and returns didSave=false")
    func linkIdeaIgnoresUnparseableTargetIdText() async {
        let result = await IdeaLibraryOps.linkIdea(
            library: nil,
            ideaId: UUID(),
            target: .chapter,
            targetIdText: "not-a-uuid",
            context: "ch1"
        )
        #expect(result.didSave == false)
        #expect(result.error == nil)
    }

    @Test("linkIdea ignores empty targetIdText and returns didSave=false")
    func linkIdeaIgnoresEmptyTargetIdText() async {
        let result = await IdeaLibraryOps.linkIdea(
            library: nil,
            ideaId: UUID(),
            target: .character,
            targetIdText: "",
            context: ""
        )
        #expect(result.didSave == false)
        #expect(result.error == nil)
    }

    @Test("linkIdea ignores nil ideaId and returns didSave=false")
    func linkIdeaIgnoresNilIdeaId() async {
        let result = await IdeaLibraryOps.linkIdea(
            library: nil,
            ideaId: nil,
            target: .plotThread,
            targetIdText: UUID().uuidString,
            context: ""
        )
        #expect(result.didSave == false)
        #expect(result.error == nil)
    }

    @Test("unlinkIdea ignores nil library and returns didSave=false")
    func unlinkIdeaIgnoresNilLibrary() async {
        let result = await IdeaLibraryOps.unlinkIdea(
            library: nil,
            ideaId: UUID(),
            link: IdeaLink(target: .chapter, targetId: UUID(), context: "")
        )
        #expect(result.didSave == false)
        #expect(result.error == nil)
    }

    // MARK: - runSuggest

    @Test("runSuggest ignores nil library and returns suggestions=[]")
    func runSuggestIgnoresNilLibrary() async {
        let result = await IdeaLibraryOps.runSuggest(
            library: nil,
            bookId: UUID(),
            context: "A character ponders a red lantern."
        )
        #expect(result.didRun == false)
        #expect(result.suggestions.isEmpty)
        #expect(result.error == nil)
    }
}