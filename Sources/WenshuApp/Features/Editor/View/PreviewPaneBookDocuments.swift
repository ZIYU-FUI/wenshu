//
//  PreviewPaneBookDocuments.swift
//
//  The book scope's documents, loaded ONCE and OFF the main thread.
//
//  WHY THIS FILE EXISTS
//
//  The material column's book scope read its documents from inside a
//  SwiftUI ViewBuilder body. SwiftUI re-evaluates a body on every
//  observation tick (= every store mutation, every selection change,
//  every parent re-render), so the walk ran hundreds of times per second
//  while the book was selected = = and the chrome's card count walked
//  the SAME book a SECOND time per pass.
//
//  ⇒ ⇒ ⇒ MEASURED on the real library (= = the probe
//  ⇒ ⇒ ⇒ ⇒ ⇒ `Tools/wenshu-devtool/probes/card_surfaces_load_cost.swift`
//  ⇒ ⇒ ⇒ ⇒ ⇒ reads the numbers, = = so they are the probe's and the
//  ⇒ ⇒ ⇒ ⇒ ⇒ probe is how they are re-measured): = = one body pass
//  ⇒ ⇒ ⇒ ⇒ ⇒ walked the book TWICE (= = the grid and the chrome's
//  ⇒ ⇒ ⇒ ⇒ ⇒ count), = = read 123854 bytes, = = and the walk's p95
//  ⇒ ⇒ ⇒ ⇒ ⇒ sits in the MILLISECONDS. = = Apple's own line is 5ms
//  ⇒ ⇒ ⇒ ⇒ ⇒ of main-thread work in one frame (= = Xcode's "Improving
//  ⇒ ⇒ ⇒ ⇒ ⇒ app responsiveness" article), = = so the pass was over
//  ⇒ ⇒ ⇒ ⇒ ⇒ the line at p95. = = And the pass runs in the frame that
//  ⇒ ⇒ ⇒ ⇒ ⇒ draws the chat zone's tab switch (= = the tree's
//  ⇒ ⇒ ⇒ ⇒ ⇒ selection follows the chat tab, = = so the material
//  ⇒ ⇒ ⇒ ⇒ ⇒ column's walk lands in the tab switch's frame).
//
//  ⇒ ⇒ ⇒ So the walk moves HERE: OFF the main thread (= the disk ask
//  is the expensive part, = = and the main thread is what the
//  tab switch needs), and OFF the body pass (= into a store the
//  pane's `.task(id:)` loads once per scope change).
//
//  ⇒ ⇒ ⇒ AND THE HEAD-ONLY READ: = = a card needs its title, its chip
//  tag (= the file's first H1) and its summary (= the first 200
//  characters after that H1) = = and all three live in the
//  file's HEAD. = = The whole-library scope already reads heads
//  only (= with its fallback to the whole file when the head
//  does not hold the card) = = and that fallback is what makes
//  the card show exactly what it showed before. = = So the book
//  scope reads the same way = = and the card a book document
//  draws is byte-identical.
//
//  ⇒ ⇒ ⇒ AND THE HEAD READ IS ONE DOOR: = = the whole-library scope
//  and the book scope both need "what does this .md's HEAD say",
//  = = so the head read lives HERE and the whole-library loader
//  asks this file for it (= = one door for one question).
//
//  ⇒ ⇒ ⇒ AND THE LOADER IS `nonisolated`: = = the disk walk touches no
//  actor state (= a URL, a file name, a date) = = so it runs on
//  a background task = = the same shape `CoverIndex` uses for
//  the cover walk.
//

import Foundation

// MARK: - The head read (= ONE door for both scopes)

/// What a .md's head says (= the card's three facts).
///
/// = = The card needs the title (= the file name), the chip tag (= the
/// = = file's first H1) and the summary (= the first 200 characters
/// = = after that H1) = = and all three live in the file's HEAD.
enum BookDocumentHead {
    /// How many bytes of a .md the card needs.
    ///
    /// = = The summary is the first 200 characters after the H1, = = and
    /// = = the H1 sits at the top of a chapter, = = so 8 KB holds both
    /// = = with room to spare. = = A chapter's body (= = the document's
    /// = = content) is not read here.
    static let headByteCount = 8 * 1024

    /// What a head read found.
    enum HeadRead {
        /// The whole file (= = the file is shorter than the head).
        case whole(String)
        /// The head of a longer file (= = and whether it holds EVERYTHING
        /// the card needs: = = the H1 line complete = = and the summary's
        /// whole window after it).
        case head(String, holdsTheCard: Bool)
        /// The head could not be decoded (= = the caller must read the
        /// whole file).
        case undecodable
    }

