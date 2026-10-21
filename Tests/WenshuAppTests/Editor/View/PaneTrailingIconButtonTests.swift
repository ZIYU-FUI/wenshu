// PaneTrailingIconButtonTests.swift · Wenshu
//
// PaneTrailingIconButton is the canonical trailing-button helper for a
// tab bar's trailing slot (= the editor's expand/shrink button). It
// lives in its own file since PaneTabBar.swift was deleted
// (= PaneTabBar / PaneTabItem / PaneIconTab had 0 constructors; only
// PaneTrailingIconButton had a live caller).
//
// It is a View type, so per the wenshu test convention it is
// exercised through source-level assertions (= value types +
// source-level assertions, not ViewInspector).
//
// Coverage:
//   1. the type is @MainActor (= macOS SwiftUI main-thread only)
//   2. it renders the 28 PT hot area (= Apple HIG minimum tap target)
//   3. it uses the .plain buttonStyle + .hoverWash() background
//      (= the icon-only button shape shared with PaneIconTab)
//   4. it takes the icon / tooltip / action surface verbatim

import Foundation
import SwiftUI
import Testing
@testable import WenshuApp

@Suite("PaneTrailingIconButton (= tab bar trailing-slot button)")
struct PaneTrailingIconButtonTests {

    private static let sourcePath =
        "Sources/WenshuApp/Shared/UI/PaneTrailingIconButton.swift"

    @Test("PaneTrailingIconButton source is @MainActor")
    func sourceIsMainActor() throws {
        let content = try String(
            contentsOf: SourceLocator.url(Self.sourcePath), encoding: .utf8)
        #expect(content.contains("@MainActor"),
                "PaneTrailingIconButton must be @MainActor (= macOS SwiftUI main-thread only)")
        #expect(content.contains("struct PaneTrailingIconButton: View"),
                "the type must still be named PaneTrailingIconButton")
    }

    @Test("PaneTrailingIconButton renders the 28 PT Apple HIG hot area")
    func rendersHotArea() throws {
        let content = try String(
            contentsOf: SourceLocator.url(Self.sourcePath), encoding: .utf8)
        #expect(content.contains("DesignTokens.paneTabHotArea"),
                "the hot area must read DesignTokens.paneTabHotArea (= Apple HIG 28 PT minimum tap target)")
        #expect(content.contains("Color.clear"),
                "the hit area must be a Color.clear overlay")
        #expect(content.contains(".contentShape(Rectangle())"),
                "the hit area must extend the tap target via .contentShape(Rectangle())")
    }

    @Test("PaneTrailingIconButton uses the plain style + hover wash")
    func usesPlainStyleAndHoverWash() throws {
        let content = try String(
            contentsOf: SourceLocator.url(Self.sourcePath), encoding: .utf8)
        #expect(content.contains(".buttonStyle(.plain)"),
                "the button must use .buttonStyle(.plain) (= the icon-only shape)")
        #expect(content.contains(".hoverWash()"),
                "the button must use .hoverWash() for the background wash")
        #expect(content.contains("style: .paneTab"),
                "the icon must use the .paneTab icon style")
    }

    @Test("PaneTrailingIconButton exposes the icon / tooltip / action surface")
    func exposesInitSurface() throws {
        let content = try String(
            contentsOf: SourceLocator.url(Self.sourcePath), encoding: .utf8)
        #expect(content.contains("let icon: String"), "init must take an icon")
        #expect(content.contains("let tooltip: String"), "init must take a tooltip")
        #expect(content.contains("let action: () -> Void"), "init must take an action")
        #expect(content.contains(".help(tooltip)"),
                "the tooltip must be wired to .help")
    }
}
