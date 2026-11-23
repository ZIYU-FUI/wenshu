//  ChatStreamingVisibilityTests.swift
//
//  What this file holds, and how each claim is held:
//
//  1. THE STREAMED ROW IS DRAWN. A reply that is still arriving holds
//     parts (= the text the model wrote, the tools it called). The
//     transcript must draw those parts as they arrive: the writer
//     watches the reply build up.
//  2. THE EMPTY ROW IS STILL A PLACEHOLDER. A row that holds no part
//     yet (= a slow provider, a queued turn) keeps the pulse row.
//  3. THE FLAG CLEARS IN PLACE. The row that stops being a placeholder
//     is the SAME row (= same identity, same object): replacing it
//     would rebuild it and take the reader's per-part choices with it.
//
//  WHY THE MEASUREMENT IS THE RENDERED TREE
//  ==========================================
//  The frame writer puts the parts on the row on every frame, and
//  the view must draw those parts (= = not a pulse row), = = so the
//  reply appears while it streams. = = A claim about "the parts are
//  on the row" is not enough on its own: = = the row can carry the
//  parts and still show a pulse row instead of them, = = so every
//  claim here is read off the rendered tree.
//
//  So each claim here is read off the BUILT tree, through the repo's
//  own accessibility reader (= the same reader the inspector tests
//  use, = `InspectorAXTree`). An offscreen SwiftPM test host paints
//  raw localization keys, so the searches look for text this fixture
//  wrote itself (= fixture data, = never a localized string).
//
//  NOTHING HERE PRINTS INSTEAD OF ASSERTING, and nothing sleeps for a
//  budget.
//
//  THE MEASUREMENT MUST BE ABLE TO FAIL
//  =====================================
//  A green suite that cannot go red proves nothing. The arm that
//  matters is the mutant: put the placeholder branch back to the flag
//  alone (= the pre-fix condition) and every claim in claim 1 must go
//  red. The suite below was checked against that arm.
//

import AppKit
import Foundation
import SwiftUI
import Testing
import WenshuAgent
@testable import WenshuApp
import WenshuData

@MainActor
@Suite("a streamed reply is drawn while it streams")
struct ChatStreamingVisibilityTests {
    // MARK: - The fixture

    /// The text this fixture puts in the streamed reply. It is data,
    /// not a localized string, so it is legal to search the built tree
    /// for it.
    private static let replyText = "the chapter opens in the rain"
    /// The tool name this fixture puts in the streamed reply. Same
    /// reason: fixture data, so it is legal to search for it.
    private static let toolName = "read_file"
    /// The text the BODY path draws.
    ///
    /// The body's own words are what the row's `content` says, = = so
    /// a row that holds them draws them. The placeholder path draws the
    /// pulse and its hint instead, = = so a row that holds them but
    /// takes the placeholder path publishes neither.
    private static let bodyText = "the body path draws this"

    /// A reply that is still arriving: it carries the text and the tool
    /// call, and it is still marked as the row the turn began with.
    private func streamingMessage() -> ChatMessage {
        var message = ChatMessage(
            role: .agent,
            source: .wenshu,
            content: Self.replyText,
            isPlaceholder: true
        )
        message.parts = [
            .text(Self.replyText),
            .toolUse(id: ToolCallID(rawValue: "call-1"), name: Self.toolName, args: "{}"),
        ]
        message.streamState = .streaming
        return message
    }

    // MARK: - The host

    /// A borderless window far offscreen: the hosted view has to reach
    /// the screen's AppKit context or the renderer never resolves its
    /// own size, and at these coordinates nothing appears on the
    /// writer's desktop.
    private static func host<Content: View>(
        _ root: Content
    ) -> (host: NSHostingView<AnyView>, window: NSWindow) {
        let hosting = NSHostingView(rootView: AnyView(root.environment(WorkspaceUIState())))
        let window = NSWindow(
            contentRect: NSRect(x: -20000, y: -20000, width: 720, height: 600),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = hosting
        window.orderFrontRegardless()
        hosting.layoutSubtreeIfNeeded()
        return (hosting, window)
    }

    private static func teardown(_ hosted: (host: NSHostingView<AnyView>, window: NSWindow)) {
        hosted.window.orderOut(nil)
        hosted.window.contentView = nil
    }

    /// Every string the built tree publishes, read through the repo's
    /// own accessibility reader.
    private static func publishedTexts(of message: ChatMessage) -> [String] {
        let hosted = host(ChatMessageView(message: message))
        defer { teardown(hosted) }
        return InspectorAXTree.elements(of: hosted.host).map(\.published)
    }

    // MARK: - The claims

    @Test("a reply that holds parts draws them, not the pulse row")
    func streamedPartsAreDrawn() {
        let texts = Self.publishedTexts(of: streamingMessage())

        #expect(
            texts.contains { $0.contains(Self.replyText) },
            "the streamed reply's text is on the tree: \(texts)"
        )
        // The tool name is NOT asserted here. The tool card is a
        // tap-gesture surface with no accessibility label, so the tool
        // name is not published to the accessibility tree (= a separate
        // finding about the tool card's own surface, = not this card's
        // claim). Asserting it here would make this suite hold a claim
        // about a surface it does not own.
    }

