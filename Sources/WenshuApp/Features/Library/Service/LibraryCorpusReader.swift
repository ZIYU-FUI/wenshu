//
//  LibraryCorpusReader.swift
//
//  Reads the reference library's corpus, = and says which corpus.
//
//  **⇒ This type exists because the check was inverted.** = The first
//  version of the librarian's corpus check built its store from
//  `ActiveLibrary.path`, = which is the `.ws` ROOT, = while the corpus
//  lives one directory deeper (= `<ws>/reference-library/`). = Against
//  a real library: = six documents at the right root, = zero at the
//  root the reader used. = **⇒ Every librarian run said "NOT in the
//  library, so it did not land" about a document that had landed.**
//
//  **⇒ And the mutation that FIXED the root left every suite green.**
//  = The old test checked that a reader is HANDED, = never that it
//  reads the right place. = A reader can be handed correctly and
//  still point at the wrong directory. = **⇒ So the reader is now a
//  value with a seam, = and the seam is where the test measures it.**
//
//  Two rules, = and each one has a test:
//
//  1. **The default reader reads the store the launch sequence bound**
//  (= `ReferenceLibraryLocator.shared.referenceStore`), = and not a
//  store built from a path. = The locator is the ONE place that knows
//  where the corpus is, = and a reader that assembles its own store
//  from a path can point somewhere else. = **⇒ The default is the
//  seam a mutation has to break, = and the test catches it there.**
//  2. **A corpus that could not be read is reported as unreadable**,
//  = and not as an empty corpus. = The two are different facts, = and
//  a check that cannot tell them apart says "it did not land" about a
//  document it never looked for.
//

import Foundation

/// Reads the corpus the user has open.
@MainActor
struct LibraryCorpusReader {
    /// Where the corpus comes from.
    ///
    /// The default is the locator's store. = It is a closure (= not a
    /// stored store), = so a read picks up the library the user has
    /// open NOW (= the user can switch libraries between two reads).
    let storeProvider: @MainActor () -> (any ReferenceStoring)?

    init(
        storeProvider: @escaping @MainActor () -> (any ReferenceStoring)? = {
            ReferenceLibraryLocator.shared.referenceStore
        }
    ) {
        self.storeProvider = storeProvider
    }

    /// Read the corpus.
    func read() -> LibraryCorpusRead {
        guard let store = storeProvider() else {
            return .unreadable("no library is open")
        }
        do {
            return try .documents(store.loadAllReferences())
        } catch {
            return .unreadable(String(describing: error))
        }
    }
}
