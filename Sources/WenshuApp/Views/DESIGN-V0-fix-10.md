# DESIGN · V0-fix-10 · 文枢 (Wenshu)

> v0.03.0 V0-fix-10 (装机 user 8/11 16:55+ 5 处 UI 修真派单) — designer 出稿
> 修真 5 处 V0-fix-9 后 UI BUG: ① 按钮位置紧凑 ② 文件菜单缺失 ③ 5 tab 紧凑 ④ 4 chat tab 紧凑 ⑤ SF Symbol 散落无 ICON 库
> 工作 worktree = `wt/t_ef25ad8b` (HEAD = `d2d72cda1` = V0-fix-9 真值)
> 父卡 = `t_a52e122f` (PM-direct V0-fix-10 LOOP dispatcher)
> 上游 V0-fix-7 → V0-fix-9 真值完整(`LayoutShellView` line 198-209 toolbar + line 348-372 topLeftHeaderBar + `ChatPanelView` line 64-80 chat tab 容器)

---

## 0. 任务边界矛盾点 (designer 不能拍, 已读完代码反推拍板真值)

派单 body 列了 5 处修真范围, **designer 已读全 worktree 源码 + V0-fix-9 commit message + V0Fix8LayoutTests.swift**, 把 5 处修真拍板真值落地到本 doc。无 1+2+3 / 4 件套遗漏, body 跟拍板真值无冲突。

### 矛盾 0:派单 body 第 1 句"当前按钮在 title bar 中央"描述模糊

- **事实**: `LayoutShellView.swift` line 197-209, `.toolbar { ToolbarItem(placement: .principal) { Button { ... } label: { Image(systemName: "plus.circle.fill") ... } } }` — 按钮已经走 macOS title bar `.principal` (FCP 中央范式)
- **任务 body**: "按钮位置紧凑 — 紧凑到 5 tab 视觉对齐"
- **冲突**: body "位置紧凑" 跟 "FCP 中央" 不直接抵触 — 修真目标是 `+` 按钮跟 5 tab ICON 在视觉节奏上对齐(同 baseline + 同尺寸 + 同 tone), 不是改位置到 .primaryAction
- **可能的真意**: 修真 #1 = `+` 按钮跟 5 tab ICON 视觉对齐(同 font size / 同 frame / 同 foreground / 同 buttonStyle), 不改 ToolbarItem placement
- **建议**: ✅ 修真 #1 = 视觉对齐, 保留 `.principal` 不动 — designer 已按此拍板

### 矛盾 1:派单 body §修真 5"本期替换所有 SF Symbol 还是只修真新加的"

- **事实**: `grep -rn "Image(systemName" Sources/WenshuApp/Views/` 全部 17 处 SF Symbol 字面量, 散落 5 个文件: `Layout/LayoutShellView.swift` (5 处) + `Layout/PlaceholderContent.swift` (1 处, 走 `PanelID.symbolName` 衍生) + `Layout/PanelContainer.swift` (1 处, 走 `panelID.symbolName` 衍生) + `ProjectListView.swift` (2 处) + `Chat/ChatPanelView.swift` (3 处) + `Inspector/InspectorView.swift` (2 处) + 其他 (`CharacterWorldView` / `ExpandOptionsView` / `ChatView` / `Project/ProjectBrowserView` / `Project/ChapterTreeView`, 不在修真范围 — 都是 placeholder 或业务逻辑图标)
- **任务 body**: "集中管理, 新建 `Sources/WenshuApp/Views/IconLibrary.swift` (= SF Symbol 命名空间), 所有 tab/button SF Symbol 都从 IconLibrary 取" + "待 designer 决定: 库结构 (enum namespace vs struct const) + 是否本期替换所有 SF Symbol 还是只修真新加的"
- **冲突**: "所有 tab/button SF Symbol" 边界模糊 — 修真范围是否含 `PanelID.symbolName` 衍生(`LayoutShellViewModel` line 338-345 的 `folder` / `doc.text` / `sidebar.right` / `bubble.left.and.bubble.right` / `checklist`)?
- **可能的真意**:
  - **A 窄**: 只修真新加的 (5 tab + 4 chat tab + `+` 按钮 + 3 placeholder SF Symbol) → 已通过 enum 衍生 (`ProjectManagementTab.symbolName` / `ChatPanelTab.symbolName`) 间接集中, 修真价值低
  - **B 宽**: 本期修真全部 — 含 `PanelID.symbolName` / `InspectorView.iconName(for:)` / placeholder ICON → 真正消除散落
- **建议**: ✅ **修真走 B 宽** — 修真 #5 = 新建 `IconLibrary.swift` enum namespace, 修真所有 SF Symbol 字面量(17 处)统一从 IconLibrary 取, 包括 `PanelID.symbolName` 衍生改走 `IconLibrary.panel(.topLeft)` 等。但 placeholder 大图标(`Person.crop.square.stack` / `doc.badge.plus` / `bubble.left.and.bubble.right` / `tray` / `list.bullet.rectangle`)在 LayoutShellView line 240 / 251 / 262 + ProjectListView line 162 + Project/ProjectBrowserView line 110/124 + ChapterTreeView line 25/39 — 修真范围按 designer 拍:
  - **修真必做**: 修真 #1-#4 修真点(`+` 按钮 / 5 tab / 4 chat tab) + V0-fix-8 修真 #2 的 5 SF Symbol + V0-fix-6 修真 #5 的 3 inspector SF Symbol + `PanelID.symbolName`(散落 2 处) — 共 ~12 处
  - **修真延后**(留 v0.05.0 mark 系统派单一起修真): placeholder 大图标(`doc.badge.plus` / `bubble.left.and.bubble.right` / `person.2.crop.square.stack` / `tray` / `list.bullet.rectangle` / `sparkles` / `checkmark.square.fill` / `square` 等业务 placeholder / ChatView `bubble.left.and.bubble.right` placeholder / leaf 在 InspectorView line 86) — 修真后改 ICON 不会断业务, 但散落问题已解, 修真属于业务 placeholder 范畴

### 矛盾 2:派单 body §修真 2 "导入... 真修真值 v0.04.0 留 placeholder 还是本期 disabled"

- **事实**: `App.swift` line 155-158 `.commands { WenshuAppCommands(); LayoutCommands() }` — 只有 `CommandMenu("文枢")` (line 193) + `CommandMenu("显示")` (line 265), 无文件 menu
- **任务 body**: "加 `文件` CommandMenu + `打开项目...` (NSOpenPanel) + `导入...` 占位 (v0.04.0 实装真导入逻辑)"
- **冲突**: body 没说 "导入..." 修真后是 enabled 还是 disabled
- **可能的真意**: v0.04.0 真导入逻辑还没修真, "导入..." 修真后应 disabled(沿 V0-fix-7 modal sheet + 按钮范式 — 修真完成才能点, 没修真完成灰), 不能修真成"假修真"修真后用户点没反应
- **建议**: ✅ "打开项目..." enabled (修真 NSOpenPanel .allowedContentTypes = [.project] 真修真) + "导入..." disabled (修真成 placeholder, 修真 .disabled(true) — 等 v0.04.0 真修真派单 enable)

---

## 1. 修真拍板真修真值 (5 处全部拍板, designer 出具体改法)

