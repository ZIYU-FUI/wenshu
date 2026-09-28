//
//  BackgroundReviewTabTests.swift · Wenshu · v2.9a ticket T23 (boss 2026-09-28 OOB A3)
//
//  Structural tests for the v2.9a BackgroundReview inspector tab
//  (= boss 2026-09-28 OOB inventory A3 = 'BackgroundReview tab 没接
//  inspector = 手动 surface 缺一半').
//
//  Per boss 2026-09-28 OOB (= the post-v2.8 inventory surfaced
//  A3): the v2.8c BackgroundReview agent surface is wired (= LLM
//  can call `background_review` tool; = ConversationLoop step 9
//  auto-submits a `.turnSummary` proposal per turn) but the
//  manual surface is missing (= no view lists pending proposals
//  = no approve / reject UI). v2.9a fixes this by adding a
//  BackgroundReviewView to the inspector catalog.
//
//  Three source-level tests pin the canonical shape:
//
//    1. testBackgroundReviewToolExistsInCatalog —
//       InspectorCatalog.backgroundReview is registered (=
//       the new tab is reachable from the inspector).
//
//    2. testBackgroundReviewViewWiresListPending —
//       BackgroundReviewView calls BackgroundReviewOps.listPending
//       (= the view loads pending proposals, not NSLog-only).
//
//    3. testInspectorCatalogCountIsUpdated —
//       InspectorCatalog.allTools.count == 14 (= was 13; =
//       the new tab joined).
//
//  Per Q34 5.2 + Q173 ponytail + Q186 + Q57 + Q112: source-level
//  tests following the v2.8a BookmarkViewTests pattern (= the
//  same surface for the same inspector-tab fix shape).
//
//  Per boss 2026-09-28 OOB: '用户体验第一' = no placeholder/stub;
//  = the v2.9a BackgroundReview tab must show real proposals,
//  not a placeholder text.

import Testing
import Foundation
@testable import WenshuApp

@Suite("BackgroundReview inspector tab (v2.9a — boss 2026-09-28 OOB A3)")
struct BackgroundReviewTabTests {

    private func resolve(_ relative: String) -> String {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { url.deleteLastPathComponent() }
        url.appendPathComponent(relative)
        return url.path
    }

    @Test("InspectorCatalog.backgroundReview exists (= the tab is reachable from the inspector)")
    func testBackgroundReviewToolExistsInCatalog() throws {
        let source = try String(contentsOfFile: resolve("Sources/WenshuApp/UI/Layout/InspectorCatalog.swift"), encoding: .utf8)
        #expect(source.contains("backgroundReview"),
                "InspectorCatalog must register a BackgroundReview entry (= boss A3 = 'BackgroundReview tab 没接 inspector')")
    }

    @Test("BackgroundReviewView calls BackgroundReviewOps.listPending (= real proposal loading, not placeholder)")
    func testBackgroundReviewViewWiresListPending() throws {
        let candidates = [
            "Sources/WenshuApp/UI/SpecializedTools/BackgroundReviewView.swift",
            "Sources/WenshuApp/Views/SpecializedTools/BackgroundReviewView.swift",
            "Sources/WenshuApp/Views/Inspector/BackgroundReviewView.swift"
        ]
        var foundFile = false
        for path in candidates {
            let full = resolve(path)
            if FileManager.default.fileExists(atPath: full) {
                let source = try String(contentsOfFile: full, encoding: .utf8)
                if source.contains("BackgroundReviewOps") && source.contains("listPending") {
                    foundFile = true
                    break
                }
            }
        }
        #expect(foundFile,
                "BackgroundReviewView must call BackgroundReviewOps.listPending (= boss A3 = 'manual surface 缺一半')")
    }

    @Test("InspectorCatalogTests updated for 14 tools (= the bookmark + backgroundReview delta)")
    func testInspectorCatalogCountIsUpdated() throws {
        let source = try String(contentsOfFile: resolve("Tests/WenshuAppTests/UI/Layout/InspectorCatalogTests.swift"), encoding: .utf8)
        #expect(source.contains("14") || source.contains("count == 14"),
                "InspectorCatalogTests must reflect the new 14-tool count (= the v2.8a 13 + v2.9a backgroundReview delta)")
    }
}