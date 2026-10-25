//
//  ImportAgentReplyPartsTests.swift · wenshu
//
//  The import row shows the agent's reply, using the chat zone's own
//  parts.
//
//  Coverage:
//    1. The import task carries parts, not log lines.
//    2. A text block becomes a text part and a tool-call block becomes
//       a tool-call part.
//    3. The tool call's arguments are summarised, so the document body
//       does not bury the reply.
//    4. A part round-trips through the progress channel's wire form.
//

import WenshuAgent
import WenshuData
import XCTest
@testable import WenshuApp

final class ImportAgentReplyPartsTests: XCTestCase {

    // MARK: - The task's parts

    func testTheImportTaskCarriesPartsRatherThanLogLines() {
        var task = ImportTask(sourcePath: "/tmp/source.md")
        XCTAssertTrue(task.agentParts.isEmpty)
        task.agentParts.append(.text("the agent's reply"))
        XCTAssertEqual(task.agentParts.count, 1)
    }

    // MARK: - The block conversion

    func testATextBlockBecomesATextPart() {
        let emitter = ImportAgentPartEmitter()
        let parts = emitter.consume(.text("the agent is writing"))
        XCTAssertEqual(parts.count, 1)
        XCTAssertEqual(parts.first?.kind, .text)
        XCTAssertEqual(parts.first?.text, "the agent is writing")
    }

    func testAToolCallBlockBecomesAToolCallPart() {
        let emitter = ImportAgentPartEmitter()
        let parts = emitter.consume(
            .toolUse(id: "call_1", name: "writeBookDoc", input: "{\"relativePath\":\"world/story.md\"}")
        )
        XCTAssertEqual(parts.count, 1)
        XCTAssertEqual(parts.first?.kind, .toolUse)
        XCTAssertEqual(parts.first?.toolName, "writeBookDoc")
        XCTAssertEqual(parts.first?.toolCallID, "call_1")
    }

    func testTheToolCallsArgumentsAreSummarised() {
        let summarised = ImportAgentPartEmitter.summarise(
            tool: "writeBookDoc",
            input: "{\"relativePath\":\"world/story.md\",\"body\":\"a very long document body\"}"
        )
        XCTAssertTrue(summarised.contains("writeBookDoc"))
        XCTAssertTrue(summarised.contains("world/story.md"))
        XCTAssertFalse(
            summarised.contains("a very long document body"),
            "The document body must not travel to the sheet."
        )
    }

    func testTheTextIsCoalescedIntoOnePart() {
        let emitter = ImportAgentPartEmitter()
        _ = emitter.consume(.text("one "))
        let parts = emitter.consume(.text("two"))
        XCTAssertEqual(parts.count, 1)
        XCTAssertEqual(parts.first?.text, "two")
    }

    // MARK: - The wire form

    func testAPartRoundTripsThroughTheWireForm() {
        let original = ImportAgentPart(
            kind: .toolUse,
            toolName: "writeBookDoc",
            toolCallID: "call_1",
            toolArgs: "writeBookDoc: world/story.md"
        )
        let wire = original.encoded()
        XCTAssertTrue(wire.hasPrefix(ImportAgentPart.marker))
        let decoded = ImportAgentPart.decode(wire)
        XCTAssertEqual(decoded, original)
        guard case .toolUse(let tool)? = decoded?.chatPart().kind else {
            XCTFail("The wire form must decode to a tool call part.")
            return
        }
        XCTAssertEqual(tool.name, "writeBookDoc")
        XCTAssertEqual(tool.args, "writeBookDoc: world/story.md")
        XCTAssertEqual(tool.id, ToolCallID(rawValue: "call_1"))
    }

    func testAPlainLineIsNotAPart() {
        XCTAssertNil(ImportAgentPart.decode("wrote the main file: world/story.md"))
    }
}
