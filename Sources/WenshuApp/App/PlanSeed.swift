//
//  PlanSeed.swift
//  wenshu
//
//  A dev-only seed for the assistant's plan, the delegation crew, and
//  the board's tasks.
//
//  The trailing column's todo page reads the plan the assistant wrote,
//  the sub-agent page reads the crew, and the task page reads the
//  board's tasks. All three live in memory or in a store that starts
//  empty, so a fresh launch has nothing to show. This seed writes a
//  sample of each so the pages can be seen.
//
//  The seed is GATED: it runs only when the environment says so
//  (= WS_SEED_PLAN=1), and the environment is read at launch. A launch
//  without that variable never reaches the seed, so the shipped app
//  never sees a sample plan.
//
//  The seed writes into the same stores the real agent writes into
//  (= the shared plan store, = the shared delegation registry, = the
//  app's task store), so the pages read the seed exactly as they read
//  the agent's own work.
//

import Foundation
import SwiftUI
import WenshuData

/// A dev-only sample of the assistant's plan, the crew, and the board.
enum PlanSeed {

    /// Whether the environment asks for the seed.
    static func isRequested() -> Bool {
        ProcessInfo.processInfo.environment["WS_SEED_PLAN"] == "1"
    }

    /// Write the sample plan, the sample crew, and the sample tasks.
    ///
    /// The plan carries every state the page draws (= an item still to
    /// do, = the item being worked on, = a resolved item, = a dropped
    /// item) and a nested item (= a sub-step reads indented under its
    /// parent), so one look shows the whole page.
    ///
    /// The tasks carry every board group (= the queue, = the ready row,
    /// = the running row, = the blocked row, = the resolved row), so one
    /// look shows the whole board.
    @MainActor
    static func run(bookID: String?) async {
        seedPlan()
        await seedCrew()
        seedTasks(bookID: bookID)
    }

    // MARK: - The plan

    /// The sample plan (= the agent's own plan store).
    private static func seedPlan() {
        let items = [
            HermesTodoItem(
                id: "plan-1",
                content: "Read the chapter and note what the letter says",
                status: .inProgress
            ),
            HermesTodoItem(
                id: "plan-1a",
                content: "Find the scene where the letter arrives",
                status: .pending,
                parent: "plan-1"
            ),
            HermesTodoItem(
                id: "plan-1b",
                content: "Note the sender and the date on the envelope",
                status: .pending,
                parent: "plan-1"
            ),
            HermesTodoItem(
                id: "plan-2",
                content: "Check the family letter for a second mention",
                status: .pending
            ),
            HermesTodoItem(
                id: "plan-3",
                content: "Search the archive for the 1911 register",
                status: .pending
            ),
            HermesTodoItem(
                id: "plan-4",
                content: "Open the reference shelf and pull the ledger",
                status: .completed
            ),
            HermesTodoItem(
                id: "plan-5",
                content: "Compare the two drafts of the will",
                status: .cancelled
            ),
        ]
        HermesTodoTool.shared.writePlan(items, merge: false)
    }

    // MARK: - The crew

    /// The sample crew (= the shared delegation registry).
    ///
    /// The records carry no scope, because the page shows one session's
    /// crew only and the scope is not known at launch. The page claims
    /// the records that belong to no scope the first time it sees one,
    /// so the sample lands where the user is looking.
    private static func seedCrew() async {
        let now = Date()
        let handles = [
            BackgroundDelegationHandle(
                agentName: "researcher",
                userMessage: "Find the scene where the letter arrives.",
                state: .running,
                startedAt: now.addingTimeInterval(-95),
                currentTool: "read_file"
            ),
            BackgroundDelegationHandle(
                agentName: "archivist",
                userMessage: "Search the archive for the 1911 register.",
                state: .running,
                startedAt: now.addingTimeInterval(-40),
                currentTool: "web_search"
            ),
            BackgroundDelegationHandle(
                agentName: "editor",
                userMessage: "Check the family letter for a second mention.",
                state: .completed,
                startedAt: now.addingTimeInterval(-600),
                completedAt: now.addingTimeInterval(-120),
                result: "The letter mentions the register once, in the second paragraph."
            ),
        ]
        for handle in handles {
            await AsyncDelegationRegistry.shared.register(handle: handle)
        }
    }

    // MARK: - The board's tasks

    /// The sample tasks (= the app's task store).
    ///
    /// The board follows the session, and the session names its book,
    /// so the sample lands on the focused session's board (= the book id
    /// the caller passes, = the book's board when the session names one,
    /// = the library-level board when it does not).
    @MainActor
    private static func seedTasks(bookID: String?) {
        let store = WSKanbanRepository()
        let samples: [(String, String, String)] = [
            ("new", "整理十二地仙卷宗总表", "把十二个朝代与《月令广义》的十二原典字…"),
            ("triage", "补齐「关键场景种子」的六处出处", "场景种子分「已建 / 可推 / 建议」三档，每档的出处要标到具体卷宗。"),
            ("ready", "核对三条硬规则的互相咬合", "「分清 / 唯一 / 代价」三条规则要能互相推导，不留例外。"),
            ("running", "给「十二地仙」写第一卷开篇", "开篇从家族信开始写，家族信有三处版本差异。"),
            ("blocked", "等老板确认第十二卷的卷宗归属", "第十二卷同时被两处引用，归属要先定。"),
            ("done", "列出全书时间线的三处冲突", "冲突有三处，都是年份与事件顺序对不上。"),
            ("failed", "对齐「代价」一词的两种用法", "两处用法讲的不是一件事，需要一处改写。"),
        ]
        for (status, title, body) in samples {
            do {
                _ = try store.add(
                    title: title,
                    status: status,
                    priority: 5,
                    body: body,
                    bookID: bookID
                )
            } catch {
                // The seed is a convenience; a store that refuses the
                // write leaves the board as it was.
                continue
            }
        }
    }
}
