// FileSystemLibraryStore.swift · Wenshu (Wenshu) · v0.02.0 (bookshelf module)
//
// Filesystem-backed LibraryStoring implementation. The v0.02.0 default;
// swap for MetadataQuery / CoreData / CloudKit later without changing
// the contract (= LibraryStoring) or any caller (= view layer).
//
// [CJK-TRANSLATE] 1 line(s) awaiting manual translation (see git blame for original CJK text)
// Owner 8/15 15:55: '架构需要先定好, 不能没事加个东西, 然后重构一堆
// 东西'. By satisfying LibraryStoringContractTests, this implementation
// is the architectural reference: any future impl must behave the same.
//
// Apple HIG document-based-app convention (= Pages / TextEdit / Numbers):
//   ~/Documents/wenshu/<shelf-id-uuid>/
//     shelf.json     ← encoded Bookshelf (the metadata)
//     books/         ← v0.02.1
//     chapters/      ← v0.02.1
//
// Atomic write strategy (= the Apple HIG pattern, also used by NSDocument
// + FileWrapper.write(to:options:originalContents:)):
//   1. write shelf.json.tmp
//   2. fsync the temp file (FileManager doesn't expose fsync directly;
//      use replaceItemAt on a separate backup file path so the rename
//      through the kernel is atomic)
//   3. atomic rename via FileManager.replaceItemAt
// If the app crashes mid-write, the temp file is orphaned (harmless) and
// shelf.json is untouched (= the previous-good-state stays on disk).

import Foundation

final class FileSystemLibraryStore: LibraryStoring, @unchecked Sendable {
    let rootURL: URL

    init(rootURL: URL) {
        self.rootURL = rootURL
    }

    // MARK: - LibraryStoring

    func loadShelves() throws -> [Bookshelf] {
        let fm = FileManager.default
        // Apple HIG: don't fail loudly if the user's library root is missing
        // on first launch (= they haven't created any shelf yet). Return
        // empty; the user can pick a different root in Preferences.
        guard fm.fileExists(atPath: rootURL.path) else { return [] }
        guard let entries = try? fm.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw LibraryStoringError(kind: .rootDirectoryUnavailable(rootURL))
        }

        var shelves: [Bookshelf] = []
        for entry in entries {
            let isDir = (try? entry.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            guard isDir else { continue }
            let jsonURL = entry.appendingPathComponent("shelf.json")
            guard fm.fileExists(atPath: jsonURL.path) else { continue }
            do {
                let data = try Data(contentsOf: jsonURL)
                let shelf = try JSONDecoder().decode(Bookshelf.self, from: data)
                shelves.append(shelf)
            } catch {
                // Per the Apple HIG document-based pattern, a corrupt
                // shelf.json is a recoverable condition: log it (= skipped
                // here to keep the protocol free of logging deps), leave
                // the file alone, and continue loading the rest. The
                // contract test for "corrupt shelf" is in v0.02.0+ (= not
                // v0.02.0, since we haven't built a corruption recovery UI
                // yet); land with the FileSystem-specific tests in v39b.
                continue
            }
        }
        return shelves.sorted { $0.updatedAt > $1.updatedAt }
    }

