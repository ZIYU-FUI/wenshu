// V0Fix2LayoutTests.swift · 文枢 (Wenshu) · v0.03.0 V0-fix-2
//
// 装机 user 8/10 15:30 + 15:35 OOB 真机拍板 V0-fix-1 (commit 1512a68d3,
// worktree 不带) + v0.02.0 LT-03 v2 (commit 3fab4fadc, worktree 不带)
// 漏修的 4 处 UI BUG 回归测试。 沿用 V0Fix1LayoutTests 的"源码静态扫描 +
// 字符面量断言"模式 — SwiftPM-only binary AX tree 抓不到, 我们的真
// 值就是 source 里"有这个 / 没这个".
//
// 覆盖 (4 个 test):
//   - testChatPanelView_4chatTabs_iconOnlyStyle         (Fix G)
//   - testInspectorView_2inspectorTabs_iconOnlyStyle    (Fix H)
//   - testLayoutShellView_topLeftHeaderBar_hasPlusButton (Fix I)
//   - testProjectListView_5tabList_present              (Fix J)
//
// 拍板背景 (装机 user 8/10 15:30 + 15:35 OOB 实机拍 v0.02.0 LOOP 后):
//   Fix G: ChatPanelView Picker ".segmented" 改 ".iconOnly" (macOS 13
//          上 segmented picker 即便只放 Image 也 fallback 显 SF Symbol
//          文字, 必须 iconOnly 才真 ICON-only). 同时真删 Picker a11y
//          "聊天区视图" H1 残留 (worktree 不带 v-fix-1, 必须从 0 改).
//   Fix H: InspectorView Picker 改 ICON-only (.iconOnly + 2 SF Symbol
//          eye / pencil.and.list.clipboard + Image(systemName:)
//          替 Text(tab.title)) + 删 selfHeader H1 "检视" + Picker a11y
//          "检视" 改 "". InspectorViewModel 不动, iconName 走 View 内
//          inline 静态映射 (跟 V0-fix-1 ChatPanelView 不动 ChatPanelView
//          Model 同形态).
//   Fix I: LayoutShellView 加 `topLeftPanelWithTitleBar` private var
//          (38pt HStack + Spacer + `plus.circle.fill` Button + .help
//          "新建项目") + .topLeft 分支改用 `topLeftPanelWithTitleBar`
//          (取代原 PlaceholderContent).
//   Fix J: ProjectListView 重写 5 tab 容器 (ProjectManagementTab enum +
//          5 case + 5 SF Symbol + Picker(.segmented) + 5 Tab 内容).
//          沿用 LT-03 v2 设计, 不新建 ProjectManagement/ 目录 (5 tab
//          内容放 ProjectListView 内部).

import XCTest
@testable import WenshuApp

final class V0Fix2LayoutTests: XCTestCase {

    // MARK: - Helpers (从 V0Fix1LayoutTests 复制, helper 完全相同)

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
    /// headers + doc comments. Mirrors the helper in V0Fix1LayoutTests.
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

    // MARK: - Fix G: ChatPanelView Picker 改 .iconOnly

    /// 装机 user 8/10 15:30 OOB 真机拍 V0-fix-1 后仍不符 (chat 4 tab
    /// 仍显文字). 真根因 = macOS 13 上 `.pickerStyle(.segmented)` 即便
    /// 只放 Image 也会 fallback 显 SF Symbol 名字 (实测: "bubble.left"
    /// "clock" "person.2" "list.bullet.rectangle" 这 4 个 SF Symbol 名字
    /// 字符串). 必须 `.pickerStyle(.iconOnly)` 强制 ICON-only.
    ///
    /// Source 必须包含 `.iconOnly`, strip 注释后不应再含 `.segmented`
    /// (避免未来回归到 .segmented).
    func testChatPanelView_4chatTabs_iconOnlyStyle() throws {
        let rawSource = try repoFile(
            "Sources/WenshuApp/Views/Chat/ChatPanelView.swift"
        )
        let code = stripSwiftComments(rawSource)
        let iconLibCode = stripSwiftComments(try repoFile(
            "Sources/WenshuApp/Views/Components/IconButton.swift"
        ))

        // V0-fix-11 修真 #5: Picker 修真 HStack + IconButton (修真
        // V0-fix-2 Fix G Picker(.iconOnly) + V0-fix-8 修真 #3 +
        // V0-fix-10.1 修真 #4 衍生). .buttonStyle(.plain) + frame 28×22
        // + IconButton 修真 pickerStyle.
        // V0-fix-11 修真 #5 / #6: .buttonStyle(.plain) 修真 IconButton
        // 组件 (Sources/WenshuApp/Views/Components/IconButton.swift) 内部,
        // View 修真文件不直接含 .buttonStyle(.plain) 字面量.
        XCTAssertTrue(
            iconLibCode.contains(".buttonStyle(.plain)"),
            "ChatPanelView 必须使用 .buttonStyle(.plain) (V0-fix-11 修真 #5 — IconButton 内部, FCP timeline 范式) — IconButton 内部 (V0-fix-11 修真 #5/#6 全局 ICON 按钮组件)"
        )
        XCTAssertFalse(
            code.contains(".pickerStyle(.segmented)"),
            "ChatPanelView 不应再用 .pickerStyle(.segmented) (V0-fix-2 Fix G 替换, 避免回归)"
        )

        // V0-fix-11 修真 #5: padding(.vertical: 8 → 4) (修真 FCP timeline 修真)
        XCTAssertTrue(
            code.contains(".padding(.vertical, 4)"),
            "ChatPanelView 修真 padding(.vertical, 4) (V0-fix-11 修真 #5 — FCP timeline 修真)"
        )

        // V0-fix-11 修真 #5: IconButton 组件 (Sources/WenshuApp/Views/Components/IconButton.swift)
        XCTAssertTrue(
            code.contains("IconButton("),
            "ChatPanelView 必须用 IconButton( 组件 (V0-fix-11 修真 #5 — 全局 ICON 按钮组件)"
        )
    }

