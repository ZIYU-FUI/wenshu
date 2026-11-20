//
//  ChatStreamIdentityTests.swift
//
//  What this card is allowed to claim, and how each claim is held:
//
//  1. THE COUNTING SEAM. Apple describes a streamed reply as "An async
//     sequence of snapshots of partially generated content", and one
//     reply as a list of segments each carrying a stable identity, so a
//     growing tail re-renders only the segment that grew. The counts here
//     are the halves of that which this app can be measured on without a
//     renderer: an appended frame destroys no part, mints no part it did
//     not have to mint, grows exactly one part, and keeps the reply text
//     it draws its parts from. (= Measured against the unmodified tree
//     first: an appended frame did none of the destroying this card was
//     asked to look for, so these are the guards that hold it that way,
//     not a fix dressed up as one.)
//  2. THE FOLLOW-THE-TAIL KEY. The transcript scrolls to the newest block
//     when the newest block moves, and does not move for anything else.
//     Asserted on the key the scroll is gated on.
//  3. THE DISCLOSURE-STATE SEAM. Apple's rule for a scrolling list is
//     "don't depend on view state for data that needs to be kept alive
//     after scrolling". A thinking block the reader closed is that data:
//     the row that drew it is built again when the reply grows, and is
//     not built at all while a `LazyVStack` has scrolled it out of the
//     viewport. So the collapse is proved to live on the part (= state)
//     and to survive both, and the block is proved to have no body in the
//     tree that is built for a collapsed part (= structure, read through
//     the repo's own accessibility reader).
//
//  Nothing here prints instead of asserting, nothing here sleeps for a
//  budget, and no claim in this file rests on a rendered label: an
//  offscreen host from a SwiftPM test target paints raw localization
//  keys, so the searches below look for text this fixture wrote itself.
//

import AppKit
import Foundation
import SwiftUI
import Testing
@testable import WenshuApp

@MainActor
@Suite("streamed snapshot: what an append does, and what a collapse survives")
struct ChatStreamIdentityTests {
    /// The reasoning text this fixture puts in the reply. It is data, not
    /// a localized string, so it is legal to search the built tree for it.
    private static let reasoningText = "what the model weighed"
    private static let reasoningChunk = "[[thinking: \(reasoningText)]] "

    // MARK: - The fixture

    /// A conversation with settled replies in it, plus the reply that is
    /// still arriving.
    private func makeViewModel(settledReplies: Int = 4, partsPerReply: Int = 3) -> (ChatViewModel, UUID) {
        let streamingID = UUID()
        var transcript: [ChatMessage] = []
        for index in 0 ..< settledReplies {
            var message = ChatMessage(role: .agent, source: .wenshu, content: "settled reply \(index)")
            message.parts = (0 ..< partsPerReply).map { ChatMessagePart.text("block \($0) of reply \(index). ") }
            message.streamState = .sealed
            transcript.append(message)
        }
        transcript.append(
            ChatMessage(id: streamingID, role: .agent, source: .wenshu, content: "", isPlaceholder: true)
        )
        return (ChatViewModel(initialMessages: transcript, providersConfigured: { true }), streamingID)
    }

    /// Feeds one chunk through the same entry point the agent stream uses.
    private func feed(_ vm: ChatViewModel, _ id: UUID, _ acc: StreamingAccumulator, _ chunk: String) {
        vm.applyStreamBatch(StreamBatch(text: chunk), placeholderId: id, accumulator: acc)
    }

    /// The id of the reply's reasoning block, taken from the fixture's own
    /// part structure (= never from a rendered title).
    private func reasoningPartID(_ message: ChatMessage) -> UUID? {
        message.parts.first { part in
            if case .reasoning = part.kind {
                return true
            }
            return false
        }?.id
    }

    // MARK: - 1. The counting seam

    @Test("an appended frame destroys no part and mints none it did not need")
    func appendedFrameKeepsEveryPartItAlreadyHad() throws {
        let (vm, streamingID) = makeViewModel(settledReplies: 0)
        let acc = StreamingAccumulator()
        feed(vm, streamingID, acc, "intro ")
        let before = vm.messages[0].parts
        let introID = try #require(before.first?.id, "The reply has a text part to grow")

        // Fifteen frames, which is what a sentence costs.
        for round in 1 ... 15 {
            feed(vm, streamingID, acc, "word\(round) ")
        }
        let after = vm.messages[0].parts
        let afterIDs = Set(after.map(\.id))
        let dropped = Set(before.map(\.id)).subtracting(afterIDs)
        let minted = afterIDs.subtracting(Set(before.map(\.id)))
        #expect(dropped.isEmpty, "Fifteen appended frames destroyed \(dropped.count) part(s) the reader was shown")
        #expect(minted.isEmpty, "Fifteen appended frames minted \(minted.count) part(s) out of nothing")
        let grewInPlace = after.first { $0.id == introID }.map { part in
            if case let .text(text) = part.kind {
                return text.hasPrefix("intro word1 ")
            }
            return false
        } ?? false
        #expect(grewInPlace, "The part that grew grew in place instead of being written again")
    }

