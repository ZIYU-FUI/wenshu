// LayoutStateModelTests.swift · 文枢 (Wenshu) · v0.02.0 WO-LT-01-fix2
//
// Codable + JSON-encoding contract for `LayoutSnapshot` and its inner
// `PanelCollapsedState`. Pure value-type tests — no CoreData, no UI.
// These are intentionally first because they're the cheapest signal
// that the storage format is stable before we wire anything else on top.
//
// LT-01-fix2 changes:
// - Default-ratios assertions updated to match the new 80:20 lower split
//   (聊天 80% / 状态 20%, per 装机 user 8/7 拍板 "状态 = 检视 = 20%").
// - New `testDefaultTopRightRatio_equalsBottomRight` pins the
//   检视=状态=20% hard contract.
// - Renamed `testDefault_snapshot_...` to mark LT-01-fix2 in the title.

import XCTest
@testable import WenshuApp

final class LayoutStateModelTests: XCTestCase {

    // MARK: - Defaults

    func testDefault_snapshot_matchesAGENTS_8_1_withLT01Fix2Override() {
        let snap = LayoutSnapshot.default
        XCTAssertEqual(snap.ratios.count, 5)
        XCTAssertEqual(snap.ratios[0], 0.2, accuracy: 0.0001, "topLeft = 20% per AGENTS §8.1")
        XCTAssertEqual(snap.ratios[1], 0.6, accuracy: 0.0001, "topCenter = 60% per AGENTS §8.1")
        XCTAssertEqual(snap.ratios[2], 0.2, accuracy: 0.0001, "topRight = 20% per AGENTS §8.1")
        XCTAssertEqual(snap.ratios[3], 0.5, accuracy: 0.0001, "bottom height = 50% per AGENTS §8.1")
        // LT-01-fix2 override (装机 user 8/7 拍板): bottom split = 80:20
        // (聊天 80% / 状态 20%), changed from the previous 70:30 LT-01-fix.
        // 装机 user 实机验 "状态与检视同宽 = 20%".
        XCTAssertEqual(
            snap.ratios[4], 0.8, accuracy: 0.0001,
            "bottom-left split = 80% per 装机 user 8/7 LT-01-fix2"
        )
        XCTAssertFalse(snap.collapsed.topLeft)
        XCTAssertFalse(snap.collapsed.topCenter)
        XCTAssertFalse(snap.collapsed.topRight)
        XCTAssertFalse(snap.collapsed.bottomLeft)
        XCTAssertFalse(snap.collapsed.bottomRight)
    }

    // MARK: - LT-01-fix: bottom split override (历史拍板,已 superseded)

    /// LT-01-fix 装机 user 8/7 拍板: 默认 bottom-left (聊天) = 70%,
    /// bottom-right (状态) = 30% — 装机 user 实机验后说"聊天占大面积,
    /// 别那么窄".
    ///
    /// LT-01-fix2 装机 user 8/7 又拍板: "状态 = 检视 = 20%" — 因此状态
    /// 从 30% 进一步缩到 20% (聊天 = 80%). LT-01-fix 的 70:30 已被替代,
    /// 此测试保留作为 change-trail anchor(显式注释
    /// "superseded by LT-01-fix2",方便 git log 追溯)。
    func testDefaultBottomRatio_is70_30_historySnapshot() {
        // This test documents the LT-01-fix state BEFORE fix2; it does
        // NOT assert the current default. See testDefaultTopRightRatio_
        // equalsBottomRight for the current contract.
        let previousLT01FixRatios: [Double] = [0.2, 0.6, 0.2, 0.5, 0.7]
        XCTAssertEqual(
            previousLT01FixRatios[4], 0.7, accuracy: 0.0001,
            "历史 LT-01-fix ratios[4] = 0.7 (聊天 70% / 状态 30%);" +
            " LT-01-fix2 已 superseded 此拍板"
        )
    }

    // MARK: - LT-01-fix2: 状态 = 检视 = 20%

