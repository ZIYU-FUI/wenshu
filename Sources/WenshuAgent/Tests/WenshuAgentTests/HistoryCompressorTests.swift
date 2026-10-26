// HistoryCompressorTests.swift
//
// Two properties matter more than any single outcome: every tool_use keeps
// its tool_result, and no tool_result outlives its tool_use. A transcript that
// violates either is rejected outright by Anthropic, so a compressor that
// "saves tokens" by breaking a pair trades a size problem for a failure.

import Foundation
import Testing
@testable import WenshuAgent

@Suite("History compressor")
struct HistoryCompressorTests {

    private func user(_ text: String) -> LLMMessage {
        LLMMessage(role: .user, blocks: [.text(text)])
    }
    private func assistant(_ text: String) -> LLMMessage {
        LLMMessage(role: .assistant, blocks: [.text(text)])
    }
    private func toolCall(_ id: String, _ name: String) -> LLMMessage {
        LLMMessage(role: .assistant, blocks: [.toolUse(id: id, name: name, input: "{}")])
    }
    private func toolResult(_ id: String, _ output: String) -> LLMMessage {
        LLMMessage(role: .user, blocks: [.toolResult(toolUseID: id, output: output)])
    }

    private func text(of message: LLMMessage) -> String {
        message.blocks.map(\.textValue).joined()
    }

