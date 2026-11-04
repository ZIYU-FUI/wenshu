//
//  SubAgentKanbanBridge.swift · Wenshu
//
//  Moves the kanban card that shows a research delegation's progress.
//
//  The card used to be created and then never touched. = A research
//  noun became a card in "new", = the delegation ran, = and the card
//  stayed in "new" whether the research had produced an answer or
//  failed outright. = The board was therefore a list of intentions, =
//  not a list of what happened. = The user could not tell a finished
//  research from a queued one.
//
//  This bridge is the missing half: = when the run ends, the card
//  moves to where the run actually got to. = "done" for a run that
//  produced an answer, = "failed" for one that did not.
//
//  Two properties, and why:
//
//  - The card's status follows the RUN, = not the tool call that
//    created it. = The card is created before the run starts, = so
//    creating it in "running" is the honest state; = a card that says
//    "new" while the research is already in flight is a lie.
//  - A missing card is not an error. = Most delegations have no card
//    (= only research nouns make one), = so a run with no card id has
//    nothing to move, = and that is the normal case.
//

import Foundation
import WenshuData

/// Moves a delegation's kanban card when the delegation ends.
///
/// The card lives in the same main-actor-isolated store as the rest
/// of the app's SwiftData work, = and the runner that calls this is
/// main-actor too, = so the bridge sits there too.
@MainActor
struct SubAgentKanbanBridge {

    /// The repository the card lives in.
    let repository: WSKanbanRepository

    init(repository: WSKanbanRepository) {
        self.repository = repository
    }

    /// The card states a run can be in.
    ///
    /// A run has three outcomes, = and that is fewer than the board's
    /// states, = so this is its own enum (= `typealias` to
    /// `KanbanStatus` would let a caller say "blocked" for a run, =
    /// which is not a thing a run does). The words are still the
    /// board's words: = the raw values are the same strings the board
    /// uses, = so a card moved from here is a card the board reads
    /// correctly.
    enum CardState: String, Sendable, Equatable {
        /// The run is in flight.
        case running = "running"
        /// The run produced an answer.
        case done = "done"
        /// The run did not produce an answer.
        case failed = "failed"
    }

    /// Move the card for a finished run.
    ///
    /// - Parameters:
    ///   - cardID: the card's id (= nil = no card was made, = so there
    ///     is nothing to move).
    ///   - state: where the run ended.
    /// - Returns: whether the card moved.
    @discardableResult
    func move(cardID: String?, to state: CardState) -> Bool {
        guard let cardID, !cardID.isEmpty else { return false }
        do {
            try repository.transition(id: cardID, to: state.rawValue)
            return true
        } catch {
            // A card that cannot be moved (= it was deleted, = or the
            // store is unavailable) must not fail the run. = The run's
            // own outcome is recorded in the ledger, = and the
            // conversation gets the result either way.
            return false
        }
    }
}
