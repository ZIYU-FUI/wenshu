// HistoryCompressor.swift
//
// Four-phase compression (= hermes agent/context_compressor.py::compress).
//
// Hermes spends 5,852 lines here because summarisation is a provider call
// that fails in provider-specific ways. The two phases around it are not
// model work at all, and they are where most of the savings live:
//
//  1. Prune stale tool-result bodies. Free, no LLM, and tool output is the
//     bulkiest and least reusable part of a long transcript.
//  2. Fix the boundaries. Head and tail are kept verbatim; only the middle
//     is summarised.
//  3. Summarise the middle. The only phase that costs a call.
//  4. Clean orphaned tool pairs. Replacing the middle with prose splits
//     tool_use from its tool_result, and a transcript with an unanswered
//     tool_use is a protocol error at several providers.
//
// Phases 1 and 4 run whether or not phase 3 does, so a session that cannot
// afford a summarisation call still gets smaller and still stays valid.
//
// What this replaces: manualTrigger kept the last four messages and threw
// the rest away. On a novel-length session that is not compression, it is
// amnesia, and it is why the agent contradicts itself about chapter ten.

import Foundation

/// What the compressor decided to do.
public enum CompressionOutcome: Sendable, Equatable {
    /// Nothing to do (= the transcript already fits).
    case unnecessary(messages: [LLMMessage])
    /// The transcript was reduced without a summarisation call.
    case pruned(messages: [LLMMessage], prunedToolResults: Int)
    /// The middle was replaced with a summary.
    case summarised(messages: [LLMMessage], summary: String, replacedTurns: Int)

    public var messages: [LLMMessage] {
        switch self {
        case .unnecessary(let messages): return messages
        case .pruned(let messages, _): return messages
        case .summarised(let messages, _, _): return messages
        }
    }
}

/// Budget knobs. Everything a caller can trade off.
public struct CompressionBudget: Sendable, Equatable {
    /// Messages kept verbatim from the front.
    public var protectHead: Int
    /// Messages kept verbatim from the back. Tool pairs must survive here,
    /// so this counts messages, not turns.
    public var protectTail: Int
    /// Token budget for the tail, when the tail should follow the model's
    /// window rather than a fixed message count.
    public var protectTailTokens: Int
    /// Fraction of the context window above which compression runs.
    public var threshold: Double
    /// Fraction of the window compression aims to leave free.
    public var targetFreeFraction: Double
    /// Whether a stale tool-result body may be dropped.
    public var pruneToolResults: Bool

    public init(
        protectHead: Int = 4,
        protectTail: Int = 8,
        protectTailTokens: Int = 4_000,
        threshold: Double = 0.85,
        targetFreeFraction: Double = 0.30,
        pruneToolResults: Bool = true
    ) {
        self.protectHead = protectHead
        self.protectTail = protectTail
        self.protectTailTokens = protectTailTokens
        self.threshold = threshold
        self.targetFreeFraction = targetFreeFraction
        self.pruneToolResults = pruneToolResults
    }
}

/// Reduces a transcript without losing its shape.
public struct HistoryCompressor: Sendable {
    public var budget: CompressionBudget
    /// Token estimate per message. Injected so the policy can be tested
    /// against exact counts instead of a guess.
    public var estimate: @Sendable (LLMMessage) -> Int

    public init(
        budget: CompressionBudget = .init(),
        estimate: @escaping @Sendable (LLMMessage) -> Int = HistoryCompressor.roughEstimate
    ) {
        self.budget = budget
        self.estimate = estimate
    }

    /// Roughly four characters per token, plus overhead per block. Close
    /// enough for a threshold decision and free.
    public static func roughEstimate(_ message: LLMMessage) -> Int {
        var chars = 0
        for block in message.blocks {
            switch block {
            case .text(let text): chars += text.count
            case .thinking(let text, _): chars += text.count
            case .toolUse(_, _, let input): chars += input.count
            case .toolResult(_, let output): chars += output.count
            }
        }
        return chars / 4 + 8
    }

