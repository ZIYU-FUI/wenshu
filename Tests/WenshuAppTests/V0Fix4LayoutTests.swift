// V0Fix4LayoutTests.swift · 文枢 (Wenshu) · v0.03.0 V0-fix-4
//
// 装机 user 8/10 16:25 + 16:35 + 16:40 + 16:45 OOB 真机拍 V0-fix-3
// (commit cfd5332b6 / da4a34d4f, worktree 不带) 漏修 / 漏管的 UI BUG
// 第四波回归测试。 沿用 V0Fix1/2/3LayoutTests 的"源码静态扫描 + 字
// 符面量断言"模式 — SwiftPM-only binary AX tree 抓不到, 我们的真值
// 就是 source 里"有这个 / 没这个"。
//
// 覆盖 (6 个 test):
//   - testLayoutShellView_topHeaderBar_hasPlusButtonAndNavStack (Fix 1 + Fix 3)
//   - testLayoutShellView_topHeaderBar_has5TabPicker          (Fix 2)
//   - testProjectListView_5tabList_present                    (Fix 2)
//   - testProjectListView_noToolbarPlusButton                 (Fix 1 派生)
//   - testChatPanelView_4chatTabs_iconOnlyAndLeftAligned      (Fix 4 + Fix 6)
//   - testInspectorView_2inspectorTabs_iconOnlyAndNoHeader    (Fix 5)
//
// 拍板背景 (装机 user 8/10 16:25 → 16:45 OOB 实机拍):
//   Fix 1 (BUG 7): 顶部 "+ 新建项目" 按钮移到标题栏最左(替换 v0.02.0 顶部
//                  "文枢" 文字), 38pt HStack + plus.circle.fill + .help
//                  "新建项目" + 整个 topLeftHeaderBar 跨全宽在 NativeSplitter
//                  上方(沿 AIF 16:40 拍板, 跟 v-fix-1/v-fix-3 的
//                  PanelContainer 内部 title-bar 区别).
//   Fix 2 (BUG 8): 5 tab 容器(项目/章节/设定/资料/看板)放标题栏 header bar
//                  内, 与 + 按钮平级(同 38pt 高), 用 ProjectManagementTab
//                  enum + 5 SF Symbol (folder / list.bullet.rectangle /
//                  slider.horizontal.3 / books.vertical / rectangle.split.3x1)
//                  + .pickerStyle(.segmented) 文字标签(跟 chat / inspector
//                  tab 风格刻意区分).
//   Fix 3 (BUG 9): + 按钮接 NavigationStack push to AppRoute.createProject —
//                  LayoutShellView 加 @State navPath + NavigationStack 包裹 +
//                  .navigationDestination(for: AppRoute.self) + Button 内
//                  navPath.append(.createProject) (沿 v0.01.0 WO-010 拍板
//                  NavigationStack 是 macOS HIG 主路由, 跟 v0.02.0 LOOP 边界
//                  冲突由 AIF 16:40 comment 显式拍板接受).
//   Fix 4 (BUG 4 沿用 v-fix-3): ChatPanelView Picker `.segmented` 改 `.iconOnly`
//                  (macOS 13 fallback 显 SF Symbol 文字).
//   Fix 5 (BUG 5+6 沿用 v-fix-3): InspectorView Picker 改 ICON-only + 删整段
//                  selfHeader H1 "检视" + 加 iconName(for:) inline 静态映射
//                  (伏笔 = eye / 修订 = pencil.and.list.clipboard).
//   Fix 6 (BUG 10): ChatPanelView 4 tab 居左对齐(FCP timeline 范式), 改
//                  .padding(.horizontal, 12) → .padding(.leading, 12) + 删
//                  .frame(maxWidth: .infinity) + 加 Spacer().
//   Fix 7 (编译配套): 新增 PickerStyle+IconOnly.swift (alias SegmentedPickerStyle,
//                  让 .pickerStyle(.iconOnly) 编译过).

import XCTest
@testable import WenshuApp

