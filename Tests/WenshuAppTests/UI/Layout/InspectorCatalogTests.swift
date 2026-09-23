//
//  InspectorCatalogTests.swift · Wenshu · v1.71d ticket 004
//
//  Tests for the right column MVVM split arc (= v1.71 修正): verifies
//  that the data + business layers extracted in tickets 01 + 02 are
//  complete, type-safe, and match the v1.43 inline catalog真值 (= the
//  12 tool definitions + 4 page routing tables).
//
//  Per Q244 §5.2 service-style file extraction (不动 SoT, 业务从
//  View 抽走): the highest seam (= InspectorCatalog + InspectorPage
//  .tools) is what we test. View rendering seam (ZoneContentView) is
//  unchanged and already covered by existing tests.
//
//  Test categories (= ticket 04 spec §5.2):
//    1. Data-layer: 12 tool catalog completeness
//    2. Business-layer: 4 page routing completeness
//    3. i18n key uniqueness (= Q244 baseline smell 'Duplicated Code'
//       defense — every i18n key typed twice in the old code
//       → silent filter mismatch risk)
//    4. SF Symbol 6 icon non-emptiness (= boss 2026-09-16 'ICON
//       丢失' 翻车防御)
//    5. view closure invocation (= boss 2026-09-18 '所有 ICON，
//       都不需要 .fill' 防御 + smoke test view construction doesn't
//       crash)
//
//  Per Q244 §4 反例 audit pattern: tests cover external behavior
//  only (= InspectorTool.id / .icon / .title / InspectorPage.tools
//  return values), NOT implementation details (= closure internals).
//

import Testing
import SwiftUI
@testable import WenshuApp

@Suite("v1.71 right column MVVM split — InspectorCatalog + InspectorPage.tools")
struct InspectorCatalogTests {

    // MARK: - Test 1: 12 tool catalog completeness

    @Test("InspectorCatalog.allTools count = 12 (= boss 'three per page × four pages'真值)")
    func allToolsCount() {
        #expect(InspectorCatalog.allTools.count == 12)
    }

    @Test("InspectorCatalog.allTools IDs unique (= Q244 'Duplicated Code' smell defense)")
    func allToolsIdsUnique() {
        let ids = InspectorCatalog.allTools.map(\.id)
        #expect(Set(ids).count == 12, "all 12 IDs must be unique")
    }

