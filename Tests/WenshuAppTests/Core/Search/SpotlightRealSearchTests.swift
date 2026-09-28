//
//  SpotlightRealSearchTests.swift · Wenshu · v2.9a ticket T22 (boss 2026-09-28 OOB A8)
//
//  Structural tests for the v2.9a Spotlight real-search surface
//  (= boss 2026-09-28 OOB inventory A8 = 'Spotlight 搜不到任何东西
//  — 等于空功能').
//
//  Per boss 2026-09-28 OOB (= the post-v2.8 inventory surfaced
//  A8): Cmd-F Spotlight search opens the sheet but returns an
//  empty array (= CSSearchableIndexSearch has no callers = zero
//  documents bootstrap into the index). v2.9a fixes this by
//  hooking CSSearchableIndexSearch.bootstrap + .index + .remove
//  into the 3 canonical save paths:
//    1. FileSystemChapterStore.saveChapter / replaceChapter
//    2. FileSystemReferenceStore.saveReference (= already
//       has LLMWikiOps hook from v2.8d; = adds Spotlight
//       bootstrap alongside)
//    3. WSBookmarkRepository.add (= new bookmark = new
//       Spotlight entry)
//
//  Plus the SpotlightSearchSheet handleSpotlightPick callback
//  needs to actually open the picked document (= jump-to-source;
//  = the sheet's onPick currently NSLog + close = no real
//  navigation).
//
//  Three source-level tests pin the canonical shape:
//
//    1. testSpotlightIndexBootstrapOnChapterSave —
//       FileSystemChapterStore.saveChapter calls
//       CSSearchableIndexSearch.index (or delegates to a
//       helper) to add the chapter to the Spotlight index.
//
//    2. testSpotlightIndexBootstrapOnBookmarkAdd —
//       WSBookmarkRepository.add calls
//       CSSearchableIndexSearch.index (= bookmarks surface
//       in Cmd-F results).
//
//    3. testSpotlightSheetOnPickNavigatesToDocument —
//       SpotlightSearchSheet / SpotlightOps handle a pick
//       (= the jump-to-source navigation path; = the
//       LibraryRootView.handleSpotlightPick method or
//       SpotlightOps delegate).
//
//  Per Q34 5.2 + Q173 ponytail + Q186 + Q57 + Q112: source-level
//  tests following the v1.44 specialized-tools P1 hermes-port
//  batch precedent.
//
//  Per boss 2026-09-28 OOB: '用户体验第一' = no placeholder/stub;
//  = the v2.9a spotlight search must produce real document hits.

import Testing
import Foundation
@testable import WenshuApp

@Suite("Spotlight real search (v2.9a — boss 2026-09-28 OOB A8)")
struct SpotlightRealSearchTests {

    private var chapterStorePath: String {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 { url.deleteLastPathComponent() }
        url.appendPathComponent("Sources/WenshuApp/Storage/FileSystemChapterStore.swift")
        return url.path
    }

    private var bookmarkRepoPath: String {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 { url.deleteLastPathComponent() }
        url.appendPathComponent("Sources/WenshuApp/Persistence/Repositories/WSBookmarkRepository.swift")
        return url.path
    }

    private var spotlightSearchSheetPath: String {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 { url.deleteLastPathComponent() }
        url.appendPathComponent("Sources/WenshuApp/Views/Search/SpotlightSearchSheet.swift")
        return url.path
    }

    private var spotlightOpsPath: String {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 { url.deleteLastPathComponent() }
        url.appendPathComponent("Sources/WenshuApp/UI/Search/SpotlightOps.swift")
        return url.path
    }

    @Test("FileSystemChapterStore.saveChapter bootstraps into CSSearchableIndexSearch (= chapters surface in Cmd-F)")
    func testSpotlightIndexBootstrapOnChapterSave() throws {
        let source = try String(contentsOfFile: chapterStorePath, encoding: .utf8)
        #expect(source.contains("CSSearchableIndexSearch") || source.contains("SpotlightOps"),
                "FileSystemChapterStore.saveChapter must bootstrap the chapter into the Spotlight index (= the boss A8 real-search fix)")
    }

    @Test("WSBookmarkRepository.add bootstraps into CSSearchableIndexSearch (= bookmarks surface in Cmd-F)")
    func testSpotlightIndexBootstrapOnBookmarkAdd() throws {
        let source = try String(contentsOfFile: bookmarkRepoPath, encoding: .utf8)
        #expect(source.contains("CSSearchableIndexSearch") || source.contains("SpotlightOps"),
                "WSBookmarkRepository.add must bootstrap the bookmark into the Spotlight index (= the boss A8 real-search fix)")
    }

    @Test("SpotlightSearchSheet.onPick navigates to the picked document (= real jump-to-source, not NSLog)")
    func testSpotlightSheetOnPickNavigatesToDocument() throws {
        let sheetSource = try String(contentsOfFile: spotlightSearchSheetPath, encoding: .utf8)
        let opsSource = try String(contentsOfFile: spotlightOpsPath, encoding: .utf8)
        // Either the sheet or ops layer wires navigation; =
        // the surface must reference the canonical "open the
        // picked document" path (= no NSLog-only stub).
        let hasNavigationInSheet = sheetSource.contains("openDocument") ||
                                   sheetSource.contains("navigateTo") ||
                                   sheetSource.contains("onPickNavigate")
        let hasNavigationInOps = opsSource.contains("openDocument") ||
                                 opsSource.contains("navigateTo") ||
                                 opsSource.contains("onPickNavigate")
        #expect(hasNavigationInSheet || hasNavigationInOps,
                "SpotlightSearchSheet / SpotlightOps must wire a real jump-to-source path on result pick (= boss A8 = 'Cmd-F 找到东西但不能跳过去')")
    }
}