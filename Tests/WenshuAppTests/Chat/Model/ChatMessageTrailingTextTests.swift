//
//  ChatMessageTrailingTextTests.swift · wenshu
//
//  The streaming cursor belongs to ONE block.
//
//  The cursor marks where the model is writing, = so there is one per
//  reply: = it sits at the end of the last text block. (= hermes draws
//  it once, = on the trailing block.)
//
//  The boss's own report (= measured on the import sheet): several
//  cursors blinked at once, = because every text block drew its own.
//

import WenshuData
import XCTest
@testable import WenshuApp

final class ChatMessageTrailingTextTests: XCTestCase {

    func testTheCursorBelongsToTheLastTextBlock() {
        let first = ChatMessagePart.text("first")
        let second = ChatMessagePart.text("second")
        let message = ChatMessage(
            role: .agent,
            content: "",
            parts: [first, second]
        )
        XCTAssertEqual(message.trailingTextPartID, second.id)
    }

    func testAToolBlockAfterTheTextDoesNotTakeTheCursor() {
        let text = ChatMessagePart.text("the answer")
        let tool = ChatMessagePart.toolUse(
            id: ToolCallID(rawValue: "call-1"),
            name: "writeBookDoc",
            args: "{}"
        )
        let message = ChatMessage(
            role: .agent,
            content: "",
            parts: [text, tool]
        )
        // The cursor marks where the model is writing (= the text), = not
        // the tool card that came after it.
        XCTAssertEqual(message.trailingTextPartID, text.id)
    }

    func testAMessageWithoutTextHasNoCursor() {
        let message = ChatMessage(
            role: .agent,
            content: "",
            parts: [ChatMessagePart.reasoning("thinking")]
        )
        XCTAssertNil(message.trailingTextPartID)
    }
}
