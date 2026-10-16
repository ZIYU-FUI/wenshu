//
//  CharacterLifecycleViewState.swift · Wenshu
//
//  @Observable mirror for CharacterLifecycleView. Mirrors the
//  per-view business state (= `events`, `contradictions`,
//  `characters`, `timelineRows`, `status`, `errorText`) so the
//  View holds a single @State binding. Form picker + input
//  state stays on the View per ADR-0009 §11.3.
//

import Foundation
import Observation

/// Business state mirror for `CharacterLifecycleView`.
@Observable
final class CharacterLifecycleViewState {
    var events: [LifecycleEvent] = []
    var contradictions: [LifecycleContradiction] = []
    var characters: [Character] = []
    var timelineRows: [LifecycleEvent] = []
    var status: SpecializedToolLoadStatus = .idle
    var errorText: String?

    init(
        events: [LifecycleEvent] = [],
        contradictions: [LifecycleContradiction] = [],
        characters: [Character] = [],
        timelineRows: [LifecycleEvent] = [],
        status: SpecializedToolLoadStatus = .idle,
        errorText: String? = nil
    ) {
        self.events = events
        self.contradictions = contradictions
        self.characters = characters
        self.timelineRows = timelineRows
        self.status = status
        self.errorText = errorText
    }
}