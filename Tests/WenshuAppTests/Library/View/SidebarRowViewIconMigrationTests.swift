//
//  SidebarRowViewIconMigrationTests.swift · Wenshu · v3.0
//
//  Per the per-commit 1-source-1-test rule. SidebarRowView row
//  leading icon = the central factory's SFLabelRow surface
//  (= Apple HIG sidebar-row purpose-built factory). Per
//  (see OOB.md #2026-10-06) "中央工厂保留 / 按应用位置不同加工":
//  each application position gets its own purpose-built surface.
//  SFLabelRow is the sidebar-row surface; it internally delegates
//  to Apple HIG Label view per Apple's recommended pattern.
//

import Foundation
import SwiftUI
import Testing
@testable import WenshuApp

@Suite("SidebarRowView icon sweep")
struct SidebarRowViewIconMigrationTests {

    @Test("SidebarRowView source no longer uses naked Image(systemName:)")
    func sourceNoLongerUsesNakedImage() throws {
        let url = SourceLocator.url("Sources/WenshuApp/Features/Library/View/SidebarRowView.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        let stripped = content.components(separatedBy: "\n").filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return !trimmed.hasPrefix("//") && !trimmed.hasPrefix("*") && !trimmed.hasPrefix("/*")
        }.joined(separator: "\n")
        #expect(!stripped.contains("Image(systemName:"),
                "SidebarRowView must drop naked Image(systemName:) for the v3.0 sweep")
    }

    @Test("SidebarRowView row leading glyph renders through the central icon factory")
    func rowUsesCentralIconFactory() throws {
        let url = SourceLocator.url("Sources/WenshuApp/Features/Library/View/SidebarRowView.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        // The row's leading glyph goes through the central icon factory,
        // with a semantic colour token and the metrics from the token
        // file. The row does NOT render via the `SFLabelRow` wrapper:
        // that wrapper's slot is the canonical 16 PT one, and this row's
        // glyph is a pinyin letter circle that the 16 PT slot clips (=
        // the row draws its own slot, = the tree's own tier).
        #expect(content.contains("SFIcon("),
                "SidebarRowView's leading glyph must render via the central SFIcon factory")
        #expect(content.contains("IconColor."),
                "SidebarRowView's leading glyph must carry an IconColor token (= no inline colour)")
        #expect(content.contains("DesignTokens.listRowLeadingIconColumnWidth"),
                "SidebarRowView's leading icon slot must size itself from the token file")
        #expect(!content.contains("SFLabelRow("),
                "SidebarRowView must not render via SFLabelRow (= its 16 PT slot clips the letter-circle glyph)")
    }
}