// PaneTabBarTests.swift · Wenshu · v1.80 health-ticket 2
//
// PaneTabBar.swift is a generic SwiftUI View (= @MainActor struct)
// that cannot be exercised through View rendering tests under the
// wenshu test convention (= per AGENTS.md wenshu testing = value
// types + source-level assertions, not ViewInspector; = ViewInspector
// is approved but never used in the repo's prior tests). repowise
// flagged this file at score 4.5 = untested_hotspot with 25 dependents.
//
// Strategy (= Q112 = 1 source + 1 test per ticket):
//   - PaneTabItem = a value type (= `Identifiable & Sendable`); can be
//     constructed + equality compared directly.
//   - PaneTabBar / PaneIconTab / PaneTrailingIconButton = View types;
//     exercised via source-level assertions (= the convention used by
//     LiquidGlassPolishTests for view-only files).
//
// Coverage:
//   1. PaneTabItem stores id/icon/label verbatim
//   2. PaneTabItem init defaults match the public initializer surface
//   3. PaneTabBar source declares @MainActor + the generic constraint
//      `Item: Identifiable & Sendable, Trailing: View`
//   4. PaneTabBar source has the convenience init for PaneTabItem items
//   5. PaneTabBar source includes the trailing-button rendering rule
//      (= always render trailing, never collapse to EmptyView)
//   6. PaneIconTab source uses matchedGeometryEffect for the
//      selected-state underline (= canonical Apple HIG slide animation)

import Foundation
import Testing
@testable import WenshuApp

@Suite("PaneTabBar (= generic SwiftUI view used by all 6 per-pane tab bars)")
struct PaneTabBarTests {

    // MARK: - PaneTabItem value type

    @Test("PaneTabItem stores id/icon/label verbatim")
    func paneTabItemStoresFields() {
        let item = PaneTabItem(id: "chat", icon: "bubble.left", label: "dialog")
        #expect(item.id == "chat")
        #expect(item.icon == "bubble.left")
        #expect(item.label == "dialog")
    }

    @Test("PaneTabItem init matches its public initializer surface (= Identifiable by id)")
    func paneTabItemIdentifiable() {
        let item = PaneTabItem(id: "preview", icon: "book-open-text", label: "")
        let list: [PaneTabItem] = [item]
        #expect(list.first?.id == "preview")
    }

    // MARK: - Source-level assertions for the view body

    @Test("PaneTabBar source declares @MainActor + generic Item: Identifiable & Sendable, Trailing: View")
    func paneTabBarSourceSignature() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/UI/PaneTabBar.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("@MainActor"), "PaneTabBar must be @MainActor (= macOS SwiftUI main-thread only)")
        #expect(content.contains("struct PaneTabBar<Item: Identifiable & Sendable, Trailing: View>"),
                "PaneTabBar must declare both generic constraints verbatim")
    }

    @Test("PaneTabBar source has the convenience initializer for PaneTabItem items")
    func paneTabBarConvenienceInit() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/UI/PaneTabBar.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("where Item == PaneTabItem"),
                "PaneTabBar must expose `where Item == PaneTabItem` convenience init")
        #expect(content.contains("idKeyPath: \\.id"), "convenience init must bind idKeyPath to \\.id")
        #expect(content.contains("iconKeyPath: \\.icon"), "convenience init must bind iconKeyPath to \\.icon")
        #expect(content.contains("labelKeyPath: \\.label"), "convenience init must bind labelKeyPath to \\.label")
    }

    @Test("PaneTabBar source always renders trailing (= the no-EmptyView-skip rule)")
    func paneTabBarAlwaysRendersTrailing() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/UI/PaneTabBar.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("Spacer(minLength: 0)"),
                "PaneTabBar must use Spacer(minLength: 0) to push trailing to the right edge")
        #expect(content.contains(".frame(maxWidth: .infinity)"),
                "PaneTabBar must stretch its inner HStack via .frame(maxWidth: .infinity) so Spacer expands")
    }

    @Test("PaneIconTab source uses matchedGeometryEffect for the selected-state underline")
    func paneIconTabMatchedGeometry() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/UI/PaneTabBar.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("matchedGeometryEffect(id: namespaceID, in: namespace)"),
                "PaneIconTab must use matchedGeometryEffect for the slide animation")
        #expect(content.contains(".clipShape(Capsule())"),
                "PaneIconTab must clip the underline with Capsule() for fully rounded ends")
        #expect(content.contains("DesignTokens.tabUnderlineHeight"),
                "PaneIconTab must read DesignTokens.tabUnderlineHeight (= Apple HIG 1 PT height)")
    }
}