    public func totalTokens(_ messages: [LLMMessage]) -> Int {
        messages.reduce(0) { $0 + estimate($1) }
    }

    /// Whether the transcript has grown past the threshold.
    public func needsCompression(
        _ messages: [LLMMessage],
        contextWindow: Int
    ) -> Bool {
        guard contextWindow > 0 else { return false }
        return Double(totalTokens(messages)) / Double(contextWindow) >= budget.threshold
    }

    /// Phase 1: drop the bodies of tool results that are old enough that
    /// nothing will read them again.
    ///
    /// The tool_use that asked for it is kept: the model still needs to know
    /// it called a tool, and the schema reference matters. Only the payload
    /// goes. Tool results inside the protected tail stay whole, because the
    /// next turn is the one that reads them.
    public func pruneStaleToolResults(_ messages: [LLMMessage]) -> (messages: [LLMMessage], pruned: Int) {
        guard budget.pruneToolResults else { return (messages, 0) }
        let cut = max(0, messages.count - budget.protectTail)
        var pruned = 0
        var result: [LLMMessage] = []
        result.reserveCapacity(messages.count)
        for (index, message) in messages.enumerated() {
            guard index < cut else {
                result.append(message)
                continue
            }
            var changed = false
            let rewritten = message.blocks.map { block -> LLMBlock in
                guard case .toolResult(let id, let output) = block else { return block }
                // Keep a short head so the model can still tell what the call
                // produced; drop the megabyte of log behind it.
                let preview = String(output.prefix(200))
                guard preview.count < output.count else { return block }
                pruned += 1
                changed = true
                return .toolResult(toolUseID: id, output: "\(preview)\n[trimmed \(output.count) chars]")
            }
            result.append(changed ? LLMMessage(role: message.role, blocks: rewritten) : message)
        }
        return (result, pruned)
    }

    /// Phase 2: choose the window to summarise. Returns the index just past
    /// the head and the index where the tail starts.
    public func compressionWindow(_ messages: [LLMMessage]) -> (start: Int, end: Int)? {
        let head = min(budget.protectHead, messages.count)
        let maxTail = max(0, (messages.count - head) / 2)
        // Clamp the configured tail to the midpoint. A tail that reaches past
        // half the transcript leaves no window, and a caller who set a large
        // protectTail would otherwise silently get "no compression" rather
        // than compression over a smaller middle.
        var tail = min(budget.protectTail, messages.count - head, maxTail)
        // Grow the tail to its token budget, never past the midpoint.
        var tailTokens = 0
        while tail < maxTail {
            let next = messages.count - tail - 1
            let cost = estimate(messages[next])
            if tailTokens + cost > budget.protectTailTokens, tail > 0 { break }
            tailTokens += cost
            tail += 1
        }
        let start = head
        let end = messages.count - tail
        // Need room for a summary plus at least one replaced message, and the
        // head must leave something behind. A window of one message is not a
        // compression, it is a deletion.
        guard start < end, end - start >= 2 else { return nil }
        return (start, end)
    }

    /// Phases 1, 2 and 4 without a summarisation call.
    public func reduceWithoutSummarising(_ messages: [LLMMessage]) -> CompressionOutcome {
        let (prunedMessages, prunedCount) = pruneStaleToolResults(messages)
        guard prunedCount > 0 else {
            return .unnecessary(messages: messages)
        }
        return .pruned(
            messages: repairToolPairs(in: prunedMessages),
            prunedToolResults: prunedCount
        )
    }

