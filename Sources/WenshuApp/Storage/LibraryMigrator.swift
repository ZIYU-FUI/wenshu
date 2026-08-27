// LibraryMigrator.swift · Wenshu (文枢) · v0.26 (FCP library replica)
//
// One-time v0.x → v0.26 .ws layout migration. Detects v0.x .ws (= has
// books/ at .ws root, OR no WSSchemaVersion key in Info.plist) and
// migrates to v0.26 layout.
//
// Per spec v5 ticket 022:
// - PRESERVE: Info.plist + chat.sqlite + Icon + assets/ + backups/ +
//   books/ (the v0.x books/ at root is moved into a default shelf)
// - DROP only-if-empty: chapters/ at .ws root, books/ at .ws root
//   (after moving its content), shelves/ at .ws root
// - CREATE: reference-library/{raw,entities,abstracts,indexes}/, cache/
// - WRITE: WSSchemaVersion = 1 to existing Info.plist
// - For each migrated book: create the 8 standard folders + 2 JSON
//   data files IF they do not exist
//
// CRITICAL: does NOT touch chat.sqlite (active chat history). Does NOT
// touch Info.plist if WSSchemaVersion key already exists (= idempotent).
// Does NOT touch user .md content under migrated books.

import Foundation

struct LibraryMigrator: Sendable {
    let wsRoot: URL

    /// Run the v0.x → v0.26 migration. Idempotent: if WSSchemaVersion
    /// is already 1, this is a no-op.
    func migrateIfNeeded() throws {
        let fm = FileManager.default
        // 1. Idempotency check: read Info.plist; if WSSchemaVersion = 1
        // (= current), skip migration entirely.
        if try isAlreadyCurrentSchema() {
            return
        }
        // 2. Pre-v0.26 detection: v0.x .ws had books/ at .ws root OR
        // shelves/ at .ws root (= empty orphan). Move v0.x books/ to
        // shelves/<default-shelf>/books/<id>/. If v0.x has no books/ at
        // root (e.g. user freshly selected an empty .ws), create empty
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
        // 4. CREATE: reference-library/4 layers + cache/.
        for sub in ["reference-library/raw", "reference-library/entities",
                    "reference-library/abstracts", "reference-library/indexes",
                    "reference-library/indexes/saved-searches", "cache"] {
            let url = wsRoot.appendingPathComponent(sub, isDirectory: true)
            if !fm.fileExists(atPath: url.path) {
                try fm.createDirectory(at: url, withIntermediateDirectories: true)
            }
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
        // name = '从这里开始' per boss 8/27 OOB (= used as the help-doc
        // anchor shelf; the user can delete it once they have their own
        // shelves; until deleted it holds the default book + default
        // doc).
        let defaultShelfId = UUID(uuidString: "00000000-0000-0000-0000-000000000000") ?? UUID()
        let defaultShelfDir = shelvesRoot.appendingPathComponent(defaultShelfId.uuidString, isDirectory: true)
        if !fm.fileExists(atPath: defaultShelfDir.path) {
            try fm.createDirectory(at: defaultShelfDir, withIntermediateDirectories: true)
            // Write shelf.json
            let defaultShelf = Bookshelf(id: defaultShelfId, name: "从这里开始", createdAt: Date(), updatedAt: Date())
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
        // 5. Rename the default shelf from legacy '默认书架' to '从这里开始'
        // (= boss 8/27 OOB; legacy shelf.json in existing .ws gets updated
        // in place so the user sees the new label without losing any
        // books they may have created under it).
        let shelfJSONURL = defaultShelfDir.appendingPathComponent("shelf.json")
        if fm.fileExists(atPath: shelfJSONURL.path),
           let data = try? Data(contentsOf: shelfJSONURL),
           var existing = try? JSONDecoder().decode(Bookshelf.self, from: data),
           existing.name == "默认书架" {
            existing.name = "从这里开始"
            existing.updatedAt = Date()
            let updated = try JSONEncoder().encode(existing)
            try updated.write(to: shelfJSONURL)
        }
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
            plist["WSPCreatedAt"] = ISO8601DateFormatter().string(from: Date())
        }
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: infoPlistURL)
    }
}