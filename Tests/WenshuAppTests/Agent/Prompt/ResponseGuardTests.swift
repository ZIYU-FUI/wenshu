// ResponseGuardTests.swift
//
// The decision matrix for each guard. A guard that is right on the obvious
// case and wrong on the adjacent one is worse than no guard, because the
// adjacent case is the one that happens in production.

import Foundation
import Testing
@testable import WenshuAgent

@Suite("Response guards")
struct ResponseGuardTests {

    // MARK: - Empty

    @Test("an empty reply retries once, then aborts")
    func emptyRetriesOnceThenAborts() {
        let settings = RecoverySettings()
        let facts = ReplyFacts(text: "   ", finishReason: "stop")
        #expect(EmptyResponseGuard.evaluate(facts, settings: settings, attemptsUsed: 1) == .retry(reason: .emptyReply))
        let late = EmptyResponseGuard.evaluate(facts, settings: settings, attemptsUsed: 2)
        #expect(late?.reason == .emptyReply)
        #expect(late?.userMessage != nil, "an abort must say something the user can act on")
    }

    @Test("a tool call with no prose is a legitimate reply")
    func toolCallWithoutProseIsFine() {
        let facts = ReplyFacts(text: "", hasToolCalls: true)
        #expect(EmptyResponseGuard.evaluate(facts, settings: .init(), attemptsUsed: 1) == nil)
    }

    @Test("a provider refusal aborts without retrying")
    func contentFilterAbortsImmediately() {
        let facts = ReplyFacts(text: "", finishReason: "content_filter")
        let verdict = EmptyResponseGuard.evaluate(facts, settings: .init(), attemptsUsed: 1)
        #expect(verdict?.reason == .contentFiltered)
        #expect(verdict?.userMessage?.isEmpty == false, "the user needs to know why")
    }

    @Test("disabling the empty retry turns it into an immediate abort")
    func emptyRetryCanBeTurnedOff() {
        let settings = RecoverySettings(retryOnEmptyReply: false)
        let facts = ReplyFacts(text: "", finishReason: "stop")
        #expect(EmptyResponseGuard.evaluate(facts, settings: settings, attemptsUsed: 1)?.reason == .emptyReply)
        #expect(EmptyResponseGuard.evaluate(facts, settings: settings, attemptsUsed: 1)?.userMessage != nil)
    }

    // MARK: - Truncation

    @Test("a provider-reported cap is treated as truncation even with clean punctuation")
    func providerCapBeatsPunctuationGuess() {
        let facts = ReplyFacts(text: "他说。好。", finishReason: "max_tokens")
        let verdict = TruncationGuard.evaluate(facts, settings: .init(), attemptsUsed: 1)
        #expect(verdict == .continueText(prompt: TruncationGuard.continuationPrompt))
    }

