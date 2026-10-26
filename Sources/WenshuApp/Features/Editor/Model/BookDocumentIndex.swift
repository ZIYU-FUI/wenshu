// Sources/WenshuApp/Features/Editor/Model/BookDocumentIndex.swift
//
// The documents that live inside one book (= the folders the sidebar
// shows: world/, characters/, outlines/, chapters/, drafts/, ideas/).
//
// Two readers need the same view of a book:
//
//   1. The wiki-link resolver (= the engine asks it whether a link's
//      target exists; = without an answer the link stays grey and
//      the click never reaches the app).
//   2. The link navigation (= the app opens the document the click
//      named).
//
// So both read the book through this type: one scan, one naming
// rule (= the file name without the `.md` suffix), one id (= the
// path relative to the book root).

import Foundation

struct BookDocumentIndex: Sendable {

    /// One document inside the book.
    struct Document: Sendable, Hashable {
        /// The file name without the `.md` suffix (= the name a wiki
        /// link carries: `[[核心设定]]`).
        let name: String
        /// The path relative to the book root (= `world/核心设定.md`).
        /// This is the link id (= stable, and it says which folder
        /// the document lives in).
        let relativePath: String
        /// Where the document sits on disk.
        let url: URL
    }

    /// The book's root (= the folder that holds `world/`, `characters/`,
    /// …). Nil when no book is open.
    let bookDirectory: URL?

    /// Every document in the book (= one folder scan).
    let documents: [Document]

    init(bookDirectory: URL?) {
        self.bookDirectory = bookDirectory
        self.documents = bookDirectory.map(Self.scan) ?? []
    }

    /// Read every `.md` document in the book's folders.
    static func scan(bookDirectory: URL) -> [Document] {
        var found: [Document] = []
        for spec in BookFolderCatalog.allBookFolders {
            let folder = bookDirectory
                .appendingPathComponent(spec.directoryName, isDirectory: true)
            let entries = (try? FileManager.default
                .contentsOfDirectory(atPath: folder.path)) ?? []
            for entry in entries.sorted() where entry.hasSuffix(".md") {
                found.append(Document(
                    name: String(entry.dropLast(".md".count)),
                    relativePath: "\(spec.directoryName)/\(entry)",
                    url: folder.appendingPathComponent(entry)
                ))
            }
        }
        return found
    }

    /// The document a link names.
    ///
    /// The name may or may not carry the `.md` suffix (= `核心设定` and
    /// `核心设定.md` are the same document), and the match ignores
    /// case (= the file system is case-insensitive on the target
    /// platform, so the link should be too).
    func document(named name: String) -> Document? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let wanted = trimmed.hasSuffix(".md")
            ? String(trimmed.dropLast(".md".count))
            : trimmed
        return documents.first {
            $0.name.caseInsensitiveCompare(wanted) == .orderedSame
        }
    }

    /// The document a link id names (= the relative path).
    func document(withID id: String) -> Document? {
        documents.first { $0.relativePath == id }
    }

    /// A coarse fingerprint of the book's documents (= the engine
    /// restyles the wiki links when this changes, so a new document
    /// becomes clickable without waiting for the next keystroke).
    var fingerprint: Int {
        var hasher = Hasher()
        hasher.combine(documents.map(\.relativePath))
        return hasher.finalize()
    }
}