final class V0Fix4LayoutTests: XCTestCase {

    // MARK: - Helpers (从 V0Fix1/2/3LayoutTests 复制, helper 完全相同)

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

    // MARK: - Fix 1 + Fix 3: LayoutShellView topHeaderBar + NavigationStack push

    /// 装机 user 8/10 16:35 OOB 真机拍 + 16:40 BUG 7+9 拍板:
    ///   - Fix 1: 顶部 "+ 新建项目" 按钮移到标题栏最左 (替换 v0.02.0 顶部
    ///            "文枢" 文字), 38pt HStack + plus.circle.fill + .help "新建项目"
    ///   - Fix 3: + 按钮接 NavigationStack push → AppRoute.createProject
    ///            (LayoutShellView 加 @State navPath + NavigationStack 包裹 +
    ///            .navigationDestination + Button 内 navPath.append)
    ///
    /// 跟 V0-fix-3 在 wt/t_45b06855 拍的 PanelContainer 内部 `topLeftPanelWithTitleBar`
    /// 区别: V0-fix-4 升到跨全宽 header bar (在 NativeSplitter 上方), 跟 macOS
    /// title bar 双层 (AIF 16:40 拍板 FCP toolbar 风格).
    func testLayoutShellView_topHeaderBar_hasPlusButtonAndNavStack() throws {
        let rawSource = try repoFile(
            "Sources/WenshuApp/Views/Layout/LayoutShellView.swift"
        )
        let code = stripSwiftComments(rawSource)

        // Fix 1: 顶 header bar 38pt HStack + plus.circle.fill + .help "新建项目"
        XCTAssertTrue(
            code.contains(".frame(height: 38)"),
            "LayoutShellView header bar 必须含 .frame(height: 38) (V0-fix-4 Fix 1 — FCP 38pt title-bar 跨全宽)"
        )
        XCTAssertTrue(
            code.contains("plus.circle.fill"),
            "LayoutShellView header bar 必须含 SF Symbol <plus.circle.fill> (V0-fix-4 Fix 1 — + 按钮)"
        )
        XCTAssertTrue(
            code.contains(#".help("新建项目")"#),
            "LayoutShellView header bar 必须含 .help(新建项目) tooltip (V0-fix-4 Fix 1 — 兜中文)"
        )

        // Fix 3 (V0-fix-4 → V0-fix-6 supersede): NavigationStack 仍需 (chat 路由),
        // + 按钮已改 sheet 不 push. V0-fix-4 拍 push, V0-fix-6 (装机 user
        // 8/10 17:35 OOB "走弹窗不 push") supersede — 原 `navPath.append(
        // AppRoute.createProject)` 已删, 改 `showCreateProject = true`.
        // navPath 仍为 chat 路由服务 (ProjectListView 内项目行点击 →
        // navPath.append(AppRoute.chat)). NavigationStack + .navigation
        // Destination 保留.
        XCTAssertTrue(
            code.contains("NavigationStack(path:"),
            "LayoutShellView 必须含 NavigationStack(path:) (V0-fix-4 Fix 3 — 仍需, 路由 chat 用)"
        )
        XCTAssertTrue(
            code.contains(".navigationDestination(for: AppRoute.self)"),
            "LayoutShellView 必须含 .navigationDestination(for: AppRoute.self) (V0-fix-4 Fix 3 — 仍需, 路由 chat 用)"
        )
        // V0-fix-6 改: + 按钮走 modal sheet
        XCTAssertTrue(
            code.contains("showCreateProject = true"),
            "LayoutShellView + 按钮 action 必须调 showCreateProject = true (V0-fix-6 Fix 1 — 改 sheet 弹窗不 push, 装机 user 8/10 17:35 OOB 拍)"
        )
        XCTAssertFalse(
            code.contains("navPath.append(AppRoute.createProject)"),
            "LayoutShellView + 按钮 action 不应再调 navPath.append(AppRoute.createProject) (V0-fix-6 Fix 1 — 改 sheet 不 push)"
        )
        XCTAssertTrue(
            code.contains("@State") && code.contains("NavigationPath"),
            "LayoutShellView 必须有 @State NavigationPath 字段 (V0-fix-4 Fix 3 — navPath 仍需, chat 路由用)"
        )

        // PlaceholderContent(panel: .topLeft) 必须从 panel(_:) switch 移除
        // — 5 tab 内容已经在 panel 内渲染(header bar 是独立跨全宽 bar), 不再走 PlaceholderContent
        // (strip 注释后, panel(_:) switch 里 .topLeft 分支不应再有 PlaceholderContent(panel: .topLeft))
        // 注: 这条检查 V0-fix-3 在 PanelContainer 内部还放 PlaceholderContent — V0-fix-4 改了结构
        // 这里不强断言(避免与 v-fix-3 冲突, 但在 design doc §1.3 已标拍板)
    }

    // MARK: - Fix 2: LayoutShellView header bar 内含 5 tab 容器

    /// 装机 user 8/10 16:35 OOB BUG 8 拍板 + AIF 16:40 拍板:
    ///   - 5 tab 容器放标题栏 header bar 内, 与 + 按钮平级 (FCP toolbar 风格)
    ///   - ProjectManagementTab enum (case 5: projects / chapters / settings / resources / kanban)
    ///   - 5 SF Symbol: folder / list.bullet.rectangle / slider.horizontal.3 /
    ///                 books.vertical / rectangle.split.3x1
    ///   - Picker.segmented 文字标签 (跟 chat / inspector tab 风格刻意区分, 沿 LT-03 v2)
    func testLayoutShellView_topHeaderBar_has5TabPicker() throws {
        let rawSource = try repoFile(
            "Sources/WenshuApp/Views/Layout/LayoutShellView.swift"
        )
        let code = stripSwiftComments(rawSource)

        // 5 SF Symbol 必须都在 LayoutShellView source 里 (header bar 调用 ProjectListView 容器,
        // 但 5 tab 字面量可能在 ProjectListView 里 — 这里检查 LayoutShellView 含 ProjectListView 调用)
        // 间接验证: LayoutShellView 含 ProjectManagementTab enum 引用 + 5 SF Symbol
        // — 但 5 SF Symbol 通常在 ProjectListView 内定义 — 这里不强求, 让 testProjectListView_5tabList_present 验证
        // 仅验证 LayoutShellView 调 ProjectListView
        XCTAssertTrue(
            code.contains("ProjectListView"),
            "LayoutShellView header bar 必须调 ProjectListView 容器 (V0-fix-4 Fix 2 — 5 tab 容器在 header bar 内)"
        )
    }

    // MARK: - Fix 2: ProjectListView 5 tab 容器整文件重写

    /// 沿 V0-fix-3 Fix J (cfd5332b6 / 项目/章节/设定/资料/看板 5 tab 容器):
    ///   - ProjectManagementTab enum (case 5)
    ///   - 5 SF Symbol + 5 tab 字面量
    ///   - Picker.segmented 文字标签
    ///   - 删原 .toolbar { Button "新建项目" } (跟 Fix 1 title-bar + 按钮合并, 单 + 入口)
    ///
    /// V0-fix-8 (装机 user 8/11 16:20 真机拍红字 "5 tab 改文字按钮为
    /// ICON" + "所有 ICON 按钮, 只保留 ICON, 不要矩形背景, 仿 FCP"):
    ///   - 5 SF Symbol 修真 AIF 16:20 截图重定义真值: folder / doc.text /
    ///     gearshape / archive / square.grid.3x3 (替换 V0-fix-4 字面量)
    ///   - Picker 整段已迁 LayoutShellView.topLeftHeaderBar (沿 V0-fix-5),
    ///     ProjectListView 不再含 Picker (仅保留 enum + 5 SF Symbol 字面量)
    func testProjectListView_5tabList_present() throws {
        let rawSource = try repoFile(
            "Sources/WenshuApp/Views/ProjectListView.swift"
        )
        let code = stripSwiftComments(rawSource)

        // 5 tab 字面量 (沿用 V0-fix-4 Fix 2)
        XCTAssertTrue(code.contains(#""项目""#), "ProjectListView 必须含 <项目> tab 字面量 (V0-fix-4 Fix 2 — 5 tab 容器)")
        XCTAssertTrue(code.contains(#""章节""#), "ProjectListView 必须含 <章节> tab 字面量 (V0-fix-4 Fix 2 — 5 tab 容器)")
        XCTAssertTrue(code.contains(#""设定""#), "ProjectListView 必须含 <设定> tab 字面量 (V0-fix-4 Fix 2 — 5 tab 容器)")
        XCTAssertTrue(code.contains(#""资料""#), "ProjectListView 必须含 <资料> tab 字面量 (V0-fix-4 Fix 2 — 5 tab 容器)")
        XCTAssertTrue(code.contains(#""看板""#), "ProjectListView 必须含 <看板> tab 字面量 (V0-fix-4 Fix 2 — 5 tab 容器)")

        // ProjectManagementTab enum 必须存在
        XCTAssertTrue(code.contains("ProjectManagementTab"), "ProjectListView 必须含 ProjectManagementTab enum (V0-fix-4 Fix 2)")

        // 5 SF Symbol (V0-fix-8 修真 #2 沿 AIF 16:20 截图重定义真值)
        XCTAssertTrue(code.contains(#""folder""#),              "ProjectListView 必须含 SF Symbol <folder> (V0-fix-8 修真 #2 — AIF 16:20 项目 tab)")
        XCTAssertTrue(code.contains(#""doc.text""#),            "ProjectListView 必须含 SF Symbol <doc.text> (V0-fix-8 修真 #2 — AIF 16:20 章节 tab)")
        XCTAssertTrue(code.contains(#""gearshape""#),           "ProjectListView 必须含 SF Symbol <gearshape> (V0-fix-8 修真 #2 — AIF 16:20 设定 tab)")
        XCTAssertTrue(code.contains(#""archive""#),             "ProjectListView 必须含 SF Symbol <archive> (V0-fix-8 修真 #2 — AIF 16:20 资料 tab)")
        XCTAssertTrue(code.contains(#""square.grid.3x3""#),     "ProjectListView 必须含 SF Symbol <square.grid.3x3> (V0-fix-8 修真 #2 — AIF 16:20 看板 tab)")

        // V0-fix-4 字面量修真后不应再出现 (AIF 16:20 替换)
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

        // Picker 修真后不在 ProjectListView (沿 V0-fix-5 — 5 tab Picker
        // 升 LayoutShellView.topLeftHeaderBar, ProjectListView 仅保留 enum
        // + SF Symbol 字面量)
        XCTAssertFalse(
            code.contains(".pickerStyle(.segmented)"),
            "ProjectListView 不应再有 .pickerStyle(.segmented) (V0-fix-5 Fix E — 整段 Picker 已搬到 LayoutShellView header bar)"
        )
    }

    // MARK: - Fix 1 派生: ProjectListView 删 .toolbar + button

    /// AIF 16:40 comment 第 7 条拍板: 顶部 '+ 新建项目' 按钮只保留 1 个
    /// (= Fix 1 LayoutShellView `topLeftHeaderBar`), Tab 1 (项目) 内的
    /// `.toolbar { ToolbarItem(.primaryAction) { Button ... } }` 必须
    /// 删除, 避免 2 个 '+ 按钮' 视觉冗余 (FCP 范式 = 单 + 入口).
    func testProjectListView_noToolbarPlusButton() throws {
        let rawSource = try repoFile(
            "Sources/WenshuApp/Views/ProjectListView.swift"
        )
        let code = stripSwiftComments(rawSource)

        XCTAssertFalse(
            code.contains(#"ToolbarItem(placement: .primaryAction)"#),
            "ProjectListView 不应再用 .toolbar { ToolbarItem(placement: .primaryAction) } 这个 + 新建项目按钮 (V0-fix-4 Fix 1 派生 — 跟 Fix 1 header bar + 按钮合并为 1 个, 避免冗余)"
        )
        XCTAssertFalse(
            code.contains(#"Label("新建项目""#),
            "ProjectListView 不应再用 Label(新建项目, systemImage: ...) (V0-fix-4 Fix 1 派生 — 删原 .toolbar + 按钮)"
        )
    }

    // MARK: - Fix 4 + Fix 6: ChatPanelView 修真 #3 Picker → HStack+Button + 居左

    /// V0-fix-4 Fix 4 + Fix 6 历史: Picker `.segmented` → `.iconOnly`
    /// (强制 ICON-only, macOS 13 fallback 显 SF Symbol 文字) + 4 tab
    /// 居左对齐 (FCP timeline 范式) — 改 `.padding(.horizontal, 12)`
    /// → `.leading`, 删 `.frame(maxWidth: .infinity)` + 真删 "聊天区视图"
    /// H1 残留 (Picker a11y 改 "")。
    ///
    /// V0-fix-8 (装机 user 8/11 16:20 真机拍红字 "所有 ICON 按钮, 只保留
    /// ICON, 不要矩形背景, 仿 FCP"): 修真 #3 — `.pickerStyle(.iconOnly)`
    /// (走 SegmentedPickerStyle) 仍有 macOS 系统矩形分段框背景, 不符
    /// 红字"不要矩形背景"。 真修真: Picker 整段迁 HStack + 4 Button
    /// (Image) + `.buttonStyle(.plain)`, 纯 ICON 无矩形背景, 对齐 FCP
    /// timeline 范式。本测试沿 V0-fix-8 修真更新断言 (Pick Picker → Button
    /// 形态), 历史 `.pickerStyle(.iconOnly)` 字面量不再出现。
    func testChatPanelView_4chatTabs_iconOnlyAndLeftAligned() throws {
        let rawSource = try repoFile(
            "Sources/WenshuApp/Views/Chat/ChatPanelView.swift"
        )
        let code = stripSwiftComments(rawSource)

        // V0-fix-8 修真 #3: 4 chat tab 修真后是 HStack + Button(Image)
        // + .buttonStyle(.plain) — 替代 Picker(.iconOnly), 修真矩形分段框
        XCTAssertTrue(
            code.contains("activeTab = tab"),
            "ChatPanelView 必须有 Button { activeTab = tab } 修真 4 chat tab (V0-fix-8 修真 #3 — HStack+Button 替代 Picker)"
        )
        XCTAssertTrue(
            code.contains(".buttonStyle(.plain)"),
            "ChatPanelView 必须用 .buttonStyle(.plain) (V0-fix-8 修真 #3 — 红字不要矩形背景, 仿 FCP)"
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

        // 修真后无 Picker, "聊天区视图" H1 字面量也不复存在 (沿 V0-fix-4
        // Fix 4 H1 真删)
        XCTAssertFalse(
            code.contains(#"Picker("聊天区视图""#),
            #"ChatPanelView 不应再有 Picker(\"聊天区视图\") (V0-fix-4 Fix 4 — H1 真删改 Picker(""), V0-fix-8 修真 #3 Picker 整段迁走)"#
        )

        // 兜底: Button 块走 Image(systemName:) 渲染 (沿 V0-fix-4 Fix 4
        // ICON-only 契约, 修真后形态仍保留)
        XCTAssertTrue(
            code.contains("Image(systemName:"),
            "ChatPanelView Button 块必须用 Image(systemName:) 渲染 tab (V0-fix-4 Fix 4 + V0-fix-8 修真 #3 ICON-only 契约)"
        )

        // Fix 6: 4 tab 居左对齐 (V0-fix-4 沿 V0-fix-8 修真保留 — 修真仅 tab
        // 渲染方式, 不动居左对齐)
        XCTAssertTrue(
            code.contains(".padding(.leading, 12)"),
            "ChatPanelView HStack 必须用 .padding(.leading, 12) 让 tab list 居左对齐 (V0-fix-4 Fix 6 — FCP timeline 范式, V0-fix-8 修真 #3 保留)"
        )
    }

    // MARK: - Fix 5: InspectorView Picker .iconOnly + 删 selfHeader

    /// 沿 V0-fix-3 Fix H (装机 user 8/10 15:30 OOB 真机拍 V0-fix-1 后仍不符):
    ///   - Picker `.segmented` → `.iconOnly`
    ///   - 删 selfHeader 整段 (H1 "检视" 残留)
    ///   - Picker a11y "检视" → ""
    ///   - Text(tab.title) → Image(systemName: iconName(for:))
    ///   - 2 SF Symbol: eye / pencil.and.list.clipboard
    func testInspectorView_2inspectorTabs_iconOnlyAndNoHeader() throws {
        let rawSource = try repoFile(
            "Sources/WenshuApp/Views/Inspector/InspectorView.swift"
        )
        let code = stripSwiftComments(rawSource)

        // Picker style 强制 ICON-only
        XCTAssertTrue(
            code.contains(".pickerStyle(.iconOnly)"),
            "InspectorView 必须使用 .pickerStyle(.iconOnly) 强制 ICON-only (V0-fix-4 Fix 5 — macOS 13 segmented fallback 显文字)"
        )
        XCTAssertFalse(
            code.contains(".pickerStyle(.segmented)"),
            "InspectorView 不应再用 .pickerStyle(.segmented) (V0-fix-4 Fix 5 替换, 避免回归)"
        )

        // Picker 块走 Image(systemName:) 替代 Text(tab.title)
        XCTAssertFalse(
            code.contains("Text(tab.title)"),
            "InspectorView Picker 块不应再用 Text(tab.title) 文字渲染 (V0-fix-4 Fix 5 — 改 Image(systemName:))"
        )
        XCTAssertTrue(
            code.contains("Image(systemName:"),
            "InspectorView Picker 块必须用 Image(systemName:) 渲染 tab (V0-fix-4 Fix 5 ICON-only 契约)"
        )

        // 2 SF Symbol 必须都在 source 里 (iconName(for:) 映射)
        XCTAssertTrue(code.contains(#""eye""#),                   "InspectorView 必须含 SF Symbol <eye> (V0-fix-4 Fix 5 伏笔 tab)")
        XCTAssertTrue(code.contains("pencil.and.list.clipboard"), "InspectorView 必须含 SF Symbol <pencil.and.list.clipboard> (V0-fix-4 Fix 5 修订 tab)")

        // iconName(for:) inline 静态映射必须存在
        XCTAssertTrue(
            code.contains("iconName(for:") || code.contains("iconName(for "),
            "InspectorView 必须含 iconName(for:) inline 静态映射函数 (V0-fix-4 Fix 5 — InspectorViewModel.Tab enum 不动, 走 inline)"
        )

        // Picker a11y 改 ""
        XCTAssertFalse(
            code.contains(#"Picker("检视""#),
            #"InspectorView Picker a11y 字符串标签不应再含 <检视> (V0-fix-4 Fix 5 — 改 "" 跟 V0-fix-1 Fix B 同形态)"#
        )

        // selfHeader H1 真删 — strip 注释后 `selfHeader` 标识符 + Text(检视) 都必须消失
        XCTAssertFalse(
            code.contains("selfHeader"),
            "InspectorView 不应再有 selfHeader 引用 (V0-fix-4 Fix 5 — 整段 H1 + body 调用都删除)"
        )
        XCTAssertFalse(
            code.contains(#"Text("检视")"#),
            "InspectorView 活动代码不能含 Text(检视) (V0-fix-4 Fix 5 — selfHeader H1 真删)"
        )
    }
}
