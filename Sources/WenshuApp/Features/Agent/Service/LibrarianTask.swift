//
//  LibrarianTask.swift · Wenshu
//
//  What the librarian is asked to do.
//
//  The librarian is not a chat partner and not a roaming agent. It is
//  a procedure runner: = a named procedure, = a task that says what
//  to work on, = a result that says what landed. The three pieces are
//  here, and they are here as VALUES (= not as a prompt the model is
//  asked to interpret), = because "the agent works on the library"
//  is not a task, = and a task the model has to infer from a paragraph
//  of prose is a task that runs differently every time.
//
//  The scope is deliberately narrow: = the documents already in the
//  library and the documents about to enter it. = The librarian does
//  not search the open web (= the researcher's job), = does not write
//  prose (= the writer's job), = and does not decide what the book
//  says (= the user's job).
//

import Foundation

/// The procedure the librarian runs.
///
/// A procedure, not a conversation: = the user names one, = the run
/// executes it, = the result says what happened. Two procedures, = two
/// jobs the library actually has.
enum LibrarianProcedure: String, Sendable, Equatable, CaseIterable {
    /// Take a document into the library.
    ///
    /// Reads the source, splits it per the import procedure, writes
    /// the parts into the library, = and indexes them.
    case importDocuments = "import"

    /// Tidy the library.
    ///
    /// Looks at what is already there and reports what needs a
    /// decision: = duplicates, = orphans, = stale entries. It
    /// reports; = it does not delete, = because a document the user
    /// kept is the user's document.
    case curate = "curate"
}

/// One librarian request.
///
/// Every field is explicit, = because the procedure has to run the
/// same way twice: = the same request twice must land the same way
/// twice.
struct LibrarianTask: Sendable, Equatable {
    /// Which procedure to run.
    let procedure: LibrarianProcedure

    /// The request's identity (= the idempotency key).
    ///
    /// The same key twice runs the same work against the same
    /// documents, = so a retry after a failure does not land the
    /// document twice.
    let requestID: String

    /// Where the documents come from.
    ///
    /// Empty for `curate` (= it works on what is already there).
    let sourcePaths: [String]

    /// The library scope the work is confined to.
    ///
    /// Nil = the whole library. A scope is what keeps the librarian
    /// from touching documents outside the job.
    let scope: LibrarianScope?

    /// Whether the run reports what it would do without doing it.
    ///
    /// The dry run is the one that makes the procedure safe to
    /// rehearse: = the user sees the plan, = then runs it for real.
    let dryRun: Bool

    init(
        procedure: LibrarianProcedure,
        requestID: String,
        sourcePaths: [String] = [],
        scope: LibrarianScope? = nil,
        dryRun: Bool = false
    ) {
        self.procedure = procedure
        self.requestID = requestID
        self.sourcePaths = sourcePaths
        self.scope = scope
        self.dryRun = dryRun
    }
}

/// What the librarian works on.
///
/// The library's two places a document can live, = and the scope
/// bounds are the folder's, = because that is where the documents
/// actually are.
enum LibrarianScope: Sendable, Equatable {
    /// The reference library (= the corpus the user browses).
    case referenceLibrary
    /// One book's folder (= `world`, `characters`, `chapters`, = …).
    case bookFolder(bookID: UUID, folder: String)
}

/// What one librarian run produced.
///
/// The result answers the questions the user has after the run: = what
/// landed, = where, = what was already there, = what went wrong. A
/// run that produced nothing says so, = and says why, = rather than
/// returning an empty success.
struct LibrarianResult: Sendable, Equatable {
    /// The documents that landed (= their library ids).
    let documentIDs: [UUID]

    /// The documents that were already there (= the deduplication
    /// report).
    let duplicateTitles: [String]

    /// The layer each document landed in.
    let layers: [UUID: String]

    /// Whether the index was updated for the documents.
    let indexed: Bool

    /// The archive target (= where the run's snapshot went).
    let archiveTarget: String?

    /// The failure, = when the run did not finish.
    let errorMessage: String?

    /// A run that did nothing, = with the reason.
    ///
    /// A dry run, = a task with no scope, = a request that had
    /// already been served: = these are not failures, = and they are
    /// not silent successes either.
    let skipped: String?

    init(
        documentIDs: [UUID] = [],
        duplicateTitles: [String] = [],
        layers: [UUID: String] = [:],
        indexed: Bool = false,
        archiveTarget: String? = nil,
        errorMessage: String? = nil,
        skipped: String? = nil
    ) {
        self.documentIDs = documentIDs
        self.duplicateTitles = duplicateTitles
        self.layers = layers
        self.indexed = indexed
        self.archiveTarget = archiveTarget
        self.errorMessage = errorMessage
        self.skipped = skipped
    }

    /// Whether the run landed anything.
    var landedAnything: Bool {
        !documentIDs.isEmpty
    }
}
