// Sources/WenshuApp/Storage/LibraryMigrator.swift
// … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
// Does NOT touch user .md content under migrated books.
import Foundation
import WenshuData

struct LibraryMigrator: Sendable {
    let wsRoot: URL

    // / Run the legacy migration. Idempotent: if WSSchemaVersion
    // / is already 1, this is a no-op.
    func migrateIfNeeded() throws {
        let fm = FileManager.default
        // 0. ALWAYS-RUN housekeeping (= runs on every launch, even when
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
        // though no schema change happened).
        try alwaysRunOnLaunch(fm: fm)
        // 1. Idempotency check: read Info.plist; if WSSchemaVersion = 1
        // (= current), skip migration entirely.
        if try isAlreadyCurrentSchema() {
            // BUT we still want to run helpDocUpgrade() to
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // only 1 old help-doc, upgrade to 5 files).
            try? helpDocUpgrade(fm: fm)
            return
        }
        // 2. Pre-v0.26 detection: legacy .ws had books/ at .ws root OR
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
        // shelves/ anyway so the canonical layout is established.
        let booksAtRoot = wsRoot.appendingPathComponent("books", isDirectory: true)
        if fm.fileExists(atPath: booksAtRoot.path) {
            try moveBooksToDefaultShelf(from: booksAtRoot)
        }
        // 3. DROP only-if-empty: chapters/ + books/ + shelves/ at .ws root.
        for orphan in ["chapters", "books", "shelves"] {
            let url = wsRoot.appendingPathComponent(orphan, isDirectory: true)
            if fm.fileExists(atPath: url.path), isEmptyDirectory(url) {
                try fm.removeItem(at: url)
            }
        }
        // 4. CREATE: reference-library/ layers + cache/.
        //
        // The layer list comes from the enum, not from a literal
        // array. A literal list is a second copy of the layout, and
        // the two derived layers that the enum no longer names
        // survived in it: a fresh library still grew their
        // directories, so the disk and the enum disagreed and the
        // directories came back after a manual cleanup.
        for layer in ReferenceLayer.allCases {
            let url = wsRoot
                .appendingPathComponent("reference-library", isDirectory: true)
                .appendingPathComponent(layer.directoryName, isDirectory: true)
            if !fm.fileExists(atPath: url.path) {
                try fm.createDirectory(at: url, withIntermediateDirectories: true)
            }
        }
        let cache = wsRoot.appendingPathComponent("cache", isDirectory: true)
        if !fm.fileExists(atPath: cache.path) {
            try fm.createDirectory(at: cache, withIntermediateDirectories: true)
        }
        // 5. WRITE: WSSchemaVersion = 1 to existing Info.plist (= idempotent
        // via step 1).
        try writeOrUpdateSchemaVersion()
    }

    // MARK: - Helpers

