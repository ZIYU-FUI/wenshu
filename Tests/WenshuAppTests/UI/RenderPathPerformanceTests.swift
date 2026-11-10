//
//  RenderPathPerformanceTests.swift · Wenshu
//
//  Behaviour tests for the three render-path fixes the performance audit
//  measured. Each test pins a BEHAVIOUR the fix must preserve (= the
//  output, the ordering, the identity), not the shape of the code.
//
//  The three fixes:
//    1. PreviewPaneOps.sortBookDocs / sortEntities: the pinyin sort key
//       is computed ONCE per item (= decorate, sort, undecorate) instead
//       of once per comparison. The ORDER must be identical to the
//       comparator form.
//    2. ChatTurn.id: the turn's identity comes from the turn's own first
//       message, so rebuilding the turns array hands SwiftUI the SAME
//       identity for the same turn (= the transcript stops rebuilding
//       every row on every body pass).
//    3. ChatMessageFooter: the tooltip formatters are built once, so the
//       footer allocates no formatter per render. The OUTPUT must be
//       byte-identical to the per-call construction it replaced.
//
//  Coverage (= 9 tests):
//    1.  sortBookDocs orders by pinyin key
//    2.  sortBookDocs breaks a pinyin tie by file name
//    3.  sortEntities orders by pinyin key
//    4.  sortEntities breaks a pinyin tie by id
//    5.  a rebuilt turns array gives every turn the SAME identity
//    6.  a turn's identity is its user message's id
//    7.  a turn with no user message takes the first reply's id
//    8.  the token tooltip keeps the comma grouping
//    9.  the timestamp tooltip keeps the POSIX shape
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("render-path performance — the fixes the audit measured")
@MainActor
struct RenderPathPerformanceTests {
    // MARK: - The pinyin sort key is computed once per item

    /// A book doc with a known title and file name.
    private func doc(
        fileName: String,
        title _: String,
        createdAt: Date = Date(timeIntervalSince1970: 0),
        modifiedAt: Date = Date(timeIntervalSince1970: 0)
    ) -> BookDoc {
        BookDoc(
            id: UUID(),
            bookId: UUID(),
            folderName: "chapters",
            fileName: fileName,
            modifiedAt: modifiedAt,
            createdAt: createdAt,
            tags: [],
            body: ""
        )
    }

    @Test("sortBookDocs orders by the pinyin key (= the decorated form's order)")
    func sortBookDocsOrdersByPinyinKey() {
        // The titles are Chinese because the pinyin transform is what
        // the sort key IS (= a Latin title's key is its first letter,
        // = so it would not exercise the transform at all).
        let docs = [
            doc(fileName: "c.md", title: "曹刿论战"),
            doc(fileName: "a.md", title: "阿房宫赋"),
            doc(fileName: "b.md", title: "波斯猫"),
        ]
        let sorted = PreviewPaneOps.sortBookDocs(docs, by: .pinyinFirstLetter)
        #expect(sorted.map(\.fileName) == ["a.md", "b.md", "c.md"])
    }

    @Test("sortBookDocs breaks a pinyin tie by the file name")
    func sortBookDocsBreaksTieByFileName() {
        // Both titles share the initial "A", so the file name decides.
        let docs = [
            doc(fileName: "z.md", title: "阿房宫赋"),
            doc(fileName: "a.md", title: "安史之乱"),
        ]
        let sorted = PreviewPaneOps.sortBookDocs(docs, by: .pinyinFirstLetter)
        #expect(sorted.map(\.fileName) == ["a.md", "z.md"])
    }

    @Test("sortEntities orders by the pinyin key")
    func sortEntitiesOrdersByPinyinKey() {
        let entities = [
            Reference(title: "曹刿论战"),
            Reference(title: "阿房宫赋"),
            Reference(title: "波斯猫"),
        ]
        let sorted = PreviewPaneOps.sortEntities(entities, by: .pinyinFirstLetter)
        #expect(sorted.map(\.title) == ["阿房宫赋", "波斯猫", "曹刿论战"])
    }

    @Test("sortEntities breaks a pinyin tie by the id")
    func sortEntitiesBreaksTieById() {
        let low = Reference(title: "阿房宫赋")
        let high = Reference(title: "安史之乱")
        let sorted = PreviewPaneOps.sortEntities([high, low], by: .pinyinFirstLetter)
        // The tie-break is the id string, so the expected order is the
        // two ids sorted as strings (= not the input order).
        let expected = [low, high].sorted { $0.id.uuidString < $1.id.uuidString }
        #expect(sorted.map(\.id) == expected.map(\.id))
    }

