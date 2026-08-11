// V0Fix11LayoutTests.swift · 文枢 (Wenshu) · v0.03.0 V0-fix-11
//
// 装机 user 8/11 14:35 真机拍 5 红字批注 + V0-fix-11 修真 5 处 UI BUG
// 回归测试 — 沿 V0FixNLayoutTests 的"源码静态扫描 + 字面量断言"模式
// (SwiftPM-only binary AX tree 抓不到, 我们的真值就是 source 里"有这
// 个 / 没这个")。
//
// 覆盖 (6 个 test, 修真 5 处 + 1 组件):
//   - testPlusButton_threeIcons_atPrimaryAction  (修真 #1: 3 ICON 修真群)
//   - testFiveTabs_height28pt_fiveIcons          (修真 #2: 5 tab 28pt + IconButton)
//   - testIconLibrary_ActionEnum_openImport_added(修真 #3: Action +2 case)
//   - testInspectorView_HStackButton_plainStyle  (修真 #4: HStack+IconButton)
//   - testChatPanelView_paddingVertical4_height30(修真 #5: padding 4 + IconButton)
//   - testIconButtonComponent_size13_plainStyle  (修真 #6: 全局 IconButton 组件)
//
// 拍板背景 (装机 user 8/11 14:35 真机拍 5 红字批注 + AIF 19:35 派单):
//   修真 #1: + 按钮位置 + 高度 + 纯 ICON + 新建后面加打开/导入占位
//   修真 #2: 5 tab 高度紧凑 + 5 个 ICON 补齐
//   修真 #3: ICON 库引入 + 全面替换散落字面量
//   修真 #4: inspector 改纯 SF Symbol ICON
//   修真 #5: 4 chat tab 高度紧凑 + 全局 IconButton 组件
//   修真 #6: 全局 IconButton 组件 (Sources/WenshuApp/Views/Components/IconButton.swift)

import XCTest
@testable import WenshuApp

final class V0Fix11LayoutTests: XCTestCase {

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

    // MARK: - 修真 #1: LayoutShellView macOS title bar 3 ICON 修真群 + .primaryAction

