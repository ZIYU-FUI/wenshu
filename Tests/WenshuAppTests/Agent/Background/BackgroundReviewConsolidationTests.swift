//
//  BackgroundReviewConsolidationTests.swift · Wenshu · v2.8c ticket T14-T16 (boss 2026-09-28 OOB)
//
//  Structural tests for the BackgroundReview consolidation arc
//  (= boss OOB B8 '背景审核：重复的功能，只是调用机制不同的，应
//  该合并').
//
//  boss 2026-09-28 OOB pinned the consolidation:
//    - BackgroundReview actor (= declared in v0.36) has been
//      unused (= no callers; = dead actor per §11 baseline).
//    - The inspector's BackgroundReview tab is also unused.
//    - The user-facing tool is missing.
//    - The agent-side auto-call hook is missing.
//    - boss asked for ONE unified surface (= manual-call from
//      the operator's UI + auto-call from the agent's
//      conversation loop both go through the same entry points).
//
//  Three source-level tests pin the canonical shape:
//
//    1. testBackgroundReviewOpsExposesFourEntryPoints —
//       BackgroundReviewOps exposes submit / approve / reject /
//       listPending static funcs (= the unified façade for both
//       manual + auto callers).
//
//    2. testWenshuConductorRegistersBackgroundReviewTool —
//       WenshuConductor.defaultToolNames contains
//       "background_review" (= the agent's tool-call entry
//       point).
//
//    3. testBackgroundReviewToolAndAgentCallerExist — the
//       BackgroundReviewTool file exists (= manual + auto
//       caller wired to ToolProtocol) AND a background auto-call
//       helper exists (= the agent's conversation-loop hook).
//
//  Per Q34 5.2 + Q173 ponytail + Q186 + Q57 + Q112: source-level
//  tests following the v1.44 specialized-tools P1 hermes-port
//  batch precedent.
//
//  Per boss 2026-09-28 OOB '我不懂写代码' + '你决定' (= the
//  boss-pinned scope is "manual + auto through one surface",
//  not a UI redesign).

import Testing
import Foundation
@testable import WenshuApp

@Suite("BackgroundReview consolidation (v2.8c — boss 2026-09-28 OOB B8)")
struct BackgroundReviewConsolidationTests {

    private var wenshuConductorPath: String {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<6 { url.deleteLastPathComponent() }
        url.appendPathComponent("Sources/WenshuApp/Core/Agent/Conversation/WenshuConductor.swift")
        return url.path
    }

    private var backgroundReviewOpsPath: String {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<6 { url.deleteLastPathComponent() }
        url.appendPathComponent("Sources/WenshuApp/Core/Agent/Background/BackgroundReviewOps.swift")
        return url.path
    }

    private var backgroundReviewToolPath: String {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<6 { url.deleteLastPathComponent() }
        url.appendPathComponent("Sources/WenshuApp/Core/Agent/Tool/BackgroundReviewTool.swift")
        return url.path
    }

    private var conversationLoopPath: String {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<6 { url.deleteLastPathComponent() }
        url.appendPathComponent("Sources/WenshuApp/Core/Agent/Conversation/ConversationLoop.swift")
        return url.path
    }

    @Test("BackgroundReviewOps exposes 4 entry points (submit / approve / reject / listPending) (= unified manual + auto façade)")
    func testBackgroundReviewOpsExposesFourEntryPoints() throws {
        let source = try String(contentsOfFile: backgroundReviewOpsPath, encoding: .utf8)
        for entryPoint in ["submit", "approve", "reject", "listPending"] {
            #expect(source.contains("static func \(entryPoint)"),
                    "BackgroundReviewOps must expose static func \(entryPoint)(...) (= the unified manual + auto entry point)")
        }
    }

    @Test("WenshuConductor registers background_review tool (= the agent's tool-call entry)")
    func testWenshuConductorRegistersBackgroundReviewTool() throws {
        let source = try String(contentsOfFile: wenshuConductorPath, encoding: .utf8)
        #expect(source.contains("\"background_review\""),
                "WenshuConductor.defaultToolNames must contain \"background_review\"")
    }

    @Test("BackgroundReviewTool + agent auto-call helper exist (= manual + auto callers wired)")
    func testBackgroundReviewToolAndAgentCallerExist() throws {
        // BackgroundReviewTool exists (= manual-call surface).
        let toolSource = try? String(contentsOfFile: backgroundReviewToolPath, encoding: .utf8)
        #expect(toolSource != nil,
                "BackgroundReviewTool.swift must exist (= the manual-call surface)")
        // Agent auto-call hook exists in ConversationLoop (= auto
        // surface = boss-pinned B8 '自动也可以手动也可以' clause).
        let loopSource = try String(contentsOfFile: conversationLoopPath, encoding: .utf8)
        #expect(loopSource.contains("BackgroundReview"),
                "ConversationLoop must reference BackgroundReview (= the agent's auto-call hook)")
    }
}