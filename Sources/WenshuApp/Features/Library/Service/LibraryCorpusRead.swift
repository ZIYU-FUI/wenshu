//
//  LibraryCorpusRead.swift
//
//  What one read of the corpus found.
//
//  Why this type exists: = a check that says "the library does not
//  hold this document" is only true if the library WAS READ. = A
//  reader that returns an empty list when it could not read the
//  library makes those two facts the same fact, = and then the
//  check says "it did not land" about a document that is sitting in
//  the corpus. = **⇒ The two have to be different values, = or the
//  check cannot tell them apart.** = This type is that difference.
//
//  Why it matters in production: = the first version of this check
//  read the corpus at the `.ws` ROOT, = while the corpus lives one
//  directory deeper (= `<ws>/reference-library/`). = Measured against
//  a real library: = six documents at the right root, = zero at the
//  root the reader used. = **⇒ Every librarian run said "NOT in the
//  library, so it did not land" about a document that had landed.**
//  The check was inverted, = and the check is the whole feature.
//
//  ⇒ So the reader also says WHICH corpus it read. = A check that
//  names the directory it looked in is a check a reader can audit,
//  = and a check that names it cannot silently point somewhere else.
//

import Foundation

/// One read of the reference library's corpus.
enum LibraryCorpusRead: Sendable, Equatable {
    /// The corpus was read.
    ///
    /// The documents are what the corpus holds. = An EMPTY list here
    /// is a fact (= the corpus is empty), = and it is different from
    /// `.unreadable`.
    case documents([Reference])

    /// The corpus could not be read.
    ///
    /// - Parameter reason: why, = in the words the user would use.
    ///   = A reason the user can act on (= "no library is open", =
    ///   "the library moved") = beats "it failed".
    case unreadable(String)

    /// The documents the corpus holds (= empty when it could not be
    /// read, = and the caller has to look at the case to tell).
    var documents: [Reference] {
        switch self {
        case let .documents(references): return references
        case .unreadable: return []
        }
    }

    /// Whether the corpus was read at all.
    var wasRead: Bool {
        if case .documents = self {
            return true
        }
        return false
    }

    /// The text the user reads when the corpus could not be read.
    ///
    /// **⇒ This is NOT the same text as "the library does not hold
    /// it".** = One is a fact about the corpus; = the other is a fact
    /// about the check, = and a check that could not run must say so
    /// instead of reporting a result it never got.
    var unreadableNotice: String {
        switch self {
        case .documents:
            return ""
        case let .unreadable(reason):
            return "The library could not be read, = so this report was NOT checked against it. (\(reason))"
        }
    }
}