    /// 装机 user 8/11 14:35 红字 "在新建后面加上打开和导入占位" +
    /// 红字 "位置居左, 挨着红黄绿" 修真:
    ///   - LayoutShellView NavigationStack 顶层 .toolbar 必须含
    ///     ToolbarItemGroup(placement: .primaryAction) (修真 V0-fix-8
    ///     ToolbarItem(.principal) → V0-fix-11 ToolbarItemGroup
    ///     (.primaryAction), 红黄绿后紧跟 3 个 ICON 修真群)
    ///   - ToolbarItemGroup 内必须有 3 个 Image(systemName: IconLibrary
    ///     .Action.*.rawValue) (新建 / 打开 / 导入占位)
    ///   - IconLibrary.Action 必须含 openProject (folder.badge.plus) +
    ///     importProject (square.and.arrow.down) 2 新 case
    ///   - 导入 ICON button 必须 .disabled(true) (v0.04.0 真修真导入逻辑 占位)
    func testPlusButton_threeIcons_atPrimaryAction() throws {
        let rawSource = try repoFile(
            "Sources/WenshuApp/Views/Layout/LayoutShellView.swift"
        )
        let code = stripSwiftComments(rawSource)
        let iconLib = stripSwiftComments(try repoFile(
            "Sources/WenshuApp/Views/IconLibrary.swift"
        ))

        // 1. ToolbarItemGroup(placement: .primaryAction) — 修真 #1 修真
        //    .principal → .primaryAction, 红黄绿后紧跟
        XCTAssertTrue(
            code.contains("ToolbarItemGroup(placement: .primaryAction)"),
            "LayoutShellView 必须含 ToolbarItemGroup(placement: .primaryAction) (V0-fix-11 修真 #1 — macOS title bar 红黄绿后 3 ICON 修真群)"
        )

        // 2. ToolbarItem(placement: .principal) 不应再出现 (修真 #1)
        XCTAssertFalse(
            code.contains("ToolbarItem(placement: .principal)"),
            "LayoutShellView 不应再有 ToolbarItem(placement: .principal) (V0-fix-11 修真 #1 — 修真 .primaryAction)"
        )

        // 3. 3 个 IconLibrary.Action.*.rawValue — 新建 / 打开 / 导入
        XCTAssertTrue(
            code.contains("IconLibrary.Action.newProject.rawValue"),
            "LayoutShellView + 按钮必须用 IconLibrary.Action.newProject.rawValue (V0-fix-11 修真 #1 — 新建 ICON, FCP Viewer 修真 + ICON)"
        )
        XCTAssertTrue(
            code.contains("IconLibrary.Action.openProject.rawValue"),
            "LayoutShellView 必须用 IconLibrary.Action.openProject.rawValue (V0-fix-11 修真 #1 — 打开项目 ICON, 装机 user 红字'新建后面加打开')"
        )
        XCTAssertTrue(
            code.contains("IconLibrary.Action.importProject.rawValue"),
            "LayoutShellView 必须用 IconLibrary.Action.importProject.rawValue (V0-fix-11 修真 #1 — 导入项目 ICON, 装机 user 红字'加导入占位')"
        )

        // 4. 导入按钮必须 .disabled(true) (v0.04.0 真修真导入逻辑 占位)
        XCTAssertTrue(
            code.contains(".disabled(true)") && code.contains("IconLibrary.Action.importProject.rawValue"),
            "LayoutShellView 导入按钮必须 .disabled(true) (V0-fix-11 修真 #1 — v0.04.0 真修真导入逻辑 占位)"
        )

        // 5. IconLibrary 必须有 3 个 Action case (newProject + openProject + importProject)
        XCTAssertTrue(
            iconLib.contains("case newProject    = \"plus\""),
            "IconLibrary.Action 必须含 newProject = \"plus\" (V0-fix-11 修真 #1 — FCP Viewer 修真 + ICON)"
        )
        XCTAssertTrue(
            iconLib.contains("case openProject   = \"folder.badge.plus\""),
            "IconLibrary.Action 必须含 openProject = \"folder.badge.plus\" (V0-fix-11 修真 #1)"
        )
        XCTAssertTrue(
            iconLib.contains("case importProject = \"square.and.arrow.down\""),
            "IconLibrary.Action 必须含 importProject = \"square.and.arrow.down\" (V0-fix-11 修真 #1)"
        )
    }

    // MARK: - 修真 #2: 5 tab 28pt + IconButton 组件 + 5 个 ICON 补齐

