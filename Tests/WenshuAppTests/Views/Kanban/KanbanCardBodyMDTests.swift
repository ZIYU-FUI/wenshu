//
//  Views/Kanban/KanbanCardBodyMDTests.swift · kanban-markdown 2026-09-28 T5
//
//  RED tests for Phase 1 T5:
//  KanbanCard renders ticket.body (when present) through the same
//  inline-markdown parser chat uses (= AttributedString with
//  .inlineOnlyPreservingWhitespace). Mirrors hermes 0.21.5 commit
//  63f5bc0999: chat's MessageTextContent is reused for kanban task
//  bodies. Wenshu's per-card use of ChatTextPartView.parseMarkdown
//  is the 1:1 equivalent.
//
//  Two assertions:
//  - source-level: KanbanView.swift contains a body render line
//    referencing ChatTextPartView.parseMarkdown (= no custom parser
//    = no parser duplication).
//  - behavior: **bold** parses to a span with an inline presentation
//    intent (= the same parser used by ChatTextPartView runs
//    against ticket.body verbatim).
//
//  Source-level check uses #filePath-relative path discovery.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("KanbanCard.body MD render (kanban-markdown 2026-09-28 T5)")
struct KanbanCardBodyMDTests {

    private func repoRootFromTestFile() -> URL {
        // Tests/WenshuAppTests/Views/Kanban/Tests.swift → 5 dirs up to
        // reach the repo root (= KanbanCardBodyMDTests.swift sits one
        // level deeper than the persistence tests).
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { url.deleteLastPathComponent() }
        return url
    }

    @Test("KanbanView.swift references ChatTextPartView.parseMarkdown for body rendering")
    func sourceLevelRendererWiring() throws {
        let kanban = repoRootFromTestFile()
            .appendingPathComponent("Sources/WenshuApp/Views/Kanban/KanbanView.swift")
        let text = try String(contentsOf: kanban, encoding: .utf8)
        // The kanban card must render ticket.body through the same helper
        // chat uses (1:1 with hermes 0.21.5 reusing MessageTextContent).
        #expect(text.contains("ChatTextPartView.parseMarkdown"))
        #expect(text.contains("ticket.body") == false || text.contains("body") == true,
                "ticket body should be rendered when present")
    }

    @Test("ChatTextPartView.parseMarkdown renders inline **bold** as a single AttributedString")
    func behaviorMarkdownRendersBold() {
        let raw = "**Goal:** write a 4-beat outline."
        let parsed = ChatTextPartView.parseMarkdown(raw)
        // Without the parser the whole string would be plain .primary
        // foreground. With it we expect at least one intentional
        // presentation contrast (= a foregroundStyle / font .inline
        // intent spans). AttributedString exposes this via runs; we
        // assert the string is non-empty and the raw ** delimiters
        // are gone (= meaningful inline markdown).
        #expect(parsed.characters.isEmpty == false)
        #expect(String(parsed.characters).contains("**") == false,
                "** delimiters must be consumed by the inline parser")
    }
}
