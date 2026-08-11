// V0Fix5LayoutTests.swift · 文枢 (Wenshu) · v0.03.0 V0-fix-5
//
// 装机 user 8/10 17:35 AIF CUA 自验拍 V0-fix-4 (commit 41646b01) 漏修
// 第五波回归测试 — 沿 V0Fix1/2/3/4LayoutTests 的"源码静态扫描 + 字面
// 量断言"模式 (SwiftPM-only binary AX tree 抓不到, 我们的真值就是
// source 里"有这个 / 没这个")。
//
// 覆盖 (8 个 test):
//   - testLayoutShellView_topHeaderBar_has5TabPickerInHeaderBar   (Fix A)
//   - testLayoutShellView_topHeaderBar_plusButtonAnd5TabCoexist  (Fix B)
//   - testLayoutShellView_ownsActiveTabState                     (Fix C)
//   - testLayoutShellView_panel_topLeft_passesActiveTabBinding   (Fix D)
//   - testProjectListView_noInternalPicker                       (Fix E)
//   - testProjectListView_activeTabIsBinding                     (Fix F)
//   - testProjectListView_5tabEnumsAndSymbolsPreserved            (Fix G)
//   - testLayoutShellView_headerBarStillHasPlusButtonAndNavStack  (Fix H)
//
// 拍板背景 (AIF 8/10 17:35 CUA 自验 + V0-fix-4 designer 1a09cd550 §5):
//   V0-fix-4 Fix 2 拍板说"5 tab 容器放标题栏 header bar 内, 与 + 按钮平
//   级" — 但 CC V0-fix-4 实装把 Picker.segmented 留在 ProjectListView
//   内部, header bar 只有 + 按钮。 V0-fix-5 真修: 把 5 tab Picker 从
//   ProjectListView 内部搬到 LayoutShellView.topLeftHeaderBar 内, 与
//   + 按钮平级 (同 38pt 高, + 按钮在左, 5 tab Picker 在右)。
//
//   - LayoutShellView 持 @State activeTab: ProjectManagementTab
//   - topLeftHeaderBar 跨全宽 38pt HStack 含 + 按钮 + Picker.segmented
//   - panel(.topLeft) 调 ProjectListView(activeTab: $activeTab, ...)
//   - ProjectListView 改 @Binding activeTab, 内部不再含 Picker
//   - ProjectManagementTab enum + 5 SF Symbol 字面量保留
//
// 兼容性:
//   - V0Fix4LayoutTests 6/6 仍过 (本卡不动 V0-fix-4 已修的 Fix 1/3/4/5)
//   - PickerStyle+IconOnly.swift 不动
//   - swift build exit 0 + swift test 全过 (44 stale baseline 沿用)

import XCTest
@testable import WenshuApp

final class V0Fix5LayoutTests: XCTestCase {

    // MARK: - Helpers (从 V0Fix1/2/3/4LayoutTests 复制)

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

    // MARK: - Fix A: 5 tab ICON 在 LayoutShellView header bar 内

    /// V0-fix-5 核心修复 (AIF 8/10 17:35 CUA 拍 V0-fix-4 漏修): 5 tab
    /// Picker 从 ProjectListView 内部搬到 LayoutShellView.topLeftHeaderBar
    /// 跨全宽 header bar 内, 与 + 按钮平级。
    ///
    /// V0-fix-8 (装机 user 8/11 16:20 真机拍红字 "5 tab 改文字按钮为
    /// ICON" + "所有 ICON 按钮, 只保留 ICON, 不要矩形背景, 仿 FCP"):
    /// 修真 #2 — 5 tab Picker.segmented 文字标签改 HStack + 5 Button(Image)
    /// + `.buttonStyle(.plain)`, 纯 ICON 无矩形背景, 对齐 FCP toolbar 范式。
    /// 本测试沿 V0-fix-8 修真更新断言 (Pick Picker → Button 形态), 历史
    /// `Picker.segmented` 字面量不再出现。
    func testLayoutShellView_topHeaderBar_has5TabPickerInHeaderBar() throws {
        let rawSource = try repoFile(
            "Sources/WenshuApp/Views/Layout/LayoutShellView.swift"
        )
        let code = stripSwiftComments(rawSource)

        // V0-fix-8 修真 #2: 5 tab 修真后是 HStack + 5 Button(Image) +
        // .buttonStyle(.plain) — 替代 Picker.segmented, 修真矩形分段框
        XCTAssertTrue(
            code.contains("ProjectManagementTab.allCases"),
            "LayoutShellView header bar 必须用 ProjectManagementTab.allCases 渲染 5 tab (V0-fix-5 Fix A — 5 tab 容器升 header bar, V0-fix-8 修真 #2 HStack+Button 形态)"
        )
        XCTAssertTrue(
            code.contains("Image(systemName: tab.symbolName)"),
            "LayoutShellView header bar 必须用 Image(systemName: tab.symbolName) 渲染 5 tab (V0-fix-8 修真 #2 — 改文字为 ICON)"
        )
        XCTAssertTrue(
            code.contains(".buttonStyle(.plain)"),
            "LayoutShellView header bar 必须用 .buttonStyle(.plain) (V0-fix-8 修真 #2 — 红字不要矩形背景, 仿 FCP)"
        )

        // V0-fix-8 修真 #2: 不应再有 Picker / .pickerStyle 字面量
        XCTAssertFalse(
            code.contains(".pickerStyle(.segmented)"),
            "LayoutShellView header bar 不应再有 .pickerStyle(.segmented) (V0-fix-8 修真 #2 — 改 HStack+Button, 去矩形分段框)"
        )
    }

