//
//  SubAgentProgressViewIconMigrationTests.swift · Wenshu · v3.0
//
//  Per Q112 = 1 source + 1 test per ticket. SubAgentProgressView
//  statusIcon switch swept 4 status icons to SFIcon(.inlineSmall,
//  IconColor.x):
//  - circle.dashed (IconColor.blue)
//  - checkmark.circle (IconColor.green)
//  - xmark.circle (IconColor.red)
//  - circle (DesignTokens.statusForeground Color escape hatch)
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("SubAgentProgressView icon sweep")
struct SubAgentProgressViewIconMigrationTests {

    @Test("SubAgentProgressView source no longer uses naked Image(systemName:)")
    func sourceNoLongerUsesNakedImage() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Views/Kanban/SubAgentProgressView.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        let stripped = content.components(separatedBy: "\n").filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return !trimmed.hasPrefix("//") && !trimmed.hasPrefix("*") && !trimmed.hasPrefix("/*")
        }.joined(separator: "\n")
        #expect(!stripped.contains("Image(systemName:"),
                "SubAgentProgressView must drop naked Image(systemName:) for the v3.0 sweep")
    }

    @Test("SubAgentProgressView 4 status icons use SFIcon with IconColor semantic tokens")
    func statusIconsUseSFIcon() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Views/Kanban/SubAgentProgressView.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("SFIcon(\"circle.dashed\", style: .inlineSmall, color: IconColor.blue)"),
                "SubAgentProgressView circle.dashed status icon must use SFIcon")
        #expect(content.contains("SFIcon(\"checkmark.circle\", style: .inlineSmall, color: IconColor.green)"),
                "SubAgentProgressView checkmark.circle status icon must use SFIcon")
        #expect(content.contains("SFIcon(\"xmark.circle\", style: .inlineSmall, color: IconColor.red)"),
                "SubAgentProgressView xmark.circle status icon must use SFIcon")
        #expect(content.contains("SFIcon(\"circle\", style: .inlineSmall, color: IconColor.tertiary)"),
                "SubAgentProgressView default circle status icon must use SFIcon")
    }
}