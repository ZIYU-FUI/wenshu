//
//  DeadCodeCleanupTests.swift · Wenshu · v2.9a ticket T25 (boss 2026-09-28 OOB B2 + B3)
//
//  Structural tests for the v2.9a dead-code + dangling-string cleanup
//  (= boss 2026-09-28 OOB inventory B2 + B3 = 'dangling skill_bundles
//  string + dead-code actors').
//
//  Per boss 2026-09-28 OOB (= the post-v2.8 inventory surfaced
//  B2 + B3): the §11.17 v2.4 skill cleanup arc deleted
//  SkillBundlesTool + SkillBundles + SkillBundlesYAMLDiscovery + 13
//  test files, but left a dangling 'skill_bundles' string in
//  WenshuConductor.defaultToolNames (= silent drop on every launch).
//
//  v2.9a fixes B2 by removing the dangling string.
//
//  v2.9a also fixes B3 by removing two dead-code files that
//  had no production callers:
//    - QuickSwitcherIndex (v0.19 Obsidian replica; = never
//      bound to a keybinding; = the boss-pinned B4 'QuickSwitcher
//      快捷键 deferred' answer says the keybinding never lands)
//    - DropAffordance (v0.28 followup TKT-028-021; = never wired
//      into any drag-drop surface; = the boss-pinned B11 answer
//      says the wiring never lands)
//
//  Three source-level tests pin the canonical shape:
//
//    1. testWenshuConductorDefaultToolNamesHasNoSkillBundles —
//       WenshuConductor.defaultToolNames does NOT contain
//       "skill_bundles" (= boss B2 dangling string removed).
//
//    2. testQuickSwitcherIndexDeleted —
//       The file Sources/WenshuApp/Core/QuickSwitcher/QuickSwitcherIndex.swift
//       no longer exists (= boss B3 dead-code deleted).
//
//    3. testDropAffordanceDeleted —
//       The file Sources/WenshuApp/UI/Drag/DropAffordance.swift
//       no longer exists (= boss B3 dead-code deleted).
//
//  Per Q34 5.2 + Q173 ponytail + Q186 + Q57 + Q112: source-level
//  tests following the v2.4 skill-cleanup-arc pattern.

import Testing
import Foundation
@testable import WenshuApp

@Suite("Dead code + dangling cleanup (v2.9a — boss 2026-09-28 OOB B2 + B3)")
struct DeadCodeCleanupTests {

    private func resolve(_ relative: String) -> String {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { url.deleteLastPathComponent() }
        url.appendPathComponent(relative)
        return url.path
    }

    @Test("WenshuConductor.defaultToolNames has no 'skill_bundles' string (= boss B2 dangling removed)")
    func testWenshuConductorDefaultToolNamesHasNoSkillBundles() throws {
        let source = try String(contentsOfFile: resolve("Sources/WenshuApp/Core/Agent/Conversation/WenshuConductor.swift"), encoding: .utf8)
        // defaultToolNames contains a string literal "skill_bundles"
        // OR a "toolNames" array element. The fix removes it.
        let hasDangling = source.contains("\"skill_bundles\"")
        #expect(!hasDangling,
                "WenshuConductor must not have a dangling 'skill_bundles' string (= boss B2 = 'conductor 启动时尝试 tools[skill_bundles] = 永远拿不到')")
    }

    @Test("QuickSwitcherIndex.swift is deleted (= boss B3 dead-code removed)")
    func testQuickSwitcherIndexDeleted() throws {
        let path = resolve("Sources/WenshuApp/Core/QuickSwitcher/QuickSwitcherIndex.swift")
        let exists = FileManager.default.fileExists(atPath: path)
        #expect(!exists,
                "QuickSwitcherIndex.swift must be deleted (= boss B3 = dead code with no callers + boss-pinned B4 'QuickSwitcher 快捷键 deferred')")
    }

    @Test("DropAffordance.swift is deleted (= boss B3 dead-code removed)")
    func testDropAffordanceDeleted() throws {
        let path = resolve("Sources/WenshuApp/UI/Drag/DropAffordance.swift")
        let exists = FileManager.default.fileExists(atPath: path)
        #expect(!exists,
                "DropAffordance.swift must be deleted (= boss B3 = dead code with no callers + boss-pinned B11 'DropAffordance wiring deferred')")
    }
}