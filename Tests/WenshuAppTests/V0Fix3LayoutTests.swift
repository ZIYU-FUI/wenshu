// V0Fix3LayoutTests.swift · 文枢 (Wenshu) · v0.03.0 V0-fix-3 (Fix G/H/I/J 6 BUG + P11 防回退)
//
// 装机 user 8/10 15:30 + 15:35 OOB 实机拍 V0-fix-1 (commit 1512a68d3) +
// v0.02.0 LT-03 v2 (commit 3fab4fadc) 漏修的 UI BUG 第三波回归测试。 本
// 卡在 V0Fix2 已有 4 个 test 的基础上, 加 7 个 test 强化覆盖率, 含 P11
// 防回退验证 (Fix A 沿用保护)。
//
// 拍板背景 (装机 user 8/10 15:30 + 15:55 OOB):
//   Fix G (BUG 4): ChatPanelView Picker ".segmented" 改 ".iconOnly" + 真删
//                 Picker a11y "聊天区视图" H1 残留 (跟 V0-fix-1 Fix B 同形态).
//   Fix H (BUG 5+6): InspectorView Picker 改 ICON-only + 删 selfHeader H1
//                 "检视" + 加 iconName(for:) inline 静态映射 (伏笔 = eye /
//                 修订 = pencil.and.list.clipboard).
//   Fix I (BUG 1 沿用): LayoutShellView `topLeftPanelWithTitleBar` 38pt +.
//                 .help("新建项目") 必须保持 (P11 沿用保护, 装机 user 15:55
//                 反馈 "做完的东西被改没了" 沿用).
//   Fix J (BUG 2): ProjectListView 重写 5 tab 容器 (ProjectManagementTab
//                 enum + 5 SF Symbol + Picker(.segmented) 5 tab 文字标签) +
//                 **删** 原 .toolbar { Button("新建项目", ...) } (跟 Fix I
//                 title-bar + 按钮重复, §0.4 第 7 条合并为 1 个).
//
// 覆盖 (7 个 test):
//   - testProjectListView_5tabList_present       (Fix J — 5 tab 内容)
//   - testProjectListView_noToolbarPlusButton    (Fix J — 删原 toolbar + 按钮)
//   - testChatPanelView_chatPicker_iconOnly      (BUG 4 — Fix G .iconOnly)
//   - testChatPanelView_noChatPanelH1            (BUG 3 — Fix B 沿用 H1 删)
//   - testInspectorView_inspectorPicker_iconOnly (BUG 6 — Fix H .iconOnly)
//   - testInspectorView_noJianShiH1              (BUG 5 — Fix H selfHeader 删)
//   - testLayoutShellView_topLeftPanel_protected (P11 — Fix A 沿用保护, 装机 user 15:55 OOB 反馈)

import XCTest
@testable import WenshuApp

final class V0Fix3LayoutTests: XCTestCase {

    // MARK: - Helpers (从 V0Fix1LayoutTests 复制, XCTest 不跨文件共享 private func)

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

    // MARK: - Fix J (Part 1): ProjectListView 5 tab 容器