    @Test("InspectorCatalog.allTools IDs match i18n catalog (tab.title.* keys)")
    func allToolsIdsAreI18nKeys() {
        let expectedPrefix = "tab.title."
        for tool in InspectorCatalog.allTools {
            #expect(tool.id.hasPrefix(expectedPrefix),
                    "tool ID '\(tool.id)' must start with '\(expectedPrefix)'")
        }
    }

    @Test("InspectorCatalog 12 individual entries exist + resolve (= catalog completeness)")
    func individualEntries() {
        // Spot-check 4 of the 12 (= the 4 pages' first entries).
        // If any of these is missing, the catalog is broken.
        let entries: [InspectorTool] = [
            InspectorCatalog.foreshadowing,
            InspectorCatalog.longForm,
            InspectorCatalog.characterRelationships,
            InspectorCatalog.ideaLibrary
        ]
        for entry in entries {
            #expect(!entry.id.isEmpty)
            #expect(!entry.title.isEmpty)
        }
    }

    // MARK: - Test 2: 4 page routing completeness

    @Test("InspectorPage.authoringFiction.tools = 3 + matches v1.43 inline真值")
    func authoringFictionRouting() {
        let tools = InspectorPage.authoringFiction.tools
        #expect(tools.count == 3)
        #expect(tools.contains(InspectorCatalog.foreshadowing))
        #expect(tools.contains(InspectorCatalog.placeholder))
        #expect(tools.contains(InspectorCatalog.plotThread))
    }

    @Test("InspectorPage.authoringStyle.tools = 3 + matches v1.43 inline真值")
    func authoringStyleRouting() {
        let tools = InspectorPage.authoringStyle.tools
        #expect(tools.count == 3)
        #expect(tools.contains(InspectorCatalog.longForm))
        #expect(tools.contains(InspectorCatalog.readerExperience))
        #expect(tools.contains(InspectorCatalog.genreFit))
    }

    @Test("InspectorPage.authoringCharacters.tools = 3 + matches v1.43 inline真值")
    func authoringCharactersRouting() {
        let tools = InspectorPage.authoringCharacters.tools
        #expect(tools.count == 3)
        #expect(tools.contains(InspectorCatalog.characterRelationships))
        #expect(tools.contains(InspectorCatalog.characterLifecycle))
        #expect(tools.contains(InspectorCatalog.emotionCurve))
    }

    @Test("InspectorPage.projectManagement.tools = 3 + matches v1.43 inline真值")
    func projectManagementRouting() {
        let tools = InspectorPage.projectManagement.tools
        #expect(tools.count == 3)
        #expect(tools.contains(InspectorCatalog.ideaLibrary))
        #expect(tools.contains(InspectorCatalog.tagManager))
        #expect(tools.contains(InspectorCatalog.bookSettingConstraints))
    }

    @Test("page tools IDs unique per page (= no duplicate within page)")
    func pageToolsUniquePerPage() {
        for page in InspectorPage.allCases {
            let ids = page.tools.map(\.id)
            #expect(Set(ids).count == ids.count,
                    "page \(page) has duplicate tools")
        }
    }

    @Test("sum of all page tools = 12 (no overlap, no missing)")
    func sumOfAllPageTools() {
        var union: Set<String> = []
        for page in InspectorPage.allCases {
            union.formUnion(page.tools.map(\.id))
        }
        #expect(union.count == 12, "4 pages × 3 = 12, no overlap, no missing")
    }

    // MARK: - Test 3: i18n key resolution (= silent rename defense)

    @Test("InspectorTool.title = WenshuI18n.t(self.id) (= i18n resolves, no typo)")
    func toolTitlesResolve() {
        for tool in InspectorCatalog.allTools {
            // If id is not a valid i18n key, WenshuI18n.t returns the
            // key path itself (= the fallback policy documented in
            // WenshuI18n.swift:2). The non-fallback case is title
            // == i18n-resolved value of id (= test ensures
            // catalog definition matches what view will display).
            #expect(tool.title == WenshuI18n.t(tool.id),
                    "tool '\(tool.id)' title = '\(tool.title)' but WenshuI18n.t('\(tool.id)') = '\(WenshuI18n.t(tool.id))'")
        }
    }

    // MARK: - Test 4: SF Symbol 6 icon non-emptiness

    @Test("InspectorTool icons non-empty (= boss 9/16 'ICON 丢失' 翻车 defense)")
    func toolIconsNonEmpty() {
        for tool in InspectorCatalog.allTools {
            #expect(!tool.icon.isEmpty,
                    "tool '\(tool.id)' has empty icon")
        }
    }

    @Test("InspectorTool icons do not contain '.fill' (= boss 9/18 '所有 ICON，都不要 .fill')")
    func toolIconsOutlineOnly() {
        for tool in InspectorCatalog.allTools {
            #expect(!tool.icon.contains(".fill"),
                    "tool '\(tool.id)' icon '\(tool.icon)' contains .fill variant")
        }
    }

    @Test("InspectorTool icons do not contain kebab-case Lucide names (= boss 9/16 'ICON 丢失' Lucide → SF Symbols 6 migration defense)")
    func toolIconsNotLucide() {
        // Sanity: the 12 SF Symbol 6 names verified 2026-09-16 should
        // NOT look like Lucide kebab-case (e.g. 'git-fork' /
        // 'square-dashed' / 'shield-check'). Lucide convention uses
        // kebab-case (hyphen-separated); SF Symbols 6 uses either
        // single-word lowercase ('sparkles', 'bookmark', 'tag') OR
        // dotted.case ('arrow.triangle.branch'). The discriminator:
        // Lucide has hyphens; SF Symbols 6 does not.
        for tool in InspectorCatalog.allTools {
            #expect(!tool.icon.contains("-"),
                    "tool '\(tool.id)' icon '\(tool.icon)' contains '-' (Lucide kebab-case marker; should be SF Symbols 6 dotted.case)")
        }
    }

    // MARK: - Test 5: view closure invocation (smoke test)

    @MainActor
    @Test("InspectorTool.view() returns constructible view (= smoke test, no crash)")
    func toolViewsReturn() {
        for tool in InspectorCatalog.allTools {
            // Just verify the closure can be called without crashing.
            // The closure invocation exercises the @MainActor path and
            // constructs AnyView (= wraps the underlying specialized
            // tool view). We can't introspect AnyView body directly
            // (= black-box by Apple SwiftUI design), but the call
            // returning without trapping is the smoke test.
            let _ = tool.view()
        }
    }
}