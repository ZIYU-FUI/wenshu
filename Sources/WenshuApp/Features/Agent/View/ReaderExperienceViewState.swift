//
//  ReaderExperienceViewState.swift · Wenshu
//
//  @Observable mirror for ReaderExperienceView. Mirrors the
//  per-view business state (= `report`, `status`) so the View
//  holds a single @State binding instead of N independent
//  @State fields. Form picker state (= `selectedKind`,
//  `chapterText`) stays on the View as transient UI state per
//  ADR-0009 §11.3.
//

import Foundation
import Observation

/// Business state mirror for `ReaderExperienceView`. Uses the
/// canonical `SpecializedToolLoadStatus` (= same enum shape as
/// the other specialized tools) so the mirror file can live in
/// `Views/SpecializedTools/` without exporting the View-private
/// `AnalyzeStatus` enum.
@Observable
final class ReaderExperienceViewState {
    var report: ReaderExperienceReport?
    var status: SpecializedToolLoadStatus = .idle

    init(
        report: ReaderExperienceReport? = nil,
        status: SpecializedToolLoadStatus = .idle
    ) {
        self.report = report
        self.status = status
    }
}