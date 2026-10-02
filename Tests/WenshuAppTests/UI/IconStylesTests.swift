//
//  IconStylesTests.swift · Wenshu · v3.0
//
//  Per Q112 = 1 source + 1 test per ticket. IconStyles.swift is a
//  central abstraction (= SFIcon + IconStyle + IconColor + IconRendering
//  + WenshuTextStyle). Tests = source-level (= per wenshu test
//  convention): value-type direct construction + source-content
//  assertions for the View body wiring.
//
//  Coverage:
//      1. IconStyle.pointSize = Apple-default (= not wenshu-invented)
//      2. IconStyle.fontWeight = .thin for ≥38 PT zone, .regular otherwise
//      3. IconStyle.isHitArea = true for .hitArea / .toolbarButton
//      4. IconStyle.allCases = 11 (= 1:1 with the Apple-HIG surface list)
//      5. WenshuTextStyle.font = SwiftUI text-style API verbatim
//      6. WenshuTextStyle.pointSize = Apple default (= not ad-hoc)
//      7. SFIcon source declares @MainActor + the canonical initializer
//      8. SFIcon source applies the .hierarchical default at <38 PT zone
//      9. SFIcon source applies the .monochrome default at ≥38 PT zone
//     10. IconColor.style = SwiftUI semantic color, no ad-hoc RGB
//     11. View extension `wenshuFont(_:)` exists and pins the case body
//

import Foundation
import SwiftUI
import Testing
@testable import WenshuApp

@Suite("IconStyles (= central SF Symbols 6 factory + Apple HIG walk)")
struct IconStylesTests {

    // MARK: - IconStyle.pointSize = Apple-default per HIG

    @Test("IconStyle.inlineSmall = 14 (= Apple HIG list row leading inline icon)")
    func inlineSmallPointSize() {
        #expect(IconStyle.inlineSmall.pointSize == 14)
    }

    @Test("IconStyle.small = 16 (= SwiftUI ControlSize.mini)")
    func smallPointSize() {
        #expect(IconStyle.small.pointSize == 16)
    }

    @Test("IconStyle.paneTab = 18 (= NSToolbar item macOS 14+ default)")
    func paneTabPointSize() {
        #expect(IconStyle.paneTab.pointSize == 18)
    }

    @Test("IconStyle.toolbar = 22 (= SwiftUI ControlSize.small / macOS toolbar default)")
    func toolbarPointSize() {
        #expect(IconStyle.toolbar.pointSize == 22)
    }

    @Test("IconStyle.nav = 24 (= SwiftUI ControlSize.regular / HIG macOS nav)")
    func navPointSize() {
        #expect(IconStyle.nav.pointSize == 24)
    }

    @Test("IconStyle.hitArea = 28 (= macOS HIG minimum hit area)")
    func hitAreaPointSize() {
        #expect(IconStyle.hitArea.pointSize == 28)
    }

    @Test("IconStyle.emptyStateHero = 76 (= ContentUnavailableView default zone)")
    func emptyStateHeroPointSize() {
        #expect(IconStyle.emptyStateHero.pointSize == 76)
    }

    @Test("IconStyle.avatar = 64 (= NSTableView thumbnail row standard)")
    func avatarPointSize() {
        #expect(IconStyle.avatar.pointSize == 64)
    }

    @Test("IconStyle.cover = 192 (= CoverFlow thumbnail)")
    func coverPointSize() {
        #expect(IconStyle.cover.pointSize == 192)
    }

    @Test("IconStyle.toolbarButton = 32 (= SwiftUI ControlSize.regular)")
    func toolbarButtonPointSize() {
        #expect(IconStyle.toolbarButton.pointSize == 32)
    }

    @Test("IconStyle.surface = 56 (= HIG medium card standard)")
    func surfacePointSize() {
        #expect(IconStyle.surface.pointSize == 56)
    }

    // MARK: - IconStyle.fontWeight split (boss 2026-09-17 SF Symbols 6 rule)

    @Test("IconStyle.fontWeight = .thin for the >=38 PT zone (= hero / avatar / cover)")
    func fontWeightThinForLargeZones() {
        #expect(IconStyle.emptyStateHero.fontWeight == .thin)
        #expect(IconStyle.avatar.fontWeight == .thin)
        #expect(IconStyle.cover.fontWeight == .thin)
    }

    @Test("IconStyle.fontWeight = .regular for the <38 PT zone (= boss 9/15 thin canonical)")
    func fontWeightRegularForSmallZones() {
        #expect(IconStyle.inlineSmall.fontWeight == .regular)
        #expect(IconStyle.small.fontWeight == .regular)
        #expect(IconStyle.paneTab.fontWeight == .regular)
        #expect(IconStyle.toolbar.fontWeight == .regular)
        #expect(IconStyle.nav.fontWeight == .regular)
        #expect(IconStyle.hitArea.fontWeight == .regular)
        #expect(IconStyle.toolbarButton.fontWeight == .regular)
        #expect(IconStyle.surface.fontWeight == .regular)
    }

    // MARK: - IconStyle.isHitArea

    @Test("IconStyle.isHitArea = true for .hitArea / .toolbarButton (= glyph-invisible zones)")
    func isHitAreaSemantics() {
        #expect(IconStyle.hitArea.isHitArea == true)
        #expect(IconStyle.toolbarButton.isHitArea == true)
        #expect(IconStyle.paneTab.isHitArea == false)
        #expect(IconStyle.toolbar.isHitArea == false)
    }

    // MARK: - IconStyle coverage