    /// 装机 user 8/10 15:35 OOB 实机拍 (worktree 不带 v0.02.0 LT-03 v2
    /// commit 3fab4fadc) — "两次不符合规则" (AIF 推论 = 左上 5 tab 列表消失).
    ///
    /// V0-fix-3 Fix J 修法 (沿用 LT-03 v2 设计, 派单 §0.4 第 6 条拍板
    /// 改写 ProjectListView, 不新建 ProjectManagement/ 目录):
    ///   - 新增 `ProjectManagementTab` enum (case 5: projects / chapters /
    ///     settings / resources / kanban)
    ///   - 5 SF Symbol: folder / list.bullet.rectangle /
    ///     slider.horizontal.3 / books.vertical / rectangle.split.3x1
    ///     (V0-fix-4 + V0-fix-5 沿用)
    ///   - 5 个 tab 字面量 (项目 / 章节 / 设定 / 资料 / 看板)
    ///   - Picker.segmented (5 tab 用文字标签, 不走 .iconOnly — 跟 chat /
    ///     inspector tab 风格刻意区分)
    ///
    /// V0-fix-8 (装机 user 8/11 16:20 真机拍红字 "5 tab 改文字按钮为
    /// ICON" + "所有 ICON 按钮, 只保留 ICON, 不要矩形背景, 仿 FCP"):
    ///   - 5 SF Symbol 修真 AIF 16:20 截图重定义真值: folder / doc.text /
    ///     gearshape / archive / square.grid.3x3 (替换 V0-fix-3 字面量)
    ///   - Picker 整段已迁 LayoutShellView.topLeftHeaderBar (沿 V0-fix-5),
    ///     ProjectListView 不再含 Picker (仅保留 enum + 5 SF Symbol 字面量)
    func testProjectListView_5tabList_present() throws {
        let rawSource = try repoFile(
            "Sources/WenshuApp/Views/ProjectListView.swift"
        )
        let code = stripSwiftComments(rawSource)
        let iconLibCode = stripSwiftComments(try repoFile(
            "Sources/WenshuApp/Views/Components/IconButton.swift"
        ))

        // 5 tab 字面量 (沿用 V0-fix-3 Fix J)
        XCTAssertTrue(code.contains("\"项目\""),  "ProjectListView 必须含 '项目' tab 字面量 (V0-fix-3 Fix J)")
        XCTAssertTrue(code.contains("\"章节\""),  "ProjectListView 必须含 '章节' tab 字面量 (V0-fix-3 Fix J)")
        XCTAssertTrue(code.contains("\"设定\""),  "ProjectListView 必须含 '设定' tab 字面量 (V0-fix-3 Fix J)")
        XCTAssertTrue(code.contains("\"资料\""),  "ProjectListView 必须含 '资料' tab 字面量 (V0-fix-3 Fix J)")
        XCTAssertTrue(code.contains("\"看板\""),  "ProjectListView 必须含 '看板' tab 字面量 (V0-fix-3 Fix J)")

        // ProjectManagementTab enum
        XCTAssertTrue(code.contains("ProjectManagementTab"), "ProjectListView 必须含 ProjectManagementTab enum (V0-fix-3 Fix J)")

        // 5 SF Symbol (V0-fix-8 修真 #2 沿 AIF 16:20 截图重定义真值)
        XCTAssertTrue(code.contains("\"folder\""),          "ProjectListView 必须含 SF Symbol 'folder' (V0-fix-8 修真 #2 — AIF 16:20 项目 tab)")
        XCTAssertTrue(code.contains("\"doc.text\""),        "ProjectListView 必须含 SF Symbol 'doc.text' (V0-fix-8 修真 #2 — AIF 16:20 章节 tab)")
        XCTAssertTrue(code.contains("\"gearshape\""),       "ProjectListView 必须含 SF Symbol 'gearshape' (V0-fix-8 修真 #2 — AIF 16:20 设定 tab)")
        XCTAssertTrue(code.contains("\"archive\""),         "ProjectListView 必须含 SF Symbol 'archive' (V0-fix-8 修真 #2 — AIF 16:20 资料 tab)")
        XCTAssertTrue(code.contains("\"square.grid.3x3\""),  "ProjectListView 必须含 SF Symbol 'square.grid.3x3' (V0-fix-8 修真 #2 — AIF 16:20 看板 tab)")

        // V0-fix-3 字面量修真后不应再出现 (AIF 16:20 替换)
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

        // Picker 修真后不在 ProjectListView (沿 V0-fix-5 — 5 tab Picker
        // 升 LayoutShellView.topLeftHeaderBar, ProjectListView 仅保留 enum
        // + SF Symbol 字面量)
        XCTAssertFalse(
            code.contains(".pickerStyle(.segmented)"),
            "ProjectListView 不应再有 .pickerStyle(.segmented) (V0-fix-5 Fix E — 整段 Picker 已搬到 LayoutShellView header bar)"
        )
    }