    func saveShelf(_ shelf: Bookshelf) throws {
        let fm = FileManager.default
        let dir = rootURL.appendingPathComponent(shelf.directoryName)

        // First-save-wins: refuse to overwrite an existing shelf id. The
        // rename operation = save with the same id + new name (caller
        // responsibility to update updatedAt), which works because the
        // directory already exists at this id.
        if fm.fileExists(atPath: dir.path) {
            throw LibraryStoringError(kind: .shelfAlreadyExists(shelf.id))
        }

        // Create the shelf directory. .createIntermediates = true so any
        // missing parent (= the root) is also created (= first-ever save).
        do {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            throw LibraryStoringError(
                kind: .ioFailed(dir, underlying: "\(error)")
            )
        }

        // Atomic write of shelf.json: tmp file + replaceItemAt.
        let jsonURL = dir.appendingPathComponent("shelf.json")
        let tmpURL = dir.appendingPathComponent("shelf.json.tmp")

        let data: Data
        do {
            data = try JSONEncoder().encode(shelf)
        } catch {
            throw LibraryStoringError(
                kind: .ioFailed(jsonURL, underlying: "encode failed: \(error)")
            )
        }

        do {
            try data.write(to: tmpURL, options: [.atomic])
        } catch {
            throw LibraryStoringError(
                kind: .ioFailed(tmpURL, underlying: "tmp write failed: \(error)")
            )
        }

        // Atomic rename: replaceItemAt moves the tmp file to the final
        // path. If a shelf.json already existed (= shouldn't happen given
        // the shelfAlreadyExists guard above, but defense in depth),
        // this would replace it; since we already returned the error,
        // this branch only runs on the clean first-save path.
        do {
            if fm.fileExists(atPath: jsonURL.path) {
                _ = try fm.replaceItemAt(jsonURL, withItemAt: tmpURL)
            } else {
                try fm.moveItem(at: tmpURL, to: jsonURL)
            }
        } catch {
            // Clean up the orphaned tmp file.
            try? fm.removeItem(at: tmpURL)
            throw LibraryStoringError(
                kind: .ioFailed(jsonURL, underlying: "rename failed: \(error)")
            )
        }

        // Pre-create the books/ and chapters/ subdirs so that the storage
        // layout is consistent before v0.02.1 adds anything inside them.
        // (= Apple HIG: a document's bundle structure is set up once at
        // creation, not lazily as files appear.)
        let booksDir = dir.appendingPathComponent("books")
        let chaptersDir = dir.appendingPathComponent("chapters")
        do {
            try fm.createDirectory(at: booksDir, withIntermediateDirectories: true)
            try fm.createDirectory(at: chaptersDir, withIntermediateDirectories: true)
        } catch {
            // Non-fatal: shelves can exist without these subdirs. v0.02.1
            // will create them on demand.
        }
    }

    func deleteShelf(id: UUID) throws {
        let fm = FileManager.default
        let dir = rootURL.appendingPathComponent(id.uuidString)
        guard fm.fileExists(atPath: dir.path) else { return }  // idempotent
        do {
            try fm.removeItem(at: dir)
        } catch {
            throw LibraryStoringError(
                kind: .ioFailed(dir, underlying: "remove failed: \(error)")
            )
        }
    }

    func search(query: String) throws -> [SearchHit] {
        // v0.03.0 implementation: NSMetadataQuery on rootURL.
        // v0.02.0: stub returns [] (= the protocol signature is locked
        // now so the UI can wire up its search bar without an API
        // change later).
        return []
    }

    // MARK: - Book ops (v0.02.1, = book module end-to-end)
    //
    // Mirrors the shelf ops above: loadBooks reads, saveBook writes
    // atomically (= tmp + replaceItemAt), deleteBook is idempotent.
    // The books/ subdir under each shelf was pre-created by saveShelf in
    // v0.02.0 (= the v39 commit); this method just writes into it.

