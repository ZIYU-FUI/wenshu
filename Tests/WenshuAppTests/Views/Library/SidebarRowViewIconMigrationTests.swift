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
import Testing
@testable import WenshuApp

@Suite("SidebarRowView icon sweep")
struct SidebarRowViewIconMigrationTests {

    @Test("SidebarRowView source no longer uses naked Image(systemName:)")
    func sourceNoLongerUsesNakedImage() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Views/Library/SidebarRowView.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        let stripped = content.components(separatedBy: "\n").filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return !trimmed.hasPrefix("//") && !trimmed.hasPrefix("*") && !trimmed.hasPrefix("/*")
        }.joined(separator: "\n")
        #expect(!stripped.contains("Image(systemName:"),
                "SidebarRowView must drop naked Image(systemName:) for the v3.0 sweep")
    }

    @Test("SidebarRowView row uses the central SFLabelRow factory (= Apple HIG sidebar row surface)")
    func rowUsesCentralLabelRowFactory() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Views/Library/SidebarRowView.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("SFLabelRow("),
                "SidebarRowView row must render via the central SFLabelRow factory (= Apple HIG sidebar-row surface)")
    }
}