    // MARK: - Fix B: + 按钮 (macOS title bar 接管) 和 5 tab ICON 在 header bar

    /// V0-fix-5 拍板真值: 5 tab 在 + 按钮右边, 同一 38pt HStack 内 (FCP
    /// toolbar 风格).
    ///
    /// V0-fix-8 (装机 user 8/11 16:20 真机拍红字 "新建按钮放在这里, 替换
    /// 文枢文字" + "去掉引行的新建按钮"): 修真 #1 + #4 — + 按钮从
    /// topLeftHeaderBar 移到 macOS title bar (LayoutShellView NavigationStack
    /// 顶层 .toolbar ToolbarItem(.principal)), topLeftHeaderBar 仅持 5 tab
    /// ICON (修真 #4 衍生 — 避免双 + 入口, FCP 单 + 范式)。 本测试沿
    /// V0-fix-8 修真更新断言: 修真后 `Picker("", selection: $activeTab)`
    /// 不再出现, 修真后 `ToolbarItem(placement: .principal)` + `activeTab =
    /// tab` 必须出现 (macOS title bar 接管)。
    func testLayoutShellView_topHeaderBar_plusButtonAnd5TabCoexist() throws {
        let rawSource = try repoFile(
            "Sources/WenshuApp/Views/Layout/LayoutShellView.swift"
        )
        let code = stripSwiftComments(rawSource)

        // topLeftHeaderBar 必须含 38pt HStack (沿用 V0-fix-5 Fix B)
        XCTAssertTrue(
            code.contains(".frame(height: 38)"),
            "LayoutShellView header bar 必须含 .frame(height: 38) (V0-fix-5 Fix B — 维持 V0-fix-4 Fix 1 38pt header bar)"
        )

        // V0-fix-8 修真 #1 + #4: + 按钮已移到 macOS title bar, 由
        // ToolbarItem(placement: .principal) 接管。 topLeftHeaderBar
        // 修真后不再含 plus.circle.fill Button (修真 #4 衍生 — FCP
        // 单 + 入口)。
        XCTAssertTrue(
            code.contains("ToolbarItem(placement: .principal)"),
            "LayoutShellView macOS title bar 必须由 ToolbarItem(placement: .principal) 接管 + 按钮 (V0-fix-8 修真 #1 — 红字新建按钮放这里替换文枢文字)"
        )
        XCTAssertTrue(
            code.contains("plus.circle.fill"),
            "LayoutShellView macOS title bar 必须含 SF Symbol <plus.circle.fill> (V0-fix-8 修真 #1 — + 按钮 SF Symbol)"
        )
        XCTAssertTrue(
            code.contains("activeTab = tab"),
            "LayoutShellView header bar 必须有 Button { activeTab = tab } 修真 5 tab (V0-fix-8 修真 #2 — HStack+Button 替代 Picker, 修真 #4 衍生 topLeftHeaderBar 不再有 Picker)"
        )

        // V0-fix-8 修真 #2: 不应再有 Picker 字面量
        XCTAssertFalse(
            code.contains("Picker(\"\", selection: $activeTab)"),
            "LayoutShellView header bar 不应再有 Picker(\"\", selection: $activeTab) (V0-fix-8 修真 #2 — 改 HStack+Button, 修真 #4 衍生 topLeftHeaderBar 不再有 Picker)"
        )
    }

    // MARK: - Fix C: LayoutShellView 顶层持有 activeTab state

