//
//  IdeaLibraryViewState.swift · Wenshu
//
//  @Observable mirror for IdeaLibraryView. Mirrors the per-view
//  business state (= `ideas`, `suggestions`, `status`, `errorText`)
//  so the View holds a single @State binding to one struct instead
//  of N independent @State fields. Form draft state (= search text,
//  picker text, etc.) stays on the View as transient UI state per
//  ADR-0009 §11.3.
//

import Foundation
import Observation

/// Business state mirror for `IdeaLibraryView`. Holds the lists and
/// load status that the View used to keep in `@State`. The View's
/// transient form drafts (= `draftTitle`, `searchText`, etc.) stay
/// on the View (= per §11.3 = binding resets, not business rules).
@Observable
final class IdeaLibraryViewState {
    var ideas: [Idea] = []
    var suggestions: [Idea] = []
    var status: SpecializedToolLoadStatus = .idle
    var errorText: String?

    init(
        ideas: [Idea] = [],
        suggestions: [Idea] = [],
        status: SpecializedToolLoadStatus = .idle,
        errorText: String? = nil
    ) {
        self.ideas = ideas
        self.suggestions = suggestions
        self.status = status
        self.errorText = errorText
    }
}