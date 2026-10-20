// ResponseGuards.swift
//
// Four checks on one reply, in the order the ladder runs them (= hermes
// turn_empty_response, turn_truncation, turn_overflow, turn_stop_gates).
//
// Precedence is the design. Empty beats everything: there is nothing to
// continue or inspect. Overflow beats truncation: if the prompt did not fit,
// the "truncation" is a symptom, and continuing would compound the problem.
// Stop gates run last: they only apply to a reply that passed the others.
//
// Every guard is a pure function of (ReplyFacts, RecoverySettings, state). No
// actor, no I/O, no clock. That is what makes the matrix tests possible and
// what keeps the ladder honest.

import Foundation

// MARK: - Empty reply

/// Catches a reply with nothing in it.
public enum EmptyResponseGuard {
    /// Reasons a provider reports when it declined, as opposed to the model
    /// simply producing nothing. These are not the model's fault and a retry
    /// will not fix them.
    private static let refusalReasons: Set<String> = [
        "content_filter", "content_policy", "safety", "recitation", "refusal"
    ]

    public static func evaluate(
        _ facts: ReplyFacts,
        settings: RecoverySettings,
        attemptsUsed: Int
    ) -> ResponseVerdict? {
        if let error = facts.error {
            return error == .contentFiltered ? .abort(reason: .contentFiltered, message: message(for: .contentFiltered)) : nil
        }

        // A tool call with no prose is a legitimate reply (= the loop will run
        // the tool and come back for prose).
        if facts.hasToolCalls { return nil }
        if !facts.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return nil }

        if refusalReasons.contains(facts.finishReason.lowercased()) {
            return .abort(reason: .contentFiltered, message: message(for: .contentFiltered))
        }

        guard settings.retryOnEmptyReply else {
            return .abort(reason: .emptyReply, message: message(for: .emptyReply))
        }
        // One retry is the budget. A model that produced nothing twice will
        // not produce something on a third try, and the user is waiting.
        return attemptsUsed <= 1 ? .retry(reason: .emptyReply) : .abort(reason: .emptyReply, message: message(for: .emptyReply))
    }

    private static func message(for reason: RetryReason) -> String {
        switch reason {
        case .contentFiltered:
            return "这次回复被服务方的内容策略挡住了。换个说法或者换个服务再试一次。"
        default:
            return "模型这次没有返回内容。可以再说一次，或者换个服务。"
        }
    }
}

// MARK: - Truncation

/// Catches a reply that stopped mid-thought.
public enum TruncationGuard {
    /// Terminal punctuation that means the sentence finished. CJK and ASCII
    /// both, because a Chinese novel ends a sentence with the same set.
    private static let terminators: Set<Character> = [
        "。", "！", "？", "…", "」", "』", "】", "》", "）",
        ".", "!", "?", ")", "]", "\"", "'"
    ]

    public static func evaluate(
        _ facts: ReplyFacts,
        settings: RecoverySettings,
        attemptsUsed: Int
    ) -> ResponseVerdict? {
        if facts.error != nil { return nil }
        if facts.hasToolCalls { return nil }
        let text = facts.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        // A provider that reports hitting the output cap knows where it
        // stopped, and the tail may well be punctuation by chance (= "他说。
        // " can be a genuine sentence end). Trust the provider over the
        // punctuation. Both vocabularies appear: Anthropic says max_tokens,
        // OpenAI says length.
        let stopReasons: Set<String> = ["length", "max_tokens", "max_output_tokens"]
        if stopReasons.contains(facts.finishReason.lowercased()) {
            return verdict(for: .truncated, settings: settings, attemptsUsed: attemptsUsed)
        }

        // A provider that reports a clean stop has answered the question.
        // Judging the tail anyway misfires on every reply that legitimately
        // ends without terminal punctuation: a chapter title, a bare filename,
        // a code identifier, a single word. Guessing over a stated stop reason
        // trades a rare miss for a common false positive.
        let cleanStops: Set<String> = ["stop", "end_turn", "stop_sequence", "complete", "completed"]
        if cleanStops.contains(facts.finishReason.lowercased()) { return nil }

        // Otherwise only judge a tail that looks unfinished. A long reply that
        // simply ends in a period is finished, however long it is.
        guard let last = text.last else { return nil }
        if terminators.contains(last) { return nil }
        // Markdown fences and list bullets end legitimately.
        if text.hasSuffix("```") { return nil }
        if last == "*" || last == "-" { return nil }

        return verdict(for: .incompleteSentence, settings: settings, attemptsUsed: attemptsUsed)
    }

    private static func verdict(
        for reason: RetryReason,
        settings: RecoverySettings,
        attemptsUsed: Int
    ) -> ResponseVerdict {
        // Continuing beats retrying: a retry throws away prose the user asked
        // for. Hermes does the same (= turn_truncation _continue_text).
        if settings.continueOnTruncation {
            return .continueText(prompt: Self.continuationPrompt)
        }
        if settings.retryOnTruncation, attemptsUsed <= 1 {
            return .retry(reason: reason)
        }
        return .accept
    }

    /// The instruction sent alongside a continuation request.
    ///
    /// "Do not repeat" is the load-bearing clause: without it a model asked to
    /// continue a truncated reply commonly restates the opening, and the user
    /// gets the paragraph twice.
    static let continuationPrompt = """
    Your previous reply was cut off before it finished. Continue exactly \
    where it stopped. Do not repeat, restate, or re-open anything you already \
    wrote, and do not add a summary of what you wrote. Pick up mid-thought.
    """
}

