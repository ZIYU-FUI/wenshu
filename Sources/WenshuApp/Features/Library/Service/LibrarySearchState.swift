//
//  LibrarySearchState.swift
//
//  Which search result the user is allowed to see.
//
//  Why this type exists: = the view needs to tell a STALE result from a
//  FRESH one, = and the rule has to be measurable rather than merely
//  readable. = **⇒ So the rule lives here, = and the view and the test
//  both use THIS one** (= a second copy of the rule is a second rule, =
//  and the test would then measure the copy rather than the product).
//
//  **⇒ WHY THE OLD GUARD COULD NEVER FIRE.** = It compared the query it
//  had just trimmed with the same query trimmed again, = and `query` is
//  an immutable `let` on the view struct that is never reassigned. = So
//  the comparison was `x == x`, = which is true by construction, = and a
//  stale result was never dropped.
//
//  **⇒ AND CANCELLATION DOES NOT RESCUE IT.** = The search awaits
//  `Task.detached { … }.value`, = and a cancelled task still resumes
//  from that await, = so the OLDER search still lands, = and it lands
//  last whenever it finishes last. = **⇒ So the test is the NUMBER, =
//  not the query** (= each search takes the NEXT number, = and a result
//  whose number is not the latest is dropped).
//

import Foundation

/// The search's results, = and the rule that says which of them may land.
@MainActor
final class LibrarySearchState {
    /// The hits the user currently sees.
    private(set) var hits: [ReferenceLibrarySearch.Hit] = []

    /// Whether the search has run at least once (= so the view can say
    /// "nothing found" without saying it before the search started).
    private(set) var hasSearched = false

    /// The searches that have started, = counted.
    private var generation = 0

    /// Start a search, = and take the number that identifies it.
    ///
    /// **⇒ The NEXT number, = and not a number derived from the query.**
    /// = Two searches for the SAME query are still two searches, = and
    /// only the later one may land.
    func begin() -> Int {
        generation += 1
        return generation
    }

    /// Land a result, = if it is the latest search's.
    ///
    /// - Returns: whether the result landed (= `false` = it was stale, =
    ///   and the newer result stays on screen).
    @discardableResult
    func land(_ found: [ReferenceLibrarySearch.Hit], generation number: Int) -> Bool {
        guard number == generation else { return false }
        hits = found
        hasSearched = true
        return true
    }

    /// Say that there is nothing to show (= before any search has run).
    func clear() {
        hits = []
        hasSearched = false
    }
}
