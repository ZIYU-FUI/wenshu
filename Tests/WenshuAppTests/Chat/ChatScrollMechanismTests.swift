//
//  ChatScrollMechanismTests.swift · WenshuApp
//
//  The mechanism that keeps the reader's place.
//
//  WHY
//  ===
//  The behaviour suite drives the MODEL (it calls
//  `readerAtBottomChanged`), so it proves the model's flag, and not the
//  production path that is supposed to set it. Measured: deleting the
//  viewport's row binding, deleting the call that hands Apple's answer
//  to the model, making the follow ignore the gate, or never rendering
//  the way back left EVERY suite green.
//
//  A suite that stays green when the mechanism is gone measures
//  nothing. = = So these cases read the VIEW's own source, = = and
//  they name the four pieces the claim rests on:
//
//    1. the viewport is bound to the row the reader is looking at
//       (= = Apple's `scrollPosition(id:)`, = = the viewport's own
//       write path);
//    2. the view asks Apple whether the bottom target is on screen, and
//       hands that answer to the model (the hop);
//    3. the follow reads the gate (= = it does not follow a reader who
//       is away), = = and it puts the viewport back through the
//       binding;
//    4. the way back is drawn under the gate's condition.
//
//  Why the source and not the model: = = an offscreen host cannot
//  deliver a scroll to SwiftUI (= = the geometry callback never saw a
//  programmatic scroll), = = so the only honest way to hold the
//  production path is to hold the text that IS the production path.
//
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("The scroll mechanism is present (= = the view's own write path)")
struct ChatScrollMechanismTests {
    private static let chatView = "Sources/WenshuApp/Features/Chat/View/ChatView.swift"
    private static let transcript = "Sources/WenshuApp/Features/Chat/View/ChatView+Transcript.swift"
    private static let model = "Sources/WenshuApp/Features/Chat/Store/ChatViewModel.swift"

    private static func source(_ relative: String) throws -> String {
        let url = SourceLocator.url(relative)
        return try String(contentsOf: url, encoding: .utf8)
    }

    @Test("The viewport is bound to the row the reader is looking at")
    func theViewportIsBoundToTheReadersRow() throws {
        let source = try Self.source(Self.chatView)
        #expect(source.contains(".scrollPosition(id: $anchoredRowID"),
                "The viewport must be bound to the reader's row (= = Apple's own write path)")
    }

    @Test("The reader's scroll position is the view's state, not the model's")
    func theScrollPositionIsTheViewsState() throws {
        let view = try Self.source(Self.chatView)
        let model = try Self.source(Self.model)
        #expect(view.contains("@State var anchoredRowID: UUID?"),
                "The anchor must be view state (= = Apple writes it back on every scroll)")
        #expect(!model.contains("anchoredRowID"),
                "The model must not hold the reader's scroll position (= = that write reaches every observer of the model)")
        #expect(!view.contains("$vm.anchoredRowID"),
                "The binding must not reach the model (= = the reader's wheel is the viewport's business)")
    }

    @Test("The view asks Apple whether the bottom target is on screen")
    func theViewAsksApple() throws {
        let source = try Self.source(Self.chatView)
        #expect(source.contains(".onScrollTargetVisibilityChange"),
                "The gate must ride Apple's own visibility signal, not a distance we measure")
        #expect(source.contains("ids.contains(ChatTranscriptBottom.clearanceID)"),
                "The view must hand Apple's answer for the clearance row to the model")
        #expect(source.contains(".onScrollPhaseChange"),
                "The gate must learn from Apple whether the reader is the one moving")
        #expect(source.contains("if bottomVisible || readerIsScrolling {"),
                "The bottom row being off screen may count as leaving only while the reader is moving")
        #expect(!source.contains("ChatTranscriptBottom.distanceFromBottom"),
                "The view must not compute the distance from the bottom itself")
        #expect(!source.contains("ChatTranscriptBottom.atBottomBand"),
                "The view must not carry a tolerance we tuned")
    }

    @Test("The follow reads the gate, and puts the viewport back through the binding")
    func theFollowReadsTheGate() throws {
        let source = try Self.source(Self.transcript)
        #expect(source.contains("guard force || vm.readerIsAtBottom else { return }"),
                "The follow must stop when the reader is away (= = the gate is its condition)")
        #expect(!source.contains("guard true"),
                "The follow must not follow unconditionally (= = that is the defect the gate fixes)")
        #expect(source.contains("anchoredRowID = ChatTranscriptBottom.clearanceID"),
                "The follow must put the viewport back through the binding (= = the row it binds)")
        #expect(!source.contains("vm.anchoredRowID"),
                "The follow must not put the anchor into the model (= = one fact, one owner: it is the viewport's)")
    }

    @Test("The way back is drawn under the gate's condition")
    func theWayBackIsDrawnUnderTheCondition() throws {
        let source = try Self.source(Self.chatView)
        #expect(source.contains("if offersWayBack {"),
                "The control must be drawn while the reader is away (= = the condition is the promise)")
    }
}
