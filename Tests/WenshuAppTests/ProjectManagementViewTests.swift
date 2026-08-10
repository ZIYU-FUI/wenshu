// ProjectManagementViewTests.swift · 文枢 (Wenshu) · v0.02.0 WO-LT-03 v2
//
// Compile-time + structural tests for the new 5-tab left-top panel.
// Mirrors the chat-panel test pattern (LT04ChatPanelTests.swift):
//   - Assert enum-driven tab defaults
//   - Assert placeholder text constants
//   - Assert view construction (compile-time regression guard for
//     @MainActor + NavigationStack + Picker API).
//
// What this does NOT do:
// - Drive the live UI (no cua-driver; PM-direct verifies visual flow).
// - Touch .sheet / NSWindow (AGENTS §6 — sheet focus bugs WO-006~010).
// - Touch .ws / CDChapter (AGENTS §5 — CC does not change .ws schema).

import XCTest
import SwiftUI
@testable import WenshuApp

final class ProjectManagementViewTests: XCTestCase {

    // MARK: - Tab enum contract

    /// AGENTS §8.1 says topLeft panel hosts 5 tabs in this exact order:
    /// 项目 / 章节 / 设定 / 资料 / 看板. If a future refactor re-orders
    /// or drops a tab, the default-tab test below breaks.
    func testTabOrder_matchesAGENTS_8_1() {
        let order = ProjectManagementTab.allCases.map { $0.rawValue }
        XCTAssertEqual(order, ["项目", "章节", "设定", "资料", "看板"])
    }

    /// 默认 tab = 项目 (装机 user 8/10 拍板)。 allCases.first 锁了
    /// 项目是 default, 加 enum 顺序 guard (见上一个 test) 就锁了
    /// 用户启动时直接看到项目 tab。
    func testDefaultTab_isProjects() {
        XCTAssertEqual(ProjectManagementTab.allCases.first, .projects)
    }

    /// Tab 1 + 2 实装, Tab 3-5 占位 (v0.02.0 拍板边界)
    func testImplementationFlags_matchV020Boundary() {
        XCTAssertTrue(ProjectManagementTab.projects.isImplemented)
        XCTAssertTrue(ProjectManagementTab.chapters.isImplemented)
        XCTAssertFalse(ProjectManagementTab.settings.isImplemented)
        XCTAssertFalse(ProjectManagementTab.resources.isImplemented)
        XCTAssertFalse(ProjectManagementTab.kanban.isImplemented)
    }

    /// Tab 3-5 占位文案锁住 (避免后续拍板变化时无声变更 UI 文案)
    func testPlaceholderStrings_areStable() {
        XCTAssertEqual(ProjectManagementTab.settings.placeholder,
                       "v0.01.0 ProjectSnapshot 字段只读展示")
        XCTAssertEqual(ProjectManagementTab.resources.placeholder,
                       "v0.04.0 实现")
        XCTAssertEqual(ProjectManagementTab.kanban.placeholder,
                       "v0.04.0 实现")
    }

    // MARK: - Compile-time guards

    /// 5-tab root 持有 NavigationStack + Picker(.segmented) + 5 个子
    /// view, body type-check 是最容易被未来 SDK 升级 / API 弃用打
    /// 到的点。 构造一次整个 view 树作为编译期回归 guard。
    @MainActor
    func testProjectManagementView_instantiatesCleanly() {
        let view = ProjectManagementView()
        XCTAssertNotNil(view, "ProjectManagementView must instantiate")
    }

    /// Tab 1/2 各带 NavigationStack — 必须能在没有数据时渲染空状态
    /// (projects == [] 时 ChapterTreeTab 不崩)。
    @MainActor
    func testTabSubviews_instantiateWithEmptyState() {
        let chapterTab = ChapterTreeTab(
            projects: [],
            navPath: .constant(NavigationPath())
        )
        XCTAssertNotNil(chapterTab)

        let settingsTab = ProjectSettingsTab(project: nil)
        XCTAssertNotNil(settingsTab)

        let kanbanTab = ProjectKanbanTab(projectCount: 0)
        XCTAssertNotNil(kanbanTab)
    }
}
