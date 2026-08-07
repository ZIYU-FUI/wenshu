// LayoutStateModelTests.swift · 文枢 (Wenshu) · v0.02.0 WO-LT-01
//
// Codable + JSON-encoding contract for `LayoutSnapshot` and its inner
// `PanelCollapsedState`. Pure value-type tests — no CoreData, no UI.
// These are intentionally first because they're the cheapest signal
// that the storage format is stable before we wire anything else on top.

import XCTest
@testable import WenshuApp

final class LayoutStateModelTests: XCTestCase {

    // MARK: - Defaults

    func testDefault_snapshot_matchesAGENTS_8_1() {
        let snap = LayoutSnapshot.default
        XCTAssertEqual(snap.ratios.count, 5)
        XCTAssertEqual(snap.ratios[0], 0.2, accuracy: 0.0001, "topLeft = 20% per AGENTS §8.1")
        XCTAssertEqual(snap.ratios[1], 0.6, accuracy: 0.0001, "topCenter = 60% per AGENTS §8.1")
        XCTAssertEqual(snap.ratios[2], 0.2, accuracy: 0.0001, "topRight = 20% per AGENTS §8.1")
        XCTAssertEqual(snap.ratios[3], 0.5, accuracy: 0.0001, "bottom height = 50% per AGENTS §8.1")
        XCTAssertEqual(snap.ratios[4], 0.5, accuracy: 0.0001, "bottom-left split = 50% per AGENTS §8.1")
        XCTAssertFalse(snap.collapsed.topLeft)
        XCTAssertFalse(snap.collapsed.topCenter)
        XCTAssertFalse(snap.collapsed.topRight)
        XCTAssertFalse(snap.collapsed.bottomLeft)
        XCTAssertFalse(snap.collapsed.bottomRight)
    }

    // MARK: - Codable / JSON round-trip

    func testEncodeDecodeCollapsed_roundTrip() {
        let original = PanelCollapsedState(
            topLeft: true, topCenter: false, topRight: true,
            bottomLeft: false, bottomRight: true
        )
        let json = LayoutSnapshot.encodeCollapsed(original)
        XCTAssertFalse(json.isEmpty)
        let decoded = LayoutSnapshot.decodeCollapsed(json)
        XCTAssertEqual(decoded, original)
    }

    func testEncodeDecodeRatios_roundTrip() {
        let original: [Double] = [0.18, 0.64, 0.18, 0.42, 0.58]
        let json = LayoutSnapshot.encodeRatios(original)
        XCTAssertFalse(json.isEmpty)
        let decoded = LayoutSnapshot.decodeRatios(json)
        XCTAssertEqual(decoded, original)
    }

    func testDecodeCollapsed_emptyString_returnsDefaults() {
        // First launch path (or a pre-LT-01 .ws file with empty column).
        let decoded = LayoutSnapshot.decodeCollapsed("")
        XCTAssertEqual(decoded, PanelCollapsedState())
    }

    func testDecodeCollapsed_malformedJSON_returnsDefaults() {
        let decoded = LayoutSnapshot.decodeCollapsed("not json at all")
        XCTAssertEqual(decoded, PanelCollapsedState())
    }

    func testDecodeRatios_emptyString_returnsCanonicalDefaults() {
        let decoded = LayoutSnapshot.decodeRatios("")
        XCTAssertEqual(decoded, LayoutSnapshot.default.ratios)
    }

    func testDecodeRatios_wrongLength_returnsCanonicalDefaults() {
        // Schema version drift protection: a future version writing 6 ratios
        // shouldn't crash a v0.02.0 reader.
        let tooShort = LayoutSnapshot.decodeRatios("[0.2,0.6,0.2]")
        let tooLong = LayoutSnapshot.decodeRatios("[0.2,0.6,0.2,0.5,0.5,0.5]")
        XCTAssertEqual(tooShort, LayoutSnapshot.default.ratios)
        XCTAssertEqual(tooLong, LayoutSnapshot.default.ratios)
    }

    func testDecodeRatios_malformedJSON_returnsCanonicalDefaults() {
        let decoded = LayoutSnapshot.decodeRatios("garbage")
        XCTAssertEqual(decoded, LayoutSnapshot.default.ratios)
    }

    // MARK: - Constants

    func testConstants_matchAGENTS_8_1_thresholds() {
        XCTAssertEqual(LayoutSnapshot.autoCollapsePixels, 30)
        XCTAssertEqual(LayoutSnapshot.topCollapsedPixels, 50)
        XCTAssertEqual(LayoutSnapshot.bottomCollapsedPixels, 30)
    }
}
