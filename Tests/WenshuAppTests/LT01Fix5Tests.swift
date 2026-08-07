// LT01Fix5Tests.swift · 文枢 (Wenshu) · v0.02.0 WO-LT-01-fix5
//
// 4 件事全做的回归测试, 总 10 个 case (2 + 3 + 1 + 4):
//
// - BUG1 fix (PanelSplitter click 路径堵):
//     1. testSplitterClick_zeroTranslation_isClick
//     2. testSplitterClick_5px_isDrag
//
// - 优化1 fix (PanelVisibilityState.isDismissible + fallback):
//     3. testDocumentAndChatNotDismissible
//     4. testToggleChatVisibility_blocked
//     5. testAllOptionalHiddenFallbackToDocChat_50_50
//
// - 优化2 fix (菜单 "wenshu" → "文枢" + 唯一 "显示" menu):
//     6. testMenuStructure_only2TopLevelMenus
//
// - 优化3 fix (删 panel 标题栏 + content 内置 H1):
//     7. testPanelHeadersRemoved
//     8. testCollapsedGutter_hasNoTextTitle
//     9. testPanelContentHasFunctionLabel
//    10. testPanelContainer_noHeaderBarInBody
//
// 沿用 LT-01 测试的纪律:
// - BUG1 / 优化1 用纯 helper function (SplitterClickDetector,
//   LayoutMetrics) + VM API — 无 SwiftUI 渲染依赖.
// - 优化2 / 优化3 用 source-level 静态扫描, 因为 (a) SwiftPM-only
//   binary 的 AX tree 没法 cua-driver 抓 (见 LT-01 ACCEPTANCE log 同款
//   限制), (b) 我们的真值就是 source 里"有这个 / 没这个", 不用等
//   实际渲染.

import XCTest
@testable import WenshuApp

final class LT01Fix5Tests: XCTestCase {

    // MARK: - Helpers (source-level scanning for 优化2 / 优化3)

    /// Resolve `<worktree>/Sources/WenshuApp/<path>` to an absolute path
    /// the test runner can `String(contentsOf:)`. Works under both
    /// `swift test` (CWD = package root) and xctest CLI.
    private func repoFile(_ relative: String) throws -> String {
        let cwd = FileManager.default.currentDirectoryPath
        let candidate = cwd + "/" + relative
        return try String(contentsOfFile: candidate, encoding: .utf8)
    }