    @Test("a closed marker mints exactly the block it names")
    func markerCloseMintsOneBlockAndKeepsTheAnswer() throws {
        let (vm, streamingID) = makeViewModel(settledReplies: 0)
        let acc = StreamingAccumulator()
        feed(vm, streamingID, acc, "the answer so far ")
        let before = vm.messages[0].parts
        let answerID = try #require(before.first?.id, "The answer is one text part before the marker lands")

        feed(vm, streamingID, acc, Self.reasoningChunk)
        let after = vm.messages[0].parts
        let afterIDs = Set(after.map(\.id))
        let dropped = Set(before.map(\.id)).subtracting(afterIDs)
        let minted = afterIDs.subtracting(Set(before.map(\.id)))
        #expect(dropped.isEmpty, "Lifting the marker destroyed the answer's part: \(dropped)")
        #expect(minted.count <= 1, "Lifting one marker minted \(minted.count) parts")
        let answerKept = after.first { $0.id == answerID }.flatMap { part in
            if case let .text(text) = part.kind {
                return text
            }
            return nil
        }
        let keptTheWords = answerKept.map { $0.contains("the answer so far") && !$0.contains("[[") } ?? false
        #expect(keptTheWords, "The part that kept its id no longer holds the answer: \(String(describing: answerKept))")
    }

    @Test("a blank remainder leaves one part, not an empty row")
    func markerOnlyRunKeepsItsIdentity() {
        let (vm, streamingID) = makeViewModel(settledReplies: 0)
        let acc = StreamingAccumulator()
        feed(vm, streamingID, acc, Self.reasoningChunk)
        let after = vm.messages[0].parts
        let onePart = after.count == 1
        #expect(onePart, "A run that became a block left \(after.count) parts")
        let becameTheBlock = after.first.flatMap { part in
            if case .reasoning = part.kind {
                return true
            }
            return false
        } ?? false
        #expect(becameTheBlock, "The block is the run that carried the marker")
    }

    @Test("the reply text is the parts the reply is drawn from")
    func replyTextMatchesItsOwnParts() {
        let (vm, streamingID) = makeViewModel(settledReplies: 0)
        let acc = StreamingAccumulator()
        for chunk in ["plain ", Self.reasoningChunk, "more ", "[[action: did a thing]] ", "end"] {
            feed(vm, streamingID, acc, chunk)
            let agrees = vm.messages[0].content == ChatMessagePart.joinedText(vm.messages[0].parts)
            #expect(agrees, "The reply's text and its parts disagree after \(chunk.debugDescription)")
        }
    }

    @Test("a closing bracket that straddles two frames still lifts")
    func closerAcrossFrameBoundary() {
        let (vm, streamingID) = makeViewModel(settledReplies: 0)
        let acc = StreamingAccumulator()
        feed(vm, streamingID, acc, "answer ")
        feed(vm, streamingID, acc, "[[thinking: split closer ")
        let showsAsText = vm.messages[0].parts.count == 1
        #expect(showsAsText, "A half-written marker is still shown as text")
        feed(vm, streamingID, acc, "and weighed]] tail")
        let parts = vm.messages[0].parts
        let blockAndAnswer = parts.count == 2
        #expect(blockAndAnswer, "The closed marker and the remainder are two parts: \(parts.count)")
        let keepsItsWords = parts.last.flatMap { part in
            if case let .text(text) = part.kind {
                return text.contains("tail")
            }
            return false
        } ?? false
        #expect(keepsItsWords, "The answer keeps its own words")
    }

    // MARK: - 2. The key the follow-the-tail scroll is gated on

    @Test("the follow key moves when the tail moves and only then")
    func followKeyMovesOnlyWithTheTail() throws {
        let (vm, streamingID) = makeViewModel(settledReplies: 0)
        let acc = StreamingAccumulator()
        feed(vm, streamingID, acc, "the answer so far ")
        let before = try #require(vm.messages.last?.streamFollowKey, "A streaming reply carries a follow key")

        feed(vm, streamingID, acc, "and it grew ")
        let afterGrowth = try #require(vm.messages.last?.streamFollowKey)
        #expect(before != afterGrowth, "The tail grew and the follow key did not move (= the scroll never fires)")

        // A frame that touches nothing the reader is following: the same
        // bytes, asked about again.
        let again = vm.messages.last?.streamFollowKey
        #expect(again == afterGrowth, "Asking the same tail twice gave two different keys (= the scroll fires on nothing)")

        // A new block changes the block being followed, not only its text.
        feed(vm, streamingID, acc, Self.reasoningChunk)
        let withBlock = try #require(vm.messages.last?.streamFollowKey)
        #expect(withBlock != afterGrowth, "A block landed and the follow key held still (= it is never scrolled to)")
    }

    // MARK: - 3. The disclosure seam: state