// MARK: - Overflow

/// Catches a prompt that does not fit the context window.
public enum OverflowGuard {
    /// Fraction above which a prompt is refused rather than merely tight.
    /// Providers differ; this is the fraction the ladder treats as
    /// "degrade now" regardless of what the provider said.
    static let dangerFraction = 0.95

    public static func evaluate(
        _ facts: ReplyFacts,
        settings: RecoverySettings,
        attemptsUsed: Int,
        isLastAttempt: Bool
    ) -> ResponseVerdict? {
        if let error = facts.error, error == .contextOverflow {
            return degrade(settings: settings, attemptsUsed: attemptsUsed, isLastAttempt: isLastAttempt)
        }
        // A provider that returns a normal finish reason while sitting at the
        // window edge did not technically fail. It will on the next turn, so
        // compress now rather than after the user has waited for the failure.
        guard let fraction = facts.promptFraction, fraction >= dangerFraction else { return nil }
        return degrade(settings: settings, attemptsUsed: attemptsUsed, isLastAttempt: isLastAttempt)
    }

    private static func degrade(
        settings: RecoverySettings,
        attemptsUsed: Int,
        isLastAttempt: Bool
    ) -> ResponseVerdict {
        // Compressing then retrying fixes the common case (= a long session
        // grew past the window).
        if attemptsUsed <= 1, !isLastAttempt {
            return .degrade(reason: .contextOverflow)
        }
        // Still too big after one compression: the reply itself is too long
        // to place. Shrink the output cap, or give up cleanly.
        if settings.degradeOutputCapOnOverflow, attemptsUsed <= 2 {
            return .degrade(reason: .contextOverflow)
        }
        return .abort(
            reason: .contextOverflow,
            message: "这一章的历史太长了，放不下的内容被截掉了。压缩一下这本书的上下文再试。"
        )
    }
}

// MARK: - Stop gates

/// Catches a reply that claims completion without the work being there.
public enum StopGateGuard {
    /// Phrases that announce a finished task.
    private static let completionMarkers = [
        "完成了", "已完成", "搞定", "done", "finished", "完成。"
    ]

    public static func evaluate(
        _ facts: ReplyFacts,
        settings: RecoverySettings,
        requiredDeliverables: [String],
        attemptsUsed: Int
    ) -> ResponseVerdict? {
        guard settings.checkStopGates else { return nil }
        guard !requiredDeliverables.isEmpty else { return nil }
        if facts.error != nil || facts.hasToolCalls { return nil }
        let text = facts.text
        guard !text.isEmpty else { return nil }

        // Only when the reply claims completion. A reply that is still
        // describing what it will do has not tripped anything.
        let claimsCompletion = completionMarkers.contains { text.contains($0) }
        guard claimsCompletion else { return nil }

        // A deliverable counts as present when the user can see it in the
        // reply. Matching is loose on purpose: the point is to catch "finished"
        // over an empty result, not to verify content the user will judge.
        let missing = requiredDeliverables.filter { deliverable in
            !Self.isMentioned(deliverable, in: text)
        }
        guard !missing.isEmpty else { return nil }

        // One nudge. A second pass costs a full turn and usually returns the
        // same answer with more words.
        return attemptsUsed <= 1 ? .retry(reason: .incompleteSentence) : .accept
    }

    private static func isMentioned(_ deliverable: String, in text: String) -> Bool {
        let needle = deliverable.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return true }
        if text.contains(needle) { return true }
        // A deliverable named in full ("第一章") may be written short ("第一章"
        // vs "第一章：起雾") or with its last path segment only.
        let tail = needle.split(whereSeparator: { "/:" .contains($0) }).last.map(String.init) ?? needle
        return !tail.isEmpty && text.contains(tail)
    }
}

// MARK: - Chain

/// Runs the guards in precedence order and returns the first non-accept
/// verdict.
public struct RecoveryLadder: Sendable {
    public var settings: RecoverySettings
    /// What the user asked for and can therefore check. Empty disables the
    /// stop gate (= most turns).
    public var requiredDeliverables: [String]
    /// How many provider calls this turn has already spent.
    public var attemptsUsed: Int
    /// Whether the retry budget is spent.
    public var isLastAttempt: Bool

    public init(
        settings: RecoverySettings = .init(),
        requiredDeliverables: [String] = [],
        attemptsUsed: Int = 1,
        isLastAttempt: Bool = false
    ) {
        self.settings = settings
        self.requiredDeliverables = requiredDeliverables
        self.attemptsUsed = attemptsUsed
        self.isLastAttempt = isLastAttempt
    }

    public func evaluate(_ facts: ReplyFacts) -> ResponseVerdict {
        if let verdict = EmptyResponseGuard.evaluate(facts, settings: settings, attemptsUsed: attemptsUsed) {
            return verdict
        }
        if let verdict = OverflowGuard.evaluate(
            facts, settings: settings, attemptsUsed: attemptsUsed, isLastAttempt: isLastAttempt
        ) {
            return verdict
        }
        if let verdict = TruncationGuard.evaluate(facts, settings: settings, attemptsUsed: attemptsUsed) {
            return verdict
        }
        if let verdict = StopGateGuard.evaluate(
            facts,
            settings: settings,
            requiredDeliverables: requiredDeliverables,
            attemptsUsed: attemptsUsed
        ) {
            return verdict
        }
        return .accept
    }
}