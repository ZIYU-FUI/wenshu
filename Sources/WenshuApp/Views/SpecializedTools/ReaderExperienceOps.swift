//
//  ReaderExperienceOps.swift · Wenshu · v1.75 reader-experience-mvvm T1b
//
//  Per-chapter reader-experience analysis business layer, extracted from
//  ReaderExperienceView (= the P0-mild view listed in
//  .scratch/2026-09-23-mvvm-audit/spec.md §9 v1.75 arc).
//
//  Per v1.72 KanbanOps template (= @MainActor enum + Result types +
//  static funcs). Per Q112 1 ticket = 1 file.
//
//  Public surface (= 2 entry points + 1 Result type):
//    1. ensureAnalyzer(analyzer:inout ReaderExperienceAnalyzer?) -> Void
//    2. runAnalyze(analyzer:chapterText:kind:) -> RunResult
//
//  All actor calls nil-guarded. Per Q112 no actor 搬家: actor stays in
//  Sources/WenshuApp/Core/Agent/Specialized/ReaderExperienceTools.swift.
//

import Foundation

/// Stateless business layer for ReaderExperienceView. Mirrors the v1.72 +
/// v1.74 + v1.75a-f precedents.
@MainActor
enum ReaderExperienceOps {

    // MARK: - Result types

    /// Outcome of a `runAnalyze` (= the reader-experience report snapshot).
    struct RunResult {
        var report: ReaderExperienceReport?
        var didRun: Bool
        var error: String?
    }

    // MARK: - Entry points

    /// Lazily construct the `ReaderExperienceAnalyzer` (= or fetch existing).
    static func ensureAnalyzer(analyzer: inout ReaderExperienceAnalyzer?) {
        if analyzer == nil {
            analyzer = ReaderExperienceAnalyzer()
        }
    }

    /// Run the reader-experience analysis for one chapter text + kind.
    static func runAnalyze(
        analyzer: ReaderExperienceAnalyzer?,
        chapterText: String,
        kind: ReaderExperienceKind
    ) async -> RunResult {
        guard let actor = analyzer else {
            return RunResult(report: nil, didRun: false, error: nil)
        }
        do {
            let newReport = try await actor.analyze(chapterText: chapterText, kind: kind)
            return RunResult(report: newReport, didRun: true, error: nil)
        } catch {
            return RunResult(report: nil, didRun: false, error: error.localizedDescription)
        }
    }
}