    @Test("a collapse survives the frames that arrive after it")
    func collapseSurvivesAnAppendedSnapshot() throws {
        let (vm, streamingID) = makeViewModel(settledReplies: 0)
        let acc = StreamingAccumulator()
        feed(vm, streamingID, acc, Self.reasoningChunk)
        feed(vm, streamingID, acc, "the answer so far ")

        let partID = try #require(reasoningPartID(vm.messages[0]), "The fixture reply has a thinking block")
        let openAtFirst = vm.messages[0].parts.first { $0.id == partID }?.isThinkingRevealed == true
        #expect(openAtFirst, "A block the reader never touched is shown open")

        // The reader closes it.
        vm.setThinkingRevealed(false, messageID: streamingID, partID: partID)
        let closedNow = vm.messages[0].parts.first { $0.id == partID }?.isThinkingRevealed == false
        #expect(closedNow, "The collapse did not land on the part the reader closed")

        // The reply keeps arriving: every frame writes the parts array
        // again from the accumulator, which never heard about the reader.
        for round in 1 ... 5 {
            feed(vm, streamingID, acc, "more words \(round) ")
        }
        let parts = vm.messages[0].parts
        let stillTheSameBlock = parts.contains { $0.id == partID }
        #expect(stillTheSameBlock, "The block the reader closed is no longer in the reply")
        let stillClosed = parts.first { $0.id == partID }?.isThinkingRevealed == false
        #expect(stillClosed, "Five appended frames undid the reader's collapse")
    }

    @Test("a collapse survives the row being torn down and built again")
    func collapseSurvivesTheRowBeingRebuilt() throws {
        // A `LazyVStack` realises the rows near the visible band only: a row
        // that scrolls out is torn down, and the row that scrolls back in is
        // built again from the model. What survives that is what the model
        // holds, so the reply is grown while the first host is gone and the
        // check is made after a second host has been built over the same
        // store (= the store is the only thing the two hosts share).
        let (vm, streamingID) = makeViewModel()
        let acc = StreamingAccumulator()
        feed(vm, streamingID, acc, Self.reasoningChunk)
        feed(vm, streamingID, acc, "the answer so far ")

        let streaming = try #require(vm.messages.last)
        let partID = try #require(reasoningPartID(streaming))
        vm.setThinkingRevealed(false, messageID: streamingID, partID: partID)

        let first = Self.host(ChatMessageBodyView(message: streaming))
        Self.teardown(first)

        feed(vm, streamingID, acc, "words that arrived while nothing was drawn ")
        let rebuilt = try #require(vm.messages.last)
        let second = Self.host(ChatMessageBodyView(message: rebuilt))
        defer { Self.teardown(second) }

        let carried = rebuilt.parts.first { $0.id == partID }
        let cameBackClosed = carried?.isThinkingRevealed == false
        #expect(cameBackClosed, "The block came back open after the row was built again from the model")
    }

    // MARK: - 4. The disclosure seam: structure

    @Test("a collapsed block has no body in the tree that is built for it")
    func collapsedBlockHasNoBodyInItsTree() throws {
        let (vm, streamingID) = makeViewModel(settledReplies: 0)
        let acc = StreamingAccumulator()
        feed(vm, streamingID, acc, Self.reasoningChunk)
        feed(vm, streamingID, acc, "the answer so far ")
        let partID = try #require(reasoningPartID(vm.messages[0]))
        let openMessage = vm.messages[0]

        // The search finds the fixture's own reasoning text when the block
        // is open. Without this the absence asserted below would be a
        // property of the search, not of the block.
        let openTexts = Self.publishedTexts(of: openMessage)
        let bodyIsDrawnWhenOpen = openTexts.contains { $0.contains(Self.reasoningText) }
        #expect(bodyIsDrawnWhenOpen, "An open block does not put its own text in the tree (= nothing to compare)")

        // The reader closes it, and the tree is built again from that part.
        vm.setThinkingRevealed(false, messageID: streamingID, partID: partID)
        let closedTexts = Self.publishedTexts(of: vm.messages[0])
        let bodyIsGoneWhenClosed = !closedTexts.contains { $0.contains(Self.reasoningText) }
        #expect(bodyIsGoneWhenClosed,
                "The block stayed open in the tree that was built after the reader closed it")
        let answerStillDrawn = closedTexts.contains { $0.contains("the answer so far") }
        #expect(answerStillDrawn, "Closing the block took the answer down with it")
    }

    // MARK: - The host

    /// A borderless window far offscreen: the hosted view has to reach the
    /// screen's AppKit context or the renderer never resolves its own size,
    /// and at these coordinates nothing appears on the writer's desktop.
    private static func host(_ root: ChatMessageBodyView) -> (host: NSHostingView<AnyView>, window: NSWindow) {
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

    /// Every string the built tree publishes, read through the repo's own
    /// accessibility reader (= the same reader the inspector tests use).
    private static func publishedTexts(of message: ChatMessage) -> [String] {
        let hosted = host(ChatMessageBodyView(message: message, isStreaming: false))
        defer { teardown(hosted) }
        return InspectorAXTree.elements(of: hosted.host).map(\.published)
    }
}
