// V0Fix6LayoutTests.swift · 文枢 (Wenshu) · v0.03.0 V0-fix-6
//
// 装机 user 8/10 17:35+17:40 OOB 真机拍 V0-fix-4 (worktree 41646b01b)
// 漏修的 5 处 UI + LOGO 没生效第五波回归测试。 沿用 V0FixNLayoutTests
// 的"源码静态扫描 + 字面量断言"模式 — SwiftPM-only binary AX tree
// 抓不到, 我们的真值就是 source 里"有这个 / 没这个"。
//
// 覆盖 (10 个 test, 装机 user 17:35+17:40 OOB 真机拍):
//   Fix 1 (BUG B5-1): + 按钮走 modal sheet (`.sheet(isPresented:)`),
//                       不用 NavigationStack push
//   Fix 2 (BUG B5-2): 5 tab iconOnly Picker 升到标题栏 (HStack 内 +
//                       按钮右侧), 复用 ProjectManagementTab.symbolName
//   Fix 3 (BUG B5-3): 标题栏替换 v0.02.0 "文枢" 标题文字 (38pt HStack)
//   Fix 4 (BUG B5-4): chat 4 tab 保持 ICON-only + 内容区居中
//                       (.frame(maxWidth: .infinity, alignment: .center))
//   Fix 5 (BUG B5-5): LOGO 没生效 — 标准 Assets.xcassets/AppIcon.appiconset
//                       接入 (Contents.json + 8 PNG + Package.swift resources
//                       + Info.plist CFBundleIconName/File + applicationIconImage
//                       兜底)

import XCTest
@testable import WenshuApp

final class V0Fix6LayoutTests: XCTestCase {

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

    // MARK: - Fix 1 (B5-1): + 按钮走 modal sheet (替代 push)

