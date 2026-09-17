//
//  PaneNSController+CollectHelpers.swift · Wenshu · v1.28 C3.2.5
//
//  v1.28 C3.2.5: extract 2 traversal helpers from PaneNSController.swift
//  (= countSplitNodesBefore + collectPaneControllers). These 2 helpers
//  are unique to C3.2.5 (= they were not part of C3.2.1 + C3.2.2 + C3.2.4).
//
//  Originally at PaneNSController.swift:981-994 (= countSplitNodesBefore)
//  and 1608-1625 (= collectPaneControllers). Both are self-contained
//  (= they read only `store` + `paneKindByItem` which are already
//  relaxed to `internal` access level by C3.2.2 + C3.2.4).
//
//  Behavior preserved (= both helpers unchanged; = same logic; = same
//  return types).
//

import AppKit

extension PaneNSController {
    /// Count how many .split nodes appear before `node` in the
    /// parent's children array. Used to pair .split SplitNodes with
    /// the corresponding nested NSSplitViewController by index.
    func countSplitNodesBefore(_ node: LayoutNode) -> Int {
        guard case .split(let parent) = store.workspace.root else { return 0 }
        guard let index = parent.children.firstIndex(of: node) else { return 0 }
        var count = 0
        for i in 0..<index {
            if case .split = parent.children[i] {
                count += 1
            }
        }
        return count
    }

    /// Flatten self + every nested PaneNSController child into an
    /// array. The root controller hosts wrap-mode items (= the
    /// upper-band and lower-band nested controllers live as
    /// root.splitViewItems); the per-pane NSSplitViewItems live on
    /// the nested controllers.
    func collectPaneControllers() -> [PaneNSController] {
        var result: [PaneNSController] = [self]
        var queue: [NSSplitViewController] = [self]
        while let next = queue.first {
            queue.removeFirst()
            for child in next.children {
                if let splitChild = child as? PaneNSController {
                    result.append(splitChild)
                    queue.append(splitChild)
                }
            }
        }
        return result
    }
}
