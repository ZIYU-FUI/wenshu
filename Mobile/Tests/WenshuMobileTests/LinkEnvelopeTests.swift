import Foundation
import Testing
@testable import WenshuMobileKit

@Test func envelopeRoundTripsThroughTheWireFormat() throws {
    let envelope = LinkEnvelope(kind: .command, payload: Data([1, 2, 3]))
    let decoded = try LinkEnvelope.decode(envelope.encoded())
    #expect(decoded == envelope)
}

@Test func envelopeCarriesTheCurrentVersion() {
    #expect(LinkEnvelope.currentVersion == 1)
    #expect(LinkEnvelope.accepts(version: LinkEnvelope.currentVersion))
}

@Test func envelopeRefusesAForeignVersion() {
    #expect(!LinkEnvelope.accepts(version: LinkEnvelope.currentVersion + 1))
}

@Test func pairingClaimsShareAVersionWithTheMac() {
    let claims = PairingClaims.initial(deviceName: "iPhone", publicKey: Data([9]))
    #expect(claims.hasCommonVersion(with: [LinkEnvelope.currentVersion]))
    #expect(!claims.hasCommonVersion(with: [LinkEnvelope.currentVersion + 1]))
}