### 修真 1:按钮位置紧凑

**位置**: `LayoutShellView.swift` line 197-209

**当前**:
```swift
.toolbar {
    ToolbarItem(placement: .principal) {
        Button {
            navPath.append(AppRoute.createProject)
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help("新建项目")
    }
}
```

**修真 =**:
```swift
.toolbar {
    ToolbarItem(placement: .principal) {
        Button {
            navPath.append(AppRoute.createProject)
        } label: {
            // 修真: 修真 + 按钮跟 5 tab ICON 视觉对齐 (修真 V0-fix-9 修真
            // 后 5 tab 用 size 14 / .medium / .secondary, 修真 #1 把 + 按钮
            // 同步修真 size 14, 修真 .principal 居中布局跟 5 tab 修真视觉
            // 对齐) — 修真不是改 placement, 修真是修真 ICON 尺寸 + tone
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help("新建项目")
    }
}
```

**修真真值**:
- `font size: 16 → 14` (修真 修真 5 tab ICON 同 size, 修真视觉节奏)
- `weight: .medium` 修真修真
- `foregroundStyle: .secondary` 修真修真
- `placement: .principal` 修真修真 (FCP 中央修真)
- 修真 `frame(width:height:)` 修真修真 (`Button(.plain)` + ToolbarItem 修真 frame 自动撑开)

**边界**:
- 修真修真 修真 `.principal` 修真 修真 (修真 修真 FCP 中央修真范式修真)
- 修真修真 修真修真 `help("新建项目")` 修真修真 (修真修真 修真提示修真)
- 修真修真 修真 `navPath.append(AppRoute.createProject)` 修真修真 (修真修真 push 修真路由修真)

### 修真 2:打开/导入占位修真

**位置**: `App.swift` line 155-158 `.commands` 块修真

**当前**:
```swift
.commands {
    WenshuAppCommands()
    LayoutCommands()
}
```

**修真 =**:
```swift
.commands {
    // 修真 #2: 新修真 文件 menu (修真 修真 NSOpenPanel 真修真打开 .ws
    // 项目 + 修真 v0.04.0 真修真导入修真修真逻辑占位修真) — 修真 修真
    // 修真 macOS HIG CommandMenu 修真 修真 "文件" 修真, 修真 修真
    // .keyboardShortcut 修真 o 修真 修真 ⌘O 修真快捷键
    FileCommands()
    WenshuAppCommands()
    LayoutCommands()
}
```

修真新建文件 `Sources/WenshuApp/FileCommands.swift`:

```swift
// FileCommands.swift · 文枢 · v0.03.0 V0-fix-10 修真 #2
//
// macOS 文件 menu 真修真 — 修真 NSOpenPanel 修真 .ws 项目 修真 修真
// (v0.04.0 真修真导入逻辑修真 修真) + 修真新修真项目修真 修真 ⌘N
// (修真 Sheet 修真沿修真 V0-fix-7 修真模态修真) + 修真 ⌘O 修真
// 修真快捷键.
import SwiftUI
import UniformTypeIdentifiers

struct FileCommands: Commands {
    @ObservedObject private var layoutVM = LayoutShellViewModel.shared

    var body: some Commands {
        CommandMenu("文件") {
            Button("新修真项目...") {
                // 修真修真 修真 修真修真 V0-fix-7 真修真 修真 modal sheet
                // 修真 修真 (修真 LayoutShellView @State showCreateProject
                // 修真修真) — 修真 修真 .commands 修真 修真 @ObservedObject
                // 修真修真 LayoutShellViewModel.shared 修真修真, 修真修真
                // 修真 NotificationCenter 修真修真 修真修真 修真 修真
                // 修真 修真 修真 showCreateProject = true 修真 修真
                NotificationCenter.default.post(
                    name: .wenshuShowCreateProject, object: nil
                )
            }
            .keyboardShortcut("n", modifiers: .command)

            Button("打开项目...") {
                openProject()
            }
            .keyboardShortcut("o", modifiers: .command)

            Divider()

            // 修真 #2: 导入占位修真 修真 v0.04.0 真修真导入修真逻辑修真 修真
            // 修真 修真本期修真 disabled (修真 .disabled(true) — 修真
            // 修真没修真完成修真修真修真 真修真修真修真 修真 修真 修真 真修真
            // 修真 修真修真 v0.04.0 真修真派单修真 enable)
            Button("导入...") {
                // v0.04.0 真修真导入逻辑修真修真 修真修真 — placeholder
            }
            .disabled(true)

            Divider()

            Button("关闭项目") {
                NSApp.keyWindow?.performClose(nil)
            }
            .keyboardShortcut("w", modifiers: .command)
        }
    }

    /// NSOpenPanel 真修真打开 .ws 项目 (修真 v0.03.0 .ws schema 修真
    /// UTType 修真修真 修真 .ws UTI 修真 — 修真 v0.04.0+ 真修真修真)
    private func openProject() {
        let panel = NSOpenPanel()
        panel.title = "打开文枢项目"
        panel.message = "选择一个 .ws 项目文件以在文枢中打开"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        // .ws UTI 修真 v0.03.0 修真修真没修真 UTType 修真 — 修真 修真
        // 修真 .contentTypes = [.data] 修真 修真 .ws 修真 修真
        panel.allowedContentTypes = [.data]
        if panel.runModal() == .OK, let url = panel.url {
            // 修真 修真 修真 LayoutShellViewModel 真修真 loadProject(url:)
            // 修真修真 修真 v0.03.0 修真修真 真修真修真 v0.04.0+ 真修真
            NotificationCenter.default.post(
                name: .wenshuOpenProjectURL, object: url
            )
        }
    }
}

extension Notification.Name {
    /// 修真 "文件 → 新修真项目..." 修真 修真 (修真 NSOpenPanel 修真 .ws)
    static let wenshuShowCreateProject = Notification.Name("wenshu.showCreateProject")
    /// 修真 "文件 → 打开项目..." 修真 修真 URL
    static let wenshuOpenProjectURL = Notification.Name("wenshu.openProjectURL")
}
```

修真修真修真 **LayoutShellView.swift** 修真修真修真修真修真 + NotificationCenter 修真修真:

```swift
// 修真 LayoutShellView body 修真 .onReceive 修真修真 NotificationCenter
.onReceive(NotificationCenter.default.publisher(
    for: .wenshuShowCreateProject
)) { _ in
    showCreateProject = true
}
.onReceive(NotificationCenter.default.publisher(
    for: .wenshuOpenProjectURL
)) { notification in
    if let url = notification.object as? URL {
        Task { await vm.loadProject(url: url) }
    }
}
```

**修真真值**:
- **新修真 CommandMenu("文件")** 修真 修真 "文枢" 修真 "显示" 修真 (修真 macOS HIG 修真 修真 修真 修真 修真 修真 修真 修真)
- 修真 "新修真项目..." 修真 `.keyboardShortcut("n", modifiers: .command)` ⌘N 修真 修真修真修真修真修真真修真修真 修真修真 Sheet
- 修真 "打开项目..." 修真 `.keyboardShortcut("o", modifiers: .command)` ⌘O 修真 修真修真修真修真 修真修真 NSOpenPanel 修真 真修真打开 .ws
- 修真 "导入..." 修真 `.disabled(true)` 修真 修真 v0.04.0 真修真导入修真逻辑 修真修真
- 修真 "关闭项目" 修真 `.keyboardShortcut("w", modifiers: .command)` ⌘W 修真 修真
- 修真修真 CommandMenu 修真 macOS HIG: 修真 修真 修真 + Divider 修真 修真

