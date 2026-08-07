import XCTest
@testable import WenshuApp

final class SSEParserTests: XCTestCase {
    func testSingleEvent() {
        let events = SSEParser().append("event: message_start\ndata: {\"type\":\"message_start\"}\n\n")
        XCTAssertEqual(events, [SSEEvent(event: "message_start", data: "{\"type\":\"message_start\"}")])
    }

    func testMultipleEvents() {
        let input = (1...3).map { "event: event\($0)\ndata: {\"n\":\($0)}\n\n" }.joined()
        let events = SSEParser().append(input)
        XCTAssertEqual(events.map(\.event), ["event1", "event2", "event3"])
    }

    func testMultiLineData() {
        let events = SSEParser().append("event: message\ndata: {\"type\":\ndata: \"message_start\"}\n\n")
        XCTAssertEqual(events.first?.data, "{\"type\":\"message_start\"}")
    }

    func testMalformedData() {
        let events = SSEParser().append("event: bad\ndata: not-json\n\nevent: good\ndata: {\"ok\":true}\n\n")
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.event, "good")
    }

    func testByteAccumulation() {
        let parser = SSEParser()
        XCTAssertTrue(parser.append(Data("event: message_start\ndata: {\"type\":".utf8)).isEmpty)
        let events = parser.append(Data("\"message_start\"}\n\n".utf8))
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.event, "message_start")
    }
}
