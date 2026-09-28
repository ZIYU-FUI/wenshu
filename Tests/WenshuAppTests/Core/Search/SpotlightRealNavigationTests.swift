//
//  SpotlightRealNavigationTests.swift · Wenshu · v2.9d ticket T35 (boss 2026-09-28 OOB A8 polish)
//
//  Structural tests confirming the v2.9d Spotlight search
//  real-result navigation polish (= the v2.9a T22 jump-to-source
//  used the raw docId as the editor tab title; = the user saw
//  'book:UUID:default' instead of the friendly chapter /
//  reference / bookmark name).
//
//  v2.9d T35 (= boss 2026-09-28 OOB A8 polish follow-up):
//   1. CSSearchableIndexSearch exposes a public `title(forDocId:)`
//      API (= the mirror's stored title; = falls back to the
//      docId when the mirror has no entry).
//   2. SearchDocMirrorEntry exposes a `displayTitle` helper (=
//      returns title when non-empty; = falls back to docId).
//   3. LibraryRootView.handleSpotlightPick uses
//      CSSearchableIndexSearch.shared.title(forDocId:) (=
//      the editor tab title is the friendly display title).
//
//  Three source-level tests pin the canonical shape:
//
//    1. testCSSearchableIndexSearchHasTitleLookup —
//       CSSearchableIndexSearch exposes
//       `title(forDocId:) -> String`.
//
//    2. testSearchDocMirrorEntryHasDisplayTitle —
//       SearchDocMirrorEntry has `displayTitle` (= non-empty
//       title; = falls back to docId).
//
//    3. testLibraryRootViewUsesTitleLookup —
//       LibraryRootView.handleSpotlightPick calls
//       CSSearchableIndexSearch.shared.title(forDocId:).
//
//  Per Q34 5.2 + Q173 ponytail + Q186 + Q57 + Q112:
//  source-level tests following the v2.9a SpotlightRealSearchTests
//  pattern.

import Testing
import Foundation
@testable import WenshuApp

@Suite("Spotlight real navigation polish (v2.9d — boss 2026-09-28 OOB A8 polish follow-up)")
struct SpotlightRealNavigationTests {

    private func resolve(_ relative: String) -> String {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { url.deleteLastPathComponent() }
        url.appendPathComponent(relative)
        return url.path
    }

    @Test("CSSearchableIndexSearch exposes title(forDocId:) lookup")
    func testCSSearchableIndexSearchHasTitleLookup() throws {
        let source = try String(contentsOfFile: resolve("Sources/WenshuApp/Core/Search/CSSearchableIndexSearch.swift"), encoding: .utf8)
        #expect(source.contains("func title(forDocId docId: String) -> String"),
                "CSSearchableIndexSearch must expose title(forDocId:) lookup (= boss A8 polish = 'tab title 用 docId 不好看')")
    }

    @Test("SearchDocMirrorEntry has displayTitle helper (= non-empty title; falls back to docId)")
    func testSearchDocMirrorEntryHasDisplayTitle() throws {
        let source = try String(contentsOfFile: resolve("Sources/WenshuApp/Core/Search/CSSearchableIndexSearch.swift"), encoding: .utf8)
        #expect(source.contains("var displayTitle: String"),
                "SearchDocMirrorEntry must expose displayTitle (= non-empty title; = falls back to docId)")
    }

    @Test("LibraryRootView.handleSpotlightPick uses CSSearchableIndexSearch.shared.title(forDocId:)")
    func testLibraryRootViewUsesTitleLookup() throws {
        let source = try String(contentsOfFile: resolve("Sources/WenshuApp/Views/Onboarding/LibraryRootView.swift"), encoding: .utf8)
        #expect(source.contains("CSSearchableIndexSearch.shared.title(forDocId:"),
                "LibraryRootView.handleSpotlightPick must call CSSearchableIndexSearch.shared.title(forDocId:) (= boss A8 polish = friendly editor tab title)")
    }
}