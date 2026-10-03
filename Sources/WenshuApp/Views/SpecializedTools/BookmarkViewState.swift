//
//  BookmarkViewState.swift · Wenshu
//
//  @Observable mirror for BookmarkView. Mirrors the per-view
//  business state (= `bookmarks`, `status`, `errorText`) so the
//  View holds a single @State binding. Form draft state
//  (= `draftLabel`) stays on the View per ADR-0009 §11.3.
//

import Foundation
import Observation

/// Business state mirror for `BookmarkView`.
@Observable
final class BookmarkViewState {
    var bookmarks: [Bookmark] = []
    var status: SpecializedToolLoadStatus = .idle
    var errorText: String?

    init(
        bookmarks: [Bookmark] = [],
        status: SpecializedToolLoadStatus = .idle,
        errorText: String? = nil
    ) {
        self.bookmarks = bookmarks
        self.status = status
        self.errorText = errorText
    }
}