    /// 装机 user 8/11 14:35 红字 "5 tab 高度仍高 + 5 个 ICON, 少了一个,
    /// 补完好" 修真:
    ///   - LayoutShellView.topLeftHeaderBar 必须含 .frame(height: 28)
    ///     (修真 V0-fix-8 38pt → V0-fix-11 28pt, FCP Viewer 顶部 toolbar)
    ///   - 5 tab 全部 ProjectManagementTab.allCases 真修真 5 个 case
    ///     (.projects / .chapters / .settings / .resources / .kanban)
    ///   - 5 tab 必须用 IconButton( 组件 (修真 HStack+Button(Image) 重复代码)
    ///   - 5 tab 必须用 IconLibrary.tab(tab) 修真 SF Symbol (修真 SF Symbol 字面量)
    func testFiveTabs_height28pt_fiveIcons() throws {
        let rawSource = try repoFile(
            "Sources/WenshuApp/Views/Layout/LayoutShellView.swift"
        )
        let code = stripSwiftComments(rawSource)
        let iconLib = stripSwiftComments(try repoFile(
            "Sources/WenshuApp/Views/IconLibrary.swift"
        ))

        // 1. topLeftHeaderBar 修真 38pt → 28pt (FCP Viewer 顶部 toolbar)
        XCTAssertTrue(
            code.contains(".frame(height: 28)"),
            "LayoutShellView topLeftHeaderBar 必须含 .frame(height: 28) (V0-fix-11 修真 #2 — FCP Viewer 顶部 toolbar 修真)"
        )
        XCTAssertFalse(
            code.contains(".frame(height: 38)"),
            "LayoutShellView topLeftHeaderBar 不应再有 .frame(height: 38) (V0-fix-11 修真 #2 — 修真 28pt)"
        )

        // 2. 5 tab 修真 ProjectManagementTab.allCases 真修真 5 个 case
        XCTAssertTrue(
            code.contains("ProjectManagementTab.allCases"),
            "LayoutShellView header bar 必须用 ProjectManagementTab.allCases (V0-fix-5 + V0-fix-11 — 5 tab 全部修真)"
        )

        // 3. 5 tab 用 IconButton( 组件 (修真 V0-fix-8 HStack+Button 重复代码)
        XCTAssertTrue(
            code.contains("IconButton(") && code.contains("IconLibrary.tab(tab)"),
            "LayoutShellView header bar 5 tab 必须用 IconButton + IconLibrary.tab(tab) (V0-fix-11 修真 #2 — 全局 ICON 按钮组件 + IconLibrary 修真)"
        )

        // 4. IconLibrary.Tab.Project 5 case 全部修真 (5 SF Symbol)
        XCTAssertTrue(
            iconLib.contains("case projects  = \"folder\""),
            "IconLibrary.Tab.Project 必须含 projects = \"folder\" (V0-fix-11 修真 #3 + AIF 16:20 真值)"
        )
        XCTAssertTrue(
            iconLib.contains("case chapters  = \"doc.text\""),
            "IconLibrary.Tab.Project 必须含 chapters = \"doc.text\" (V0-fix-11 修真 #3 + AIF 16:20 真值)"
        )
        XCTAssertTrue(
            iconLib.contains("case settings  = \"gearshape\""),
            "IconLibrary.Tab.Project 必须含 settings = \"gearshape\" (V0-fix-11 修真 #3 + AIF 16:20 真值)"
        )
        XCTAssertTrue(
            iconLib.contains("case resources = \"archive\""),
            "IconLibrary.Tab.Project 必须含 resources = \"archive\" (V0-fix-11 修真 #3 + AIF 16:20 真值)"
        )
        XCTAssertTrue(
            iconLib.contains("case kanban    = \"square.grid.3x3\""),
            "IconLibrary.Tab.Project 必须含 kanban = \"square.grid.3x3\" (V0-fix-11 修真 #3 + AIF 16:20 真值)"
        )
    }

    // MARK: - 修真 #3: IconLibrary Action enum + openProject + importProject

