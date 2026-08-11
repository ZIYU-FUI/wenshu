// V0Fix7LayoutTests.swift · 文枢 (Wenshu) · v0.03.0 V0-fix-7
//
// 装机 user 8/11 18:05 CUA 自验拍 V0-fix-6 (commit b33ece371) 真机拍,
// 发现 3 处漏修被 LT-N1-merge (commit a216b1220) 解决冲突时回滚:
//   - BUG 1: + 按钮走 NavigationStack push (V0-fix-6 拍改 modal sheet
//            被 LT-N1-merge 拍 "push 优先 sheet" 时回滚)
//   - BUG 2: 5 tab Picker 用 segmented Text (V0-fix-6 拍改 iconOnly
//            + SF Symbol 被 LT-N1-merge 同上原因回滚)
//   - BUG 3: App.swift WindowGroup("文枢") — 主窗口 traffic light 旁
//            硬显示 "文枢" 两字 (OOB 3 拍板去掉)
//
// 沿用 V0FixNLayoutTests 的 "源码静态扫描 + 字面量断言" 模式 —
// SwiftPM-only binary AX tree 抓不到, 我们的真值就是 source 里 "有这
// 个 / 没这个"。
//
// 覆盖 (8 个 test, AIF 18:05 CUA 自验拍板):
//   1. test_ProjectCreateView_called_via_sheet_not_push
//   2. test_topLeftHeaderBar_uses_iconOnly_picker_style
//   3. test_topLeftHeaderBar_uses_sf_symbol_not_text_label
//   4. test_WindowGroup_drops_wenshu_title
//   5. test_AppRoute_createProject_route_still_defined
//   6. test_navPath_still_used_for_chat_or_detail_route
//   7. test_ProjectManagementTab_symbolName_5_sf_symbols_preserved
//   8. test_ChatPanelTab_already_iconOnly_unchanged

import XCTest
@testable import WenshuApp

final class V0Fix7LayoutTests: XCTestCase {

    // MARK: - Helpers (从 V0Fix1/2/3/4/5/6LayoutTests 复制, helper 完全相同)

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

    // MARK: - BUG 1: ProjectCreateView 走 sheet 不走 push

