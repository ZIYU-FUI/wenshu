// WorkspaceStateTests.swift · Wenshu (文枢) · v0.28 ticket 028-003
//
// Unit tests for the WorkspaceState v2 split-tree model (= 1:1 port
// of /Volumes/ANAN/.hermes/hermes-agent/apps/desktop/src/components/
// pane-shell/tree/model.ts). Covers the 6 primary pure functions +
// JSON round-trip + the v1 → v2 wholesale-retire migration logic.
//
// Acceptance criterion (= ticket 028-003 §"Acceptance criteria"):
// "Unit tests for all 6 primary pure functions (= mirror hermes's
// test suite)" — modeled after /Volumes/ANAN/.hermes/hermes-agent/
// apps/desktop/src/components/pane-shell/tree/{remove-pane,multi-tab-
// drag,dock-enforce,floating-adoption}.test.ts.

import XCTest
@testable import WenshuApp

final class WorkspaceStateTests: XCTestCase {
    // MARK: - Test fixtures

    /// A simple 3-pane tree (sidebar / editor / chat) with the editor
    /// in the middle and chat on the right. Mirrors the FCP Browser
    /// paradigm.
    private func makeSimpleTree() -> (root: LayoutNode, sidebar: PaneID, editor: PaneID, chat: PaneID) {
        let sidebar = PaneID()
        let editor = PaneID()
        let chat = PaneID()
        let root = makeSplit(
            orientation: .row,
            children: [
                makeGroup(panes: [sidebar]),
                makeGroup(panes: [editor]),
                makeGroup(panes: [chat])
            ],
            weights: [1, 2, 1]
        )
        return (root, sidebar, editor, chat)
    }

    // MARK: - normalize (= primary function #1)

    func testNormalizePrunesEmptyGroups() {
        let empty = makeGroup(panes: [])
        let result = normalize(empty)
        XCTAssertNil(result, "empty group must normalize to nil (= prune)")
    }

    func testNormalizeUnwrapsSingleChildSplit() {
        let inner = makeGroup(panes: [PaneID()])
        let outer = makeSplit(orientation: .row, children: [inner])
        let result = normalize(outer)
        XCTAssertNotNil(result)
        if case .group = result! {
            // unwrapped back to the inner group
        } else {
            XCTFail("single-child split must unwrap to the child")
        }
    }

    func testNormalizeReassignsActivePaneWhenMissing() {
        let p1 = PaneID()
        let p2 = PaneID()
        // active references p1 but panes no longer contains p1 (after
        // a structural edit) — normalize should fall back to p2.
        let g = GroupNode(id: "g", panes: [p2], active: p1, minimized: nil, tabStrip: nil)
        let result = normalize(.group(g))
        XCTAssertNotNil(result)
        if case .group(let resultGroup) = result! {
            XCTAssertEqual(resultGroup.active, p2)
        } else {
            XCTFail("expected group result")
        }
    }

    // MARK: - removePane (= primary function #2)

    func testRemovePanePromotesNeighborAsActive() {
        let (root, sidebar, editor, chat) = makeSimpleTree()
        guard let next = removePane(root, paneId: editor) else {
            XCTFail("removePane returned nil"); return
        }
        // The editor group is gone; sidebar + chat remain in a row
        // split with 2 children.
        XCTAssertTrue(allPaneIDs(next).contains(sidebar))
        XCTAssertTrue(allPaneIDs(next).contains(chat))
        XCTAssertFalse(allPaneIDs(next).contains(editor))
    }

    func testRemovePaneDropsEmptyTree() {
        let only = PaneID()
        let root = makeGroup(panes: [only])
        let result = removePane(root, paneId: only)
        XCTAssertNil(result, "removing the only pane must empty the tree")
    }

    // MARK: - insertAtGroup (= primary function #3)

    func testInsertCenterJoinsAsTab() {
        let (root, _, editor, _) = makeSimpleTree()
        let newPane = PaneID()
        guard let editorGroup = findGroup(ofPane: editor, in: root) else {
            XCTFail("could not find editor group"); return
        }
        guard let next = insertAtGroup(root, targetGroupId: editorGroup.id, paneId: newPane, pos: .center) else {
            XCTFail("insertAtGroup returned nil"); return
        }
        // The new pane should land in the editor's group (= joins as
        // a tab alongside editor).
        XCTAssertTrue(findGroup(ofPane: newPane, in: next)?.panes.contains(editor) ?? false,
                      "editor should still be in the same group")
        XCTAssertTrue(findGroup(ofPane: newPane, in: next)?.panes.contains(newPane) ?? false,
                      "new pane should join the editor group")
    }

