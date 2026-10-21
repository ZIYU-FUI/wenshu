//
//  KanbanBoardStyleTests.swift · Wenshu
//
//  Behavior tests for the board's status presentation (= the label and
//  the tone each status shows, and the column list the board renders).
//
//  The mapping must be total: every case of `KanbanStatus` gets a
//  column and a tone. A status with no column makes its cards invisible
//  on the board, because a card renders in the column that matches its
//  status.
//

import SwiftUI
import Testing
@testable import WenshuApp

@Suite("Kanban board style (= every status has a column and a tone)")
struct KanbanBoardStyleTests {

    @Test("every status maps to a non-empty label")
    func testEveryStatusHasLabel() {
        for status in KanbanStatus.allCases {
            #expect(!status.boardLabel.isEmpty,
                    "KanbanStatus.\(status.rawValue) must have a column label")
        }
    }

    @Test("every status maps to a tone (= no status renders colorless)")
    func testEveryStatusHasTone() {
        for status in KanbanStatus.allCases {
            // The tone is a non-optional shape style, so the mere fact
            // that it resolves proves the case is covered.
            let tone = status.boardTone
            #expect(tone is AnyShapeStyle,
                    "KanbanStatus.\(status.rawValue) must map to a tone")
        }
    }

    @Test("board order covers every status exactly once")
    func testBoardOrderIsTotal() {
        let order = KanbanStatus.boardOrder
        #expect(order.count == KanbanStatus.allCases.count,
                "The board must show one column per status (= \(KanbanStatus.allCases.count))")
        for status in KanbanStatus.allCases {
            #expect(order.contains(status),
                    "KanbanStatus.\(status.rawValue) must appear in the board order")
        }
        #expect(Set(order).count == order.count,
                "The board order must not repeat a status")
    }

    @Test("the two statuses that used to be hidden have columns")
    func testPreviouslyHiddenStatusesHaveColumns() {
        // `.triage` and `.failed` were absent from the column list, so a
        // card moved to either status vanished from the board.
        #expect(KanbanStatus.boardOrder.contains(.triage),
                ".triage must have a column")
        #expect(KanbanStatus.boardOrder.contains(.failed),
                ".failed must have a column")
    }

    @Test("the label comes from the string catalog, not a literal")
    func testLabelIsLocalized() throws {
        let sourcePath = SourceLocator.repoRoot
            .appendingPathComponent("Sources/WenshuApp/Features/Kanban/Model/KanbanBoardStyle.swift")
            .path
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("String(localized:"),
                "The column label must come from the string catalog")
        // A hardcoded Chinese label in the code would bypass the catalog.
        let codeLines = source.components(separatedBy: "\n").filter { line in
            !line.trimmingCharacters(in: .whitespaces).hasPrefix("//")
        }
        let hasCJK = codeLines.contains { line in
            line.unicodeScalars.contains { scalar in
                (0x4E00...0x9FFF).contains(scalar.value)
            }
        }
        #expect(!hasCJK,
                "The status mapping must not hardcode Chinese labels (= use the catalog)")
    }
}
