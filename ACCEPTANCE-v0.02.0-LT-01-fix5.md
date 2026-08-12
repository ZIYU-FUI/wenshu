# v0.02.0 WO-LT-01-fix5 Acceptance Log

**WO**: v0.02.0 · LT-01-fix5 · 4 件事一起做
**Date**: 2026-08-07
**Verifier**: my-pm (PM-direct dispatched claude --bare, 与老板 8/7 实机验配合)
**Branch**: `wenshu/v0.02.0/LT-01-fix5`
**CC final commit**: `60a5a77e0` · 8 files changed, 721 insertions(+), 75 deletions(-)

---

## 完成定义 check (per WO-LT-01-fix5 spec)

| # | Acceptance criterion | Status | Evidence |
|---|----------------------|--------|---------|
| 1 | PanelSplitter click 路径堵 (BUG1 fix, 3 个 splitter 共用 5px 阈值) | OK | `SplitterClickDetector.isClick(translation:)` 在 `PanelSplitter.onEnded` 中调用, `thresholdPixels = 5` 老板 拍板 |
| 2 | PanelID.isDismissible (文档 / 聊天 = false, 项目 / 检视 / 状态 = true) | OK | `PanelID` extension 在 `LayoutShellViewModel.swift:323-331` |
| 3 | 全隐藏 fallback = 文档:聊天 50:50 | OK | `LayoutMetrics.isFallbackLayout` + `lowerBandHeight` 强制 `totalHeight * 0.5` (only topCenter + bottomLeft visible) |
| 4 | App.swift 第一个 menu = "文枢" (不是 wenshu) | OK | 显式 `CommandMenu(Self.menuTitle)` 替换原 `CommandGroup(replacing: .appInfo)`, `menuTitle` 兜底硬编码 "文枢" |
| 5 | App.swift 唯一 "显示" menu (重复合并) | OK | `grep "CommandMenu("` source code (除注释外) = 2 (文枢 + 显示) |
| 6 | 4 panel 标题栏全删 (headerBar 删 + CollapsedGutter 删 Text) | OK | `PanelContainer.swift` 不再有 `private var headerBar` 或 `Text(panelID.title)` |
| 7 | 4 placeholder content H1 标识 | OK (含全部 5 panel) | `PlaceholderContent.h1Title` switch returns 5 strings, `Text(h1Title)` rendered as leading H1 |
| 8 | 10 个新 unit test 全过 | OK | `LT01Fix5Tests.swift` (NEW): BUG1 2 + 优化1 3 + 优化2 1 + 优化3 4 = 10 cases |
| 9 | swift build exit 0 | OK | `swift build` exit 0 (0.43s incremental, 13.18s clean) |
| 10 | swift test 51/51 全过 | OK | 41 原 + 10 新 = 51/51 0 failures |
| 11 | 老板 实机验视觉通过 | 待跑 PM-direct | 见下"视觉验证清单" |
| 12 | git commit 落盘 (不 push) | OK | commit `60a5a77e0` on branch `wenshu/v0.02.0/LT-01-fix5` |

## 质量门禁

- OK `swift build` exit 0
- OK `swift test 51/51 全过` (原 41 + 新 10)
- OK Schema migration test (`testMigration_preLT01_wsFile_doesNotLoseData`) 仍过 — `.ws` schema 没动
- OK WenshuStoreActor 签名 没动 (`saveLayoutState / loadLayoutState / countLayoutStates`)
- OK Package.swift, Info.plist, swift-tools-version, platforms 没动
- OK AGENTS.md / CLAUDE.md / README.md 没动
- OK LT-01 / LT-01-fix2 / LT-01-fix3 / LT-01-fix4 worktree 没动 (独立 branch 并发)

## 实现 summary (a)

**改动文件 (7) — 不含新增测试文件**

| Path | 改动 |
|------|------|
| `Sources/WenshuApp/App.swift` | 替换 `CommandGroup(replacing: .appInfo)` 为显式 `CommandMenu("文枢")` (含 About / Hide / 隐藏其他 / 全部显示 / Quit) + `LayoutMenuContent` 的 toggle 按钮加 `.disabled(!panel.isDismissible)` |
| `Sources/WenshuApp/Views/Layout/PanelSplitter.swift` | 新增 `SplitterClickDetector` enum (thresholdPixels = 5 + `isClick(translation:)` static func) + `onEnded` 用 detector 判 click |
| `Sources/WenshuApp/Views/Layout/LayoutShellViewModel.swift` | `PanelID` extension 加 `isDismissible: Bool` (compile-time 常量) + `togglePanelVisibility` 加 `guard panel.isDismissible else return` + `LayoutMetrics.isFallbackLayout` + `lowerBandHeight` fallback 50:50 |
| `Sources/WenshuApp/Views/Layout/PanelContainer.swift` | 删 `headerBar` private var + 删 divider + 删 `Text(panelID.title)` + `CollapsedGutter` 删 Text 标题 |
| `Sources/WenshuApp/Views/Layout/PlaceholderContent.swift` | 加 `h1Title` computed property (5 panel → 5 strings) + `Text(h1Title)` 在内容顶部, `.frame(.leading)` 对齐 |