    /// Read a file's head.
    ///
    /// = = INTERNAL (= = not private) = = so the test can pin the READ
    /// = = itself (= = the card's content is the same whether the head
    /// = = read works or falls back, = = so only the read's own result
    /// = = can tell the two apart).
    ///
    /// = = The read stops at the head's byte count, = = and a head that
    /// = = ends mid-character keeps its COMPLETE characters (= = the
    /// = = trailing incomplete one is dropped) = = so a CJK document's
    /// = = head is still a head (= = dropping the whole read would make
    /// = = the head read a whole-body read for every CJK file, = = =
    /// = = because the cut lands inside a character in almost every one
    /// = = of them).
    ///
    /// = = A head that cannot be decoded AT ALL is reported as
    /// = = undecodable (= = so the caller reads the whole file and the
    /// = = card shows exactly what it showed before).
    static func readHead(of url: URL) -> HeadRead {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return .undecodable }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: headByteCount) else { return .undecodable }
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        guard let text = Self.decodePrefix(data) else { return .undecodable }
        if size <= headByteCount {
            return .whole(text)
        }
        // The file is longer than the head: = = the head is a prefix,
        // = = and the card can be built from it ONLY when the head holds
        // = = everything the card needs.
        return .head(text, holdsTheCard: headHoldsTheCard(text))
    }

    /// Whether the head holds everything the card needs.
    ///
    /// = = The card needs TWO things from the body: = = the chip tag (= =
    /// = = the H1's text) = = and the summary (= = the first 200
    /// = = characters of the body after that H1).
    ///
    /// = = ⇒ The head is sufficient when it holds the H1 line COMPLETE
    /// = = (= not cut by the head's boundary, = = or the chip tag is a
    /// = = truncated title) = = AND at least 200 characters of the body
    /// = = after it (= = or the summary is shorter than the whole-body
    /// = = = read's).
    ///
    /// = = ⇒ AND the head's LAST line may be cut (= = the head's
    /// = = boundary can land in the middle of a line), = = so the check
    /// = = runs on the head's COMPLETE lines only (= = the lines before
    /// = = that cut).
    static func headHoldsTheCard(_ text: String) -> Bool {
        let (h1, body) = PreviewPaneOps.splitFirstH1(Self.completeLines(of: text))
        guard h1 != nil else { return false }
        return body.count >= 200
    }

    /// The text's COMPLETE lines (= = minus a last line that a read's
    /// boundary may have cut).
    private static func completeLines(of text: String) -> String {
        guard !text.hasSuffix("\n") else { return text }
        guard let lastNewline = text.lastIndex(of: "\n") else { return "" }
        return String(text[...lastNewline])
    }

    /// Decode a byte block, = = dropping a trailing incomplete
    /// character.
    ///
    /// = = A UTF-8 character is at most four bytes, = = so a block that
    /// = = ends mid-character is repaired by dropping up to three
    /// = = trailing bytes (= = and the longest decodable prefix is what
    /// = = the caller gets).
    private static func decodePrefix(_ data: Data) -> String? {
        if let text = String(data: data, encoding: .utf8) {
            return text
        }
        var trimmed = data
        for _ in 0 ..< 3 {
            guard !trimmed.isEmpty else { return nil }
            trimmed = trimmed.dropLast()
            if let text = String(data: trimmed, encoding: .utf8) {
                return text
            }
        }
        return nil
    }

    /// Build one document's card metadata from its file (= = its head).
    ///
    /// = = ⇒ The body is NOT read here. = = The document's body is read
    /// = = when the document is OPENED (= = `CardOpenOps.loadBookDocBody`,
    /// = = which reads the file from disk), = = so a truncated body never
    /// = = reaches the editor.
    ///
    /// = = ⇒ The head is EXACT: = = the file's first H1 may sit
    /// = = anywhere, = = so a head with no H1 in it (= = and the file is
    /// = = longer than the head) falls back to the whole file, = = and a
    /// = = head that would cut a multi-byte character in half falls back
    /// = = too. = = The card then shows exactly what it showed before.
    static func document(bookId: UUID, folderName: String, url: URL) -> BookDoc? {
        let rawBody: String
        switch readHead(of: url) {
        case let .whole(text):
            rawBody = text
        case let .head(text, holdsTheCard: false):
            // The head does NOT hold everything the card needs (= = its
            // H1 was cut by the head's boundary, = = or the body after
            // that H1 is shorter than the summary's window), = = so the
            // whole file is read (= = and the card shows exactly what
            // it showed before).
            rawBody = (try? String(contentsOf: url, encoding: .utf8)) ?? text
        case let .head(text, holdsTheCard: true):
            // The head holds the H1 line COMPLETE = = and the summary's
            // whole 200-character window after it, = = so the card shows
            // exactly what it showed before.
            rawBody = text
        case .undecodable:
            rawBody = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        }
        let (firstH1, bodyWithoutH1) = PreviewPaneOps.splitFirstH1(rawBody)
        let attrs = try? url.resourceValues(forKeys: [
            URLResourceKey.contentModificationDateKey,
            URLResourceKey.creationDateKey,
        ])
        return BookDoc(
            id: PreviewPane.stableBookDocId(
                bookId: bookId,
                folderName: folderName,
                fileName: url.lastPathComponent
            ),
            bookId: bookId,
            folderName: folderName,
            fileName: url.lastPathComponent,
            modifiedAt: attrs?.contentModificationDate ?? Date.distantPast,
            createdAt: attrs?.creationDate ?? Date.distantPast,
            tags: firstH1.map { [$0] } ?? [],
            body: bodyWithoutH1
        )
    }
}

