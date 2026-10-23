//
//  ConductorSessionScopeTests.swift · WenshuAgent
//
//  The rule under test: the turn's session reaches the tool the model calls.
//
//  Before this change the conductor took a session id and threw it away
//  (`_ = sessionId`), so a tool that creates a sub-agent had no way to
//  learn which chat asked for it. The delegation it created therefore
//  belonged to no chat, and the status column could not scope its list
//  to the conversation the user is in.
//
//  The test drives the PRODUCTION path (the conductor's `handle`, into
//  the real turn, into the real tool dispatch), because a test that
//  only checks the scope value proves nothing: the scope is a task
//  local, and only a tool that READS it at call time proves the value
//  travelled.
//

import Foundation
import Testing
@testable import WenshuAgent

/// A connector that answers with a scripted sequence of responses.
///
/// The first response asks for a tool, the second one carries the prose
/// the loop returns after the tool answered.
private actor ScriptedConnector: LLMConnector {
    nonisolated let connectorID: String = "mock"
    nonisolated let contextWindow: Int = 32_000

    private let scripted: [LLMResponse]
    private var index: Int = 0

    init(scripted: [LLMResponse]) {
        self.scripted = scripted
    }

    func send(messages: [LLMMessage], options: LLMCallOptions) async throws -> LLMResponse {
        guard index < scripted.count else {
            return LLMResponse(
                id: "mock-exhausted",
                model: options.model,
                blocks: [.text("no more scripted responses")],
                stopReason: .endTurn,
                usage: LLMUsage(inputTokens: 0, outputTokens: 0)
            )
        }
        defer { index += 1 }
        return scripted[index]
    }

    nonisolated func stream(
        messages: [LLMMessage],
        options: LLMCallOptions
    ) -> AsyncStream<LLMBlock> {
        AsyncStream { continuation in
            Task {
                let blocks = await self.nextBlocks()
                for block in blocks {
                    continuation.yield(block)
                }
                continuation.finish()
            }
        }
    }

    private func nextBlocks() -> [LLMBlock] {
        guard index < scripted.count else { return [.text("no more scripted responses")] }
        defer { index += 1 }
        return scripted[index].blocks
    }
}

/// A tool that records the scope it was called under.
///
/// It stands in for the delegation tool: the delegation is created
/// inside the tool, so the tool is the only place the scope can be
/// read.
private final class ScopeProbeTool: Tool, @unchecked Sendable {
    private let lock = NSLock()
    private var observedSessionID: String?

    /// The session the tool saw when it ran. Nil = the tool ran with no
    /// turn around it.
    var seenSessionID: String? {
        lock.withLock { observedSessionID }
    }

    func execute(input: String) async throws -> String {
        let sessionID = TurnScope.currentSessionID
        lock.withLock { observedSessionID = sessionID }
        return "probe answered"
    }
}

@Suite("The conductor's session reaches the tool the model calls")
struct ConductorSessionScopeTests {

    private static let toolName = "scope_probe"

    private func conductor(
        probe: ScopeProbeTool,
        connector: LLMConnector
    ) -> WenshuConductor {
        WenshuConductor(
            connector: connector,
            tools: [Self.toolName: probe]
        )
    }

    // MARK: - The session reaches the tool

    @Test("the tool the model calls sees the turn's session")
    @MainActor
    func theToolSeesTheTurnSession() async throws {
        let probe = ScopeProbeTool()
        let connector = ScriptedConnector(scripted: [
            LLMResponse(
                id: "r1",
                model: "mock",
                blocks: [
                    .toolUse(
                        id: "t1",
                        name: Self.toolName,
                        input: "{\"noun\":\"Xi'an\"}"
                    )
                ],
                stopReason: .toolUse,
                usage: LLMUsage(inputTokens: 1, outputTokens: 1)
            ),
            LLMResponse(
                id: "r2",
                model: "mock",
                blocks: [.text("done")],
                stopReason: .endTurn,
                usage: LLMUsage(inputTokens: 1, outputTokens: 1)
            )
        ])

        let result = await conductor(probe: probe, connector: connector).handle(
            userMessage: "research Xi'an",
            sessionId: "s_session-42",
            model: "mock"
        )

        #expect(result.reply == "done", "the turn must run to the tool (= the connector was reached)")
        #expect(probe.seenSessionID == "s_session-42", "the tool must see the session of the turn that called it")
    }

    // MARK: - The scope does not leak past the turn

    @Test("a tool that runs outside a turn sees no session")
    @MainActor
    func aToolOutsideATurnSeesNoSession() async throws {
        let probe = ScopeProbeTool()

        _ = try await probe.execute(input: "{}")

        #expect(probe.seenSessionID == nil, "the session is bound to the turn, not to the process")
    }
}
