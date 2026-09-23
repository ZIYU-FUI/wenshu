//
//  GenreFitOps.swift · Wenshu · v1.75 genre-fit-mvvm T1b
//
//  Per-chapter genre-fit analysis business layer, extracted from
//  GenreFitView (= the P0-mild view listed in
//  .scratch/2026-09-23-mvvm-audit/spec.md §9 v1.75 arc).
//
//  Per v1.72 KanbanOps template (= @MainActor enum + Result types +
//  static funcs). Per Q112 1 ticket = 1 file.
//
//  Public surface (= 2 entry points + 1 Result type):
//    1. ensureAnalyzer(analyzer:inout GenreFitAnalyzer?) -> Void
//    2. runAnalyze(analyzer:chapterText:genre:) -> RunResult
//
//  All actor calls nil-guarded. Per Q112 no actor 搬家: actor stays in
//  Sources/WenshuApp/Core/Agent/Specialized/GenreFitTools.swift.
//

import Foundation

/// Stateless business layer for GenreFitView. Mirrors the v1.72 +
/// v1.74 + v1.75a-f precedents.
@MainActor
enum GenreFitOps {

    // MARK: - Result types

    /// Outcome of a `runAnalyze` (= the genre-fit report snapshot).
    struct RunResult {
        var report: GenreFitReport?
        var didRun: Bool
        var error: String?
    }

    // MARK: - Entry points

    /// Lazily construct the `GenreFitAnalyzer` (= or fetch existing).
    static func ensureAnalyzer(analyzer: inout GenreFitAnalyzer?) {
        if analyzer == nil {
            analyzer = GenreFitAnalyzer()
        }
    }

    /// Run the genre-fit analysis for one chapter text + genre.
    static func runAnalyze(
        analyzer: GenreFitAnalyzer?,
        chapterText: String,
        genre: LiteraryGenre
    ) async -> RunResult {
        guard let actor = analyzer else {
            return RunResult(report: nil, didRun: false, error: nil)
        }
        do {
            let newReport = try await actor.analyze(chapterText: chapterText, genre: genre)
            return RunResult(report: newReport, didRun: true, error: nil)
        } catch {
            return RunResult(report: nil, didRun: false, error: error.localizedDescription)
        }
    }
}