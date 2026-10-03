//
//  LongFormGuardrailsViewState.swift · Wenshu
//
//  @Observable mirror for LongFormGuardrailsView. Mirrors the
//  per-view business state (= `guardrails`, `loadingState`,
//  `lastViolations`) so the View holds a single @State binding.
//  The View's transient check status (= lastCheckStatus) stays
//  on the View (= per §11.3 = binding reset / form draft, not
//  business data). Form drafts stay on the View per §11.3.
//

import Foundation
import Observation

/// Business state mirror for `LongFormGuardrailsView`.
@Observable
final class LongFormGuardrailsViewState {
    var guardrails: [LongFormGuardrail] = []
    var loadingState: SpecializedToolLoadStatus = .idle
    var lastViolations: [LongFormGuardrailViolation] = []

    init(
        guardrails: [LongFormGuardrail] = [],
        loadingState: SpecializedToolLoadStatus = .idle,
        lastViolations: [LongFormGuardrailViolation] = []
    ) {
        self.guardrails = guardrails
        self.loadingState = loadingState
        self.lastViolations = lastViolations
    }
}