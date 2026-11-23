//
//  ChatToolCardSettlementTests.swift · WenshuApp
//
//  ONE card per tool call, = = and the card says what happened.
//
//  WHY
//  ===
//  The transcript drew TWO cards for one tool call: the call card (= =
//  whose status was ALWAYS `.running`, = = because nothing ever wrote
//  the state its view already knew how to draw) and a separate result
//  card next to it.
//
//  And the failure never arrived: the provider layer knows whether a
//  call failed, = = the public block enum dropped the flag, = = and the
//  chat layer wrote `isError: false` (= = so a failed tool read as a
//  successful one).
//
//  WHAT THESE TESTS HOLD
//  =====================
//    1. the result settles the CALL (= = one part, = = the state is
//       complete, = = the result is on the card);
//    2. a failing result settles the call as an error (= = with the
//       error's text);
//    3. an orphan result (= a result with no call) stays its own part;
//    4. a second result for the same call does not settle it twice.
//
//  AND THE ARM
//  ==========
//  A green suite that cannot go red proves nothing: the merge is
//  switched off (= = the result becomes a second part again) and the
//  suite must go RED.
//

import Foundation
import Testing
import WenshuAgent
@testable import WenshuApp
import WenshuData

@MainActor
@Suite("The tool card settles its own call")
struct ChatToolCardSettlementTests {
    /// The call's id (= the id the result points at).
    private static let callID = ToolCallID(rawValue: "call-1")

    /// An accumulator with one tool call in it.
    private func accumulatorWithCall() -> StreamingAccumulator {
        let accumulator = StreamingAccumulator()
        accumulator.appendPart(
            .toolUse(
                id: Self.callID,
                name: "read_file",
                args: "{\"path\":\"chapter.md\"}"
            )
        )
        return accumulator
    }

    /// The call's own state, as the card would read it.
    private func callState(in parts: [ChatMessagePart]) -> ChatMessagePart.ToolUsePart? {
        for part in parts {
            if case let .toolUse(call) = part.kind {
                return call
            }
        }
        return nil
    }

