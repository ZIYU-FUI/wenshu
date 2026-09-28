//
//  ForeshadowingGraphWindowActorWireTests.swift · Wenshu · v2.9c ticket T31 (boss 2026-09-28 OOB A5 follow-up)
//
//  Structural tests for the v2.9c ForeshadowingGraphWindow actor
//  wire-up (= boss 2026-09-28 OOB inventory follow-up A5 = '4 个 window
//  接 actor' 续集; = ForeshadowingGraphWindow was EmptyStateView
//  placeholder before v2.9c).
//
//  Per boss 2026-09-28 OOB: '重复的应该合并, 不同的功能每个独立的；
//  = 但缺失的应该补'; = v2.9c wires ForeshadowingGraphWindow to
//  the existing ForeshadowingTracker actor (= the canonical
//  persistence per AGENTS.md §11 baseline; = same pattern as
//  ForeshadowingView).
//
//  Three source-level tests pin the canonical shape:
//
//    1. testForeshadowingGraphWindowCallsTracker —
//       ForeshadowingGraphWindow.reload calls
//       ForeshadowingTracker.list (= the view delegates to
//       the canonical actor; = no sidecar reads).
//
//    2. testForeshadowingGraphWindowRefreshToolbarButton —
//       ForeshadowingGraphWindow.toolbar has a refresh
//       button (= i18n key foreshadowing_graph.refresh).
//
//    3. testForeshadowingGraphWindowNoBookEmptyState —
//       ForeshadowingGraphWindow shows the no-book empty
//       state when activeBookId is nil (= user feedback
//       instead of silent empty state).
//
//  Per Q34 5.2 + Q173 ponytail + Q186 + Q57 + Q112: source-level
//  tests following the v2.8b SecondaryWindowsTests pattern.

import Testing
import Foundation
@testable import WenshuApp

@Suite("ForeshadowingGraphWindow actor wire-up (v2.9c — boss 2026-09-28 OOB A5 follow-up)")
struct ForeshadowingGraphWindowActorWireTests {

    private func resolve(_ relative: String) -> String {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { url.deleteLastPathComponent() }
        url.appendPathComponent(relative)
        return url.path
    }

    @Test("ForeshadowingGraphWindow.reload calls ForeshadowingTracker.list")
    func testForeshadowingGraphWindowCallsTracker() throws {
        let source = try String(contentsOfFile: resolve("Sources/WenshuApp/Views/Windows/ForeshadowingGraphWindow.swift"), encoding: .utf8)
        #expect(source.contains("ForeshadowingTracker(bookStore:") && source.contains("tracker.list(bookId:"),
                "ForeshadowingGraphWindow.reload must call ForeshadowingTracker.list (= boss A5 follow-up = 'window 是占位')")
    }

    @Test("ForeshadowingGraphWindow.toolbar has refresh button (= i18n key foreshadowing_graph.refresh)")
    func testForeshadowingGraphWindowRefreshToolbarButton() throws {
        let source = try String(contentsOfFile: resolve("Sources/WenshuApp/Views/Windows/ForeshadowingGraphWindow.swift"), encoding: .utf8)
        #expect(source.contains("foreshadowing_graph.refresh"),
                "ForeshadowingGraphWindow.toolbar must include a refresh action")
    }

    @Test("ForeshadowingGraphWindow shows no-book empty state when activeBookId is nil")
    func testForeshadowingGraphWindowNoBookEmptyState() throws {
        let source = try String(contentsOfFile: resolve("Sources/WenshuApp/Views/Windows/ForeshadowingGraphWindow.swift"), encoding: .utf8)
        #expect(source.contains("foreshadowing_graph.no_book.title"),
                "ForeshadowingGraphWindow must show a no-book empty state (= user feedback instead of silent empty)")
    }
}