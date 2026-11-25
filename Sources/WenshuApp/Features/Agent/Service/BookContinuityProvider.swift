//
//  BookContinuityProvider.swift
//
//  The report the app hands the agent's turn.
//
//  Why: the agent runtime does not own a book, = = the book lives on
//  disk under the library, = = so the app reads it and hands the turn
//  what it says. This is the same seam the memory provider uses: = =
//  the runtime holds a provider and reads it per turn, = = and the app
//  decides what the provider is.
//
//  The book comes from the turn's own scope, = = the same way the
//  agent's other book-scoped tools find it, = = so a conversation
//  about one book carries that book's report and a conversation about
//  another carries the other.
//
//  The book is read once per turn and the report is cached, = = so a
//  conversation does not re-read the whole book on every message. The
//  cache is dropped when the library says it changed, = = which is the
//  app's own signal (= the same one the editor's fingerprint cache
//  uses).
//

import Foundation
import WenshuAgent
import WenshuData

/// The app's source of a turn's continuity report.
actor BookContinuityProvider: ContinuityProvider {
    /// Where the library's shelves live (= the root every book sits
    /// under). Nil = the user has picked no library yet.
    private let shelvesRoot: URL?
    /// The cached report, and the book it was read from.
    private var cached: (bookID: String, report: ContinuityReport)?
    /// The task watching the library's change signal (= the app posts
    /// it after every write it makes).
    private var watch: Task<Void, Never>?

    /// The app's provider, built from the library the user has picked.
    ///
    /// The library root is the app's own single accessor (= the same
    /// one every consumer reads), = = and the shelves sit under it.
    static func live() -> BookContinuityProvider {
        let root = ActiveLibrary.path.map {
            URL(fileURLWithPath: $0).appendingPathComponent("shelves", isDirectory: true)
        }
        return BookContinuityProvider(shelvesRoot: root)
    }

    init(shelvesRoot: URL?) {
        self.shelvesRoot = shelvesRoot
    }

    deinit {
        watch?.cancel()
    }

    /// The report for the book the current turn is about.
    ///
    /// The turn's book comes from the turn's own scope, = = so a turn
    /// that names no book carries no report.
    func continuityReport() async -> ContinuityReport {
        // The library's change signal is watched from here, = = not
        // from the initializer: = = an actor's initializer cannot call
        // an isolated method, = = and the first report is the first
        // moment the watch matters.
        if watch == nil {
            observeLibraryChanges()
        }
        guard let bookID = TurnScope.currentBookID else {
            return ContinuityReport()
        }
        if let cached, cached.bookID == bookID {
            return cached.report
        }
        guard let directory = bookDirectory(bookID: bookID) else {
            return ContinuityReport()
        }
        let report = BookContinuityReader(bookDirectory: directory).report()
        cached = (bookID, report)
        return report
    }

    /// The directory of the book with an id.
    ///
    /// A book id is unique across the library and it lives in exactly
    /// one shelf, = = so the shelves are walked. = = This is the same
    /// walk the app's own book-directory lookup does, = = and it is
    /// bounded by the user's library size.
    private func bookDirectory(bookID: String) -> URL? {
        guard let shelvesRoot else { return nil }
        let fileManager = FileManager.default
        guard let shelves = try? fileManager.contentsOfDirectory(
            atPath: shelvesRoot.path
        ) else { return nil }
        for shelf in shelves {
            let candidate = shelvesRoot
                .appendingPathComponent(shelf, isDirectory: true)
                .appendingPathComponent("books", isDirectory: true)
                .appendingPathComponent(bookID, isDirectory: true)
            if fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }

    /// Drop the cached report when the library says it changed.
    ///
    /// The watch is a task over the notification's own async sequence,
    /// = = so there is no observer token to keep, = = and cancelling
    /// the task is the whole teardown.
    private func observeLibraryChanges() {
        watch = Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: .wenshuLibraryDidChange) {
                await self?.invalidate()
            }
        }
    }

    /// Forget the cached report.
    private func invalidate() {
        cached = nil
    }
}
