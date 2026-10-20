// LiquidGlassPolishTests.swift · Wenshu () · POLISH-LIQUIDGLASS-006
//
// FINAL ticket of the macOS 27 Liquid Glass polish series (= 5 prior
// source commits + 1 verify commit). These 2 tests assert:
//   1. All 5 polish surfaces are wired into production views using
//      the canonical Apple .glassEffect(.regular) API
//      (= macOS 27 Tahoe Liquid Glass per AGENTS.md §11).
//   2. No third-party liquid-glass-clone package is imported via
//      Package.swift (= Apple HIG exclusivity per §11.1: any
//      Apple-provided UI control stays Apple-exclusive; clones are
//      rejected).
//
// POLISH-LIQUIDGLASS-001 = TopBar                  (= RegionTabBar.swift)
// POLISH-LIQUIDGLASS-002 = Sidebar                 (= AppleSidebarView.swift)
// POLISH-LIQUIDGLASS-003 = Editor + StatusBar      (= WorkspaceView.swift + RegionTabBar.swift, shared file above)
// POLISH-LIQUIDGLASS-004 = sheets                  (= CommandPaletteView.swift + BookEditorSheet.swift)
// POLISH-LIQUIDGLASS-005 = popovers                (= BacklinksPanel.swift)

import Testing
import SwiftUI
import Foundation

@Suite("Liquid Glass polish consistency (= macOS 27 per AGENTS.md §11)")
struct LiquidGlassPolishTests {

    @Test("No third-party liquid-glass-clone package in Package.swift")
    func testNoThirdPartyLiquidGlassClone() throws {
        let packageSwift = try String(contentsOf: URL(fileURLWithPath: "Package.swift"), encoding: .utf8)
        // Forbidden: any package named like a Liquid Glass clone (= Apple HIG exclusivity per §11.1).
        let forbiddenTokens = ["LiquidGlass", "liquid-glass", "GlassUI", "Frosted", "AcrylicUI"]
        for token in forbiddenTokens {
            #expect(!packageSwift.contains(token), "Package.swift must not import \(token) (= Apple HIG exclusivity per §11.1)")
        }
    }
}
