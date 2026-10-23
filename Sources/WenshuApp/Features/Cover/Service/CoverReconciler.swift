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
//  The DECISION is a pure function of the live card keys and the
//  cover keys, so it can be tested without a library, a store or a
//  disk. The sweep that acts on the decision needs both, and runs on
//  the library reload that already happens.
//
//  A kind whose live cards could not be listed is LEFT ALONE. An
//  unknown set is not an empty set: a cover whose card is alive must
//  never be deleted because the listing failed.
//

import Foundation
import WenshuData
import os

private let coverReconcilerLogger = Logger(subsystem: "com.wenshu", category: "coverreconciler")

/// Removes the covers whose document no longer exists.
@MainActor
struct CoverReconciler {

    init() {}

    /// The reconciler over the library the app is running on.
    static func live() -> CoverReconciler {
        CoverReconciler()
    }

    // MARK: - The live cards

    /// The ids of the book docs that are still on disk.
    ///
    /// A book doc's id comes from its path (= book + folder + file
    /// name), so the ids come from walking the shelves root the way
    /// the sidebar walks it.
    ///
    /// Nil when the shelves root could not be read: an unknown set
    /// is not an empty set.
    static func bookDocIds(shelvesRoot: URL) -> [UUID]? {
        guard FileManager.default.fileExists(atPath: shelvesRoot.path) else { return nil }
        guard let shelves = try? FileManager.default.contentsOfDirectory(
            at: shelvesRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return nil }

        var ids: [UUID] = []
        for shelf in shelves {
            let booksRoot = shelf.appendingPathComponent("books", isDirectory: true)
            guard let books = try? FileManager.default.contentsOfDirectory(
                at: booksRoot,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }
            for book in books {
                // A directory whose name is not a book id holds no
                // cover, so it is skipped rather than given a made-up
                // id (= a made-up id matches no cover, and the walk
                // would keep looking).
                guard let bookId = UUID(uuidString: book.lastPathComponent) else { continue }
                guard let folders = try? FileManager.default.contentsOfDirectory(
                    at: book,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                ) else { continue }
                for folder in folders {
                    let folderName = folder.lastPathComponent
                    guard let files = try? FileManager.default.contentsOfDirectory(
                        at: folder,
                        includingPropertiesForKeys: nil,
                        options: [.skipsHiddenFiles]
                    ) else { continue }
                    for file in files where file.pathExtension == "md" {
                        ids.append(BookDocIDFactory.make(
                            bookId: bookId,
                            folderName: folderName,
                            fileName: file.lastPathComponent
                        ))
                    }
                }
            }
        }
        return ids
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
    /// - Parameters:
    ///   - liveReferenceIds: the ids of the references that still
    ///     exist. Nil when the reference library could not be read.
    ///   - shelvesRoot: the shelves root, where the book docs live.
    ///     Nil when the library is not known.
    /// - Returns: how many covers were removed.
    @discardableResult
    func sweep(liveReferenceIds: [UUID]?, shelvesRoot: URL?) -> Int {
        // The library reload means the library may have changed on
        // disk, so what the app remembers about its covers is dropped
        // and read again.
        CoverEntryCache.shared.removeAll()

        let service = CardCoverService()
        let coverKeys = service.storedKeys()
        // Nothing to reconcile: the cheap check first, because the
        // walk over the library is the expensive part.
        guard !coverKeys.isEmpty else { return 0 }

        var removed = 0

        // Each kind is walked only when it has a cover to check, so
        // a library with only reference covers never walks the book
        // folders. The kind is in the key, so a cover folder says
        // which card it belongs to without a record to read.
        let referenceKeys = coverKeys.filter { $0.hasPrefix("\(WSCardCoverKind.reference)-") }
        if let liveReferenceIds, !referenceKeys.isEmpty {
            let liveKeys = Set(liveReferenceIds.map { CardCoverService.key(forReference: $0) })
            removed += remove(
                service: service,
                keys: referenceKeys,
                liveKeys: liveKeys
            )
        }

        let bookDocKeys = coverKeys.filter { $0.hasPrefix("\(WSCardCoverKind.bookDoc)-") }
        if let shelvesRoot,
           !bookDocKeys.isEmpty,
           let liveBookDocIds = Self.bookDocIds(shelvesRoot: shelvesRoot) {
            let liveKeys = Set(liveBookDocIds.map { CardCoverService.key(forBookDoc: $0) })
            removed += remove(
                service: service,
                keys: bookDocKeys,
                liveKeys: liveKeys
            )
        }

        if removed > 0 {
            coverReconcilerLogger.info("[wenshu.cover] removed \(removed) orphan cover(s)")
        }
        return removed
    }

    /// Removes the covers of one card kind whose card is gone.
    private func remove(
        service: CardCoverService,
        keys: [String],
        liveKeys: Set<String>
    ) -> Int {
        let orphans = Self.orphanKeys(
            liveCardKeys: liveKeys,
            coverKeys: Set(keys)
        )
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
        return orphans.count
    }
}