    @Test("both provider vocabularies for a cap are recognised")
    func bothCapVocabularies() {
        for reason in ["length", "max_tokens", "max_output_tokens", "MAX_TOKENS"] {
            let facts = ReplyFacts(text: "正文", finishReason: reason)
            #expect(TruncationGuard.evaluate(facts, settings: .init(), attemptsUsed: 1) != nil,
                    "\(reason) must count as truncation")
        }
    }

    @Test("a stated clean stop is never second-guessed on punctuation")
    func statedStopBeatsPunctuationGuess() {
        // A bare identifier, a filename, a chapter title: all legitimately end
        // without terminal punctuation. Rejecting them means every such reply
        // costs an extra provider call, or worse, a duplicate paragraph.
        for text in ["abcdef", "loop-reply", "第一章", "chapter-04.md", "TODO"] {
            let facts = ReplyFacts(text: text, finishReason: "end_turn")
            #expect(TruncationGuard.evaluate(facts, settings: .init(), attemptsUsed: 1) == nil,
                    "\(text) ended as the provider said it did")
        }
    }

    @Test("finished punctuation is not truncation")
    func cleanEndingIsAccepted() {
        for ending in ["他说。", "真的吗？", "真好啊！", "然后……", "（未完）", "done.", "really?", "abc)"] {
            let facts = ReplyFacts(text: "正文\(ending)", finishReason: "unknown")
            #expect(TruncationGuard.evaluate(facts, settings: .init(), attemptsUsed: 1) == nil,
                    "\(ending) reads as finished")
        }
    }

    @Test("a mid-sentence tail is truncation when the provider did not claim a stop")
    func danglingTailIsTruncation() {
        // "unknown" = the provider gave no usable stop reason. Only then does
        // the punctuation heuristic decide, and only then can it be wrong.
        let facts = ReplyFacts(text: "他推开门，看见", finishReason: "unknown")
        #expect(TruncationGuard.evaluate(facts, settings: .init(), attemptsUsed: 1)
            == .continueText(prompt: TruncationGuard.continuationPrompt))
    }

    @Test("a code fence is not a dangling tail")
    func codeFenceIsFinished() {
        let facts = ReplyFacts(text: "正文\n```swift\nlet x = 1\n```", finishReason: "stop")
        #expect(TruncationGuard.evaluate(facts, settings: .init(), attemptsUsed: 1) == nil)
    }

    @Test("the continuation instruction forbids repeating what was written")
    func continuationInstructionCarriesTheAntiRepeatClause() {
        // Without this the model restates the opening and the user sees the
        // paragraph twice, which is the whole reason continuation beats retry.
        #expect(TruncationGuard.continuationPrompt.lowercased().contains("do not repeat"))
    }

    @Test("continuation can be turned off in favour of a retry")
    func continuationIsOptional() {
        let settings = RecoverySettings(retryOnTruncation: true, continueOnTruncation: false)
        let facts = ReplyFacts(text: "他推开门，看见", finishReason: "unknown")
        #expect(TruncationGuard.evaluate(facts, settings: settings, attemptsUsed: 1) == .retry(reason: .incompleteSentence))
    }

    // MARK: - Overflow

    @Test("an explicit overflow error degrades once then aborts")
    func overflowDegradesThenAborts() {
        let settings = RecoverySettings()
        let facts = ReplyFacts(text: "", error: .contextOverflow)
        #expect(OverflowGuard.evaluate(facts, settings: settings, attemptsUsed: 1, isLastAttempt: false)
            == .degrade(reason: .contextOverflow))
        let late = OverflowGuard.evaluate(facts, settings: settings, attemptsUsed: 3, isLastAttempt: true)
        #expect(late?.reason == .contextOverflow)
        #expect(late?.userMessage != nil)
    }

    @Test("a prompt near the window edge degrades before the provider complains")
    func nearWindowEdgeDegradesEarly() {
        let settings = RecoverySettings()
        let facts = ReplyFacts(text: "正文", promptFraction: 0.97)
        #expect(OverflowGuard.evaluate(facts, settings: settings, attemptsUsed: 1, isLastAttempt: false)
            == .degrade(reason: .contextOverflow))
    }

    @Test("a comfortable prompt is left alone")
    func comfortablePromptAccepted() {
        let facts = ReplyFacts(text: "正文", promptFraction: 0.4)
        #expect(OverflowGuard.evaluate(facts, settings: .init(), attemptsUsed: 1, isLastAttempt: false) == nil)
        #expect(OverflowGuard.evaluate(ReplyFacts(text: "正文"), settings: .init(), attemptsUsed: 1, isLastAttempt: false) == nil)
    }

    // MARK: - Stop gates

    @Test("a completion claim without the deliverable gets one more pass")
    func missingDeliverableNudgesOnce() {
        let facts = ReplyFacts(text: "已经完成了。", finishReason: "stop")
        let verdict = StopGateGuard.evaluate(
            facts,
            settings: .init(),
            requiredDeliverables: ["第四章"],
            attemptsUsed: 1
        )
        #expect(verdict == .retry(reason: .incompleteSentence))
        // The second pass lets it through rather than returning nil: nil means
        // "the guard had no opinion", accept means "the gate decided to stop
        // gating". Either ends the turn, but only one of them is the decision.
        #expect(StopGateGuard.evaluate(facts, settings: .init(), requiredDeliverables: ["第四章"], attemptsUsed: 2) == .accept)
    }

    @Test("a reply that shows the deliverable passes")
    func presentDeliverableAccepted() {
        let facts = ReplyFacts(text: "第四章已经写好，见下面。", finishReason: "stop")
        #expect(StopGateGuard.evaluate(facts, settings: .init(), requiredDeliverables: ["第四章"], attemptsUsed: 1) == nil)
    }

    @Test("a reply that has not claimed completion is not gated")
    func noCompletionClaimNoGate() {
        let facts = ReplyFacts(text: "我接下来会写第四章。", finishReason: "stop")
        #expect(StopGateGuard.evaluate(facts, settings: .init(), requiredDeliverables: ["第四章"], attemptsUsed: 1) == nil)
    }

    @Test("no required deliverables disables the gate")
    func noDeliverablesDisablesGate() {
        let facts = ReplyFacts(text: "完成了。", finishReason: "stop")
        #expect(StopGateGuard.evaluate(facts, settings: .init(), requiredDeliverables: [], attemptsUsed: 1) == nil)
    }

    @Test("the gate can be turned off")
    func gateIsOptional() {
        let settings = RecoverySettings(checkStopGates: false)
        let facts = ReplyFacts(text: "完成了。", finishReason: "stop")
        #expect(StopGateGuard.evaluate(facts, settings: settings, requiredDeliverables: ["第四章"], attemptsUsed: 1) == nil)
    }

    // MARK: - Precedence

    @Test("empty beats truncation")
    func emptyOutranksTruncation() {
        let ladder = RecoveryLadder(attemptsUsed: 1)
        #expect(ladder.evaluate(ReplyFacts(text: "", finishReason: "length")).reason == .emptyReply)
    }

    @Test("overflow beats truncation")
    func overflowOutranksTruncation() {
        let ladder = RecoveryLadder(attemptsUsed: 1, isLastAttempt: false)
        let verdict = ladder.evaluate(ReplyFacts(text: "他推开门", finishReason: "length", error: .contextOverflow))
        #expect(verdict == .degrade(reason: .contextOverflow),
                "a prompt that did not fit makes truncation a symptom, not the fault")
    }

    @Test("a clean reply is accepted")
    func cleanReplyAccepted() {
        let ladder = RecoveryLadder(attemptsUsed: 1)
        #expect(ladder.evaluate(ReplyFacts(text: "写好了。", finishReason: "stop")) == .accept)
    }

    @Test("only an abort carries a user message")
    func onlyAbortSpeaksToTheUser() {
        #expect(ResponseVerdict.accept.userMessage == nil)
        #expect(ResponseVerdict.retry(reason: .emptyReply).userMessage == nil)
        #expect(ResponseVerdict.continueText(prompt: "x").userMessage == nil)
        #expect(ResponseVerdict.degrade(reason: .contextOverflow).userMessage == nil)
        #expect(ResponseVerdict.abort(reason: .emptyReply, message: "说明").userMessage == "说明")
    }
}