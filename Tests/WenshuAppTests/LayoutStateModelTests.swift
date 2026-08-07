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

    func testDefault_snapshot_matchesAGENTS_8_1_withLT01FixOverride() {
        let snap = LayoutSnapshot.default
        XCTAssertEqual(snap.ratios.count, 5)
        XCTAssertEqual(snap.ratios[0], 0.2, accuracy: 0.0001, "topLeft = 20% per AGENTS §8.1")
        XCTAssertEqual(snap.ratios[1], 0.6, accuracy: 0.0001, "topCenter = 60% per AGENTS §8.1")
        XCTAssertEqual(snap.ratios[2], 0.2, accuracy: 0.0001, "topRight = 20% per AGENTS §8.1")
        XCTAssertEqual(snap.ratios[3], 0.5, accuracy: 0.0001, "bottom height = 50% per AGENTS §8.1")
        // LT-01-fix override (装机 user 8/7 拍板): bottom split = 70:30
        // (聊天 70% / 状态 30%), not AGENTS §8.1's original 50:50.
        XCTAssertEqual(snap.ratios[4], 0.7, accuracy: 0.0001, "bottom-left split = 70% per 装机 user 8/7 LT-01-fix")
        XCTAssertFalse(snap.collapsed.topLeft)
        XCTAssertFalse(snap.collapsed.topCenter)
        XCTAssertFalse(snap.collapsed.topRight)
        XCTAssertFalse(snap.collapsed.bottomLeft)
        XCTAssertFalse(snap.collapsed.bottomRight)
    }

    // MARK: - LT-01-fix: bottom split override

    /// LT-01-fix 装机 user 8/7 拍板: 默认 bottom-left (聊天) = 70%,
    /// bottom-right (状态) = 30% — 装机 user 实机验后说"聊天占大面积,
    /// 别那么窄". This test pins the contract so a future refactor
    /// can't silently revert to AGENTS §8.1's original 50:50.
    func testDefaultBottomRatio_is70_30() {
        let snap = LayoutSnapshot.default
        XCTAssertEqual(
            snap.ratios[4], 0.7, accuracy: 0.0001,
            "聊天区默认占比必须 70%(LT-01-fix 装机 user 8/7 拍板)"
        )
        // 状态 panel 不折叠 (默认可见),且宽度 = 1.0 - 0.7 = 0.3.
        XCTAssertEqual(
            1.0 - snap.ratios[4], 0.3, accuracy: 0.0001,
            "状态区默认占比必须 30%(LT-01-fix 装机 user 8/7 拍板,保持可见)"
        )
        XCTAssertFalse(
            snap.collapsed.bottomRight,
            "状态 panel 不折叠 — 30% 宽度足够展示 chevron + tag + 视图切换"
        )
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
