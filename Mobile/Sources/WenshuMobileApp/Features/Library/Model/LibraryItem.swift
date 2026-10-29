/// A shelf the Mac reported: the books that sit on it.
///
/// The Mac owns the library, so these are a projection of it: the names
/// the Mac sends and the counts it reports, and nothing the device
/// invents.
struct LibraryShelf: Identifiable, Equatable, Sendable {
    /// The Mac's identifier for the shelf.
    let id: String
    /// The shelf's name, as the Mac spells it.
    let name: String
    /// The books on the shelf.
    let books: [LibraryBook]
}

/// A book on a shelf.
struct LibraryBook: Identifiable, Equatable, Sendable {
    /// The Mac's identifier for the book.
    let id: String
    /// The book's title, as the Mac spells it.
    let title: String
    /// The chapters inside the book.
    let chapters: [LibraryChapter]
}

/// A chapter inside a book.
struct LibraryChapter: Identifiable, Equatable, Sendable {
    /// The Mac's identifier for the chapter.
    let id: String
    /// The chapter's title, as the Mac spells it.
    let title: String
    /// How many words the chapter holds.
    let wordCount: Int
}
