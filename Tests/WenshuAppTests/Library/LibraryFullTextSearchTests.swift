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
    @MainActor
    func staleResultIsDropped() {
        // **⇒ BEHAVIOUR, = not source text.** = The old test asserted
        // that the guard's SOURCE STRING was present, = so it passed
        // while the behaviour it names was absent (= the guard compared
        // the query with itself, = and a comparison of `x` with `x` is
        // true by construction). = **⇒ So the rule is measured here, =
        // with the rule the VIEW RUNS** (= the production type, = not a
        // copy of it; = a copy would be a second rule, = and the test
        // would then measure the copy rather than the product).
        let state = LibrarySearchState()
        // The OLDER search starts (= it takes the first number).
        let older = state.begin()
        // The NEWER search starts (= it takes the next number).
        let newer = state.begin()
        #expect(older < newer, "the older search must carry the older number")
        // The newer result lands (= it is the latest).
        #expect(state.land([Self.hit(titled: "the newer hit")], generation: newer),
                "the latest result must land")
        #expect(state.hits.count == 1)
        #expect(state.hits.first?.reference.title == "the newer hit")
        // **⇒ THE OLDER SEARCH FINISHES LAST.** = Its result is stale, =
        // and a stale result must not overwrite the newer one.
        #expect(state.land([Self.hit(titled: "the older hit")], generation: older) == false,
                "a result whose number is not the latest must be dropped")
        #expect(state.hits.count == 1, "the stale result must not have landed")
        #expect(state.hits.first?.reference.title == "the newer hit",
                "the newer result must still be the one on screen")
    }

    /// One hit, = so the rule can be measured with real values.
    private static func hit(titled title: String) -> ReferenceLibrarySearch.Hit {
        ReferenceLibrarySearch.Hit(
            reference: Reference(id: UUID(), title: title, layer: .layerEntities),
            snippet: title,
            score: 1
        )
    }

    @Test("The snippet the user reads carries no markup")
    func theSnippetCarriesNoMarkup() {
        // **⇒ The index wraps a match in `<mark>`, = and the view paints
        // the snippet as a plain String** (= so the tags would be read as
        // words). = **⇒ The tags are stripped where the snippet is
        // made**, = so no consumer has to know the index's markup.
        //
        // **⇒ AND THE SNIPPET COMES FROM THE PRODUCTION SEARCH, = not
        // from the helper called directly.** = A test that called
        // `stripMarkup` on a hand-written string would pass even if the
        // search stopped calling it at all (= the helper would be
        // perfect and unused). = So the search runs, = and its own
        // snippet is what is inspected.
        let hits = ReferenceLibrarySearch.search(
            query: "quanzhou",
            references: [Reference(title: "Sea routes", layer: .layerEntities)],
            bodyOf: { _ in "The harbour at Quanzhou carried the tribute." }
        )
        #expect(hits.count == 1, "the body word must match (= the change's own headline)")
        let snippet = hits.first?.snippet ?? ""
        #expect(!snippet.contains("<mark>"), "the snippet must carry no opening tag")
        #expect(!snippet.contains("</mark>"), "the snippet must carry no closing tag")
        #expect(snippet.contains("quanzhou"), "the snippet must still say what matched")
        #expect(snippet.contains("harbour"), "the snippet must still carry the excerpt")
    }
}


