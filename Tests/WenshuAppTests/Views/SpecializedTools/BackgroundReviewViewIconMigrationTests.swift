//
//  BackgroundReviewViewIconMigrationTests.swift · Wenshu · v3.0
//
//  Per Q112 = 1 source + 1 test per ticket. BackgroundReviewView
//  proposal-row icon migration: the kind icon site
//  `Image(systemName: proposalIcon(for: proposal.kind)).foregroundStyle(proposalColor(for: proposal.kind))`
//  replaced with `SFIcon(name, style: .inlineSmall, color: Color)`.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("BackgroundReviewView icon sweep")
struct BackgroundReviewViewIconMigrationTests {

    @Test("BackgroundReviewView source no longer uses naked Image(systemName:)")
    func sourceNoLongerUsesNakedImage() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Views/SpecializedTools/BackgroundReviewView.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        let stripped = content.components(separatedBy: "\n").filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return !trimmed.hasPrefix("//") && !trimmed.hasPrefix("*") && !trimmed.hasPrefix("/*")
        }.joined(separator: "\n")
        #expect(!stripped.contains("Image(systemName:"),
                "BackgroundReviewView must drop naked Image(systemName:) for the v3.0 sweep")
    }

    @Test("BackgroundReviewView kind-icon uses SFIcon with Color escape hatch")
    func kindIconUsesSFIcon() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Views/SpecializedTools/BackgroundReviewView.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("SFIcon(\n                    proposalIcon") && content.contains("color: proposalColor"),
                "BackgroundReviewView kind-icon must render via SFIcon(.inlineSmall, proposalColor)")
    }
}