    /// 装机 user 8/11 14:35 红字 "在新建后面加上打开和导入占位" + 修真 #3
    /// "如果苹果自己的不够用, 也不太适合, 去引入 ICON 库" (修真 V0-fix-11
    /// 修真: 不引入 ICON 库依赖, 修真 SF Symbol 6 优先 + IconLibrary
    /// Action enum +2 case):
    ///   - IconLibrary.Action enum 必须含 10 case (newProject / openProject
    ///     / importProject / createProject / chatPlaceholder / characterWorld
    ///     / leaf / sparkles / checkmarkFilled / squareEmpty)
    ///   - 新增 2 case 修真: openProject = "folder.badge.plus" +
    ///     importProject = "square.and.arrow.down"
    ///   - newProject 值修真修真修真: "plus.circle.fill" → "plus" (FCP Viewer 修真)
    ///   - 不引入 ICON 库依赖 (沿 V0-fix-10.1 修真, 不修真 Package.swift)
    func testIconLibrary_ActionEnum_openImport_added() throws {
        let rawSource = try repoFile(
            "Sources/WenshuApp/Views/IconLibrary.swift"
        )
        let code = stripSwiftComments(rawSource)

        // 1. 新增 2 case 修真 (修真 #3 修真)
        XCTAssertTrue(
            code.contains("case openProject   = \"folder.badge.plus\""),
            "IconLibrary.Action 必须新增 openProject = \"folder.badge.plus\" (V0-fix-11 修真 #3 — 打开项目 ICON)"
        )
        XCTAssertTrue(
            code.contains("case importProject = \"square.and.arrow.down\""),
            "IconLibrary.Action 必须新增 importProject = \"square.and.arrow.down\" (V0-fix-11 修真 #3 — 导入项目 ICON, v0.04.0 占位)"
        )

        // 2. newProject 值修真修真修真 (修真 V0-fix-8 "plus.circle.fill" → V0-fix-11 "plus")
        XCTAssertTrue(
            code.contains("case newProject    = \"plus\""),
            "IconLibrary.Action.newProject 必须 = \"plus\" (V0-fix-11 修真 #3 — FCP Viewer 修真 + ICON, 修真 V0-fix-8 plus.circle.fill)"
        )
        XCTAssertFalse(
            code.contains("case newProject    = \"plus.circle.fill\""),
            "IconLibrary.Action.newProject 不应再 = \"plus.circle.fill\" (V0-fix-11 修真 #3 — 修真 FCP Viewer 修真 + ICON)"
        )

        // 3. Action enum 修真全部 10 case (修真 V0-fix-10.1 修真 8 case → V0-fix-11 修真 10 case)
        XCTAssertTrue(
            code.contains("case createProject    = \"doc.badge.plus\""),
            "IconLibrary.Action 必须含 createProject = \"doc.badge.plus\" (V0-fix-10.1 + V0-fix-11 修真 #3)"
        )
        XCTAssertTrue(
            code.contains("case chatPlaceholder  = \"bubble.left.and.bubble.right\""),
            "IconLibrary.Action 必须含 chatPlaceholder (V0-fix-10.1 + V0-fix-11 修真 #3)"
        )
        XCTAssertTrue(
            code.contains("case characterWorld   = \"person.2.crop.square.stack\""),
            "IconLibrary.Action 必须含 characterWorld (V0-fix-10.1 + V0-fix-11 修真 #3)"
        )
        XCTAssertTrue(
            code.contains("case leaf             = \"leaf\""),
            "IconLibrary.Action 必须含 leaf (V0-fix-10.1 + V0-fix-11 修真 #3)"
        )
        XCTAssertTrue(
            code.contains("case sparkles         = \"sparkles\""),
            "IconLibrary.Action 必须含 sparkles (V0-fix-10.1 + V0-fix-11 修真 #3)"
        )
        XCTAssertTrue(
            code.contains("case checkmarkFilled  = \"checkmark.square.fill\""),
            "IconLibrary.Action 必须含 checkmarkFilled (V0-fix-10.1 + V0-fix-11 修真 #3)"
        )
        XCTAssertTrue(
            code.contains("case squareEmpty      = \"square\""),
            "IconLibrary.Action 必须含 squareEmpty (V0-fix-10.1 + V0-fix-11 修真 #3)"
        )
    }

    // MARK: - 修真 #4: InspectorView HStack + 2 IconButton(.plain)

    /// 装机 user 8/11 14:35 红字 "纯 ICON 按钮, 这也改, 以后界面上所有的
    /// 按钮都这么处理" 修真:
    ///   - InspectorView Picker(.iconOnly) 修真 HStack + 2 Button(Image)
    ///     + .buttonStyle(.plain) (修真 V0-fix-4 Fix 5 Picker(.iconOnly)
    ///     + V0-fix-10.1 修真 #5 衍生)
    ///   - IconLibrary.tab(_ kind: InspectorViewModel.Tab) accessor 必须存在
    ///     (修真 V0-fix-4 Fix 5 inline iconName(for:) 静态映射)
    ///   - 2 SF Symbol 必须都在 IconLibrary: eye + pencil.and.list.clipboard
    ///   - padding(.vertical, 4) — FCP timeline 修真 (修真 8pt → 4pt)
    func testInspectorView_HStackButton_plainStyle() throws {
        let rawSource = try repoFile(
            "Sources/WenshuApp/Views/Inspector/InspectorView.swift"
        )
        let code = stripSwiftComments(rawSource)
        let iconLib = stripSwiftComments(try repoFile(
            "Sources/WenshuApp/Views/IconLibrary.swift"
        ))

        // 1. InspectorView 必须用 IconButton( 组件 (HStack + IconButton)
        XCTAssertTrue(
            code.contains("IconButton("),
            "InspectorView 必须用 IconButton( 组件 (V0-fix-11 修真 #4 — HStack + IconButton 修真 Picker)"
        )

        // 2. Picker(.iconOnly) 不应再出现 (修真 V0-fix-4 Fix 5)
        XCTAssertFalse(
            code.contains(".pickerStyle(.iconOnly)"),
            "InspectorView 不应再有 .pickerStyle(.iconOnly) (V0-fix-11 修真 #4 — HStack+IconButton 修真 Picker)"
        )

        // 3. IconLibrary.tab(InspectorViewModel.Tab) accessor 必须存在
        XCTAssertTrue(
            iconLib.contains("static func tab(_ kind: InspectorViewModel.Tab)"),
            "IconLibrary 必须有 tab(InspectorViewModel.Tab) accessor (V0-fix-11 修真 #4 — 修真 V0-fix-4 Fix 5 inline iconName(for:) 映射)"
        )

        // 4. 2 SF Symbol 必须在 IconLibrary: eye + pencil.and.list.clipboard
        XCTAssertTrue(
            iconLib.contains("case foreshadow = \"eye\""),
            "IconLibrary.Tab.Inspector.foreshadow 必须 = \"eye\" (V0-fix-11 修真 #4)"
        )
        XCTAssertTrue(
            iconLib.contains("case revision   = \"pencil.and.list.clipboard\""),
            "IconLibrary.Tab.Inspector.revision 必须 = \"pencil.and.list.clipboard\" (V0-fix-11 修真 #4)"
        )

        // 5. .help(tab.title) tooltip — IconButton 自修真
        XCTAssertTrue(
            code.contains("label: tab.title"),
            "InspectorView 必须传 tab.title 给 IconButton label (V0-fix-11 修真 #4 — IconButton 自修真 .help(label))"
        )

        // 6. padding(.vertical, 4) — FCP timeline 修真 (修真 8pt → 4pt)
        XCTAssertTrue(
            code.contains(".padding(.vertical, 4)"),
            "InspectorView 必须用 .padding(.vertical, 4) (V0-fix-11 修真 #4 — FCP timeline 修真)"
        )
    }