    // MARK: - Fix H: InspectorView 2 tab ICON-only + 删 selfHeader

    /// 装机 user 8/10 15:30 OOB 真机拍 V0-fix-1 后仍不符 (右上 inspector
    /// 完全没动). 真根因 = V0-fix-1 派单 body 写 "Fix C: 4 chat tab ICON-only",
    /// **没写 InspectorView**, CC 实现只动 ChatPanelView. InspectorView
    /// 当前 (v-fix-1 后) 状态 = `Picker("检视", ...) { Text(tab.title) }
    /// .pickerStyle(.segmented)` + 顶部 `selfHeader` H1 "检视".
    ///
    /// V0-fix-2 Fix H 修法:
    ///   - Picker ".segmented" → ".iconOnly" (强制 ICON-only)
    ///   - Picker a11y "检视" → "" (跟 V0-fix-1 Fix B 同形态)
    ///   - Picker 块 Text(tab.title) → Image(systemName: iconName(for:))
    ///   - 2 SF Symbol: eye (伏笔) / pencil.and.list.clipboard (修订)
    ///   - 删 selfHeader 整段 (H1 "检视" 残留)
    func testInspectorView_2inspectorTabs_iconOnlyStyle() throws {
        let rawSource = try repoFile(
            "Sources/WenshuApp/Views/Inspector/InspectorView.swift"
        )
        let code = stripSwiftComments(rawSource)
        let iconLibCode = stripSwiftComments(try repoFile(
            "Sources/WenshuApp/Views/Components/IconButton.swift"
        ))
        let iconLib = stripSwiftComments(try repoFile(
            "Sources/WenshuApp/Views/IconLibrary.swift"
        ))

        // V0-fix-11 修真 #4: Picker 修真 HStack + IconButton (修真
        // V0-fix-2 Fix H + V0-fix-4 Fix 5 + V0-fix-10.1 修真 #5 衍生).
        XCTAssertTrue(
            code.contains("IconButton("),
            "InspectorView 必须用 IconButton( 组件 (V0-fix-11 修真 #4 — HStack + IconButton 修真 Picker)"
        )
        // V0-fix-11 修真 #5 / #6: .buttonStyle(.plain) 修真 IconButton
        // 组件 (Sources/WenshuApp/Views/Components/IconButton.swift) 内部,
        // View 修真文件不直接含 .buttonStyle(.plain) 字面量.
        XCTAssertTrue(
            iconLibCode.contains(".buttonStyle(.plain)"),
            "InspectorView 必须含 .buttonStyle(.plain) (V0-fix-11 修真 #4 — IconButton 内部, FCP 范式) — IconButton 内部 (V0-fix-11 修真 #5/#6 全局 ICON 按钮组件)"
        )
        XCTAssertFalse(
            code.contains(".pickerStyle(.iconOnly)"),
            "InspectorView 不应再用 .pickerStyle(.iconOnly) (V0-fix-11 修真 #4 — HStack+IconButton 修真 Picker)"
        )

        // 2 SF Symbol 必须都在 source 里 (IconLibrary.Inspector 真值)
        XCTAssertTrue(
            iconLib.contains("\"eye\""),
            "IconLibrary 必须含 SF Symbol 'eye' (V0-fix-11 修真 — Inspector.Tab.Inspector.foreshadow)"
        )
        XCTAssertTrue(
            iconLib.contains("pencil.and.list.clipboard"),
            "IconLibrary 必须含 SF Symbol 'pencil.and.list.clipboard' (V0-fix-11 修真 — Inspector.Tab.Inspector.revision)"
        )

        // V0-fix-11 修真 #4: IconLibrary.tab(_:) accessor (替代
        // V0-fix-4 Fix 5 iconName(for:) inline 映射)
        XCTAssertTrue(
            iconLib.contains("static func tab(_ kind: InspectorViewModel.Tab)"),
            "IconLibrary 必须有 tab(InspectorViewModel.Tab) accessor (V0-fix-11 修真 #4 — 替代 iconName(for:) inline 映射)"
        )
    }

