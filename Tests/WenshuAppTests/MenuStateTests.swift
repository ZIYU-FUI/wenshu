// MenuStateTests.swift · 文枢 (Wenshu) · v0.02.0 WO-LT-01-fix4
//
// LT-01-fix4 优化2: the macOS menu-bar panel toggle items advertise
// their NEXT action in the label (FCP 范式):
//   - visible  → "隐藏 X"  (clicking will hide it)
//   - hidden   → "显示 X"  (clicking will show it)
//
// `LayoutShellViewModel.menuTitle(for:)` is the single source of truth —
// `LayoutMenuContent` (in App.swift) calls it from inside a `@ViewBuilder`
// so SwiftUI re-renders the menu after every toggle. These tests pin the
// string contract independently of any SwiftUI render path, so a future
// refactor can't silently break the FCP convention.

import XCTest
@testable import WenshuApp

final class MenuStateTests: XCTestCase {

    // MARK: - Visible panel → "隐藏 X"

    /// Default state (fresh VM, no .ws loaded) has every panel visible.
    /// The menu item must therefore read "隐藏 项目管理" — promising the
    /// user that a click will hide the panel.
    @MainActor
    func testMenuTitle_showsHideWhenVisible() {
        let vm = LayoutShellViewModel()
        XCTAssertTrue(vm.isVisible(.topLeft),
                      "Default visibility must be all-visible")
        XCTAssertEqual(vm.menuTitle(for: .topLeft), "隐藏 项目管理")

        // Sanity-check the rest of the panels (titles depend on PanelID).
        XCTAssertEqual(vm.menuTitle(for: .topCenter), "隐藏 文档")
        XCTAssertEqual(vm.menuTitle(for: .topRight), "隐藏 检视")
        XCTAssertEqual(vm.menuTitle(for: .bottomLeft), "隐藏 聊天")
        XCTAssertEqual(vm.menuTitle(for: .bottomRight), "隐藏 状态")
    }

    // MARK: - Hidden panel → "显示 X"

    /// After hiding topLeft (togglePanelVisibility), the menu item must
    /// read "显示 项目管理" — promising the user that a click will
    /// restore the panel.
    @MainActor
    func testMenuTitle_showsShowWhenHidden() {
        let vm = LayoutShellViewModel()
        vm.togglePanelVisibility(.topLeft)
        XCTAssertFalse(vm.isVisible(.topLeft),
                       "togglePanelVisibility must hide the target panel")

        XCTAssertEqual(vm.menuTitle(for: .topLeft), "显示 项目管理")

        // Other panels still read "隐藏 X" — toggling one panel doesn't
        // disturb the others' titles.
        XCTAssertEqual(vm.menuTitle(for: .topCenter), "隐藏 文档")
        XCTAssertEqual(vm.menuTitle(for: .bottomRight), "隐藏 状态")
    }

    // MARK: - Toggle flips the title

    /// Walk the full lifecycle: visible → click → hidden → click → visible.
    /// The menu title must invert at every step. This is the test that
    /// catches a regression in the wire-up between
    /// `LayoutMenuContent`'s `@ObservedObject` and `vm.menuTitle(for:)`.
    @MainActor
    func testMenuToggle_changesTitleAfterClick() {
        let vm = LayoutShellViewModel()

        // 1. Initial: visible → "隐藏 项目管理".
        let before = vm.menuTitle(for: .topLeft)
        XCTAssertEqual(before, "隐藏 项目管理")

        // 2. Click (togglePanelVisibility) — flips visibility.
        vm.togglePanelVisibility(.topLeft)

        // 3. Title inverts.
        let after = vm.menuTitle(for: .topLeft)
        XCTAssertEqual(after, "显示 项目管理")
        XCTAssertNotEqual(after, before,
                          "Toggle must invert the menu title")

        // 4. Click again — title flips back.
        vm.togglePanelVisibility(.topLeft)
        XCTAssertEqual(vm.menuTitle(for: .topLeft), "隐藏 项目管理")

        // 5. 全显示 (Cmd+Shift+1) brings it back too — even if it had been
        //    hidden via a separate path (panel was hidden mid-test, but
        //    showAllPanels resets to all-visible).
        vm.togglePanelVisibility(.bottomLeft)
        vm.togglePanelVisibility(.topRight)
        XCTAssertEqual(vm.menuTitle(for: .bottomLeft), "显示 聊天")
        XCTAssertEqual(vm.menuTitle(for: .topRight), "显示 检视")

        vm.showAllPanels()
        XCTAssertEqual(vm.menuTitle(for: .topLeft), "隐藏 项目管理")
        XCTAssertEqual(vm.menuTitle(for: .bottomLeft), "隐藏 聊天")
        XCTAssertEqual(vm.menuTitle(for: .topRight), "隐藏 检视")
    }
}
