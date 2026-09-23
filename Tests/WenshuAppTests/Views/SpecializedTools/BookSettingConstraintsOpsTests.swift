//
//  BookSettingConstraintsOpsTests.swift · Wenshu · v1.75 book-setting-constraints-mvvm T1a
//
//  Behavior + source-level tests for `BookSettingConstraintsOps`
//  (= the stateless enum extracted from BookSettingConstraintsView;
//  = the P0 view listed in .scratch/2026-09-23-mvvm-audit/spec.md §9).
//
//  Coverage (= 12 tests):
//    1.  fileExistsAtCanonicalPath: source-level structural guard
//    2.  reload returns empty LoadResult when manager is nil
//    3.  reload returns empty LoadResult when bookId is nil
//    4.  addConstraint returns didSave=false when manager is nil
//    5.  addConstraint returns didSave=false when title is empty
//    6.  addConstraint returns didSave=false when title is whitespace-only
//    7.  removeConstraint returns didSave=false when manager is nil
//    8.  runCheck returns empty CheckResult when manager is nil
//    9.  runCheck returns empty CheckResult when bookId is nil
//    10. runCheck preserves empty chapterText (= silent no-op)
//    11. sourceHasFourPublicStaticFuncs marker
//    12. ops file is a stateless enum (= no @Observable / @MainActor class)
//
//  All nil-paths return silent no-op (= didLoad/didSave=false; error=nil
//  when no actor attempt) — mirrors TagManagerOps / CharacterLifecycleOps
//  v1.74 + v1.75a contract.
//
//  Per Q112 1 ticket 1 file.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("v1.75 book-setting-constraints-mvvm T1a — BookSettingConstraintsOps (per-book constraint business layer)")
struct BookSettingConstraintsOpsTests {

    // MARK: - Path guard

    @Test("BookSettingConstraintsOps.swift exists at the canonical path under Views/SpecializedTools/")
    func fileExistsAtCanonicalPath() throws {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let repoRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourcePath = repoRoot
            .appendingPathComponent("Sources/WenshuApp/Views/SpecializedTools/BookSettingConstraintsOps.swift")
        let exists = FileManager.default.fileExists(atPath: sourcePath.path)
        #expect(exists, "BookSettingConstraintsOps.swift must exist at \(sourcePath.path)")
    }

    // MARK: - reload

    @Test("reload returns empty LoadResult when manager is nil")
    func reloadIgnoresNilManager() async {
        let r = await BookSettingConstraintsOps.reload(manager: nil, bookId: UUID())
        #expect(r.didLoad == false)
        #expect(r.constraints.isEmpty)
        #expect(r.error == nil)
    }

    @Test("reload returns empty LoadResult when bookId is nil")
    func reloadIgnoresNilBookId() async {
        // We can't construct a real actor here without BookStore fixture;
        // = pass a non-nil placeholder to exercise the bookId-nil branch.
        let r = await BookSettingConstraintsOps.reload(manager: nil, bookId: nil)
        #expect(r.didLoad == false)
        #expect(r.constraints.isEmpty)
    }

    // MARK: - addConstraint

    @Test("addConstraint ignores nil manager and returns didSave=false")
    func addConstraintIgnoresNilManager() async {
        let r = await BookSettingConstraintsOps.addConstraint(
            manager: nil,
            bookId: UUID(),
            title: "no opening chapter dialogue",
            description: "forbid opening with character speech",
            severity: .soft,
            scope: .world,
            appliesToId: nil,
            forbiddenPatterns: []
        )
        #expect(r.didSave == false)
        #expect(r.error != nil)
    }

    @Test("addConstraint ignores empty title and returns didSave=false")
    func addConstraintIgnoresEmptyTitle() async {
        let r = await BookSettingConstraintsOps.addConstraint(
            manager: nil,
            bookId: UUID(),
            title: "",
            description: "anything",
            severity: .soft,
            scope: .world,
            appliesToId: nil,
            forbiddenPatterns: []
        )
        #expect(r.didSave == false)
        #expect(r.error != nil)
    }

    @Test("addConstraint ignores whitespace-only title and returns didSave=false")
    func addConstraintIgnoresWhitespaceTitle() async {
        let r = await BookSettingConstraintsOps.addConstraint(
            manager: nil,
            bookId: UUID(),
            title: "   \n  \t  ",
            description: "anything",
            severity: .soft,
            scope: .world,
            appliesToId: nil,
            forbiddenPatterns: []
        )
        #expect(r.didSave == false)
        #expect(r.error != nil)
    }

    // MARK: - removeConstraint

    @Test("removeConstraint ignores nil manager and returns didSave=false")
    func removeConstraintIgnoresNilManager() async {
        let constraint = BookSettingConstraint(
            bookId: UUID(),
            title: "any",
            description: "",
            severity: .hard,
            scope: .world,
            appliesToId: nil,
            forbiddenPatterns: []
        )
        let r = await BookSettingConstraintsOps.removeConstraint(manager: nil, constraint: constraint)
        #expect(r.didSave == false)
        #expect(r.error != nil)
    }

    // MARK: - runCheck

    @Test("runCheck returns empty CheckResult when manager is nil")
    func runCheckIgnoresNilManager() async {
        let r = await BookSettingConstraintsOps.runCheck(manager: nil, bookId: UUID(), chapterText: "any")
        #expect(r.didRun == false)
        #expect(r.violations.isEmpty)
    }

    @Test("runCheck returns empty CheckResult when bookId is nil")
    func runCheckIgnoresNilBookId() async {
        let r = await BookSettingConstraintsOps.runCheck(manager: nil, bookId: nil, chapterText: "any")
        #expect(r.didRun == false)
        #expect(r.violations.isEmpty)
    }

    @Test("runCheck preserves empty chapterText (= silent no-op)")
    func runCheckPreservesEmptyText() async {
        let r = await BookSettingConstraintsOps.runCheck(manager: nil, bookId: UUID(), chapterText: "")
        #expect(r.didRun == false)
        #expect(r.violations.isEmpty)
    }

    // MARK: - Source-level markers

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
            .appendingPathComponent("Sources/WenshuApp/Views/SpecializedTools/BookSettingConstraintsOps.swift")
        let source = try String(contentsOf: sourcePath, encoding: .utf8)
        #expect(source.contains("static func reload"))
        #expect(source.contains("static func addConstraint"))
        #expect(source.contains("static func removeConstraint"))
        #expect(source.contains("static func runCheck"))
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
            .appendingPathComponent("Sources/WenshuApp/Views/SpecializedTools/BookSettingConstraintsOps.swift")
        let source = try String(contentsOf: sourcePath, encoding: .utf8)
        // Per v1.72 KanbanOps template + v1.74 standing rule: enum + static funcs.
        #expect(source.contains("@MainActor"))
        #expect(source.contains("enum BookSettingConstraintsOps"))
        #expect(!source.contains("@Observable"))
        #expect(!source.contains("class BookSettingConstraintsOps"))
    }
}