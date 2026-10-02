//
//  EmptyStateViewIconMigrationTests.swift · Wenshu · v3.0
//
//  Per Q112 = 1 source + 1 test per ticket. EmptyStateView's hero icon
//  migrated from the ad-hoc
//  `Image+resizable+aspectRatio+frame(76)+symbolRenderingMode(.monochrome)
//  +foregroundStyle(.secondary)` chain to `SFIcon(.emptyStateHero, .secondary)`.
//
//  Source-level assertions verify:
//      1. EmptyStateView no longer references DesignTokens.emptyStateIconSize
//      2. EmptyStateView uses SFIcon style: .emptyStateHero
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("EmptyStateView icon sweep (= hero icon migrated to SFIcon)")
struct EmptyStateViewIconMigrationTests {

    @Test("EmptyStateView source no longer uses DesignTokens.emptyStateIconSize in production code")
    func emptyStateViewNoLongerUsesEmptyStateIconSize() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/UI/EmptyState/EmptyStateView.swift")
        let raw = try String(contentsOf: url, encoding: .utf8)
        // Strip comment lines so doc-comment cross-references don't false-positive.
        let stripped = raw.components(separatedBy: "\n").filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return !trimmed.hasPrefix("//") && !trimmed.hasPrefix("*") && !trimmed.hasPrefix("/*")
        }.joined(separator: "\n")
        #expect(!stripped.contains("DesignTokens.emptyStateIconSize"),
                "EmptyStateView must drop DesignTokens.emptyStateIconSize in production code (= the doc-comment reference on L68 is allowed but no production-code path uses it)")
    }

    @Test("EmptyStateView hero icon uses SFIcon style: .emptyStateHero + .secondary")
    func emptyStateViewHeroUsesSFIcon() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/UI/EmptyState/EmptyStateView.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("SFIcon(icon, style: .emptyStateHero, color: IconColor.secondary)"),
                "EmptyStateView hero icon must render via SFIcon(.emptyStateHero, .secondary)")
    }
}