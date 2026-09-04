// Phase1to5IntegrationTests.swift · Wenshu (文枢) · v0.28 followup TKT-028-018
//
// Integration tests for the full Phase 1-5 stack (= contribution
// registry + visibility + chrome + panes + sash + applyTree deep-clone).
// Boss 2026-08-29 OOB '完整复刻 hermes app, 用户体验第一'.

import XCTest
@testable import WenshuApp

@MainActor
final class Phase1to5IntegrationTests: XCTestCase {

    func testFullStackConstruction() {
        // 1. Build all pieces together.
        let registry = ContributionRegistry()
        registerBuiltinPanes(registry)
        let visibilityStore = PaneVisibilityStore()
        let scopeStore = WorkspaceScopeStore()
        let lifecycle = emptyPaneLifecycleState()
        _ = lifecycle  // unused here

        // 2. Verify all builtin panes are registered.
        let panes = registry.getArea(ContributionArea.panes)
        XCTAssertEqual(panes.count, 6)

        // 3. Verify pane visibility store starts empty.
        XCTAssertTrue(visibilityStore.hiddenTreePanes.isEmpty)
        XCTAssertTrue(visibilityStore.dismissedPanes.isEmpty)
        XCTAssertTrue(visibilityStore.collapsePanes.isEmpty)

        // 4. Verify workspace scope starts in default mode.
        XCTAssertEqual(scopeStore.mode, .sessions)
        XCTAssertNil(scopeStore.ownerKey)
    }

    func testPaneVisibilityFlow() {
        // Simulate user toggling a pane (= ⌘B for sidebar).
        let registry = ContributionRegistry()
        registerBuiltinPanes(registry)
        let visibilityStore = PaneVisibilityStore()

        // Register opener + closer (= simulates the chrome binding).
        var closeCalled = false
        var openCalled = false
        visibilityStore.bindPaneVisibility(
            paneId: TabKind.projectSidebar.rawValue,
            isOpen: true,
            close: { closeCalled = true },
            open: { openCalled = true }
        )

        // Toggle to hidden (= user pressed ⌘B).
        visibilityStore.togglePaneVisible(paneId: TabKind.projectSidebar.rawValue)
        XCTAssertTrue(visibilityStore.hiddenTreePanes.contains(TabKind.projectSidebar.rawValue))

        // Toggle back (= user pressed ⌘B again).
        visibilityStore.togglePaneVisible(paneId: TabKind.projectSidebar.rawValue)
        XCTAssertFalse(visibilityStore.hiddenTreePanes.contains(TabKind.projectSidebar.rawValue))
    }

    func testApplyTreeViaRegistryFlow() {
        // 1. Build a custom layout (= not a builtin preset).
        let customLayout = makeSplit(
            orientation: .row,
            children: [
                makeGroup(panes: [PaneID()]),
                makeGroup(panes: [PaneID()])
            ],
            weights: [2.0, 3.0]
        )

        // 2. Apply it via WorkspaceStore.loadPreset (= equivalent
        // to the legacy applyTree deep-clone path removed in v0.30).
        // Reuse the built-in default's panes + tabs so the
        // resulting workspace is internally consistent.
        let store = WorkspaceStore(userDefaults: UserDefaults(suiteName: "test-\(UUID())")!)
        let builtinDefault = store.presets.first { $0.isBuiltIn && $0.name == "默认" }!
        let presetID = UUID()
        let preset = LayoutPreset(
            id: presetID,
            name: "test-applyTree",
            workspace: WorkspaceState(
                root: customLayout,
                panes: builtinDefault.workspace.panes,
                tabs: builtinDefault.workspace.tabs,
                version: 2
            ),
            isBuiltIn: false
        )
        store.loadPreset(preset)

        // 3. Verify the tree structure is applied.
        if case .split(let s) = store.workspace.root {
            XCTAssertEqual(s.weights, [2.0, 3.0])
            XCTAssertEqual(s.children.count, 2)
            XCTAssertEqual(s.orientation, .row)
        } else {
            XCTFail("Expected split root")
        }
    }

    func testPaneSizePersistence() {
        let visibilityStore = PaneVisibilityStore()
        let groupId = "test-group-1"

        // Simulate sash drag (= user dragged split right by 50 PT).
        visibilityStore.setPaneWidthOverride(paneId: groupId, width: 250)
        visibilityStore.setPaneHeightOverride(paneId: groupId, height: 180)

        XCTAssertEqual(visibilityStore.paneSizeSnapshot(groupId)?.widthOverride, 250)
        XCTAssertEqual(visibilityStore.paneSizeSnapshot(groupId)?.heightOverride, 180)

        // Persistence round-trip.
        let data = try! visibilityStore.encoded()
        let restored = PaneVisibilityStore()
        restored.restore(from: data)
        XCTAssertEqual(restored.paneSizeSnapshot(groupId)?.widthOverride, 250)
        XCTAssertEqual(restored.paneSizeSnapshot(groupId)?.heightOverride, 180)
    }

    func testStatusbarItemHideShow() {
        let visibilityStore = PaneVisibilityStore()

        // Hide model pill.
        visibilityStore.setStatusbarItemVisible(itemId: "model", visible: false)
        XCTAssertTrue(visibilityStore.statusbarHiddenIds.contains("model"))

        // Reset (= show all).
        visibilityStore.resetStatusbarLayout()
        XCTAssertFalse(visibilityStore.statusbarHiddenIds.contains("model"))
    }

    func testPaneLifecycleReconcileAcrossPhases() {
        // Simulate a zone with 5 panes (= foreground + 4 inactive).
        let previous = emptyPaneLifecycleState()
        let next = reconcilePaneLifecycle(
            previous: previous,
            options: ReconcilePaneLifecycleOptions(
                activeId: "p1",
                hotHiddenCap: 2,
                paneIds: ["p1", "p2", "p3", "p4", "p5"]
            )
        )
        // Active is visible.
        XCTAssertEqual(next.entries["p1"]?.lifecycle, .visible)
        // First 2 (sorted by lastVisible desc after p1=visible) are hot-hidden.
        // With empty state, all inactive panes have lastVisible=0 (= tied).
        // Sorted = insertion order: p5, p4, p3, p2 are sorted by entry
        // order in paneIds list (= p2, p3, p4, p5 with lastVisible=0).
        // cap=2 = p2 + p3 hot-hidden (insertion order on ties).
        XCTAssertEqual(next.entries["p2"]?.lifecycle, .hotHidden)
        XCTAssertEqual(next.entries["p3"]?.lifecycle, .hotHidden)
        // Older (= later in list) parked.
        XCTAssertEqual(next.entries["p4"]?.lifecycle, .parked)
        XCTAssertEqual(next.entries["p5"]?.lifecycle, .parked)
    }
}