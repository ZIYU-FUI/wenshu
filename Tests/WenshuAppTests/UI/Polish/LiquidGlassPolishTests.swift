// LiquidGlassPolishTests.swift · Wenshu (文枢) · POLISH-LIQUIDGLASS-006
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
// POLISH-LIQUIDGLASS-002 = Sidebar                 (= NewLibraryOutlineView.swift)
// POLISH-LIQUIDGLASS-003 = Editor + StatusBar      (= WorkspaceView.swift + RegionTabBar.swift, shared file above)
// POLISH-LIQUIDGLASS-004 = sheets                  (= CommandPaletteView.swift + BookEditorSheet.swift)
// POLISH-LIQUIDGLASS-005 = popovers                (= BacklinksPanel.swift)

import Testing
import Foundation

@Suite("Liquid Glass polish consistency (= macOS 27 per AGENTS.md §11)")
struct LiquidGlassPolishTests {

    @Test("All 5 polish surfaces (.glassEffect(.regular)) are wired into production views")
    func testAllFivePolishSurfacesWired() {
        // Verify the source files exist + contain .glassEffect(.regular).
        let polishedFiles = [
            "Sources/WenshuApp/UI/RegionTabBar.swift",                         // POLISH-LIQUIDGLASS-001 TopBar
            "Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift",    // POLISH-LIQUIDGLASS-002 Sidebar
            "Sources/WenshuApp/Views/Workspace/WorkspaceView.swift",          // POLISH-LIQUIDGLASS-003 Editor
            // StatusBar lives in RegionTabBar.swift too (= same file; covered above).
            "Sources/WenshuApp/Views/CommandPalette/CommandPaletteView.swift", // POLISH-LIQUIDGLASS-004 sheet
            "Sources/WenshuApp/Views/Library/BookEditorSheet.swift",          // POLISH-LIQUIDGLASS-004 sheet
            "Sources/WenshuApp/Core/LinkGraph/BacklinksPanel.swift"           // POLISH-LIQUIDGLASS-005 popover
        ]

        for file in polishedFiles {
            let url = URL(fileURLWithPath: file)
            #expect(FileManager.default.fileExists(atPath: url.path), "\(file) must exist")
            let content = try? String(contentsOf: url, encoding: .utf8)
            #expect(content != nil, "\(file) must be readable")
            #expect(content?.contains(".glassEffect(.regular)") ?? false, "\(file) must contain .glassEffect(.regular)")
        }
    }

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