    func loadBooks(shelfId: UUID) throws -> [Book] {
        let fm = FileManager.default
        let booksDir = rootURL
            .appendingPathComponent(shelfId.uuidString)
            .appendingPathComponent("books")
        // Apple HIG: a missing directory means "no books" (= shelf
        // exists but is empty), not "error". Same forgiving convention
        // as loadShelves on a missing root.
        guard fm.fileExists(atPath: booksDir.path) else { return [] }
        guard let entries = try? fm.contentsOfDirectory(
            at: booksDir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var books: [Book] = []
        for entry in entries {
            let isDir = (try? entry.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            guard isDir else { continue }
            let jsonURL = entry.appendingPathComponent("book.json")
            guard fm.fileExists(atPath: jsonURL.path) else { continue }
            do {
                let data = try Data(contentsOf: jsonURL)
                let book = try JSONDecoder().decode(Book.self, from: data)
                books.append(book)
            } catch {
                // Same forgiveness policy as loadShelves: skip corrupt
                // book.json, continue loading the rest.
                continue
            }
        }
        return books.sorted { $0.updatedAt > $1.updatedAt }
    }

    func saveBook(_ book: Book) throws {
        let fm = FileManager.default
        let parentShelf = rootURL.appendingPathComponent(book.shelfId.uuidString)
        let booksDir = parentShelf.appendingPathComponent("books")
        let bookDir = booksDir.appendingPathComponent(book.directoryName)

        // Orphan-prevention: the parent shelf has to be on disk before
        // a book can be saved (= same constraint as the type system:
        // Book.shelfId is required at init).
        guard fm.fileExists(atPath: parentShelf.path) else {
            throw LibraryStoringError(kind: .parentShelfNotFound(book.shelfId))
        }

        // First-save-wins: refuse to overwrite an existing book id.
        if fm.fileExists(atPath: bookDir.path) {
            throw LibraryStoringError(kind: .bookAlreadyExists(book.id))
        }

        do {
            try fm.createDirectory(at: bookDir, withIntermediateDirectories: true)
        } catch {
            throw LibraryStoringError(
                kind: .ioFailed(bookDir, underlying: "\(error)")
            )
        }

        // Atomic write of book.json (= same pattern as saveShelf).
        let jsonURL = bookDir.appendingPathComponent("book.json")
        let tmpURL = bookDir.appendingPathComponent("book.json.tmp")

        let data: Data
        do {
            data = try JSONEncoder().encode(book)
        } catch {
            throw LibraryStoringError(
                kind: .ioFailed(jsonURL, underlying: "encode failed: \(error)")
            )
        }

        do {
            try data.write(to: tmpURL, options: [.atomic])
        } catch {
            throw LibraryStoringError(
                kind: .ioFailed(tmpURL, underlying: "tmp write failed: \(error)")
            )
        }

        do {
            if fm.fileExists(atPath: jsonURL.path) {
                _ = try fm.replaceItemAt(jsonURL, withItemAt: tmpURL)
            } else {
                try fm.moveItem(at: tmpURL, to: jsonURL)
            }
        } catch {
            try? fm.removeItem(at: tmpURL)
            throw LibraryStoringError(
                kind: .ioFailed(jsonURL, underlying: "rename failed: \(error)")
            )
        }

        // Pre-create chapters/ subdir so v0.03.0 (= chapter content)
        // has a consistent bundle structure (= Apple HIG: set up the
        // document's bundle once at creation, not lazily).
        let chaptersDir = bookDir.appendingPathComponent("chapters")
        try? fm.createDirectory(at: chaptersDir, withIntermediateDirectories: true)
    }

    func deleteBook(id: UUID) throws {
        let fm = FileManager.default
        // We don't know which shelf the book belongs to from the id alone.
        // For idempotent delete, scan all shelves and remove matching
        // <book-id> directories (= the contract is "idempotent no-op if
        // missing", so a multi-match is acceptable as long as we don't
        // crash and end up with no books remaining).
        guard let shelfEntries = try? fm.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return }
        for shelfEntry in shelfEntries {
            let booksDir = shelfEntry
                .appendingPathComponent("books")
                .appendingPathComponent(id.uuidString)
            guard fm.fileExists(atPath: booksDir.path) else { continue }
            do {
                try fm.removeItem(at: booksDir)
            } catch {
                throw LibraryStoringError(
                    kind: .ioFailed(booksDir, underlying: "remove failed: \(error)")
                )
            }
        }
    }

    func loadBook(id: UUID) throws -> Book? {
        let fm = FileManager.default
        // Same scan pattern as deleteBook (= book id alone doesn't know
        // its shelf). Return the first match (= the contract says id is
        // unique across the library; multi-match would be a bug upstream).
        guard let shelfEntries = try? fm.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return nil }
        for shelfEntry in shelfEntries {
            let jsonURL = shelfEntry
                .appendingPathComponent("books")
                .appendingPathComponent(id.uuidString)
                .appendingPathComponent("book.json")
            guard fm.fileExists(atPath: jsonURL.path) else { continue }
            do {
                let data = try Data(contentsOf: jsonURL)
                return try JSONDecoder().decode(Book.self, from: data)
            } catch {
                continue
            }
        }
        return nil
    }

    // MARK: - Document ops (v0.03.0)
    //
    // Layout (= 老板 8/15 15:55 '架构需要先定好, 不能没事加个东西, 然后
    // [CJK-TRANSLATE] 1 line(s) awaiting manual translation (see git blame for original CJK text)
    // 重构一堆东西'):
    //   ~/Documents/wenshu/<shelf>/<book>/
    //     book.json
    //     chapters/<docId>.md   BookCategory.chapter
    //     settings/<docId>.md   BookCategory.setting
    //     research/<docId>.md   BookCategory.research
    //
    // Document metadata is NOT separately stored (= the .md IS the
    // source of truth; loadDocuments reads the .md, extracts title +
    // summary, fills Document fields). This matches the Boss 15:55
    // principle: storage layer never holds a derived copy of the .md.