// MARK: - The loader

/// Reads one book's documents off the main thread.
///
/// = = The loader takes PLAIN VALUES (= a shelves root, a book id, a
/// = = folder name) = = and never touches a SwiftData model = = so it
/// = = can run on a background task = = and its result crosses back as
/// = = a value.
enum BookDocumentLoader {
    /// One book's folder names to scan (= nil = every standard folder).
    static func folderNames(for folderName: String?) -> [String] {
        guard let folderName else {
            return BookFolder.allCases.map(\.directoryName)
        }
        return [folderName]
    }

    /// Find the book directory under the shelves root.
    ///
    /// = = The walk is N shelves (= bounded by the user's library) = =
    /// = = and it is the same walk `BookStore.bookDirectory` does.
    nonisolated static func bookDirectory(
        shelvesRoot: URL,
        bookId: UUID
    ) -> URL? {
        let fm = FileManager.default
        guard let shelfEntries = try? fm.contentsOfDirectory(
            at: shelvesRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return nil }
        for shelfEntry in shelfEntries {
            let candidate = shelfEntry
                .appendingPathComponent("books", isDirectory: true)
                .appendingPathComponent(bookId.uuidString, isDirectory: true)
            if fm.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }

    /// Read one book's documents (= every .md in its folders).
    nonisolated static func load(
        shelvesRoot: URL,
        bookId: UUID,
        folderName: String?
    ) -> [BookDoc] {
        guard let bookDir = bookDirectory(shelvesRoot: shelvesRoot, bookId: bookId) else {
            return []
        }
        let fm = FileManager.default
        var docs: [BookDoc] = []
        for folder in folderNames(for: folderName) {
            let dir = bookDir.appendingPathComponent(folder)
            guard let entries = try? fm.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [
                    URLResourceKey.contentModificationDateKey,
                    URLResourceKey.creationDateKey,
                ],
                options: [.skipsHiddenFiles]
            ) else { continue }
            for url in entries where url.pathExtension == "md" {
                guard let doc = BookDocumentHead.document(
                    bookId: bookId,
                    folderName: folder,
                    url: url
                ) else {
                    continue
                }
                docs.append(doc)
            }
        }
        return docs
    }
}

// MARK: - The store

/// The book scope's documents, held ONCE (= = not once per body pass).
///
/// = = An `@Observable` object (= = the house's store shape, = = the same
/// = = one `LibraryDocumentStore` uses): = = the pane's body reads
/// = = `documents`, = = and the load writes them, = = so the view updates
/// = = when the load lands.
///
/// = = ⇒ AND THE COUNT READS THIS SAME LIST: = = the chrome's card count
/// = = = = the grid's list = = so one walk answers both questions (= =
/// = = the one-door rule) = = and the two answers cannot drift apart.
@MainActor
@Observable
final class BookDocumentStore {
    /// The documents (= = empty until the first load lands).
    private(set) var documents: [BookDoc] = []

    /// Whether the documents have been loaded at least once.
    private(set) var isLoaded = false

    /// The book the documents belong to (= = nil until the first load
    /// lands).
    ///
    /// = = ⇒ The chrome's card count asks this: = = the count reads the
    /// = = store's list, = = and the list belongs to ONE book = = so the
    /// = = count must know it is counting the right book (= = the pane
    /// = = shows the list of the scope it is in, = = and the count is in
    /// = = the pane's chrome = = so both read the same scope).
    private(set) var bookId: UUID?

    /// The folder the documents belong to (= = nil = every folder).
    ///
    /// = = ⇒ The count asks this too: = = a book's "chapters" scope and
    /// = = the book's "everything" scope are DIFFERENT lists (= = and the
    /// = = count must not answer one scope's number for the other's).
    private(set) var folderName: String?

