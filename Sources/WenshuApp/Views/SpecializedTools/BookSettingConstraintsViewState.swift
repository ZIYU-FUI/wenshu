//
//  BookSettingConstraintsViewState.swift · Wenshu
//
//  @Observable mirror for BookSettingConstraintsView. Mirrors
//  the per-view business state (= `constraints`, `violations`,
//  `status`, `errorText`) so the View holds a single @State
//  binding. Form drafts stay on the View per ADR-0009 §11.3.
//

import Foundation
import Observation

/// Business state mirror for `BookSettingConstraintsView`.
@Observable
final class BookSettingConstraintsViewState {
    var constraints: [BookSettingConstraint] = []
    var violations: [ConstraintViolation] = []
    var status: SpecializedToolLoadStatus = .idle
    var errorText: String?

    init(
        constraints: [BookSettingConstraint] = [],
        violations: [ConstraintViolation] = [],
        status: SpecializedToolLoadStatus = .idle,
        errorText: String? = nil
    ) {
        self.constraints = constraints
        self.violations = violations
        self.status = status
        self.errorText = errorText
    }
}