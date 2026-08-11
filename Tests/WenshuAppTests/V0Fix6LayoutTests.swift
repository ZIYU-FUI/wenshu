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

        // 38pt header bar 沿用 V0-fix-4 Fix 1
        XCTAssertTrue(
            code.contains(".frame(height: 38)"),
            "LayoutShellView header bar 必须含 .frame(height: 38) (V0-fix-6 Fix 1 + Fix 3 — FCP 38pt title-bar 跨全宽)"
        )
        XCTAssertTrue(
            code.contains("plus.circle.fill"),
            "LayoutShellView header bar 必须含 SF Symbol <plus.circle.fill> (V0-fix-6 Fix 1 — + 按钮)"
        )
        XCTAssertTrue(
            code.contains(#".help("新建项目")"#),
            "LayoutShellView header bar 必须含 .help(新建项目) tooltip (V0-fix-6 Fix 1 — 兜中文)"
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

        // 5 tab iconOnly Picker 必须存在
        XCTAssertTrue(
            code.contains("Picker(\"\", selection: $projectListActiveTab)"),
            "LayoutShellView 标题栏必须含 5 tab Picker (V0-fix-6 Fix 2 — 5 tab 容器升标题栏)"
        )
        XCTAssertTrue(
            code.contains(".pickerStyle(.iconOnly)"),
            "LayoutShellView 标题栏 Picker 必须用 .pickerStyle(.iconOnly) (V0-fix-6 Fix 2 — ICON-only, 走 PickerStyle+IconOnly alias)"
        )

        // 5 SF Symbol 引用 (复用 ProjectManagementTab.symbolName — 在 ProjectListView
        // enum 定义, LayoutShellView 通过 `tab.symbolName` 间接引用). 此处只验
        // Image(systemName: tab.symbolName) 调, 5 SF Symbol 字面量由
        // testProjectListView_5tab_usesIcons 单独验.
        XCTAssertTrue(
            code.contains("Image(systemName: tab.symbolName)"),
            "LayoutShellView 标题栏 Picker 块必须用 Image(systemName: tab.symbolName) (V0-fix-6 Fix 2 — 复用 ProjectManagementTab.symbolName)"
        )

        // activeTab state 顶层持有
        XCTAssertTrue(
            code.contains("@State private var projectListActiveTab: ProjectManagementTab"),
            "LayoutShellView 必须有 @State projectListActiveTab (V0-fix-6 Fix 5 — 标题栏与 ProjectListView 共享 activeTab)"
        )
    }

    // MARK: - Fix 2 (B5-2): ProjectListView 5 tab Picker 改 ICON

    /// 装机 user 8/10 17:35 OOB 真机拍 "5 tab 文字改 ICON" (BUG B5-2
    /// ProjectListView 部分):
    ///   - Picker 内容 `Text(tab.rawValue)` → `Image(systemName: tab.symbolName)`
    ///   - pickerStyle 保持 `.segmented` (沿用 LT-03 v2 拍板, 不动风格)
    ///   - activeTab 改 @Binding (V0-fix-6 Fix 5 共享顶层 state)
    func testProjectListView_5tab_usesIcons() throws {
        let rawSource = try repoFile(
            "Sources/WenshuApp/Views/ProjectListView.swift"
        )
        let code = stripSwiftComments(rawSource)

        // Picker.segmented 保留 (沿用 LT-03 v2)
        XCTAssertTrue(
            code.contains(".pickerStyle(.segmented)"),
            "ProjectListView 5 tab Picker 必须用 .pickerStyle(.segmented) 文字标签 (V0-fix-6 Fix 2 — 沿用 LT-03 v2 拍板, 不动风格)"
        )

        // Picker 内容改 Image(systemName:), Text(tab.rawValue) 删除
        XCTAssertTrue(
            code.contains("Image(systemName: tab.symbolName)"),
            "ProjectListView Picker 块必须用 Image(systemName: tab.symbolName) 渲染 (V0-fix-6 Fix 2 — ICON-only 文字改 ICON)"
        )
        XCTAssertFalse(
            code.contains("Text(tab.rawValue).tag(tab)"),
            "ProjectListView Picker 块不应再用 Text(tab.rawValue).tag(tab) (V0-fix-6 Fix 2 — 改 Image SF Symbol)"
        )

        // 5 SF Symbol 沿用 ProjectManagementTab.symbolName
        XCTAssertTrue(code.contains(#""folder""#),                  "ProjectListView 必须含 SF Symbol <folder> (V0-fix-6 Fix 2 — 5 tab 图标)")
        XCTAssertTrue(code.contains(#""list.bullet.rectangle""#),   "ProjectListView 必须含 SF Symbol <list.bullet.rectangle> (V0-fix-6 Fix 2 — 5 tab 图标)")
        XCTAssertTrue(code.contains(#""slider.horizontal.3""#),     "ProjectListView 必须含 SF Symbol <slider.horizontal.3> (V0-fix-6 Fix 2 — 5 tab 图标)")
        XCTAssertTrue(code.contains(#""books.vertical""#),          "ProjectListView 必须含 SF Symbol <books.vertical> (V0-fix-6 Fix 2 — 5 tab 图标)")
        XCTAssertTrue(code.contains(#""rectangle.split.3x1""#),     "ProjectListView 必须含 SF Symbol <rectangle.split.3x1> (V0-fix-6 Fix 2 — 5 tab 图标)")

        // Fix 5: activeTab 改 @Binding
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

    // MARK: - Fix 4 (B5-4): ChatPanelView 4 tab ICON-only + 内容居中

    /// 装机 user 8/10 17:35 OOB 真机拍 "tab 居左 OK, 内容居中" (BUG B5-4):
    ///   - Fix 4a: Picker 保持 `.iconOnly` (沿 V0-fix-4 Fix 4)
    ///   - Fix 4b: Picker 保持 `.padding(.leading, 12)` (沿 V0-fix-4 Fix 6)
    ///   - Fix 4c: tabContent 加 `.frame(maxWidth: .infinity, alignment: .center)`
    func testChatPanelView_4tab_iconOnly() throws {
        let rawSource = try repoFile(
            "Sources/WenshuApp/Views/Chat/ChatPanelView.swift"
        )
        let code = stripSwiftComments(rawSource)

        // 4 tab ICON-only 沿用
        XCTAssertTrue(
            code.contains(".pickerStyle(.iconOnly)"),
            "ChatPanelView 必须使用 .pickerStyle(.iconOnly) (V0-fix-6 Fix 4a — 沿用 V0-fix-4 Fix 4)"
        )
        XCTAssertFalse(
            code.contains(".pickerStyle(.segmented)"),
            "ChatPanelView 不应再用 .pickerStyle(.segmented) (V0-fix-6 Fix 4a — 沿用 V0-fix-4 Fix 4 替换)"
        )

        // 4 tab 居左沿用
        XCTAssertTrue(
            code.contains(".padding(.leading, 12)"),
            "ChatPanelView Picker 必须用 .padding(.leading, 12) 居左 (V0-fix-6 Fix 4b — 沿用 V0-fix-4 Fix 6)"
        )
        XCTAssertFalse(
            code.contains(".padding(.horizontal, 12)"),
            "ChatPanelView 不应再用 .padding(.horizontal, 12) (V0-fix-6 Fix 4b — 沿用 V0-fix-4 Fix 6)"
        )

        // 4 SF Symbol 沿用
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

        // Fix 1: + 按钮改 sheet
        XCTAssertTrue(layoutShell.contains(".sheet(isPresented: $showCreateProject)"),
                      "V0-fix-6 Fix 1 — + 按钮 sheet 弹窗 (装机 user 17:35 OOB)")
        XCTAssertFalse(layoutShell.contains("navPath.append(AppRoute.createProject)"),
                       "V0-fix-6 Fix 1 — navPath.append(createProject) 已删 (改 sheet)")

        // Fix 2: 5 tab ICON-only (LayoutShellView 标题栏 + ProjectListView 内容)
        XCTAssertTrue(layoutShell.contains("Picker(\"\", selection: $projectListActiveTab)"),
                      "V0-fix-6 Fix 2 — 标题栏 5 tab Picker")
        XCTAssertTrue(layoutShell.contains(".pickerStyle(.iconOnly)"),
                      "V0-fix-6 Fix 2 — 标题栏 Picker .iconOnly")
        XCTAssertTrue(projectList.contains("Image(systemName: tab.symbolName)"),
                      "V0-fix-6 Fix 2 — ProjectListView Picker 改 Image(systemName:)")

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
