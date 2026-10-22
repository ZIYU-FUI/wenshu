//
//  CoverAutoCoverPolicyTests.swift · Wenshu
//
//  Proves the STOCK-versus-INCREMENTAL split.
//
//  The test that matters is the second one: a document that existed
//  BEFORE the switch was turned on gets NO automatic cover, because
//  it belongs to the batch. That distinction is the user's rule, and
//  it is invisible in the UI: without it, turning the switch on would
//  quietly spend the image allowance on the whole library.
//
//  The decision is a pure function, so "now" is passed in and there
//  is no clock behind any of this.
//

import Foundation
import Testing
import WenshuData
@testable import WenshuApp

@Suite("Cover auto-cover policy")
struct CoverAutoCoverPolicyTests {

    /// A fixed "now" for the tests.
    private static let now = Date(timeIntervalSince1970: 1_700_000_000)

    @Test("The switch off means nothing is automatic")
    func theSwitchOffMeansNothingIsAutomatic() {
        let policy = CoverAutoCoverPolicy.disabled

        #expect(policy.shouldGenerateCover(
            createdAt: Self.now,
            hasCover: false,
            kind: WSCardCoverKind.reference,
            now: Self.now
        ) == false)
    }

    @Test("A document created BEFORE the switch was turned on gets NO cover")
    func aDocumentFromBeforeTheSwitchGetsNoCover() {
        // The switch was turned on at "now". A document created an
        // hour earlier is "stock": it belongs to the batch.
        let policy = CoverAutoCoverPolicy.enabling(at: Self.now)
        let anHourBefore = Self.now.addingTimeInterval(-3600)

        #expect(policy.shouldGenerateCover(
            createdAt: anHourBefore,
            hasCover: false,
            kind: WSCardCoverKind.reference,
            now: Self.now
        ) == false)
    }

    @Test("A document created AFTER the switch was turned on DOES get a cover")
    func aDocumentFromAfterTheSwitchGetsACover() {
        let policy = CoverAutoCoverPolicy.enabling(at: Self.now)
        let aMomentLater = Self.now.addingTimeInterval(1)

        #expect(policy.shouldGenerateCover(
            createdAt: aMomentLater,
            hasCover: false,
            kind: WSCardCoverKind.reference,
            now: Self.now
        ))
        // The book-doc kind is automatic too.
        #expect(policy.shouldGenerateCover(
            createdAt: aMomentLater,
            hasCover: false,
            kind: WSCardCoverKind.bookDoc,
            now: Self.now
        ))
    }

    @Test("A document that already has a cover never gets another one")
    func aDocumentWithACoverNeverGetsAnother() {
        let policy = CoverAutoCoverPolicy.enabling(at: Self.now)

        #expect(policy.shouldGenerateCover(
            createdAt: Self.now.addingTimeInterval(1),
            hasCover: true,
            kind: WSCardCoverKind.reference,
            now: Self.now
        ) == false)
    }

    @Test("A kind the user did not opt in never gets an automatic cover")
    func anUnlistedKindNeverGetsACover() {
        let policy = CoverAutoCoverPolicy.enabling(at: Self.now)

        #expect(policy.shouldGenerateCover(
            createdAt: Self.now.addingTimeInterval(1),
            hasCover: false,
            kind: "someOtherKind",
            now: Self.now
        ) == false)
    }

    @Test("The switch and its timestamp travel together")
    func theSwitchAndItsTimestampTravelTogether() {
        let policy = CoverAutoCoverPolicy.enabling(at: Self.now)

        #expect(policy.isEnabled)
        #expect(policy.enabledAt == Self.now)
        #expect(CoverAutoCoverPolicy.disabled.enabledAt == nil)
    }
}