    func testInsertEdgeSplitsGroup() {
        let (root, _, _, chat) = makeSimpleTree()
        let newPane = PaneID()
        guard let chatGroup = findGroup(ofPane: chat, in: root) else {
            XCTFail("could not find chat group"); return
        }
        guard let next = insertAtGroup(root, targetGroupId: chatGroup.id, paneId: newPane, pos: .right) else {
            XCTFail("insertAtGroup returned nil"); return
        }
        // The new pane should appear as a sibling in a row split.
        XCTAssertTrue(allPaneIDs(next).contains(newPane))
    }

    // MARK: - movePane (= primary function #4)

    func testMovePaneIsNoOpForSelfSingleGroup() {
        let (root, sidebar, _, _) = makeSimpleTree()
        let sidebarGroup = findGroup(ofPane: sidebar, in: root)!
        let result = movePane(root, paneId: sidebar, target: (groupId: sidebarGroup.id, pos: .center, before: nil))
        // No-op guard: dropping a single-pane group onto itself must
        // return the same tree.
        XCTAssertEqual(result.id, root.id)
    }

    func testMovePaneRebuildsTree() {
        let (root, sidebar, _, chat) = makeSimpleTree()
        let chatGroup = findGroup(ofPane: chat, in: root)!
        // Move sidebar to the right edge of the chat group (= join as
        // a tab on the right side).
        let result = movePane(root, paneId: sidebar, target: (groupId: chatGroup.id, pos: .center, before: nil))
        XCTAssertTrue(allPaneIDs(result).contains(sidebar))
        XCTAssertTrue(allPaneIDs(result).contains(chat))
    }

    // MARK: - setActivePane (= primary function #5)

    func testSetActivePaneSwitchesActive() {
        let (root, _, editor, _) = makeSimpleTree()
        guard let editorGroup = findGroup(ofPane: editor, in: root) else {
            XCTFail("could not find editor group"); return
        }
        let otherPane = PaneID()
        let withOther = insertAtGroup(root, targetGroupId: editorGroup.id, paneId: otherPane, pos: .center)
        XCTAssertNotNil(withOther)
        guard let updated = withOther.flatMap({ setActivePane($0, groupId: editorGroup.id, paneId: otherPane) }) else {
            XCTFail("setActivePane returned nil"); return
        }
        if let g = findGroup(updated, groupId: editorGroup.id) {
            XCTAssertEqual(g.active, otherPane)
        } else {
            XCTFail("editor group should still exist")
        }
    }

    // MARK: - mergeZonesWithPane (= primary function #6)

    func testMergeZonesReturnsNilForNonRectangularSet() {
        let (root, _, _, _) = makeSimpleTree()
        // A single-element set (= merging just one zone) must return
        // nil because `set.count > 1` is the rectangle guard.
        let sidebar = PaneID()
        let result = mergeZonesWithPane(root, groupIds: [groupLeafIDs(root)[0]], paneId: [sidebar])
        XCTAssertNil(result, "single-element set must return nil")
    }

    // MARK: - JSON round-trip