    /// 拍板真值: activeTab 必须升到 LayoutShellView 顶层 @State, 不能留在
    /// ProjectListView @State (否则 Picker + 内容区跨区无法共享 state)
    func testLayoutShellView_ownsActiveTabState() throws {
        let rawSource = try repoFile(
            "Sources/WenshuApp/Views/Layout/LayoutShellView.swift"
        )
        let code = stripSwiftComments(rawSource)

        XCTAssertTrue(
            code.contains("@State") && code.contains("var activeTab: ProjectManagementTab"),
            "LayoutShellView 必须有 @State var activeTab: ProjectManagementTab (V0-fix-5 Fix C — 顶层 state, 跨 header bar + panel 共享)"
        )
    }

    // MARK: - Fix D: panel(.topLeft) 把 activeTab binding 传给 ProjectListView

    /// 拍板真值: panel(.topLeft) 调的 ProjectListView 必须接 activeTab: $activeTab
    /// (让 Picker 在 header bar 切换时, panel(.topLeft) 内的 tab 内容跟切)
    func testLayoutShellView_panel_topLeft_passesActiveTabBinding() throws {
        let rawSource = try repoFile(
            "Sources/WenshuApp/Views/Layout/LayoutShellView.swift"
        )
        let code = stripSwiftComments(rawSource)

        XCTAssertTrue(
            code.contains("activeTab: $activeTab"),
            "LayoutShellView panel(.topLeft) 必须把 activeTab binding 传给 ProjectListView (V0-fix-5 Fix D — 共享 state)"
        )
    }

    // MARK: - Fix E: ProjectListView 内部不再含 Picker

    /// V0-fix-5 真删 ProjectListView 内部的 Picker.segmented 整段 (V0-fix-4
    /// Fix 2 实装错的形态 — Picker 留在 panel 内, 没升到 header bar)
    func testProjectListView_noInternalPicker() throws {
        let rawSource = try repoFile(
            "Sources/WenshuApp/Views/ProjectListView.swift"
        )
        let code = stripSwiftComments(rawSource)

        XCTAssertFalse(
            code.contains("Picker(\"\", selection: $activeTab)"),
            "ProjectListView 内部不应再有 Picker(, selection: $activeTab) (V0-fix-5 Fix E — Picker 升 LayoutShellView header bar, ProjectListView 只渲染 tab 内容)"
        )
        XCTAssertFalse(
            code.contains(".pickerStyle(.segmented)"),
            "ProjectListView 不应再有 .pickerStyle(.segmented) (V0-fix-5 Fix E — 整段 Picker 已搬到 LayoutShellView header bar)"
        )
    }

    // MARK: - Fix F: ProjectListView 改接 @Binding activeTab

    /// 拍板真值: activeTab 必须从 @State 升到 @Binding, 由 LayoutShellView
    /// 顶层持有 (Fix C), 共享同一 state
    func testProjectListView_activeTabIsBinding() throws {
        let rawSource = try repoFile(
            "Sources/WenshuApp/Views/ProjectListView.swift"
        )
        let code = stripSwiftComments(rawSource)

        XCTAssertTrue(
            code.contains("@Binding") && code.contains("var activeTab: ProjectManagementTab"),
            "ProjectListView 必须接 @Binding var activeTab: ProjectManagementTab (V0-fix-5 Fix F — 共享 LayoutShellView 顶层 state)"
        )
        XCTAssertFalse(
            code.contains("@State private var activeTab: ProjectManagementTab"),
            "ProjectListView 不应再有 @State private var activeTab (V0-fix-5 Fix F — 升 @Binding, 避免双 state 不同步)"
        )
    }

    // MARK: - Fix G: 5 tab enum + 5 SF Symbol 字面量保留 (V0-fix-8 修真 #2 沿 AIF 16:20)