    @Test("The settled call still draws its result line (= the activity list is not starved)")
    func theSettledCallStillDrawsItsResultLine() {
        // The merge removed the second part (= = the result), = = and
        // the activity list read its result line FROM that part. = = So
        // the settled call has to carry the line itself, = = or the
        // reader loses the completion row under the action row.
        let accumulator = accumulatorWithCall()
        accumulator.settleToolResult(
            toolUseID: Self.callID,
            content: "the chapter's first line",
            isError: false
        )

        let steps = ToolActivity.activity(from: accumulator.snapshotParts())
        let kinds = steps.map(\.kind)
        #expect(kinds == [.action, .result],
                Comment("the settled call draws an action row and a result row (= \(kinds))"))
    }

    @Test("A call with no result yet draws only the action row")
    func aCallWithNoResultDrawsOnlyTheActionRow() {
        let accumulator = accumulatorWithCall()
        let steps = ToolActivity.activity(from: accumulator.snapshotParts())
        #expect(steps.map(\.kind) == [.action],
                Comment("a running call has no result row yet (= \(steps.map(\.kind)))"))
    }

    @Test("The result settles the call: one part, and the card says it finished")
    func theResultSettlesTheCall() {
        let accumulator = accumulatorWithCall()
        accumulator.settleToolResult(
            toolUseID: Self.callID,
            content: "the chapter's first line",
            isError: false
        )

        let parts = accumulator.snapshotParts()
        #expect(parts.count == 1,
                Comment("the call and its result are ONE card (= the parts are \(parts.count))"))

        let call = callState(in: parts)
        #expect(call?.status == .complete,
                Comment("the call must be settled (= the status is \(String(describing: call?.status)))"))
        #expect(call?.result == "the chapter's first line",
                Comment("the result must be on the card"))
        #expect(call?.errorMessage == nil,
                Comment("a successful call carries no error"))
    }

    @Test("A failing call settles as an error, with the error's text")
    func aFailingCallSettlesAsAnError() {
        let accumulator = accumulatorWithCall()
        accumulator.settleToolResult(
            toolUseID: Self.callID,
            content: "Error [permission]: the file is not readable",
            isError: true
        )

        let parts = accumulator.snapshotParts()
        #expect(parts.count == 1,
                Comment("a failing call is still ONE card"))

        let call = callState(in: parts)
        #expect(call?.status == .error,
                Comment("the call must settle as an error (= the status is \(String(describing: call?.status)))"))
        #expect(call?.errorMessage == "Error [permission]: the file is not readable",
                Comment("the error's text must reach the card"))
    }

    @Test("A result with no call stays its own part")
    func anOrphanResultStaysItsOwnPart() {
        let accumulator = StreamingAccumulator()
        accumulator.settleToolResult(
            toolUseID: ToolCallID(rawValue: "call-nobody"),
            content: "a result nobody asked for",
            isError: false
        )

        let parts = accumulator.snapshotParts()
        #expect(parts.count == 1)
        guard case let .toolResult(result) = parts.first?.kind else {
            Issue.record(Comment("a result with no call must stay a result"))
            return
        }
        #expect(result.content == "a result nobody asked for",
                Comment("the orphan result must keep its text"))
    }

    @Test("A second result does not settle the same call twice")
    func aSecondResultDoesNotSettleTwice() {
        let accumulator = accumulatorWithCall()
        accumulator.settleToolResult(
            toolUseID: Self.callID,
            content: "the first result",
            isError: false
        )
        accumulator.settleToolResult(
            toolUseID: Self.callID,
            content: "a second result for the same call",
            isError: true
        )

        let parts = accumulator.snapshotParts()
        #expect(parts.count == 1,
                Comment("a second result must not open a second card"))

        let call = callState(in: parts)
        #expect(call?.status == .complete,
                Comment("the call keeps the state its FIRST result gave it"))
        #expect(call?.result == "the first result",
                Comment("the call keeps the first result's text"))
    }

    @Test("The failure fact survives the chat layer")
    func theFailureFactSurvivesTheChatLayer() {
        // The end-to-end half: the flag travels from the block the
        // stream delivered (= = the agent layer's own failure fact) to
        // the card the writer reads.
        //
        // MEASURED before the fix: the chat layer wrote `isError:
        // false` (= = so a failed tool arrived as a successful one), = =
        // and this case is what holds that.
        let model = ChatViewModel(
            initialMessages: [],
            repository: ChatToolSettlementRepository(),
            providersConfigured: { true }
        )
        let placeholderId = UUID()
        model.messages.append(
            ChatMessage(id: placeholderId, role: .agent, source: .wenshu, content: "", isPlaceholder: true)
        )
        let accumulator = StreamingAccumulator()

        // The call arrives.
        model.applyStreamBatch(
            StreamBatch(blocks: [.toolUse(id: "call-1", name: "read_file", input: "{}")]),
            placeholderId: placeholderId,
            accumulator: accumulator
        )
        // The call FAILS.
        model.applyStreamBatch(
            StreamBatch(blocks: [
                .toolResult(toolUseID: "call-1", output: "Error [permission]: denied", isError: true),
            ]),
            placeholderId: placeholderId,
            accumulator: accumulator
        )

        let parts = model.messages.first?.parts ?? []
        #expect(parts.count == 1,
                Comment("the call and its result are ONE card (= the parts are \(parts.count))"))
        let call = callState(in: parts)
        #expect(call?.status == .error,
                Comment("a failed call must settle as an error (= the status is \(String(describing: call?.status)))"))
        #expect(call?.errorMessage == "Error [permission]: denied",
                Comment("the error's text must reach the card"))
    }
}

/// The repository the case needs (= = nothing: the rule is about the
/// messages).
private final class ChatToolSettlementRepository: ChatRepositoryProtocol, @unchecked Sendable {
    func append(_: ChatMessage, sessionId _: SessionID, bookID _: BookID?) async throws {}

    func loadMessages(sessionId _: SessionID, bookID _: BookID?) async throws -> [ChatMessage] {
        []
    }

    func summarizeIfNeeded(
        sessionId _: SessionID,
        lastN _: Int,
        threshold _: Int,
        verifier _: WenshuVerifier,
        bookID _: BookID?
    ) async throws {}

    func copyChatUpload(sourceURL _: URL, intoLibraryAt _: String) async throws -> String? {
        nil
    }
}
