//
//  ReferenceBodyStore.swift
//
//  Where a reference's body lives, = and the ONE place that answers.
//
//  **⇒ The corpus had two truths, = and they were both written.**
//
//  - `<ws>/reference-library/<layer>/<uuid>.md` = the layer copy.
//  - `<ws>/references/<uuid>.md` = the single-file copy
//    (= `referenceFileURL`, = the location the 2026-10-14
//    "doc-truth-git" ticket named, = and the one the editor's
//    auto-save writes).
//
//  Measured against the user's real library: = **six documents, = six
//  divergent pairs** (= every one of them), = `references/` newer in
//  every case, = and one of them differing in CONTENT (= the user
//  edited it in the editor). = The other five differ only by a
//  leading newline.
//
//  **⇒ The three ways that divergence bites:**
//
//  1. **The agent's write is invisible.** = In production the store
//     has no SwiftData container, = so the write path writes the
//     LAYER copy, = while the read path prefers the single-file copy.
//     **⇒ A document the agent just wrote reads back as the older
//     text.**
//  2. **A deleted document's body stays on disk.** = The delete path
//     removes the layer copy, = and the single-file copy survives.
//  3. **The search index is stale.** = The index is scheduled from
//     the write path, = and the editor's auto-save does not schedule
//     one. = So a document the user edited is searchable by its old
//     words.
//
//  **⇒ The rule.** = `references/<uuid>.md` is the TRUTH. = The layer
//  copy is a MIRROR: = written whenever the truth is written, = so
//  the two cannot drift, = and read only when the truth is absent
//  (= a library that predates the truth location). = One place
//  answers "where is this body", = so the three paths cannot each
//  pick their own.
//

import Foundation

/// Where a reference's body lives.
enum ReferenceBodyStore {
    /// The truth location for one document.
    ///
    /// = `<ws>/references/<uuid>.md`. = This is the location the
    /// editor's auto-save writes, = the location the read path
    /// prefers, = and the location the doc-truth ticket named.
    nonisolated static func truthURL(
        id: UUID,
        referenceLibraryRoot: URL
    ) -> URL {
        referenceLibraryRoot
            .deletingLastPathComponent()
            .appendingPathComponent("references", isDirectory: true)
            .appendingPathComponent("\(id.uuidString).md", isDirectory: false)
    }

    /// The mirror location for one document.
    ///
    /// = `<ws>/reference-library/<layer>/<uuid>.md`. = It is written
    /// whenever the truth is written, = so a reader that walks the
    /// layer directories sees the current text.
    nonisolated static func mirrorURL(
        id: UUID,
        layer: ReferenceLayer,
        referenceLibraryRoot: URL
    ) -> URL {
        referenceLibraryRoot
            .appendingPathComponent(layer.directoryName, isDirectory: true)
            .appendingPathComponent("\(id.uuidString).md", isDirectory: false)
    }

    /// Read a body, = truth first.
    ///
    /// The mirror is the fallback, = and only when the truth is
    /// ABSENT. = A mirror that is present but older is not read: = the
    /// truth is the truth, = and the mirror is written beside it.
    nonisolated static func read(
        id: UUID,
        layer: ReferenceLayer,
        referenceLibraryRoot: URL
    ) -> String? {
        let truth = truthURL(id: id, referenceLibraryRoot: referenceLibraryRoot)
        if let body = try? String(contentsOf: truth, encoding: .utf8) {
            return body
        }
        let mirror = mirrorURL(id: id, layer: layer, referenceLibraryRoot: referenceLibraryRoot)
        return try? String(contentsOf: mirror, encoding: .utf8)
    }

    /// Write a body, = to the truth and to the mirror.
    ///
    /// Both are written because the two are read by different readers,
    /// and a reader that finds one of them must find the current text.
    /// **⇒ The write is one operation, = so the two cannot drift.**
    nonisolated static func write(
        id: UUID,
        layer: ReferenceLayer,
        bodyMarkdown: String,
        referenceLibraryRoot: URL
    ) throws {
        let truth = truthURL(id: id, referenceLibraryRoot: referenceLibraryRoot)
        try FileManager.default.createDirectory(
            at: truth.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try AtomicFileWrite.write(
            bodyMarkdown.data(using: .utf8) ?? Data(),
            to: truth
        )

        let mirror = mirrorURL(id: id, layer: layer, referenceLibraryRoot: referenceLibraryRoot)
        try FileManager.default.createDirectory(
            at: mirror.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try AtomicFileWrite.write(
            bodyMarkdown.data(using: .utf8) ?? Data(),
            to: mirror
        )
    }

    /// Write ONLY the mirror.
    ///
    /// **⇒ This is the editor's path.** = The editor writes the truth
    /// location itself (= `tab.documentPath`), = and it does not know
    /// the document's layer, = so it cannot write the mirror. = The
    /// store knows the layer, = so the store writes it. = **⇒ The
    /// truth file is NOT rewritten here**: = the editor may have a
    /// watcher on it, = and rewriting a file the editor just wrote
    /// can trigger a reload it does not need.
    nonisolated static func writeMirror(
        id: UUID,
        layer: ReferenceLayer,
        bodyMarkdown: String,
        referenceLibraryRoot: URL
    ) throws {
        let mirror = mirrorURL(id: id, layer: layer, referenceLibraryRoot: referenceLibraryRoot)
        try FileManager.default.createDirectory(
            at: mirror.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try AtomicFileWrite.write(
            bodyMarkdown.data(using: .utf8) ?? Data(),
            to: mirror
        )
    }

    /// Remove a body, = from both locations.
    ///
    /// **⇒ A delete that leaves the body on disk is not a delete.**
    nonisolated static func remove(
        id: UUID,
        layer: ReferenceLayer,
        referenceLibraryRoot: URL
    ) {
        for url in [
            truthURL(id: id, referenceLibraryRoot: referenceLibraryRoot),
            mirrorURL(id: id, layer: layer, referenceLibraryRoot: referenceLibraryRoot),
        ] where FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
