//
//  ReferenceLayerMembership.swift
//
//  Who is IN a layer.
//
//  **⇒ The corpus's membership was the INDEX, = and the index is one
//  of TWO writes.** = The body is written by `ReferenceBodyStore.write`
//  (= the truth, = then the ownership record, = then the mirror), = and
//  the index by `writeIndexToFileSystem`. = `AtomicFileWrite` makes
//  EACH one atomic, = **⇒ but the PAIR is not.** = A crash between
//  them leaves a body on disk that the index does not list.
//
//  **⇒ And the consequence was a LIE, = and the same shape as the one
//  the corpus-unreadable fix just closed, = one step further out.**
//  = The corpus was READABLE (= so the strict read did not help),
//  = and the report said **"NOT in the library, = so it did not
//  land"** about a document that was sitting there.
//
//  **⇒ So membership is now read from what is ON DISK.** = A layer's
//  members are the documents whose bodies are in it, = plus the rows
//  the index holds (= the index carries the METADATA, = and the
//  metadata is worth keeping even when the body is gone).
//
//  **⇒ And a document with no metadata is still a MEMBER.** = The
//  corpus's own identity rule reads a body's first H1 as its title
//  (`FileSystemLibraryStore.extractTitle`), = so a body on disk names
//  itself. = What is NOT knowable is its kind, = its tags, = its
//  category, = and its summary: = those live in the index row that
//  was lost, = and **⇒ this type does not invent them** (= `.other`
//  and empty, = which is what the model's own decode fallback uses for
//  a row whose kind it cannot read).
//
//  **⇒ And the WRITERS are not affected.** = A writer rewrites the
//  index from the index's own rows, = so a recovered member never
//  becomes a permanent index row with invented metadata. = **⇒ The
//  membership read and the index read are two different questions, =
//  and this type is the answer to only one of them.**
//
//  **⇒ And the scan does not read the bodies it does not need.** = The
//  corpus's UI read runs on every library change, = so reading every
//  body's text on that path would make the sidebar slower for a
//  library of any size. = **⇒ Only the bodies the index does NOT list
//  are read** (= the crash window, = which is empty in a healthy
//  library), = and the rest are recognised by their FILENAME alone.
//

import Foundation

/// A layer's members.
enum ReferenceLayerMembership {
    /// The documents a layer holds.
    ///
    /// - Parameters:
    ///   - indexRows: The layer's index rows (= the metadata the
    ///     index holds; = the index is NOT the membership, = it is the
    ///     metadata).
    ///   - layer: The layer being read.
    ///   - referenceLibraryRoot: The corpus root (= the layer
    ///     directory is under it).
    /// - Returns: The index rows, = plus one row per body the layer
    ///   holds and the index does not list (= the crash window).
    static func members(
        indexRows: [Reference],
        layer: ReferenceLayer,
        referenceLibraryRoot: URL
    ) -> [Reference] {
        let listed = Set(indexRows.map(\.id))
        let unlisted = bodiesOnDisk(
            layer: layer,
            referenceLibraryRoot: referenceLibraryRoot
        )
        .filter { !listed.contains($0.id) }
        guard !unlisted.isEmpty else { return indexRows }
        let recovered = unlisted.compactMap { recoveredReference(for: $0, layer: layer) }
        guard !recovered.isEmpty else { return indexRows }
        return indexRows + recovered
    }

    /// One body the layer holds on disk.
    private struct BodyOnDisk {
        /// The document's id (= the filename's UUID).
        let id: UUID

        /// The body's file (= read only when the body has to become a
        /// member, = and the corpus's UI read does not need it for the
        /// bodies the index already lists).
        let url: URL

        /// When the body was last written (= the dates a lost index
        /// row cannot carry).
        let modifiedAt: Date
    }

    /// The bodies in a layer's directory.
    ///
    /// **⇒ The filename is the id** (= `<uuid>.md`, = the layout the
    /// store writes), = so a body with a name that is not a UUID is
    /// not a document (= it is a file the user dropped in, = and it
    /// must not become a corpus member with a made-up identity).
    ///
    /// **⇒ The scan is RECURSIVE** (= the legacy layout put bodies in
    /// `entities/<category>/<uuid>.md`, = and that layout still
    /// exists on disk), = and it takes only `.md` files (= the index
    /// itself is a `.json`).
    private static func bodiesOnDisk(
        layer: ReferenceLayer,
        referenceLibraryRoot: URL
    ) -> [BodyOnDisk] {
        let directory = referenceLibraryRoot
            .appendingPathComponent(layer.directoryName, isDirectory: true)
        guard let walker = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var bodies: [BodyOnDisk] = []
        for case let url as URL in walker where url.pathExtension == "md" {
            // **⇒ The corpus's OWN rule says whether a filename is a
            // document's** (= `documentIdFromFilename`), = so this
            // reader and the corpus's reader cannot disagree about
            // what a document is.
            guard let id = FileSystemLibraryStore.documentIdFromFilename(
                url.lastPathComponent
            ) else { continue }
            let modified = (try? url.resourceValues(
                forKeys: [.contentModificationDateKey]
            ))?.contentModificationDate ?? Date(timeIntervalSince1970: 0)
            bodies.append(BodyOnDisk(id: id, url: url, modifiedAt: modified))
        }
        return bodies
    }

    /// The reference a body names itself.
    ///
    /// **⇒ The title is the body's own first H1** (= the corpus's
    /// existing rule, = `extractTitle`, = with the filename's UUID as
    /// the fallback). = **⇒ The kind, = the tags, = and the category
    /// are NOT invented** (= `.other` and empty), = because a lost index
    /// row means they are unknown, = and a document filed under a kind
    /// nobody chose is a worse lie than one filed under "other".
    private static func recoveredReference(
        for body: BodyOnDisk,
        layer: ReferenceLayer
    ) -> Reference? {
        guard let text = try? String(contentsOf: body.url, encoding: .utf8) else {
            return nil
        }
        let title = FileSystemLibraryStore.extractTitle(
            from: text,
            fallback: body.id.uuidString
        )
        return Reference(
            id: body.id,
            title: title,
            layer: layer,
            entityType: .other,
            createdAt: body.modifiedAt,
            updatedAt: body.modifiedAt
        )
    }
}