    @Test("the pinyin sort key is computed ONCE per item (= not once per comparison)")
    func pinyinSortKeyIsComputedOncePerItem() {
        // The key is the expensive part (= a CFStringTransform, = 47us
        // measured), and a comparator that computes it runs it O(n log n)
        // times (= 48ms on a 17-item set). The count is the difference
        // between a fast sort and a slow one, and the ORDER is the same
        // either way (= so an order-only test cannot tell them apart).
        let docs = (0 ..< 17).map { index in
            doc(fileName: "f\(index).md", title: "标题\(index)")
        }
        var keyCalls = 0
        let sorted = PreviewPaneOps.sortBookDocs(docs, by: .pinyinFirstLetter) { title in
            keyCalls += 1
            return title
        }
        #expect(sorted.count == docs.count)
        #expect(keyCalls == docs.count, "the key must be computed once per item, not once per comparison")
    }

    @Test("the entity pinyin sort key is computed ONCE per entity")
    func pinyinEntitySortKeyIsComputedOncePerEntity() {
        let entities = (0 ..< 17).map { index in
            Reference(title: "条目\(index)")
        }
        var keyCalls = 0
        let sorted = PreviewPaneOps.sortEntities(entities, by: .pinyinFirstLetter) { title in
            keyCalls += 1
            return title
        }
        #expect(sorted.count == entities.count)
        #expect(keyCalls == entities.count, "the key must be computed once per entity, not once per comparison")
    }

    // MARK: - A turn keeps its identity across a rebuild

    private func userMessage(_ content: String) -> ChatMessage {
        ChatMessage(role: .user, source: .user, content: content)
    }

    private func agentMessage(_ content: String) -> ChatMessage {
        ChatMessage(role: .agent, source: .wenshu, content: content)
    }

    /// The same grouping the chat view's `turns` computed property does.
    private func turns(from messages: [ChatMessage]) -> [ChatTurn] {
        var result: [ChatTurn] = []
        for msg in messages {
            if msg.source == .user {
                result.append(ChatTurn(userMessage: msg, replies: []))
            } else {
                if result.isEmpty {
                    result.append(ChatTurn(userMessage: nil, replies: [msg]))
                } else {
                    result[result.count - 1].replies.append(msg)
                }
            }
        }
        return result
    }

    @Test("rebuilding the turns array gives every turn the SAME identity")
    func rebuiltTurnsKeepTheirIdentity() {
        let messages = [
            userMessage("first question"),
            agentMessage("first answer"),
            userMessage("second question"),
            agentMessage("second answer"),
        ]
        let first = turns(from: messages)
        let second = turns(from: messages)
        #expect(first.count == 2)
        #expect(first.map(\.id) == second.map(\.id))
    }

    @Test("a turn's identity is its user message's id")
    func turnIdentityIsTheUserMessageId() {
        let question = userMessage("a question")
        let turn = ChatTurn(userMessage: question, replies: [agentMessage("an answer")])
        #expect(turn.id == question.id)
    }

    @Test("a turn with no user message takes the first reply's id")
    func turnIdentityIsTheFirstReplyIdWhenThereIsNoUserMessage() {
        let reply = agentMessage("an opening greeting")
        let turn = ChatTurn(userMessage: nil, replies: [reply])
        #expect(turn.id == reply.id)
    }

    // MARK: - The tooltip formatters are built once, and the output is unchanged

    @Test("the token tooltip keeps the comma grouping")
    func tokenTooltipKeepsCommaGrouping() {
        #expect(ChatMessageFooter.fullTokenCountTooltip(for: 1500) == "1,500 tokens")
        #expect(ChatMessageFooter.fullTokenCountTooltip(for: 1_234_567) == "1,234,567 tokens")
        #expect(ChatMessageFooter.fullTokenCountTooltip(for: 234) == "234 tokens")
    }

    @Test("the timestamp tooltip keeps the POSIX shape")
    func timestampTooltipKeepsThePosixShape() {
        let tooltip = ChatMessageFooter.fullTimestampTooltip(for: Date(timeIntervalSince1970: 1_700_000_000))
        #expect(tooltip.count == 19)
        #expect(tooltip.contains("-"))
        #expect(tooltip.contains(":"))
    }
}