    // MARK: - Fix J (Part 2): 删原 .toolbar + 按钮 (跟 Fix I title-bar 合并)

    /// V0-fix-3 Fix J 派单 §0.4 第 7 条拍板: 顶部 '+ 新建项目' 按钮只
    /// 保留 1 个 (= Fix I LayoutShellView `topLeftPanelWithTitleBar`), Tab 1
    /// 内的 `.toolbar { ToolbarItem(.primaryAction) { Button ... } }` 必须
    /// 删除, 避免 2 个 '+ 按钮' 视觉冗余 (FCP 范式 = 单 + 入口)。
    ///
    /// 跟 P11 防回退 (顶部 + 按钮由 LayoutShellView 接管) 对齐.
    func testProjectListView_noToolbarPlusButton() throws {
        let rawSource = try repoFile(
            "Sources/WenshuApp/Views/ProjectListView.swift"
        )
        let code = stripSwiftComments(rawSource)

        // strip 注释后, `.toolbar { ToolbarItem(placement: .primaryAction)` 整块必须消失
        XCTAssertFalse(
            code.contains("ToolbarItem(placement: .primaryAction)"),
            "ProjectListView 不应再用 .toolbar { ToolbarItem(placement: .primaryAction) } 这个 + 新建项目按钮 (V0-fix-3 Fix J — 跟 Fix I title-bar 合并为 1 个, 避免冗余)"
        )
    }

    // MARK: - Fix G (BUG 4): ChatPanelView 修真 #3 Picker → HStack+Button

    /// V0-fix-3 Fix G 历史: Picker `.segmented` → `.pickerStyle(.iconOnly)`
    /// (走 PickerStyle+IconOnly alias, macOS 14+ SegmentedPickerStyle 配
    /// 合 Image-only content 自动隐藏文字标签)。
    ///
    /// V0-fix-8 (装机 user 8/11 16:20 真机拍红字 "所有 ICON 按钮, 只保留
    /// ICON, 不要矩形背景, 仿 FCP"): 修真 #3 — `.pickerStyle(.iconOnly)`
    /// (走 SegmentedPickerStyle) 仍有 macOS 系统矩形分段框背景, 不符
    /// 红字"不要矩形背景"。 真修真: Picker 整段迁 HStack + 4 Button
    /// (Image) + `.buttonStyle(.plain)`, 纯 ICON 无矩形背景, 对齐 FCP
    /// timeline 范式。本测试沿 V0-fix-8 修真更新断言 (Pick Picker → Button
    /// 形态), 历史 `.pickerStyle(.iconOnly)` 字面量不再出现。
    func testChatPanelView_chatPicker_iconOnly() throws {
        let rawSource = try repoFile(
            "Sources/WenshuApp/Views/Chat/ChatPanelView.swift"
        )
        let code = stripSwiftComments(rawSource)
        let iconLibCode = stripSwiftComments(try repoFile(
            "Sources/WenshuApp/Views/Components/IconButton.swift"
        ))

        // V0-fix-8 修真 #3: 4 chat tab 修真后是 HStack + Button(Image)
        // + .buttonStyle(.plain) — 替代 Picker(.iconOnly), 修真矩形分段框
        XCTAssertTrue(
            code.contains("activeTab = tab"),
            "ChatPanelView 必须有 Button { activeTab = tab } 修真 4 chat tab (V0-fix-8 修真 #3 — HStack+Button 替代 Picker)"
        )
        // V0-fix-11 修真 #5 / #6: .buttonStyle(.plain) 修真 IconButton
        // 组件 (Sources/WenshuApp/Views/Components/IconButton.swift) 内部,
        // View 修真文件不直接含 .buttonStyle(.plain) 字面量.
        XCTAssertTrue(
            iconLibCode.contains(".buttonStyle(.plain)"),
            "ChatPanelView 必须用 .buttonStyle(.plain) (V0-fix-8 修真 #3 — 红字不要矩形背景, 仿 FCP) — IconButton 内部 (V0-fix-11 修真 #5/#6 全局 ICON 按钮组件)"
        )

        // V0-fix-8 修真 #3: 不应再有 Picker / .pickerStyle 字面量
        XCTAssertFalse(
            code.contains(".pickerStyle(.iconOnly)"),
            "ChatPanelView 不应再有 .pickerStyle(.iconOnly) (V0-fix-8 修真 #3 — 改 HStack+Button 去矩形分段框)"
        )
        XCTAssertFalse(
            code.contains(".pickerStyle(.segmented)"),
            "ChatPanelView 不应再用 .pickerStyle(.segmented) (V0-fix-8 修真 #3 — 改 HStack+Button)"
        )

        // 兜底: Button 块走 Image(systemName:) 渲染 (沿 V0-fix-3 Fix G
        // ICON-only 契约, 修真后形态仍保留)
        XCTAssertTrue(
            code.contains("Image(systemName:"),
            "ChatPanelView Button 块必须用 Image(systemName:) 渲染 tab (V0-fix-3 Fix G + V0-fix-8 修真 #3 ICON-only 契约)"
        )
    }

