//
//  EmotionCurveOpsTests.swift · Wenshu · v1.75 emotion-curve-mvvm T1a
//
//  Behavior + source-level tests for `EmotionCurveOps`
//  (= the stateless enum extracted from EmotionCurveView;
//  = the P0-mild view listed in .scratch/2026-09-23-mvvm-audit/spec.md §9).
//
//  Coverage (= 12 tests):
//    1.  fileExistsAtCanonicalPath
//    2.  runAnalyze returns empty RunResult when analyzer is nil
//    3.  runAnalyze preserves empty chapterText (= silent no-op)
//    4.  runAnalyze ignores windowCount value when analyzer is nil
//    5.  ensureAnalyzer creates the actor when analyzer is nil
//    6.  ensureAnalyzer is a no-op when analyzer is non-nil
//    7.  ensureAnalyzer produces distinct instances on repeated nil calls
//    8.  sourceHasTwoPublicStaticFuncs marker
//    9.  sourceIsStatelessEnum marker
//    10. sourceDeclaresEnsureAnalyzerWithInout (= runAnalyze caller mutates analyzer var)
//    11. sourceDeclaresRunAnalyzeChapterTextParameter
//    12. sourceDeclaresRunAnalyzeWindowCountParameter
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("v1.75 emotion-curve-mvvm T1a — EmotionCurveOps (per-chapter emotion-curve business layer)")
struct EmotionCurveOpsTests {

    // MARK: - Path guard

    @Test("EmotionCurveOps.swift exists at the canonical path under Views/SpecializedTools/")
    func fileExistsAtCanonicalPath() throws {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let repoRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourcePath = repoRoot
            .appendingPathComponent("Sources/WenshuApp/Views/SpecializedTools/EmotionCurveOps.swift")
        let exists = FileManager.default.fileExists(atPath: sourcePath.path)
        #expect(exists, "EmotionCurveOps.swift must exist at \(sourcePath.path)")
    }

    // MARK: - runAnalyze

    @Test("runAnalyze returns empty RunResult when analyzer is nil")
    func runAnalyzeIgnoresNilAnalyzer() async {
        let r = await EmotionCurveOps.runAnalyze(analyzer: nil, chapterText: "any", windowCount: 10)
        #expect(r.didRun == false)
        #expect(r.report == nil)
        #expect(r.error == nil)
    }

    @Test("runAnalyze preserves empty chapterText (= silent no-op)")
    func runAnalyzePreservesEmptyText() async {
        let r = await EmotionCurveOps.runAnalyze(analyzer: nil, chapterText: "", windowCount: 5)
        #expect(r.didRun == false)
        #expect(r.report == nil)
    }

    @Test("runAnalyze ignores windowCount value when analyzer is nil")
    func runAnalyzeIgnoresWindowCountWhenAnalyzerNil() async {
        // Exercises the nil-analyzer short-circuit with edge-case
        // windowCount values. The source guards `analyzer` first
        // (= before windowCount is inspected), so 0 / 1 / negative /
        // huge values must all return the same nil result without
        // touching windowCount.
        let rZero = await EmotionCurveOps.runAnalyze(analyzer: nil, chapterText: "any", windowCount: 0)
        let rOne = await EmotionCurveOps.runAnalyze(analyzer: nil, chapterText: "any", windowCount: 1)
        let rNegative = await EmotionCurveOps.runAnalyze(analyzer: nil, chapterText: "any", windowCount: -7)
        let rHuge = await EmotionCurveOps.runAnalyze(analyzer: nil, chapterText: "any", windowCount: Int.max)
        #expect(rZero.didRun == false)
        #expect(rOne.didRun == false)
        #expect(rNegative.didRun == false)
        #expect(rHuge.didRun == false)
        #expect(rZero.report == nil)
        #expect(rOne.report == nil)
        #expect(rNegative.report == nil)
        #expect(rHuge.report == nil)
    }

    // MARK: - ensureAnalyzer

    @Test("ensureAnalyzer creates the actor when analyzer is nil")
    func ensureAnalyzerCreatesActorWhenNil() async {
        var analyzer: EmotionCurveAnalyzer? = nil
        await EmotionCurveOps.ensureAnalyzer(analyzer: &analyzer)
        #expect(analyzer != nil)
    }

    @Test("ensureAnalyzer is a no-op when analyzer is non-nil")
    func ensureAnalyzerNoOpWhenNonNil() async {
        let existing = EmotionCurveAnalyzer()
        var analyzer: EmotionCurveAnalyzer? = existing
        await EmotionCurveOps.ensureAnalyzer(analyzer: &analyzer)
        // Identity preserved (= still the same instance).
        #expect(analyzer === existing)
    }

    @Test("ensureAnalyzer produces a fresh instance each time on nil (= not memoized)")
    func ensureAnalyzerFreshInstanceOnRepeatedNil() async {
        var first: EmotionCurveAnalyzer? = nil
        await EmotionCurveOps.ensureAnalyzer(analyzer: &first)
        var second: EmotionCurveAnalyzer? = nil
        await EmotionCurveOps.ensureAnalyzer(analyzer: &second)
        #expect(first != nil)
        #expect(second != nil)
        // Two separate nil→fresh calls must yield two distinct
        // instances (= ensureAnalyzer does NOT cache).
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
            .appendingPathComponent("Sources/WenshuApp/Views/SpecializedTools/EmotionCurveOps.swift")
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
            .appendingPathComponent("Sources/WenshuApp/Views/SpecializedTools/EmotionCurveOps.swift")
        let source = try String(contentsOf: sourcePath, encoding: .utf8)
        #expect(source.contains("@MainActor"))
        #expect(source.contains("enum EmotionCurveOps"))
        #expect(!source.contains("@Observable"))
        #expect(!source.contains("class EmotionCurveOps"))
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
            .appendingPathComponent("Sources/WenshuApp/Views/SpecializedTools/EmotionCurveOps.swift")
        let source = try String(contentsOf: sourcePath, encoding: .utf8)
        #expect(source.contains("analyzer: inout EmotionCurveAnalyzer?"))
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
            .appendingPathComponent("Sources/WenshuApp/Views/SpecializedTools/EmotionCurveOps.swift")
        let source = try String(contentsOf: sourcePath, encoding: .utf8)
        #expect(source.contains("chapterText: String"))
    }

    @Test("source-marker: runAnalyze declares windowCount: Int parameter")
    func sourceDeclaresRunAnalyzeWindowCountParameter() throws {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let repoRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourcePath = repoRoot
            .appendingPathComponent("Sources/WenshuApp/Views/SpecializedTools/EmotionCurveOps.swift")
        let source = try String(contentsOf: sourcePath, encoding: .utf8)
        #expect(source.contains("windowCount: Int"))
    }
}