    @Test("a row that holds no part yet is still the placeholder row")
    func emptyRowKeepsThePlaceholder() {
        // The row is born EMPTY (= no content, no parts): the
        // placeholder row's hint is the VIEW's own text, = = and a row
        // that carried the hint as its content would synthesize a .text
        // part (= the initializer does that when the content is not
        // empty), = = so the row would look like it already held a reply.
        //
        // This is the state the row is in before the first frame
        // arrives: it holds no part, = = so it draws the pulse row
        // (= = even though the fixture gives it the text the body path
        // would draw, = = so the claim below is about WHICH path drew
        // the row, = = and not about the text being absent).
        var message = ChatMessage(
            role: .agent,
            source: .wenshu,
            content: "",
            isPlaceholder: true
        )
        message.parts = []
        // The row carries the text the BODY path would draw, = = so the
        // claim below (= = "the placeholder path does not draw the
        // row's content") is a claim about WHICH path drew the row, = =
        // and not a claim that is true for every possible view.
        message.content = Self.bodyText
        message.streamState = .streaming

        let texts = Self.publishedTexts(of: message)

        // The row holds NO PART (= = the body's text is on the row, = =
        // but the row takes the placeholder's path): nothing of a reply
        // is on the tree. The row's hint is a localized string, and an
        // offscreen host paints the raw key (= never the word), so the
        // assertion cannot be about the hint's text.
        //
        // The handle that DOES exist is the row's own content: the body
        // path draws the row's `content`, = = and the placeholder path
        // does not. So the claim here is made by giving the row content
        // the body would draw, = = and by seeing whether it shows up:
        //
        // - the placeholder row (this case): the content must NOT show
        //   up, = = because the placeholder row draws its pulse and its
        //   hint, = = not the row's content;
        // - the row that holds parts (the case above): the content DOES
        //   show up.
        //
        // Together the two cases pin WHICH path draws the row, = = and
        // the pair can go red: with the branch inverted (= = an empty row
        // drawing the body), the first case goes red.
        #expect(
            !texts.contains { $0.contains(Self.bodyText) },
            "an empty row must not draw the body's text: \(texts)"
        )
    }

    @Test("the frame writer clears the flag on the same row")
    func frameWriterClearsTheFlagInPlace() {
        let viewModel = ChatViewModel(
            initialMessages: [],
            repository: EmptyChatRepository(),
            providersConfigured: { true }
        )
        let rowID = UUID()
        var row = ChatMessage(
            id: rowID,
            role: .agent,
            source: .wenshu,
            content: "AI thinking",
            isPlaceholder: true
        )
        row.parts = []
        row.streamState = .streaming
        viewModel.messages = [row]

        let accumulator = StreamingAccumulator()
        accumulator.appendText(Self.replyText)

        viewModel.applyStreamBatch(
            StreamBatch(text: "", reasoning: "", blocks: []),
            placeholderId: rowID,
            accumulator: accumulator
        )

        // The row is the same row (= same identity): a replacement would
        // take the reader's per-part choices with it.
        #expect(
            viewModel.messages.count == 1,
            "the frame did not add a row"
        )
        #expect(
            viewModel.messages.first?.id == rowID,
            "the frame kept the row's identity"
        )
        #expect(
            viewModel.messages.first?.isPlaceholder == false,
            "the row stopped being a placeholder once it held a part"
        )
        #expect(
            viewModel.messages.first?.parts.isEmpty == false,
            "the row holds the part the frame produced"
        )
    }
}

/// A repository that stores nothing: this suite drives the frame writer
/// directly, and the real repository would touch SwiftData.
private final class EmptyChatRepository: ChatRepositoryProtocol, @unchecked Sendable {
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