    /// 装机 user 8/10 17:35 OOB 真机拍 "走弹窗不 push" (沿 V0-fix-6 Fix 1):
    ///   - LayoutShellView 加 `@State private var showCreateProject: Bool`
    ///     + `.sheet(isPresented: $showCreateProject)` 包裹 NavigationStack
    ///     顶级, sheet content = ProjectCreateView
    ///   - + 按钮 action 改 `showCreateProject = true`
    ///   - 删 V0-fix-4 `navPath.append(AppRoute.createProject)` (改 sheet)
    ///   - destinationView(.createProject) 改 placeholder 兜底 (保留
    ///     enum 不破坏外部引用 — 沿 V0-fix-6 真值)
    ///   - navPath 仍为 chat/detail 路由服务
    ///
    /// 本卡 (V0-fix-7) 真修 LT-N1-merge 回滚的 push 路由回 modal sheet
    /// (AIF 18:05 CUA 自验拍板)。
    func test_ProjectCreateView_called_via_sheet_not_push() throws {
        let rawSource = try repoFile(
            "Sources/WenshuApp/Views/Layout/LayoutShellView.swift"
        )
        let code = stripSwiftComments(rawSource)

        // showCreateProject state 必须存在 (sheet 显隐 state)
        XCTAssertTrue(
            code.contains("@State private var showCreateProject: Bool = false"),
            "LayoutShellView 必须有 @State showCreateProject (V0-fix-7 BUG 1 — sheet 显隐 state, 替代 LT-N1-merge 回滚的 push)"
        )

        // .sheet(isPresented:) 必须挂在 LayoutShellView body 顶级
        XCTAssertTrue(
            code.contains(".sheet(isPresented: $showCreateProject)"),
            "LayoutShellView body 必须含 .sheet(isPresented: $showCreateProject) (V0-fix-7 BUG 1 — + 按钮走弹窗不 push)"
        )

        // + 按钮 action 走 showCreateProject = true (替代 push)
        XCTAssertTrue(
            code.contains("showCreateProject = true"),
            "LayoutShellView + 按钮 action 必须调 showCreateProject = true (V0-fix-7 BUG 1 — 改 sheet 弹窗)"
        )

        // V0-fix-4 / LT-N1-merge 留下的 navPath.append(AppRoute.createProject)
        // 必须删除 (改 sheet 不 push)
        XCTAssertFalse(
            code.contains("navPath.append(AppRoute.createProject)"),
            "LayoutShellView 不应再有 navPath.append(AppRoute.createProject) (V0-fix-7 BUG 1 — + 按钮改 sheet 不 push)"
        )

        // destinationView(.createProject) 必须改 placeholder 兜底 (sheet 是真路由)
        // — 不能继续调 ProjectCreateView(onCreate: ...) 真装 (避免双路由)
        // 实现: 在 .createProject 关键字之后 500 char 内不应有 ProjectCreateView(
        let createProjectRange = code.range(of: "case .createProject:")
        if let range = createProjectRange {
            let after = range.upperBound
            let afterOffset = code.distance(from: code.startIndex, to: after)
            let endOffset = min(afterOffset + 500, code.distance(from: code.startIndex, to: code.endIndex))
            let endIdx = code.index(code.startIndex, offsetBy: endOffset)
            var window = String(code[after..<endIdx])
            // window 范围限定到下一个 case 关键字之前
            if let nextCaseRange = window.range(of: "\n        case .") {
                window = String(window[..<nextCaseRange.lowerBound])
            }
            XCTAssertFalse(
                window.contains("ProjectCreateView("),
                "LayoutShellView destinationView(.createProject) case 不应再有 ProjectCreateView( 真装 (V0-fix-7 BUG 1 — sheet 才是真路由, push 路径走 placeholder)"
            )
        } else {
            XCTFail("LayoutShellView destinationView 缺少 case .createProject: 分支 (V0-fix-7 BUG 1 — enum case 必须保留作 placeholder 兜底)")
        }
    }

    // MARK: - BUG 2a: 5 tab Picker .iconOnly (替代 .segmented)

    /// 装机 user 8/10 17:35 OOB 真机拍 "5 tab 文字改 ICON" (沿 V0-fix-6
    /// Fix 2): 标题栏 5 tab Picker 改 `.iconOnly` (替代 LT-N1-merge 回
    /// 滚的 `.segmented`)。
    func test_topLeftHeaderBar_uses_iconOnly_picker_style() throws {
        let rawSource = try repoFile(
            "Sources/WenshuApp/Views/Layout/LayoutShellView.swift"
        )
        let code = stripSwiftComments(rawSource)

        // .pickerStyle(.iconOnly) 必须出现在 LayoutShellView (header bar Picker)
        XCTAssertTrue(
            code.contains(".pickerStyle(.iconOnly)"),
            "LayoutShellView 标题栏 Picker 必须用 .pickerStyle(.iconOnly) (V0-fix-7 BUG 2 — 沿 V0-fix-6 Fix 2, 替代 LT-N1-merge 回滚的 .segmented)"
        )

        // .pickerStyle(.segmented) 在 LayoutShellView 必须删除 (5 tab 标题栏
        // 改 iconOnly, .segmented 只在 ProjectCreateView 文笔风格 picker
        // 出现 — 不应在 LayoutShellView 标题栏 5 tab 上残留)
        XCTAssertFalse(
            code.contains(".pickerStyle(.segmented)"),
            "LayoutShellView 不应再用 .pickerStyle(.segmented) (V0-fix-7 BUG 2 — 标题栏 5 tab 改 iconOnly, .segmented 是 ProjectCreateView 文笔风格专用)"
        )

        // .labelsHidden() 在 LayoutShellView 必须删除 (.iconOnly 不需要 labelsHidden)
        XCTAssertFalse(
            code.contains(".labelsHidden()"),
            "LayoutShellView 不应再用 .labelsHidden() (V0-fix-7 BUG 2 — .iconOnly 不需要 labelsHidden)"
        )
    }