    /// 装机 user 8/10 17:35 OOB 真机拍 "走弹窗不 push" (BUG B5-1):
    ///   - LayoutShellView body 加 `.sheet(isPresented: $showCreateProject)`
    ///     包裹, sheet content = `ProjectCreateView(onCreate:onCancel:)`
    ///   - 删 V0-fix-4 `navPath.append(AppRoute.createProject)` (改 sheet)
    ///   - 加 `@State private var showCreateProject: Bool = false`
    func testLayoutShellView_toolbar_usesPlusIcon() throws {
        let rawSource = try repoFile(
            "Sources/WenshuApp/Views/Layout/LayoutShellView.swift"
        )
        let code = stripSwiftComments(rawSource)
        let iconLibCode = stripSwiftComments(try repoFile(
            "Sources/WenshuApp/Views/Components/IconButton.swift"
        ))
        let iconLibSource = stripSwiftComments(try repoFile(
            "Sources/WenshuApp/Views/IconLibrary.swift"
        ))

        // V0-fix-11 修真 #2: topLeftHeaderBar 修真 38pt → 28pt (FCP Viewer 顶部 toolbar 修真)
        XCTAssertTrue(
            code.contains(".frame(height: 28)"),
            "LayoutShellView topLeftHeaderBar 必须含 .frame(height: 28) (V0-fix-11 修真 #2 — FCP Viewer 顶部 toolbar 修真)"
        )
        // V0-fix-11 修真 #1: + 按钮 SF Symbol 修真修真 <plus> (修真 V0-fix-8 plus.circle.fill)
        XCTAssertTrue(
            iconLibSource.contains(#""plus""#),
            "IconLibrary Action.newProject 必须含 SF Symbol 'plus' (V0-fix-11 修真 #1 — FCP Viewer 修真 + ICON)"
        )
        XCTAssertTrue(
            code.contains(#".help("新建项目"#),
            "LayoutShellView + 按钮必须含 .help(新建项目...) tooltip (V0-fix-11 修真 #1 — 兜中文)"
        )

        // V0-fix-6 Fix 1 新契约: + 按钮走 sheet 不走 push
        XCTAssertTrue(
            code.contains(".sheet(isPresented: $showCreateProject)"),
            "LayoutShellView body 必须含 .sheet(isPresented: $showCreateProject) (V0-fix-6 Fix 1 — + 按钮走弹窗不 push, 装机 user 17:35 OOB)"
        )
        XCTAssertTrue(
            code.contains("@State private var showCreateProject: Bool = false"),
            "LayoutShellView 必须有 @State showCreateProject (V0-fix-6 Fix 1 — sheet 显隐 state)"
        )
        XCTAssertTrue(
            code.contains("showCreateProject = true"),
            "LayoutShellView + 按钮 action 必须调 showCreateProject = true (V0-fix-6 Fix 1 — sheet 显示)"
        )

        // V0-fix-4 navPath.append(AppRoute.createProject) 必须删除 (Fix 1 替代)
        XCTAssertFalse(
            code.contains("navPath.append(AppRoute.createProject)"),
            "LayoutShellView 不应再有 navPath.append(AppRoute.createProject) (V0-fix-6 Fix 1 — + 按钮改 sheet 不 push)"
        )

        // .createProject 路由 (走 navPath) 不再被 + 按钮消费, 改为 placeholder
        // 兜底 (sheet 才是真路由, push 路径保留兼容)
        // 不强断言 destinationView(.createProject) 状态 — prompt 允许
        // placeholder 兜底.
    }

    // MARK: - Fix 2 (B5-2): 标题栏 5 tab iconOnly Picker

    /// 装机 user 8/10 17:35 OOB 真机拍 "文字按钮改 ICON" (BUG B5-2):
    ///   - LayoutShellView topLeftHeaderBar 加 5 tab iconOnly Picker
    ///     (HStack 内 + 按钮右侧), 复用 ProjectManagementTab.symbolName
    ///   - `.pickerStyle(.iconOnly)` (走 PickerStyle+IconOnly alias)
    ///   - 5 SF Symbol (folder / list.bullet.rectangle / slider.horizontal.3
    ///                / books.vertical / rectangle.split.3x1) 沿用 enum
    ///   - 共享同一 @State activeTab (FCP toolbar 范式)
    func testLayoutShellView_toolbar_has5TabIcons() throws {
        let rawSource = try repoFile(
            "Sources/WenshuApp/Views/Layout/LayoutShellView.swift"
        )
        let code = stripSwiftComments(rawSource)

        // V0-fix-11 修真 #2: 5 tab 修真 HStack + IconButton (修真
        // V0-fix-6 Fix 2 Picker(.iconOnly) + V0-fix-8 修真 #2 +
        // V0-fix-10.1 修真 #3 衍生). 不再含 Picker / .pickerStyle.
        XCTAssertFalse(
            code.contains("Picker(\"\", selection: $projectListActiveTab)"),
            "LayoutShellView 标题栏不应再有 Picker(\"\", selection: $projectListActiveTab) (V0-fix-11 修真 #2 — 改 HStack+IconButton)"
        )
        XCTAssertFalse(
            code.contains(".pickerStyle(.iconOnly)"),
            "LayoutShellView 标题栏不应再用 .pickerStyle(.iconOnly) (V0-fix-11 修真 #2 — HStack+IconButton)"
        )
        XCTAssertTrue(
            code.contains("IconButton("),
            "LayoutShellView 标题栏必须用 IconButton( 组件 (V0-fix-11 修真 #2 — 全局 ICON 按钮组件)"
        )
        XCTAssertTrue(
            code.contains("IconLibrary.tab(tab)"),
            "LayoutShellView 标题栏必须用 IconLibrary.tab(tab) 修真 5 tab SF Symbol (V0-fix-11 修真 #2 — IconLibrary 修真)"
        )

        // activeTab state 顶层持有 (V0-fix-6 Fix 5 → V0-fix-8 修真后沿用)
        XCTAssertTrue(
            code.contains("@State private var activeTab: ProjectManagementTab"),
            "LayoutShellView 必须有 @State activeTab (V0-fix-6 Fix 5 — 标题栏与 ProjectListView 共享 activeTab)"
        )
    }

    // MARK: - Fix 2 (B5-2): ProjectListView 5 tab 修真 #2 + V0-fix-8 派生

    /// V0-fix-6 Fix 2 历史: 5 tab Picker.segmented 文字标签 + Image
    /// (systemName: tab.symbolName) — 装机 user 8/10 17:35 OOB 真机拍
    /// "5 tab 文字改 ICON" (BUG B5-2)。
    ///
    /// V0-fix-8 (装机 user 8/11 16:20 真机拍红字 "5 tab 改文字按钮为
    /// ICON"): 修真 #2 — 5 SF Symbol 沿 AIF 16:20 截图重定义真值:
    /// folder / doc.text / gearshape / archive / square.grid.3x3 (替换
    /// V0-fix-6 字面量)。 Picker 整段已迁 LayoutShellView.topLeftHeaderBar
    /// (沿 V0-fix-5), ProjectListView 不再含 Picker (仅保留 enum +
    /// 5 SF Symbol 字面量 + activeTab @Binding)。 本测试沿 V0-fix-8
    /// 修真更新断言。
    func testProjectListView_5tab_usesIcons() throws {
        let rawSource = try repoFile(
            "Sources/WenshuApp/Views/ProjectListView.swift"
        )
        let code = stripSwiftComments(rawSource)

        // V0-fix-8 修真 #2 + V0-fix-5 Fix E: Picker 修真后不在 ProjectListView
        // (5 tab Picker 升 LayoutShellView.topLeftHeaderBar, ProjectListView
        // 仅保留 enum + SF Symbol 字面量)
        XCTAssertFalse(
            code.contains(".pickerStyle(.segmented)"),
            "ProjectListView 不应再有 .pickerStyle(.segmented) (V0-fix-8 修真 #2 — Picker 已迁 LayoutShellView header bar)"
        )

        // Picker 内容改 Image(systemName:) 删除 (修真 #2 后 Picker 整段不在
        // ProjectListView)
        XCTAssertFalse(
            code.contains("Text(tab.rawValue).tag(tab)"),
            "ProjectListView 不应再有 Text(tab.rawValue).tag(tab) (V0-fix-6 Fix 2 — 改 Image SF Symbol, V0-fix-8 修真 #2 Picker 整段迁走)"
        )

        // 5 SF Symbol (V0-fix-8 修真 #2 沿 AIF 16:20 截图重定义真值)
        XCTAssertTrue(code.contains(#""folder""#),              "ProjectListView 必须含 SF Symbol <folder> (V0-fix-8 修真 #2 — AIF 16:20 项目 tab)")
        XCTAssertTrue(code.contains(#""doc.text""#),            "ProjectListView 必须含 SF Symbol <doc.text> (V0-fix-8 修真 #2 — AIF 16:20 章节 tab)")
        XCTAssertTrue(code.contains(#""gearshape""#),           "ProjectListView 必须含 SF Symbol <gearshape> (V0-fix-8 修真 #2 — AIF 16:20 设定 tab)")
        XCTAssertTrue(code.contains(#""archive""#),             "ProjectListView 必须含 SF Symbol <archive> (V0-fix-8 修真 #2 — AIF 16:20 资料 tab)")
        XCTAssertTrue(code.contains(#""square.grid.3x3""#),     "ProjectListView 必须含 SF Symbol <square.grid.3x3> (V0-fix-8 修真 #2 — AIF 16:20 看板 tab)")

        // V0-fix-6 字面量修真后不应再出现 (AIF 16:20 替换)
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

        // Fix 5: activeTab 改 @Binding (沿 V0-fix-6 Fix 5 保留)
        XCTAssertTrue(
            code.contains("@Binding var activeTab: ProjectManagementTab"),
            "ProjectListView 必须有 @Binding var activeTab (V0-fix-6 Fix 5 — 共享顶层 state)"
        )
        XCTAssertFalse(
            code.contains("@State private var activeTab: ProjectManagementTab = .projects"),
            "ProjectListView 不应再有 @State activeTab (V0-fix-6 Fix 5 — 顶层持有, 此处改 @Binding)"
        )
    }

    // MARK: - Fix 1 (B5-1): ProjectCreateView 不改 form/focus/frame

    /// 装机 user 8/10 17:35 OOB 真机拍 "走弹窗不 push" (BUG B5-1
    /// ProjectCreateView 部分): sheet 弹窗内容不动 form, focus state
    /// 保留, 540x480 frame 硬固定 (沿 V0-fix-1 Fix D).
    func testProjectCreateView_unchanged_formFocusFrame() throws {
        let rawSource = try repoFile(
            "Sources/WenshuApp/Views/ProjectCreateView.swift"
        )
        let code = stripSwiftComments(rawSource)

        // form 必含 4 字段: name / style / verbosity / tagsText
        XCTAssertTrue(
            code.contains("@State private var name: String = \"\""),
            "ProjectCreateView 必须含 @State name (V0-fix-6 Fix 1 — sheet 弹窗内容不动 form)"
        )
        XCTAssertTrue(
            code.contains("@State private var style: String = \"严肃\""),
            "ProjectCreateView 必须含 @State style = 严肃 (V0-fix-6 Fix 1 — sheet 弹窗内容不动 form)"
        )
        XCTAssertTrue(
            code.contains("@State private var verbosity: Double = 5"),
            "ProjectCreateView 必须含 @State verbosity = 5 (V0-fix-6 Fix 1 — sheet 弹窗内容不动 form)"
        )
        XCTAssertTrue(
            code.contains("@State private var tagsText: String = \"\""),
            "ProjectCreateView 必须含 @State tagsText (V0-fix-6 Fix 1 — sheet 弹窗内容不动 form)"
        )

        // focus state 保留 (WO-006 拍板)
        XCTAssertTrue(
            code.contains("@FocusState private var nameFocused: Bool"),
            "ProjectCreateView 必须含 @FocusState nameFocused (V0-fix-6 Fix 1 — focus state 沿用 WO-006)"
        )
        XCTAssertTrue(
            code.contains("@FocusState private var tagsFocused: Bool"),
            "ProjectCreateView 必须含 @FocusState tagsFocused (V0-fix-6 Fix 1 — focus state 沿用 WO-006)"
        )

        // 540x480 frame 硬固定 (V0-fix-1 Fix D)
        XCTAssertTrue(
            code.contains(".frame(width: 540, height: 480)"),
            "ProjectCreateView 必须含 .frame(width: 540, height: 480) (V0-fix-6 Fix 1 — 硬固定 540x480 沿用 V0-fix-1 Fix D)"
        )

        // WindowActivation.forceKeyToWenshuSheet 保留 (WO-007 拍板)
        XCTAssertTrue(
            code.contains("WindowActivation.forceKeyToWenshuSheet()"),
            "ProjectCreateView 必须调 WindowActivation.forceKeyToWenshuSheet() (V0-fix-6 Fix 1 — WO-007 沿用)"
        )
    }

    // MARK: - Fix 4 (B5-4): ChatPanelView 4 tab 修真 #3 Picker → HStack+Button + 内容居中

    /// V0-fix-6 Fix 4a + Fix 4b 历史: Picker `.iconOnly` + `.padding(.leading,
    /// 12)` 居左 (沿 V0-fix-4 Fix 4 + Fix 6)。
    ///
    /// V0-fix-8 (装机 user 8/11 16:20 真机拍红字 "所有 ICON 按钮, 只保留
    /// ICON, 不要矩形背景, 仿 FCP"): 修真 #3 — `.pickerStyle(.iconOnly)`
    /// (走 SegmentedPickerStyle) 仍有 macOS 系统矩形分段框背景, 不符
    /// 红字"不要矩形背景"。 真修真: Picker 整段迁 HStack + 4 Button
    /// (Image) + `.buttonStyle(.plain)`, 纯 ICON 无矩形背景。 本测试沿
    /// V0-fix-8 修真更新断言 (Pick Picker → Button 形态), 历史 `.pickerStyle
    /// (.iconOnly)` 字面量不再出现。 V0-fix-6 Fix 4b (居左) + Fix 4c (内容
    /// 居中) 修真后保留。
    func testChatPanelView_4tab_iconOnly() throws {
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

        // V0-fix-6 Fix 4b: 4 tab 居左沿用 (修真 #3 不动居左对齐)
        XCTAssertTrue(
            code.contains(".padding(.leading, 12)"),
            "ChatPanelView HStack 必须用 .padding(.leading, 12) 居左 (V0-fix-6 Fix 4b — 沿用 V0-fix-4 Fix 6, V0-fix-8 修真 #3 保留)"
        )

        // 4 SF Symbol 沿用 (AIF 未列新值, 修真仅 tab 渲染方式)
        XCTAssertTrue(code.contains(#""bubble.left.and.bubble.right""#), "ChatPanelView 必须含 SF Symbol <bubble.left.and.bubble.right> (V0-fix-6 Fix 4a — 4 tab 图标)")
        XCTAssertTrue(code.contains(#""clock.arrow.circlepath""#),      "ChatPanelView 必须含 SF Symbol <clock.arrow.circlepath> (V0-fix-6 Fix 4a — 4 tab 图标)")
        XCTAssertTrue(code.contains(#""person.2""#),                    "ChatPanelView 必须含 SF Symbol <person.2> (V0-fix-6 Fix 4a — 4 tab 图标)")
        XCTAssertTrue(code.contains(#""list.bullet.indent""#),          "ChatPanelView 必须含 SF Symbol <list.bullet.indent> (V0-fix-6 Fix 4a — 4 tab 图标)")
    }

    /// Fix 4c: tabContent 居中 (`.frame(maxWidth: .infinity, alignment: .center)`).
    func testChatPanelView_content_centered() throws {
        let rawSource = try repoFile(
            "Sources/WenshuApp/Views/Chat/ChatPanelView.swift"
        )
        let code = stripSwiftComments(rawSource)

        XCTAssertTrue(
            code.contains(".frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)"),
            "ChatPanelView tabContent 必须含 .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center) (V0-fix-6 Fix 4c — 内容区居中, 装机 user 17:35 OOB)"
        )
    }

    // MARK: - Fix 5 (B5-5): LOGO 套件标准 .appiconset 接入

    /// 装机 user 8/10 17:40 OOB 真机拍 "LOGO 没生效" (BUG B5-5):
    ///   - 标准 Assets.xcassets/AppIcon.appiconset/ 接入
    ///     (Apple HIG + Xcode 16 推荐姿势)
    ///   - Contents.json (10 slots, 8 PNGs 复用) + 8 PNG 文件全在
    ///   - Assets.xcassets/Contents.json (root metadata)
    func testAppIcon_assets_exist() throws {
        // 1. Assets.xcassets/Contents.json (root metadata)
        let rootContents = try repoFile(
            "Sources/WenshuApp/Assets.xcassets/Contents.json"
        )
        XCTAssertTrue(
            rootContents.contains("\"author\" : \"xcode\""),
            "Assets.xcassets/Contents.json 必须含 info.author = xcode (V0-fix-6 Fix 5 — Xcode 标准 metadata)"
        )
        XCTAssertTrue(
            rootContents.contains("\"version\" : 1"),
            "Assets.xcassets/Contents.json 必须含 info.version = 1 (V0-fix-6 Fix 5 — Xcode 标准 metadata)"
        )

        // 2. AppIcon.appiconset/Contents.json (10 slots)
        let iconContents = try repoFile(
            "Sources/WenshuApp/Assets.xcassets/AppIcon.appiconset/Contents.json"
        )
        XCTAssertTrue(
            iconContents.contains("\"idiom\" : \"mac\""),
            "AppIcon.appiconset/Contents.json 必须含 Mac idiom (V0-fix-6 Fix 5 — Apple HIG macOS AppIcon 规范)"
        )
        XCTAssertTrue(
            iconContents.contains("\"filename\" : \"wenshu-icon-16.png\""),
            "AppIcon.appiconset/Contents.json 必须含 16x16 槽位 (V0-fix-6 Fix 5 — Mac 最小尺寸)"
        )
        XCTAssertTrue(
            iconContents.contains("\"filename\" : \"wenshu-icon-1024.png\""),
            "AppIcon.appiconset/Contents.json 必须含 512x512 @2x (1024) 槽位 (V0-fix-6 Fix 5 — Mac master 尺寸)"
        )

        // 3. 8 PNG 文件必须在
        let cwd = FileManager.default.currentDirectoryPath
        let iconDir = cwd + "/Sources/WenshuApp/Assets.xcassets/AppIcon.appiconset"
        let fileManager = FileManager.default
        let requiredPNGs = [
            "wenshu-icon-16.png",
            "wenshu-icon-32.png",
            "wenshu-icon-48.png",
            "wenshu-icon-64.png",
            "wenshu-icon-128.png",
            "wenshu-icon-256.png",
            "wenshu-icon-512.png",
            "wenshu-icon-1024.png"
        ]
        for pngName in requiredPNGs {
            let path = iconDir + "/" + pngName
            XCTAssertTrue(
                fileManager.fileExists(atPath: path),
                "AppIcon.appiconset/\(pngName) 必须存在 (V0-fix-6 Fix 5 — Mac 8 尺寸 PNG 全套)"
            )
        }
    }

    /// Fix 5: Info.plist 必须含 CFBundleIconName + CFBundleIconFile
    /// (Apple HIG AppIcon 资源名 + legacy fallback).
    func testInfoPlist_iconKeys() throws {
        let rawSource = try repoFile(
            "Sources/WenshuApp/Resources/Info.plist"
        )

        XCTAssertTrue(
            rawSource.contains("<key>CFBundleIconName</key>"),
            "Info.plist 必须含 CFBundleIconName (V0-fix-6 Fix 5 — .appiconset 资源名)"
        )
        XCTAssertTrue(
            rawSource.contains("<string>AppIcon</string>"),
            "Info.plist 必须含 AppIcon 资源名 (V0-fix-6 Fix 5 — 标准命名)"
        )
        XCTAssertTrue(
            rawSource.contains("<key>CFBundleIconFile</key>"),
            "Info.plist 必须含 CFBundleIconFile (V0-fix-6 Fix 5 — Mac legacy fallback)"
        )

        // plutil -lint 静态校验 (双保险 — 真值在 SDK 编进 bundle 前正确)
        let plistPath = FileManager.default.currentDirectoryPath + "/Sources/WenshuApp/Resources/Info.plist"
        let plistProcess = Process()
        plistProcess.executableURL = URL(fileURLWithPath: "/usr/bin/plutil")
        plistProcess.arguments = ["-lint", plistPath]
        let pipe = Pipe()
        plistProcess.standardOutput = pipe
        plistProcess.standardError = pipe
        try plistProcess.run()
        plistProcess.waitUntilExit()
        XCTAssertEqual(
            plistProcess.terminationStatus, 0,
            "Info.plist 必须 plutil -lint 通过 (V0-fix-6 Fix 5 — plist 语法校验)"
        )
    }

    /// Fix 5: Package.swift resources: [.copy("Assets.xcassets")] 接入.
    func testPackage_resources_assets() throws {
        let rawSource = try repoFile(
            "Package.swift"
        )
        let code = stripSwiftComments(rawSource)

        XCTAssertTrue(
            code.contains("resources:") && code.contains(#".copy("Assets.xcassets")"#),
            "Package.swift 必须含 resources: [.copy(\"Assets.xcassets\")] (V0-fix-6 Fix 5 — .appiconset 资源接入)"
        )

        // linkerSettings (sectcreate __info_plist) 必须保留 — V0-fix-3 拍
        XCTAssertTrue(
            code.contains("__info_plist"),
            "Package.swift linkerSettings 必须保留 __info_plist (V0-fix-6 Fix 5 — 沿用 V0-fix-3 sectcreate, 改 = 撞 approval gate)"
        )

        // Resources/Info.plist exclude 必须保留 (跟 linkerSettings 兼容)
        XCTAssertTrue(
            code.contains("\"Resources/Info.plist\""),
            "Package.swift exclude 必须保留 Resources/Info.plist (V0-fix-6 Fix 5 — SwiftPM 禁止 Info.plist 作 top-level resource)"
        )
    }

    /// Fix 5: AppDelegate applicationIconImage 兜底 — 显式
    /// `NSApp.applicationIconImage = NSImage(contentsOfFile:)` 加载 .icns
    /// (SwiftPM 纯命令行 build 不跑 actool, 兜底必要).
    func testAppDelegate_applicationIconImage_fallback() throws {
        let rawSource = try repoFile(
            "Sources/WenshuApp/App.swift"
        )
        let code = stripSwiftComments(rawSource)

        XCTAssertTrue(
            code.contains("NSApp.applicationIconImage"),
            "App.swift 必须含 NSApp.applicationIconImage (V0-fix-6 Fix 5 — applicationIconImage 兜底)"
        )
        XCTAssertTrue(
            code.contains("NSImage(contentsOfFile:"),
            "App.swift 必须含 NSImage(contentsOfFile:) (V0-fix-6 Fix 5 — 显式加载 .icns)"
        )
        XCTAssertTrue(
            code.contains("AppIcon.icns"),
            "App.swift 必须引用 AppIcon.icns (V0-fix-6 Fix 5 — 兜底资源名)"
        )
    }

    // MARK: - B5 综合验证: 5 改一致性

    /// V0-fix-6 5 改一致性 — 不应再含 V0-fix-4 `navPath.append(AppRoute.createProject)`
    /// (改 sheet), 不应再用 Text 文案 5 tab (改 Image), 不应缺 AppIcon 资源
    /// (改 .appiconset 标准接入), chat 内容区应居中.
    func testV0Fix6_consistency_5fixes() throws {
        let layoutShell = try stripSwiftComments(repoFile(
            "Sources/WenshuApp/Views/Layout/LayoutShellView.swift"
        ))
        let projectList = try stripSwiftComments(repoFile(
            "Sources/WenshuApp/Views/ProjectListView.swift"
        ))
        let chatPanel = try stripSwiftComments(repoFile(
            "Sources/WenshuApp/Views/Chat/ChatPanelView.swift"
        ))
        let infoPlist = try repoFile(
            "Sources/WenshuApp/Resources/Info.plist"
        )
        let package = try stripSwiftComments(repoFile(
            "Package.swift"
        ))
        let iconLib = try stripSwiftComments(repoFile(
            "Sources/WenshuApp/Views/IconLibrary.swift"
        ))

        // Fix 1: + 按钮改 sheet (沿 V0-fix-6 真值, V0-fix-11 修真 #1 修真修真修真修真)
        XCTAssertTrue(layoutShell.contains(".sheet(isPresented: $showCreateProject)"),
                      "V0-fix-6 Fix 1 — + 按钮 sheet 弹窗 (装机 user 17:35 OOB)")
        XCTAssertFalse(layoutShell.contains("navPath.append(AppRoute.createProject)"),
                       "V0-fix-6 Fix 1 — navPath.append(createProject) 已删 (改 sheet)")

        // V0-fix-11 修真 #2: 5 tab 修真 HStack+IconButton (修真 V0-fix-6 Fix 2 Picker(.iconOnly))
        XCTAssertTrue(layoutShell.contains("IconButton("),
                      "V0-fix-11 修真 #2 — 标题栏 5 tab HStack+IconButton")
        XCTAssertFalse(layoutShell.contains(".pickerStyle(.iconOnly)"),
                      "V0-fix-11 修真 #2 — 标题栏 不应再有 Picker(.iconOnly)")
        XCTAssertTrue(layoutShell.contains("IconLibrary.tab(tab)"),
                      "V0-fix-11 修真 #2 — 标题栏 IconLibrary.tab(tab) 修真 5 tab SF Symbol")

        // Fix 4: chat 内容区居中
        XCTAssertTrue(chatPanel.contains("alignment: .center"),
                      "V0-fix-6 Fix 4c — chat tabContent 居中 (装机 user 17:35 OOB)")

        // Fix 5: LOGO 标准 .appiconset 接入
        XCTAssertTrue(infoPlist.contains("CFBundleIconName"),
                      "V0-fix-6 Fix 5 — Info.plist CFBundleIconName")
        XCTAssertTrue(package.contains(#".copy("Assets.xcassets")"#),
                      "V0-fix-6 Fix 5 — Package.swift resources Assets.xcassets")
    }
}