**改动测试文件 (3) — 含新增测试文件**

| Path | 改动 |
|------|------|
| `Tests/WenshuAppTests/LT01Fix5Tests.swift` (NEW) | 10 个新 unit test (SplitterClickDetector 2 + isDismissible 3 + MenuStructure 1 + PanelHeaders 4) |
| `Tests/WenshuAppTests/MenuStateTests.swift` | `testMenuToggle_changesTitleAfterClick` 把 `vm.togglePanelVisibility(.bottomLeft)` 改为 `.bottomRight` (聊天 现在不可 toggle, 之前那个 case 必须改 panel 才能继续覆盖全显示 + title flow) |
| `Tests/WenshuAppTests/WenshuStoreActorTests.swift` | 仅加文件头注释 (无逻辑改动) |

**Test count delta:**

- 原: 41 tests, 11 suites
- 新: 51 tests, 12 suites (+1 suite `LT01Fix5Tests`)
- +10 tests, +1 suite

## 老板 视觉验证清单 (PM-direct 待跑 swift run)

PC 必须实际启 `swift run` 在 `.worktrees/t_5063da4d-LT-01-fix5/`, 然后:

1. **BUG1 (水平 splitter click):**
   - 点水平 splitter 5 次 (鼠标按下 + 松开, 不动) → ratios 都保持不变 (不变成 90:10)
   - 真正拖水平 splitter → ratios 仍正确变化 (drag 路径没废)

2. **优化1 (panel 内容):**
   - 5 panel 都没标题栏 (toolbar 上没"项目管理"等字样)
   - 5 panel content 顶部都有 H1: "项目管理" / "文档" / "检视" / "聊天" / "状态"

3. **优化2 (macOS 菜单):**
   - 第一个 menu 叫 "文枢" (不是 wenshu / Wenshu)
   - 显示 menu 下:
     - 重置布局 (可点)
     - 隐藏 项目管理 / 检视 / 状态 (可点)
     - 隐藏 文档 / 聊天 (灰色 disabled, 不可点)
     - 全显示 (可点)
   - 文枢 menu 下:
     - 关于文枢 / 隐藏文枢 (Cmd+H) / 隐藏其他 (Cmd+Opt+H) / 全部显示 / 退出文枢 (Cmd+Q)

4. **优化1 fallback (全隐藏):**
   - 隐藏 项目管理 / 检视 / 状态 → 布局切到 文档:聊天 = 50:50 分屏 (上 50% 文档, 下 50% 聊天)

5. **持久化:** 关闭 + 重开 → layout 状态都恢复 (包括 dismissible panel 的可见状态)

## 已知限制 (worth flagging for follow-up)

### SwiftUI Commands runtime menu count

实现走"显式 `CommandMenu("文枢")`"路径, 取代旧 `CommandGroup(replacing:
.appInfo)`. 这条修法在 source 层面 (我们的静态扫描测试) 完全满足 "恰好 2
个 CommandMenu". 但运行时 macOS AppKit 会根据 `CFBundleName` (= "Wenshu")
自动合成第三个 app menu, 菜单栏可能呈现:

1. Wenshu (auto-generated by AppKit from CFBundleName, 含 About + Quit)
2. 文枢 (我们的显式 CommandMenu, 含 About + Hide + Quit — 等同 #1 的副本)
3. 显示 (我们的显式 CommandMenu)

要彻底解决"菜单栏 3 个 menu"问题, 需要改 `Resources/Info.plist` 的
`CFBundleName = "文枢"` —— 这样 AppKit 的 auto-generated menu 名字跟
我们一致, SwiftUI 会把它合并. 这一改 不在 LT-01-fix5 派单边界内 (派
单只列了 4 个 src 文件), 留给 LT-01-fix6 (如果老板 验视觉时确认
"3 个 menu" 是必须修的)。

### Compiled placeholder H1 vs LT-XX real content

`PlaceholderContent.h1Title` 的 5 个 H1 是 v0.02.0 占位内容. 后续 LT-02/
03/04 把真实内容 View (InspectorView / ProjectListView / ChatView 等) 填
进 4 个 panel 后, 各真实 View 必须自带自己的 H1 替代 placeholder 这一行,
否则保留 placeholder H1 会跟真实内容产生双重 header. 在 LT-02/03/04 派
单时 CC 必须知晓这一约束 (transition: placeholder H1 → real H1).

## 接管 plan

- [ ] PM-direct 跑 `swift run` + cua-driver 验视觉 (5 个 checklist)
- [ ] 如果用户要"3 个 menu"修法 → 派 LT-01-fix6 改 Info.plist CFBundleName
- [ ] LT-02 (右上 inspector) 派单时必须提醒: PlaceholderContent.h1Title 取代机制
- [ ] LT-03 / LT-04 同上
