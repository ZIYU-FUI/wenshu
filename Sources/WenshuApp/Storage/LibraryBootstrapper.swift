// LibraryBootstrapper.swift · Wenshu (文枢) · v0.26 (FCP library replica)
//
// One-time setup + ongoing self-heal for the .ws library structure.
// Per spec v5 ticket 021:
// - On first launch with a new .ws (= missing shelves/, reference-library/,
//   cache/): create them
// - On missing Info.plist: create with defaults (= defensive; LibraryRootView
//   normally creates it at onboarding, but if user dragged a folder in
//   without Info.plist, this recovers)
// - Remove empty chapters/ + books/ at .ws root IF they exist and are
//   empty (= orphan from early onboarding iteration)
// - For each book discovered under shelves/<shelf>/books/<book-id/>,
//   verify all 8 standard folders + 2 data files exist; create missing
//   ones (= defensive for books created before v0.26 or by external tools)
// - Never deletes user data (= .md bodies + chat.sqlite + attachments)

import Foundation

struct LibraryBootstrapper: Sendable {
    let wsRoot: URL

    /// Ensure the .ws library structure is valid (= create missing
    /// directories + write missing Info.plist + drop empty orphans).
    /// Idempotent: safe to call on every launch.
    func ensureValidStructure() throws {
        let fm = FileManager.default
        // 1. Create top-level subdirs if missing.
        for subdir in ["shelves", "reference-library", "cache"] {
            let url = wsRoot.appendingPathComponent(subdir, isDirectory: true)
            if !fm.fileExists(atPath: url.path) {
                try fm.createDirectory(at: url, withIntermediateDirectories: true)
            }
        }
        // 2. Create reference-library subdirs (= LLM Wiki 4-layer).
        for layer in ["raw", "entities", "abstracts", "indexes"] {
            let url = wsRoot
                .appendingPathComponent("reference-library", isDirectory: true)
                .appendingPathComponent(layer, isDirectory: true)
            if !fm.fileExists(atPath: url.path) {
                try fm.createDirectory(at: url, withIntermediateDirectories: true)
            }
        }
        // 3. Create reference-library/indexes/saved-searches/ (= ticket 016).
        let savedSearches = wsRoot
            .appendingPathComponent("reference-library", isDirectory: true)
            .appendingPathComponent("indexes", isDirectory: true)
            .appendingPathComponent("saved-searches", isDirectory: true)
        if !fm.fileExists(atPath: savedSearches.path) {
            try fm.createDirectory(at: savedSearches, withIntermediateDirectories: true)
        }
        // 4. Info.plist defensive creation (= if missing).
        let infoPlist = wsRoot.appendingPathComponent("Info.plist")
        if !fm.fileExists(atPath: infoPlist.path) {
            try writeDefaultInfoPlist(to: infoPlist)
        }
        // 5. Remove empty chapters/ + books/ at .ws root IF they exist
        // and are empty (= orphan from early onboarding; safe to remove).
        // NOTE: do NOT touch shelves/ at .ws root here (= canonical book
        // container per ticket 022; bootstrapper CREATES it, not deletes).
        for orphan in ["chapters", "books"] {
            let url = wsRoot.appendingPathComponent(orphan, isDirectory: true)
            if fm.fileExists(atPath: url.path), isEmptyDirectory(url) {
                try fm.removeItem(at: url)
            }
        }
        // 6. For each book, verify 8 standard folders + 2 data files.
        try ensurePerBookStructure()
    }

    // MARK: - Per-book setup

    private func ensurePerBookStructure() throws {
        let fm = FileManager.default
        let shelvesRoot = wsRoot.appendingPathComponent("shelves", isDirectory: true)
        guard fm.fileExists(atPath: shelvesRoot.path) else { return }
        // Walk shelves/<shelf-uuid>/books/<book-uuid>/
        guard let shelfEnumerator = fm.enumerator(
            at: shelvesRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        let standardFolders = [
            "world", "characters", "outlines", "chapters",
            "drafts", "sessions", "foreshadowing", "placeholders"
        ]
        let dataFiles = ["kanban.json", "todo.json"]
        for case let bookDir as URL in shelfEnumerator {
            // Only process the deepest books/<book-uuid>/ directories.
            // We detect them by the immediate parent dir name being "books".
            let parentLast = bookDir.deletingLastPathComponent().lastPathComponent
            guard parentLast == "books" else { continue }
            for folder in standardFolders {
                let dir = bookDir.appendingPathComponent(folder, isDirectory: true)
                if !fm.fileExists(atPath: dir.path) {
                    try fm.createDirectory(at: dir, withIntermediateDirectories: true)
                }
            }
            for file in dataFiles {
                let url = bookDir.appendingPathComponent(file)
                if !fm.fileExists(atPath: url.path) {
                    try writeEmptyJSONArray(to: url)
                }
            }
        }
    }

    // MARK: - Helpers

    private func isEmptyDirectory(_ url: URL) -> Bool {
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []
        return contents.isEmpty
    }

    private func writeDefaultInfoPlist(to url: URL) throws {
        let plist: [String: Any] = [
            "CFBundlePackageType": "WSPC",
            "CFBundleName": "wenshu",
            "CFBundleIdentifier": "com.wenshu.library",
            "WSSchemaVersion": CURRENT_SCHEMA_VERSION,
            "WSPCreatedAt": ISO8601DateFormatter().string(from: Date())
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: url)
    }

    private func writeEmptyJSONArray(to url: URL) throws {
        let data = Data("[]".utf8)
        try data.write(to: url)
    }
}