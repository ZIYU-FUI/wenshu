//
//  TagManagerViewIconMigrationTests.swift · Wenshu · v3.0
//
//  Per Q112 = 1 source + 1 test per ticket. TagManagerView icon
//  sweep: the 2 inline list-row leading icon sites (tagRow,
//  applicationRow) replaced their `Image(systemName: x).imageScale
//  (.small).foregroundStyle(.tint).frame(width: DesignTokens.tabIcon
//  Size)` (= 14 PT SF Symbol pinned to a 18 PT wenshu-ad-hoc frame)
//  with `SFIcon(x, style: .inlineSmall, color: .tint)` (= Apple HIG
//  list-row leading inline = 14 PT, no frame pin).
//
//  Source-level assertions verify that:
//      1. TagManagerView source no longer uses DesignTokens.tabIconSize
//         for leading inline icons (= the sweep target was removed).
//      2. TagManagerView source calls SFIcon with style: .inlineSmall
//         in the 2 sweep sites (= tagRow + applicationRow).
//      3. The wenshu-icon-policy surface in IconStyles.swift is in
//         place (= the SFIcon factory + .inlineSmall case are
//         present).
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("TagManagerView icon sweep (= inline leading migrated to SFIcon)")
struct TagManagerViewIconMigrationTests {

    @Test("TagManagerView source no longer uses DesignTokens.tabIconSize")
    func tagManagerViewNoLongerUsesTabIconSize() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Views/SpecializedTools/TagManagerView.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(!content.contains("DesignTokens.tabIconSize"),
                "TagManagerView must drop DesignTokens.tabIconSize for inline leading icons (= wenshu-ad-hoc 18 PT pin removed; = SFIcon owns the size now)")
    }

    @Test("TagManagerView tagRow uses SFIcon style: .inlineSmall")
    func tagManagerViewTagRowUsesSFIcon() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Views/SpecializedTools/TagManagerView.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("SFIcon(tag.category.icon, style: .inlineSmall, color: .tint)"),
                "tagRow must render the category icon via SFIcon(.inlineSmall) (= the migrated inline-leading site)")
    }

    @Test("TagManagerView applicationRow uses SFIcon style: .inlineSmall")
    func tagManagerViewApplicationRowUsesSFIcon() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Views/SpecializedTools/TagManagerView.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("SFIcon(application.target.icon, style: .inlineSmall, color: .tint)"),
                "applicationRow must render the target icon via SFIcon(.inlineSmall) (= the migrated inline-leading site)")
    }

    @Test("IconStyles.swift surface = SFIcon + .inlineSmall case present")
    func iconStylesSurfaceIsInPlace() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/UI/IconStyles.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("struct SFIcon: View"),
                "SFIcon factory must be present (= the sweep target)")
        #expect(content.contains("case inlineSmall"),
                ".inlineSmall case must be present (= the migrated surface)")
        #expect(content.contains("case .inlineSmall: 14"),
                ".inlineSmall must resolve to 14 PT (= Apple HIG list-row leading inline)")
    }
}