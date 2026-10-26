// Sources/WenshuApp/Features/Editor/Model/BookAwareWikiLinkResolver.swift
//
// A wiki-link resolver that knows the open book's own documents as
// well as the reference library.
//
// Why this exists: the engine turns a wiki link into a clickable
// link only when the resolver says the target exists. A link into
// the book (= the index an import writes: `[[核心设定]]`) used to
// have no answer, = so it stayed grey, = and the click never
// reached the app. A markdown link is worse: the engine rewrites
// its target to `https://<target>` and hands it to the browser.
//
// The reference library keeps its own resolver; this type sits in
// front of it, so a library link behaves exactly as before and a
// book link resolves too.

import Foundation
import MarkdownEngine

struct BookAwareWikiLinkResolver: WikiLinkResolver {

    /// The library resolver (= the fallback for library links).
    private let library: any WikiLinkResolver

    /// The open book's documents.
    private let index: BookDocumentIndex

    init(library: any WikiLinkResolver, bookDirectory: URL?) {
        self.library = library
        self.index = BookDocumentIndex(bookDirectory: bookDirectory)
    }

    func resolve(displayName: String, range: NSRange) -> WikiLinkResolution? {
        if let document = index.document(named: displayName) {
            return WikiLinkResolution(id: document.relativePath, exists: true)
        }
        return library.resolve(displayName: displayName, range: range)
    }

    func name(forID id: String) -> String? {
        if let document = index.document(withID: id) {
            return document.name
        }
        return library.name(forID: id)
    }

    /// A change in either source (= a new document, a renamed one)
    /// restyles the links, so a link that just came to life is
    /// clickable right away.
    func fingerprint() -> AnyHashable {
        var hasher = Hasher()
        hasher.combine(index.fingerprint)
        hasher.combine(library.fingerprint())
        return hasher.finalize()
    }
}