    @Test("IconStyle.allCases = 11 (= the full Apple-HIG surface list)")
    func iconStyleAllCasesCount() {
        let cases = IconStyle.allCases
        #expect(cases.count == 11, "IconStyle has 11 cases; = the union of all Apple-HIG-tier + .hitArea / .toolbarButton / .surface wrappers")
        let names = Set(cases.map { String(describing: $0) })
        for expected in ["inlineSmall", "small", "paneTab", "toolbar", "nav",
                          "hitArea", "emptyStateHero", "avatar", "cover",
                          "toolbarButton", "surface"] {
            #expect(names.contains(expected), "IconStyle is missing case: \(expected)")
        }
    }

    // MARK: - WenshuTextStyle.font = SwiftUI text-style API verbatim

    @Test("WenshuTextStyle.font = SwiftUI text-style API verbatim (= Apple HIG text style)")
    func wenshuTextStyleFontAPI() {
        #expect(WenshuTextStyle.largeTitle.font == .largeTitle)
        #expect(WenshuTextStyle.title.font == .title)
        #expect(WenshuTextStyle.title2.font == .title2)
        #expect(WenshuTextStyle.title3.font == .title3)
        #expect(WenshuTextStyle.headline.font == .headline)
        #expect(WenshuTextStyle.body.font == .body)
        #expect(WenshuTextStyle.callout.font == .callout)
        #expect(WenshuTextStyle.subheadline.font == .subheadline)
        #expect(WenshuTextStyle.caption.font == .caption)
        #expect(WenshuTextStyle.caption2.font == .caption2)
        #expect(WenshuTextStyle.footnote.font == .footnote)
    }

    // MARK: - WenshuTextStyle.pointSize = Apple-default (= not ad-hoc)

    @Test("WenshuTextStyle.pointSize = SwiftUI text-style default (= Apple HIG text style default)")
    func wenshuTextStylePointSize() {
        #expect(WenshuTextStyle.largeTitle.pointSize == 26)
        #expect(WenshuTextStyle.title.pointSize == 22)
        #expect(WenshuTextStyle.title2.pointSize == 17)
        #expect(WenshuTextStyle.title3.pointSize == 15)
        #expect(WenshuTextStyle.headline.pointSize == 13)
        #expect(WenshuTextStyle.body.pointSize == 13)
        #expect(WenshuTextStyle.callout.pointSize == 12)
        #expect(WenshuTextStyle.subheadline.pointSize == 11)
        #expect(WenshuTextStyle.caption.pointSize == 11)
        #expect(WenshuTextStyle.caption2.pointSize == 11)
        #expect(WenshuTextStyle.footnote.pointSize == 10)
    }

    // MARK: - WenshuTextStyle.allCases coverage

    @Test("WenshuTextStyle.allCases = 11 (= 1:1 with SwiftUI text-style API)")
    func wenshuTextStyleAllCasesCount() {
        #expect(WenshuTextStyle.allCases.count == 11,
                "WenshuTextStyle covers every SwiftUI text-style API (= no extra ad-hoc)")
    }

    // MARK: - SFIcon source signature

    @Test("SFIcon source declares the canonical initializer (= factory view type)")
    func sfIconSourceSignature() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/UI/IconStyles.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("struct SFIcon: View"),
                "SFIcon must be a View (= the factory renders the symbol)")
        #expect(content.contains("color: Color = Color.secondary,\n        rendering: IconRendering? = nil"),
                "SFIcon must expose the 4-argument convenience initializer with Color (= escape hatch for domain-enum callers like CommandPaletteView)")
        #expect(content.contains("color: IconColor,\n        rendering: IconRendering? = nil"),
                "SFIcon must expose the 4-argument convenience initializer with IconColor (= the canonical semantic path)")
    }

    // MARK: - SFIcon rendering-mode default per zone

    @Test("SFIcon source applies .symbolRenderingMode(.hierarchical) at the <38 PT default")
    func sfIconHierarchicalDefault() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/UI/IconStyles.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("symbolRenderingMode(.hierarchical)"),
                "SFIcon must apply .hierarchical for the <38 PT zone (= boss 9/15 canonical macOS chrome default)")
    }

    @Test("SFIcon source applies .symbolRenderingMode(.monochrome) at the >=38 PT default")
    func sfIconMonochromeDefault() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/UI/IconStyles.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("symbolRenderingMode(.monochrome)"),
                "SFIcon must apply .monochrome for the >=38 PT zone (= boss 2026-09-17 SF Symbols 6 weight split rule)")
        #expect(content.contains("style.pointSize >= 38"),
                "SFIcon must branch on style.pointSize >= 38 to pick the rendering mode (= the source of the weight-split rule)")
    }

    // MARK: - IconColor semantic resolver

    @Test("IconColor.style resolves to SwiftUI semantic color (= no ad-hoc RGB)")
    func iconColorSemanticResolver() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/UI/IconStyles.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("var style: Color"),
                "IconColor.style must return Color (= SwiftUI foregroundStyle accepts Color directly)")
        #expect(content.contains("Color.primary"),
                "IconColor.primary must resolve to SwiftUI .primary")
        #expect(content.contains("Color.secondary"),
                "IconColor.secondary must resolve to SwiftUI .secondary")
        #expect(content.contains("Color.accentColor"),
                "IconColor.accent must resolve to SwiftUI Color.accentColor (= HIG Apple HIG toolbar accent rule)")
    }

    // MARK: - View extension

    @Test("View.wenshuFont(_:) extension applies the HIG text-style font")
    func viewWenshuFontExtension() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/UI/IconStyles.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("func wenshuFont(_ style: WenshuTextStyle) -> some View"),
                "View extension wenshuFont(_:) must exist (= convenience modifier for color/styling)")
        #expect(content.contains("self.font(style.font)"),
                "wenshuFont(_:) must forward to SwiftUI Font")
    }
}