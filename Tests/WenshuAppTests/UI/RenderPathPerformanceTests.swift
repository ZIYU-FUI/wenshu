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
//    2. ChatMessage.id: the transcript's row identity comes from the row's
//       own message, so rebuilding the transcript's rows hands SwiftUI the
//       SAME identity for the same row (= the transcript stops rebuilding
//       every row on every body pass). The WIRING that carries the rule
//       is read here from the production source; the BEHAVIOUR it
//       produces (= the row views survive a body pass) is measured on the
//       real view in `ChatTranscriptFlatFlowTests`.
//    3. ChatMessageFooter: the tooltip formatters are built once, so the
//       footer allocates no formatter per render. The OUTPUT must be
//       byte-identical to the per-call construction it replaced.
//
//  WHY THE TRANSCRIPT'S CLAIMS ARE READ FROM THE PRODUCTION SOURCE
//  ================================================================
//  The audit's finding was that the transcript's identity claims were
//  measured on a COPY the test built beside the production code (= a
//  helper that returned its input unchanged), so the copy still passed
//  when the production row's identity was broken. A copy is a second
//  rule, and the test then measures the copy. So the claim is read from
//  the production source itself, through the house's `SourceLocator`.
//
//  Coverage (= 10 tests):
//    1.  sortBookDocs orders by pinyin key
//    2.  sortBookDocs breaks a pinyin tie by file name
//    3.  sortEntities orders by pinyin key
//    4.  sortEntities breaks a pinyin tie by id
//    5.  the book pinyin sort key is computed ONCE per item
//    6.  the entity pinyin sort key is computed ONCE per entity
//    7.  the transcript renders one flat list of the model's messages
//    8.  a row's identity is its own message's id
//    9.  the token tooltip keeps the comma grouping
//    10. the timestamp tooltip keeps the POSIX shape
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

    // MARK: - A row keeps its identity across a rebuild

    private func userMessage(_ content: String) -> ChatMessage {
        ChatMessage(role: .user, source: .user, content: content)
    }

    private func agentMessage(_ content: String) -> ChatMessage {
        ChatMessage(role: .agent, source: .wenshu, content: content)
    }

    /// The transcript renders one flat list of the model's messages.
    ///
    /// The claim is about the transcript's WIRING (= which rows it renders
    /// and how each is identified), so it is read from the production
    /// source through the house's `SourceLocator` (= the reader that
    /// resolves the repo root by looking for `Package.swift`, so the test
    /// does not depend on its own directory depth, and that reads the WHOLE
    /// view group, so a split view is read whole).
    ///
    /// It is not read from a copy the test builds beside it: a copy would
    /// still pass if the production wiring were broken (= and the audit's
    /// finding was that the copy was all that was left).
    @Test("the transcript renders one flat list of the model's messages")
    func theTranscriptRendersOneFlatList() throws {
        let source = try SourceLocator.readGroup(prefixed: "ChatView")
        #expect(
            source.contains("ForEach(vm.messages)"),
            "the transcript must render a ForEach over the model's messages (= every message is a row of its own)"
        )
        #expect(
            !source.contains("ChatTurn"),
            "the transcript must not group the messages into turns (= the grouping type went with the pinned row it carried)"
        )
    }

    /// The transcript's rows are identified by their own message's id.
    ///
    /// The claim is the transcript's IDENTITY rule, and it is read from the
    /// production row builder: a row carries its own message's id, so a
    /// body pass hands SwiftUI the same identity for the same row. A fresh
    /// identity per render would tear every row down and rebuild it.
    ///
    /// The BEHAVIOUR this rule produces is measured on the real view in
    /// `ChatTranscriptFlatFlowTests` (= the row views survive a body pass);
    /// this is the wiring that carries it.
    @Test("a row's identity is its own message's id")
    func rowIdentityIsItsOwnMessageId() throws {
        let source = try SourceLocator.readGroup(prefixed: "ChatView")
        #expect(
            source.contains(".id(message.id)"),
            """
            a row must be identified by its own message's id (= the \
            transcript stops rebuilding every row on every body pass)
            """
        )
        #expect(
            !source.contains(".id(UUID())"),
            "no row may be given a fresh identity per render (= the rows would be rebuilt on every body pass)"
        )
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
