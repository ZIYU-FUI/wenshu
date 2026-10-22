//
//  Features/Cover/Service/CoverReconciler.swift
//
//   : CoverReconciler.
//  Removes the covers whose document is gone.
//
//  The cascade removes a cover when the app deletes a document. The
//  reconciler is the second line of defence, for the documents the
//  app did NOT delete:
//
//  - a file removed in Finder,
//  - a script or a sync client that removed it,
//  - a git checkout that brought a different tree.
//
//  In each of those cases the cover is an orphan: a row and a file
//  for a card that no longer exists. The cover can never be shown
//  again, so it is dead weight in the library, and it is the sort of
//  thing that accumulates silently until a user wonders where the
//  space went.
//
//  The DECISION is a pure function of (the live card keys, the cover
//  keys), so it can be tested without a library, a store or a disk.
//  The sweep that acts on the decision needs all three, and runs on
//  the library reload that already happens.
//

import Foundation
import SwiftData
import WenshuData
import os

private let coverReconcilerLogger = Logger(subsystem: "com.wenshu", category: "coverreconciler")

/// Removes the covers whose document no longer exists.
@MainActor
struct CoverReconciler {

    /// The store that holds the cover rows.
    let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// The reconciler over the library the app is running on.
    static func live() -> CoverReconciler {
        CoverReconciler(modelContext: WSPersistenceContainer.current.mainContext)
    }

    // MARK: - The decision

    /// The cover keys whose card is no longer alive.
    ///
    /// Pure: the same inputs always give the same answer, and no
    /// clock, disk or store is involved.
    static func orphanKeys(liveCardKeys: Set<String>, coverKeys: Set<String>) -> Set<String> {
        coverKeys.subtracting(liveCardKeys)
    }

    // MARK: - The sweep

    /// Removes every cover whose card is not in the live set.
    ///
    /// - Parameter liveCardKeys: the cover keys of the cards that
    ///   still exist.
    /// - Returns: how many covers were removed.
    @discardableResult
    func sweep(liveCardKeys: Set<String>) -> Int {
        let service = CardCoverService(modelContext: modelContext)
        let coverKeys = Set(service.allRows().map(\.id))
        let orphans = Self.orphanKeys(liveCardKeys: liveCardKeys, coverKeys: coverKeys)

        for key in orphans {
            do {
                try service.removeCover(forKey: key)
            } catch {
                // A cover that cannot be removed is not worth failing
                // the reload over; the next sweep will try again.
                coverReconcilerLogger.error(
                    "[wenshu.cover] orphan cover removal failed key=\(key, privacy: .public): \(String(describing: error), privacy: .public)"
                )
            }
        }
        if !orphans.isEmpty {
            coverReconcilerLogger.info("[wenshu.cover] removed \(orphans.count) orphan cover(s)")
        }
        return orphans.count
    }
}
