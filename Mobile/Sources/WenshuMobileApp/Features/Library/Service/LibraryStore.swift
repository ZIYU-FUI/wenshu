import Observation
import WenshuMobileKit

// The boundary the library views read through.
//
// A view asks for an outline and gets one; where the outline came from
// is the store's business, not the view's.
//
// This file carries the protocol, the store the app reads through, the
// seam the transport plugs into, and the fixture. THE FIXTURE IS
// COMPILED ONLY INTO A DEBUG BUILD: it sits inside `#if DEBUG`, so a
// release build of the app carries neither the type nor any path to it,
// and only a test build or a preview can reach it.

/// What the app knows about the library the Mac sends.
///
/// The Mac owns the library, so the device reads a projection of it. A
/// library that has not arrived yet is a state of the app, not a
/// failure of the link.
enum LibraryState: Equatable, Sendable {
    /// The Mac has sent no library yet.
    case notYet
    /// The Mac sent an outline: the shelves, their books and chapters.
    case loaded([LibraryShelf])
}

/// The boundary the library views read through.
///
/// The view asks for an outline and gets one. The per-book detail the
/// chapter reader needs joins this protocol with the reader.
@MainActor
protocol LibraryStore {
    /// What the app knows about the library right now.
    var state: LibraryState { get }
    /// The outline the Mac reported: the shelves, their books and the
    /// chapters in each book.
    func outline() async throws -> [LibraryShelf]
}

/// The channel the library store sends its commands through.
///
/// The client has no socket yet: the transport that will carry the
/// command arrives with the link. Until then the store reports that no
/// library has arrived.
protocol LinkTransport: Sendable {
    /// Sends one command to the Mac and returns the outline it answers.
    func send(_ command: LinkCommand) async throws -> [LibraryShelf]
}

/// The library the app reads: the outline comes from the Mac over the link.
///
/// The store holds the state and the transitions; it does not open a
/// socket. A transport that exists later replaces the channel and
/// nothing else.
@MainActor
@Observable
final class LinkLibraryStore: LibraryStore {
    /// What the app knows about the library right now.
    private(set) var state: LibraryState = .notYet

    /// The link the store reads through.
    private let link: ConnectionStore
    /// The channel the outline comes through.
    private let transport: (any LinkTransport)?

    init(link: ConnectionStore, transport: (any LinkTransport)? = nil) {
        self.link = link
        self.transport = transport
    }

    /// The outline the Mac reported.
    ///
    /// A Mac that has sent no library is a state of the app, not an
    /// error: the outline comes back empty and the state says so.
    func outline() async throws -> [LibraryShelf] {
        guard link.state.canReadLibrary, let transport else {
            state = .notYet
            return []
        }
        let command = LinkCommand(
            kind: .listChapters,
            identifier: Self.libraryIdentifier,
            baseRevision: link.state.companion?.revision ?? 0
        )
        let shelves = try await transport.send(command)
        state = shelves.isEmpty ? .notYet : .loaded(shelves)
        return shelves
    }

    /// The identifier the library-wide listing travels under.
    ///
    /// The Mac's library route is `/v1/library`, so the listing that
    /// asks for every shelf names that route.
    private static let libraryIdentifier = "library"
}

#if DEBUG
/// The fixture library: a fixed outline for previews and tests.
///
/// The type is compiled only into a debug build, so the shipped app
/// cannot reach it.
@MainActor
@Observable
final class FixtureLibraryStore: LibraryStore {
    /// What the app knows about the library right now.
    private(set) var state: LibraryState = .loaded(FixtureLibraryStore.sample)

    /// The fixed outline the fixture serves.
    static let sample: [LibraryShelf] = [
        LibraryShelf(
            id: "shelf-fiction",
            name: "Fiction",
            books: [
                LibraryBook(
                    id: "book-tide",
                    title: "The Long Tide",
                    chapters: [
                        LibraryChapter(id: "chapter-harbour", title: "The Harbour", wordCount: 3120),
                        LibraryChapter(id: "chapter-ferry", title: "Night Ferry", wordCount: 2480)
                    ]
                )
            ]
        ),
        LibraryShelf(
            id: "shelf-notes",
            name: "Notes",
            books: [
                LibraryBook(
                    id: "book-ledger",
                    title: "The Ledger",
                    chapters: [
                        LibraryChapter(id: "chapter-entries", title: "Entries", wordCount: 980)
                    ]
                )
            ]
        )
    ]

    /// The fixed outline.
    func outline() async throws -> [LibraryShelf] { Self.sample }
}
#endif
