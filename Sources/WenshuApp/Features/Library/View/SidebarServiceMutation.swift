//
//  SidebarServiceMutation.swift
//
//  Mutation business layer for SidebarService (= the create / delete / rename
//  operations on shelves + books + references; = the v1.69y (= boss
//  2026-09-23 (see OOB.md #2026-09-23) OOB ', ') restoration that was
//  recovered from the deleted NewLibraryOutlineView.swift (2366 LOC) after
//  `git rm`'d it without re-wiring).
//
//  Why extracted (= §6.6 god-class split): the main SidebarService class
//  (= 440 LOC) handles the sidebar tree state (= the `nodes` array +
//  the reload lifecycle + the `loadError` state). The mutation
//  business layer (= 569 LOC) handles the persistence surface (=
//  FileManager + JSONEncoder/Decoder for shelvesRoot/, books/<bookId>/
//  book.json, shelf.json) + the reserved-name guard (= rejects "" /
//  "Reference Library" legacy system-shelf names) + the default-
//  shelf-delete guard (= shelf 00000000-... cannot be deleted) +
//  the duplicate-name validation. The 2 concerns have no shared
//  state (= the mutation methods read from the closure-based data
//  accessors; = they don't access the `nodes` array directly).
//
//  Note (= Swift 6 strict concurrency): the 5 stored properties that
//  the extension reads from the main class (= `loadShelves` /
//  `loadAllBooks` / `loadReferences` / `loadFolderDocCount` /
//  `bookStore`) are now `let` (internal) instead of `private let`.
//  Cross-file `extension` cannot access `private` of the class
//  (= Swift 5.5+ rule; = the access level is per-scope, not per-
//  declaration); = the 5 properties are now module-internal.
//

import Foundation

// MARK: - v1.69y (see OOB.md #2026-09-23) OOB ', '
// Create + delete + rename business layer for the sidebar. Restored from the deleted
// NewLibraryOutlineView.swift (2366 LOC) after `git rm`'d it without re-wiring (= per
// (see OOB.md #2026-09-23) OOB '，'). What lives here: - persistence surface (=
// FileManager + JSONEncoder/Decoder for shelvesRoot/, books/<bookId>/book.json,
// shelf.json). - reserved-name guard (= rejects "" / "Reference Library" legacy
// system-shelf names; = (see OOB.md #2026-09-20) OOB). - default-shelf-delete guard (=
// shelf 00000000-... cannot be deleted; = Reference Library is immutable). -
// duplicate-name validation for create + rename. What does NOT live here: - UI (=
// sheets in SidebarSheets.swift + context menu in SidebarContextMenu.swift + alert +
// sheet wiring in AppleSidebarView.swift). Error type = one enum with LocalizedError
// (= the m1 legacy ShelfError / ShelfDeleteError pair merged into one with all cases;
// = same set of reserved + duplicate + cannot-delete-default guards preserved
// verbatim).
extension SidebarService {
    /// domain error for the create / delete / rename operations (=
    /// LocalizedError so the caller can present the message in a SwiftUI
    /// `.alert(item:)`).
    enum MutationError: LocalizedError, Equatable {
        case cannotDeleteDefault
        case duplicateName(String)
        case reservedName(String)
        case bookNotFound
        case shelfNotFound

        var errorDescription: String? {
            switch self {
            case .cannotDeleteDefault:
                return String(localized: "sidebar_service_error_cannot_delete_default")
            case .duplicateName(let name):
                return String(localized: "new_shelf_sheet_duplicate_error")
                    .replacingOccurrences(of: "%@", with: name)
            case .reservedName(let name):
                return String(localized: "new_shelf_sheet_reserved_error")
                    .replacingOccurrences(of: "%@", with: name)
            case .bookNotFound:
                return String(localized: "sidebar_service_error_book_not_found")
            case .shelfNotFound:
                return String(localized: "sidebar_service_error_shelf_not_found")
            }
        }
    }

