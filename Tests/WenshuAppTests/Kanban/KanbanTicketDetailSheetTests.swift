//
//  Views/Kanban/KanbanTicketDetailSheetTests.swift · kanban-detail-sheet 2026-09-28
//
//  the kanban detail sheet (Phase 2 of the kanban-markdown arc).
//  Phase 1 added inline MD rendering on the card body. Phase 2 adds a
//  full-body sheet that the user opens by clicking the card, mirroring
//  hermes 0.21.5 drawer.tsx DescriptionSection + TaskMarkdown pattern.
//
//  Two surfaces asserted here:
//  - source-level: a sheet file exists, contains the expected API,
//    uses ChatTextPartView.parseMarkdown for the body (= 1 markdown
//    pipeline = no per-surface parser).
//  - behavior: KanbanView wires the sheet to KanbanCard via a tappable
//    surface; = clicking the card opens the sheet.
//
//  Repo-root walk: Tests/WenshuAppTests/Views/Kanban/*.swift → 5 dirs up.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("KanbanTicketDetailSheet (kanban-detail-sheet 2026-09-28)")
struct KanbanTicketDetailSheetTests {

    private func repoRootFromTestFile() -> URL {
        var url = SourceLocator.repoRoot
        return url
    }

    @Test("KanbanTicketDetailSheet.swift exists and references ChatTextPartView.parseMarkdown")
    func sourceLevelSheetRenderer() throws {
        let path = repoRootFromTestFile()
            .appendingPathComponent("Sources/WenshuApp/Features/Kanban/View/KanbanTicketDetailSheet.swift")
        let text = try String(contentsOf: path, encoding: .utf8)
        // The sheet must re-use chat's markdown helper (= 1:1 with hermes 0.21.5
        // reusing MessageTextContent across surfaces).
        #expect(text.contains("ChatTextPartView.parseMarkdown"))
        #expect(text.contains("struct KanbanTicketDetailSheet"))
    }

    @Test("KanbanView.swift wires the sheet via .sheet(item:) tied to a card tap")
    func sourceLevelWiring() throws {
        let path = repoRootFromTestFile()
            .appendingPathComponent("Sources/WenshuApp/Features/Kanban/View/KanbanView.swift")
        let text = try String(contentsOf: path, encoding: .utf8)
        // The wire-up must:
        //  - declare a sheet item binding (@State var ... ticket: KanbanTicket?)
        //  - attach .sheet(item: ...) to the column OR to KanbanCard
        //  - expose a tap surface (.onTapGesture / Button / etc.) on KanbanCard
        //  - point the sheet at KanbanTicketDetailSheet
        #expect(text.contains("KanbanTicketDetailSheet"))
        #expect(text.contains(".sheet("))
        #expect(text.contains(".onTapGesture") || text.contains("Button("))
    }

    /// The sheet agrees with the card: the owner reads first, and only when
    /// the card names one.
    @Test("the sheet renders the assignee above the title (= source-level)")
    func sourceLevelOwnerLine() throws {
        let path = repoRootFromTestFile()
            .appendingPathComponent("Sources/WenshuApp/Features/Kanban/View/KanbanTicketDetailSheet.swift")
        let lines = try String(contentsOf: path, encoding: .utf8).components(separatedBy: "\n")
        let owner = try #require(lines.firstIndex { $0.contains("Text(assignee)") },
                                 "the sheet must draw the assignee line")
        let title = try #require(lines.firstIndex { $0.contains("Text(task.title)") },
                                 "the sheet must draw the title")
        #expect(owner < title, "the sheet names the owner before the work")
        #expect(lines.contains { $0.contains("if let assignee = task.assignee, !assignee.isEmpty") },
                "the owner line must be gated on a named assignee")
    }
}
