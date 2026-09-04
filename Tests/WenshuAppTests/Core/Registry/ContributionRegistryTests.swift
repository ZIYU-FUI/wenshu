// ContributionRegistryTests.swift · Wenshu (文枢) · v0.28 followup TKT-028-013
//
// Tests for the contribution registry pattern (= hermes pane-shell
// verbatim port). Boss 2026-08-29 OOB '完整复刻 hermes app'.

import XCTest
import SwiftUI
@testable import WenshuApp

@MainActor
final class ContributionRegistryTests: XCTestCase {

    // MARK: - Registration

    func testRegisterAndGet() {
        let reg = ContributionRegistry()
        reg.register(Contribution(
            id: "files-pane",
            area: ContributionArea.panes,
            title: "Files",
            order: 100
        ))
        let list = reg.getArea(ContributionArea.panes)
        XCTAssertEqual(list.count, 1)
        XCTAssertEqual(list[0].id, "files-pane")
        XCTAssertEqual(list[0].title, "Files")
    }

    func testRegisterManyReturnsBatchDisposer() {
        let reg = ContributionRegistry()
        let dispose = reg.registerMany([
            Contribution(id: "p1", area: ContributionArea.panes),
            Contribution(id: "p2", area: ContributionArea.panes),
            Contribution(id: "p3", area: ContributionArea.panes),
        ])
        XCTAssertEqual(reg.getArea(ContributionArea.panes).count, 3)
        dispose()
        XCTAssertEqual(reg.getArea(ContributionArea.panes).count, 0)
    }

    func testReRegisterSameIdReplaces() {
        let reg = ContributionRegistry()
        reg.register(Contribution(id: "x", area: ContributionArea.panes, title: "v1"))
        reg.register(Contribution(id: "x", area: ContributionArea.panes, title: "v2"))
        let list = reg.getArea(ContributionArea.panes)
        XCTAssertEqual(list.count, 1)
        XCTAssertEqual(list[0].title, "v2")
    }

    func testRemoveById() {
        let reg = ContributionRegistry()
        reg.register(Contribution(id: "x", area: ContributionArea.panes))
        reg.remove(area: ContributionArea.panes, id: "x")
        XCTAssertEqual(reg.getArea(ContributionArea.panes).count, 0)
    }

    func testRemoveMissingIdIsNoop() {
        let reg = ContributionRegistry()
        reg.register(Contribution(id: "x", area: ContributionArea.panes))
        reg.remove(area: ContributionArea.panes, id: "nope")
        XCTAssertEqual(reg.getArea(ContributionArea.panes).count, 1)
    }

    // MARK: - Area scoping (= the core invariant)

    func testAreaScopedInvalidation() {
        let reg = ContributionRegistry()
        reg.register(Contribution(id: "p1", area: ContributionArea.panes))
        reg.register(Contribution(id: "s1", area: ContributionArea.statusbarLeft))
        // Snapshot caches (= first access).
        _ = reg.getArea(ContributionArea.panes)
        _ = reg.getArea(ContributionArea.statusbarLeft)
        // Mutate panes.
        reg.register(Contribution(id: "p2", area: ContributionArea.panes))
        // Panes snapshot invalidated (= p2 added).
        XCTAssertEqual(reg.getArea(ContributionArea.panes).count, 2)
        // Statusbar snapshot untouched (= still 1 item, not re-fetched
        // from source). This proves area-scoped invalidation.
        XCTAssertEqual(reg.getArea(ContributionArea.statusbarLeft).count, 1)
    }

    // MARK: - Sorting (= order ascending, nil last, insertion order on ties)

    func testSortByOrderAscending() {
        let reg = ContributionRegistry()
        reg.register(Contribution(id: "b", area: ContributionArea.panes, order: 200))
        reg.register(Contribution(id: "a", area: ContributionArea.panes, order: 100))
        reg.register(Contribution(id: "c", area: ContributionArea.panes, order: 300))
        let ids = reg.getArea(ContributionArea.panes).map(\.id)
        XCTAssertEqual(ids, ["a", "b", "c"])
    }

    func testNilOrderSortsLast() {
        let reg = ContributionRegistry()
        reg.register(Contribution(id: "ordered", area: ContributionArea.panes, order: 1))
        reg.register(Contribution(id: "nil-order", area: ContributionArea.panes, order: nil))
        let ids = reg.getArea(ContributionArea.panes).map(\.id)
        XCTAssertEqual(ids, ["ordered", "nil-order"])
    }

    func testTiesKeepInsertionOrder() {
        let reg = ContributionRegistry()
        reg.register(Contribution(id: "first", area: ContributionArea.panes, order: 100))
        reg.register(Contribution(id: "second", area: ContributionArea.panes, order: 100))
        reg.register(Contribution(id: "third", area: ContributionArea.panes, order: 100))
        let ids = reg.getArea(ContributionArea.panes).map(\.id)
        XCTAssertEqual(ids, ["first", "second", "third"])
    }

    // MARK: - Listeners

    func testAreaListenerFires() {
        let reg = ContributionRegistry()
        var count = 0
        let id = reg.subscribe(area: ContributionArea.panes) {
            count += 1
        }
        reg.register(Contribution(id: "x", area: ContributionArea.panes))
        XCTAssertEqual(count, 1)
        reg.register(Contribution(id: "y", area: ContributionArea.panes))
        XCTAssertEqual(count, 2)
        reg.unsubscribe(area: ContributionArea.panes, id: id)
        reg.register(Contribution(id: "z", area: ContributionArea.panes))
        XCTAssertEqual(count, 2)  // unsubscribed
    }

    func testGlobalListenerFires() {
        let reg = ContributionRegistry()
        var count = 0
        let id = reg.subscribeAll {
            count += 1
        }
        reg.register(Contribution(id: "x", area: ContributionArea.panes))
        reg.register(Contribution(id: "y", area: ContributionArea.statusbarLeft))
        XCTAssertEqual(count, 2)
        reg.unsubscribeAll(id: id)
        reg.register(Contribution(id: "z", area: ContributionArea.panes))
        XCTAssertEqual(count, 2)  // unsubscribed
    }

    // MARK: - Versioning (= for non-SwiftUI reactive consumers)

    func testVersionBumpsOnMutation() {
        let reg = ContributionRegistry()
        let v0 = reg.version
        reg.register(Contribution(id: "x", area: ContributionArea.panes))
        XCTAssertEqual(reg.version, v0 + 1)
        reg.remove(area: ContributionArea.panes, id: "x")
        XCTAssertEqual(reg.version, v0 + 2)
    }
}