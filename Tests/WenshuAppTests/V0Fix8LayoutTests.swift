// V0Fix8LayoutTests.swift · 文枢 (Wenshu) · v0.03.0 V0-fix-8
//
// 装机 user 8/11 16:20 真机拍 4 红字批注 + AIF 16:20 截图重定义真值
// 回归测试 — 沿 V0FixNLayoutTests 的"源码静态扫描 + 字面量断言"模式
// (SwiftPM-only binary AX tree 抓不到, 我们的真值就是 source 里"有这
// 个 / 没这个")。
//
// 覆盖 (8 个 test, 修真 4 处 UI BUG):
//   - testApp_noWenshuInWindowGroup            (修真 #1: 删 WindowGroup "文枢")
//   - testApp_hasToolbarItemWithPlusButton     (修真 #1: + 按钮进 macOS title bar)
//   - testLayoutShellView_topLeftHeaderBar_5tabUsesImageSymbol (修真 #2: 5 tab ICON)
//   - testLayoutShellView_topLeftHeaderBar_5tabIsButton       (修真 #2: HStack+Button)
//   - testLayoutShellView_topLeftHeaderBar_noPlusButton       (修真 #4 衍生)
//   - testChatPanelView_chat4TabIsButton       (修真 #3: chat 4 tab 去矩形)
//   - testProjectManagementTab_symbolName_AFspecified         (修真 #2: 5 SF Symbol AIF 指定)
//   - testProjectManagementTab_isEnabled_3Disabled            (修真 #2: 3 disabled)
//
// 拍板背景 (装机 user 8/11 16:20 真机拍 4 红字批注 + AIF 16:20 截图重定义真值):
//   修真 #1: macOS 顶部 "文枢" 两字删, + 按钮放这里替代 (FCP 范式)
//   修真 #2: 5 tab 改文字按钮为 ICON (folder / doc.text / gearshape /
//            archive / square.grid.3x3)
//   修真 #3: 所有 ICON 按钮只保留 ICON, 不要矩形背景, 仿 FCP
//   修真 #4 衍生: 去掉引行的 + 按钮 (修真 #1 后避免双 + 入口)

import XCTest
@testable import WenshuApp

final class V0Fix8LayoutTests: XCTestCase {

    // MARK: - Helpers (从 V0Fix1/2/3/4LayoutTests 复制, helper 完全相同)

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

    // MARK: - 修真 #1: App.swift WindowGroup 删 "文枢" 字面量

