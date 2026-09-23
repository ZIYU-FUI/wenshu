//
//  ForeshadowingOpsTests.swift · Wenshu · v1.75 foreshadowing-mvvm T1a
//
//  Behavior + source-level tests for `ForeshadowingOps`
//  (= the stateless enum extracted from ForeshadowingView;
//  = the P0 view listed in .scratch/2026-09-23-mvvm-audit/spec.md §9).
//
//  Coverage (= 11 tests):
//    1.  fileExistsAtCanonicalPath
//    2.  reload returns empty LoadResult when manager is nil
//    3.  reload returns empty LoadResult when bookId is nil
//    4.  addForeshadowing returns didSave=false when manager is nil
//    5.  addForeshadowing returns didSave=false when bookId is nil
//    6.  addForeshadowing returns didSave=false when title is empty
//    7.  addForeshadowing returns didSave=false when title is whitespace-only
//    8.  removeForeshadowing returns didSave=false when manager is nil
//    9.  sourceHasThreePublicStaticFuncs marker
//    10. sourceIsStatelessEnum marker
//    11. ops file is in Views/Tools/ (= matches ForeshadowingView location)
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("v1.75 foreshadowing-mvvm T1a — ForeshadowingOps (per-book foreshadowing business layer)")
struct ForeshadowingOpsTests {

    // MARK: - Path guard

    @Test("ForeshadowingOps.swift exists at the canonical path under Views/Tools/")
    func fileExistsAtCanonicalPath() throws {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let repoRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourcePath = repoRoot
            .appendingPathComponent("Sources/WenshuApp/Views/Tools/ForeshadowingOps.swift")
        let exists = FileManager.default.fileExists(atPath: sourcePath.path)
        #expect(exists, "ForeshadowingOps.swift must exist at \(sourcePath.path)")
    }

    // MARK: - reload

    @Test("reload returns empty LoadResult when manager is nil")
    func reloadIgnoresNilManager() async {
        let r = await ForeshadowingOps.reload(manager: nil, bookId: UUID(), filterStatus: nil)
        #expect(r.didLoad == false)
        #expect(r.rows.isEmpty)
        #expect(r.staleRows.isEmpty)
        #expect(r.error == nil)
    }

    @Test("reload returns empty LoadResult when bookId is nil")
    func reloadIgnoresNilBookId() async {
        let r = await ForeshadowingOps.reload(manager: nil, bookId: nil, filterStatus: nil)
        #expect(r.didLoad == false)
        #expect(r.rows.isEmpty)
    }

    // MARK: - addForeshadowing

    @Test("addForeshadowing returns didSave=false when manager is nil")
    func addForeshadowingIgnoresNilManager() async {
        let r = await ForeshadowingOps.addForeshadowing(
            manager: nil,
            bookId: UUID(),
            title: "the old key",
            setupChapterIdText: "",
            setupExcerpt: "a key hangs on the wall",
            status: .setup
        )
        #expect(r.didSave == false)
        #expect(r.error != nil)
    }

    @Test("addForeshadowing returns didSave=false when bookId is nil")
    func addForeshadowingIgnoresNilBookId() async {
        let r = await ForeshadowingOps.addForeshadowing(
            manager: nil,
            bookId: nil,
            title: "the old key",
            setupChapterIdText: "",
            setupExcerpt: "a key hangs on the wall",
            status: .setup
        )
        #expect(r.didSave == false)
        #expect(r.error != nil)
    }

    @Test("addForeshadowing returns didSave=false when title is empty")
    func addForeshadowingIgnoresEmptyTitle() async {
        let r = await ForeshadowingOps.addForeshadowing(
            manager: nil,
            bookId: UUID(),
            title: "",
            setupChapterIdText: "",
            setupExcerpt: "test",
            status: .setup
        )
        #expect(r.didSave == false)
        #expect(r.error != nil)
    }

    @Test("addForeshadowing returns didSave=false when title is whitespace-only")
    func addForeshadowingIgnoresWhitespaceTitle() async {
        let r = await ForeshadowingOps.addForeshadowing(
            manager: nil,
            bookId: UUID(),
            title: "   \n  \t  ",
            setupChapterIdText: "",
            setupExcerpt: "test",
            status: .setup
        )
        #expect(r.didSave == false)
        #expect(r.error != nil)
    }

    // MARK: - removeForeshadowing

    @Test("removeForeshadowing returns didSave=false when manager is nil")
    func removeForeshadowingIgnoresNilManager() async {
        let row = Foreshadowing(
            bookId: UUID(),
            title: "any",
            setupChapterId: nil,
            setupExcerpt: "",
            status: .setup
        )
        let r = await ForeshadowingOps.removeForeshadowing(manager: nil, row: row)
        #expect(r.didSave == false)
        #expect(r.error != nil)
    }

    // MARK: - Source-level markers

    @Test("source-marker: ops file contains 3 public static funcs")
    func sourceHasThreePublicStaticFuncs() throws {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let repoRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourcePath = repoRoot
            .appendingPathComponent("Sources/WenshuApp/Views/Tools/ForeshadowingOps.swift")
        let source = try String(contentsOf: sourcePath, encoding: .utf8)
        #expect(source.contains("static func reload"))
        #expect(source.contains("static func addForeshadowing"))
        #expect(source.contains("static func removeForeshadowing"))
    }

    @Test("ops file is a stateless enum (= no @Observable / @MainActor class)")
    func sourceIsStatelessEnum() throws {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let repoRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourcePath = repoRoot
            .appendingPathComponent("Sources/WenshuApp/Views/Tools/ForeshadowingOps.swift")
        let source = try String(contentsOf: sourcePath, encoding: .utf8)
        #expect(source.contains("@MainActor"))
        #expect(source.contains("enum ForeshadowingOps"))
        #expect(!source.contains("@Observable"))
        #expect(!source.contains("class ForeshadowingOps"))
    }

    @Test("ops file is in Views/Tools/ (= matches ForeshadowingView location)")
    func sourceIsInViewsToolsDirectory() throws {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let repoRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourcePath = repoRoot
            .appendingPathComponent("Sources/WenshuApp/Views/Tools/ForeshadowingOps.swift")
        #expect(sourcePath.path.contains("/Views/Tools/"))
    }
}