    // MARK: - BUG 2b: 5 tab Picker 走 SF Symbol (替代 Text 文字)

    /// 装机 user 8/10 17:35 OOB 真机拍 "5 tab 文字改 ICON" (沿 V0-fix-6
    /// Fix 2): Picker 内容 `Text(tab.rawValue).tag(tab)` → `Image(
    /// systemName: tab.symbolName).tag(tab).help(tab.rawValue)`。
    ///
    /// 沿用 ProjectManagementTab.symbolName 真值 (5 SF Symbol: folder /
    /// list.bullet.rectangle / slider.horizontal.3 / books.vertical /
    /// rectangle.split.3x1), 不改 enum。
    func test_topLeftHeaderBar_uses_sf_symbol_not_text_label() throws {
        let rawSource = try repoFile(
            "Sources/WenshuApp/Views/Layout/LayoutShellView.swift"
        )
        let code = stripSwiftComments(rawSource)

        // Picker 块用 Image(systemName: tab.symbolName) (替代 Text)
        XCTAssertTrue(
            code.contains("Image(systemName: tab.symbolName)"),
            "LayoutShellView 标题栏 Picker 块必须用 Image(systemName: tab.symbolName) (V0-fix-7 BUG 2 — 复用 ProjectManagementTab.symbolName 5 SF Symbol)"
        )

        // Picker 块 .help(tab.rawValue) 加 tooltip (iconOnly 必备)
        XCTAssertTrue(
            code.contains(".help(tab.rawValue)"),
            "LayoutShellView 标题栏 Picker 块必须加 .help(tab.rawValue) tooltip (V0-fix-7 BUG 2 — iconOnly 必备, 用户看不到文字)"
        )

        // Picker 块不应再用 Text(tab.rawValue).tag(tab) 文字标签 (改 ICON-only)
        XCTAssertFalse(
            code.contains("Text(tab.rawValue).tag(tab)"),
            "LayoutShellView 标题栏 Picker 块不应再用 Text(tab.rawValue).tag(tab) (V0-fix-7 BUG 2 — 改 Image SF Symbol)"
        )
    }

    // MARK: - BUG 3: WindowGroup 去 "文枢" 两字