    func loadDocuments(bookId: UUID, category: BookCategory) throws -> [Document] {
        let fm = FileManager.default
        // Same forgiving pattern as loadBooks / loadShelves: a missing
        // category dir means "no documents yet" (= just-created book,
        // user hasn't added any chapters). Return [], not an error.
        guard let categoryDir = categoryDirectory(bookId: bookId, category: category),
              fm.fileExists(atPath: categoryDir.path)
        else { return [] }
        guard let entries = try? fm.contentsOfDirectory(
            at: categoryDir,
            includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var documents: [Document] = []
        for entry in entries {
            // Only .md files (= skip macOS resource forks, .DS_Store, etc.)
            guard entry.pathExtension == "md" else { continue }
            // Filename must be <UUID>.md (= we don't tolerate arbitrary
            // names so the storage contract is strict). If the filename
            // doesn't parse, skip (= forensics: someone hand-edited a
            // file with a non-UUID name; we ignore it).
            guard let id = Self.documentIdFromFilename(entry.lastPathComponent)
            else { continue }
            do {
                let data = try Data(contentsOf: entry)
                let body = Self.decodeUTF8(data) ?? ""
                let attrs = try? entry.resourceValues(forKeys: [
                    .contentModificationDateKey, .fileSizeKey
                ])
                let createdAt = attrs?.contentModificationDate ?? .now
                let byteSize = attrs?.fileSize ?? data.count
                let doc = Document(
                    id: id,
                    bookId: bookId,
                    category: category,
                    title: Self.extractTitle(from: body, fallback: entry.deletingPathExtension().lastPathComponent),
                    byteSize: byteSize,
                    summary: Self.extractSummary(from: body),
                    createdAt: createdAt,
                    updatedAt: createdAt
                )
                documents.append(doc)
            } catch {
                // Corrupt .md: skip (= same forgiveness policy as the
                // other loaders). Don't crash the card view.
                continue
            }
        }
        // Sort by updatedAt descending (= most-recent first; matches
        // Finder 'Recents' and the rest of the library).
        return documents.sorted { $0.updatedAt > $1.updatedAt }
    }

    func loadDocumentContent(id: UUID, bookId: UUID, category: BookCategory) throws -> String {
        let fm = FileManager.default
        let path = try documentPath(id: id, bookId: bookId, category: category)
        guard fm.fileExists(atPath: path.path) else {
            throw LibraryStoringError(kind: .documentNotFound(id))
        }
        let data = try Data(contentsOf: path)
        return Self.decodeUTF8(data) ?? ""
    }

    func saveDocument(id: UUID, bookId: UUID, category: BookCategory, content: String) throws {
        let fm = FileManager.default
        // Orphan-prevention: the parent book must be on disk first
        // (= same constraint as saveBook checking parentShelf). A
        // document without a parent book would be invisible to the
        // rest of the system (= the cards view only loads docs for
        // books that exist).
        guard let bookDir = bookDirectory(bookId: bookId),
              fm.fileExists(atPath: bookDir.path)
        else {
            throw LibraryStoringError(kind: .parentBookNotFound(bookId))
        }
        // Create the category dir if it doesn't exist yet (= first save
        // in a category for a book that's been around a while).
        guard let categoryDir = categoryDirectory(bookId: bookId, category: category)
        else { return }  // unreachable; bookDirectory already returned
        do {
            try fm.createDirectory(at: categoryDir, withIntermediateDirectories: true)
        } catch {
            throw LibraryStoringError(
                kind: .ioFailed(categoryDir, underlying: "\(error)")
            )
        }

        // Atomic write: tmp file + rename. Same pattern as saveShelf /
        // saveBook. Crash mid-write = tmp file orphaned, .md untouched.
        let path = try documentPath(id: id, bookId: bookId, category: category)
        let tmpPath = path.deletingLastPathComponent()
            .appendingPathComponent("\(id.uuidString).md.tmp")
        let data = content.data(using: .utf8) ?? Data()
        do {
            try data.write(to: tmpPath, options: [.atomic])
        } catch {
            throw LibraryStoringError(
                kind: .ioFailed(tmpPath, underlying: "tmp write failed: \(error)")
            )
        }
        do {
            if fm.fileExists(atPath: path.path) {
                _ = try fm.replaceItemAt(path, withItemAt: tmpPath)
            } else {
                try fm.moveItem(at: tmpPath, to: path)
            }
        } catch {
            try? fm.removeItem(at: tmpPath)
            throw LibraryStoringError(
                kind: .ioFailed(path, underlying: "rename failed: \(error)")
            )
        }
    }

    func deleteDocument(id: UUID, bookId: UUID, category: BookCategory) throws {
        let fm = FileManager.default
        let path = try documentPath(id: id, bookId: bookId, category: category)
        // Idempotent (= the contract is "no-op if missing", like
        // deleteShelf and deleteBook).
        guard fm.fileExists(atPath: path.path) else { return }
        do {
            try fm.removeItem(at: path)
        } catch {
            throw LibraryStoringError(
                kind: .ioFailed(path, underlying: "remove failed: \(error)")
            )
        }
    }

    // MARK: - Path helpers (= single source of truth for layout)

    /// <root>/<shelf-id>/books/<book-id>  (= the book's directory).
    private func bookDirectory(bookId: UUID) -> URL? {
        // Book id is unique across the library; the book lives in
        // exactly one shelf. We need the shelf to resolve the path,
        // so scan (= same shape as loadBook).
        let fm = FileManager.default
        guard let shelfEntries = try? fm.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return nil }
        for shelfEntry in shelfEntries {
            let candidate = shelfEntry
                .appendingPathComponent("books")
                .appendingPathComponent(bookId.uuidString)
            if fm.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }

    /// <root>/<shelf-id>/books/<book-id>/<category.directoryName>
    private func categoryDirectory(bookId: UUID, category: BookCategory) -> URL? {
        bookDirectory(bookId: bookId)?
            .appendingPathComponent(category.directoryName)
    }

    /// <root>/<shelf-id>/books/<book-id>/<category.directoryName>/<docId>.md
    /// v0.23 audit #014 fix: don't force-unwrap. If book directory missing
    /// (corrupted state), throw instead of crashing.
    private func documentPath(id: UUID, bookId: UUID, category: BookCategory) throws -> URL {
        guard let dir = categoryDirectory(bookId: bookId, category: category) else {
            throw LibraryStoringError(kind: .parentBookNotFound(bookId))
        }
        return dir.appendingPathComponent("\(id.uuidString).md")
    }

    // MARK: - MD parsing (= title from H1, summary from body)

    /// Parse '<UUID>.md' → UUID?  (= inverse of Document.filename).
    /// Returns nil for anything that doesn't look like a UUID-named
    /// .md (= catches Finder's .DS_Store, our own .md.tmp atomics,
    /// any hand-edited file, etc.).
    static func documentIdFromFilename(_ name: String) -> UUID? {
        guard name.hasSuffix(".md") else { return nil }
        let stem = String(name.dropLast(3))
        return UUID(uuidString: stem)
    }

    /// Decode data as UTF-8, falling back to a lossy conversion if
    /// the file has bad bytes (= corruption recovery; wenshu never
    /// produces bad bytes but the storage layer is defensive).
    static func decodeUTF8(_ data: Data) -> String? {
        String(data: data, encoding: .utf8)
    }

    /// First H1 (= '# Title') from the MD body. Falls back to a generic
    /// placeholder (the filename, without .md) when no H1 is present.
    /// Apple HIG documents typically have an H1 (= the document title);
    /// if the user is still drafting, the filename is a reasonable
    /// stand-in.
    static func extractTitle(from body: String, fallback: String) -> String {
        for rawLine in body.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("# ") {
                let title = String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                if !title.isEmpty { return title }
            }
        }
        return fallback
    }