    // MARK: - Fix B (BUG 3): ChatPanelView "聊天区视图" H1 真删

    /// V0-fix-1 Fix B + V0-fix-3 (Fix G) 沿用: Picker a11y 字符串标签
    /// "聊天区视图" 必须从源里消失 (= 原 H1 残留, 改 Picker(""))。
    /// 装机 user 8/10 15:30 实机拍 V0-fix-1 后仍不符 — 真根因是 V0-fix-1
    /// worktree 不在本卡 worktree, 必须从 0 改.
    func testChatPanelView_noChatPanelH1() throws {
        let rawSource = try repoFile(
            "Sources/WenshuApp/Views/Chat/ChatPanelView.swift"
        )
        let code = stripSwiftComments(rawSource)

        // "聊天区视图" 在活动代码里必须不存在 (Picker a11y 字串已删,
        // 注释里可能还提到, strip 后消除)
        XCTAssertFalse(
            code.contains("Text(\"聊天区视图\")"),
            "ChatPanelView 活动代码不能含 Text(\"聊天区视图\") (V0-fix-1 Fix B + V0-fix-3 Fix G — H1 真删)"
        )
        XCTAssertFalse(
            code.contains("Picker(\"聊天区视图\""),
            "ChatPanelView Picker a11y 字符串标签不应再含 '聊天区视图' (V0-fix-1 Fix B + V0-fix-3 Fix G — Picker a11y 改 \"\")"
        )
    }

    // MARK: - Fix H (BUG 6): InspectorView Picker 改 .iconOnly

    /// V0-fix-1 完全没动 InspectorView, V0-fix-3 Fix H 修法:
    ///   - `.pickerStyle(.segmented)` → `.pickerStyle(.iconOnly)` (强制 ICON-only)
    ///   - `Text(tab.title).tag(tab)` → `Image(systemName: iconName(for:)).tag(tab).help(tab.title)`
    ///   - 2 SF Symbol: eye (伏笔) / pencil.and.list.clipboard (修订)
    ///   - Picker a11y "检视" → ""
    func testInspectorView_inspectorPicker_iconOnly() throws {
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
        // V0-fix-3 Fix H Picker(.iconOnly) + V0-fix-4 Fix 5 +
        // V0-fix-10.1 修真 #5 衍生). IconButton 自修真 .buttonStyle(.plain).
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

        // 2 SF Symbol 必须都在 IconLibrary 里 (Inspector.Tab.Inspector 真值)
        XCTAssertTrue(iconLib.contains("\"eye\""),                       "IconLibrary 必须含 SF Symbol 'eye' (V0-fix-11 — Inspector.Tab.Inspector.foreshadow)")
        XCTAssertTrue(iconLib.contains("pencil.and.list.clipboard"),     "IconLibrary 必须含 SF Symbol 'pencil.and.list.clipboard' (V0-fix-11 — Inspector.Tab.Inspector.revision)")
    }

