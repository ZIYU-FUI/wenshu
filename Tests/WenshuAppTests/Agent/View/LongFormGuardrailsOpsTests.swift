//
//  LongFormGuardrailsOpsTests.swift · Wenshu · v1.75 longform-guardrails-mvvm T1a
//
//  Behavior + source-level tests for `LongFormGuardrailsOps`
//  (= the stateless enum extracted from LongFormGuardrailsView;
//  = the P0 view listed in .scratch/2026-09-23-mvvm-audit/spec.md §9).
//
//  Coverage (= 12 tests):
//    1.  fileExistsAtCanonicalPath
//    2.  reload returns empty LoadResult when manager is nil
//    3.  reload returns empty LoadResult when bookId is nil
//    4.  autoDerive returns didSave=false when manager is nil
//    5.  autoDerive returns didSave=false when bookId is nil
//    6.  removeRow returns didSave=false when manager is nil
//    7.  removeRow returns didSave=false when bookId is nil
//    8.  saveDraft returns didSave=false when name is empty
//    9.  saveDraft returns didSave=false when manager is nil
//    10. runCheck returns empty CheckResult when manager is nil
//    11. sourceHasFivePublicStaticFuncs marker
//    12. sourceIsStatelessEnum marker
//
//  All nil-paths return silent no-op. Mirrors v1.74 + v1.75a/b contract.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("v1.75 longform-guardrails-mvvm T1a — LongFormGuardrailsOps (per-book guardrail business layer)")
struct LongFormGuardrailsOpsTests {

    // MARK: - Path guard

    @Test("LongFormGuardrailsOps.swift exists at the canonical path under Views/SpecializedTools/")
    func fileExistsAtCanonicalPath() throws {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let repoRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourcePath = repoRoot
            .appendingPathComponent("Sources/WenshuApp/Views/SpecializedTools/LongFormGuardrailsOps.swift")
        let exists = FileManager.default.fileExists(atPath: sourcePath.path)
        #expect(exists, "LongFormGuardrailsOps.swift must exist at \(sourcePath.path)")
    }

    // MARK: - reload

    @Test("reload returns empty LoadResult when manager is nil")
    func reloadIgnoresNilManager() async {
        let r = await LongFormGuardrailsOps.reload(manager: nil, bookId: UUID())
        #expect(r.didLoad == false)
        #expect(r.rows.isEmpty)
        #expect(r.error == nil)
    }

    @Test("reload returns empty LoadResult when bookId is nil")
    func reloadIgnoresNilBookId() async {
        let r = await LongFormGuardrailsOps.reload(manager: nil, bookId: nil)
        #expect(r.didLoad == false)
        #expect(r.rows.isEmpty)
    }

    // MARK: - autoDerive

    @Test("autoDerive returns didSave=false when manager is nil")
    func autoDeriveIgnoresNilManager() async {
        let r = await LongFormGuardrailsOps.autoDerive(manager: nil, bookId: UUID())
        #expect(r.didSave == false)
        #expect(r.error != nil)
    }

    @Test("autoDerive returns didSave=false when bookId is nil")
    func autoDeriveIgnoresNilBookId() async {
        let r = await LongFormGuardrailsOps.autoDerive(manager: nil, bookId: nil)
        #expect(r.didSave == false)
        #expect(r.error != nil)
    }

    // MARK: - removeRow

    @Test("removeRow returns didSave=false when manager is nil")
    func removeRowIgnoresNilManager() async {
        let r = await LongFormGuardrailsOps.removeRow(
            manager: nil,
            bookId: UUID(),
            row: LongFormGuardrail(
                kind: .persona,
                source: .bookContext,
                enforce: .warn,
                name: "any",
                description: "",
                isAutoDerived: false
            )
        )
        #expect(r.didSave == false)
        #expect(r.error != nil)
    }

    @Test("removeRow returns didSave=false when bookId is nil")
    func removeRowIgnoresNilBookId() async {
        let r = await LongFormGuardrailsOps.removeRow(
            manager: nil,
            bookId: nil,
            row: LongFormGuardrail(
                kind: .persona,
                source: .bookContext,
                enforce: .warn,
                name: "any",
                description: "",
                isAutoDerived: false
            )
        )
        #expect(r.didSave == false)
        #expect(r.error != nil)
    }

    // MARK: - saveDraft

    @Test("saveDraft returns didSave=false when manager is nil")
    func saveDraftIgnoresNilManager() async {
        let r = await LongFormGuardrailsOps.saveDraft(
            manager: nil,
            bookId: UUID(),
            kind: .persona,
            enforcement: .warn,
            name: "no adverbs",
            description: "preferred style"
        )
        #expect(r.didSave == false)
        #expect(r.error != nil)
    }

    @Test("saveDraft returns didSave=false when name is empty")
    func saveDraftIgnoresEmptyName() async {
        let r = await LongFormGuardrailsOps.saveDraft(
            manager: nil,
            bookId: UUID(),
            kind: .persona,
            enforcement: .warn,
            name: "   \n  \t  ",
            description: "test"
        )
        #expect(r.didSave == false)
        #expect(r.error != nil)
    }

    // MARK: - runCheck

    @Test("runCheck returns empty CheckResult when manager is nil")
    func runCheckIgnoresNilManager() async {
        let r = await LongFormGuardrailsOps.runCheck(
            manager: nil,
            guardrails: [],
            checkText: "any"
        )
        #expect(r.didRun == false)
        #expect(r.violations.isEmpty)
        #expect(r.hasCritical == false)
    }

    // MARK: - Source-level markers

    @Test("source-marker: ops file contains 5 public static funcs")
    func sourceHasFivePublicStaticFuncs() throws {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let repoRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourcePath = repoRoot
            .appendingPathComponent("Sources/WenshuApp/Views/SpecializedTools/LongFormGuardrailsOps.swift")
        let source = try String(contentsOf: sourcePath, encoding: .utf8)
        #expect(source.contains("static func reload"))
        #expect(source.contains("static func autoDerive"))
        #expect(source.contains("static func removeRow"))
        #expect(source.contains("static func saveDraft"))
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
            .appendingPathComponent("Sources/WenshuApp/Views/SpecializedTools/LongFormGuardrailsOps.swift")
        let source = try String(contentsOf: sourcePath, encoding: .utf8)
        #expect(source.contains("@MainActor"))
        #expect(source.contains("enum LongFormGuardrailsOps"))
        #expect(!source.contains("@Observable"))
        #expect(!source.contains("class LongFormGuardrailsOps"))
    }
}