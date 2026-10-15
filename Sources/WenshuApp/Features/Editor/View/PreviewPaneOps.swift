// PreviewPaneOps.swift · Wenshu Reference-card data loading + sorting business layer,
// extracted from PreviewPane (= the largest P0 view listed in
// .scratch/2026-09-23-mvvm-audit/spec.md §9 arc). Per KanbanOps template (= @MainActor
// enum + Result types + static funcs). Per one ticket per file. Per the rule:
// "PreviewPane single-consumer (B)" (= BookDocLoaderOps is PreviewPane's private copy;
// = future ticket lifts to shared service when PaneView consumes it too). Public
// surface (= 11 entry points + 5 Result types): 1. loadAllEntities(bookStore:) ->
// LoadEntitiesResult 2. loadBooksInShelf(bookStore:shelfId:) -> LoadBooksResult 3.
// loadShelfBooksAsync(bookStore:shelfId:) async -> LoadBooksResult 4.
// loadBody(bookStore:for:) -> LoadBodyResult 5.
// loadBookDocs(bookStore:bookId:folderName:) -> LoadBookDocsResult 6.
// sortBookDocs(_:by:) -> [BookDoc] 7. sortEntities(_:by:) -> [Reference] 8.
// searchFilteredEntities(_:query:) -> [Reference]   (= spec §9.2 row 6) 9.
// searchFilteredBookDocs(_:query:) -> [BookDoc]      (= spec §9.2 row 6) 10.
// matchesSearch(title:summary:query:) -> Bool       (= spec §9.2 row 6) 11.
// pinyinFirstLetters(_:) -> String                  (= spec §9.2 row 6) No actor
// involvement (= pure filesystem + JSON helpers). All bookStore input preserved as
// view-supplied.

import Foundation

/// Stateless business layer for PreviewPane. Mirrors the wenshu
/// MVVM enum + static + Result types precedent.
@MainActor
enum PreviewPaneOps {

    // MARK: - Result types

    struct LoadEntitiesResult {
        var entities: [Reference]
        var error: String?
    }

    struct LoadBooksResult {
        var books: [Book]
    }

    struct LoadBodyResult {
        var body: String?
    }

    struct LoadBookDocsResult {
        var docs: [BookDoc]
    }

    // MARK: - Entry points

    /// Load all reference entities (= the picker source).
    static func loadAllEntities(bookStore: BookStore?) -> LoadEntitiesResult {
        guard let bookStore else {
            return LoadEntitiesResult(entities: [], error: "bookStore is nil")
        }
        do {
            let allRefs = try bookStore.loadAllReferences()
            let layer = allRefs.filter { $0.layer == .layerEntities }
            return LoadEntitiesResult(entities: layer, error: nil)
        } catch {
            return LoadEntitiesResult(entities: [], error: String(describing: error))
        }
    }

    /// Load all books in one shelf (= the shelf scope source).
    static func loadBooksInShelf(bookStore: BookStore?, shelfId: UUID) -> LoadBooksResult {
        guard let bookStore else { return LoadBooksResult(books: []) }
        let allBooks = (try? bookStore.sidebarLoadAllBooks()) ?? []
        return LoadBooksResult(books: allBooks.filter { $0.shelfId == shelfId })
    }

    /// Async wrapper around `loadBooksInShelf` (= the picker reload trigger).
    static func loadShelfBooksAsync(bookStore: BookStore?, shelfId: UUID) async -> LoadBooksResult {
        // Yield first so SwiftUI can finish rendering the empty state before we touch
        // disk (= same yield discipline as the pre-extraction inline impl).
        await Task.yield()
        return loadBooksInShelf(bookStore: bookStore, shelfId: shelfId)
    }

    /// Load the body text for one reference entity (= the preview pane content).
    static func loadBody(bookStore: BookStore?, for entity: Reference) -> LoadBodyResult {
        guard let bookStore else { return LoadBodyResult(body: nil) }
        return LoadBodyResult(body: bookStore.loadReferenceBody(id: entity.id))
    }

