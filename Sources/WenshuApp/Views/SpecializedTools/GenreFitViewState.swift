//
//  GenreFitViewState.swift · Wenshu
//
//  @Observable mirror for GenreFitView. Mirrors the per-view
//  business state (= `report`, `status`) so the View holds a
//  single @State binding. Form picker + input state stays on
//  the View per ADR-0009 §11.3.
//

import Foundation
import Observation

/// Business state mirror for `GenreFitView`. Uses the canonical
/// `SpecializedToolLoadStatus` enum.
@Observable
final class GenreFitViewState {
    var report: GenreFitReport?
    var status: SpecializedToolLoadStatus = .idle

    init(
        report: GenreFitReport? = nil,
        status: SpecializedToolLoadStatus = .idle
    ) {
        self.report = report
        self.status = status
    }
}