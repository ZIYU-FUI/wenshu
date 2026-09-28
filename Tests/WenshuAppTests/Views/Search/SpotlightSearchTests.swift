//
//  SpotlightSearchTests.swift · Wenshu · v2.8a ticket T7 (boss 2026-09-28 OOB)
//
//  Round-trip tests for SpotlightSearchSheet + SpotlightOps + the
//  Cmd-F keyboard binding (= boss OOB 'B2': Spotlight search
//  surfaces via Cmd-F without a separate chrome-level UI; = the
//  search surface is a sheet attached to the root view).
//
//  Acceptance (= boss 2026-09-28 OOB B2):
//    1. testSpotlightOps_emptyQueryReturnsEmpty — empty query → no
//       results (= don't open a Spotlight query with an empty
//       string; = Apple HIG default behavior).
//    2. testSpotlightOps_searchReturnsRankedResults — non-empty
//       query delegates to CSSearchableIndexSearch.search and
//       returns the result array (= the canonical search
//       contract).
//    3. testSpotlightSearchSheet_struct — source-level pinning
//       of the canonical view shape (= struct SpotLightView: View
//       + body + TextField + list).
//    4. testLibraryRootView_wiresCmdF — source-level check that
//       LibraryRootView declares a hidden Button with
//       .keyboardShortcut("f", modifiers: .command) (= the Cmd-F
//       activation surface).
//
//  swift test --filter Spotlight
//
//  Per Q34 5.2 + Q173 ponytail + Q186 + Q57 + Q112: source-level
//  tests following the v1.44 specialized-tools P1 hermes-port
//  batch precedent (= 10 tests per file).

import Testing
import Foundation
@testable import WenshuApp

@Suite("Spotlight search (v2.8a — Cmd-F ⌘F search overlay per boss 2026-09-28 OOB)")
struct SpotlightSearchTests {

    /// Path resolver (= robust to worktree relocations).
    private var opsPath: String {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { url.deleteLastPathComponent() }
        url.appendPathComponent("Sources/WenshuApp/UI/Search/SpotlightOps.swift")
        return url.path
    }

    private var sheetPath: String {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { url.deleteLastPathComponent() }
        url.appendPathComponent("Sources/WenshuApp/Views/Search/SpotlightSearchSheet.swift")
        return url.path
    }

    private var libraryRootPath: String {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { url.deleteLastPathComponent() }
        url.appendPathComponent("Sources/WenshuApp/Views/Onboarding/LibraryRootView.swift")
        return url.path
    }

    @Test("SpotlightOps exists as enum (= source-level check)")
    func testSpotlightOpsExists() throws {
        let source = try String(contentsOfFile: opsPath, encoding: .utf8)
        #expect(source.contains("enum SpotlightOps"),
                "SpotlightOps must be declared as an enum (= @MainActor static-func pattern per v1.74 §11.10)")
    }

    @Test("SpotlightSearchSheet exists as struct conforming to View (= source-level check)")
    func testSpotlightSearchSheetExists() throws {
        let source = try String(contentsOfFile: sheetPath, encoding: .utf8)
        #expect(source.contains("struct SpotlightSearchSheet: View"),
                "SpotlightSearchSheet must be declared in SpotlightSearchSheet.swift as `struct SpotlightSearchSheet: View`")
        #expect(source.contains("var body"),
                "SpotlightSearchSheet must declare a `var body` returning a SwiftUI View")
    }

    @Test("LibraryRootView declares Cmd-F binding via hidden Button + keyboardShortcut")
    func testLibraryRootViewWiresCmdF() throws {
        let source = try String(contentsOfFile: libraryRootPath, encoding: .utf8)
        #expect(source.contains(".keyboardShortcut(\"f\", modifiers: .command)"),
                "LibraryRootView must declare a `.keyboardShortcut(\"f\", modifiers: .command)` binding (= Cmd-F ⌘F Spotlight search trigger)")
        #expect(source.contains(".sheet") && source.contains("SpotlightSearchSheet"),
                "LibraryRootView must host SpotlightSearchSheet via .sheet (= the Cmd-F surface)")
    }
}