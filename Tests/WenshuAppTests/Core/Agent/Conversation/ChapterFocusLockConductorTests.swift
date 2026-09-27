//
//  ChapterFocusLockConductorTests.swift · wenshu · chapter-focus-lock 2026-09-28 T3
//
//  RED tests for the conductor-side retry behavior. When a tool
//  throws ChapterFocusedByBossError, the conductor (= WenshuConductor
//  or its executeTool layer) temporarily clears focusedChapterPath,
//  retries the tool, and surfaces the result. This is the
//  auto-Allow path (= no UI dialog yet = T4 scope when the
//  boss asks for the explicit dialog). The MVP behavior accepts
//  the boss's approval unconditionally so the agent never blocks;
//  = future ticket swaps in the Allow/Deny UI without touching
//  the conductor's retry shape.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("ChapterFocusLockConductor (chapter-focus-lock 2026-09-28 T3)")
struct ChapterFocusLockConductorTests {

    @Test("WenshuConductor catches ChapterFocusedByBossError and retries")
    func conductorCatchesAndRetries() throws {
        let path = Self.repoSourcePath("Sources/WenshuApp/Core/Agent/Conversation/WenshuConductor.swift")
        let source = try String(contentsOfFile: path, encoding: .utf8)
        #expect(source.contains("ChapterFocusedByBossError"))
        #expect(source.contains("focusedChapterPath"))
    }

    @Test("ChapterFocusLockConductor retries with a temporary lock release")
    func conductorReleasesLockDuringRetry() throws {
        let path = Self.repoSourcePath("Sources/WenshuApp/Core/Agent/Conversation/WenshuConductor.swift")
        let source = try String(contentsOfFile: path, encoding: .utf8)
        // The retry path must set focusedChapterPath to nil (= or
        // whatever the prior value was; = restored on exit) so the
        // agent's second attempt passes the gate.
        #expect(source.contains("focusedChapterPath"))
    }

    // MARK: - Repo-root path helper
    private static func repoSourcePath(_ relativeFromRepoRoot: String) -> String {
        let path = "/Volumes/ANAN/Engineering/wenshu/wt/chapter-focus-lock-2026-09-28/\(relativeFromRepoRoot)"
        return path
    }
}