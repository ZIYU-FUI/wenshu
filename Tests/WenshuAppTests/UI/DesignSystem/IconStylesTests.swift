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
//      2. IconStyle.fontWeight = .regular everywhere (no .thin anywhere)
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

    @Test("IconStyle.toolbar = 18 (= SwiftUI ControlSize.small / macOS toolbar default)")
    func toolbarPointSize() {
        #expect(IconStyle.toolbar.pointSize == 18)
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

    @Test("IconStyle.sidebar = 16 (= Apple Mail / Notes / Xcode sidebar row leading icon)")
    func sidebarPointSize() {
        #expect(IconStyle.sidebar.pointSize == 16)
    }

    // MARK: - IconStyle.fontWeight (uniform .regular)

    // a per-tier weight split has no register row and HIG bans thin labels
    // (= craft audit 2026-11-21 T4/X7).

    @Test("IconStyle.fontWeight = .regular for the >=38 PT zone (= hero / avatar / cover)")
    func fontWeightRegularForLargeZones() {
        #expect(IconStyle.emptyStateHero.fontWeight == .regular)
        #expect(IconStyle.avatar.fontWeight == .regular)
        #expect(IconStyle.cover.fontWeight == .regular)
    }

    @Test("IconStyle.fontWeight = .regular for the <38 PT zone")
    func fontWeightRegularForSmallZones() {
        #expect(IconStyle.inlineSmall.fontWeight == .regular)
        #expect(IconStyle.small.fontWeight == .regular)
        #expect(IconStyle.paneTab.fontWeight == .regular)
        #expect(IconStyle.toolbar.fontWeight == .regular)
        #expect(IconStyle.nav.fontWeight == .regular)
        #expect(IconStyle.hitArea.fontWeight == .regular)
        #expect(IconStyle.toolbarButton.fontWeight == .regular)
        #expect(IconStyle.surface.fontWeight == .regular)
        #expect(IconStyle.sidebar.fontWeight == .regular)
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

    @Test("IconStyle.allCases = 13 (= the full Apple-HIG surface list + sidebarTree)")
    func iconStyleAllCasesCount() {
        let cases = IconStyle.allCases
        #expect(cases.count == 13, "IconStyle has 13 cases; = the union of all Apple-HIG-tier + .hitArea / .toolbarButton / .surface / .sidebar / .sidebarTree wrappers")
        let names = Set(cases.map { String(describing: $0) })
        for expected in ["inlineSmall", "small", "paneTab", "toolbar", "nav",
                          "hitArea", "emptyStateHero", "avatar", "cover",
                          "toolbarButton", "surface", "sidebar", "sidebarTree"] {
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
        let url = SourceLocator.url("Sources/WenshuApp/Shared/UI/IconStyles.swift")
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
        let url = SourceLocator.url("Sources/WenshuApp/Shared/UI/IconStyles.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("symbolRenderingMode(.hierarchical)"),
                "SFIcon must apply .hierarchical for the <38 PT zone (= boss 9/15 canonical macOS chrome default)")
    }

    @Test("SFIcon source applies .symbolRenderingMode(.monochrome) at the >=38 PT default")
    func sfIconMonochromeDefault() throws {
        let url = SourceLocator.url("Sources/WenshuApp/Shared/UI/IconStyles.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("symbolRenderingMode(.monochrome)"),
                "SFIcon must apply .monochrome for the >=38 PT zone (= boss 2026-09-17 SF Symbols 6 weight split rule)")
        #expect(content.contains("style.pointSize >= 38"),
                "SFIcon must branch on style.pointSize >= 38 to pick the rendering mode (= the source of the weight-split rule)")
    }

    // MARK: - IconColor semantic resolver

    @Test("IconColor.style resolves to SwiftUI semantic color (= no ad-hoc RGB)")
    func iconColorSemanticResolver() throws {
        let url = SourceLocator.url("Sources/WenshuApp/Shared/UI/IconStyles.swift")
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
        let url = SourceLocator.url("Sources/WenshuApp/Shared/UI/WenshuTextStyle.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("func wenshuFont(_ style: WenshuTextStyle) -> some View"),
                "View extension wenshuFont(_:) must exist (= convenience modifier for color/styling)")
        #expect(content.contains("self.font(style.font)"),
                "wenshuFont(_:) must forward to SwiftUI Font")
    }

    // MARK: - Settings scene pane count = the icon factory's own comments

    @Test("the settings scene declares 10 SettingsPane cases and the icon factory comments agree (= 10-pane, no stale pane count)")
    func settingsPaneCountMatchesIconFactoryComments() throws {
        let settingViewURL = SourceLocator.url("Sources/WenshuApp/Features/Settings/View/SettingView.swift")
        let settingViewContent = try String(contentsOf: settingViewURL, encoding: .utf8)

        let enumRange = try #require(settingViewContent.range(of: "enum SettingsPane"),
                                     "the settings scene must declare an enum SettingsPane (= the left-column sidebar source)")
        let enumBlock = String(settingViewContent[enumRange.lowerBound...])
        let enumEnd = enumBlock.range(of: "\n    }")?.lowerBound ?? enumBlock.endIndex
        let enumBody = String(enumBlock[..<enumEnd])
        let caseDeclarations = enumBody.components(separatedBy: "\n").filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.hasPrefix("case ") && !trimmed.contains(":") && !trimmed.contains(".")
        }
        #expect(caseDeclarations.count == 10,
                "the SettingsPane enum must declare exactly 10 cases (= appearance / editor / network / providers / models / memory / agent / covers / archive / roles; = the pane count must never drift again)")

        let iconURL = SourceLocator.url("Sources/WenshuApp/Shared/UI/IconStyles.swift")
        let iconContent = try String(contentsOf: iconURL, encoding: .utf8)
        // The stale-count needle is assembled at runtime (= the literal
        // must not appear in this file either, or the repo-wide grep for
        // it would keep hitting this very assertion).
        let staleCountNeedle = "9" + "-pane"
        #expect(!iconContent.contains(staleCountNeedle),
                "the icon factory must not describe the settings scene with a stale pane count (= the enum declares 10 cases)")
        let tenPaneMentions = iconContent.components(separatedBy: "10-pane").count - 1
        #expect(tenPaneMentions == 2,
                "the icon factory must call the settings scene 10-pane in both of its comments (= the icon factory's count must match the enum's count)")
        #expect(!iconContent.contains("Apple System Settings 10-pane"),
                "the icon factory must not attribute a 10-pane count to Apple's System Settings (= that app's layout is not ours to count)")
    }
    // MARK: - A symbol beside text wears that text's own style

    @Test("The factory wears the text style it is given instead of the tier's font")
    func factoryAppliesTheMatchingTextStyle() throws {
        let url = SourceLocator.url("Sources/WenshuApp/Shared/UI/IconStyles.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("let matchingText: WenshuTextStyle?"),
                "the factory carries the text style a symbol sits beside")
        #expect(content.contains("plainImage.font($0.font)"),
                "a named text style decides the symbol's font on its own (= the style carries both its size and its weight, so the zone tier's font is never applied underneath it)")
    }

    @Test("Every symbol in a measured caption row names the text beside it")
    func symbolsBesideTextNameTheirStyle() throws {
        // The caption rows the factory is checked in: a symbol in one of
        // them is a prefix of a caption, so its size is the caption's and
        // not a zone's.
        let measuredFiles = [
            "Sources/WenshuApp/Features/Chat/View/ChatMessageFooter.swift",
            "Sources/WenshuApp/Features/Chat/View/ChatPlanPartView.swift",
            "Sources/WenshuApp/Features/Chat/View/ChatToolDiffPreview.swift",
            "Sources/WenshuApp/Features/Chat/View/ChatToolResultPartView.swift",
            "Sources/WenshuApp/Features/Chat/View/ChatToolUsePartView.swift",
            "Sources/WenshuApp/Features/Agent/View/MemoryRetrievalPanel.swift",
            "Sources/WenshuApp/Features/Agent/View/ImportSheetViewPieces.swift",
        ]
        // A control's own icon slot is not a caption's neighbour: its label is
        // the control's text, so the zone tier decides its glyph.
        let controlSlots = ["play.fill"]
        var matchedSymbols = 0
        for file in measuredFiles {
            let content = try String(contentsOf: SourceLocator.url(file), encoding: .utf8)
            for range in Self.sfIconCallRanges(in: content) {
                let call = String(content[range])
                if controlSlots.contains(where: { call.contains($0) }) {
                    #expect(!call.contains("matchingText:"),
                            "\(file): a control's own icon slot keeps its zone tier (= naming a text style for it would size the glyph off a caption it does not sit in)")
                    continue
                }
                guard let named = Self.namedTextStyle(of: call) else {
                    Issue.record("\(file): a symbol in a caption row sizes itself off a zone tier (= no matchingText named): \(call.prefix(72))")
                    continue
                }
                matchedSymbols += 1
                if let beside = Self.firstTextStyle(after: range, in: content) {
                    #expect(named == beside,
                            "\(file): the symbol wears \(named) while the text beside it is \(beside)")
                }
            }
        }
        #expect(matchedSymbols == 12,
                "the twelve measured caption-row symbols are the census this rule covers (= a new one joins it, a removed one leaves it)")
    }

    /// The range of every `SFIcon(` call in a file (= balanced parentheses,
    /// and a call spelled inside a comment is not a call).
    private static func sfIconCallRanges(in content: String) -> [Range<String.Index>] {
        var found: [Range<String.Index>] = []
        let needle = "SFIcon("
        var cursor = content.startIndex
        while let open = content.range(of: needle, range: cursor..<content.endIndex) {
            cursor = open.upperBound
            let lineStart = content[content.startIndex..<open.lowerBound]
                .lastIndex(of: "\n").map { content.index(after: $0) } ?? content.startIndex
            if content[lineStart..<open.lowerBound].contains("//") { continue }
            var depth = 0
            var scan = open.upperBound
            while scan < content.endIndex {
                let character = content[scan]
                if character == "(" {
                    depth += 1
                } else if character == ")" {
                    if depth == 0 {
                        found.append(Range(uncheckedBounds: (open.lowerBound, content.index(after: scan))))
                        break
                    }
                    depth -= 1
                }
                scan = content.index(after: scan)
            }
        }
        return found
    }

    /// The text style a call names, or nil when it names none.
    private static func namedTextStyle(of call: String) -> String? {
        guard let at = call.range(of: "matchingText: .") else { return nil }
        return call[at.upperBound...].prefix(while: { $0.isLetter || $0.isNumber }).lowercased()
    }

    /// The first `.font(.<style>` after a call (= the style of the text the
    /// symbol sits beside, in the same row).
    private static func firstTextStyle(after call: Range<String.Index>, in content: String) -> String? {
        let window = content[call.upperBound...].prefix(400)
        guard let at = window.range(of: ".font(.") else { return nil }
        return window[at.upperBound...].prefix(while: { $0.isLetter || $0.isNumber }).lowercased()
    }
}
