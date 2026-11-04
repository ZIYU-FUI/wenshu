//
//  LibraryFullTextSearchTests.swift
//
//  The library's full-text search, and where it is wired.
//
//  Two halves, held separately on purpose:
//
//  1. The SEARCH ITSELF (= `ReferenceLibrarySearchTests` holds the
//     matching rules; = this file holds only the wiring).
//
//  2. The WIRING. The search reads files, and a file read on the
//     main actor while the user types is a frozen app. So the
//     contract is measured by reading the source: the search runs in
//     a detached task keyed on the query, and the view body does no
//     reading at all. A search that is correct but blocks the app
//     is not a search the user can use.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("The library's full-text search wiring")
struct LibraryFullTextSearchTests {
    /// The source of the view that shows the hits.
    private static var viewSource: String {
        readRepoFile("Sources/WenshuApp/Features/Library/View/LibraryFullTextSearchView.swift")
    }

    /// The source of the scope view that shows the hits.
    private static var scopeSource: String {
        readRepoFile("Sources/WenshuApp/Features/Editor/View/PreviewPaneScopeViews.swift")
    }

    /// Read one file out of the repository.
    private static func readRepoFile(_ relativePath: String) -> String {
        var url = SourceLocator.repoRoot
        url.appendPathComponent(relativePath)
        return (try? String(contentsOfFile: url.path, encoding: .utf8)) ?? ""
    }

    // MARK: - The scope shows the hits

    @Test("The reference scope shows the library's full-text hits")
    func scopeShowsTheHits() {
        #expect(Self.scopeSource.contains("LibraryFullTextSearchView("))
    }

    @Test("The scope passes the search field's text to the hits")
    func scopePassesTheQuery() {
        #expect(Self.scopeSource.contains("query: resolvedSearchQuery"))
    }

    @Test("A hit opens the document it names")
    func hitOpensTheDocument() {
        #expect(Self.scopeSource.contains("onOpen: { reference in"))
        #expect(Self.scopeSource.contains("onDoubleClick(.reference(reference))"))
    }

    // MARK: - The search does not freeze the app

    @Test("The search runs off the main actor, keyed on the query")
    func searchRunsDetachedAndKeyed() {
        let source = Self.viewSource
        #expect(source.contains(".task(id: query)"))
        #expect(source.contains("Task.detached"))
    }

    @Test("The view body reads no document (= the reading happens off the main actor)")
    func bodyReadsNothing() {
        // The body is everything before the search function; a file
        // read there would be on the main actor, on every keystroke.
        let source = Self.viewSource
        guard let bodyEnd = source.range(of: "private func search() async") else {
            #expect(Bool(false), "the search function was not found")
            return
        }
        let body = String(source[source.startIndex ..< bodyEnd.lowerBound])
        #expect(!body.contains("loadReferenceBody"))
    }

    @Test("A result that arrives after the query moved on is dropped")
    func staleResultIsDropped() {
        #expect(Self.viewSource.contains("guard trimmed == query.trimmingCharacters"))
    }
}