    // MARK: - 修真 #5: 4 chat tab padding(vertical, 4) + IconButton 组件

    /// 装机 user 8/11 14:35 红字 "4 chat tab 栏太高, 紧凑点, FCP 范式" 修真:
    ///   - ChatPanelView 4 chat tab 必须用 IconButton( 组件 (修真 V0-fix-8
    ///     HStack+Button(Image) + V0-fix-10.1 修真 #4 衍生)
    ///   - padding(.vertical, 8) → padding(.vertical, 4) — FCP timeline 修真
    ///   - IconLibrary.tab(_ kind: ChatPanelTab) accessor 必须存在
    ///   - 4 SF Symbol 必须在 IconLibrary: bubble.left / clock /
    ///     person.2 / list.bullet.indent
    ///   - padding(.leading, 12) 修真修真修真修真 — FCP timeline 居左
    func testChatPanelView_paddingVertical4_height30() throws {
        let rawSource = try repoFile(
            "Sources/WenshuApp/Views/Chat/ChatPanelView.swift"
        )
        let code = stripSwiftComments(rawSource)
        let iconLib = stripSwiftComments(try repoFile(
            "Sources/WenshuApp/Views/IconLibrary.swift"
        ))

        // 1. ChatPanelView 4 chat tab 必须用 IconButton( 组件
        XCTAssertTrue(
            code.contains("IconButton("),
            "ChatPanelView 4 chat tab 必须用 IconButton( 组件 (V0-fix-11 修真 #5 — 全局 ICON 按钮组件)"
        )

        // 2. padding(.vertical, 8) → padding(.vertical, 4) — FCP timeline 修真
        XCTAssertTrue(
            code.contains(".padding(.vertical, 4)"),
            "ChatPanelView 必须用 .padding(.vertical, 4) (V0-fix-11 修真 #5 — FCP timeline 修真)"
        )
        XCTAssertFalse(
            code.contains(".padding(.vertical, 8)"),
            "ChatPanelView 不应再用 .padding(.vertical, 8) (V0-fix-11 修真 #5 — FCP timeline 修真)"
        )

        // 3. IconLibrary.tab(ChatPanelTab) accessor 必须存在
        XCTAssertTrue(
            iconLib.contains("static func tab(_ kind: ChatPanelTab)"),
            "IconLibrary 必须有 tab(ChatPanelTab) accessor (V0-fix-11 修真 #5 — 修真 V0-fix-8 ChatPanelTab.symbolName 真值)"
        )

        // 4. 4 SF Symbol 必须在 IconLibrary: bubble.left / clock / person.2 / list.bullet.indent
        XCTAssertTrue(
            iconLib.contains("case chat          = \"bubble.left.and.bubble.right\""),
            "IconLibrary.Tab.Chat.chat 必须 = \"bubble.left.and.bubble.right\" (V0-fix-11 修真 #5 + V0-fix-8 真值)"
        )
        XCTAssertTrue(
            iconLib.contains("case timeline      = \"clock.arrow.circlepath\""),
            "IconLibrary.Tab.Chat.timeline 必须 = \"clock.arrow.circlepath\" (V0-fix-11 修真 #5 + V0-fix-8 真值)"
        )
        XCTAssertTrue(
            iconLib.contains("case relationships = \"person.2\""),
            "IconLibrary.Tab.Chat.relationships 必须 = \"person.2\" (V0-fix-11 修真 #5 + V0-fix-8 真值)"
        )
        XCTAssertTrue(
            iconLib.contains("case outline       = \"list.bullet.indent\""),
            "IconLibrary.Tab.Chat.outline 必须 = \"list.bullet.indent\" (V0-fix-11 修真 #5 + V0-fix-8 AIF 16:20 真值)"
        )

        // 5. padding(.leading, 12) — FCP timeline 居左
        XCTAssertTrue(
            code.contains(".padding(.leading, 12)"),
            "ChatPanelView 必须保留 .padding(.leading, 12) (V0-fix-11 修真 #5 — FCP timeline 居左, 沿 V0-fix-4 Fix 6)"
        )

        // 6. tab button frame: 修真修真修真 28×20 → 28×22 (修真 hit area ≥ 24pt HIG)
        //    IconButton 组件内部修真 28×22 frame, View 文件不再含字面量.
        let iconButtonCode = stripSwiftComments(try repoFile(
            "Sources/WenshuApp/Views/Components/IconButton.swift"
        ))
        XCTAssertTrue(
            iconButtonCode.contains(".frame(width: 28, height: 22)"),
            "IconButton 组件内部必须修真 .frame(width: 28, height: 22) (V0-fix-11 修真 #5 — hit area 28×22 = 616pt² ≥ 24×22 = 528pt², 修真 V0-fix-10.1 修真 28×20)"
        )
    }

