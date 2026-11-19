//
//  CoverChangeSignal.swift · Wenshu
//
//  One place that says "a card's cover changed on the disk".
//
//  Why this exists:
//
//  A card asks the cover store what its cover holds on every render,
//  and the store answers from memory, so a removal drops the memory
//  and the next question goes to the disk. That half already worked.
//  What did not work is the other half: NOTHING TOLD THE CARD TO ASK
//  AGAIN. Making a clip has an in-flight phase the card watches
//  (= `isMakingVideo`), so a card re-renders when the clip lands.
//  Removing one has no phase at all, so the removal was over before
//  the card's next pass, and a card that was not told to ask again
//  kept drawing a clip the disk no longer held. The boss met exactly
//  that on 2026-11-19: the click took the file away and the card went
//  on showing the motion.
//
//  The library's own announcement is NOT the door to use here.
//  `.wenshuLibraryDidChange` re-reads the whole document list and
//  asks the automatic cover pass about every document it then sees,
//  so a cover removal that announced itself that way would spend the
//  image allowance to put back what the user had just taken away.
//
//  So the signal is cover-scoped, and the material zone reads it at
//  ONE door: `coverEntry(for:)`, which is where every card's cover is
//  looked up. A card builder therefore needs no wiring of its own.
//

import Foundation
import Observation

/// Says that a card's cover changed on the disk.
@MainActor
@Observable
final class CoverChangeSignal {
    /// The one signal the app's covers change through.
    ///
    /// Shared, and not a property of the pane: the service that takes
    /// a cover away is not always the service the pane holds (= a
    /// batch run, an automatic pass, a test), and the card that has
    /// to ask again does not know which one asked for the removal.
    static let shared = CoverChangeSignal()

    private init() {}

    /// How many times a cover changed.
    ///
    /// The NUMBER is not the point: a view that reads it renders
    /// again when it moves, and rendering again is what makes the
    /// card ask the disk what its cover holds now.
    private(set) var revision: Int = 0

    /// Says that a cover's files changed.
    func noteCoverChanged() {
        revision &+= 1
    }
}