    private func isAlreadyCurrentSchema() throws -> Bool {
        let infoPlistURL = wsRoot.appendingPathComponent("Info.plist")
        guard FileManager.default.fileExists(atPath: infoPlistURL.path) else {
            return false
        }
        guard let data = try? Data(contentsOf: infoPlistURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
              let version = plist["WSSchemaVersion"] as? Int else {
            return false
        }
        return version >= CURRENT_SCHEMA_VERSION
    }

    private func moveBooksToDefaultShelf(from booksAtRoot: URL) throws {
        let fm = FileManager.default
        // 1. Ensure shelves/ exists (= canonical container).
        let shelvesRoot = wsRoot.appendingPathComponent("shelves", isDirectory: true)
        if !fm.fileExists(atPath: shelvesRoot.path) {
            try fm.createDirectory(at: shelvesRoot, withIntermediateDirectories: true)
        }
        // 2. Create the default shelf (= id = '00000000-0000-0000-0000-000000000000',
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
        // doc).
        let defaultShelfId = UUID(uuidString: "00000000-0000-0000-0000-000000000000") ?? UUID()
        let defaultShelfDir = shelvesRoot.appendingPathComponent(defaultShelfId.uuidString, isDirectory: true)
        if !fm.fileExists(atPath: defaultShelfDir.path) {
            try fm.createDirectory(at: defaultShelfDir, withIntermediateDirectories: true)
            // Write shelf.json
            let defaultShelf = Bookshelf(id: defaultShelfId, name: String(localized: "library.default.shelf_name"), createdAt: Date(), updatedAt: Date())
            let data = try JSONEncoder().encode(defaultShelf)
            try data.write(to: defaultShelfDir.appendingPathComponent("shelf.json"))
        }
        // 3. Create books/ inside default shelf.
        let defaultBooksDir = defaultShelfDir.appendingPathComponent("books", isDirectory: true)
        try fm.createDirectory(at: defaultBooksDir, withIntermediateDirectories: true)
        // 4. Move each book from books/ at root into default shelf's books/.
        guard let bookDirs = try? fm.contentsOfDirectory(
            at: booksAtRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        for bookDir in bookDirs {
            let isDir = (try? bookDir.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            guard isDir else { continue }
            let dest = defaultBooksDir.appendingPathComponent(bookDir.lastPathComponent, isDirectory: true)
            if !fm.fileExists(atPath: dest.path) {
                try fm.moveItem(at: bookDir, to: dest)
            } else {
                // Collision: skip (= user manually created a same-id book in default shelf).
                continue
            }
        }
    }

    // / Always-run-on-launch housekeeping ((see OOB.md #2026-08-27)
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / every launch).
    private func alwaysRunOnLaunch(fm: FileManager) throws {
        // 1. Compute the default shelf dir (= all-zeros UUID).
        let shelvesRoot = wsRoot.appendingPathComponent("shelves", isDirectory: true)
        let defaultShelfId = UUID(uuidString: "00000000-0000-0000-0000-000000000000") ?? UUID()
        let defaultShelfDir = shelvesRoot.appendingPathComponent(defaultShelfId.uuidString, isDirectory: true)
        guard fm.fileExists(atPath: defaultShelfDir.path) else { return }
        // 2. Rename legacy 'default' → ' (idempotent).
        let shelfJSONURL = defaultShelfDir.appendingPathComponent("shelf.json")
        if fm.fileExists(atPath: shelfJSONURL.path),
           let data = try? Data(contentsOf: shelfJSONURL),
           var existing = try? JSONDecoder().decode(Bookshelf.self, from: data),
           existing.name == String(localized: "library.default.legacy_shelf_name") {
            existing.name = String(localized: "library.default.shelf_name")
            existing.updatedAt = Date()
            let updated = try JSONEncoder().encode(existing)
            try updated.write(to: shelfJSONURL)
        }
        // 2b. Rename the existing default book title ' → '
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
        // that was actually written by earlier wenshu versions).
        let defaultBooksDir = defaultShelfDir.appendingPathComponent("books", isDirectory: true)
        let legacyBookIds = [
            UUID(uuidString: "00000000-0000-0000-0000-000000000001"),
            UUID(uuidString: "11111111-1111-1111-1111-111111111111"),
        ]
        for legacyBookId in legacyBookIds {
            guard let bookId = legacyBookId else { continue }
            let bookDir = defaultBooksDir.appendingPathComponent(
                bookId.uuidString, isDirectory: true
            )
            let bookJSONURL = bookDir.appendingPathComponent("book.json")
            guard fm.fileExists(atPath: bookJSONURL.path),
                  let data = try? Data(contentsOf: bookJSONURL),
                  var existing = try? JSONDecoder().decode(Book.self, from: data),
                  existing.title == String(localized: "library.default.shelf_name")
            else { continue }
            existing.title = String(localized: "library.default.book_title")
            existing.updatedAt = Date()
            let updated = try JSONEncoder().encode(existing)
            try updated.write(to: bookJSONURL)
        }
        // 3. Seed default help-doc anchor (= skipped if already present).
        try seedDefaultHelpDoc(in: defaultShelfDir, fm: fm)
    }


    private func isEmptyDirectory(_ url: URL) -> Bool {
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []
        return contents.isEmpty
    }

    private func writeOrUpdateSchemaVersion() throws {
        let infoPlistURL = wsRoot.appendingPathComponent("Info.plist")
        var plist: [String: Any] = [:]
        if FileManager.default.fileExists(atPath: infoPlistURL.path),
           let data = try? Data(contentsOf: infoPlistURL),
           let existing = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] {
            plist = existing
        }
        plist["CFBundlePackageType"] = plist["CFBundlePackageType"] ?? "WSPC"
        plist["CFBundleName"] = plist["CFBundleName"] ?? "wenshu"
        plist["CFBundleIdentifier"] = plist["CFBundleIdentifier"] ?? "com.wenshu.library"
        plist["WSSchemaVersion"] = CURRENT_SCHEMA_VERSION
        if plist["WSPCreatedAt"] == nil {
            plist["WSPCreatedAt"] = Date().formatted(.iso8601)
        }
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: infoPlistURL)
    }
}
