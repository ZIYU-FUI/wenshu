//
//  ChatScrollMechanismTests.swift · WenshuApp
//
//  The mechanism that keeps the reader's place.
//
//  WHY
//  ===
//  The behaviour suite drives the MODEL (= = it calls
//  `readerLeftTheBottom()`), = = so it proves the model's flag, = = and
//  not the production path that is supposed to set that flag. = =
//  Measured: deleting the viewport's row binding, = = deleting the hop
//  that writes the reader's place, = = making the follow ignore the
//  gate, = = or never rendering the way back left EVERY suite green.
//
//  A suite that stays green when the mechanism is gone measures
//  nothing. = = So these cases read the VIEW's own source, = = and
//  they name the four pieces the claim rests on:
//
//    1. the viewport is bound to the row the reader is looking at
//       (= = Apple's `scrollPosition(id:)`, = = the viewport's own
//       write path);
//    2. the view writes the reader's place when that row changes
//       (= = the hop);
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

    private static func source(_ relative: String) throws -> String {
        let url = SourceLocator.url(relative)
        return try String(contentsOf: url, encoding: .utf8)
    }

    @Test("The viewport is bound to the row the reader is looking at")
    func theViewportIsBoundToTheReadersRow() throws {
        let source = try Self.source(Self.chatView)
        #expect(source.contains(".scrollPosition(id: $vm.anchoredRowID"),
                "The viewport must be bound to the reader's row (= = Apple's own write path)")
    }

    @Test("The view writes the reader's place when that row changes")
    func theViewWritesTheReadersPlace() throws {
        let source = try Self.source(Self.chatView)
        #expect(source.contains(".onChange(of: vm.anchoredRowID)"),
                "The view must notice that the reader's row changed")
        #expect(source.contains("vm.readerMoved("),
                "The view must write the reader's place (= = the model's gate reads it)")
    }

    @Test("The follow reads the gate, and puts the viewport back through the binding")
    func theFollowReadsTheGate() throws {
        let source = try Self.source(Self.transcript)
        #expect(source.contains("guard force || vm.readerIsAtBottom else { return }"),
                "The follow must stop when the reader is away (= = the gate is its condition)")
        #expect(!source.contains("guard true"),
                "The follow must not follow unconditionally (= = that is the defect the gate fixes)")
        #expect(source.contains("vm.anchoredRowID = ChatTranscriptBottom.clearanceID"),
                "The follow must put the viewport back through the binding (= = the row it binds)")
    }

    @Test("The way back is drawn under the gate's condition")
    func theWayBackIsDrawnUnderTheCondition() throws {
        let source = try Self.source(Self.chatView)
        #expect(source.contains("if offersWayBack {"),
                "The control must be drawn while the reader is away (= = the condition is the promise)")
    }
}