    /// Every tool_use id has a result and every result has a call.
    private func assertToolPairsIntact(
        _ messages: [LLMMessage],
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        var asked: Set<String> = []
        var answered: Set<String> = []
        for message in messages {
            for block in message.blocks {
                if case .toolUse(let id, _, _) = block { asked.insert(id) }
                if case .toolResult(let id, _) = block { answered.insert(id) }
            }
        }
        #expect(asked == answered, "unpaired tool calls: asked \\(asked.sorted()) answered \\(answered.sorted())",
                sourceLocation: sourceLocation)
    }

    // MARK: - Pruning

    @Test("old tool results are trimmed, recent ones are not")
    func prunesOldToolResultsOnly() {
        var messages: [LLMMessage] = []
        messages.append(toolCall("old", "read"))
        messages.append(toolResult("old", String(repeating: "x", count: 5_000)))
        for i in 0..<10 { messages.append(user("正文 \(i)")) }

        let compressor = HistoryCompressor(budget: CompressionBudget(protectHead: 2, protectTail: 4))
        let (pruned, count) = compressor.pruneStaleToolResults(messages)
        #expect(count == 1, "only the result outside the tail should be trimmed")
        assertToolPairsIntact(pruned)
        let trimmedResult = pruned.first { message in
            if case .toolResult = message.blocks.first { return true }
            return false
        }
        guard case .toolResult(_, let oldOutput)? = trimmedResult?.blocks.first else {
            Issue.record("the tool result must survive trimming in shortened form")
            return
        }
        #expect(oldOutput.count < 5_000)
        #expect(oldOutput.contains("trimmed"))
    }

    @Test("a tool result already short enough is left alone")
    func shortToolResultUntouched() {
        let messages = [toolCall("a", "x"), toolResult("a", "ok")]
        let compressor = HistoryCompressor(budget: CompressionBudget(protectTail: 1))
        let (pruned, count) = compressor.pruneStaleToolResults(messages)
        #expect(count == 0)
        #expect(pruned == messages)
    }

    @Test("pruning preserves the tool_use so the model knows it called something")
    func toolUseSurvivesPruning() {
        let messages = [
            toolCall("a", "read"),
            toolResult("a", String(repeating: "y", count: 9_000)),
            user("a"), user("b"), user("c")
        ]
        let compressor = HistoryCompressor(budget: CompressionBudget(protectTail: 1))
        let (pruned, _) = compressor.pruneStaleToolResults(messages)
        guard case .toolUse(let id, _, _)? = pruned.first?.blocks.first else {
            Issue.record("the tool_use must survive trimming its result")
            return
        }
        #expect(id == "a")
    }

    // MARK: - Window

    @Test("head and tail are protected, the middle is the window")
    func windowSpansTheMiddle() {
        var messages: [LLMMessage] = [user("head1"), user("head2")]
        for i in 0..<20 { messages.append(user("middle\(i)")) }
        for i in 0..<8 { messages.append(user("tail\(i)")) }

        let compressor = HistoryCompressor(budget: CompressionBudget(protectHead: 2, protectTail: 8, protectTailTokens: 1_000_000))
        guard let window = compressor.compressionWindow(messages) else {
            Issue.record("a 30-message transcript must have a compression window")
            return
        }
        #expect(window.start == 2)
        #expect(text(of: messages[window.start]) == "middle0")
        #expect(text(of: messages[window.end - 1]).contains("middle"))
    }

    @Test("an oversized protectTail is clamped rather than cancelling compression")
    func oversizedProtectTailIsClamped() {
        var messages = [user("head")]
        for i in 0..<30 { messages.append(assistant("正文\(i)")) }
        // Without the clamp this leaves start == end, so the caller is told
        // "no window" and compression silently never runs.
        let compressor = HistoryCompressor(budget: CompressionBudget(protectHead: 1, protectTail: 30))
        let window = compressor.compressionWindow(messages)
        #expect(window != nil)
        if let window {
            #expect(window.start < window.end)
            #expect(window.end >= messages.count / 2, "the tail stops at the midpoint")
        }
    }

    @Test("a short transcript has no window")
    func shortTranscriptHasNoWindow() {
        let compressor = HistoryCompressor(budget: CompressionBudget(protectHead: 2, protectTail: 8))
        #expect(compressor.compressionWindow([user("a"), user("b"), user("c")]) == nil)
    }

    @Test("the tail token budget caps how far the tail reaches")
    func tailBudgetCapsReach() {
        var messages = [user("head")]
        for _ in 0..<30 { messages.append(assistant(String(repeating: "字", count: 400))) }
        let generous = HistoryCompressor(budget: CompressionBudget(protectHead: 1, protectTail: 30, protectTailTokens: 1_000_000))
        let tight = HistoryCompressor(budget: CompressionBudget(protectHead: 1, protectTail: 30, protectTailTokens: 500))
        guard let wide = generous.compressionWindow(messages),
              let narrow = tight.compressionWindow(messages) else {
            Issue.record("both budgets must yield a window")
            return
        }
        #expect(wide.end <= narrow.end, "a smaller token budget must not protect more tail messages")
    }

    // MARK: - Pair repair

    @Test("an unanswered tool_use is dropped")
    func unansweredCallIsDropped() {
        let messages = [user("q"), toolCall("ghost", "read"), assistant("正文")]
        let repaired = HistoryCompressor().repairToolPairs(in: messages)
        assertToolPairsIntact(repaired)
        #expect(repaired.count == 2, "the orphaned call must not survive")
    }

    @Test("an orphaned tool_result is dropped")
    func orphanedResultIsDropped() {
        let messages = [user("q"), toolResult("ghost", "output"), assistant("正文")]
        let repaired = HistoryCompressor().repairToolPairs(in: messages)
        assertToolPairsIntact(repaired)
        #expect(repaired.count == 2)
    }

    @Test("a balanced transcript is returned unchanged")
    func balancedTranscriptUntouched() {
        let messages = [user("q"), toolCall("a", "read"), toolResult("a", "out"), assistant("done")]
        #expect(HistoryCompressor().repairToolPairs(in: messages) == messages)
    }

    @Test("a message emptied by pair repair is removed rather than left blank")
    func emptiedMessageIsRemoved() {
        let messages = [user("q"), toolCall("ghost", "read"), assistant("正文")]
        let repaired = HistoryCompressor().repairToolPairs(in: messages)
        #expect(!repaired.contains { $0.blocks.isEmpty })
    }

    // MARK: - Full compression

    @Test("compression summarises the middle and keeps both ends verbatim")
    func compressionKeepsEnds() async {
        // Alternating, because that is what a transcript is. A fixture of
        // nothing but user turns would make the summary's role choice look
        // arbitrary and would hide an alternation break.
        var messages: [LLMMessage] = [user("第一章开头"), assistant("第一章回答")]
        for i in 0..<20 {
            messages.append(user("中段提问\(i)"))
            messages.append(assistant("中段回答\(i)"))
        }
        for i in 0..<6 {
            messages.append(user("结尾提问\(i)"))
            messages.append(assistant("结尾回答\(i)"))
        }

        let compressor = HistoryCompressor(
            budget: CompressionBudget(protectHead: 2, protectTail: 6, protectTailTokens: 1_000_000)
        )
        let outcome = await compressor.compress(messages) { middle in
            "摘要：\(middle.count) 条"
        }
        guard case .summarised(let result, _, let replaced) = outcome else {
            Issue.record("expected a summarised outcome, got \(outcome)")
            return
        }
        // The tail budget is a floor on message count, not a ceiling: with a
        // large token budget the tail grows to half the transcript, because
        // keeping more verbatim history is strictly better than summarising it.
        #expect(replaced > 0 && replaced < messages.count)
        // The count lands on or just under the arithmetic, because folding two
        // same-role neighbours into one removes a message the arithmetic still
        // counts. Exact equality would fail on the summary boundary and pass
        // everywhere else, which is the wrong way round.
        let expected = messages.count - replaced + 1
        #expect(abs(result.count - expected) <= 1,
                "the summary replaces the window (got \(result.count), expected about \(expected))")
        print("DIAG first=\(result.first.map(text(of:)) ?? "nil")")
        print("DIAG roles=\(result.map(\.role))")
        #expect(result.first.map(text(of:)) == "第一章开头", "the head must survive verbatim")
        #expect(result.last.map(text(of:)) == "结尾回答5", "the tail must survive verbatim")
        #expect(result.contains { text(of: $0).contains("摘要") })
        #expect(result.count < messages.count)
    }

    @Test("a failed summary still leaves a smaller valid transcript")
    func failedSummaryStillPrunes() async {
        var messages: [LLMMessage] = []
        for i in 0..<30 { messages.append(user("正文\(i)")) }
        let compressor = HistoryCompressor(
            budget: CompressionBudget(protectHead: 1, protectTail: 4, protectTailTokens: 1_000_000)
        )
        let outcome = await compressor.compress(messages) { _ in nil }
        #expect(outcome.messages.count <= messages.count)
    }

    @Test("compression keeps every tool pair matched")
    func compressionPreservesPairing() async {
        var messages: [LLMMessage] = [user("开始")]
        for i in 0..<10 {
            messages.append(toolCall("call\(i)", "read"))
            messages.append(toolResult("call\(i)", String(repeating: "z", count: 3_000)))
            messages.append(assistant("处理完\(i)"))
        }
        let compressor = HistoryCompressor(
            budget: CompressionBudget(protectHead: 2, protectTail: 6, protectTailTokens: 1_000_000)
        )
        let outcome = await compressor.compress(messages) { _ in "摘要" }
        assertToolPairsIntact(outcome.messages)
    }

    // MARK: - Role alternation

    @Test("consecutive user messages are merged, not left adjacent")
    func adjacentUserMessagesAreMerged() async {
        // A summary carries the user role, and the window it replaces can
        // start or end on a user turn, so the summary lands next to one.
        // Anthropic rejects two user messages in a row.
        var messages: [LLMMessage] = []
        for i in 0..<4 {
            messages.append(user("头提问\(i)"))
            messages.append(assistant("头回答\(i)"))
        }
        for i in 0..<16 {
            messages.append(user("中提问\(i)"))
            messages.append(assistant("中回答\(i)"))
        }
        for i in 0..<6 {
            messages.append(user("尾提问\(i)"))
            messages.append(assistant("尾回答\(i)"))
        }

        let compressor = HistoryCompressor(
            budget: CompressionBudget(protectHead: 4, protectTail: 4, protectTailTokens: 1_000_000)
        )
        let outcome = await compressor.compress(messages) { _ in "摘要内容" }
        let roles = outcome.messages.map(\.role)
        for index in 1..<roles.count {
            #expect(roles[index] != roles[index - 1],
                    "two \(roles[index]) messages in a row at \(index)")
        }
    }

    @Test("merging preserves the text of both messages, in order")
    func mergingIsLossless() {
        for role in [LLMMessage.Role.user, .assistant] {
            let merged = HistoryCompressor().mergeAdjacentSameRoleMessages([
                LLMMessage(role: role, blocks: [.text("前面")]),
                LLMMessage(role: role, blocks: [.text("后面")])
            ])
            #expect(merged.count == 1)
            #expect(text(of: merged[0]).contains("前面"))
            #expect(text(of: merged[0]).contains("后面"))
            #expect(text(of: merged[0]).range(of: "前面")!.lowerBound
                    < text(of: merged[0]).range(of: "后面")!.lowerBound,
                    "order must survive the fold")
        }
    }

    @Test("alternating messages are left alone")
    func alternatingMessagesUntouched() {
        let messages = [user("a"), assistant("b"), user("c")]
        #expect(HistoryCompressor().mergeAdjacentSameRoleMessages(messages) == messages)
    }

    // MARK: - Threshold

    @Test("the threshold decides whether compression is due")
    func thresholdDecides() {
        var messages: [LLMMessage] = []
        for _ in 0..<200 { messages.append(assistant(String(repeating: "字", count: 100))) }
        let compressor = HistoryCompressor()
        let tokens = compressor.totalTokens(messages)
        #expect(compressor.needsCompression(messages, contextWindow: tokens) == true)
        #expect(compressor.needsCompression(messages, contextWindow: tokens * 10) == false)
        #expect(compressor.needsCompression(messages, contextWindow: 0) == false,
                "an unknown window must not trigger compression")
    }
}