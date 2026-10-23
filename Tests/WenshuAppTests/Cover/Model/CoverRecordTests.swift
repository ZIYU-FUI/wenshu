//
//  CoverRecordTests.swift · Wenshu
//
//  Proves that the STILL's state and the CLIP's state are separate,
//  and that a record written before the split is read as what it
//  meant.
//
//  The split exists because of one measured defect: a clip that
//  failed marked a card whose PICTURE was perfect as broken, because
//  one status and one error carried both.
//

import Foundation
import Testing
import WenshuData
@testable import WenshuApp

@Suite("Cover record states")
struct CoverRecordTests {

    /// Decodes a raw record the way the store does.
    private func decode(_ json: String) throws -> CoverRecord {
        try JSONDecoder().decode(CoverRecord.self, from: Data(json.utf8))
    }

    /// Encodes a record the way the store does.
    private func encode(_ record: CoverRecord) throws -> String {
        let data = try JSONEncoder().encode(record)
        return String(data: data, encoding: .utf8) ?? ""
    }

    @Test("A record written before the split with a clip reads as both ready")
    func anOldRecordWithAClipReadsAsBothReady() throws {
        // The old shape had ONE state, and "dynamicReady" meant "the
        // picture AND the clip exist".
        let record = try decode("""
            {"cardKind":"reference","status":"dynamicReady","updatedAt":0}
            """)

        #expect(record.status == WSCardCoverStatus.staticReady)
        #expect(record.clipStatus == WSCardCoverStatus.clipReady)
    }

    @Test("A record written before the split with a failed clip reads as the clip failing")
    func anOldRecordWithAFailedClipReadsAsTheClipFailing() throws {
        // "videoFailed" meant "the clip gave up and the picture was
        // fine", and the one error it carried was the CLIP's.
        let record = try decode("""
            {"cardKind":"reference","status":"videoFailed","lastError":"no quota left","updatedAt":0}
            """)

        #expect(record.status == WSCardCoverStatus.staticReady)
        #expect(record.clipStatus == WSCardCoverStatus.clipFailed)
        #expect(record.clipError == "no quota left")
        // The still did not fail, so it carries no error.
        #expect(record.lastError == nil)
    }

    @Test("A record written before the split with a still failure keeps its error")
    func anOldRecordWithAStillFailureKeepsItsError() throws {
        let record = try decode("""
            {"cardKind":"reference","status":"failed","lastError":"no image service","updatedAt":0}
            """)

        #expect(record.status == WSCardCoverStatus.failed)
        #expect(record.clipStatus == WSCardCoverStatus.clipNone)
        #expect(record.lastError == "no image service")
        #expect(record.clipError == nil)
    }

    @Test("A new record round-trips both states")
    func aNewRecordRoundTripsBothStates() throws {
        let record = CoverRecord(
            cardKind: "reference",
            status: WSCardCoverStatus.staticReady,
            clipStatus: WSCardCoverStatus.clipFailed,
            lastError: nil,
            clipError: "no quota left"
        )

        let read = try decode(try encode(record))

        #expect(read.status == WSCardCoverStatus.staticReady)
        #expect(read.clipStatus == WSCardCoverStatus.clipFailed)
        #expect(read.clipError == "no quota left")
    }

    @Test("A record with no clip state reads as no clip")
    func aRecordWithNoClipStateReadsAsNoClip() throws {
        let record = try decode("""
            {"cardKind":"reference","status":"staticReady","updatedAt":0}
            """)

        #expect(record.status == WSCardCoverStatus.staticReady)
        #expect(record.clipStatus == WSCardCoverStatus.clipNone)
    }
}
