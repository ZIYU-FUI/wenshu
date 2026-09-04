// RegisteredPanesTests.swift · Wenshu (文枢) · v0.28 followup TKT-028-016
//
// Tests for registered panes pattern (= new pane = 1 registry.register()
// call instead of editing PaneRenderer switch). Boss 2026-08-29 OOB.

import XCTest
import SwiftUI
@testable import WenshuApp

@MainActor
final class RegisteredPanesTests: XCTestCase {

    func testRegisterBuiltinPanesRegistersSix() {
        let registry = ContributionRegistry()
        registerBuiltinPanes(registry)
        let panes = registry.getArea(ContributionArea.panes)
        XCTAssertEqual(panes.count, 6)
    }

    func testRegisterBuiltinPanesAllTabKinds() {
        let registry = ContributionRegistry()
        registerBuiltinPanes(registry)
        for kind in [TabKind.projectSidebar, .projectPreview, .editor,
                     .specializedTools, .aiChat, .aiDynamic] {
            XCTAssertNotNil(
                contributionForTabKind(kind, in: registry),
                "TabKind \(kind.rawValue) should be registered"
            )
        }
    }

    func testContributionForTabKindReturnsNilForUnregistered() {
        let registry = ContributionRegistry()
        // Don't register any panes.
        XCTAssertNil(contributionForTabKind(.projectSidebar, in: registry))
    }

    func testRegisterBuiltinPanesSortedByOrder() {
        let registry = ContributionRegistry()
        registerBuiltinPanes(registry)
        let panes = registry.getArea(ContributionArea.panes)
        let orders = panes.map { $0.order ?? -1 }
        XCTAssertEqual(orders, [10, 20, 30, 40, 50, 60])
    }

    func testReRegisterReplacesPane() {
        let registry = ContributionRegistry()
        registerBuiltinPanes(registry)
        XCTAssertEqual(registry.getArea(ContributionArea.panes).count, 6)
        // Re-register should NOT duplicate (= re-register same id replaces).
        registerBuiltinPanes(registry)
        XCTAssertEqual(registry.getArea(ContributionArea.panes).count, 6)
    }

    func testNewPaneViaRegistryWithoutRendererEdit() {
        // Simulate adding a new pane type (= not in TabKind enum).
        let registry = ContributionRegistry()
        registerBuiltinPanes(registry)
        // Register a hypothetical plugin pane.
        registry.register(Contribution(
            id: "plugin:custom-pane",
            area: ContributionArea.panes,
            source: "plugin:test",
            title: "Custom Pane",
            order: 100,
            render: { AnyView(EmptyView()) }
        ))
        let panes = registry.getArea(ContributionArea.panes)
        XCTAssertEqual(panes.count, 7)  // 6 builtin + 1 plugin
        let custom = panes.first { $0.id == "plugin:custom-pane" }
        XCTAssertNotNil(custom)
        XCTAssertEqual(custom?.source, "plugin:test")
    }
}