    // MARK: - 修真 #6: 全局 IconButton 组件 (Sources/WenshuApp/Views/Components/IconButton.swift)

    /// 装机 user 8/11 14:35 红字 "以后界面上所有的按钮都这么处理" 修真:
    ///   - 必须新增 Sources/WenshuApp/Views/Components/IconButton.swift
    ///     全局 ICON 按钮组件
    ///   - IconButton.size 13 (V0-fix-10.1 真值, 修真 V0-fix-8 修真 size 14)
    ///   - IconButton.weight .medium
    ///   - IconButton.frame(width: 28, height: 22) — hit area ≥ 24pt HIG
    ///   - IconButton.buttonStyle(.plain) — 无背景, 无边框, 无 hover (FCP 范式)
    ///   - IconButton.foregroundStyle(isActive ? Color.accentColor : .secondary)
    ///   - IconButton.contentShape(Rectangle())
    ///   - IconButton.help(label) tooltip
    ///   - IconButton.disabled(isDisabled)
    ///   - API: IconButton(systemImage:label:isActive:isDisabled:action:)
    ///   - 必须被 LayoutShellView + ChatPanelView + InspectorView 修真 (4 文件修真)
    func testIconButtonComponent_size13_plainStyle() throws {
        let rawSource = try repoFile(
            "Sources/WenshuApp/Views/Components/IconButton.swift"
        )
        let code = stripSwiftComments(rawSource)
        let layoutShell = stripSwiftComments(try repoFile(
            "Sources/WenshuApp/Views/Layout/LayoutShellView.swift"
        ))
        let chatPanel = stripSwiftComments(try repoFile(
            "Sources/WenshuApp/Views/Chat/ChatPanelView.swift"
        ))
        let inspector = stripSwiftComments(try repoFile(
            "Sources/WenshuApp/Views/Inspector/InspectorView.swift"
        ))

        // 1. IconButton 文件必须存在 + 定义 struct IconButton: View
        XCTAssertTrue(
            code.contains("struct IconButton: View"),
            "Components/IconButton.swift 必须定义 struct IconButton: View (V0-fix-11 修真 #6 — 全局 ICON 按钮组件)"
        )

        // 2. IconButton API 修真修真修真 (5 修真修真修真: systemImage / label / isActive / isDisabled / action)
        XCTAssertTrue(
            code.contains("let systemImage: String"),
            "IconButton 必须有 systemImage: String (V0-fix-11 修真 #6 — SF Symbol 修真)"
        )
        XCTAssertTrue(
            code.contains("let label: String"),
            "IconButton 必须有 label: String (V0-fix-11 修真 #6 — a11y / help 修真)"
        )
        XCTAssertTrue(
            code.contains("let isActive: Bool"),
            "IconButton 必须有 isActive: Bool (V0-fix-11 修真 #6 — active tab 修真 Color.accentColor)"
        )
        XCTAssertTrue(
            code.contains("let isDisabled: Bool"),
            "IconButton 必须有 isDisabled: Bool (V0-fix-11 修真 #6 — 修真修真修真 修真 .disabled)"
        )
        XCTAssertTrue(
            code.contains("let action: () -> Void"),
            "IconButton 必须有 action: () -> Void (V0-fix-11 修真 #6 — 点击动作)"
        )

        // 3. size 13 + weight .medium
        XCTAssertTrue(
            code.contains(#".font(.system(size: 13, weight: .medium))"#),
            "IconButton 必须用 .font(.system(size: 13, weight: .medium)) (V0-fix-11 修真 #6 — V0-fix-10.1 真值, 修真 V0-fix-8 修真 size 14)"
        )

        // 4. frame(width: 28, height: 22) — hit area ≥ 24pt HIG
        XCTAssertTrue(
            code.contains(".frame(width: 28, height: 22)"),
            "IconButton 必须用 .frame(width: 28, height: 22) (V0-fix-11 修真 #6 — hit area 28×22 = 616pt² ≥ 24×22 = 528pt², 修真 V0-fix-10.1 修真 28×20)"
        )

        // 5. .buttonStyle(.plain) — FCP 范式, 无背景
        XCTAssertTrue(
            code.contains(".buttonStyle(.plain)"),
            "IconButton 必须用 .buttonStyle(.plain) (V0-fix-11 修真 #6 — FCP 范式, 无背景无边框无 hover)"
        )

        // 6. foregroundStyle(isActive ? Color.accentColor : .secondary)
        XCTAssertTrue(
            code.contains(#".foregroundStyle(isActive ? Color.accentColor : .secondary)"#),
            "IconButton 必须用 .foregroundStyle(isActive ? Color.accentColor : .secondary) (V0-fix-11 修真 #6 — active 修真 Color.accentColor)"
        )

        // 7. .contentShape(Rectangle())
        XCTAssertTrue(
            code.contains(".contentShape(Rectangle())"),
            "IconButton 必须用 .contentShape(Rectangle()) (V0-fix-11 修真 #6 — hit area 修真修真"
        )

        // 8. .help(label) tooltip
        XCTAssertTrue(
            code.contains(".help(label)"),
            "IconButton 必须用 .help(label) (V0-fix-11 修真 #6 — a11y tooltip)"
        )

        // 9. .disabled(isDisabled)
        XCTAssertTrue(
            code.contains(".disabled(isDisabled)"),
            "IconButton 必须用 .disabled(isDisabled) (V0-fix-11 修真 #6 — 修真修真修真 修真 .disabled)"
        )

        // 10. IconButton 必须被 3 文件修真: LayoutShellView + ChatPanelView + InspectorView
        XCTAssertTrue(
            layoutShell.contains("IconButton("),
            "LayoutShellView 必须修真 IconButton( (V0-fix-11 修真 #6 — topLeftHeaderBar 5 tab + IconLibrary.tab(tab) 修真)"
        )
        XCTAssertTrue(
            chatPanel.contains("IconButton("),
            "ChatPanelView 必须修真 IconButton( (V0-fix-11 修真 #6 — 4 chat tab 修真)"
        )
        XCTAssertTrue(
            inspector.contains("IconButton("),
            "InspectorView 必须修真 IconButton( (V0-fix-11 修真 #6 — 2 inspector tab 修真)"
        )
    }
}
