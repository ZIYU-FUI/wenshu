// V0Fix1LayoutTests.swift · 文枢 (Wenshu) · v0.03.0 V0-fix-1
//
// 装机 user 8/10 OOB 拍板 6 件 UI FCP-ification fix 的回归测试。
// 沿用 LT01Fix5Tests / WenshuInspectorForeshadowTests 的"源码静态扫
// 描 + 字符面量断言"模式 — SwiftPM-only binary AX tree 抓不到, 我
// 们的真值就是 source 里"有这个 / 没这个"。
//
// 覆盖:
//   - testLayoutShellView_topLeftPanelTitle_noH1Text
//   - testLayoutShellView_bottomLeftPanelTitle_noH1Text
//   - testLayoutShellView_topLeftHeaderBar_hasPlusButton
//   - testChatPanelView_chatTabIcons_4Icons
//   - testProjectCreateView_modalSheetSize_540x480
//   - testLayoutShellView_titleBar_noProjectLiteral
//   - testProjectKanbanTab_deferred_to_v040
//
// 拍板背景 (装机 user 8/10 14:35 OOB):
//   Fix A: LayoutShellView 左上 panel 加 38pt title-bar (0 text +
//          plus.circle.fill, FCP 风格)
//   Fix B: ChatPanelView Picker 删 H1 残留 "聊天区视图" (a11y 改 ""),
//          ProjectListView 删 "项目管理视图" H1 (如存在)
//   Fix C: 4 个 chat tab 改 ICON-only (bubble.left / clock /
//          person.2 / list.bullet.rectangle), 走 .help() tooltip
//          兜中文
//   Fix D: ProjectCreateView frame 540x480 (硬固定, 替换原 520x480
//          软下限)
//   Fix E: ProjectKanbanTab 32pt ICON + 短 label + tooltip —
//          v0.02.0 暂无此文件, 留 v0.04.0 实现
//   Fix F: 新增 DESIGN-V0-fix-1.md 设计文档 (~380 行)

import XCTest
@testable import WenshuApp

final class V0Fix1LayoutTests: XCTestCase {

    // MARK: - Helpers

    /// Resolve `<worktree>/<path>` to an absolute path the test runner
    /// can `String(contentsOf:)`. Works under both `swift test` (CWD =
    /// package root) and xctest CLI.
    private func repoFile(_ relative: String) throws -> String {
        let cwd = FileManager.default.currentDirectoryPath
        let candidate = cwd + "/" + relative
        return try String(contentsOfFile: candidate, encoding: .utf8)
    }

    /// Strip `// line comments` and `/* block comments */` so source-
    /// level tests don't trip on illustrative mentions inside markdown
    /// headers + doc comments. Mirrors the helper in LT01Fix5Tests.
    private func stripSwiftComments(_ source: String) -> String {
        var result = ""
        result.reserveCapacity(source.count)
        var idx = source.startIndex
        let end = source.endIndex
        var inStringLiteral = false
        while idx < end {
            let next = source.index(after: idx)
            if !inStringLiteral,
               next < end,
               source[idx] == "/",
               source[next] == "*" {
                var scan = source.index(after: next)
                while scan < end {
                    let after = source.index(after: scan)
                    if after < end,
                       source[scan] == "*",
                       source[after] == "/" {
                        scan = source.index(after: after)
                        break
                    }
                    scan = after
                }
                idx = scan
                continue
            }
            if !inStringLiteral,
               next < end,
               source[idx] == "/",
               source[next] == "/" {
                var scan = idx
                while scan < end, source[scan] != "\n" {
                    scan = source.index(after: scan)
                }
                idx = scan
                continue
            }
            if source[idx] == "\"" {
                inStringLiteral.toggle()
            }
            result.append(source[idx])
            idx = next
        }
        return result
    }

    // MARK: - Fix B (Part 1): LayoutShellView 删 "项目管理视图" H1

    /// 装机 user 8/10 OOB 拍板 (Fix B): LayoutShellView 不应再含 H1 文
    /// 本 "项目管理视图" (= LT-01-fix5 优化3 拍板"标题栏全删, 用功能
    /// 告诉用户" 沿用, 文字版冗余标题清掉)。 此断言扫整个 source (含
    /// 注释), 因为 LayoutShellView 全文注释里也不该出现这个字面量。
    func testLayoutShellView_topLeftPanelTitle_noH1Text() throws {
        let source = try repoFile(
            "Sources/WenshuApp/Views/Layout/LayoutShellView.swift"
        )
        XCTAssertFalse(
            source.contains("项目管理视图"),
            "LayoutShellView 不应含 H1 字面量 '项目管理视图' (V0-fix-1 Fix B)"
        )
    }

    // MARK: - Fix B (Part 2): LayoutShellView 删 "聊天区视图" H1