    /// Full reduction with a summary for the middle.
    ///
    /// `summarise` is injected so the caller chooses the provider and so the
    /// policy is testable without one. Returning nil means the call failed,
    /// and the reduction still happens (= a smaller valid transcript beats a
    /// larger broken one).
    public func compress(
        _ messages: [LLMMessage],
        summarise: @Sendable ([LLMMessage]) async -> String?
    ) async -> CompressionOutcome {
        let (pruned, prunedCount) = pruneStaleToolResults(messages)

        guard let window = compressionWindow(pruned) else {
            return prunedCount > 0
                ? .pruned(messages: repairToolPairs(in: pruned), prunedToolResults: prunedCount)
                : .unnecessary(messages: messages)
        }

        let middle = Array(pruned[window.start..<window.end])
        guard let summary = await summarise(middle), !summary.isEmpty else {
            return .pruned(
                messages: repairToolPairs(in: pruned),
                prunedToolResults: prunedCount
            )
        }

        var rebuilt: [LLMMessage] = Array(pruned[..<window.start])
        // The summary speaks as the assistant: it is this assistant's own
        // record of what happened, which is both what it is and what keeps the
        // role alternation intact when the window it replaces began on a user
        // turn. Naming the boundary in the text means the model does not have
        // to infer it from the role.
        rebuilt.append(LLMMessage(role: .assistant, blocks: [.text(summaryBlock(summary))]))
        rebuilt.append(contentsOf: pruned[window.end...])
        // A summary landing next to a message of the same role is rejected
        // outright, and which side it lands on is a coin flip on the window
        // boundary, so both directions get folded.
        rebuilt = mergeAdjacentSameRoleMessages(rebuilt)
        return .summarised(
            messages: repairToolPairs(in: rebuilt),
            summary: summary,
            replacedTurns: middle.count
        )
    }

    /// Fold consecutive messages that share a role, preserving order.
    ///
    /// Providers require alternating roles. The summary speaks as the
    /// assistant, and the window it replaces can begin on either side of a
    /// turn, so it lands next to an assistant message on one side and a user
    /// message on the other. Merging is lossless: both texts survive, in
    /// order, under a separator so the boundary stays readable.
    func mergeAdjacentSameRoleMessages(_ messages: [LLMMessage]) -> [LLMMessage] {
        var merged: [LLMMessage] = []
        for message in messages {
            if let last = merged.last, last.role == message.role {
                let combined = last.blocks + [.text("")] + message.blocks
                merged[merged.count - 1] = LLMMessage(role: last.role, blocks: combined)
                continue
            }
            merged.append(message)
        }
        return merged
    }

    /// Phase 4: close or drop tool pairs left open by the rewrite.
    ///
    /// A tool_use with no matching tool_result is a protocol error at
    /// Anthropic, and a tool_result with no tool_use is meaningless. Both
    /// directions get fixed here rather than being handed to a provider that
    /// will reject the request.
    public func repairToolPairs(in messages: [LLMMessage]) -> [LLMMessage] {
        var pendingUseIDs: Set<String> = []
        var resolved: Set<String> = []

        // First pass: what was asked for, and what came back.
        for message in messages {
            for block in message.blocks {
                if case .toolUse(let id, _, _) = block { pendingUseIDs.insert(id) }
                if case .toolResult(let id, _) = block { resolved.insert(id) }
            }
        }
        let unanswered = pendingUseIDs.subtracting(resolved)
        let orphaned = resolved.subtracting(pendingUseIDs)
        guard !unanswered.isEmpty || !orphaned.isEmpty else { return messages }

        var result: [LLMMessage] = []
        result.reserveCapacity(messages.count)
        for message in messages {
            var rewritten: [LLMBlock] = []
            var changed = false
            for block in message.blocks {
                switch block {
                case .toolUse(let id, _, _) where unanswered.contains(id):
                    // Drop the call whose result the compression removed.
                    changed = true
                    continue
                case .toolResult(let id, _) where orphaned.contains(id):
                    // Drop the result whose call is not in this transcript.
                    changed = true
                    continue
                default:
                    rewritten.append(block)
                }
            }
            if rewritten.isEmpty && !message.blocks.isEmpty && changed {
                continue
            }
            result.append(changed ? LLMMessage(role: message.role, blocks: rewritten) : message)
        }
        return result
    }

    private func summaryBlock(_ summary: String) -> String {
        """
        # Conversation so far

        Earlier turns were compressed to stay within the context window. What
        matters from them:

        \(summary)
        """
    }
}