    /// The key of the load that is current (= = the book + the folder +
    /// = = the library-change tick).
    ///
    /// = = NOT observable (= = `@ObservationIgnored`): = = the body sets
    /// = = it while it runs, = = and an observable write there would make
    /// = = the view invalidate itself mid-update.
    @ObservationIgnored private var loadedKey: String?

    /// Which read is the current one (= = the newest one that started).
    ///
    /// = = ⇒ AND IT IS A COUNTER, NOT THE KEY: = = a read that starts
    /// = = ⇒ FIRST can land SECOND (= = the disk is faster for one book
    /// = = ⇒ than another). = = A key comparison cannot tell the two
    /// = = ⇒ apart (= = the older read can set the key, = = and then its
    /// = = ⇒ own check passes). = = ⇒ ⇒ So every read takes the next
    /// = = ⇒ number, = = and only the newest number may write.
    ///
    /// = = ⇒ AND IT IS READABLE BY THE TEST: = = the test needs to know
    /// = = ⇒ that the older read HAS STARTED (= = so the newer one
    /// = = ⇒ starts second, = = deterministically).
    @ObservationIgnored var currentLoadGeneration: Int = 0

    /// Read the book's documents and land them (= = the one read).
    ///
    /// = = This is the store's ONLY door (= = the pane's `.task(id:)` and
    /// = = a test both come here): = = the read is disk IO, = = and it runs
    /// = = ONCE per key (= = not once per body pass, = = which was the
    /// = = cost this change removes).
    ///
    /// = = ⇒ AND THE READ RUNS OFF THE MAIN ACTOR: = = the walk touches
    /// = = no actor state (= = a URL, = = a file name, = = a date), = =
    /// = = so it runs on a background task = = and the main thread is
    /// = = free for the frame that drew the chat zone's tab switch.
    ///
    /// = = ⇒ ⇒ ⇒ AND WHY A DETACHED TASK IS THE RIGHT DOOR HERE: = =
    /// = = ⇒ ⇒ ⇒ AGENTS.md 4.5's rule is about background WRITES (= =
    /// = = ⇒ ⇒ ⇒ "never a detached task on the context" = = = = the
    /// = = ⇒ ⇒ ⇒ SwiftData context). = = ⇒ ⇒ ⇒ This read writes
    /// = = ⇒ ⇒ ⇒ NOTHING (= = it reads files and returns plain values),
    /// = = = = so the context's rule does not reach it. = = ⇒ ⇒ ⇒ And
    /// = = ⇒ ⇒ ⇒ the house's own background READ uses this exact shape
    /// = = ⇒ ⇒ ⇒ (= = `CoverIndex.prefill` walks the covers in a
    /// = = ⇒ ⇒ ⇒ detached task).
    ///
    /// = = ⇒ AND THE KEY IS THE GUARD: = = a caller whose key is already
    /// = = loaded does not read again (= = so the pane's task and a
    /// = = test's own call cannot read the book twice for the same list).
    func loadNow(
        key: String,
        shelvesRoot: URL?,
        bookId: UUID,
        folderName: String?
    ) async {
        guard loadedKey != key || !isLoaded else { return }
        loadedKey = key
        currentLoadGeneration &+= 1
        let generation = currentLoadGeneration
        // The list for THIS key is not here yet.
        //
        // ⇒ ⇒ ⇒ AND THE IDENTITY IS NOT TOUCHED YET: = = the identity
        // (= = which book, = = which folder) names the documents
        // the store HOLDS, = = so it can only be set together with
        // them. = = Setting it first would let the PREVIOUS book's
        // documents answer "is this the right book?" under the NEW
        // book's name (= = and the grid would draw book A's cards in
        // book B's scope).
        isLoaded = false
        await Task.yield()
        guard let shelvesRoot else {
            documents = []
            self.bookId = bookId
            self.folderName = folderName
            isLoaded = true
            return
        }
        let loaded = await Task.detached(priority: .userInitiated) {
            BookDocumentLoader.load(
                shelvesRoot: shelvesRoot,
                bookId: bookId,
                folderName: folderName
            )
        }.value
        // ⇒ ⇒ ⇒ AND A STALE READ IS DROPPED: = = the scope can change
        // while the read runs (= = the user picked another book),
        // and the read that started first can land SECOND. = = So
        // the read asks "is my key still the current one?" = = and
        // drops its result when it is not (= = = = the old book's
        // documents must never answer the new book's scope).
        guard currentLoadGeneration == generation else { return }
        // The identity and the documents land TOGETHER (= = no await
        // between them), = = so a reader never sees one book's name over
        // another book's documents.
        documents = loaded
        self.bookId = bookId
        self.folderName = folderName
        isLoaded = true
    }
}
