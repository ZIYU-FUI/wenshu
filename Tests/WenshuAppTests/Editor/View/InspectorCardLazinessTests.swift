//
//  InspectorCardLazinessTests.swift
//  wenshu
//
//  The three inspector card pages (= the trailing column's status,
//  todo and task pages) and the cost of drawing them.
//
//  Each page draws a list of cards, and a card list that is drawn
//  EAGERLY costs the whole list on every body pass (= every card's
//  body is built, = even the cards that are off screen). So the three
//  pages are held to the shape that keeps the cost to what the user
//  can see:
//
//  - The STATUS page's clock lives in the one card that shows a time
//    (= the elapsed label), = and not on the page (= a page-level
//    tick rebuilt every card on the page once a second, = including
//    the cards that show no time at all).
//  - The TODO page's cards sit in a LAZY stack, = so a body pass
//    builds the cards on screen and not every card in the plan.
//  - The BOARD's cards sit in a LAZY stack, = and a task's body is
//    parsed ONCE (= at the board's load), = not once per card per
//    body pass.
//
//  The page is a View, so per the wenshu test convention its shape
//  is asserted at the source level (= the same style the kanban
//  markdown suite uses), = and the values behind the pages are
//  exercised through the value types.
//
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("Inspector card pages: lazy lists and scoped clocks")
struct InspectorCardLazinessTests {
    // MARK: - Fixtures

    /// The repo root (= the tree the pages live in).
    private func repoRoot() -> URL {
        SourceLocator.repoRoot
    }

    /// One source file's text.
    private func source(_ relativePath: String) throws -> String {
        let url = repoRoot().appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }

    /// The text between two markers (= one declaration's own block).
    private func block(
        _ text: String,
        from startMarker: String,
        to endMarker: String
    ) -> String {
        guard let start = text.range(of: startMarker) else { return "" }
        guard let end = text.range(of: endMarker, range: start.upperBound ..< text.endIndex) else {
            return String(text[start.upperBound...])
        }
        return String(text[start.upperBound ..< end.lowerBound])
    }

    // MARK: - The status page's clock

    @Test("the status page carries no page-level clock")
    func statusPageCarriesNoPageLevelClock() throws {
        let source = try source("Sources/WenshuApp/Features/Editor/View/InspectorStatusView.swift")

        #expect(source.contains("TimelineView(.periodic") == false,
                "the status page must not tick every second: the tick belongs to the elapsed label")
        #expect(source.contains("now: context.date") == false,
                "no card may take the page's clock: the label reads its own")
    }

    @Test("the elapsed label carries the clock, and only the running card ticks")
    func elapsedLabelCarriesTheClock() throws {
        let source = try source("Sources/WenshuApp/Features/Editor/View/InspectorStatusElapsedLabel.swift")

        #expect(source.contains("TimelineView(.periodic"),
                "the elapsed label is the one subtree that shows a running time, so it ticks")
        #expect(source.contains("case .running") && source.contains("case .completed"),
                "the label ticks for a running card and is frozen for a finished one")
    }

    @Test("a finished card's elapsed time is frozen at its completion")
    func finishedCardElapsedTimeIsFrozen() {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let handle = BackgroundDelegationHandle(
            agentName: "researcher",
            userMessage: "Find the scene where the letter arrives.",
            state: .completed,
            startedAt: start,
            completedAt: start.addingTimeInterval(90)
        )
        let task = InspectorStatusTask(handle: handle)

        // The label reads the completion instant (= not the page's
        // clock), = so a finished card's time does not move.
        #expect(task.elapsedText(at: start.addingTimeInterval(90)) == "1:30",
                "the house format is unchanged: minutes and seconds")
        #expect(task.elapsedText(at: start.addingTimeInterval(600)) == "1:30",
                "a finished card's elapsed time is frozen at its completion")
    }

    // MARK: - The todo page's list

    @Test("the todo page's cards sit in a lazy stack")
    func todoPageCardsSitInALazyStack() throws {
        let source = try source("Sources/WenshuApp/Features/Editor/View/InspectorTodoPageView.swift")

        #expect(source.contains("LazyVStack"),
                "a long list in a scroll view draws only what is on screen")
    }

    @Test("the todo page's refresh reads the same plan as the same cards")
    @MainActor
    func todoPageRefreshReadsTheSameCards() {
        let items = [
            HermesTodoItem(id: "1", content: "Draft chapter 1", status: .pending, parent: nil),
            HermesTodoItem(id: "2", content: "Draft chapter 2", status: .inProgress, parent: nil),
        ]
        let model = InspectorTodoModel(readPlan: { items })
        model.refresh()

        let before = model.todos
        model.refresh()
        let after = model.todos

        #expect(before == after, "the same plan reads as the same cards")
        #expect(model.todos.count == 2, "both plan items are still on the page")
    }

    // MARK: - The board's list

    @Test("the board's cards sit in a lazy stack")
    func boardCardsSitInALazyStack() throws {
        let source = try source("Sources/WenshuApp/Features/Kanban/View/KanbanView.swift")

        let group = block(
            source,
            from: "private struct KanbanGroup",
            to: "// MARK: - Card"
        )
        #expect(group.contains("LazyVStack"),
                "the board's card column draws only the cards that are on screen")
        // The eager stack is the one whose line does NOT start with
        // "Lazy" (= a lazy stack's own line carries that prefix, = so
        // the plain substring would match both).
        let eagerStacks = group
            .split(separator: "\n")
            .filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("VStack(") }
        #expect(eagerStacks.isEmpty,
                "an eager stack in the board's card column builds every card on every body pass")
    }

    @Test("a task's body is parsed once at the load, not per card per body pass")
    func taskBodyIsParsedOnceAtTheLoad() throws {
        let source = try source("Sources/WenshuApp/Features/Kanban/View/KanbanView.swift")

        // The CARD draws the parsed body (= it parses nothing).
        let card = block(
            source,
            from: "private struct KanbanCard",
            to: "\n}\n"
        )
        #expect(card.contains("ChatTextPartView.parseMarkdown") == false,
                "the card must draw the parsed body, not parse it per body pass")
        #expect(card.contains("card.parsedBody"),
                "the card draws the body the load parsed")

        // The LOAD parses it (= once per task).
        let load = block(
            source,
            from: "private func reloadFromStore()",
            to: "/// Remove a task from the board."
        )
        #expect(load.contains("ChatTextPartView.parseMarkdown"),
                "the board's load parses each body once, at the loading boundary")
    }

    @Test("the board still renders a task's body through the one markdown pipeline")
    func boardStillUsesTheOneMarkdownPipeline() throws {
        let source = try source("Sources/WenshuApp/Features/Kanban/View/KanbanView.swift")

        #expect(source.contains("ChatTextPartView.parseMarkdown"),
                "wenshu keeps ONE markdown pipeline across the app (= no per-surface parser)")

        // The rendered text is the shared parser's output (= unchanged).
        let body = "**Goal:** write a 4-beat outline."
        let parsed = ChatTextPartView.parseMarkdown(body)
        #expect(String(parsed.characters).contains("**") == false,
                "the body's markdown is consumed by the shared parser")
    }
}