    /// Load the book docs for one book (= the doc list source; = file scan).
    static func loadBookDocs(
        bookStore: BookStore?,
        bookId: UUID,
        folderName: String?
    ) -> LoadBookDocsResult {
        guard let bookStore else { return LoadBookDocsResult(docs: []) }
        // Walk shelves root to find which shelf this bookId lives in. Layout =
        // shelves/<shelf-uuid>/books/<book-uuid>/...
        let shelvesRoot = bookStore.stores.shelvesRoot
        guard FileManager.default.fileExists(atPath: shelvesRoot.path) else {
            return LoadBookDocsResult(docs: [])
        }
        let bookDirs: [URL]
        if let shelfDirs = try? FileManager.default.contentsOfDirectory(
            at: shelvesRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) {
            bookDirs = shelfDirs.compactMap { shelfDir in
                let candidate = shelfDir
                    .appendingPathComponent("books")
                    .appendingPathComponent(bookId.uuidString)
                return FileManager.default.fileExists(atPath: candidate.path)
                    ? candidate
                    : nil
            }
        } else {
            bookDirs = []
        }
        guard let bookDir = bookDirs.first else { return LoadBookDocsResult(docs: []) }

        // Determine which folders to scan.
        let folders: [String]
        if let folderName {
            folders = [folderName]
        } else {
            folders = BookFolder.allCases.map(\.directoryName)
        }

        var docs: [BookDoc] = []
        for folder in folders {
            let dir = bookDir.appendingPathComponent(folder)
            guard let entries = try? FileManager.default.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [
                    URLResourceKey.contentModificationDateKey,
                    URLResourceKey.creationDateKey
                ],
                options: [.skipsHiddenFiles]
            ) else { continue }
            for url in entries where url.pathExtension == "md" {
                let rawBody = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
                // 2026-10-12 boss directive "书的卡片, 和资料库的卡片样式 不同, 标签还在用 #加文字显示, 向资料库卡片对齐.
                // 统一样式" = the book's first H1 is the canonical single-
                // tag source for the chip row. Strip the leading "# "
                // (= raw markdown syntax never appears on a card
                // surface) and lift the rest of the H1 text into the
                // `tags` array. Strip the H1 line from the body so the
                // summary body no longer starts with "# 大纲\n" (= the
                // same literal text would otherwise reappear in the
                // summary row).
                let (firstH1, bodyWithoutH1) = PreviewPaneOps.splitFirstH1(rawBody)
                let body = bodyWithoutH1
                let tags: [String] = firstH1.map { [$0] } ?? []
                let attrs = try? url.resourceValues(forKeys: [
                    URLResourceKey.contentModificationDateKey,
                    URLResourceKey.creationDateKey
                ])
                let modifiedAt = attrs?.contentModificationDate ?? Date.distantPast
                let createdAt = attrs?.creationDate ?? Date.distantPast
                docs.append(BookDoc(
                    id: stableBookDocId(
                        bookId: bookId,
                        folderName: folder,
                        fileName: url.lastPathComponent
                    ),
                    bookId: bookId,
                    folderName: folder,
                    fileName: url.lastPathComponent,
                    modifiedAt: modifiedAt,
                    createdAt: createdAt,
                    tags: tags,
                    body: body
                ))
            }
        }
        return LoadBookDocsResult(docs: docs)
    }

    /// Sort book docs by the active sort order (= .pinyinFirstLetter default).
    /// Stable sort by fileName tiebreaker.
    static func sortBookDocs(_ docs: [BookDoc], by order: EntitySortOrder) -> [BookDoc] {
        switch order {
        case .pinyinFirstLetter:
            return docs.sorted { lhs, rhs in
                let lKey = pinyinFirstLetter(lhs.title)
                let rKey = pinyinFirstLetter(rhs.title)
                if lKey != rKey { return lKey < rKey }
                return lhs.fileName < rhs.fileName
            }
        case .createdAt:
            return docs.sorted { lhs, rhs in
                if lhs.createdAt != rhs.createdAt {
                    return lhs.createdAt > rhs.createdAt
                }
                return lhs.fileName < rhs.fileName
            }
        case .modifiedAt:
            return docs.sorted { lhs, rhs in
                if lhs.modifiedAt != rhs.modifiedAt {
                    return lhs.modifiedAt > rhs.modifiedAt
                }
                return lhs.fileName < rhs.fileName
            }
        }
    }

    /// Sort reference entities by the active sort order.
    /// Stable sort by id tiebreaker (= prevents visual re-shuffle).
    static func sortEntities(_ entities: [Reference], by order: EntitySortOrder) -> [Reference] {
        switch order {
        case .pinyinFirstLetter:
            return entities.sorted { lhs, rhs in
                let lKey = pinyinFirstLetter(lhs.title)
                let rKey = pinyinFirstLetter(rhs.title)
                if lKey != rKey { return lKey < rKey }
                return lhs.id.uuidString < rhs.id.uuidString
            }
        case .createdAt:
            return entities.sorted { lhs, rhs in
                if lhs.createdAt != rhs.createdAt {
                    return lhs.createdAt > rhs.createdAt
                }
                return lhs.id.uuidString < rhs.id.uuidString
            }
        case .modifiedAt:
            return entities.sorted { lhs, rhs in
                let lMod = lhs.updatedAt
                let rMod = rhs.updatedAt
                if lMod != rMod {
                    return lMod > rMod
                }
                return lhs.id.uuidString < rhs.id.uuidString
            }
        }
    }

    // MARK: - Search filter (= per spec §9.2 row 6 extension)

    /// Filter reference entities by the current search query.
    /// Matches against BOTH:
    /// 1. Original title / summary substring (= case-insensitive)
    /// 2. Pinyin first-letter substring (= e.g. "d" matches "X" -> DX)
    /// Empty query = pass-through (= show all entities).
    static func searchFilteredEntities(_ entities: [Reference], query: String) -> [Reference] {
        return entities.filter { matchesSearch(title: $0.title, summary: $0.summary, query: query) }
    }

    // MARK: - Card count (= the column-bottom chrome footer source)

    /// 2026-10-12 boss directive "在素材栏也加一个底栏, 然后
    /// 文字显示的是, 当前栏中显示的卡片总数, XX 项" — the
    /// assets column's bottom chrome footer displays the
    /// total card count for the active scope (= the chrome
    /// text reads "N 项"; = same 1:1 visual recipe the
    /// sidebar '+' button / chat token-count footer /
    /// editor status bar use via the shared
    /// `ChromeBottomFooter` component). This helper resolves
    /// the count for a given scope (= applies the same scope
    /// semantics the corresponding `*ScopeView` in
    /// `PreviewPane.swift` uses: reference scope = filter
    /// `loadAllEntities()` by `layer == .layerEntities` and
    /// the optional category; tag scope = additionally
    /// filter by `tags.contains(tag)`; book scope = file
    /// scan of `loadBookDocs(bookId:, folderName:)`; shelf
    /// scope = union of every book's `loadBookDocs` results
    /// filtered to books whose `shelfId == shelfId`).
    /// The search filter (= `envAppState.searchText`) is
    /// applied on top so the chrome shows the COUNT OF
    /// VISIBLE CARDS (= matches what the user sees in the
    /// grid; = empty search query = full count, search
    /// query = filtered count).
    static func countCardsInScope(
        scope: PreviewScope,
        bookStore: BookStore?,
        searchQuery: String
    ) -> Int {
        switch scope {
        case .referenceScope(let category):
            let entities = loadAllEntities(bookStore: bookStore).entities
                .filter { entity in
                    entity.layer == .layerEntities
                        && (category == nil || entity.category == category)
                }
            return searchFilteredEntities(entities, query: searchQuery).count

        case .tagScope(let tag):
            // dedicated tag scope; = the chrome count = the same `loadAllEntities()`
            // prefilter + tag contains + search query (= 1:1 with
            // `referenceScopeView(category: nil, tagOverride: tag)`
            // semantics).
            let entities = loadAllEntities(bookStore: bookStore).entities
                .filter { entity in
                    entity.layer == .layerEntities && entity.tags.contains(tag)
                }
            return searchFilteredEntities(entities, query: searchQuery).count

        case .bookScope(let bookId, let folderName):
            let docs = loadBookDocs(
                bookStore: bookStore,
                bookId: bookId,
                folderName: folderName
            ).docs
            return searchFilteredBookDocs(docs, query: searchQuery).count

        case .shelfScope(let shelfId):
            // The shelf scope is the union of every book's .md docs under the shelf (=
            // 1:1 with `shelfScopeView`); = per-book loadBookDocs +
            // flatten + search filter.
            guard let bookStore else { return 0 }
            let booksInShelf = (try? bookStore.sidebarLoadAllBooks())?
                .filter { $0.shelfId == shelfId } ?? []
            let allDocs = booksInShelf.flatMap { book in
                loadBookDocs(
                    bookStore: bookStore,
                    bookId: book.id,
                    folderName: nil
                ).docs
            }
            return searchFilteredBookDocs(allDocs, query: searchQuery).count

        case .empty:
            // No sidebar selection (= the empty-state hint path in `PreviewPane`); = the
            // chrome count is 0 (= no cards visible).
            return 0
        }
    }

    /// Filter book docs by the current search query.
    /// Same filter shape as `searchFilteredEntities` but for book
    /// docs (= filesystem .md files loaded by `loadBookDocs`).
    static func searchFilteredBookDocs(_ docs: [BookDoc], query: String) -> [BookDoc] {
        return docs.filter { matchesSearch(title: $0.title, summary: $0.summary, query: query) }
    }

    /// Substring matcher shared between entities and book docs
    /// (= per the 'use one common interface' rule).
    /// Empty query = pass-through. Pure function (= no actor,
    /// no MainActor; = trivially testable).
    static func matchesSearch(title: String, summary: String, query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        let lowered = trimmed.lowercased()
        if title.localizedCaseInsensitiveContains(trimmed)
            || summary.localizedCaseInsensitiveContains(trimmed) {
            return true
        }
        let pinyinKey = pinyinFirstLetters(title)
        if pinyinKey.lowercased().contains(lowered) {
            return true
        }
        return false
    }

    /// Pinyin first-letter sequence for one title.
    /// Tokenises on whitespace, drops pure-punctuation tokens,
    /// takes the first letter of each (= per the dual-axis audit Standards axis
    /// LOW fix: emoji titles now produce one initial char too).
    /// Pure function (= no actor, no MainActor).
    static func pinyinFirstLetters(_ title: String) -> String {
        let mutable = NSMutableString(string: title)
        CFStringTransform(mutable, nil, kCFStringTransformToLatin, false)
        CFStringTransform(mutable, nil, kCFStringTransformStripDiacritics, false)
        let latinized = (mutable as String)
        let initials = latinized
            .split(whereSeparator: { $0.isWhitespace })
            .compactMap { token -> String? in
                guard let first = token.first else { return nil }
                guard first.isLetter || first.isNumber || first.isSymbol else { return nil }
                return String(first).uppercased()
            }
            .joined()
        return String(initials)
    }

    // MARK: - Private helpers

    /// Stable id for a book doc (= bookId + folderName + fileName).
    /// Pure function (= no actor, no MainActor). Returns UUID
    /// via BookDocIDFactory (= SHA256 hash of canonical path).
    nonisolated static func stableBookDocId(bookId: UUID, folderName: String, fileName: String) -> UUID {
        return BookDocIDFactory.make(bookId: bookId, folderName: folderName, fileName: fileName)
    }

    /// Split a `.md` body into (firstH1, bodyWithoutH1) for the
    /// book's card chip row. The H1 line (= the markdown `# xxx`
    /// line at the very top of the file) is stripped from the body
    /// and surfaced as the first tag (= the 2026-10-12 boss
    /// directive "书的卡片, 和资料库的卡片样式不同, 标签还在用
    /// #加文字显示, 向资料库卡片对齐. 统一样式"). Rules:
    /// - the first non-blank line of the body must start with `# `;
    ///   only the leading single `#` (= ATX-style H1) is treated
    ///   as a chip. `## xxx` / `### xxx` etc. (= H2 / H3 / etc.)
    ///   are body content (= the chip row only ever shows the
    ///   file's first H1).
    /// - the matched line is stripped from the returned body
    ///   (= the summary row no longer re-renders the literal
    ///   `# xxx` line that was the prior visual mismatch).
    /// - if no H1 line is present, returns `(nil, body)` (= the
    ///   card silently omits the chip row, same as a reference
    ///   with `tags = []`).
    /// - the H1 text is trimmed of surrounding whitespace but
    ///   otherwise returned verbatim (= no slugification, no
    ///   case folding; = the chip displays the raw chapter
    ///   heading text).
    nonisolated static func splitFirstH1(_ body: String) -> (String?, String) {
        // Split into lines preserving order. Swift's `String` does not expose
        // `components(separatedBy:omittingEmptySubsequences:)` (= that's an
        // NSString API on a different surface) — use a one-shot
        // `Character`-set split that lets us set `omittingEmptySubsequences:
        // false` (= we need the blank-line trim to land on a real element of
        // the array, not a missing one) and `maxSplits: .max` to preserve
        // every line.  The `Character` predicate `isNewline` matches LF / CR /
        // CRLF / VT / FF — every .md line break on Apple platforms is LF on
        // macOS 27, but the `Character`-set route keeps the function robust to
        // CRLF imports from Windows-authored chapter files.
        let lines: [String] = body
            .split(omittingEmptySubsequences: false, whereSeparator: { $0.isNewline })
            .map { String($0) }
        // Find the first non-blank line that begins with "# ".
        var h1Index: Int? = nil
        var h1Text: String? = nil
        for (i, raw) in lines.enumerated() {
            let line = String(raw)
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                continue
            }
            // Only the single-`#` H1 is treated as a chip. H2+ and Setext-style (=
            // underlined with `===`) headings are body content (= the
            // user's directive = strip the first H1 only).
            if trimmed.hasPrefix("# ") && !trimmed.hasPrefix("## ") {
                h1Text = String(trimmed.dropFirst(2))
                    .trimmingCharacters(in: .whitespaces)
                h1Index = i
            }
            break  // first non-blank line is the only candidate
        }
        guard let i = h1Index, let text = h1Text else {
            return (nil, body)
        }
        // Drop the H1 line + the blank line(s) immediately after it (= typical `.md`
        // files put a blank line between the H1 and the first paragraph; = the
        // summary should not start with a leading blank).
        var dropped = lines
        dropped.remove(at: i)
        while !dropped.isEmpty,
              let next = dropped.first,
              String(next).trimmingCharacters(in: .whitespaces).isEmpty {
            dropped.removeFirst()
        }
        return (text.isEmpty ? nil : text, dropped.joined(separator: "\n"))
    }

    /// Convert Chinese title to its pinyin first letter (= uppercase).
    /// Uses Apple CFStringTransform (kCFStringTransformToLatin +
    /// kCFStringTransformStripDiacritics). Pure function (= no actor).
    private static func pinyinFirstLetter(_ title: String) -> String {
        let mutable = NSMutableString(string: title)
        CFStringTransform(mutable, nil, kCFStringTransformToLatin, false)
        CFStringTransform(mutable, nil, kCFStringTransformStripDiacritics, false)
        let latinized = (mutable as String).trimmingCharacters(in: .whitespaces)
        if let first = latinized.first {
            return String(first).uppercased()
        }
        return "~"
    }
}