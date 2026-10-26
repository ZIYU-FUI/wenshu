//
//  ImportReplyMergeTests.swift · Wenshu
//
//  Behavior tests for `ImportReplyParts` (= the import sheet's reply
//  accumulation).
//
//  Why it exists: the boss reported (2026-10-26) that the import's
//  thinking read as one line per few characters. The provider cuts its
//  reasoning into small chunks, = and the sheet appended every chunk
//  as its own part, = so each chunk became its own row. The chat zone
//  never had this problem: its accumulator merges the chunks of the
//  same kind into the trailing part.
//
//  Coverage (= 5 tests):
//   1. `theReasoningChunksBecomeOnePart`
//   2. `theTextChunksBecomeOnePart`
//   3. `aToolCallStartsANewPart`
//   4. `aTextPartAfterAToolCallStartsANewPart`
//   5. `aToolResultStartsANewPart`
//

import Foundation
import Testing
import WenshuData
@testable import WenshuApp

@Suite("Import reply — the sheet merges the stream's chunks")
struct ImportReplyMergeTests {

    /// The reply after the given parts arrive.
    private func reply(after parts: [ChatMessagePart]) -> [ChatMessagePart] {
        parts.reduce(into: [ChatMessagePart]()) { merged, part in
            merged = ImportReplyParts.merging(part, into: merged)
        }
    }

    @Test("the reasoning chunks become one part")
    func theReasoningChunksBecomeOnePart() {
        let parts = reply(after: [.reasoning("a "), .reasoning("few "), .reasoning("characters")])

        #expect(parts.count == 1)
        if case .reasoning(let text)? = parts.first?.kind {
            #expect(text == "a few characters")
        } else {
            Issue.record("the chunks must merge into one reasoning part")
        }
    }

    @Test("the text chunks become one part")
    func theTextChunksBecomeOnePart() {
        let parts = reply(after: [.text("one "), .text("reply "), .text("line")])

        #expect(parts.count == 1)
        if case .text(let text)? = parts.first?.kind {
            #expect(text == "one reply line")
        } else {
            Issue.record("the chunks must merge into one text part")
        }
    }

    @Test("a tool call starts a new part")
    func aToolCallStartsANewPart() {
        let parts = reply(after: [
            .reasoning("thinking"),
            .toolUse(id: ToolCallID(rawValue: "call-1"), name: "writeBookDoc", args: "{}")
        ])

        #expect(parts.count == 2)
    }

    @Test("a text part after a tool call starts a new part")
    func aTextPartAfterAToolCallStartsANewPart() {
        let parts = reply(after: [
            .toolUse(id: ToolCallID(rawValue: "call-1"), name: "writeBookDoc", args: "{}"),
            .text("the answer")
        ])

        #expect(parts.count == 2)
        if case .text(let text)? = parts.last?.kind {
            #expect(text == "the answer")
        } else {
            Issue.record("the answer must be its own part")
        }
    }

    @Test("a tool result starts a new part")
    func aToolResultStartsANewPart() {
        let parts = reply(after: [
            .toolUse(id: ToolCallID(rawValue: "call-1"), name: "writeBookDoc", args: "{}"),
            .toolResult(toolUseID: ToolCallID(rawValue: "call-1"), content: "written", isError: false)
        ])

        #expect(parts.count == 2)
    }
}
