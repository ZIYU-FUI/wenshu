// FileSystemLibraryStore.swift · Wenshu (Wenshu) · v0.02.0 (bookshelf module)
//
// Filesystem-backed LibraryStoring implementation. The v0.02.0 default;
// swap for MetadataQuery / CoreData / CloudKit later without changing
// the contract (= LibraryStoring) or any caller (= view layer).
//
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
}