    // MARK: - Fix I: LayoutShellView topLeft title-bar + "+" button

    /// 装机 user 8/10 15:35 OOB 真机拍 v0.02.0 LOOP 后 (worktree 不带
    /// v-fix-1 commit 1512a68d3, topLeftPanelWithTitleBar 没落地) —
    /// "新建项目区域的功能全消失了" + "顶部 '+ 新建项目' 按钮没了".
    ///
    /// V0-fix-2 Fix I 修法:
    ///   - LayoutShellView 加 `topLeftPanelWithTitleBar` private var
    ///   - 38pt HStack + Spacer + `Button(Image(systemName: "plus.circle.fill"))`
    ///   - `.help("新建项目")` tooltip 兜中文
    ///   - .topLeft 分支改用 `topLeftPanelWithTitleBar` (取代原 PlaceholderContent)
    ///
    /// 不动 5-zone geometry, 不动 splitter, 不动 PlaceholderContent (其他 3 panel 还用它).
    func testLayoutShellView_topLeftHeaderBar_hasPlusButton() throws {
        let rawSource = try repoFile(
            "Sources/WenshuApp/Views/Layout/LayoutShellView.swift"
        )
        let code = stripSwiftComments(rawSource)
        let iconLib = stripSwiftComments(try repoFile(
            "Sources/WenshuApp/Views/IconLibrary.swift"
        ))

        // V0-fix-11 修真 #1: + 按钮由 macOS title bar .toolbar
        // ToolbarItemGroup(.primaryAction) 接管 (修真 V0-fix-2 Fix I
        // topLeftPanelWithTitleBar + V0-fix-8 修真 #1 ToolbarItem
        // (.principal) — V0-fix-11 修真 #1 修真 3 个 ICON 修真群 + 修真
        // .principal → .primaryAction placement).
        XCTAssertTrue(
            code.contains("ToolbarItemGroup(placement: .primaryAction)"),
            "LayoutShellView 必须含 ToolbarItemGroup(placement: .primaryAction) (V0-fix-11 修真 #1 — macOS title bar 3 ICON 修真群, 红黄绿后紧跟)"
        )

        // V0-fix-11 修真 #2: topLeftHeaderBar 修真 38pt → 28pt (FCP Viewer 修真)
        XCTAssertTrue(
            code.contains(".frame(height: 28)"),
            "LayoutShellView topLeftHeaderBar 必须含 .frame(height: 28) (V0-fix-11 修真 #2 — FCP Viewer 顶部 toolbar 修真)"
        )

        // V0-fix-11 修真 #1: newProject SF Symbol 修真修真 <plus> (修真 V0-fix-8 plus.circle.fill)
        XCTAssertTrue(
            iconLib.contains(#""plus""#),
            "IconLibrary Action.newProject 必须含 SF Symbol 'plus' (V0-fix-11 修真 #1 — FCP Viewer 修真 + ICON)"
        )

        // .help("新建项目 (⌘N)") tooltip 兜中文
        XCTAssertTrue(
            code.contains(".help(\"新建项目"),
            "LayoutShellView + 按钮必须含 .help(\"新建项目...\") tooltip (V0-fix-11 修真 #1 — 兜中文)"
        )
    }

    // MARK: - Fix J: ProjectListView 5 tab 列表重写

    /// 装机 user 8/10 15:35 OOB 真机拍 (worktree 不带 v0.02.0 LT-03 v2
    /// commit 3fab4fadc) — "两次不符合规则" (AIF 推论 = 左上 5 tab 列表消失).
    ///
    /// V0-fix-2 Fix J 修法 (沿用 LT-03 v2 设计, 派单 §0.4 第 6 条拍板
    /// 改写 ProjectListView, 不新建 ProjectManagement/ 目录):
    ///   - 新增 `ProjectManagementTab` enum (case 5)
    ///   - 5 SF Symbol: folder / list.bullet.rectangle /
    ///     slider.horizontal.3 / books.vertical / rectangle.split.3x1
    ///   - 5 个 tab 字面量 (项目 / 章节 / 设定 / 资料 / 看板)
    ///   - Picker.segmented (5 tab 用文字标签, 不走 .iconOnly)
    ///   - **删**原 .toolbar { Button("新建项目", ...) } (跟 Fix I
    ///     title-bar + 按钮重复, §0.4 第 7 条合并为 1 个)
    func testProjectListView_5tabList_present() throws {
        let rawSource = try repoFile(
            "Sources/WenshuApp/Views/ProjectListView.swift"
        )
        let code = stripSwiftComments(rawSource)

        // 5 个 tab 字面量必须都在 source 里 (case rawValue)
        XCTAssertTrue(
            code.contains("\"项目\""),
            "ProjectListView 必须含 '项目' tab 字面量 (V0-fix-2 Fix J — 5 tab 容器)"
        )
        XCTAssertTrue(
            code.contains("\"章节\""),
            "ProjectListView 必须含 '章节' tab 字面量 (V0-fix-2 Fix J — 5 tab 容器)"
        )
        XCTAssertTrue(
            code.contains("\"设定\""),
            "ProjectListView 必须含 '设定' tab 字面量 (V0-fix-2 Fix J — 5 tab 容器)"
        )
        XCTAssertTrue(
            code.contains("\"资料\""),
            "ProjectListView 必须含 '资料' tab 字面量 (V0-fix-2 Fix J — 5 tab 容器)"
        )
        XCTAssertTrue(
            code.contains("\"看板\""),
            "ProjectListView 必须含 '看板' tab 字面量 (V0-fix-2 Fix J — 5 tab 容器)"
        )

        // ProjectManagementTab enum 必须存在
        XCTAssertTrue(
            code.contains("ProjectManagementTab"),
            "ProjectListView 必须含 ProjectManagementTab enum (V0-fix-2 Fix J — 沿用 LT-03 v2)"
        )

        // 5 SF Symbol (V0-fix-8 修真 #2 沿 AIF 16:20 截图重定义真值)
        XCTAssertTrue(
            code.contains("\"folder\""),
            "ProjectListView 必须含 SF Symbol 'folder' (V0-fix-8 修真 #2 — AIF 16:20 项目 tab)"
        )
        XCTAssertTrue(
            code.contains("\"doc.text\""),
            "ProjectListView 必须含 SF Symbol 'doc.text' (V0-fix-8 修真 #2 — AIF 16:20 章节 tab)"
        )
        XCTAssertTrue(
            code.contains("\"gearshape\""),
            "ProjectListView 必须含 SF Symbol 'gearshape' (V0-fix-8 修真 #2 — AIF 16:20 设定 tab)"
        )
        XCTAssertTrue(
            code.contains("\"archive\""),
            "ProjectListView 必须含 SF Symbol 'archive' (V0-fix-8 修真 #2 — AIF 16:20 资料 tab)"
        )
        XCTAssertTrue(
            code.contains("\"square.grid.3x3\""),
            "ProjectListView 必须含 SF Symbol 'square.grid.3x3' (V0-fix-8 修真 #2 — AIF 16:20 看板 tab)"
        )

        // V0-fix-2 字面量修真后不应再出现 (AIF 16:20 替换)
        XCTAssertFalse(
            code.contains("\"list.bullet.rectangle\""),
            "ProjectListView 不应再用 SF Symbol 'list.bullet.rectangle' (V0-fix-8 修真 #2 — AIF 16:20 替换为 doc.text)"
        )
        XCTAssertFalse(
            code.contains("\"slider.horizontal.3\""),
            "ProjectListView 不应再用 SF Symbol 'slider.horizontal.3' (V0-fix-8 修真 #2 — AIF 16:20 替换为 gearshape)"
        )
        XCTAssertFalse(
            code.contains("\"books.vertical\""),
            "ProjectListView 不应再用 SF Symbol 'books.vertical' (V0-fix-8 修真 #2 — AIF 16:20 替换为 archive)"
        )
        XCTAssertFalse(
            code.contains("\"rectangle.split.3x1\""),
            "ProjectListView 不应再用 SF Symbol 'rectangle.split.3x1' (V0-fix-8 修真 #2 — AIF 16:20 替换为 square.grid.3x3)"
        )

        // V0-fix-5 Fix E + V0-fix-8 修真 #2: Picker 修真后不在 ProjectListView
        // (5 tab Picker 升 LayoutShellView.topLeftHeaderBar)
        XCTAssertFalse(
            code.contains(".pickerStyle(.segmented)"),
            "ProjectListView 不应再有 .pickerStyle(.segmented) (V0-fix-5 Fix E — 整段 Picker 已搬到 LayoutShellView header bar)"
        )
    }
}