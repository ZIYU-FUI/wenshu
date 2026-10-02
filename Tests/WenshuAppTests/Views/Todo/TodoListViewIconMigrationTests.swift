//
//  TodoListViewIconMigrationTests.swift · Wenshu · v3.0
//
//  Per Q112 = 1 source + 1 test per ticket. TodoListView
//  6 inline icons swept to SFIcon(.inlineSmall):
//  - ellipsis (= menu trigger; IconColor.secondary)
//  - calendar (= due-date prefix; .secondary)
//  - circle (= pending status toggle; .secondary)
//  - circle.dotted (= in-progress status toggle; .tint)
//  - checkmark.circle (= completed status toggle; IconColor.green)
//  - xmark.circle (= cancelled status display; IconColor.tertiary = the
//    canonical mapping of DesignTokens.statusForeground = .tertiary)
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("TodoListView icon sweep")
struct TodoListViewIconMigrationTests {

    @Test("TodoListView source no longer uses naked Image(systemName:)")
    func sourceNoLongerUsesNakedImage() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Views/Todo/TodoListView.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        let stripped = content.components(separatedBy: "\n").filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return !trimmed.hasPrefix("//") && !trimmed.hasPrefix("*") && !trimmed.hasPrefix("/*")
        }.joined(separator: "\n")
        #expect(!stripped.contains("Image(systemName:"),
                "TodoListView must drop naked Image(systemName:) for the v3.0 sweep")
    }

    @Test("TodoListView 6 inline icons use SFIcon with semantic IconColor tokens")
    func inlineIconsUseSFIcon() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Views/Todo/TodoListView.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("SFIcon(\"ellipsis\", style: .inlineSmall, color: IconColor.secondary)"),
                "TodoListView ellipsis menu trigger must use SFIcon")
        #expect(content.contains("SFIcon(\"calendar\", style: .inlineSmall, color: IconColor.secondary)"),
                "TodoListView calendar due-date prefix must use SFIcon")
        #expect(content.contains("SFIcon(\"circle\", style: .inlineSmall, color: IconColor.secondary)"),
                "TodoListView pending status toggle must use SFIcon")
        #expect(content.contains("SFIcon(\"circle.dotted\", style: .inlineSmall, color: IconColor.tint)"),
                "TodoListView in-progress status toggle must use SFIcon")
        #expect(content.contains("SFIcon(\"checkmark.circle\", style: .inlineSmall, color: IconColor.green)"),
                "TodoListView completed status toggle must use SFIcon")
        #expect(content.contains("SFIcon(\"xmark.circle\", style: .inlineSmall, color: IconColor.tertiary)"),
                "TodoListView cancelled status display must use SFIcon")
    }
}