    /// 同 Fix B 拍板, LayoutShellView 不应含 "聊天区视图" 文本 (= 原
    /// ChatPanelView 残留 H1 字符串的对应源)。 注意 ChatPanelView 仍然
    /// 持有自己的字符串 ("聊天区视图"), 那个走 ChatPanelView 的
    /// Picker a11y label 删除, 由 `testChatPanelView_chatTabIcons_4Icons`
    /// 单独断言.
    func testLayoutShellView_bottomLeftPanelTitle_noH1Text() throws {
        let source = try repoFile(
            "Sources/WenshuApp/Views/Layout/LayoutShellView.swift"
        )
        XCTAssertFalse(
            source.contains("聊天区视图"),
            "LayoutShellView 不应含 H1 字面量 '聊天区视图' (V0-fix-1 Fix B)"
        )
    }

    // MARK: - Fix A: topLeft title-bar "+" 按钮

    /// 装机 user 8/10 OOB 拍板 (Fix A): 左上 panel 加 38pt title-bar,
    /// 内容只有 `plus.circle.fill` SF Symbol + `.help("新建项目")` tooltip。
    /// Source 必须包含两个核心字面量 (`plus.circle.fill` + `新建项目`),
    /// 二者同时在场才能认定 title-bar + tooltip 接对。
    func testLayoutShellView_topLeftHeaderBar_hasPlusButton() throws {
        let source = try repoFile(
            "Sources/WenshuApp/Views/Layout/LayoutShellView.swift"
        )
        let iconLib = try repoFile(
            "Sources/WenshuApp/Views/IconLibrary.swift"
        )
        // V0-fix-11 修真 #1: + 按钮 SF Symbol 修真修真 <plus> (修真
        // FCP Viewer 修真 + ICON, 修真 V0-fix-8 大圆圈 plus.circle.fill).
        XCTAssertTrue(
            iconLib.contains(#""plus""#),
            "IconLibrary Action.newProject 必须含 SF Symbol 'plus' (V0-fix-11 修真 #1 — FCP Viewer 修真 + ICON)"
        )
        XCTAssertTrue(
            source.contains("新建项目"),
            "LayoutShellView 必须包含 '新建项目' 字符串 (Fix A title-bar 按钮 tooltip)"
        )
        // V0-fix-11 修真 #2: topLeftHeaderBar height 38pt → 28pt
        // (修真 FCP Viewer 顶部 toolbar 修真, memi §3.5 layout 修真).
        XCTAssertTrue(
            source.contains(".frame(height: 28)"),
            "LayoutShellView topLeft header-bar 必须固定 height=28pt (V0-fix-11 修真 #2 — FCP Viewer 顶部 toolbar)"
        )
    }

    // MARK: - Fix C: 4 chat tab ICON-only

    /// 装机 user 8/10 OOB 拍板 (Fix C): 4 个 chat tab 改 ICON-only, SF
    /// Symbol 映射按 fix19 风格精简。 Picker 内必须出现 4 个 SF Symbol,
    /// 且 Picker 不再用 `Label(tab.rawValue, ...)` 文字标签 (= Tab 的
    /// 文字版 label, 走 .help() 兜中文)。
    ///
    /// 关于 "聊天" / "时间线" / "关系图" / "大纲" 字符串: 它们仍出现在
    /// `ChatPanelTab` enum 的 rawValue (= Picker 不再依赖它们, 但 enum
    /// 自描述保留), 也走 `.help(tab.rawValue)` tooltip — 这些用法都允
    /// 许, 测试只断言 **Picker 块里没 `Label(tab.rawValue` 这种文字标签**.
    func testChatPanelView_chatTabIcons_4Icons() throws {
        let source = try repoFile(
            "Sources/WenshuApp/Views/Chat/ChatPanelView.swift"
        )
        // 4 个 SF Symbol 必须都在 source 里 (出现在 IconLibrary.tab
        // accessor 或 ChatPanelTab.symbolName 映射, V0-fix-11)
        XCTAssertTrue(
            source.contains("bubble.left"),
            "ChatPanelView 必须含 SF Symbol 'bubble.left' (Fix C + V0-fix-8 chat tab)"
        )
        XCTAssertTrue(
            source.contains("clock"),
            "ChatPanelView 必须含 SF Symbol 'clock' (Fix C + V0-fix-8 timeline tab)"
        )
        XCTAssertTrue(
            source.contains("person.2"),
            "ChatPanelView 必须含 SF Symbol 'person.2' (Fix C + V0-fix-8 relationships tab)"
        )
        // V0-fix-8 (AIF 16:20 重定义真值): list.bullet.rectangle → list.bullet.indent
        XCTAssertTrue(
            source.contains("list.bullet.indent"),
            "ChatPanelView 必须含 SF Symbol 'list.bullet.indent' (V0-fix-8 AIF 16:20 真值, outline tab)"
        )
        // Picker 块不应再用文字 Label — 改成 Image(systemName:)
        XCTAssertFalse(
            source.contains("Label(tab.rawValue"),
            "ChatPanelView Picker 不应再用 Label(tab.rawValue, ...) 文字标签 (Fix C ICON-only)"
        )
        // Fix B 兜底: Picker a11y 字符串标签不应再含 "聊天区视图"
        XCTAssertFalse(
            source.contains("Picker(\"聊天区视图\""),
            "ChatPanelView Picker a11y 字符串标签不应再含 '聊天区视图' (Fix B H1 残留清掉)"
        )
    }

    // MARK: - Fix D: ProjectCreateView 540x480

    /// 装机 user 8/10 OOB 拍板 (Fix D): modal 硬固定 540x480, 替换原
    /// 520x480 软下限 (= 用户拖拽边界时 modal 跟主窗口变形, 比例失调)。
    func testProjectCreateView_modalSheetSize_540x480() throws {
        let rawSource = try repoFile(
            "Sources/WenshuApp/Views/ProjectCreateView.swift"
        )
        // 兜底: 软下限的 minWidth/minHeight 应已删。 strip 注释避免跟
        // V0-fix-1 注释里的 "(原 520x480 软下限...)" 字面量误命中。
        let code = stripSwiftComments(rawSource)

        XCTAssertTrue(
            code.contains(".frame(width: 540, height: 480)"),
            "ProjectCreateView 必须使用 .frame(width: 540, height: 480) 硬固定 (Fix D)"
        )
        XCTAssertFalse(
            code.contains(".frame(minWidth: 520, minHeight: 480)"),
            "ProjectCreateView 活动代码不应再用 .frame(minWidth: 520, minHeight: 480) 软下限 (Fix D 替换)"
        )
    }

    // MARK: - Fix A 兜底: title-bar 不带 panel 名文本

    /// Fix A 兜底: 左上 title-bar 不显示 "项目" / "项目管理" / "项目管理视图"
    /// 等任何 panel 名文本 — 仅显示 + 按钮, hover tooltip 兜语义。 我
    /// 们 strip 注释后扫描, 因为 LayoutShellView 注释里仍然有
    /// "│ 项目管理   │" (= LT-01-fix5 拍板前的 ASCII layout 注释, 不动)。
    func testLayoutShellView_titleBar_noProjectLiteral() throws {
        let rawSource = try repoFile(
            "Sources/WenshuApp/Views/Layout/LayoutShellView.swift"
        )
        let source = stripSwiftComments(rawSource)

        // strip 注释后, "项目" 不应再出现 (V0-fix-1 Fix A: title-bar 0 text)
        XCTAssertFalse(
            source.contains("\"项目\""),
            "LayoutShellView 活动代码不能含 Text(\"项目\") 这种独立 '项目' 字面量 (Fix A title-bar 0 text)"
        )
        XCTAssertFalse(
            source.contains("\"项目管理\""),
            "LayoutShellView 活动代码不能含 \"项目管理\" 字面量 (Fix A title-bar 0 text)"
        )
        XCTAssertFalse(
            source.contains("\"项目管理视图\""),
            "LayoutShellView 活动代码不能含 \"项目管理视图\" 字面量 (Fix B H1 残留清掉)"
        )
    }

    // MARK: - Fix E 兜底: ProjectKanbanTab 留 v0.04.0

    /// 装机 user 8/10 OOB 拍板 (Fix E): ProjectKanbanTab 的 32pt ICON +
    /// 短 label + tooltip 风格 — 但 v0.02.0 当前 codebase 还没有
    /// ProjectKanbanTab.swift 文件 (它是 LT-03 / v0.04.0 的产物)。
    /// 本 test 断言 deferred 状态: 文件不存在, 留 v0.04.0 实现。 跟
    /// 拍板任务的"IF not exists, SKIP Fix E + report"一致。
    func testProjectKanbanTab_deferred_to_v040() throws {
        let cwd = FileManager.default.currentDirectoryPath
        let kanbanPath = cwd + "/Sources/WenshuApp/Views/ProjectKanbanTab.swift"
        let exists = FileManager.default.fileExists(atPath: kanbanPath)
        XCTAssertFalse(
            exists,
            "ProjectKanbanTab.swift 在 v0.02.0 还未引入 (V0-fix-1 Fix E 留 v0.04.0 实现), 当前路径: \(kanbanPath)"
        )
        // 兜底: 整个 Sources/WenshuApp/Views/ 下都不该有 ProjectKanbanTab 相关文件
        // (e.g. 不同命名空间也算 deferred)
        let viewsRoot = cwd + "/Sources/WenshuApp/Views"
        let allFiles = FileManager.default.subpaths(atPath: viewsRoot) ?? []
        let kanbanFiles = allFiles.filter { $0.lowercased().contains("kanban") }
        XCTAssertEqual(
            kanbanFiles.count, 0,
            "Sources/WenshuApp/Views/ 下不应有 kanban 相关文件 (Fix E deferred), 当前: \(kanbanFiles)"
        )
    }
}