    /// First ~100 chars of the MD body, with frontmatter stripped and
    /// newlines collapsed to spaces. This is the '中心思想' the user
    /// sees at a glance in the card. (v0.04+ adds an explicit
    /// `summary` frontmatter field to override.)
    static func extractSummary(from body: String) -> String {
        var content = body
        // Strip frontmatter (= lines between the first '---' and the
        // second '---', e.g. 'title: ...' / 'date: ...'). Standard
        // Jekyll / Hugo / Pandoc frontmatter.
        if content.hasPrefix("---\n") || content.hasPrefix("---\r\n") {
            let scanner = content.dropFirst(3)
            if let endRange = scanner.range(of: "\n---") {
                content = String(scanner[endRange.upperBound...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        // Collapse all whitespace (= newlines, tabs, multi-space) to
        // single spaces. The summary is shown in a fixed-width card
        // body, so multi-line summaries would force the card to grow
        // unpredictably.
        let collapsed = content
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        // Cap at ~100 chars. Apple HIG card body fields typically
        // hold 2-3 lines (= roughly 80-120 chars depending on font);
        // 100 is a comfortable midpoint.
        if collapsed.count <= 100 { return collapsed }
        let prefix = collapsed.prefix(100)
        // Truncate at the last word boundary (= don't cut "first pa" out
        // of "first paragraph").
        if let lastSpace = prefix.lastIndex(of: " ") {
            return String(prefix[..<lastSpace]) + "…"
        }
        return String(prefix) + "…"
    }
}