// LibraryRoot.swift · Wenshu (Wenshu) · v0.02.0
//
// Where wenshu stores the user's bookshelves on disk. The location is
// hard-coded for v0.02.0 (= the user has no Preferences panel yet) but
// kept behind a single function so v0.02.1+ can swap it for an
// NSOpenPanel-chosen location (= Apple HIG document-based apps: every
// app picks a default but lets the user pick a different one).
//
// Why ~/Documents/wenshu (= Apple HIG default):
//   - Documents is the macOS-standard user-content location (= Pages,
//     Numbers, Keynote, TextEdit, Bear, Obsidian all default here).
//   - Finder treats it as the canonical 'files I created' folder.
//   - It shows up in Time Machine backups without extra config.
//   - Cloud-synced folders (= iCloud Drive, Dropbox) can be substituted
//     by the user moving the directory; Spotlight index travels with it.

import Foundation

enum LibraryRoot {
    /// Default = ~/Documents/wenshu. Single point of change (= v0.02.1+
    /// can read this from UserDefaults once Preferences ships).
    static var defaultURL: URL {
        let documents = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents")
        return documents.appendingPathComponent("wenshu", isDirectory: true)
    }

    /// Create the default root if it doesn't exist (= first launch).
    /// Returns the URL whether or not it had to be created.
    @discardableResult
    static func ensureDefault() -> URL {
        let url = defaultURL
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}