    /// V0-fix-5 不重写 ProjectManagementTab enum, 只搬 Picker 位置:
    ///   - 5 tab 文字字面量 (项目 / 章节 / 设定 / 资料 / 看板)
    ///   - 5 SF Symbol (folder / list.bullet.rectangle / slider.horizontal.3 /
    ///                 books.vertical / rectangle.split.3x1)
    ///
    /// V0-fix-8 (装机 user 8/11 16:20 真机拍红字 "5 tab 改文字按钮为
    /// ICON"): 修真 #2 — 5 SF Symbol 沿 AIF 16:20 截图重定义真值:
    /// folder / doc.text / gearshape / archive / square.grid.3x3 (替换
    /// V0-fix-5 字面量)。 本测试沿 V0-fix-8 修真更新 SF Symbol 断言。
    func testProjectListView_5tabEnumsAndSymbolsPreserved() throws {
        let rawSource = try repoFile(
            "Sources/WenshuApp/Views/ProjectListView.swift"
        )
        let code = stripSwiftComments(rawSource)

        // 5 tab 字面量 (沿用 V0-fix-5 Fix G)
        XCTAssertTrue(code.contains(#""项目""#), "ProjectListView 必须含 <项目> tab 字面量 (V0-fix-5 Fix G — enum 保留)")
        XCTAssertTrue(code.contains(#""章节""#), "ProjectListView 必须含 <章节> tab 字面量 (V0-fix-5 Fix G)")
        XCTAssertTrue(code.contains(#""设定""#), "ProjectListView 必须含 <设定> tab 字面量 (V0-fix-5 Fix G)")
        XCTAssertTrue(code.contains(#""资料""#), "ProjectListView 必须含 <资料> tab 字面量 (V0-fix-5 Fix G)")
        XCTAssertTrue(code.contains(#""看板""#), "ProjectListView 必须含 <看板> tab 字面量 (V0-fix-5 Fix G)")

        // 5 SF Symbol (V0-fix-8 修真 #2 沿 AIF 16:20 截图重定义真值)
        XCTAssertTrue(code.contains(#""folder""#),              "ProjectListView 必须含 SF Symbol <folder> (V0-fix-8 修真 #2 — AIF 16:20 项目 tab)")
        XCTAssertTrue(code.contains(#""doc.text""#),            "ProjectListView 必须含 SF Symbol <doc.text> (V0-fix-8 修真 #2 — AIF 16:20 章节 tab)")
        XCTAssertTrue(code.contains(#""gearshape""#),           "ProjectListView 必须含 SF Symbol <gearshape> (V0-fix-8 修真 #2 — AIF 16:20 设定 tab)")
        XCTAssertTrue(code.contains(#""archive""#),             "ProjectListView 必须含 SF Symbol <archive> (V0-fix-8 修真 #2 — AIF 16:20 资料 tab)")
        XCTAssertTrue(code.contains(#""square.grid.3x3""#),     "ProjectListView 必须含 SF Symbol <square.grid.3x3> (V0-fix-8 修真 #2 — AIF 16:20 看板 tab)")

        // V0-fix-5 字面量修真后不应再出现 (AIF 16:20 替换)
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

        // enum 本身保留 (沿 V0-fix-5 Fix G)
        XCTAssertTrue(
            code.contains("enum ProjectManagementTab"),
            "ProjectListView 必须保留 ProjectManagementTab enum (V0-fix-5 Fix G — LayoutShellView header bar 引用 allCases)"
        )
    }

    // MARK: - Fix H: V0-fix-4 已修的 Fix 1 + Fix 3 维持 (回归保护)

    /// V0-fix-5 只搬 Picker 位置, 不能回归掉 V0-fix-4 已修的:
    ///   - Fix 1: + 按钮 + .help(新建项目) + 38pt header bar
    ///   - Fix 3: NavigationStack(path:) + .navigationDestination(for: AppRoute.self) +
    ///            navPath.append(AppRoute.createProject)
    func testLayoutShellView_headerBarStillHasPlusButtonAndNavStack() throws {
        let rawSource = try repoFile(
            "Sources/WenshuApp/Views/Layout/LayoutShellView.swift"
        )
        let code = stripSwiftComments(rawSource)

        // V0-fix-4 Fix 1: + 按钮
        XCTAssertTrue(
            code.contains(#".help("新建项目")"#),
            "LayoutShellView header bar 必须含 .help(新建项目) tooltip (V0-fix-5 Fix H — V0-fix-4 Fix 1 不能回归)"
        )

        // V0-fix-4 Fix 3: NavigationStack push
        XCTAssertTrue(
            code.contains("NavigationStack(path:"),
            "LayoutShellView 必须含 NavigationStack(path:) (V0-fix-5 Fix H — V0-fix-4 Fix 3 不能回归)"
        )
        XCTAssertTrue(
            code.contains(".navigationDestination(for: AppRoute.self)"),
            "LayoutShellView 必须含 .navigationDestination(for: AppRoute.self) (V0-fix-5 Fix H — V0-fix-4 Fix 3 不能回归)"
        )
        XCTAssertTrue(
            code.contains("navPath.append(AppRoute.createProject)"),
            "LayoutShellView + 按钮 action 必须调 navPath.append(AppRoute.createProject) (V0-fix-5 Fix H — V0-fix-4 Fix 3 不能回归)"
        )
    }
}
