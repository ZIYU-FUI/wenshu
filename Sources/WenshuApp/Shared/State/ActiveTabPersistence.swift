//
//  ActiveTabPersistence.swift · Wenshu
//
//  Shared/State · the writer the editor's tab-switch path hands its
//  value to, instead of doing the write itself.
//
//  WHY THIS FILE EXISTS. `AppState.activeTabId`'s `didSet` used to call
//  `UserDefaultsStore.shared.setUUID(_:forKey:)` on the spot (= the P2
//  finding in the 2026-11-21 root-cause plan, §1.5), so every click on
//  the tab strip / Cmd-Shift-Bracket ran a defaults write inside the
//  same frame the editor zone had to produce its first frame in. A
//  discrete user interaction gets no I/O in its frame. The write is
//  still owed (= a launch must reopen the tab the user left on); this
//  type is where it went instead.
//
//  THE SHAPE: one pending value, one flush outside the frame that set
//  it. `markSwitched(to:)` overwrites the slot (= coalescing, not
//  queuing: a burst of ten switches owes one write of the last id, not
//  ten writes of ids nobody is looking at) and asks the main actor for
//  a turn after the current one. There is NO clock in this file: the
//  hop is a one-shot `Task`, not a `Timer` and not a `while` loop, so
//  nothing runs when nothing changed (= the house rule the right
//  column's change-to-view path was written under).
//
//  WHY THE FLUSH STAYS ON THE MAIN ACTOR. Moving the write to a
//  background queue would take the last main-thread instruction out of
//  the switch frame, but it would buy a second writer to the same key
//  and make "the id persisted is the newest switch" depend on queue
//  ordering instead of on the one actor that owns the value. The frame
//  that matters is the interaction's own turn, and one scalar defaults
//  set on a later turn is what this ticket removed from it.
//
//  THE DURABILITY POINTS THAT FLUSH EARLY. A switch followed by
//  nothing else is written by the hop. `AppState.closeTab` is
//  different: the id it rewrites must never be left naming a document
//  that is no longer open (= a correctness invariant, not a staleness
//  one; see the close-last-tab comment there), and that path already
//  flushes the draft file and the tabs' snapshot synchronously, so it
//  asks for the write instead of waiting for a turn.
//

import Foundation

/// The ONE writer of `WenshuDefaultsKey.activeTabId`.
///
/// Built per `AppState`, and the app has exactly ONE `AppState` for the
/// process (= `WenshuAppMain.swift`'s `private static let sharedAppState`),
/// so today there is one pending slot and one writer process-wide — NOT
/// one per window. A second window would share this slot and this key
/// (as it already shares the id the observer writes), which is the
/// behaviour the old synchronous write had too; the `weak` capture in
/// the hop is about that one object's lifetime, not about per-window
/// state.
@MainActor
final class ActiveTabPersistence {
    /// The id the user switched to that has not reached disk. nil = the
    /// disk already agrees with memory.
    ///
    /// `private(set)` and readable: it is how a test sees the pending
    /// half of the contract without waiting for anything.
    private(set) var pendingActiveTabId: UUID?

    /// True while the one-shot hop waits for its turn. This is a GATE,
    /// not a counter: `markSwitched` raises it on the first switch and
    /// every later switch of a burst sees it already raised, so the
    /// boolean reads true whether or not the burst coalesced. What a
    /// test counts is `hopCount` below.
    private(set) var isFlushHopQueued = false

    /// How many hops have actually run. A coalesced burst takes ONE
    /// hop however many switches fed it, so this grows by 1 for ten
    /// switches; a per-switch queue (= the `guard` in `markSwitched`
    /// removed) grows by ten. That difference is the coalescing claim,
    /// and no boolean can carry it.
    private(set) var hopCount = 0

    private let store: UserDefaultsStore

    init(store: UserDefaultsStore) {
        self.store = store
    }

    /// The tab-switch path. Records the value and asks for one write
    /// outside this frame; touches no storage.
    func markSwitched(to id: UUID) {
        pendingActiveTabId = id
        // THE COALESCING LINE. Without it every switch of a burst
        // queues its own hop and the slot is a queue, which is what
        // `hopCount` exists so a test can tell the two apart.
        guard !isFlushHopQueued else { return }
        isFlushHopQueued = true
        // A one-shot hop, not a clock: this runs once, drains the slot,
        // and never runs again until a switch asks for it. Capturing the
        // persistence object weakly so a window that closed mid-frame
        // cannot be kept alive by its own pending write.
        Task { @MainActor [weak self] in
            self?.takeTheHop()
        }
    }

    /// Write the pending value now (= the durability points call this;
    /// idempotent: nothing pending, nothing written).
    func flush() {
        guard let pending = pendingActiveTabId else { return }
        pendingActiveTabId = nil
        store.setUUID(pending, forKey: .activeTabId)
    }

    /// The hop landed. It counts itself first (= `hopCount` is what a
    /// coalescing test reads: a burst that folded into one hop moves
    /// it by 1, a per-switch queue moves it by the burst's size), then
    /// clears the flag BEFORE the write so a switch made by the write's
    /// own call stack (= none today) still gets a hop.
    private func takeTheHop() {
        hopCount += 1
        isFlushHopQueued = false
        flush()
    }
}
