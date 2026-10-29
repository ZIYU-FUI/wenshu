import Foundation
import SwiftUI

// The library the Mac reported: the shelves, the books on them and the
// chapters inside each book.
//
// The outline reads through the store, so it does not care whether the
// outline came from the link or from the fixture.
//
// The file also carries the two screens the outline pushes: the chapters
// of one book and the books of one shelf.

/// The outline the Library tab draws.
struct LibraryOutlineView: View {
    /// The store the outline comes from.
    @State private var store: any LibraryStore
    /// What the app knows about the library the Mac sent.
    @State private var state: LibraryState = .notYet

    /// How many books one shelf shows before it offers the rest.
    private static let booksShown = 5

    /// The shelves the reader closed again.
    ///
    /// A shelf is open when the app opens it: the outline is the screen
    /// a person came for, so its books are on it without a tap. The set
    /// holds the shelves the reader closed.
    @State private var closedShelves: Set<String> = []

    /// The outline the app draws, read through the link.
    init(link: ConnectionStore) {
        _store = State(initialValue: LinkLibraryStore(link: link))
    }

    /// The outline a caller supplies.
    ///
    /// A preview and a test hand over a store of their own, so the
    /// outline draws what they hold.
    init(store: any LibraryStore) {
        _store = State(initialValue: store)
    }

    var body: some View {
        Group {
            switch state {
            case .notYet:
                LibraryEmptyState()
            case .loaded(let shelves):
                outline(shelves)
            }
        }
        .task { await load() }
        .navigationDestination(for: ChapterID.self) { chapterID in
            ChapterReaderView(chapterID: chapterID, store: store)
        }
    }

    /// The shelves the Mac reported.
    ///
    /// Each shelf is a section of the list, and the section's header
    /// carries the shelf's name the way the system's headers do. The
    /// books sit in a disclosure group, so the reader opens the shelf
    /// or closes it, and a shelf holding more books than the group
    /// shows gets the see-all row: a navigation link, so the chevron
    /// beside it is the system's.
    private func outline(_ shelves: [LibraryShelf]) -> some View {
        List {
            ForEach(shelves) { shelf in
                Section {
                    DisclosureGroup(isExpanded: openness(of: shelf)) {
                        ForEach(shelf.books.prefix(Self.booksShown)) { book in
                            NavigationLink {
                                LibraryChaptersView(book: book)
                            } label: {
                                Text(book.title)
                            }
                        }
                    } label: {
                        SFIcon.library
                            .accessibilityLabel(Text(shelf.name))
                    }
                    if shelf.books.count > Self.booksShown {
                        NavigationLink {
                            LibraryShelfView(shelf: shelf)
                        } label: {
                            Text("See All")
                        }
                    }
                } header: {
                    Text(shelf.name)
                }
            }
        }
        .navigationTitle("Library")
    }

    /// Whether a shelf's group is open, and the binding that opens and
    /// closes it.
    private func openness(of shelf: LibraryShelf) -> Binding<Bool> {
        Binding(
            get: { !closedShelves.contains(shelf.id) },
            set: { isOpen in
                if isOpen {
                    closedShelves.remove(shelf.id)
                } else {
                    closedShelves.insert(shelf.id)
                }
            }
        )
    }

    /// Asks the store for the outline.
    private func load() async {
        do {
            _ = try await store.outline()
            state = store.state
        } catch {
            state = .notYet
        }
    }
}

/// The chapters of one book, each with its word count beside it.
struct LibraryChaptersView: View {
    /// The book whose chapters this is.
    let book: LibraryBook

    var body: some View {
        List {
            ForEach(book.chapters) { chapter in
                NavigationLink(value: ChapterID(id: chapter.id)) {
                    LabeledContent(chapter.title) {
                        words(chapter)
                    }
                }
            }
        }
        .navigationTitle(book.title)
    }

    /// The chapter's word count, with the unit the reader counts in.
    ///
    /// The count is the Mac's, and the unit says what it counts, so a
    /// number on its own is not read as pages.
    @ViewBuilder
    private func words(_ chapter: LibraryChapter) -> some View {
        if chapter.wordCount == 1 {
            Text("1 word")
        } else {
            Text("\(chapter.wordCount.formatted()) words")
        }
    }
}

/// Every book of one shelf.
struct LibraryShelfView: View {
    /// The shelf whose books this is.
    let shelf: LibraryShelf

    var body: some View {
        List {
            ForEach(shelf.books) { book in
                NavigationLink {
                    LibraryChaptersView(book: book)
                } label: {
                    Text(book.title)
                }
            }
        }
        .navigationTitle(shelf.name)
    }
}

#if DEBUG
#Preview("Library") {
    NavigationStack {
        LibraryOutlineView(store: FixtureLibraryStore())
    }
}
#endif
