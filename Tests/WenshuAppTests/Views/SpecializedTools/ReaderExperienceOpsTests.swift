//
//  ReaderExperienceOpsTests.swift · Wenshu · v1.75 reader-experience-mvvm T1a
//
//  Behavior + source-level tests for `ReaderExperienceOps`
//  (= the stateless enum extracted from ReaderExperienceView;
//  = the P0-mild view listed in .scratch/2026-09-23-mvvm-audit/spec.md §9).
//
//  Coverage (= 12 tests):
//    1.  fileExistsAtCanonicalPath
//    2.  runAnalyze returns empty RunResult when analyzer is nil
//    3.  runAnalyze preserves empty chapterText (= silent no-op)
//    4.  runAnalyze accepts every ReaderExperienceKind case when analyzer is nil
//    5.  ensureAnalyzer creates the actor when analyzer is nil
//    6.  ensureAnalyzer is a no-op when analyzer is non-nil
//    7.  ensureAnalyzer produces distinct instances on repeated nil calls
//    8.  sourceHasTwoPublicStaticFuncs marker
//    9.  sourceIsStatelessEnum marker
//    10. sourceDeclaresEnsureAnalyzerWithInout
//    11. sourceDeclaresRunAnalyzeChapterTextParameter
//    12. sourceDeclaresRunAnalyzeKindParameter
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("v1.75 reader-experience-mvvm T1a — ReaderExperienceOps (per-chapter reader-experience business layer)")
struct ReaderExperienceOpsTests {

    // MARK: - Path guard

    @Test("ReaderExperienceOps.swift exists at the canonical path under Views/SpecializedTools/")
    func fileExistsAtCanonicalPath() throws {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let repoRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourcePath = repoRoot
            .appendingPathComponent("Sources/WenshuApp/Views/SpecializedTools/ReaderExperienceOps.swift")
        let exists = FileManager.default.fileExists(atPath: sourcePath.path)
        #expect(exists, "ReaderExperienceOps.swift must exist at \(sourcePath.path)")
    }

    // MARK: - runAnalyze

    @Test("runAnalyze returns empty RunResult when analyzer is nil")
    func runAnalyzeIgnoresNilAnalyzer() async {
        let r = await ReaderExperienceOps.runAnalyze(analyzer: nil, chapterText: "any", kind: .pacing)
        #expect(r.didRun == false)
        #expect(r.report == nil)
        #expect(r.error == nil)
    }

    @Test("runAnalyze preserves empty chapterText (= silent no-op)")
    func runAnalyzePreservesEmptyText() async {
        let r = await ReaderExperienceOps.runAnalyze(analyzer: nil, chapterText: "", kind: .pacing)
        #expect(r.didRun == false)
        #expect(r.report == nil)
    }

    @Test("runAnalyze accepts every ReaderExperienceKind case when analyzer is nil")
    func runAnalyzeAcceptsEveryKindWhenAnalyzerNil() async {
        // The source guards `analyzer` before `kind`, so every
        // ReaderExperienceKind case must produce the same silent
        // no-op result. Exercises the parameter pass-through contract.
        for kind in ReaderExperienceKind.allCases {
            let r = await ReaderExperienceOps.runAnalyze(
                analyzer: nil,
                chapterText: "any chapter text",
                kind: kind
            )
            #expect(r.didRun == false)
            #expect(r.report == nil)
            #expect(r.error == nil)
        }
    }

    // MARK: - ensureAnalyzer

    @Test("ensureAnalyzer creates the actor when analyzer is nil")
    func ensureAnalyzerCreatesActorWhenNil() async {
        var analyzer: ReaderExperienceAnalyzer? = nil
        await ReaderExperienceOps.ensureAnalyzer(analyzer: &analyzer)
        #expect(analyzer != nil)
    }

    @Test("ensureAnalyzer is a no-op when analyzer is non-nil")
    func ensureAnalyzerNoOpWhenNonNil() async {
        let existing = ReaderExperienceAnalyzer()
        var analyzer: ReaderExperienceAnalyzer? = existing
        await ReaderExperienceOps.ensureAnalyzer(analyzer: &analyzer)
        #expect(analyzer === existing)
    }

    @Test("ensureAnalyzer produces a fresh instance each time on nil (= not memoized)")
    func ensureAnalyzerFreshInstanceOnRepeatedNil() async {
        var first: ReaderExperienceAnalyzer? = nil
        await ReaderExperienceOps.ensureAnalyzer(analyzer: &first)
        var second: ReaderExperienceAnalyzer? = nil
        await ReaderExperienceOps.ensureAnalyzer(analyzer: &second)
        #expect(first != nil)
        #expect(second != nil)
        #expect(first !== second)
    }

    // MARK: - Source-level markers

    @Test("source-marker: ops file contains 2 public static funcs")
    func sourceHasTwoPublicStaticFuncs() throws {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let repoRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourcePath = repoRoot
            .appendingPathComponent("Sources/WenshuApp/Views/SpecializedTools/ReaderExperienceOps.swift")
        let source = try String(contentsOf: sourcePath, encoding: .utf8)
        #expect(source.contains("static func ensureAnalyzer"))
        #expect(source.contains("static func runAnalyze"))
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
            .appendingPathComponent("Sources/WenshuApp/Views/SpecializedTools/ReaderExperienceOps.swift")
        let source = try String(contentsOf: sourcePath, encoding: .utf8)
        #expect(source.contains("@MainActor"))
        #expect(source.contains("enum ReaderExperienceOps"))
        #expect(!source.contains("@Observable"))
        #expect(!source.contains("class ReaderExperienceOps"))
    }

    @Test("ensureAnalyzer declares inout analyzer parameter (= caller mutates state)")
    func sourceDeclaresInoutAnalyzer() throws {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let repoRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourcePath = repoRoot
            .appendingPathComponent("Sources/WenshuApp/Views/SpecializedTools/ReaderExperienceOps.swift")
        let source = try String(contentsOf: sourcePath, encoding: .utf8)
        #expect(source.contains("analyzer: inout ReaderExperienceAnalyzer?"))
    }

    @Test("source-marker: runAnalyze declares chapterText: String parameter")
    func sourceDeclaresRunAnalyzeChapterTextParameter() throws {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let repoRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourcePath = repoRoot
            .appendingPathComponent("Sources/WenshuApp/Views/SpecializedTools/ReaderExperienceOps.swift")
        let source = try String(contentsOf: sourcePath, encoding: .utf8)
        #expect(source.contains("chapterText: String"))
    }

    @Test("source-marker: runAnalyze declares kind: ReaderExperienceKind parameter")
    func sourceDeclaresRunAnalyzeKindParameter() throws {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let repoRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourcePath = repoRoot
            .appendingPathComponent("Sources/WenshuApp/Views/SpecializedTools/ReaderExperienceOps.swift")
        let source = try String(contentsOf: sourcePath, encoding: .utf8)
        #expect(source.contains("kind: ReaderExperienceKind"))
    }
}