    /// Strip `// line comments` and `/* block comments */` so source-
    /// level tests don't trip on illustrative mentions inside markdown
    /// headers + doc comments. Multi-line `/* ... */` is rare in App.swift
    /// but handled here for completeness.
    private func stripSwiftComments(_ source: String) -> String {
        var result = ""
        result.reserveCapacity(source.count)
        var idx = source.startIndex
        let end = source.endIndex
        var inStringLiteral = false
        while idx < end {
            let next = source.index(after: idx)
            // Detect `/* ... */` block comment.
            if !inStringLiteral,
               next < end,
               source[idx] == "/",
               source[next] == "*" {
                // Scan forward to closing `*/`.
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
            // Detect `// line comment`.
            if !inStringLiteral,
               next < end,
               source[idx] == "/",
               source[next] == "/" {
                // Skip to next newline.
                var scan = idx
                while scan < end, source[scan] != "\n" {
                    scan = source.index(after: scan)
                }
                idx = scan
                continue
            }
            // Detect `\"` inside string literals — heuristic only,
            // strings with escaped quotes are unlikely in App.swift.
            if source[idx] == "\"" {
                inStringLiteral.toggle()
            }
            result.append(source[idx])
            idx = next
        }
        return result
    }

    /// Walk forward from `from` (a position right after an open `{`) and
    /// return the index of the matching `}`, accounting for nested
    /// braces. Returns `nil` if no match is found (malformed source).
    private func findMatchingBrace(in source: String, from: String.Index) -> String.Index? {
        var depth = 1
        var idx = from
        let end = source.endIndex
        while idx < end {
            let ch = source[idx]
            if ch == "{" { depth += 1 }
            else if ch == "}" {
                depth -= 1
                if depth == 0 { return idx }
            }
            idx = source.index(after: idx)
        }
        return nil
    }

    // MARK: - 1. BUG1: Splitter click path

    /// Pure mouseDown + mouseUp (no drag) → cumulative translation = (0, 0)
    /// → click. 装机 user 8/7 拍板阈值 5px: < 5px = click, 不回调任何 handler.
    func testSplitterClick_zeroTranslation_isClick() {
        let click = SplitterClickDetector.isClick(translation: CGSize(width: 0, height: 0))
        XCTAssertTrue(click, "鼠标点一下 (translation = 0) 必须是 click")

        // Sub-pixel jitter should also be classified as click (anything
        // strictly under the 5px threshold in both axes).
        XCTAssertTrue(SplitterClickDetector.isClick(translation: CGSize(width: 1, height: 0)))
        XCTAssertTrue(SplitterClickDetector.isClick(translation: CGSize(width: 4.9, height: 4.9)))
        XCTAssertTrue(SplitterClickDetector.isClick(translation: CGSize(width: -4, height: 0)))
    }

    /// Drag ≥ 5px in either axis is NOT a click → VM `onDrag` handler is
    /// allowed to fire. This pins the 5px threshold as the boundary
    /// between "viewer's mouse jitter" and "intentional drag".
    @MainActor
    func testSplitterClick_5px_isDrag() {
        XCTAssertEqual(SplitterClickDetector.thresholdPixels, 5,
                       "装机 user 8/7 拍板阈值必须 = 5px")

        // 5px in any axis → not a click.
        XCTAssertFalse(
            SplitterClickDetector.isClick(translation: CGSize(width: 5, height: 0)),
            "水平拖 5px 必须是 drag (click 阈值边界)"
        )
        XCTAssertFalse(
            SplitterClickDetector.isClick(translation: CGSize(width: 0, height: 5)),
            "垂直拖 5px 必须是 drag (click 阈值边界)"
        )

        // 50px realistic drag → not a click.
        XCTAssertFalse(
            SplitterClickDetector.isClick(translation: CGSize(width: 50, height: 0)),
            "水平拖 50px 必须是 drag (装机 user BUG1 实测路径)"
        )

        // Asymmetric: 50px vertical, 0 horizontal → still not a click.
        XCTAssertFalse(
            SplitterClickDetector.isClick(translation: CGSize(width: 0, height: 50))
        )

        // End-to-end: the VM still mutates ratios when a drag handler
        // is invoked. This mirrors the original
        // `testHorizontalSplitterDrag_changesBottomRatio` and locks the
        // drag path (LT-01-fix4 BUG1 fix) doesn't regress.
        let vm = LayoutShellViewModel()
        let initial = vm.snapshot.ratios[4]
        vm.adjustLowerColumn(delta: 50, totalWidth: 1000)
        XCTAssertNotEqual(vm.snapshot.ratios[4], initial,
                          "5px+ drag 必须仍能 change ratios (drag 路径没废)")
    }

    // MARK: - 3. 优化1: PanelVisibilityState.isDismissible + fallback

    /// 装机 user 8/7 拍板: 文档 (topCenter) + 聊天 (bottomLeft) 不可
    /// 隐藏; 项目管理 / 检视 / 状态 可隐藏. compile-time 常量, 不进 JSON.
    func testDocumentAndChatNotDismissible() {
        XCTAssertFalse(PanelID.topCenter.isDismissible, "文档 不可隐藏")
        XCTAssertFalse(PanelID.bottomLeft.isDismissible, "聊天 不可隐藏")

        // The other 3 ARE dismissible.
        XCTAssertTrue(PanelID.topLeft.isDismissible, "项目管理 可隐藏")
        XCTAssertTrue(PanelID.topRight.isDismissible, "检视 可隐藏")
        XCTAssertTrue(PanelID.bottomRight.isDismissible, "状态 可隐藏")

        // Exhaustiveness: 5 panels enumerated.
        let dismissiblePanels = PanelID.allCases.filter { $0.isDismissible }
        XCTAssertEqual(dismissiblePanels.count, 3,
                       "恰好 3 个 dismissible panel (项目/检视/状态)")
    }

    /// `togglePanelVisibility(.bottomLeft)` is a no-op because 聊天 不可隐藏.
    /// menu 项 (.disabled) 也走同一条路径, 但 VM 直调也必须被挡住 (defense
    /// in depth).
    @MainActor
    func testToggleChatVisibility_blocked() {
        let vm = LayoutShellViewModel()
        let beforeChat = vm.isVisible(.bottomLeft)
        let beforeDoc = vm.isVisible(.topCenter)
        XCTAssertTrue(beforeChat, "默认 聊天 visible")
        XCTAssertTrue(beforeDoc, "默认 文档 visible")

        // Try to hide both — both must be blocked.
        vm.togglePanelVisibility(.bottomLeft)
        vm.togglePanelVisibility(.topCenter)
        XCTAssertTrue(vm.isVisible(.bottomLeft),
                      "toggle 聊天必须被挡 (isDismissible guard)")
        XCTAssertTrue(vm.isVisible(.topCenter),
                      "toggle 文档必须被挡 (isDismissible guard)")

        // The dismissible ones still toggle normally.
        vm.togglePanelVisibility(.topLeft)
        XCTAssertFalse(vm.isVisible(.topLeft),
                       "可隐藏的 panel (项目管理) 仍可 toggle")

        // `showAllPanels` does NOT change the state of an already-all-
        // visible VM, but more importantly: when called after a block,
        // it must not roll back the (already correct) visible state.
        // 这条 guard 防 "blocked toggle 把 visible 状态悄悄改了" 的回归.
        XCTAssertTrue(vm.visibility.topCenter)
        XCTAssertTrue(vm.visibility.bottomLeft)
    }

    /// 全部 dismissible panel (项目 / 检视 / 状态) hidden 后, lowerBandHeight
    /// 必须强制 = totalHeight * 0.5 (装机 user 拍板 fallback "文档:聊天 = 50:50"),
    /// 即使 persisted `ratios[3]` 不是 0.5.
    func testAllOptionalHiddenFallbackToDocChat_50_50() {
        // Sanity: fallback helper itself.
        let visibility = PanelVisibilityState(
            topLeft: false, topCenter: true,
            topRight: false, bottomLeft: true, bottomRight: false
        )
        XCTAssertTrue(LayoutMetrics.isFallbackLayout(visibility: visibility),
                      "只剩 文档 + 聊天 必须触发 fallback")

        // Negatives — fallback must NOT trigger when any other panel is visible.
        XCTAssertFalse(
            LayoutMetrics.isFallbackLayout(visibility: PanelVisibilityState()),
            "默认 all-visible 不是 fallback"
        )
        XCTAssertFalse(
            LayoutMetrics.isFallbackLayout(
                visibility: PanelVisibilityState(topRight: false)  // 只有 检视 隐藏
            ),
            "只 hide 一个 dismissible panel 不是 fallback"
        )
        XCTAssertFalse(
            LayoutMetrics.isFallbackLayout(visibility: PanelVisibilityState(
                topLeft: false, topRight: false, bottomLeft: false, bottomRight: false
            )),
            "fallback 要求 文档 + 聊天 都 visible"
        )

        // Force ratios[3] to something != 0.5 so we'd notice if the
        // fallback didn't override.
        let skewedRatios: [Double] = [0.2, 0.6, 0.2, 0.7, 0.7]
        let height: CGFloat = 800
        let lower = LayoutMetrics.lowerBandHeight(
            totalHeight: height,
            ratios: skewedRatios,         // ratios[3] = 0.7 (would normally yield 560)
            visibility: visibility
        )
        XCTAssertEqual(lower, height * 0.5, accuracy: 0.0001,
                       "fallback 模式 lowerBandHeight 必须强制 50% (装机 user 拍板)")

        // Outside-fallback mode honors the user-dragged ratio.
        let nonFallbackHeight = LayoutMetrics.lowerBandHeight(
            totalHeight: height,
            ratios: skewedRatios,
            visibility: PanelVisibilityState()  // 全部 visible
        )
        XCTAssertEqual(nonFallbackHeight, height * skewedRatios[3], accuracy: 0.0001,
                       "非 fallback 模式必须尊重 ratios[3] 用户拖拽值")
    }

    // MARK: - 6. 优化2: Menu structure (source-level)

    /// 装机 user 8/7 拍板: macOS 菜单栏第一个 menu 必须是 "文枢", 全文
    /// `CommandMenu(` 调用必须恰好 2 个 (文枢 + 显示). 不能有 2 个
    /// `CommandMenu("显示")` (= LT-01-fix4 派单没合并干净), 也不能
    /// 留 `CommandGroup(replacing: .appInfo)` (= LT-01-fix5 替换目标).
    func testMenuStructure_only2TopLevelMenus() throws {
        let rawSource = try repoFile("Sources/WenshuApp/App.swift")
        // Strip // and /* */ comments first so illustrative mentions
        // inside doc headers don't confuse the count.
        let source = stripSwiftComments(rawSource)

        // Count `CommandMenu(` references — only ACTIVE code, not comments.
        let occurrences = source.components(separatedBy: "CommandMenu(").count - 1
        XCTAssertEqual(occurrences, 2,
                       "App.swift (除注释外) 必须恰好 2 个 CommandMenu 声明 (文枢 + 显示), 实际 \(occurrences) 个")

        // Both expected menus present (code).
        XCTAssertTrue(
            source.contains("CommandMenu(\"文枢\")")
                || source.contains("CommandMenu(Self.menuTitle)"),
            "必须存在 CommandMenu(\"文枢\") (= 文枢 menu)"
        )
        XCTAssertTrue(
            source.contains("CommandMenu(\"显示\")"),
            "必须存在 CommandMenu(\"显示\") (= 显示 menu)"
        )

        // No legacy `CommandGroup(replacing: .appInfo)` left.
        XCTAssertFalse(
            source.contains("CommandGroup(replacing: .appInfo)"),
            "不能留 CommandGroup(replacing: .appInfo) (会跟显式 CommandMenu(\"文枢\") 冲突)"
        )

        // No accidental "wenshu" lower-case string in active code.
        XCTAssertFalse(
            source.contains("\"wenshu\""),
            "App.swift 活动代码不能出现 \"wenshu\" 字面量 (应统一为 \"文枢\")"
        )
    }

    // MARK: - 9, 10. 优化3: Panel headers removed

    /// 装机 user 8/7 拍板: "标题栏全删, 用功能告诉用户". 因此 AX tree
    /// 不应再出现 panel 的 header label. Source-level: `PanelContainer.body`
    /// 必须不再调用 `headerBar` 这个 private var. 这条是 proxy test,
    /// 实机验证 (cua-driver) 会再过一遍.
    func testPanelHeadersRemoved() throws {
        let panelContainerSource = try repoFile(
            "Sources/WenshuApp/Views/Layout/PanelContainer.swift"
        )
        let layoutShellSource = try repoFile(
            "Sources/WenshuApp/Views/Layout/LayoutShellView.swift"
        )

        // PanelContainer.swift: `private var headerBar` must NOT appear
        // (旧 LT-01-fix3 chrome 已删).
        XCTAssertFalse(
            panelContainerSource.contains("private var headerBar"),
            "PanelContainer.headerBar 必须删掉 (LT-01-fix5 优化3 拍板)"
        )

        // PanelContainer.swift: no `panelID.title` reference inside a
        // Text — that's the header label.
        XCTAssertFalse(
            panelContainerSource.contains("Text(panelID.title)"),
            "PanelContainer 不能渲 Text(panelID.title) (title bar 内容已迁到 content H1)"
        )

        // LayoutShellView.swift: it must NOT pass `headerBar { ... }` to
        // any panel (vanilla `.headerBar` modifier doesn't exist in our
        // code anyway, but explicit check catches future refactors).
        XCTAssertFalse(
            layoutShellSource.contains(".headerBar "),
            "LayoutShellView 不能调用任何 .headerBar 修饰符"
        )
        XCTAssertFalse(
            layoutShellSource.contains(".headerBar{"),
            "LayoutShellView 不能调用任何 .headerBar 修饰符"
        )
    }

    /// `CollapsedGutter` (上半折叠后的 50px icon strip) 沿用同一优化3 拍板:
    /// 也不显示 panel 标题文字, 只露 SF Symbol. 避免用户在 collapsed gutter
    /// 里看到 "检视" / "聊天" 等文字, 与"标题栏全删" 原则一致.
    func testCollapsedGutter_hasNoTextTitle() throws {
        let rawSource = try repoFile(
            "Sources/WenshuApp/Views/Layout/PanelContainer.swift"
        )
        let source = stripSwiftComments(rawSource)

        // CollapsedGutter struct 仍然保留 (50px vertical icon strip
        // 占位). 但它内部不能再 `Text(panelID.title)` 那种标题文字.
        XCTAssertTrue(source.contains("struct CollapsedGutter"),
                      "CollapsedGutter 必须保留 (上半折叠的 icon strip)")

        // 在 CollapsedGutter struct 体里不能引用 panelID.title 作 Text.
        // 用 slice 把 CollapsedGutter struct 的那段 body 切出来再 grep.
        if let startRange = source.range(of: "struct CollapsedGutter"),
           let openBrace = source.range(of: "{", range: startRange.upperBound..<source.endIndex),
           let closeBrace = findMatchingBrace(in: source, from: openBrace.upperBound) {
            let body = String(source[openBrace.upperBound..<closeBrace])
            XCTAssertFalse(
                body.contains("Text(panelID.title)"),
                "CollapsedGutter body 不能有 Text(panelID.title) — 标题文字已删 (LT-01-fix5 优化3)"
            )
            XCTAssertFalse(
                body.contains(".title"),
                "CollapsedGutter body 不应引用 panelID.title (沿用'标题栏全删'原则)"
            )
        }
    }

    /// LT-01-fix6 反转 fix5 优化3: 装机 user 8/7 二次实机验拍板
    /// "不要任何标题文字". fix5 删了 headerBar 却在 content 里补了
    /// 一个 H1, 视觉上等同标题栏 = 没删干净. 这里保留 `PanelID.title`
    /// 本身 (菜单栏 "隐藏 X" / AX label 仍然要用), 只断言它**不再**
    /// 被 placeholder 渲染 — 渲染侧的断言见
    /// `testPlaceholderContentNoH1`.
    func testPanelIDTitlesStillExistForMenus() {
        // Menu 层 (View 菜单的 "隐藏 X" / "显示 X") 仍然依赖这些字符串,
        // 所以 PanelID.title 不能跟着 H1 一起删.
        XCTAssertEqual(PanelID.topLeft.title, "项目管理")
        XCTAssertEqual(PanelID.topCenter.title, "文档")
        XCTAssertEqual(PanelID.topRight.title, "检视")
        XCTAssertEqual(PanelID.bottomLeft.title, "聊天")
        XCTAssertEqual(PanelID.bottomRight.title, "状态")
        XCTAssertEqual(PanelID.allCases.count, 5)
    }

    /// LT-01-fix6 问题1: `PlaceholderContent` 不能渲染任何 panel 名.
    /// 源码级断言 — 5 个 panel 名字面量全部消失, `h1Title` 这个
    /// computed property 也删干净 (不留死代码), 且不再有
    /// `Text(panel.title)` 这个二次标题.
    func testPlaceholderContentNoH1() throws {
        let source = try repoFile(
            "Sources/WenshuApp/Views/Layout/PlaceholderContent.swift"
        )
        let code = stripSwiftComments(source)

        for h1 in ["项目管理", "文档", "检视", "聊天", "状态"] {
            XCTAssertFalse(
                code.contains("\"\(h1)\""),
                "PlaceholderContent 不能再含标题字面量 \"\(h1)\" (LT-01-fix6: 不要任何标题文字)"
            )
        }
        XCTAssertFalse(
            code.contains("h1Title"),
            "h1Title 必须整个删掉, 不留死代码 (LT-01-fix6)"
        )
        XCTAssertFalse(
            code.contains("Text(panel.title)"),
            "PlaceholderContent 不能渲染 panel.title 作为标题 (LT-01-fix6)"
        )
        // 留下来的必须是: 图标 + placeholder 文案.
        XCTAssertTrue(
            code.contains("Image(systemName: panel.symbolName)"),
            "panel 仍然要靠 SF Symbol 图标自我说明 (FCP 范式)"
        )
        XCTAssertTrue(
            code.contains("Text(hint)"),
            "panel 仍然要显示 'LT-XX 将在此填充…' 的 placeholder 文案"
        )
    }
}