    /// 装机 user 8/11 16:20 真机拍 "新建按钮放在这里, 替换文枢文字":
    ///   - App.swift 不应再有 `WindowGroup("文枢")` 字面量
    ///   - 必须用 `WindowGroup { ... }` (删 title 字面量, 让 macOS
    ///     title bar 不显"文枢"两字)
    ///   - + 按钮由 LayoutShellView NavigationStack 顶层 .toolbar
    ///     ToolbarItem(.principal) 接管 (FCP 范式 单 + 入口)
    func testApp_noWenshuInWindowGroup() throws {
        let rawSource = try repoFile("Sources/WenshuApp/App.swift")
        let code = stripSwiftComments(rawSource)
        let iconLibCode = stripSwiftComments(try repoFile(
            "Sources/WenshuApp/Views/Components/IconButton.swift"
        ))

        XCTAssertFalse(
            code.contains(#"WindowGroup("文枢")"#),
            "App.swift 不应再有 WindowGroup(\"文枢\") 字面量 (V0-fix-8 修真 #1 — macOS title bar 不显文枢两字)"
        )
        XCTAssertTrue(
            code.contains("WindowGroup {"),
            "App.swift 必须用 WindowGroup { ... } (V0-fix-8 修真 #1 — 删 title 字面量)"
        )
    }

    // MARK: - 修真 #1: LayoutShellView NavigationStack 顶层 .toolbar + 按钮

    /// 装机 user 8/11 16:20 真机拍红字: 新建按钮放这里 (macOS title bar
    /// 替代"文枢"文字):
    ///   - LayoutShellView NavigationStack 顶层必须有 .toolbar
    ///   - 内部用 ToolbarItem(placement: .principal) (macOS title bar 中央)
    ///   - Button 调 navPath.append(AppRoute.createProject) (push 路由,
    ///     沿 LT-N1-merge 拍板 push 优先 sheet)
    ///   - Image(systemName: "plus.circle.fill") (沿 V0-fix-4 Fix 1 SF Symbol)
    ///   - .help("新建项目") tooltip (沿 V0-fix-4 Fix 1 中文兜底)
    func testApp_hasToolbarItemWithPlusButton() throws {
        let rawSource = try repoFile(
            "Sources/WenshuApp/Views/Layout/LayoutShellView.swift"
        )
        let code = stripSwiftComments(rawSource)
        let iconLib = stripSwiftComments(try repoFile(
            "Sources/WenshuApp/Views/IconLibrary.swift"
        ))

        XCTAssertTrue(
            code.contains(".toolbar {"),
            "LayoutShellView NavigationStack 顶层必须有 .toolbar (V0-fix-8 修真 #1 + V0-fix-11 修真 #1 — + 按钮进 macOS title bar)"
        )
        // V0-fix-11 修真 #1: ToolbarItem(placement: .principal) 修真 ToolbarItemGroup(placement: .primaryAction)
        XCTAssertTrue(
            code.contains("ToolbarItemGroup(placement: .primaryAction)"),
            "LayoutShellView 必须有 ToolbarItemGroup(placement: .primaryAction) (V0-fix-11 修真 #1 — 3 ICON 修真群, macOS title bar 红黄绿后)"
        )
        XCTAssertFalse(
            code.contains("ToolbarItem(placement: .principal)"),
            "LayoutShellView 不应再有 ToolbarItem(placement: .principal) (V0-fix-11 修真 #1 — 修真 .primaryAction + ToolbarItemGroup)"
        )

        // V0-fix-6 Fix 1 (B5-装): + 按钮改 sheet 弹窗 (showCreateProject = true),
        // 修真 navPath.append(AppRoute.createProject)
        XCTAssertTrue(
            code.contains("showCreateProject = true"),
            "LayoutShellView + 按钮 action 必须调 showCreateProject = true (V0-fix-6 Fix 1 — 改 sheet 弹窗不 push, 装机 user 17:35 OOB)"
        )
        XCTAssertFalse(
            code.contains("navPath.append(AppRoute.createProject)"),
            "LayoutShellView + 按钮 action 不应再调 navPath.append(AppRoute.createProject) (V0-fix-6 Fix 1 — 改 sheet 不 push)"
        )

        // V0-fix-11 修真 #1: newProject SF Symbol 修真修真 <plus> (修真 V0-fix-8 plus.circle.fill)
        XCTAssertTrue(
            iconLib.contains(#""plus""#),
            "IconLibrary Action.newProject 必须含 SF Symbol 'plus' (V0-fix-11 修真 #1 — FCP Viewer 修真 + ICON)"
        )

        XCTAssertTrue(
            code.contains(#".help("新建项目"#),
            "LayoutShellView + 按钮必须有 .help(\"新建项目...\") tooltip (V0-fix-8 修真 #1 + V0-fix-11 修真 #1 — 沿 V0-fix-4 Fix 1 中文兜底)"
        )
    }

    // MARK: - 修真 #2: LayoutShellView.topLeftHeaderBar 5 tab 改 ICON

    /// 装机 user 8/11 16:20 真机拍红字: 5 tab 改文字按钮为 ICON:
    ///   - LayoutShellView 必须调 Image(systemName: tab.symbolName) 渲染 5 tab
    ///   - 修真后 Picker.segmented 整段不在 LayoutShellView (修真 #2 替代)
    func testLayoutShellView_topLeftHeaderBar_5tabUsesImageSymbol() throws {
        let rawSource = try repoFile(
            "Sources/WenshuApp/Views/Layout/LayoutShellView.swift"
        )
        let code = stripSwiftComments(rawSource)

        // V0-fix-11 修真 #2: 5 tab 修真 IconButton + IconLibrary.tab(tab)
        // (修真 V0-fix-8 修真 #2 Image(systemName: tab.symbolName) +
        // V0-fix-10.1 修真 #3 衍生).
        XCTAssertTrue(
            code.contains("IconButton("),
            "LayoutShellView header bar 必须用 IconButton( 组件 (V0-fix-11 修真 #2 — 全局 ICON 按钮组件)"
        )
        XCTAssertTrue(
            code.contains("IconLibrary.tab(tab)"),
            "LayoutShellView header bar 必须用 IconLibrary.tab(tab) 修真 5 tab SF Symbol (V0-fix-11 修真 #2 + V0-fix-10.1 修真 #3 — IconLibrary 修真)"
        )
        XCTAssertFalse(
            code.contains("Image(systemName: tab.symbolName)"),
            "LayoutShellView header bar 不应再用 Image(systemName: tab.symbolName) (V0-fix-11 修真 #2 — IconLibrary.tab(tab) 修真)"
        )

        // Picker.segmented 不应在 header bar (修真 #2 + 红字"不要矩形背景"
        // 共同衍生 — SegmentedPickerStyle 仍有矩形分段框)
        XCTAssertFalse(
            code.contains(".pickerStyle(.segmented)"),
            "LayoutShellView header bar 不应再有 .pickerStyle(.segmented) (V0-fix-8 修真 #2 — 改 HStack+Button, 去矩形分段框)"
        )
        XCTAssertFalse(
            code.contains(#"Text(tab.rawValue).tag(tab)"#),
            "LayoutShellView header bar 不应再用 Text(tab.rawValue).tag(tab) (V0-fix-8 修真 #2 — 改 Image SF Symbol)"
        )
    }

    // MARK: - 修真 #2: LayoutShellView.topLeftHeaderBar 5 tab 是 Button

    /// 装机 user 8/11 16:20 真机拍红字: 5 tab 改文字按钮为 ICON +
    /// 红字"所有 ICON 按钮, 只保留 ICON, 不要矩形背景, 仿 FCP":
    ///   - LayoutShellView 必须有 Button { activeTab = tab } 修真 5 tab
    ///   - 修真后 Button 用 .buttonStyle(.plain) (无矩形背景, FCP 范式)
    ///   - 修真后 5 tab 不再有 Picker / .pickerStyle
    func testLayoutShellView_topLeftHeaderBar_5tabIsButton() throws {
        let rawSource = try repoFile(
            "Sources/WenshuApp/Views/Layout/LayoutShellView.swift"
        )
        let code = stripSwiftComments(rawSource)

        XCTAssertTrue(
            code.contains("activeTab = tab"),
            "LayoutShellView header bar 必须有 Button { activeTab = tab } 修真 5 tab (V0-fix-8 修真 #2 — HStack+Button 替代 Picker)"
        )
        XCTAssertTrue(
            code.contains(".buttonStyle(.plain)"),
            "LayoutShellView header bar 必须用 .buttonStyle(.plain) (V0-fix-8 修真 #2 — 红字不要矩形背景, 仿 FCP)"
        )

        // 修真后 5 tab 不是 Picker — 修真 #2 替代
        XCTAssertFalse(
            code.contains("Picker(\"\", selection: $activeTab)"),
            "LayoutShellView header bar 不应再有 Picker(\"\", selection: $activeTab) (V0-fix-8 修真 #2 — 改 HStack+Button)"
        )
    }

    // MARK: - 修真 #4 衍生: LayoutShellView macOS title bar + 按钮接管

    /// 装机 user 8/11 16:20 真机拍红字: 去掉引行的新建按钮 (修真 #4
    /// 衍生 — 修真 #1 后 + 按钮已在 macOS title bar, 修真 #4 避免双
    /// + 入口, FCP 单 + 范式):
    ///   - LayoutShellView 必须有 ToolbarItem(placement: .principal) 修真
    ///     (macOS title bar 中央接管 + 按钮, FCP 单 + 入口范式)
    func testLayoutShellView_topLeftHeaderBar_noPlusButton() throws {
        let rawSource = try repoFile(
            "Sources/WenshuApp/Views/Layout/LayoutShellView.swift"
        )
        let code = stripSwiftComments(rawSource)

        // V0-fix-11 修真 #1: + 按钮已修真 macOS title bar, 由
        // ToolbarItemGroup(placement: .primaryAction) 接管 3 个 ICON
        // 修真群. (修真 V0-fix-8 修真 #4 衍生 ToolbarItem(placement: .principal))
        XCTAssertTrue(
            code.contains("ToolbarItemGroup(placement: .primaryAction)"),
            "LayoutShellView macOS title bar 必须由 ToolbarItemGroup(placement: .primaryAction) 接管 3 ICON 修真群 (V0-fix-11 修真 #1 — 修真 #4 衍生: FCP 单 + 入口 + 修真 .primaryAction)"
        )
        XCTAssertFalse(
            code.contains("ToolbarItem(placement: .principal)"),
            "LayoutShellView 不应再有 ToolbarItem(placement: .principal) (V0-fix-11 修真 #1 — 修真 .primaryAction)"
        )

        // V0-fix-11 修真 #2: topLeftHeaderBar 5 tab 用 IconButton 组件,
        // .disabled(isDisabled) 走 IconButton 内部.
        XCTAssertTrue(
            code.contains("IconButton(") && code.contains("isDisabled: !tab.isEnabled"),
            "LayoutShellView topLeftHeaderBar 5 tab 必须用 IconButton + isDisabled (V0-fix-11 修真 #2 — IconButton 修真 #4 衍生)"
        )
    }

    // MARK: - 修真 #3: ChatPanelView 4 chat tab 改 HStack+Button 去矩形

    /// 装机 user 8/11 16:20 真机拍红字: 所有 ICON 按钮, 只保留 ICON,
    /// 不要矩形背景, 仿 FCP (修真 #3 — ChatPanelView 4 chat tab):
    ///   - ChatPanelView 必须有 Button { activeTab = tab } 修真 4 chat tab
    ///   - 修真后 Button 用 .buttonStyle(.plain) (无矩形背景)
    ///   - 修真后 4 chat tab 不再有 Picker / .pickerStyle
    func testChatPanelView_chat4TabIsButton() throws {
        let rawSource = try repoFile(
            "Sources/WenshuApp/Views/Chat/ChatPanelView.swift"
        )
        let code = stripSwiftComments(rawSource)
        let iconLibCode = stripSwiftComments(try repoFile(
            "Sources/WenshuApp/Views/Components/IconButton.swift"
        ))

        // 修真后 4 chat tab 是 HStack + Button(Image)
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

        // 修真后 4 chat tab 不是 Picker — 修真 #3 替代
        XCTAssertFalse(
            code.contains(".pickerStyle(.iconOnly)"),
            "ChatPanelView 不应再有 .pickerStyle(.iconOnly) (V0-fix-8 修真 #3 — HStack+Button 去矩形分段框)"
        )
        XCTAssertFalse(
            code.contains(".pickerStyle(.segmented)"),
            "ChatPanelView 不应再有 .pickerStyle(.segmented) (V0-fix-8 修真 #3 — HStack+Button 去矩形分段框)"
        )
        XCTAssertFalse(
            code.contains("Picker(\"\", selection: $activeTab)"),
            "ChatPanelView 不应再有 Picker(\"\", selection: $activeTab) (V0-fix-8 修真 #3 — 改 HStack+Button)"
        )

        // 4 SF Symbol 必须都在 source 里 (沿 on-disk ChatPanelTab.symbolName
        // 真值 — AIF 未列新值, 不改)
        XCTAssertTrue(code.contains(#""bubble.left.and.bubble.right""#), "ChatPanelView 必须含 SF Symbol <bubble.left.and.bubble.right> (V0-fix-8 修真 #3 — 4 chat tab 图标)")
        XCTAssertTrue(code.contains(#""clock.arrow.circlepath""#),      "ChatPanelView 必须含 SF Symbol <clock.arrow.circlepath> (V0-fix-8 修真 #3 — 4 chat tab 图标)")
        XCTAssertTrue(code.contains(#""person.2""#),                    "ChatPanelView 必须含 SF Symbol <person.2> (V0-fix-8 修真 #3 — 4 chat tab 图标)")
        XCTAssertTrue(code.contains(#""list.bullet.indent""#),          "ChatPanelView 必须含 SF Symbol <list.bullet.indent> (V0-fix-8 修真 #3 — 4 chat tab 图标)")

        // V0-fix-6 内容区居中保留 (修真 #3 不动内容区居中)
        XCTAssertTrue(
            code.contains(".frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)"),
            "ChatPanelView tabContent 必须保留 .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center) (V0-fix-8 修真 #3 — V0-fix-6 内容居中保留)"
        )
    }

    // MARK: - 修真 #2: ProjectManagementTab.symbolName 5 SF Symbol AIF 16:20 指定

    /// 装机 user 8/11 16:20 真机拍 + AIF 16:20 截图重定义真值: 5 tab
    /// SF Symbol 必须按 AIF 截图指定:
    ///   - folder (项目) — V0-fix-4 沿用
    ///   - doc.text (章节) — 替换 list.bullet.rectangle
    ///   - gearshape (设定) — 替换 slider.horizontal.3
    ///   - archive (资料) — 替换 books.vertical
    ///   - square.grid.3x3 (看板) — 替换 rectangle.split.3x1
    func testProjectManagementTab_symbolName_AFspecified() throws {
        let rawSource = try repoFile(
            "Sources/WenshuApp/Views/ProjectListView.swift"
        )
        let code = stripSwiftComments(rawSource)

        // 5 SF Symbol (AIF 16:20 真值)
        XCTAssertTrue(code.contains(#""folder""#),              "ProjectListView 必须含 SF Symbol <folder> (V0-fix-8 修真 #2 — AIF 16:20 真值, 项目 tab)")
        XCTAssertTrue(code.contains(#""doc.text""#),            "ProjectListView 必须含 SF Symbol <doc.text> (V0-fix-8 修真 #2 — AIF 16:20 真值, 章节 tab)")
        XCTAssertTrue(code.contains(#""gearshape""#),           "ProjectListView 必须含 SF Symbol <gearshape> (V0-fix-8 修真 #2 — AIF 16:20 真值, 设定 tab)")
        XCTAssertTrue(code.contains(#""archive""#),             "ProjectListView 必须含 SF Symbol <archive> (V0-fix-8 修真 #2 — AIF 16:20 真值, 资料 tab)")
        XCTAssertTrue(code.contains(#""square.grid.3x3""#),     "ProjectListView 必须含 SF Symbol <square.grid.3x3> (V0-fix-8 修真 #2 — AIF 16:20 真值, 看板 tab)")

        // 修真前 4 个 V0-fix-4 字面量不应再出现 (AIF 16:20 重定义真值)
        XCTAssertFalse(
            code.contains(#""list.bullet.rectangle""#),
            "ProjectListView 不应再用 SF Symbol <list.bullet.rectangle> (V0-fix-8 修真 #2 — AIF 16:20 替换为 doc.text)"
        )
        XCTAssertFalse(
            code.contains(#""slider.horizontal.3""#),
            "ProjectListView 不应再用 SF Symbol <slider.horizontal.3> (V0-fix-8 修真 #2 — AIF 16:20 替换为 gearshape)"
        )
        XCTAssertFalse(
            code.contains(#""books.vertical""#),
            "ProjectListView 不应再用 SF Symbol <books.vertical> (V0-fix-8 修真 #2 — AIF 16:20 替换为 archive)"
        )
        XCTAssertFalse(
            code.contains(#""rectangle.split.3x1""#),
            "ProjectListView 不应再用 SF Symbol <rectangle.split.3x1> (V0-fix-8 修真 #2 — AIF 16:20 替换为 square.grid.3x3)"
        )
    }

    // MARK: - 修真 #2: ProjectManagementTab.isEnabled 3 disabled

    /// 装机 user 8/11 16:20 真机拍 + 修真 #2 派生: ProjectManagementTab
    /// 新增 isEnabled 衍生 — projects / chapters enabled, settings /
    /// resources / kanban disabled (沿 V0-fix-6 + ProjectBrowserView.
    /// ProjectTab.enabled 拍板, v0.04.0 / v0.05.0 才实装):
    ///   - enum 修真后必有 isEnabled: Bool 派生属性
    ///   - LayoutShellView topLeftHeaderBar 必须用 .disabled(!tab.isEnabled)
    func testProjectManagementTab_isEnabled_3Disabled() throws {
        let projectList = try stripSwiftComments(repoFile(
            "Sources/WenshuApp/Views/ProjectListView.swift"
        ))
        let layoutShell = try stripSwiftComments(repoFile(
            "Sources/WenshuApp/Views/Layout/LayoutShellView.swift"
        ))

        // isEnabled 派生属性必须存在 (修真 #2 新增)
        XCTAssertTrue(
            projectList.contains("var isEnabled: Bool"),
            "ProjectListView ProjectManagementTab 必须新增 isEnabled: Bool 派生 (V0-fix-8 修真 #2 — 沿 V0-fix-6 拍板)"
        )

        // 修真 #2 真值: projects + chapters = true, settings + resources
        // + kanban = false (用 enum 上下文字面量验证)
        XCTAssertTrue(
            projectList.contains("case .projects, .chapters: return true"),
            "ProjectListView ProjectManagementTab.isEnabled projects + chapters 必须 = true (V0-fix-8 修真 #2 — v0.02.0 已实装)"
        )
        XCTAssertTrue(
            projectList.contains("case .settings, .resources, .kanban: return false"),
            "ProjectListView ProjectManagementTab.isEnabled settings + resources + kanban 必须 = false (V0-fix-8 修真 #2 — v0.04.0 / v0.05.0 才实装)"
        )

        // V0-fix-11 修真 #2: LayoutShellView.topLeftHeaderBar 修真 IconButton
        // 修真 + isDisabled: !tab.isEnabled 修真 IconButton 内部.
        XCTAssertTrue(
            layoutShell.contains("isDisabled: !tab.isEnabled"),
            "LayoutShellView topLeftHeaderBar 必须用 IconButton + isDisabled: !tab.isEnabled (V0-fix-11 修真 #2 — IconButton 修真 .disabled)"
        )
    }
}