    /// LT-01-fix2 装机 user 8/7 拍板: 默认 inspector (右上) 宽度 = 状态
    /// (右下) 宽度 = 20%. This pins the contract: the two narrow right-hand
    /// panels match in width, so 状态 panel no longer feels "too wide" (the
    /// pre-fix 30% was a 装机 user 实机验 complaint).
    ///
    /// Implementation note: `ratios[2]` = 检视占上半宽 = 20%;
    /// `1.0 - ratios[4]` = 状态占下半宽 = 20% → ratios[4] = 0.8.
    func testDefaultTopRightRatio_equalsBottomRight() {
        let snap = LayoutSnapshot.default
        // 检视占上半宽 20% (per AGENTS §8.1)
        XCTAssertEqual(snap.ratios[2], 0.2, accuracy: 0.0001, "检视 = 20%")
        // 状态占下半宽 = 1.0 - 聊天占下半宽 = 0.2 → 聊天 80%
        XCTAssertEqual(
            1.0 - snap.ratios[4], 0.2, accuracy: 0.0001,
            "状态(右下)占下半宽度必须 = 20%(LT-01-fix2 装机 user 8/7 拍板)"
        )
        // 显式断言:聊天占下半宽 = 80%(从状态 20% 推出)
        XCTAssertEqual(snap.ratios[4], 0.8, accuracy: 0.0001, "聊天(下左)占下半宽度 = 80%")
        // 状态 panel 不折叠 — 20% 宽度足够展示 chevron + tag + 视图切换
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
        let original: [Double] = [0.18, 0.64, 0.18, 0.42, 0.82]
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

// MARK: - LT-01-fix2: Splitter click does not commit drag

/// Verifies the second-layer defense for the "horizontal splitter 误触
/// collapse" 装机 user 8/7 实机验 BUG. The primary fix lives at the SwiftUI
/// layer (`PanelSplitter.swift`) — `DragGesture(minimumDistance: 5)` so
/// that a click (translation < 5px) never arms `onChanged`. This test
/// pins the model-layer contract: even if a future regression bypassed
/// `PanelSplitter`'s click-policy and forwarded `delta = 0` to the
/// View Model, the model must treat it as a no-op (no ratio change,
/// no collapse). This is the 装机 user 拍板
/// "点 5 次 splitter 不动" invariant.
final class PanelSplitterClickPolicyTests: XCTestCase {

    /// 模拟 splitter mouseDown + mouseUp (translation = 0) → View Model
    /// 调用 adjustLowerColumn(delta: 0, ...) → ratios[4] 必须保持不变
    /// (即不变更状态 panel 宽度)。
    ///
    /// 这是 click 不触发 collapse 的第二层保证 — 即便 SwiftUI 误把 click
    /// 当成 drag,VM 的 clamp 也保证 ratios[4] = max(0.05, min(0.95, x + 0))
    /// = x,no-op。
    @MainActor
    func testSplitterClickDoesNotCollapse() {
        // 直接构造一个 View Model 验证 drag math 的 no-op 性质。
        // LayoutShellViewModel 是 @MainActor;@testable import 已暴露
        // 内部 init(store: WenshuStoreActor = .shared)。
        let vm = LayoutShellViewModel()
        let before = vm.snapshot.ratios

        // 模拟 5 次 click (装机 user 实机验"点 5 次 splitter 不动")
        for _ in 0..<5 {
            vm.adjustLowerColumn(delta: 0, totalWidth: 1200)
        }

        XCTAssertEqual(
            vm.snapshot.ratios, before,
            "5 次 click (delta = 0) 后 ratios 必须保持不变 —" +
            " 状态 panel 宽度保持 20%,不折叠"
        )
        XCTAssertFalse(
            vm.snapshot.collapsed.bottomRight,
            "5 次 click 后状态 panel 仍不折叠(LT-01-fix2 装机 user 实机验硬约束)"
        )
    }
}