    /// reserved shelf / book names (= the reference library uses `` as its
    /// display name; = reusing that name for a user shelf would shadow the
    /// reference root; = same set the legacy NewLibraryOutlineView.renameShelf
    /// enforced).
    static let reservedNames: Set<String> = [
        String(localized: "library.sidebar.reference_root"),
        "资料库", "参考库", "reference library"
    ]

    /// list all shelf display names (= for duplicate-name validation in
    /// NewShelfSheet + RenameItemSheet). Caller passes the cached `shelves`
    /// from SidebarService.
    func existingShelfNames() -> [String] {
        shelves.map { $0.name }
    }

    /// list all book titles (= for duplicate-name validation in
    /// RenameItemSheet; = the legacy NewLibraryOutlineView.renameBook logic).
    func existingBookTitles() -> [String] {
        books.map { $0.title }
    }

    /// create a new shelf on disk (= shelves/<uuid>/shelf.json + standard 8
    /// book folders + empty kanban.json + todo.json). Returns the new shelf's
    /// UUID on success (= the caller updates `shelves` + `sidebarSelection` +
    /// calls `reload()`).
    @discardableResult
    func createShelf(name: String) throws -> UUID {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if Self.reservedNames.contains(where: { trimmed.caseInsensitiveCompare($0) == .orderedSame }) {
            throw MutationError.reservedName(trimmed)
        }
        if existingShelfNames().contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            throw MutationError.duplicateName(trimmed)
        }
        let shelfId = UUID()
        guard let shelvesRoot = bookStore?.stores.shelvesRoot else {
            throw MutationError.shelfNotFound
        }
        let shelfDir = shelvesRoot
            .appendingPathComponent(shelfId.uuidString, isDirectory: true)
        let fm = FileManager.default
        try fm.createDirectory(at: shelfDir, withIntermediateDirectories: true)
        let now = Date()
        let shelf = Bookshelf(id: shelfId, name: trimmed, createdAt: now, updatedAt: now)
        let data = try JSONEncoder().encode(shelf)
        try data.write(to: shelfDir.appendingPathComponent("shelf.json"))
        return shelfId
    }

    /// create a new book on disk (= shelves/<shelf>/books/<book-uuid>/ with 8
    /// standard folders + book.json + kanban.json + todo.json). Mirrors the
    /// v0.29 LibraryBootstrapper per-book setup pattern. Returns the new book's
    /// UUID on success.
    @discardableResult
    func createBook(input: NewBookSheet.NewBookInput) throws -> UUID {
        let trimmedTitle = input.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty {
            throw MutationError.bookNotFound  // signal empty title (= use this case)
        }
        if existingBookTitles().contains(where: { $0.caseInsensitiveCompare(trimmedTitle) == .orderedSame }) {
            throw MutationError.duplicateName(trimmedTitle)
        }
        let bookId = UUID()
        guard let shelvesRoot = bookStore?.stores.shelvesRoot else {
            throw MutationError.bookNotFound
        }
        let bookDir = shelvesRoot
            .appendingPathComponent(input.shelfId.uuidString, isDirectory: true)
            .appendingPathComponent("books", isDirectory: true)
            .appendingPathComponent(bookId.uuidString, isDirectory: true)
        let fm = FileManager.default
        try fm.createDirectory(at: bookDir, withIntermediateDirectories: true)
        let standardFolders = [
            "world", "characters", "outlines", "chapters",
            "drafts", "sessions", "foreshadowing", "placeholders"
        ]
        for folder in standardFolders {
            try fm.createDirectory(
                at: bookDir.appendingPathComponent(folder, isDirectory: true),
                withIntermediateDirectories: true
            )
        }
        // Empty kanban + todo JSON.
        for dataFile in ["kanban.json", "todo.json"] {
            try Data("[]".utf8).write(to: bookDir.appendingPathComponent(dataFile))
        }
        // Book metadata.
        let book = Book(
            id: bookId,
            title: trimmedTitle,
            author: input.author.trimmingCharacters(in: .whitespacesAndNewlines),
            shelfId: input.shelfId
        )
        let data = try JSONEncoder().encode(book)
        try data.write(to: bookDir.appendingPathComponent("book.json"))
        return bookId
    }

    /// delete a shelf on disk (= shelves/<uuid>/). The default shelf
    /// (`00000000-0000-0000-0000-000000000000`) cannot be deleted (= the legacy
    /// ShelfDeleteError guard; = 'Reference Library cannot be deleted').
    func deleteShelf(id: UUID) throws {
        guard id.uuidString != "00000000-0000-0000-0000-000000000000" else {
            throw MutationError.cannotDeleteDefault
        }
        guard let shelvesRoot = bookStore?.stores.shelvesRoot else {
            throw MutationError.shelfNotFound
        }
        let shelfDir = shelvesRoot
            .appendingPathComponent(id.uuidString, isDirectory: true)
        if FileManager.default.fileExists(atPath: shelfDir.path) {
            try FileManager.default.removeItem(at: shelfDir)
        }
    }

    /// delete a single book on disk (= shelves/<shelf>/books/<book-uuid>/).
    /// Silently no-op if the book is not on disk (= the legacy
    /// NewLibraryOutlineView.deleteBook behavior).
    func deleteBook(id: UUID) throws {
        guard let shelvesRoot = bookStore?.stores.shelvesRoot else {
            throw MutationError.bookNotFound
        }
        // Find the shelf that contains the book (= walk shelves to find the dir
        // containing shelves/<shelf>/books/<bookId>).
        let fm = FileManager.default
        guard let shelfDirs = try? fm.contentsOfDirectory(
            at: shelvesRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return }
        for shelfDir in shelfDirs {
            let bookDir = shelfDir
                .appendingPathComponent("books")
                .appendingPathComponent(id.uuidString, isDirectory: true)
            if fm.fileExists(atPath: bookDir.path) {
                try fm.removeItem(at: bookDir)
                return
            }
        }
        // Book not on disk = silent no-op (= matches legacy).
    }

    /// rename a shelf (= rewrites shelf.json with the new name). The directory
    /// name (= UUID) is preserved (= the shelf's identity is stable per Apple
    /// HIG document-based app).
    func renameShelf(id: UUID, newName: String) throws {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        if Self.reservedNames.contains(where: { trimmed.caseInsensitiveCompare($0) == .orderedSame }) {
            throw MutationError.reservedName(trimmed)
        }
        let others = existingShelfNames().filter { name in
            guard let shelf = self.shelves.first(where: { $0.name == name }) else {
                return true  // skip self if name lookup fails
            }
            return shelf.id != id
        }
        if others.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            throw MutationError.duplicateName(trimmed)
        }
        guard let shelvesRoot = bookStore?.stores.shelvesRoot else {
            throw MutationError.shelfNotFound
        }
        let shelfDir = shelvesRoot
            .appendingPathComponent(id.uuidString, isDirectory: true)
        let shelfJSONURL = shelfDir.appendingPathComponent("shelf.json")
        let fm = FileManager.default
        guard fm.fileExists(atPath: shelfJSONURL.path),
              let data = try? Data(contentsOf: shelfJSONURL),
              var existing = try? JSONDecoder().decode(Bookshelf.self, from: data)
        else { throw MutationError.shelfNotFound }
        existing.name = trimmed
        existing.updatedAt = Date()
        let updated = try JSONEncoder().encode(existing)
        try updated.write(to: shelfJSONURL)
    }

    /// rename a book (= rewrites book.json with the new title). The directory
    /// name (= UUID) is preserved (= the book's identity is stable per Apple
    /// HIG document-based app).
    func renameBook(id: UUID, newTitle: String) throws {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            throw MutationError.bookNotFound
        }
        let others = existingBookTitles().filter { title in
            guard let book = self.books.first(where: { $0.title == title }) else {
                return true
            }
            return book.id != id
        }
        if others.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            throw MutationError.duplicateName(trimmed)
        }
        guard let shelvesRoot = bookStore?.stores.shelvesRoot else {
            throw MutationError.bookNotFound
        }
        let fm = FileManager.default
        guard let shelfDirs = try? fm.contentsOfDirectory(
            at: shelvesRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { throw MutationError.bookNotFound }
        for shelfDir in shelfDirs {
            let bookJSONURL = shelfDir
                .appendingPathComponent("books")
                .appendingPathComponent(id.uuidString, isDirectory: true)
                .appendingPathComponent("book.json")
            if fm.fileExists(atPath: bookJSONURL.path),
               let data = try? Data(contentsOf: bookJSONURL),
               var existing = try? JSONDecoder().decode(Book.self, from: data) {
                existing.title = trimmed
                existing.updatedAt = Date()
                let updated = try JSONEncoder().encode(existing)
                try updated.write(to: bookJSONURL)
                return
            }
        }
        throw MutationError.bookNotFound
    }

    /// (= boss 2026-10-10 "素 材区，卡片， 右键菜单， 做删除、重 命名" directive). Delete a single
    /// reference from the reference library (= removes the `<layer>/<id>.md`
    /// body file + the index entry from `entities.json`). The reference card
    /// disappears from the sidebar tree on the next `reload()` (= the sidebar's
    /// `.onChange(of: workspaceUI. sidebarSelection)` triggers a reload; = we
    /// also call `reload()` here to refresh immediately).
    func deleteReference(id: UUID) throws {
        guard let referenceStore = bookStore?.stores.referenceStore else {
            throw MutationError.bookNotFound
        }
        try referenceStore.deleteReference(id: id)
    }

    /// rename a single reference (= change only the `title` field; = the .md
    /// filename is the stable UUID and stays unchanged; = the sidebar row's
    /// title text updates on next reload). The reference's body content is
    /// unchanged (= the rename only touches the index entry's `title`).
    /// Validation: - empty title = rejected - duplicate title (in any layer) =
    /// rejected (= the reference-library doesn't enforce unique titles but the
    /// rename sheet shows the duplicate error for consistency with shelf/book
    /// rename).
    func renameReference(id: UUID, newTitle: String) throws {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw MutationError.bookNotFound
        }
        guard let referenceStore = bookStore?.stores.referenceStore else {
            throw MutationError.bookNotFound
        }
        // Look up the reference across all 4 layers; = the reference id is unique across
        // the library.
        let all = (try? referenceStore.loadAllReferences()) ?? []
        guard let existing = all.first(where: { $0.id == id }) else {
            throw MutationError.bookNotFound
        }
        // Duplicate check: if another reference (in any layer) has the same title,
        // reject.
        let others = all.filter { $0.id != id }
        if others.contains(where: { $0.title.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            throw MutationError.duplicateName(trimmed)
        }
        // Build the updated reference (= the existing reference with the new title +
        // updatedAt). We keep all other fields (= tags, summary, category,
        // source, etc.) unchanged.
        var updated = existing
        updated.title = trimmed
        updated.updatedAt = Date()
        // Load the existing body (= the rename only touches the index entry; = the .md
        // body file is preserved verbatim; = `replaceReference` writes both
        // the index + the body).
        let body = referenceStore.loadReferenceBody(id: id) ?? ""
        try referenceStore.replaceReference(updated, bodyMarkdown: body)
    }

    /// list of all reference titles (= for the duplicate check in
    /// `renameReference`; = = the v2.7 [archived-round] addition; = the rename sheet
    /// reads this and shows the duplicate error).
    func otherReferenceTitles(excluding id: UUID) -> [String] {
        guard let referenceStore = bookStore?.stores.referenceStore else {
            return []
        }
        let all = (try? referenceStore.loadAllReferences()) ?? []
        return all.filter { $0.id != id }.map { $0.title }
    }

    // MARK: v2.7: bookDoc (= one .md file in a
    // book folder) rename / delete / duplicate-name helpers. The right-click context menu
    // on the workspace card grid now also fires for `.bookDoc` cards (= the boss
    // 2026-10-10 "你把书的加上就行了" directive). The methods mirror the reference shape (=
    // delegate to the file system under the books root; = the sidebar's reference
    // store path is `reference-library/`; = the bookDoc path is `shelves/<shelf-
    // uuid>/books/<book-uuid>/<folder>/<file>.md`). The `BookDoc.id` is a UUID v5
    // derived from `(bookId, folderName, fileName)` (= stable across re-
    // evaluations of the same .md file). To act on a doc by id, the service walks
    // the shelves root to find which `(bookId, folderName, fileName)` triple
    // produces that id (= matches the same hash function used at load time).

    /// Walk the shelves root and resolve a `BookDoc.id` to its on-disk file
    /// URL. Returns `nil` if the file is not found (= deleted concurrently; =
    /// the user sees the rename / delete action silently no-op with a
    /// `wenshuLogger.info`).
    func findBookDocFile(id: UUID) -> URL? {
        guard let bookStore else { return nil }
        let shelvesRoot = bookStore.stores.shelvesRoot
        guard FileManager.default.fileExists(atPath: shelvesRoot.path) else {
            return nil
        }
        let shelfDirs = (try? FileManager.default.contentsOfDirectory(
            at: shelvesRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        for shelfDir in shelfDirs {
            let booksDir = shelfDir.appendingPathComponent("books")
            guard FileManager.default.fileExists(atPath: booksDir.path) else { continue }
            let bookDirs = (try? FileManager.default.contentsOfDirectory(
                at: booksDir,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )) ?? []
            for bookDir in bookDirs {
                let folderDirs = (try? FileManager.default.contentsOfDirectory(
                    at: bookDir,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                )) ?? []
                for folderDir in folderDirs {
                    let mdFiles = (try? FileManager.default.contentsOfDirectory(
                        at: folderDir,
                        includingPropertiesForKeys: nil,
                        options: [.skipsHiddenFiles]
                    )) ?? []
                    for mdFile in mdFiles where mdFile.pathExtension == "md" {
                        let bookId = UUID(uuidString: bookDir.lastPathComponent) ?? UUID()
                        let folderName = folderDir.lastPathComponent
                        let fileName = mdFile.lastPathComponent
                        let candidate = PreviewPane.stableBookDocId(
                            bookId: bookId,
                            folderName: folderName,
                            fileName: fileName
                        )
                        if candidate == id {
                            return mdFile
                        }
                    }
                }
            }
        }
        return nil
    }

    /// Rename a book doc's .md file on disk (= the new filename =
    /// `<newTitle>.md`; = the file's H1 heading is also rewritten from `#
    /// <oldTitle>` to `# <newTitle>` so the in-file title stays in sync with
    /// the filename). Throws if the file is not found OR the new name is empty
    /// / contains invalid path characters.
    func renameBookDoc(id: UUID, newTitle: String) throws {
        guard let url = findBookDocFile(id: id) else {
            throw MutationError.bookNotFound
        }
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw MutationError.duplicateName("") }
        guard !trimmed.contains("/") && !trimmed.contains(":") else {
            throw MutationError.duplicateName(trimmed)
        }
        let newURL = url.deletingLastPathComponent()
            .appendingPathComponent(trimmed + ".md")
        if FileManager.default.fileExists(atPath: newURL.path) {
            throw MutationError.duplicateName(trimmed)
        }
        // Read current body, rewrite H1 heading if present, then write to new path.
        let body = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        let oldTitle = url.deletingPathExtension().lastPathComponent
        let updatedBody = Self.rewriteH1(in: body, from: oldTitle, to: trimmed)
        try? FileManager.default.removeItem(at: url)
        try updatedBody.write(to: newURL, atomically: true, encoding: .utf8)
        sidebarLogger.info("[wenshu.bookdoc] renamed: \(url.lastPathComponent) -> \(newURL.lastPathComponent)")
    }

    /// Helper: rewrite the file's H1 heading (= the first non-blank line in the
    /// file, if it starts with `# `) from `oldTitle` to `newTitle`. If the H1
    /// doesn't match, the body is returned unchanged.
    static func rewriteH1(in body: String, from oldTitle: String, to newTitle: String) -> String {
        let lines = body.components(separatedBy: "\n")
        var found = false
        var updated: [String] = []
        for line in lines {
            if !found, line.hasPrefix("# "), line.dropFirst(2).trimmingCharacters(in: .whitespaces) == oldTitle {
                updated.append("# \(newTitle)")
                found = true
            } else {
                updated.append(line)
            }
        }
        return updated.joined(separator: "\n")
    }

    /// Delete a book doc's .md file from disk (= the file IS the entire book
    /// doc; = no separate index entry to remove; = the file deletion is the
    /// complete delete). Throws if the file is not found.
    func deleteBookDoc(id: UUID) throws {
        guard let url = findBookDocFile(id: id) else {
            throw MutationError.bookNotFound
        }
        try FileManager.default.removeItem(at: url)
        sidebarLogger.info("[wenshu.bookdoc] deleted: \(url.lastPathComponent)")
        // A cover is a CHILD of its document: the picture and the clip
        // exist to depict this .md file, so a file that is gone leaves
        // a cover that can never be shown again. The cover goes with
        // it.
        //
        // The removal is TOLERANT: the document delete is the
        // important operation, and a cover that cannot be removed
        // must not stop it.
        CoverCascade.live().removeCoverTolerantly(forBookDoc: id)
    }

    /// List of other book doc titles in the SAME folder (= the duplicate-name
    /// check for the rename sheet; = the user shouldn't be able to rename a doc
    /// to a name that already exists in the same folder). Returns empty array
    /// if the doc is not found.
    func otherBookDocTitles(excluding id: UUID) -> [String] {
        guard let url = findBookDocFile(id: id) else { return [] }
        let folder = url.deletingLastPathComponent()
        let entries = (try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        return entries
            .filter { $0.pathExtension == "md" && $0 != url }
            .map { $0.deletingPathExtension().lastPathComponent }
    }

    // MARK: v1.69y: picker / state query helpers (= consumed by
    // AppleSidebarView when presenting NewBookSheet / RenameItemSheet; = pure reads of
    // the current SidebarService state).

    /// list of (id, name) for the shelf picker in NewBookSheet (= the user
    /// picks which shelf a new book goes into).
    func availableShelvesForPicker() -> [(id: UUID, name: String)] {
        shelves.map { ($0.id, $0.name) }
    }

    /// resolve the target shelf for a new book (= the current sidebarSelection
    /// if it's a shelf, else fallback to the default shelf). Mirrors the
    /// v1.0.0-m1 legacy NewLibraryOutlineView.resolveNewBookTargetShelf.
    func targetShelfForNewBook(currentSelection: SidebarItem?) -> (id: UUID, name: String)? {
        if case .shelf(let id) = currentSelection,
           let shelf = shelves.first(where: { $0.id == id }) {
            return (shelf.id, shelf.name)
        }
        if case .book(let id) = currentSelection,
           let book = books.first(where: { $0.id == id }),
           let shelf = shelves.first(where: { $0.id == book.shelfId }) {
            return (shelf.id, shelf.name)
        }
        return defaultShelfTarget()
    }

    /// fallback target shelf (= the default all-zeros shelf; = first-launch
    /// enable).
    func defaultShelfTarget() -> (id: UUID, name: String)? {
        let defaultId = UUID(uuidString: "00000000-0000-0000-0000-000000000000") ?? UUID()
        if let shelf = shelves.first(where: { $0.id == defaultId }) {
            return (shelf.id, shelf.name)
        }
        // First-launch fallback: no shelves on disk yet.
        return (defaultId, String(localized: "library.default.shelf_name"))
    }

    /// shelf names excluding the one with `id` (= for duplicate-name validation
    /// in RenameItemSheet when the user is renaming a shelf).
    func otherShelfNames(excluding id: UUID) -> [String] {
        shelves.filter { $0.id != id }.map { $0.name }
    }

    /// book titles excluding the one with `id` (= for duplicate-title
    /// validation in RenameItemSheet when the user is renaming a book).
    func otherBookTitles(excluding id: UUID) -> [String] {
        books.filter { $0.id != id }.map { $0.title }
    }
}