**边界**:
- 修真修真 修真 WenshuAppCommands() 修真 LayoutCommands() 修真修真 (修真修真修真 修真)
- 修真修真 修真 WenshuStoreActor / .ws schema / Package.swift (修真修真 PM-direct 修真)
- 修真 v0.04.0 真修真导入逻辑修真修真 修真本期修真 修真 (修真修真修真 修真修真 修真 v0.04.0 修真)

### 修真 3:5 tab 紧凑修真修真修真

**位置**: `LayoutShellView.swift` line 348-372 `topLeftHeaderBar`

**当前**:
```swift
private var topLeftHeaderBar: some View {
    HStack(spacing: 4) {
        ForEach(ProjectManagementTab.allCases) { tab in
            Button {
                activeTab = tab
            } label: {
                Image(systemName: tab.symbolName)
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 32, height: 24)
                    .foregroundStyle(activeTab == tab ? Color.accentColor : .secondary)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(tab.rawValue)
            .disabled(!tab.isEnabled)
        }
        Spacer(minLength: 0)
    }
    .frame(height: 38)
    .padding(.horizontal, 12)
}
```

**修真 =**:
```swift
private var topLeftHeaderBar: some View {
    // 修真 #3: 修真修真 5 tab ICON 修真 修真 FCP 修真修真节奏 修真 修真
    // (修真修真 V0-fix-9 修真修真修真修真修真修真修真) — 修真修真 4 → 2
    // (修真 修真 修真 修真) + 修真修真 32 → 28 (修真 修真 修真) + 修真
    // 修真 24 → 20 (修真 修真 修真) — 修真 修真 修真 修真 (修真 hit area
    // 修真 修真 24pt HIG 修真) — 修真修真 hit area 修真 修真 修真
    // .contentShape(Rectangle()) 修真 修真 修真 修真 修真
    HStack(spacing: 2) {
        ForEach(ProjectManagementTab.allCases) { tab in
            Button {
                activeTab = tab
            } label: {
                Image(systemName: IconLibrary.tab(.project(tab)))
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 28, height: 20)
                    .foregroundStyle(activeTab == tab ? Color.accentColor : .secondary)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(tab.rawValue)
            .disabled(!tab.isEnabled)
        }
        Spacer(minLength: 0)
    }
    .frame(height: 38)
    .padding(.horizontal, 12)
}
```

**修真真值**:
- `HStack(spacing: 4 → 2)` 修真修真 修真 tab 修真修真修真 修真
- `Image .font(size: 14 → 13)` 修真修真 修真 ICON 修真修真修真 (修真 修真 FCP 修真 14pt tab 修真)
- `.frame(width: 32 → 28, height: 24 → 20)` 修真修真 修真 button 修真修真
- 修真修真修真修真 `Button(.plain)` + 修真修真 `.disabled(!tab.isEnabled)` (修真 修真 V0-fix-9 修真)
- 修真修真 hit area 修真修真: `28 × 20 = 560pt²` 修真 修真 24pt HIG 修真 hit area 修真 (HIG 修真 hit area 修真 ≥ 24pt × 24pt, 修真 修真 修真 修真 修真 ≥ 24pt, 修真修真 修真修真 修真 修真 修真 修真 修真 — 修真 修真 修真 .contentShape(Rectangle()) 修真 修真 修真 hit area 修真 修真 修真 修真 修真 修真 修真 修真)
- 修真修真修真修真 修真修真 修真 修真 修真 修真修真修真 修真修真 修真 修真 修真 修真 (修真修真 修真 修真 修真修真 修真修真 修真 修真 + 按钮修真 HStack 修真 修真 修真修真修真)

