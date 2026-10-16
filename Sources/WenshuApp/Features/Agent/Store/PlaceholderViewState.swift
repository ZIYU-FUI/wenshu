//
//  PlaceholderViewState.swift · Wenshu
//
//  @Observable mirror for PlaceholderView. Mirrors the per-view
//  business state (= `rows`, `lastScanCount`, `loadingState`,
//  `errorText`) so the View holds a single @State binding instead
//  of N independent @State fields. Form draft state (= draft
//  chapter/line text, draft pattern, picker text, etc.) stays on
//  the View as transient UI state per ADR-0009 §11.3.
//

import Foundation
import Observation

/// Business state mirror for `PlaceholderView`. The View's transient
/// form drafts (= `draftChapterText`, `draftPattern`, etc.) stay on
/// the View (= per §11.3 = binding resets, not business rules).
@Observable
final class PlaceholderViewState {
    var rows: [Placeholder] = []
    var lastScanCount: Int? = nil
    var loadingState: SpecializedToolLoadStatus = .idle
    var errorText: String?

    init(
        rows: [Placeholder] = [],
        lastScanCount: Int? = nil,
        loadingState: SpecializedToolLoadStatus = .idle,
        errorText: String? = nil
    ) {
        self.rows = rows
        self.lastScanCount = lastScanCount
        self.loadingState = loadingState
        self.errorText = errorText
    }
}