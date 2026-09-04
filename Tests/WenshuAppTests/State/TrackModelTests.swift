// TrackModelTests.swift · Wenshu (文枢) · v0.28 followup TKT-028-033

import XCTest
import SwiftUI
@testable import WenshuApp

final class TrackModelConstantsTests: XCTestCase {
    func testMinPanePX() {
        XCTAssertEqual(kMinPanePX, 80)
    }

    func testCollapsedZonePX() {
        XCTAssertEqual(kCollapsedZonePX, 28)
    }

    func testMinimizedTrack() {
        XCTAssertEqual(kMinimizedTrack, 28)
    }
}

final class TrackKindTests: XCTestCase {
    func testCodable() throws {
        let k = TrackKind.fixed
        let data = try JSONEncoder().encode(k)
        let decoded = try JSONDecoder().decode(TrackKind.self, from: data)
        XCTAssertEqual(decoded, .fixed)
    }

    func testAllCases() {
        XCTAssertEqual(TrackKind.fixed.rawValue, "fixed")
        XCTAssertEqual(TrackKind.flex.rawValue, "flex")
        XCTAssertEqual(TrackKind.uncapped.rawValue, "uncapped")
    }
}

final class PaneSizeContributionTests: XCTestCase {
    func testEmpty() {
        let c = PaneSizeContribution()
        XCTAssertTrue(c.isEmpty)
    }

    func testNotEmpty() {
        let c = PaneSizeContribution(width: 200, minWidth: 100)
        XCTAssertFalse(c.isEmpty)
        XCTAssertEqual(c.width, 200)
        XCTAssertEqual(c.minWidth, 100)
    }

    func testCodable() throws {
        let c = PaneSizeContribution(width: 200, height: 300, minWidth: 100, maxWidth: 500)
        let data = try JSONEncoder().encode(c)
        let decoded = try JSONDecoder().decode(PaneSizeContribution.self, from: data)
        XCTAssertEqual(decoded, c)
    }
}

final class CssMaxPxTests: XCTestCase {
    func testEmpty() {
        XCTAssertNil(cssMaxPx([]))
        XCTAssertNil(cssMaxPx([nil, nil]))
    }

    func testSingleValue() {
        XCTAssertEqual(cssMaxPx([100]), 100)
    }

    func testMultipleValues() {
        XCTAssertEqual(cssMaxPx([100, 200, 150]), 200)
    }

    func testDedupe() {
        // (= Hermes dedupes before max, so duplicates don't affect result)
        XCTAssertEqual(cssMaxPx([100, 100, 200]), 200)
    }

    func testMixedNils() {
        XCTAssertEqual(cssMaxPx([nil, 100, nil, 200]), 200)
    }
}

final class ResolveTrackKindTests: XCTestCase {
    func testEmptyIsFlex() {
        let kind = resolveTrackKind(panes: [], axis: .row)
        XCTAssertEqual(kind, .flex)
    }

    func testAllNilIsFlex() {
        let kind = resolveTrackKind(panes: [PaneSizeContribution()], axis: .row)
        XCTAssertEqual(kind, .flex)
    }

    func testDeclaredIsFixed() {
        let kind = resolveTrackKind(panes: [PaneSizeContribution(width: 200)], axis: .row)
        XCTAssertEqual(kind, .fixed)
    }

    func testMainPaneIsFlexEvenWhenMixed() {
        // Per Hermes: a MAIN-bearing zone is flex-at-heart when the
        // declaration set is incomplete (= some panes declare, others don't).
        let kind = resolveTrackKind(
            panes: [
                PaneSizeContribution(width: 200),       // declared
                PaneSizeContribution(width: nil),       // not declared
            ],
            axis: .row,
            hasMainPane: true
        )
        XCTAssertEqual(kind, .flex)
    }

    func testAxisRowVsColumn() {
        // Width declaration only fixes row axis (= horizontal split).
        let rowKind = resolveTrackKind(panes: [PaneSizeContribution(width: 200)], axis: SplitAxis.row)
        XCTAssertEqual(rowKind, .fixed)
        let colKind = resolveTrackKind(panes: [PaneSizeContribution(width: 200)], axis: SplitAxis.column)
        XCTAssertEqual(colKind, .flex)
    }
}

final class AllFixedAbsorberIndexTests: XCTestCase {
    func testEmptyGrowable() {
        let result = allFixedAbsorberIndex(growable: [], maxAlongAxis: { _ in nil })
        XCTAssertEqual(result, -1)
    }

    func testLastUncappedWins() {
        // Growable indices [0, 1, 2]; maxAlongAxis returns nil for 1 and 2.
        let result = allFixedAbsorberIndex(growable: [0, 1, 2]) { i in
            i == 0 ? 500 : nil
        }
        // Last uncapped (= reverse iteration) = 2.
        XCTAssertEqual(result, 2)
    }

    func testAllCappedReturnsMinusOne() {
        let result = allFixedAbsorberIndex(growable: [0, 1, 2]) { _ in 500 }
        XCTAssertEqual(result, -1)
    }

    func testFirstUncappedAfterCapped() {
        // [capped, uncapped, capped] → the uncapped (1) wins (= last uncapped).
        let result = allFixedAbsorberIndex(growable: [0, 1, 2]) { i in
            i == 1 ? nil : 500
        }
        XCTAssertEqual(result, 1)
    }
}

final class PaneFrameModeTests: XCTestCase {
    func testFlexDefault() {
        let f = PaneFrameMode(mode: .flex, flex: 1.0)
        XCTAssertEqual(f.mode, .flex)
        XCTAssertEqual(f.flex, 1.0)
        XCTAssertNil(f.size)
        XCTAssertNil(f.minWidth)
        XCTAssertNil(f.maxWidth)
    }

    func testFixedWithSize() {
        let f = PaneFrameMode(mode: .fixed, size: 300, minWidth: 200)
        XCTAssertEqual(f.mode, .fixed)
        XCTAssertEqual(f.size, 300)
        XCTAssertEqual(f.minWidth, 200)
    }

    func testUncapped() {
        let f = PaneFrameMode(mode: .uncapped)
        XCTAssertEqual(f.mode, .uncapped)
        XCTAssertNil(f.maxWidth)
    }

    func testCodable() throws {
        let f = PaneFrameMode(mode: .fixed, size: 300, minWidth: 200, flex: 0.5, maxWidth: 500)
        let data = try JSONEncoder().encode(f)
        let decoded = try JSONDecoder().decode(PaneFrameMode.self, from: data)
        XCTAssertEqual(decoded, f)
    }
}