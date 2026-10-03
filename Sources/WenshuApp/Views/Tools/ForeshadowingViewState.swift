//
//  ForeshadowingViewState.swift · Wenshu
//
//  @Observable mirror for ForeshadowingView. Mirrors the per-view
//  business state (= `rows`, `staleRows`, `loadingState`,
//  `errorText`) so the View holds a single @State binding. Form
//  drafts stay on the View per ADR-0009 §11.3.
//

import Foundation
import Observation

/// Business state mirror for `ForeshadowingView`.
@Observable
final class ForeshadowingViewState {
    var rows: [Foreshadowing] = []
    var staleRows: [Foreshadowing] = []
    var loadingState: SpecializedToolLoadStatus = .idle
    var errorText: String?

    init(
        rows: [Foreshadowing] = [],
        staleRows: [Foreshadowing] = [],
        loadingState: SpecializedToolLoadStatus = .idle,
        errorText: String? = nil
    ) {
        self.rows = rows
        self.staleRows = staleRows
        self.loadingState = loadingState
        self.errorText = errorText
    }
}