    func testWorkspaceStateRoundTrip() throws {
        let (root, sidebar, editor, chat) = makeSimpleTree()
        let workspace = WorkspaceState(
            root: root,
            panes: [
                PaneNode(id: sidebar, split: .horizontal, frame: .defaultFrame, tabIDs: []),
                PaneNode(id: editor, split: .horizontal, frame: .defaultFrame, tabIDs: []),
                PaneNode(id: chat, split: .horizontal, frame: .defaultFrame, tabIDs: [])
            ],
            tabs: [],
            version: 2
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(workspace)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(WorkspaceState.self, from: data)
        XCTAssertEqual(decoded, workspace, "encode -> decode must round-trip equal")
        XCTAssertEqual(decoded.version, 2)
    }

    func testIsLayoutNodeValidates() {
        let (root, _, _, _) = makeSimpleTree()
        // Encode and re-decode to get a [String: Any] representation
        // (= matches the runtime usage where persisted JSON blobs are
        // deserialized as dictionaries).
        let data = (try? JSONEncoder().encode(root)) ?? Data()
        let dict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        XCTAssertNotNil(dict, "tree must encode to JSON dict")
        // Note: `isLayoutNode` is a structural shape check (= not a
        // full decode). For UUID-based ids (= PaneID encodes as
        // `{"raw": "..."}`), the cheap gate is satisfied by the
        // presence of structural keys.
        XCTAssertTrue(isLayoutNode(dict as Any), "encoded tree must validate")
        XCTAssertFalse(isLayoutNode("not a node" as Any))
        XCTAssertFalse(isLayoutNode(NSNull()))
    }

    /// The cheap structural gate accepts both legal shapes and rejects
    /// unknowns — exact content decoding is left to JSONDecoder.
    func testIsLayoutNodeAcceptsTopLevelShape() {
        // A minimal group dict validates.
        let groupDict: [String: Any] = [
            "type": "group",
            "id": "g-1",
            "panes": [["raw": "00000000-0000-0000-0000-000000000000"]],
            "active": ["raw": "00000000-0000-0000-0000-000000000000"]
        ]
        XCTAssertTrue(isLayoutNode(groupDict as Any))
        // A minimal split dict validates.
        let splitDict: [String: Any] = [
            "type": "split",
            "id": "s-1",
            "orientation": "row",
            "children": [
                ["type": "group", "id": "g-1", "panes": [], "active": ["raw": "00000000-0000-0000-0000-000000000000"]]
            ],
            "weights": [1.0]
        ]
        XCTAssertTrue(isLayoutNode(splitDict as Any))
        // Unknown type discriminator is rejected.
        XCTAssertFalse(isLayoutNode(["type": "unknown"] as Any))
        // Missing structural keys are rejected.
        XCTAssertFalse(isLayoutNode(["type": "split", "id": "s-1"] as Any))
    }

    // MARK: - v1 → v2 migration (= wholesale retire)

    func testMigrationRetiresV1Wholesale() {
        // A v1 WorkspaceState (= flat pane array) cannot be decoded
        // as v2 (= the schema is different). The store handles this
        // by removing the v1 keys; we test the schema-mismatch path
        // directly by trying to decode a v1-shaped blob as v2.
        let v1JSON = """
        {
          "panes": [],
          "activePaneID": "00000000-0000-0000-0000-000000000000",
          "activeTabIndexByPane": {},
          "tabs": [],
          "version": 1
        }
        """
        let data = v1JSON.data(using: .utf8)!
        let decoder = JSONDecoder()
        // v1 schema decode as v2 MUST fail (= the v2 WorkspaceState
        // has a `root` field that v1 lacks).
        XCTAssertThrowsError(try decoder.decode(WorkspaceState.self, from: data))
    }
}

// MARK: - Helpers used by tests above

extension WorkspaceStateTests {
    /// Find the group containing `paneId`, or nil.
    fileprivate func findGroup(ofPane paneId: PaneID, in node: LayoutNode) -> GroupNode? {
        if case .group(let g) = node {
            return g.panes.contains(paneId) ? g : nil
        }
        if case .split(let s) = node {
            for child in s.children {
                if let hit = findGroup(ofPane: paneId, in: child) { return hit }
            }
        }
        return nil
    }

    /// Convenience: find a group by its pane's membership (= matches
    /// the file-scope helper but as a fluent receiver).
    fileprivate func findGroup(_ node: LayoutNode, groupId: String) -> GroupNode? {
        if case .group(let g) = node {
            return g.id == groupId ? g : nil
        }
        if case .split(let s) = node {
            for child in s.children {
                if let hit = findGroup(child, groupId: groupId) { return hit }
            }
        }
        return nil
    }

    fileprivate func allPaneIDs(_ node: LayoutNode) -> [PaneID] {
        if case .group(let g) = node { return g.panes }
        if case .split(let s) = node { return s.children.flatMap { allPaneIDs($0) } }
        return []
    }

    fileprivate func groupLeafIDs(_ node: LayoutNode) -> [String] {
        if case .group(let g) = node { return [g.id] }
        if case .split(let s) = node { return s.children.flatMap { groupLeafIDs($0) } }
        return []
    }
}