import Foundation
import Testing
@testable import WenshuMobileKit

@Test func commandTravelsInACommandEnvelope() throws {
    let command = LinkCommand(kind: .writeChapter, identifier: "chapter-1", baseRevision: 7, body: "text")
    let envelope = command.envelope()
    #expect(envelope.kind == .command)

    let decoded = try LinkEnvelope.decode(envelope.encoded())
    let back = try JSONDecoder.link.decode(LinkCommand.self, from: decoded.payload)
    #expect(back == command)
}

@Test func commandKeepsTheRevisionItWasBasedOn() {
    let command = LinkCommand(kind: .writeChapter, identifier: "chapter-1", baseRevision: 3)
    #expect(command.baseRevision == 3)
}
