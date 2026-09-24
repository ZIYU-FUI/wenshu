//
//  EmotionCurveOps.swift · Wenshu · v1.75 emotion-curve-mvvm T1b
//
//  Per-chapter emotion-curve analysis business layer, extracted from
//  EmotionCurveView (= the P0-mild view listed in
//  .scratch/2026-09-23-mvvm-audit/spec.md §9 v1.75 arc).
//
//  Per v1.72 KanbanOps template (= @MainActor enum + Result types +
//  static funcs). Per Q112 1 ticket = 1 file.
//
//  Public surface (= 2 entry points + 1 Result type):
//    1. ensureAnalyzer(analyzer:inout EmotionCurveAnalyzer?) -> Void
//    2. runAnalyze(analyzer:chapterText:windowCount:) -> RunResult
//
//  All actor calls nil-guarded. Per Q112 no actor 搬家: actor stays in
//  Sources/WenshuApp/Core/Agent/Specialized/EmotionCurveTools.swift.
//

import Foundation

/// Stateless business layer for EmotionCurveView. Mirrors the v1.72 +
/// v1.74 + v1.75a-e precedents.
@MainActor
enum EmotionCurveOps {

    // MARK: - Result types

    /// Outcome of a `runAnalyze` (= the emotion-curve report snapshot).
    struct RunResult {
        var report: EmotionCurveReport?
        var didRun: Bool
        var error: String?
    }

    // MARK: - Entry points

    /// Lazily construct the `EmotionCurveAnalyzer` (= or fetch existing).
    /// Mutates the caller's analyzer variable in place.
    static func ensureAnalyzer(analyzer: inout EmotionCurveAnalyzer?) {
        if analyzer == nil {
            analyzer = EmotionCurveAnalyzer()
        }
    }

    /// Run the emotion-curve analysis for one chapter text.
    /// analyzer must be non-nil; = pass the result of ensureAnalyzer first.
    static func runAnalyze(
        analyzer: EmotionCurveAnalyzer?,
        chapterText: String,
        windowCount: Int
    ) async -> RunResult {
        guard let actor = analyzer else {
            return RunResult(report: nil, didRun: false, error: nil)
        }
        do {
            let newReport = try await actor.analyze(
                chapterText: chapterText,
                windowCount: windowCount
            )
            return RunResult(report: newReport, didRun: true, error: nil)
        } catch {
            return RunResult(report: nil, didRun: false, error: error.localizedDescription)
        }
    }
}