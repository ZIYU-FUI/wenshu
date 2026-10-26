// Sources/WenshuApp/Features/Editor/View/LinkedDocumentBoardSection.swift
//
// The board of documents an index points at, = the reading view of a
// document that lists other documents.
//
// The boss (2026-10-26): the index's link list read as plain text;
// = the app has a document card, = so the list is cards now. This
// view finds the documents the body links to and lays them out in
// the app's own card (= the picture), several on one row.

import SwiftUI

struct LinkedDocumentBoardSection: View {

    @Environment(BookStore.self) private var bookStore

    /// The body of the document being read.
    let documentBody: String

    /// Opens one of the documents on the board.
    let onOpen: (BookDoc) -> Void

    @State private var documents: [BookDoc] = []

    /// The names the body links to (= the board's rows).
    private var linkedNames: [String] {
        DocumentLinkIndex.linkedNames(in: documentBody)
    }

    var body: some View {
        Group {
            if !documents.isEmpty {
                LinkedDocumentCardBoard(documents: documents, onOpen: onOpen)
                    .padding(.horizontal, DesignTokens.spacingModerate)
                    .padding(.vertical, DesignTokens.spacingModerate)
            }
        }
        .task(id: loadKey) {
            load()
        }
    }

    /// Load the documents the body names (= once per body, = not per
    /// body re-evaluation).
    private func load() {
        let names = linkedNames
        guard !names.isEmpty else {
            documents = []
            return
        }
        guard let bookId = bookStore.currentBook?.bookId else {
            documents = []
            return
        }
        let loaded = PreviewPaneOps.loadBookDocs(
            bookStore: bookStore,
            bookId: bookId,
            folderName: nil
        ).docs
        // The link names the file (= "核心设定.md"); the card's title
        // is the file name without the extension.
        documents = loaded.filter { doc in
            names.contains(doc.title) || names.contains(doc.fileName)
        }
    }

    /// The key the load hangs on (= the names, = so a new link
    /// reloads the board).
    private var loadKey: String {
        linkedNames.joined(separator: "|")
    }
}