    /// 装机 user 8/11 18:05 CUA 自验拍 (OOB 3 拍板):
    ///   - App.swift `WindowGroup("文枢") {` 必须删除 "文枢" 两字
    ///   - 改成 `WindowGroup("") {` 或 `WindowGroup {` (空 title 参数)
    ///   - 含义: 主窗口 traffic light 旁不硬显示 "文枢" 两字 (sheet 触
    ///     发后 sheet 标题自带, 如 "新建项目" 是 ProjectCreateView 默认
    ///     sheet 标题; macOS 默认行为空 title 不显示任何文字)
    ///   - 不动 WindowGroup 内部 MainView() + environmentObject + frame
    ///     + windowStyle/.titleBar + .windowResizability + .commands
    func test_WindowGroup_drops_wenshu_title() throws {
        let rawSource = try repoFile(
            "Sources/WenshuApp/App.swift"
        )
        let code = stripSwiftComments(rawSource)

        // WindowGroup("文枢") 必须删除 (改空 title)
        XCTAssertFalse(
            code.contains(#"WindowGroup("文枢")"#),
            "App.swift 不应再有 WindowGroup(\"文枢\") (V0-fix-7 BUG 3 — OOB 3 拍板去 \"文枢\" 两字, 主窗口 traffic light 旁不硬显示)"
        )

        // WindowGroup("") 或 WindowGroup { (空 title 两种写法均可)
        let hasEmptyString = code.contains(#"WindowGroup("")"#)
        let hasNoTitleArg = code.contains("WindowGroup {")
        XCTAssertTrue(
            hasEmptyString || hasNoTitleArg,
            "App.swift WindowGroup 必须改空 title (V0-fix-7 BUG 3 — WindowGroup(\"\") 或 WindowGroup { 两种写法均接受)"
        )
    }

    // MARK: - BUG 1 派生: AppRoute.createProject 路由保留

    /// V0-fix-7 BUG 1 派生: + 按钮改 sheet 后, .createProject 路由不再
    /// 被 + 按钮消费 (sheet 是真路由)。 但 AppRoute enum 必须保留
    /// `case createProject` 不破坏外部引用 (LT-N1-merge 真值, enum
    /// 公开 contract 改 = 撞 approval gate)。 destinationView(.create
    /// Project) 走 placeholder 兜底。
    func test_AppRoute_createProject_route_still_defined() throws {
        let rawSource = try repoFile(
            "Sources/WenshuApp/MainView.swift"
        )
        let code = stripSwiftComments(rawSource)

        // AppRoute enum 必须保留 .createProject case
        XCTAssertTrue(
            code.contains("case createProject"),
            "MainView.swift AppRoute enum 必须保留 case createProject (V0-fix-7 BUG 1 派生 — enum 公开 contract 保留, push 路径走 placeholder 兜底)"
        )

        // AppRoute enum 必须保留 .detail(projectId:) case (LT-N1-merge 真值,
        // navPath 用 .detail 路由)
        XCTAssertTrue(
            code.contains(#"case detail(projectId: UUID)"#),
            "MainView.swift AppRoute enum 必须保留 case detail(projectId: UUID) (V0-fix-7 — LT-N1-merge 真值, navPath 路由 .detail)"
        )

        // AppRoute 必须还是 Hashable (LT-N1-merge 拍 navPath 用 [AppRoute]
        // binding, AppRoute 必须 Hashable 才能装 NavigationStack)
        XCTAssertTrue(
            code.contains("AppRoute: Hashable"),
            "MainView.swift AppRoute enum 必须仍是 Hashable (V0-fix-7 — LT-N1-merge navPath = [AppRoute] binding 依赖)"
        )
    }

    // MARK: - BUG 1 派生: navPath 仍服务 chat/detail 路由

    /// V0-fix-7 BUG 1 派生: navPath 必须保留 (LT-N1-merge 真值), 不
    /// 能整个删掉 — chat/detail 路由仍走 navPath.append(AppRoute
    /// .detail(projectId: id))。 类型 `[AppRoute]` 沿 LT-N1-merge
    /// (P0-2 fix: NavigationPath 不公开 Sequence 接口)。
    ///
    /// + 按钮改 sheet 不代表 navPath 整个删, navPath 只接 chat/detail
    /// 路由, push 行为不变。 navPath 声明在 LayoutShellView (顶层 state),
    /// navPath.append 调用在 ProjectListView (项目行点击走 .detail 路由)。
    /// 本卡验两端都在 (声明 + 调用都保留)。
    func test_navPath_still_used_for_chat_or_detail_route() throws {
        // LayoutShellView 端: navPath 声明 + NavigationStack 绑定
        let layoutShellRaw = try repoFile(
            "Sources/WenshuApp/Views/Layout/LayoutShellView.swift"
        )
        let layoutShellCode = stripSwiftComments(layoutShellRaw)

        // navPath 必须仍是 [AppRoute] 类型 (LT-N1-merge P0-2 fix)
        XCTAssertTrue(
            layoutShellCode.contains("navPath: [AppRoute]"),
            "LayoutShellView 必须有 navPath: [AppRoute] (V0-fix-7 BUG 1 派生 — LT-N1-merge P0-2 fix, 类型 [AppRoute] 沿用)"
        )

        // NavigationStack(path:) 仍必须存在 (LT-N1-merge 真值, chat/detail
        // 路由容器)
        XCTAssertTrue(
            layoutShellCode.contains("NavigationStack(path:"),
            "LayoutShellView 必须有 NavigationStack(path: $navPath) (V0-fix-7 BUG 1 派生 — chat/detail 路由容器)"
        )

        // ProjectListView 端: navPath.append(AppRoute ...) 调用 (项目行
        // 点击走 .detail 路由 — LT-N1-merge 真值)
        let projectListRaw = try repoFile(
            "Sources/WenshuApp/Views/ProjectListView.swift"
        )
        let projectListCode = stripSwiftComments(projectListRaw)

        // navPath.append(AppRoute 必须至少 1 处 (chat 或 detail 路由)
        let navPathAppendCount = projectListCode.components(separatedBy: "navPath.append(AppRoute").count - 1
        XCTAssertGreaterThanOrEqual(
            navPathAppendCount, 1,
            "ProjectListView 必须至少有 1 处 navPath.append(AppRoute ... 调用 (V0-fix-7 BUG 1 派生 — chat/detail 路由仍走 navPath, 不能整个删)"
        )

        // .detail(projectId:) 路由必须保留 (LT-N1-merge 真值, ProjectListView
        // 项目行点击 → navPath.append(.detail(projectId: id)))
        XCTAssertTrue(
            projectListCode.contains("navPath.append(AppRoute.detail"),
            "ProjectListView 必须有 navPath.append(AppRoute.detail ...) (V0-fix-7 BUG 1 派生 — LT-N1-merge 真值, 项目行点击走 .detail 路由)"
        )
    }

    // MARK: - BUG 2 派生: ProjectManagementTab.symbolName 5 SF Symbol 沿用

    /// V0-fix-7 BUG 2 派生: 5 tab Picker 改 iconOnly 但 enum 不动 —
    /// ProjectManagementTab.symbolName 5 SF Symbol 必须保留 (folder /
    /// list.bullet.rectangle / slider.horizontal.3 / books.vertical /
    /// rectangle.split.3x1)。 LayoutShellView 标题栏 Picker 块通过
    /// `Image(systemName: tab.symbolName)` 间接引用 (见 test_topLeft
    /// HeaderBar_uses_sf_symbol_not_text_label), 这里验 enum 本体
    /// SF Symbol 字面量全在。
    func test_ProjectManagementTab_symbolName_5_sf_symbols_preserved() throws {
        let rawSource = try repoFile(
            "Sources/WenshuApp/Views/ProjectListView.swift"
        )
        let code = stripSwiftComments(rawSource)

        // ProjectManagementTab enum 必须存在
        XCTAssertTrue(
            code.contains("enum ProjectManagementTab"),
            "ProjectListView 必须含 enum ProjectManagementTab (V0-fix-7 BUG 2 派生 — 5 SF Symbol 容器)"
        )

        // symbolName 静态映射必须存在 (复用 LayoutShellView Picker Image 调用)
        XCTAssertTrue(
            code.contains("symbolName"),
            "ProjectListView ProjectManagementTab 必须有 symbolName 静态映射 (V0-fix-7 BUG 2 派生 — LayoutShellView Picker 用 tab.symbolName 间接引用)"
        )

        // 5 SF Symbol 必须都在 (不删 enum, 沿 V0-fix-4/V0-fix-6 真值)
        XCTAssertTrue(code.contains(#""folder""#),                  "ProjectListView 必须含 SF Symbol <folder> (V0-fix-7 BUG 2 派生 — 5 SF Symbol 沿用 enum)")
        XCTAssertTrue(code.contains(#""list.bullet.rectangle""#),   "ProjectListView 必须含 SF Symbol <list.bullet.rectangle> (V0-fix-7 BUG 2 派生 — 5 SF Symbol 沿用 enum)")
        XCTAssertTrue(code.contains(#""slider.horizontal.3""#),     "ProjectListView 必须含 SF Symbol <slider.horizontal.3> (V0-fix-7 BUG 2 派生 — 5 SF Symbol 沿用 enum)")
        XCTAssertTrue(code.contains(#""books.vertical""#),          "ProjectListView 必须含 SF Symbol <books.vertical> (V0-fix-7 BUG 2 派生 — 5 SF Symbol 沿用 enum)")
        XCTAssertTrue(code.contains(#""rectangle.split.3x1""#),     "ProjectListView 必须含 SF Symbol <rectangle.split.3x1> (V0-fix-7 BUG 2 派生 — 5 SF Symbol 沿用 enum)")

        // 5 tab 文字字面量必须保留 (rawValue enum, .help(tab.rawValue) tooltip 用)
        XCTAssertTrue(code.contains(#""项目""#), "ProjectListView 必须含 <项目> tab 字面量 (V0-fix-7 BUG 2 派生 — rawValue enum 保留)")
        XCTAssertTrue(code.contains(#""章节""#), "ProjectListView 必须含 <章节> tab 字面量 (V0-fix-7 BUG 2 派生 — rawValue enum 保留)")
        XCTAssertTrue(code.contains(#""设定""#), "ProjectListView 必须含 <设定> tab 字面量 (V0-fix-7 BUG 2 派生 — rawValue enum 保留)")
        XCTAssertTrue(code.contains(#""资料""#), "ProjectListView 必须含 <资料> tab 字面量 (V0-fix-7 BUG 2 派生 — rawValue enum 保留)")
        XCTAssertTrue(code.contains(#""看板""#), "ProjectListView 必须含 <看板> tab 字面量 (V0-fix-7 BUG 2 派生 — rawValue enum 保留)")
    }

    // MARK: - V0-fix-6 不回归: ChatPanelTab 4 tab 已修, 本卡不动

    /// V0-fix-6 (装机 user 8/10 17:35 OOB) 已修 ChatPanelView 4 tab —
    /// V0-fix-7 不动 ChatPanelView, 这里只验回归 (iconOnly + 4 SF
    /// Symbol + 居左 + 内容居中, 沿 V0-fix-6 Fix 4a/4b/4c 真值)。
    /// 装机 user 8/11 18:05 CUA 自验拍 ChatPanelView 4 tab 保持 ICON-only
    /// 不回归。
    func test_ChatPanelTab_already_iconOnly_unchanged() throws {
        let rawSource = try repoFile(
            "Sources/WenshuApp/Views/Chat/ChatPanelView.swift"
        )
        let code = stripSwiftComments(rawSource)

        // Fix 4a: Picker .iconOnly 保持 (V0-fix-6 已修, 本卡不回归)
        XCTAssertTrue(
            code.contains(".pickerStyle(.iconOnly)"),
            "ChatPanelView 必须保持 .pickerStyle(.iconOnly) (V0-fix-7 不回归 — 沿 V0-fix-6 Fix 4a)"
        )
        XCTAssertFalse(
            code.contains(".pickerStyle(.segmented)"),
            "ChatPanelView 不应再用 .pickerStyle(.segmented) (V0-fix-7 不回归 — 沿 V0-fix-6 Fix 4a)"
        )

        // Fix 4b: Picker .padding(.leading, 12) 居左保持
        XCTAssertTrue(
            code.contains(".padding(.leading, 12)"),
            "ChatPanelView Picker 必须保持 .padding(.leading, 12) 居左 (V0-fix-7 不回归 — 沿 V0-fix-6 Fix 4b)"
        )

        // Fix 4c: tabContent 内容居中保持
        XCTAssertTrue(
            code.contains(".frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)"),
            "ChatPanelView tabContent 必须保持 .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center) (V0-fix-7 不回归 — 沿 V0-fix-6 Fix 4c)"
        )

        // 4 SF Symbol 沿用 (chat / timeline / relationships / outline)
        XCTAssertTrue(code.contains(#""bubble.left.and.bubble.right""#), "ChatPanelView 必须含 SF Symbol <bubble.left.and.bubble.right> (V0-fix-7 不回归 — chat tab)")
        XCTAssertTrue(code.contains(#""clock.arrow.circlepath""#),      "ChatPanelView 必须含 SF Symbol <clock.arrow.circlepath> (V0-fix-7 不回归 — timeline tab)")
        XCTAssertTrue(code.contains(#""person.2""#),                    "ChatPanelView 必须含 SF Symbol <person.2> (V0-fix-7 不回归 — relationships tab)")
        XCTAssertTrue(code.contains(#""list.bullet.indent""#),          "ChatPanelView 必须含 SF Symbol <list.bullet.indent> (V0-fix-7 不回归 — outline tab)")
    }
}