    // MARK: - Fix H (BUG 5): InspectorView "检视" H1 真删

    /// V0-fix-3 Fix H: 删 InspectorView 顶部 `selfHeader` private var
    /// (= 原 H1 self-identity "检视" + sidebar.right Image 整段, 跟
    /// V0-fix-1 ChatPanelView Fix B 同策略). strip 注释后, `selfHeader`
    /// 标识符必须从源里消失 (= 整段 private var 已删 + body 内 selfHeader()
    /// 调用也删了).
    func testInspectorView_noJianShiH1() throws {
        let rawSource = try repoFile(
            "Sources/WenshuApp/Views/Inspector/InspectorView.swift"
        )
        let code = stripSwiftComments(rawSource)

        // "检视" 字符串在活动代码里必须不存在 (= selfHeader H1 真删)
        XCTAssertFalse(
            code.contains("Text(\"检视\")"),
            "InspectorView 活动代码不能含 Text(\"检视\") (V0-fix-3 Fix H — selfHeader H1 真删)"
        )

        // selfHeader private var + body 调用必须消失
        XCTAssertFalse(
            code.contains("selfHeader"),
            "InspectorView 不应再有 selfHeader private var 引用 (V0-fix-3 Fix H — 整段 H1 + body 调用都删除)"
        )
    }

    // MARK: - P11 防回退 (Fix I 沿用保护): 装机 user 8/10 15:55 OOB 反馈

    /// 装机 user 8/10 15:55 OOB 反馈 "做完的东西被改没了" — 派单拍
    /// P11 防回退, V0-fix-3 必须保住 V0-fix-1 Fix A 已修的 4 元素:
    ///   - topLeftPanelWithTitleBar private var (38pt HStack + plus.circle.fill)
    ///   - .help("新建项目") tooltip 兜中文
    ///   - panel(.topLeft) 分支仍用 topLeftPanelWithTitleBar
    ///   - 不破坏 5-zone geometry (LayoutShellView 整体结构不变)
    func testLayoutShellView_topLeftPanel_protected() throws {
        let rawSource = try repoFile(
            "Sources/WenshuApp/Views/Layout/LayoutShellView.swift"
        )
        let code = stripSwiftComments(rawSource)
        let iconLib = stripSwiftComments(try repoFile(
            "Sources/WenshuApp/Views/IconLibrary.swift"
        ))

        // V0-fix-11 修真 #1: + 按钮由 macOS title bar .toolbar
        // ToolbarItemGroup(.primaryAction) 接管 (修真 V0-fix-1 Fix A
        // topLeftPanelWithTitleBar + V0-fix-8 修真 #1 ToolbarItem
        // (.principal)). 修真 3 个 ICON 修真群 (新建 / 打开 / 导入占位).
        XCTAssertTrue(
            code.contains("ToolbarItemGroup(placement: .primaryAction)"),
            "LayoutShellView 必须含 ToolbarItemGroup(placement: .primaryAction) (V0-fix-11 修真 #1 — macOS title bar 3 ICON 修真群)"
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

        // .help("新建项目 (⌘N)") tooltip 兜中文 (V0-fix-1 Fix A 拍板沿用)
        XCTAssertTrue(
            code.contains(".help(\"新建项目"),
            "LayoutShellView + 按钮必须含 .help(\"新建项目...\") tooltip (V0-fix-11 修真 #1 — 兜中文)"
        )
    }
}
