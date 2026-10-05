//
//  PlaceholderViewRound3IconMigrationTests.swift · Wenshu · v3.0
//
//  Per Q112 = 1 source + 1 test per ticket. PlaceholderView
//  sweep round 3 — sweeps the remaining 5 standalone Image(systemName:)
//  sites (resolved / retry / dropped / remove / preview action buttons)
//  to SFIcon(.inlineSmall, semantic IconColor).
//
//  Distinct from PlaceholderViewIconMigrationTests (= the round 1 test
//  that swept `DesignTokens.tabIconSize` to `SFIcon(.inlineSmall)`).
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("PlaceholderView round-3 icon sweep (= 5 standalone action buttons to SFIcon)")
struct PlaceholderViewRound3IconMigrationTests {

    @Test("PlaceholderView round-3 source no naked Image(systemName:) outside Label icon slots")
    func sourceNoNakedImageInStandalone() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Views/Tools/PlaceholderView.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        let stripped = content.components(separatedBy: "\n").filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("//") || trimmed.hasPrefix("*") || trimmed.hasPrefix("/*") { return false }
            if trimmed.contains("icon: { Image(systemName:") { return false }
            return true
        }.joined(separator: "\n")
        #expect(!stripped.contains("Image(systemName:"),
                "PlaceholderView must drop naked Image(systemName:) in standalone sites for the v3.0 sweep round 3")
    }

    @Test("PlaceholderView round-3 5 inline icons use SFIcon")
    func fiveInlineIconsUseSFIcon() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Views/Tools/PlaceholderView.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("SFIcon(\"checkmark\", style: .inlineSmall, color: IconColor.green)"),
                "PlaceholderView checkmark resolved must use SFIcon")
        #expect(content.contains("SFIcon(\"arrow.counterclockwise\", style: .inlineSmall, color: IconColor.secondary)"),
                "PlaceholderView arrow.counterclockwise retry must use SFIcon")
        #expect(content.contains("SFIcon(\"xmark.circle\", style: .inlineSmall, color: IconColor.tertiary)"),
                "PlaceholderView xmark.circle dropped must use SFIcon")
        #expect(content.contains("SFIcon(\"trash\", style: .inlineSmall, color: IconColor.secondary)"),
                "PlaceholderView trash remove must use SFIcon")
        #expect(content.contains("SFIcon(\"viewfinder\", style: .inlineSmall, color: IconColor.tint)"),
                "PlaceholderView viewfinder preview must use SFIcon")
    }

    @Test("PlaceholderViewState mirror exists (= business state hoisted out of @State per v1.72 MVVM split)")
    func testStateMirrorExists() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Views/Tools/PlaceholderView.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("PlaceholderViewState"),
                "PlaceholderView must reference PlaceholderViewState mirror")
        #expect(content.contains("@State private var state = PlaceholderViewState()"),
                "PlaceholderView must hold state via @State mirror (not bare @State vars)")
        let bareRows = content.contains("@State private var rows: [Placeholder]")
        let bareLastScan = content.contains("@State private var lastScanCount: Int? = nil")
        let bareLoading = content.contains("@State private var loadingState: LoadStatus = .idle")
        let bareErrorText = content.contains("@State private var errorText: String?")
        #expect(!bareRows, "rows must NOT be a bare @State var")
        #expect(!bareLastScan, "lastScanCount must NOT be a bare @State var")
        #expect(!bareLoading, "loadingState must NOT be a bare @State var (use SpecializedToolLoadStatus)")
        #expect(!bareErrorText, "errorText must NOT be a bare @State var")
    }
}