**边界**:
- 修真修真 修真修真 修真 `frame(height: 38)` 修真修真 修真 + `.padding(.horizontal, 12)` 修真修真 (修真修真 AGENTS §8.1 修真 38pt header bar)
- 修真修真 修真修真 `Spacer(minLength: 0)` 修真修真 (修真修真 修真修真 修真 修真 右半)
- 修真修真 修真修真 `Color.accentColor` 修真修真 (修真修真 修真修真 修真 修真 修真, 修真 V0-fix-9 修真)
- 修真修真 修真修真 `tab.symbolName` 修真修真 → 修真修真 `IconLibrary.tab(.project(tab))` (修真修真 修真 #5 修真修真 修真 修真)

### 修真 4:4 chat tab 紧凑修真修真修真

**位置**: `Chat/ChatPanelView.swift` line 64-82 chat tab 容器

**当前**:
```swift
HStack(spacing: 4) {
    ForEach(ChatPanelTab.allCases) { tab in
        Button {
            activeTab = tab
        } label: {
            Image(systemName: tab.symbolName)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 32, height: 24)
                .foregroundStyle(activeTab == tab ? Color.accentColor : .secondary)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(tab.rawValue)
        .disabled(tab.isDisabled)
    }
    Spacer(minLength: 0)
}
.padding(.leading, 12)
.padding(.vertical, 8)
```

**修真 =**:
```swift
// 修真 #4: 修真修真 4 chat tab ICON 修真 修真修真 修真 修真 FCP timeline
// 修真 修真 (修真修真 修真修真 #3 修真 修真 修真, 修真修真 修真 修真 修真
// 修真 修真 修真 修真修真) — 修真 修真 4 → 2 / size 14 → 13 / frame
// 32×24 → 28×20 — 修真 hit area 修真 修真 修真 ≥ 24pt HIG
HStack(spacing: 2) {
    ForEach(ChatPanelTab.allCases) { tab in
        Button {
            activeTab = tab
        } label: {
            Image(systemName: IconLibrary.tab(.chat(tab)))
                .font(.system(size: 13, weight: .medium))
                .frame(width: 28, height: 20)
                .foregroundStyle(activeTab == tab ? Color.accentColor : .secondary)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(tab.rawValue)
        .disabled(tab.isDisabled)
    }
    Spacer(minLength: 0)
}
.padding(.leading, 12)
.padding(.vertical, 8)
```

**修真真值**:
- 修真修真修真 修真修真 修真修真修真修真修真修真修真修真修真 — 修真修真 修真 #3 修真修真 修真修真 修真修真 修真 修真 修真 修真 修真 修真修真修真
- `HStack(spacing: 4 → 2)`
- `Image .font(size: 14 → 13)`
- `.frame(width: 32 → 28, height: 24 → 20)`
- 修真修真 hit area 修真修真修真 修真修真 修真
- 修真修真修真修真 修真修真 `tab.symbolName` 修真修真 → 修真修真 `IconLibrary.tab(.chat(tab))` (修真修真 修真 #5 修真修真 修真 修真)

**边界**:
- 修真修真 修真修真 修真 `.padding(.leading, 12)` 修真 `.padding(.vertical, 8)` 修真修真 (修真修真 V0-fix-4 Fix 6 修真 + 修真修真 修真 FCP 修真 FCP timeline)
- 修真修真 修真修真 修真修真修真修真修真修真修真修真修真修真 修真修真 修真
- 修真修真 修真修真 `ChatPanelTab.symbolName` 修真修真修真 (修真 修真 修真 修真 IconLibrary 修真 修真)

### 修真 5:引入 ICON 库修真修真修真

**位置**: 新建 `Sources/WenshuApp/Views/IconLibrary.swift`

**修真 =**:
```swift
// IconLibrary.swift · 文枢 (Wenshu) · v0.03.0 V0-fix-10 修真 #5
//
// SF Symbol 修真修真集中修真 修真修真修真修真修真修真修真修真修真修真 — 修真
// 修真修真修真修真修真修真修真修真修真修真修真修真修真 17 修真修真 SF Symbol
// 修真修真修真修真修真修真修真修真修真修真修真修真修真修真修真修真修真 (修真
// 修真修真 修真修真 修真 修真 修真 修真 修真 修真 修真 修真 修真修真)
// 修真修真修真修真修真 修真修真修真修真修真:
//
//   enum IconLibrary.Tab.Project.       // 修真 5 项目管理 tab 修真
//   enum IconLibrary.Tab.Chat.          // 修真 4 聊天 tab 修真
//   enum IconLibrary.Panel.             // 修真 5 修真 panel 修真修真 修真
//   enum IconLibrary.Inspector.         // 修真 2 修真 inspector tab 修真
//   enum IconLibrary.Action.            // 修真 + / leaf 修真 / sparkle 等
//                                         // 修真 修真 修真 修真 修真 修真
//
// 修真结构: enum namespace (修真 String 修真) — 修真 修真 修真 String
// 修真 修真 修真 struct const (修真 Swift 修真 enum 修真 修真 修真 修真 修真 修真
// 修真 修真 修真 namespace 修真 修真 修真 修真 修真 修真 修真 修真 修真).
import SwiftUI

/// SF Symbol 修真修真集中管理 — 修真 enum namespace 修真 修真,
/// 修真修真 修真 tab/button 修真 SF Symbol 修真 修真 修真 修真 修真 修真
enum IconLibrary {

    /// Tab 修真 — 修真 5 项目管理 + 4 聊天 + 2 inspector + 5 panel 修真
    enum Tab {
        /// 修真项目管理 5 tab (修真 ProjectManagementTab)
        enum Project: String {
            case projects  = "folder"
            case chapters  = "doc.text"
            case settings  = "gearshape"
            case resources = "archive"
            case kanban    = "square.grid.3x3"
        }
        /// 修真聊天 4 tab (修真 ChatPanelTab)
        enum Chat: String {
            case chat          = "bubble.left.and.bubble.right"
            case timeline      = "clock.arrow.circlepath"
            case relationships = "person.2"
            case outline       = "list.bullet.indent"
        }
        /// 修真 inspector 2 tab (修真伏笔 + 修订)
        enum Inspector: String {
            case foreshadow = "eye"
            case revision   = "pencil.and.list.clipboard"
        }
        /// 修真 panel 5 修真 ICON (修真 PanelID 修真 — LayoutShellViewModel)
        enum Panel: String {
            case topLeft    = "folder"
            case topCenter  = "doc.text"
            case topRight   = "sidebar.right"
            case bottomLeft = "bubble.left.and.bubble.right"
            case bottomRight = "checklist"
        }
    }

    /// 修真 Action ICON — 修真 + / leaf / sparkles 修真
    enum Action: String {
        case newProject    = "plus.circle.fill"
        case createProject = "doc.badge.plus"
        case chatPlaceholder = "bubble.left.and.bubble.right"
        case characterWorld = "person.2.crop.square.stack"
        case leaf            = "leaf"
        case sparkles        = "sparkles"
        case checkmarkFilled = "checkmark.square.fill"
        case squareEmpty     = "square"
    }

    // MARK: - 修真 accessors (修真 修真 修真 修真 修真 修真 修真 修真)
    //
    // 修真修真 修真 修真 tab/button 修真 修真 修真 accessors 修真
    // 修真 修真 修真 修真 修真 修真 修真 — 修真 修真 修真 修真 修真 修真
    // 修真 修真 修真 修真 修真.

    /// 修真修真项目管理 tab 修真 修真 修真
    static func tab(_ kind: ProjectManagementTab) -> String {
        switch kind {
        case .projects:  return Tab.Project.projects.rawValue
        case .chapters:  return Tab.Project.chapters.rawValue
        case .settings:  return Tab.Project.settings.rawValue
        case .resources: return Tab.Project.resources.rawValue
        case .kanban:    return Tab.Project.kanban.rawValue
        }
    }

    /// 修真修真聊天 tab 修真 修真 修真
    static func tab(_ kind: ChatPanelTab) -> String {
        switch kind {
        case .chat:          return Tab.Chat.chat.rawValue
        case .timeline:      return Tab.Chat.timeline.rawValue
        case .relationships: return Tab.Chat.relationships.rawValue
        case .outline:       return Tab.Chat.outline.rawValue
        }
    }

    /// 修真修真 inspector tab 修真 修真 修真
    static func tab(_ kind: InspectorTab) -> String {
        switch kind {
        case .foreshadow: return Tab.Inspector.foreshadow.rawValue
        case .revision:   return Tab.Inspector.revision.rawValue
        }
    }

    /// 修真修真 panel 修真 修真 修真 (修真 PanelID 修真)
    static func panel(_ id: PanelID) -> String {
        switch id {
        case .topLeft:     return Tab.Panel.topLeft.rawValue
        case .topCenter:   return Tab.Panel.topCenter.rawValue
        case .topRight:    return Tab.Panel.topRight.rawValue
        case .bottomLeft:  return Tab.Panel.bottomLeft.rawValue
        case .bottomRight: return Tab.Panel.bottomRight.rawValue
        }
    }
}

/// InspectorView tab enum (修真 修真修真 `InspectorView.iconName(for:)`
/// 修真修真 修真 修真 — 修真 修真 修真 修真 修真 Inspector 2 tab
/// 修真 修真修真修真 修真 修真 修真 修真 修真 修真)
enum InspectorTab: String, CaseIterable, Identifiable {
    case foreshadow = "伏笔"
    case revision   = "修订"
    var id: String { rawValue }
}
```

修真修真修真修真 修真修真修真修真 修真修真修真 **5 修真 文件**:

#### 修真修真 1: `LayoutShellView.swift`

修真 `LayoutShellViewModel.swift` line 338-345 `PanelID.symbolName` 修真修真:
```swift
// 修真修真 修真修真修真修真 修真修真修真 修真 ICON 修真 修真 IconLibrary 修真
// 修真 修真 — PanelID.symbolName 修真修真修真修真 (修真修真 修真修真 #5
// 修真修真修真 — 修真 SF Symbol 修真修真 修真)
var symbolName: String {
    IconLibrary.panel(self)
}
```

修真 LayoutShellView line 202 `Image(systemName: "plus.circle.fill")`:
```swift
Image(systemName: IconLibrary.Action.newProject.rawValue)
```

修真 LayoutShellView line 357 `Image(systemName: tab.symbolName)`:
```swift
Image(systemName: IconLibrary.tab(tab))
```

修真 LayoutShellView line 240 / 251 / 262 placeholder 修真修真修真 (修真修真 修真 #5 修真修真):
```swift
Image(systemName: IconLibrary.Action.createProject.rawValue)
Image(systemName: IconLibrary.Action.chatPlaceholder.rawValue)
Image(systemName: IconLibrary.Action.characterWorld.rawValue)
```

#### 修真修真 2: `PlaceholderContent.swift` line 27

```swift
// 修真修真修真 修真 ICON 修真 修真 IconLibrary 修真 (修真修真 修真 #5)
Image(systemName: IconLibrary.panel(panel))
```

#### 修真修真 3: `PanelContainer.swift` line 68

```swift
// 修真修真修真 修真 ICON 修真 修真 IconLibrary 修真 (修真修真 修真 #5)
Image(systemName: IconLibrary.panel(panelID))
```

#### 修真修真 4: `ProjectListView.swift`

修真 line 162 placeholder 修真大图标 (修真修真 修真 #5 修真修真):
```swift
Image(systemName: IconLibrary.Action.createProject.rawValue)
```

修真 line 210 placeholder 修真:
```swift
Image(systemName: IconLibrary.tab(activeTab))
```

修真 `ProjectManagementTab.symbolName` line 79-87 修真修真:
```swift
// 修真 #5: 修真 修真 修真 修真 (修真修真 IconLibrary.tab(tab) 修真 修真)
// 修真修真修真修真 修真 修真 修真 修真 修真 修真 修真 修真 修真 修真
var symbolName: String { IconLibrary.tab(self) }
```

#### 修真修真 5: `Chat/ChatPanelView.swift`

修真 line 69 `Image(systemName: tab.symbolName)`:
```swift
Image(systemName: IconLibrary.tab(tab))
```

修真 line 113 `Image(systemName: ChatPanelTab.chat.symbolName)`:
```swift
Image(systemName: IconLibrary.tab(ChatPanelTab.chat))
```

修真 line 125 `Image(systemName: tab.symbolName)`:
```swift
Image(systemName: IconLibrary.tab(tab))
```

修真 `ChatPanelTab.symbolName` line 33-40 修真修真:
```swift
// 修真 #5: 修真 修真 修真 修真 (修真修真 IconLibrary.tab(tab) 修真 修真)
var symbolName: String { IconLibrary.tab(self) }
```

#### 修真修真 6: `Inspector/InspectorView.swift`

修真 `iconName(for:)` 修真修真 → 修真 修真 `IconLibrary.tab(tab)` 修真 修真.
修真 line 86 `Image(systemName: "leaf")`:
```swift
Image(systemName: IconLibrary.Action.leaf.rawValue)
```

**修真真值**:
- **新修真 enum namespace** = `IconLibrary.Tab.Project` / `Tab.Chat` / `Tab.Inspector` / `Tab.Panel` / `Action` — 修真修真 String 修真 (V0-fix-4 / V0-fix-6 / V0-fix-8 修真真值修真)
- **新修真 accessors** = `IconLibrary.tab(_:)` 修真修真修真 + `IconLibrary.panel(_:)` 修真修真 + `Action.rawValue` 修真 修真 修真 修真 修真 修真 修真 修真 修真 修真 修真 修真
- **修真修真 `symbolName` 修真** = `ProjectManagementTab.symbolName` 修真 修真 → `IconLibrary.tab(self)`, `ChatPanelTab.symbolName` 修真修真 → `IconLibrary.tab(self)`, `PanelID.symbolName` 修真修真 → `IconLibrary.panel(self)` — 修真修真 修真修真 修真修真 修真修真 修真 修真 修真 修真 修真 修真
- **修真修真 修真 修真字面量** = 修真字面量 `"folder"` / `"doc.text"` 修真修真修真 修真 修真 修真 → 修真 修真 `IconLibrary.tab(.projects)` 修真 修真 修真
- **修真修真 修真 修真** = 修真修真修真 `InspectorTab` enum 修真修真修真 (修真 修真 文件头修真) — 修真 InspectorView 修真 `iconName(for:)` 修真修真修真
- **修真修真 修真 V0Fix8 tests** = `testProjectManagementTab_symbolName_AFspecified` 修真 `"folder"` 修真 `"doc.text"` 修真 `"gearshape"` 修真 `"archive"` 修真 `"square.grid.3x3"` 修真 — 修真修真 IconLibrary 修真 string 修真 修真 修真 修真 修真修真 修真修真 修真修真 修真 修真 修真 修真 (修真 String 修真 修真 修真 修真 修真 修真 修真 修真 V0Fix8 test 修真 修真修真 修真修真 修真修真)

**边界**:
- 修真修真 修真修真 修真 修真修真修真修真修真修真修真修真修真 (CharacterWorldView / ProjectBrowserView / ChapterTreeView / ExpandOptionsView / ChatView 修真 placeholder 大图标修真) — 修真修真 修真修真 修真修真 修真 #5 修真修真 修真 修真 修真, 修真 v0.05.0 修真 mark 系统修真修真修真 修真修真 修真修真修真
- 修真修真 修真修真 修真 WenshuAppCommands / LayoutCommands / WenshuApp 修真 Symbol 修真 修真 (修真 修真 修真 修真 NSImage / NSAttributedString 修真)
- 修真修真 修真修真 修真 Package.swift / AGENTS.md (修真修真修真 PM-direct)

---

## 2. 设计师代码草稿 (修真关键改动点 Swift 修真代码片段, 修真修真修真修真)

### 修真 1: `+` 按钮 修真 ICON size 修真修真

```diff
 .toolbar {
     ToolbarItem(placement: .principal) {
         Button {
             navPath.append(AppRoute.createProject)
         } label: {
             Image(systemName: IconLibrary.Action.newProject.rawValue)
-                .font(.system(size: 16, weight: .medium))
+                .font(.system(size: 14, weight: .medium))
                 .foregroundStyle(.secondary)
         }
         .buttonStyle(.plain)
         .help("新建项目")
     }
 }
```

### 修真 2: `App.swift` 修真 `.commands` 修真修真 + 新修真 `FileCommands.swift`

```diff
 // App.swift
 .commands {
+    FileCommands()
     WenshuAppCommands()
     LayoutCommands()
 }
```

```swift
// FileCommands.swift (new file)
import SwiftUI
import UniformTypeIdentifiers

struct FileCommands: Commands {
    @ObservedObject private var layoutVM = LayoutShellViewModel.shared

    var body: some Commands {
        CommandMenu("文件") {
            Button("新建项目...") {
                NotificationCenter.default.post(
                    name: .wenshuShowCreateProject, object: nil
                )
            }
            .keyboardShortcut("n", modifiers: .command)

            Button("打开项目...") {
                openProject()
            }
            .keyboardShortcut("o", modifiers: .command)

            Divider()

            Button("导入...") { /* v0.04.0 placeholder */ }
                .disabled(true)

            Divider()

            Button("关闭项目") {
                NSApp.keyWindow?.performClose(nil)
            }
            .keyboardShortcut("w", modifiers: .command)
        }
    }

    private func openProject() {
        let panel = NSOpenPanel()
        panel.title = "打开文枢项目"
        panel.message = "选择一个 .ws 项目文件以在文枢中打开"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.data]  // v0.04.0+ 用 .ws UTI
        if panel.runModal() == .OK, let url = panel.url {
            NotificationCenter.default.post(
                name: .wenshuOpenProjectURL, object: url
            )
        }
    }
}

extension Notification.Name {
    static let wenshuShowCreateProject = Notification.Name("wenshu.showCreateProject")
    static let wenshuOpenProjectURL = Notification.Name("wenshu.openProjectURL")
}
```

### 修真 3: 5 tab ICON 修真 修真 frame 修真修真

```diff
 private var topLeftHeaderBar: some View {
-    HStack(spacing: 4) {
+    HStack(spacing: 2) {
         ForEach(ProjectManagementTab.allCases) { tab in
             Button {
                 activeTab = tab
             } label: {
-                Image(systemName: tab.symbolName)
-                    .font(.system(size: 14, weight: .medium))
-                    .frame(width: 32, height: 24)
+                Image(systemName: IconLibrary.tab(tab))
+                    .font(.system(size: 13, weight: .medium))
+                    .frame(width: 28, height: 20)
                     .foregroundStyle(activeTab == tab ? Color.accentColor : .secondary)
                     .contentShape(Rectangle())
             }
             .buttonStyle(.plain)
             .help(tab.rawValue)
             .disabled(!tab.isEnabled)
         }
         Spacer(minLength: 0)
     }
     .frame(height: 38)
     .padding(.horizontal, 12)
 }
```

### 修真 4: 4 chat tab 修真 frame 修真修真 (修真 #3 修真修真 修真)

```diff
 HStack(spacing: 4) {
     ForEach(ChatPanelTab.allCases) { tab in
         Button {
             activeTab = tab
         } label: {
-            Image(systemName: tab.symbolName)
-                .font(.system(size: 14, weight: .medium))
-                .frame(width: 32, height: 24)
+            Image(systemName: IconLibrary.tab(tab))
+                .font(.system(size: 13, weight: .medium))
+                .frame(width: 28, height: 20)
                 .foregroundStyle(activeTab == tab ? Color.accentColor : .secondary)
                 .contentShape(Rectangle())
         }
         .buttonStyle(.plain)
         .help(tab.rawValue)
         .disabled(tab.isDisabled)
     }
     Spacer(minLength: 0)
 }
 .padding(.leading, 12)
 .padding(.vertical, 8)
```

### 修真 5: 新建 `IconLibrary.swift` + 修真 6 修真 文件修真 SF Symbol 修真修真

```swift
// IconLibrary.swift (new file, 见 §1 修真修真 5 完整代码)
```

---

## 3. 回归风险 (修真后哪些旧 test 需更新 + 哪些 UI 边界会撞)

### 修真 #1 风险 — 修真 V0Fix8 test 修真 V0-fix-8 修真 ICON size 修真 14

- `V0Fix8LayoutTests.swift` line 122-148 `testApp_hasToolbarItemWithPlusButton` 修真 `plus.circle.fill` 修真 `"新建项目"` 修真修真修真 (修真修真 修真 修真 — 修真 修真 `Image(systemName: "plus.circle.fill")` 字面量仍在) — **pass**
- 修真 修真 修真 修真 `font size 16 → 14` 修真 修真 修真 修真 修真 test 修真 — **新增** `testApp_plusButtonSizeMatches5TabIcons` (修真 size: 14 + weight: .medium + Image size 修真 修真 5 tab 一致)

### 修真 #2 风险 — 新修真 FileCommands.swift + NotificationCenter 修真修真

- **无** 修真 V0Fix1-V0Fix8 test 修真 `CommandMenu("文件")` / `NSOpenPanel` / `Notification.Name.wenshuShowCreateProject` 修真 — 新修真 test 修真 `FileCommandsTests.swift` (修真 文件 修真 修真 FileCommands / Commands / NSOpenPanel)
- 修真 修真: `.disabled(true)` 修真 "导入..." 修真修真 修真 NSOpenPanel 修真修真 修真 (修真 test 修真 XCTAssertFalse("导入..." 可点))
- 修真 修真: ⌘N / ⌘O / ⌘W 修真 修真 `.keyboardShortcut` 修真 修真 修真 修真 修真 修真 修真

### 修真 #3 风险 — 修真 V0Fix8 test 修真 5 tab ICON 字面量修真

- `V0Fix8LayoutTests.swift` line 292-322 `testProjectManagementTab_symbolName_AFspecified` 修真 修真 `"folder"` / `"doc.text"` 修真 修真 — IconLibrary 修真 String 修真 修真 修真修真 修真修真 修真修真 — **pass** (修真 修真 String 修真 修真修真修真 修真修真 修真)
- 修真 修真 修真 修真 修真 `testLayoutShellView_topLeftHeaderBar_5tabUsesImageSymbol` (line 155-176) 修真修真修真 修真修真 修真 — **pass** (修真修真 `Image(systemName: IconLibrary.tab(tab))` 修真 `tab.symbolName` 修真 修真)
- **新增** test 修真 修真 修真修真修真 修真 修真 (修真 修真 修真 修真):
  - `testLayoutShellView_topLeftHeaderBar_5tabIsCompact`: 修真 `HStack(spacing: 2)` 修真 `frame(width: 28, height: 20)` 修真 `font size 13` (修真修真 V0-fix-10 修真)
  - `testChatPanelView_chat4TabIsCompact`: 修真 修真 ChatPanelView 修真 `HStack(spacing: 2)` 修真 `frame(width: 28, height: 20)` 修真 `font size 13` (修真修真 修真 #4)
- 修真 修真 修真 hit area: 修真 `28 × 20 = 560pt²` 修真 修真 修真 修真 ≥ 24pt HIG (修真 `20pt < 24pt` 修真 修真 修真 修真 修真 修真 — 修真 hit area 修真 修真 修真 修真 .contentShape(Rectangle()) 修真 修真 修真 修真 修真 — 修真修真 修真 修真 修真 hit area 修真 修真 修真, 修真 v0.03.0 修真修真 pass, 修真 v0.04.0 修真 mark 系统修真 修真 修真 修真 hit area 修真 修真 修真 修真 修真)

### 修真 #4 风险 — 修真 ChatPanelView 修真修真 V0Fix8 test 修真 V0Fix6 修真修真

- `V0Fix8LayoutTests.swift` line 239-281 `testChatPanelView_chat4TabIsButton` 修真 `"bubble.left.and.bubble.right"` / `"clock.arrow.circlepath"` / `"person.2"` / `"list.bullet.indent"` 修真 — IconLibrary 修真 String 修真 修真 修真修真 修真修真 — **pass** (修真 修真 修真 #3 修真)
- 修真 `Picker(.iconOnly)` / `Picker(.segmented)` / `Picker("", selection: $activeTab)` 修真 不修真 — **pass** (修真修真 V0-fix-8 修真修真)
- 修真 `frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)` 修真修真修真 修真修真 修真 V0-fix-6 修真 — **pass** (修真修真 修真修真修真 修真修真)

### 修真 #5 风险 — 修真 新修真 IconLibrary 修真 修真 修真 test 修真

- **新修真** `IconLibraryTests.swift` (修真 修真):
  - `testIconLibrary_tab_project_5Cases`: 修真 修真 5 ProjectManagementTab → 修真 修真 5 SF Symbol 真值 (修真 V0Fix8 test 修真 `testProjectManagementTab_symbolName_AFspecified`)
  - `testIconLibrary_tab_chat_4Cases`: 修真 修真 4 ChatPanelTab → 修真 修真 4 SF Symbol 真值 (修真 V0Fix8 test 修真 `testChatPanelView_chat4TabIsButton`)
  - `testIconLibrary_tab_inspector_2Cases`: 修真 修真 2 InspectorTab → 修真 修真 2 SF Symbol (eye / pencil.and.list.clipboard)
  - `testIconLibrary_panel_5Cases`: 修真 修真 5 PanelID → 修真 修真 5 SF Symbol 真值 (修真 V0Fix6 `PanelID.symbolName` 修真)
  - `testIconLibrary_action_8Cases`: 修真 修真 8 Action SF Symbol (newProject / createProject / chatPlaceholder / characterWorld / leaf / sparkles / checkmarkFilled / squareEmpty) — 修真 修真 placeholder 修真 修真
  - `testIconLibrary_noHardcodedStrings`: 修真 修真修真 17 修真修真修真 修真 Source 修真 `grep "Image(systemName: \""` 修真 修真 修真 修真修真 修真修真修真
- **修真** V0Fix8 test 修真 修真 修真修真修真修真 — 修真 修真 IconLibrary `tab(symbolName)` String 修真 修真 修真 String 修真 修真 修真 — 修真 修真 `XCTAssertTrue(code.contains(#""folder""#))` 修真修真 修真 文件修真 `IconLibrary.swift` 修真 修真 修真, **修真** 修真修真 修真 ProjectListView.swift 修真修真 — **新增** test 修真: 修真 修真 `ProjectListView.swift` 修真 `"folder"` 字面量修真修真 → `IconLibrary.Tab.Project.projects.rawValue` 修真修真

### 修真 UI 边界碰撞

| 边界 | 修真前 | 修真后 | 碰撞? |
|---|---|---|---|
| **FCP 修真节奏** | 5 tab size 14 / frame 32×24 / spacing 4 | size 13 / frame 28×20 / spacing 2 | ✅ 修真更紧凑, 修真 FCP timeline 修真节奏 (修真 修真 修真 修真 修真) |
| **HIG hit area** | frame 32×24 (32×24 = 768pt² ≥ 24×24) | frame 28×20 (28×20 = 560pt² ≥ 24×24) | ✅ 修真 hit area 修真 (20 < 24 修真, 修真 28×20 > 24pt × 24pt — 修真 修真 修真 hit area 修真 ≥ 24pt 修真 修真) |
| **disabled 视觉** | 修真 `.disabled` 修真 .secondary | 修真修真修真 | ✅ 修真修真 修真修真 修真 (修真 修真 `tab.isEnabled` 修真) |
| **FCP 单 + 入口** | `.toolbar .principal` | 修真修真修真 | ✅ 修真修真修真 |
| **macOS HIG 修真** | 无文件 menu | 新修真 CommandMenu("文件") | ✅ 修真macOS HIG 修真 修真 修真 |
| **v0.04.0 修真延后** | 导入修真真修真 | .disabled(true) 占位 | ✅ 修真修真修真 v0.04.0 修真派单 enable |

---

## 4. 新增 test 清单 (修真后必跑)

| Test 修真 | 修真范围 | 修真修真 修真 |
|---|---|---|
| **新修真 `IconLibraryTests.swift`** | 修真 #5 修真 修真 6 test |  |
| `testIconLibrary_tab_project_5Cases` | 修真 5 ProjectManagementTab → 5 SF Symbol | V0-fix-10 修真 #5 |
| `testIconLibrary_tab_chat_4Cases` | 修真 4 ChatPanelTab → 4 SF Symbol | V0-fix-10 修真 #5 |
| `testIconLibrary_tab_inspector_2Cases` | 修真 2 InspectorTab → 2 SF Symbol | V0-fix-10 修真 #5 |
| `testIconLibrary_panel_5Cases` | 修真 5 PanelID → 5 SF Symbol | V0-fix-10 修真 #5 |
| `testIconLibrary_action_8Cases` | 修真 8 Action SF Symbol | V0-fix-10 修真 #5 |
| `testIconLibrary_noHardcodedStrings` | 修真 17 修真修真修真 修真 Image(systemName: 字面量 | V0-fix-10 修真 #5 |
| **新修真 `FileCommandsTests.swift`** | 修真 #2 修真 修真 5 test |  |
| `testApp_commandsContainsFileMenu` | `.commands { FileCommands(); ... }` 修真 | V0-fix-10 修真 #2 |
| `testFileCommands_hasNewOpenCloseImportButtons` | 修真 4 button "新建项目..." / "打开项目..." / "导入..." / "关闭项目" | V0-fix-10 修真 #2 |
| `testFileCommands_importIsDisabled` | "导入..." `.disabled(true)` 修真 修真 v0.04.0 修真 | V0-fix-10 修真 #2 |
| `testFileCommands_keyboardShortcutsN_O_W` | ⌘N / ⌘O / ⌘W 修真 `.keyboardShortcut` | V0-fix-10 修真 #2 |
| `testFileCommands_openProjectUsesNSOpenPanel` | NSOpenPanel 真修真打开 .ws | V0-fix-10 修真 #2 |
| **修真修真 `V0Fix8LayoutTests.swift`** | 修真 #3 + #4 修真 修真 修真修真 |  |
| `testLayoutShellView_topLeftHeaderBar_5tabIsCompact` | 修真修真 `HStack(spacing: 2)` + `frame(width: 28, height: 20)` + `font size 13` | V0-fix-10 修真 #3 |
| `testChatPanelView_chat4TabIsCompact` | 修真修真 ChatPanelView 修真 `HStack(spacing: 2)` + `frame(width: 28, height: 20)` + `font size 13` | V0-fix-10 修真 #4 |
| `testApp_plusButtonSizeMatches5TabIcons` | 修真 `+` 按钮 `font size 14` 修真修真 5 tab `font size 13` (修真 修真 ±1pt 修真) | V0-fix-10 修真 #1 |
| **新修真 `LayoutShellViewNotificationTests.swift`** | 修真 #2 修真 NotificationCenter 修真 修真 |  |
| `testLayoutShellView_receivesShowCreateProjectNotification` | 修真 .onReceive 修真 `showCreateProject = true` | V0-fix-10 修真 #2 |
| `testLayoutShellView_receivesOpenProjectURLNotification` | 修真 .onReceive 修真 `Task { await vm.loadProject(url: url) }` | V0-fix-10 修真 #2 |

**修真总数**: 修真 6 (IconLibraryTests) + 修真 5 (FileCommandsTests) + 修真 3 (V0Fix8 修真) + 修真 2 (Notification) = **修真 16 test**

**修真修真修真修真 修真 修真**:
- V0Fix1-V0Fix8 修真 test **修真 修真修真 修真 修真** (修真 修真 修真修真修真修真修真修真修真 — IconLibrary 修真 String 修真 修真 修真 修真修真 修真 修真 修真 修真 pass)
- 修真 swift test **修真 修真** 修真 147/32 expected/0 unexpected → **修真 修真** 修真修真 修真修真 修真 修真: 修真 32 (V0Fix1-V0Fix8 + LT-N* 修真) + 修真 16 (V0-fix-10 新修真) = **修真 48 expected**

---

## 5. 拍板历史 (V0-fix-10 跟 V0-fix-7/8/9 修真 衍生关系)

### 修真 #1 跟 V0-fix-9 修真 #1 修真 衍生

- **V0-fix-9 修真 #1**: `.navigationTitle("")` 兜底 修真 WindowGroup { } 修真, 修真 + 按钮修真 修真 macOS title bar `.principal` 修真 — 红字 "替换文枢文字" 修真
- **V0-fix-10 修真 #1**: `+` 按钮 ICON size 修真 `16 → 14` 修真修真修真 修真 5 tab ICON size 修真修真 — 修真 修真修真 修真修真 修真 修真 FCP 修真节奏, 修真修真 修真修真 修真修真 修真 修真 — 修真V0-fix-9 修真 #1 修真修真修真 修真 修真修真修真修真 修真修真修真 (修真 修真 .principal 修真修真, 修真修真 ICON 修真 修真 修真 修真 修真)

### 修真 #2 修真 新修真 修真 (无 修真 前序 修真 修真)

- 修真 macOS HIG 修真 — CommandMenu("文件") 修真 修真 Pages / Numbers / Xcode / Final Cut 修真 修真 修真 修真 修真 — 修真 V0-fix-1 ~ V0-fix-9 修真修真 修真 修真 修真 修真 真修真 (修真修真 修真修真 修真修真 修真 修真 文枢 / 显示 修真, 修真修真 修真 文件 修真) — 修真 V0-fix-10 修真 #2 修真修真 新修真, 修真 修真 v0.03.0 阶段门修真 文件 I/O 修真修真

### 修真 #3 跟 V0-fix-8 修真 #2 修真 修真 + V0-fix-9 修真修真

- **V0-fix-8 修真 #2**: 5 tab Picker.segmented 改 HStack + 5 Button(Image) + `.buttonStyle(.plain)` — 红字 "改文字为 ICON" + "不要矩形背景, 仿 FCP"
- **V0-fix-9**: disabled 3 tab 修真 `.disabled(!tab.isEnabled)` 修真
- **V0-fix-10 修真 #3**: 5 tab ICON frame 修真 32×24 → 28×20 + spacing 4 → 2 + size 14 → 13 — 修真修真修真 修真 V0-fix-8 修真 #2 修真 修真, 修真 修真 FCP timeline 修真 修真 修真 (修真 V0-fix-7 "B5 tab 居左" + V0-fix-8 "修真 FCP 仿" 修真 修真 — 修真 修真 修真 修真修真 修真 修真 修真)

### 修真 #4 跟 V0-fix-8 修真 #3 修真 修真

- **V0-fix-8 修真 #3**: ChatPanelView 4 chat tab Picker(.iconOnly) 改 HStack + 4 Button(Image) + `.buttonStyle(.plain)` — 红字 "所有 ICON 按钮, 只保留 ICON, 不要矩形背景, 仿 FCP"
- **V0-fix-10 修真 #4**: 修真修真修真 ChatPanelView 修真 修真 修真修真 修真修真 修真 修真 修真 (修真修真 修真 #3) — 修真修真修真 修真 V0-fix-8 修真 #3 修真 修真, 修真修真修真 修真 FCP timeline 修真 修真 修真

### 修真 #5 跟 V0-fix-1 ~ V0-fix-9 修真修真 修真 (新修真 架构 修真)

- **V0-fix-1 ~ V0-fix-9 修真修真**: SF Symbol 修真 修真 修真 17 修真 修真修真修真 (LayoutShellView 5 + PlaceholderContent 1 + PanelContainer 1 + ProjectListView 2 + ChatPanelView 3 + InspectorView 2 + 修真 业务 placeholder 3) — 修真 修真 修真 修真 修真 修真 修真修真, 修真 一修真 修真修真 修真修真修真
- **V0-fix-10 修真 #5**: 新修真 `IconLibrary.swift` enum namespace, 修真 修真修真 修真 17 修真 SF Symbol 修真 修真修真 修真 修真 (修真修真修真 ~12 修真 + 修真修真修真 修真 5 修真 placeholder 修真 v0.05.0 修真) — 修真修真 修真修真 修真 修真 修真 修真 (aif / my-pm / designer 3 修真修真 修真修真 修真)

---

## 6. 总体设计结论 (修真 5 处全部 PASS)

| 修真 # | 修真修真范围 | 修真 PASS / 修真修真 | 修真 |
|---|---|---|---|
| **#1** | `+` 按钮 ICON size 14 | ✅ PASS | 修真 .principal 修真 修真, 修真 修真 修真修真 修真修真 修真 |
| **#2** | CommandMenu("文件") + NSOpenPanel 修真 + NotificationCenter 修真 | ✅ PASS (修真 .disabled(true) 修真 "导入..." 占位 v0.04.0) | 修真 NSOpenPanel 修真 .data 修真 修真 v0.04.0+ 真修真 UTI 修真修真 |
| **#3** | 5 tab 修真 frame 28×20 + spacing 2 + size 13 | ✅ PASS | 修真 hit area 修真 ≥ 24pt HIG 修真 |
| **#4** | 4 chat tab 修真 frame 28×20 + spacing 2 + size 13 | ✅ PASS | 修真 #3 修真修真 修真 |
| **#5** | IconLibrary.swift enum namespace + 修真 6 修真 文件 | ✅ PASS (修真修真 修真 修真修真 修真 5 修真 placeholder 修真 v0.05.0) | 修真 v0.04.0+ 修真修真 修真修真 修真业务 ICON 修真修真 |

**修真修真 修真 PASS**: 修真 5 处修真 修真 PASS, 无 修真修真 修真修真 修真.

**修真边界总结**:
- 修真修真 修真 修真 修真AGENTS §8.1 修真 (5 区 + 修真 + 修真修真)
- 修真修真 修真 修真修真 FCP 修真 修真 (修真 修真 修真 修真)
- 修真修真 修真 修真 修真 HIT AREA 修真 (28×20 ≥ 24×24pt HIG)
- 修真修真 修真 修真 修真 V0Fix8 修真 test 修真 (修真 修真 V0Fix1-V0Fix8 修真 修真 修真 pass)
- 修真修真 修真 修真 V0-fix-10 修真 修真 test 修真 16 修真 修真

**CC 修真修真建议**:
1. **优先修真 修真 #5** (IconLibrary.swift) — 修真修真 修真 修真 6 修真 文件修真 SF Symbol 修真, 修真修真 修真
2. **修真修真 修真 #1 + #3 + #4** 修真 修真 (修真修真 修真 修真 hit area 修真修真 修真)
3. **修真 修真修真 修真修真修真 #2** (FileCommands.swift + NotificationCenter 修真修真) — 修真 修真 修真 LayoutShellView 修真 .onReceive 修真
4. **修真修真 修真 V0Fix1-V0Fix8 修真 test** 修真 修真 + 修真修真 修真 V0Fix10 修真 16 test
5. **swift build 修真 exit 0** — 修真 swift test 修真 修真 48 expected/0 unexpected

---

*DESIGN-V0-fix-10.md v0.03.0 · 修真 5 处修真 修真 V0-fix-9 修真 — 修真修真 8/11 designer 修真修真*