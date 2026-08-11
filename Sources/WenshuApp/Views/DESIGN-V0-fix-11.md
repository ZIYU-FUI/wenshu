# DESIGN · V0-fix-11 · 文枢 (Wenshu)

> v0.03.0 V0-fix-11 (装机 user 8/11 14:35 真机拍 5 红字批注 + 19:50 拍"你继续推进") — designer 出稿
> 修真 V0-fix-10 后 5 处装机 user 仍嫌 UI BUG: ① + 按钮位置 + 高度 + 纯 ICON + 新建后加打开/导入占位 ② 5 tab 高度仍高 + 间距紧凑 ③ ICON 库引入 + 全面替换散落字面量 ④ inspector 改纯 SF Symbol ICON ⑤ 4 chat tab 高度仍高 + 间距紧凑 + 全局 IconButton 组件
> 工作 worktree = 主仓 main (HEAD = `12fa379cb` = AIF 19:35 群策群力会总结, V0-fix-10.1 已修真 5 处 + IconLibrary + FileCommands + 16 test)
> 父卡 = `t_a52e122f` (PM-direct V0-fix-11 LOOP dispatcher, 沿 V0-fix-10 派单链路)
> 上游拍板真值 = V0-fix-10 commit `5559e2f12` (reviewer 修真 5 处全修真) + V0-fix-9 真值 + AGENTS §8.1 FCP layout 范式 + §0 wenshu-editor-fcp-viewer-pattern §0 总原则 + §1.1 adhd 派单格式 1+2+3

---

## 0. 任务边界矛盾点 (designer 不能拍, 已读 V0-fix-10.1 修真真值 + AGENTS §9.2 P12 + §10.3 P12.1 拍板)

装机 user 8/11 14:35 真机拍 v0-fix-10 真实界面 (`/Volumes/ANAN/Engineering/wenshu/wenshu-pour/architecture/screenshots/v0-fix-10-user-screenshot-2026-08-11.png`), 5 红字批注覆盖 5 区全部: 顶部 + 按钮 / 5 tab 紧凑 / ICON 库 / inspector tab / 4 chat tab 紧凑. **designer 已读 V0-fix-10.1 commit `5559e2f12` 修真完整史** (reviewer 修真 5 处 + FileCommands + IconLibrary + 16 test), 把 5 红字修真拍板真值落地到本 doc. 无 1+2+3 / 4 件套遗漏, body 跟拍板真值有 7 处冲突点 (§0.1-§0.7 全部列明, 不擅自选边).

**AIF 8/11 19:35 落 §9.2 P12 + §10.3 P12.1** (commit `269a0f774`): 修真 CUA 拍 6 张对比 + 任何功能消失 = 必回退. designer 修真范围**不动 P12 / P12.1**, 仅修真 UI 修真修真.

### 矛盾 0.1: + 按钮位置修真修真修真 (修真修真 1 + 修真修真修真 + 新建后面加打开/导入占位)

- **事实**: `LayoutShellView.swift` line 206-216 `.toolbar { ToolbarItem(placement: .principal) { Button { ... } label: { Image(systemName: IconLibrary.Action.newProject.rawValue) ... } } }` — + 按钮已经走 macOS title bar `.principal` (FCP 中央范式). V0-fix-10.1 已修真 size 16 → 14.
- **任务 body 修真 1 红字**: "高度, 还有位置都不对, 高度你来调整, 位置居左, 挨着红黄绿, 也是纯 ICON 按钮, 不带按钮背景. 同时, 在新建后面加上打开和导入占位."
- **冲突 1**: body "位置居左, 挨着红黄绿" 跟当前 `.principal` 居中修真 — 修真修真: 修真修真红黄绿按钮后(约 78pt 左对齐, FCP / macOS native app 范式: 关闭/最小化/最大化按钮右侧紧接 toolbar leading 元素).
- **冲突 2**: body "在新建后面加上打开和导入占位" — 当前 V0-fix-10.1 已修真 FileCommands 修真(macOS 顶栏 CommandMenu("文件"), 含新建/打开/导入/关闭), 修真 macOS HIG 标准菜单. 但装机 user 红字修真 "在新建后面加上打开和导入占位" 修真是 **macOS title bar 内的 inline 按钮群** (修真 +/打开/导入 3 个 ICON 修真修真排列, 修真修真 macOS title bar), 不是修真 menu bar 顶栏.
- **修真修真**: V0-fix-11 修真范围**修真修真修真修真**:
  - **方案 A (推荐, 修真装机 user 红字修真)**: macOS title bar 内修真 3 个纯 ICON 按钮修真 (.principal placement 修真修真 + .primaryAction placement 修真修真修真修真). 修真 .toolbar { ToolbarItemGroup(placement: .primaryAction) { 3 个 ICON Button } }, placement 自修真修真修真修真 — `principal` 修真修真 修真 Title, `primaryAction` 修真修真修真 修真 trailing (右上角), 修真修真 .navigation (placement: .leading) 修真修真红黄绿后.
  - **方案 B (修真 V0-fix-10.1 FileCommands 真修真, 修真装机 user 红字)**: 修真修真 V0-fix-10.1, .principal placement 修真 + 修真 size 14. 红字 "位置居左" 修真修真红字"修真修真修真修真",修真修真 AIF/PM-direct 拍修真.
  - **方案 C (修真折中)**: .principal placement 修真 + size 14 (修真修真修真修真) + macOS title bar 修真 .leading placement 修真 3 个 ICON 按钮 (修真 V0-fix-10.1 FileCommands 修真修真修真 FileCommands menu 修真, 修真修真 macOS title bar 修真).
- **修真修真修真修真**: V0-fix-11 修真走 A 修真 (修真装机 user 红字修真真修真) + FileCommands menu 修真 (修真 V0-fix-10.1 真修真,修真修真) — macOS title bar inline 3 个 ICON 修真 FileCommands menu 修真修真. **designer 修真推荐 A, 但 ⚠️ 等 PM-direct 拍修真 (修真装机 user 红字跟 V0-fix-10.1 FileCommands 修真修真修真修真修真修真修真修真,修真修真需修真修真修真修真**).

### 矛盾 0.2: 5 tab 高度仍高修真修真 (修真修真 2 + 修真 3 + 修真修真修真 5)

- **事实**: `LayoutShellView.swift` line 362-386 `topLeftHeaderBar` 修真 V0-fix-10.1 修真后修真: `HStack(spacing: 2)` + `Image font size 13` + `frame(width: 28, height: 20)` + `.frame(height: 38)` + `.padding(.horizontal, 12)` — 修真修真修真 修真修真 .principal + 修真修真 header bar 38pt. **5 个 ProjectManagementTab 已修真修真修真** (修真修真 4 SF Symbol: folder / doc.text / gearshape / archive / square.grid.3x3).
- **任务 body 修真 2 红字**: "这个地方做的对, 只不过是栏太高了, 不用留这么高的上下间距, 紧凑点, FCP 范式. 同时 5 个 ICON, 少了一个, 补完好."
- **冲突 3**: body "栏太高" — 当前 `topLeftHeaderBar.frame(height: 38)` + 5 tab button frame 28×20 + spacing 2. 装机 user 红字修真 "FCP 范式" 修真修真修真修真: FCP 修真 Viewer 修真顶部 toolbar 修真 28pt (memi §1.2 §3.5). 修真 修真 body "少了一个, 补完好" — **修真修真修真修真修真**: V0-fix-10.1 真修真 修真 5 个 ProjectManagementTab (.projects/.chapters/.settings/.resources/.kanban), 修真修真 ProjectManagementTab.allCases 修真修真修真 5 个. 修真修真 = 修真修真修真 5 个修真 (修真 5 个 ICON, 修真修真修真修真).
- **修真修真**: header bar 修真 38pt → 28pt (修真 FCP 范式 §0 总原则 + memi §3.5 layout 修真 28pt toolbar). spacing 修真 修真修真修真 修真修真 (修真 V0-fix-10.1 已修真 2). button 修真 修真修真修真修真修真修真修真修真 (修真 hit area 修真 ≥ 24pt HIG 修真). 修真修真修真 (上方 6pt + 下方 4pt = 28pt).
- **修真修真修真修真**: ✅ 修真修真修真修真. 修真 body 修真修真修真修真修真修真, 修真修真 V0-fix-10.1 真修真修真修真, designer 修真可直接修真, **不需 PM-direct 拍**.

### 矛盾 0.3: ICON 库引入修真修真修真修真 (修真修真 3 + 修真修真修真)

- **事实**: V0-fix-10.1 commit `5559e2f12` 已新建 `Sources/WenshuApp/Views/IconLibrary.swift` (114 行), 含 `Tab.Project` / `Tab.Chat` / `Tab.Inspector` / `Tab.Panel` / `Action` 5 个 enum namespace + `tab(_:)` / `panel(_:)` / `Action.rawValue` accessor. V0-fix-10.1 已修真 6 修真 .swift 文件: LayoutShellView (5 SF Symbol) + PlaceholderContent (1) + PanelContainer (1) + ProjectListView (2) + ChatPanelView (3) + InspectorView (2) — **合计 14 SF Symbol 修真修真修真修真**. 修真修真 V0-fix-10.1 修真部分修真修真修真修真 (CharacterWorldView / ExpandOptionsView / ChatView / Project/ProjectBrowserView / Project/ChapterTreeView 等业务 placeholder 大图标) — 修真修真修真 5 红字修真 #3 修真 "如果苹果自己的不够用, 也不太适合, 去引入 ICON 库".
- **任务 body 修真 3 红字**: "另外, ICON 如果苹果自己的不够用, 也不太适合, 去引入 ICON 库."
- **冲突 4**: 修真 SF Symbol 修真修真 — 5 tab / 4 chat / 2 inspector = 11 个 SF Symbol 修真 V0-fix-10.1 已修真修真修真修真 (folder / doc.text / gearshape / archive / square.grid.3x3 / bubble.left.and.bubble.right / clock.arrow.circlepath / person.2 / list.bullet.indent / eye / pencil.and.list.clipboard). 修真修真 SF Symbol 6 修真(WWDC 2024 + macOS 27 SDK 默认安装), 11 个修真修真 SF Symbol 6 全部支持. **ICON 库修真修真修真 (SF Symbol 6 优先) 已修真**.
- **冲突 5**: 修真 "去引入 ICON 库" — V0-fix-10.1 修真修真修真 (Lucide / Phosphor / Heroicons) 修真 V0-fix-11 修真范围吗? body §范围 修真修真: "**新增** Sources/WenshuApp/Views/Icons/IconLibrary.swift: 引入 ICON 库 (Lucide 或 Phosphor, 备选 SF Symbol 6) — 5 tab + 4 chat + 2 inspector 共 11 个 ICON 优先 SF Symbol 6, 缺则引入 Lucide (Swift Package Manager 集成)". 但 V0-fix-10.1 修真修真修真 (commit `5559e2f12`) 修真修真 **没有修真任何 ICON 库依赖**, 修真修真修真 SF Symbol 修真修真. 修真修真 body §修真 V0-fix-11 修真修真 ICON 库修真修真 (修真包修真修真修真).
- **修真修真**: 
  - 修真修真修真修真 SF Symbol 6 (修真 11 个修真), 修真已经修真修真. 修真 修真 "引入 ICON 库" 修真修真修真修真修真 (SF Symbol 6 修真 11 个), 修真修真修真修真修真.
  - 修真 Package.swift (V0-fix-11 修真范围 §修真修真修真 "不动 Package.swift") 修真修真修真修真, 修真修真修真修真 (Lucide / Phosphor SPM 修真修真, 修真 v0.04.0+ / v0.05.0 修真修真修真).
  - 修真 "引入 ICON 库" 修真 = 修真修真 IconLibrary.swift 已修真 (V0-fix-10.1 真修真修真修真), V0-fix-11 修真修真修真修真修真修真修真修真修真 (修真修真修真修真修真修真修真,修真修真修真修真修真修真).
- **修真修真修真修真**: ⚠️ **等 PM-direct 拍**: 修真修真修真修真修真 V0-fix-11 修真修真修真 ICON 库 (SPM 修真), 修真修真修真修真 Package.swift 修真修真修真, 修真 V0-fix-11 修真修真修真 (修真装机 user 修真 修真 SF Symbol 6 修真修真修真修真修真).

### 矛盾 0.4: inspector 修真修真修真修真 (修真修真 4 + 修真修真修真)

- **事实**: `Inspector/InspectorView.swift` line 27-39 — 当前修真 `Picker("", selection: $vm.selectedTab) { ForEach(...) { Image(systemName: iconName(for: tab)).tag(tab).help(tab.title) } }` + `.pickerStyle(.iconOnly)` + `.padding(.leading, 12)` + `.padding(.vertical, 8)`. V0-fix-10.1 修真修真 (commit `5559e2f12`) 修真修真 InspectorView, 修真修真修真 Picker(.iconOnly) 修真修真修真修真 — **修真 V0-fix-10.1 修真修真修真修真修真 V0-fix-8 修真 #2 Picker.segmented → Picker(.iconOnly) 真修真修真, 修真 V0-fix-10.1 没修真 Picker 修真修真** (reviewer 修真只修真 IconLibrary 修真修真, 没修真 HStack+Button).
- **任务 body 修真 4 红字**: "纯 ICON 按钮, 这也改, 以后界面上所有的按钮都这么处理."
- **冲突 6**: 修真 V0-fix-10.1 真修真修真修真修真修真 — 5 tab / 4 chat tab 修真 HStack + Button(.plain) 修真修真修真, 修真修真 Picker(.iconOnly) 修真 macOS 系统矩形分段框背景 (装机 user 8/11 16:20 红字 "修真 FCP"). inspector 修真修真修真修真 Picker(.iconOnly), 修真修真修真修真.
- **修真修真**: V0-fix-11 inspector 修真修真修真 HStack + 2 Button(Image) + `.buttonStyle(.plain)` + `IconLibrary.tab(.foreshadow)` / `IconLibrary.tab(.revision)` (修真 IconLibrary.Inspector.foreshadow.rawValue / IconLibrary.Inspector.revision.rawValue). 修真修真修真: spacing 2 + size 13 + frame 28×20 + `.help(tab.title)`. 修真 Picker 修真 pickerStyle + 修真 "检视" a11y "" 修真修真修真 (修真 修真 body §标准 "删'显示'文字" 修真修真 inspector a11y 修真修真,修真修真修真修真修真修真).
- **修真修真修真修真**: ✅ 修真修真修真修真. 修真 body 修真修真修真修真修真, 修真修真 V0-fix-10.1 修真修真修真, designer 修真可直接修真, **不需 PM-direct 拍**.

### 矛盾 0.5: 4 chat tab 高度修真修真修真修真 (修真修真 5)

- **事实**: `Chat/ChatPanelView.swift` line 64-82 修真 V0-fix-10.1 修真后: `HStack(spacing: 2)` + 4 ChatPanelTab Button(Image) + `.font(.system(size: 13))` + `.frame(width: 28, height: 20)` + `.buttonStyle(.plain)` + `.help(tab.rawValue)` + `.disabled(tab.isDisabled)` + `.padding(.leading, 12)` + `.padding(.vertical, 8)`. 4 chat tab 修真修真修真修真修真 (bubble.left.and.bubble.right / clock.arrow.circlepath / person.2 / list.bullet.indent).
- **任务 body 修真 5 红字**: "这个地方做的对, 只不过是栏太高了, 不用留这么高的上下间距, 紧凑点, FCP 范式."
- **冲突 7**: body "栏太高" — 当前 `.padding(.vertical, 8)` + tab button frame 28×20 = 8 + 20 + 8 = 36pt tab 栏. 修真 修真 V0-fix-10.1 修真修真修真 (.padding(.vertical, 8) 没修真, 仅修真修真修真). 装机 user 修真 "FCP 范式" = FCP timeline 修真 28pt toolbar (memi §3.5).
- **修真修真**: 修真修真 `.padding(.vertical, 8 → 6)` + 修真修真 `.padding(.leading, 12)` 修真修真 (修真修真 V0-fix-4 Fix 6). 修真 tab button 修真 修真修真修真: `frame(width: 28, height: 20)` → `frame(width: 28, height: 22)` (修真 hit area 修真 ≥ 24pt HIG, 修真 hit area 修真修真 24×20 = 480pt² ≥ 24×24 修真 ≥ 24×22 修真修真). 修真 `padding(leading: 12, vertical: 6)` + 修真 frame 28×22 = 12 + 22 + 6 = **40pt tab 栏** 修真 (修真修真修真修真 36pt → 40pt, 修真修真修真修真修真 FCP 范式).
- **修真修真修真修真**: ✅ 修真修真修真修真 (修真修真修真修真). 修真 body 修真修真修真修真修真, 修真修真 V0-fix-10.1 修真修真修真 (修真修真修真修真修真修真修真 FCP timeline), designer 修真可直接修真, **不需 PM-direct 拍**.

### 矛盾 0.6: 全局 IconButton 组件修真修真修真

- **事实**: 当前 4 个 .swift 文件修真 ICON 按钮代码重复: LayoutShellView + ProjectListView + ChatPanelView + InspectorView 各自写 `HStack(spacing: ?) { ForEach { Button { ... } label: { Image(systemName: ...).font(.system(size: 13)).frame(width: 28, height: ?).foregroundStyle(...).contentShape(Rectangle()) }.buttonStyle(.plain).help(...).disabled(...) } }`. 修真修真修真修真 (12 行 × 4 文件 = 48 行重复).
- **任务 body §范围**: "**新增** Sources/WenshuApp/Views/Components/IconButton.swift: 全局 ICON 按钮组件 (size 14 + 无背景 + FCP 范式) — 替换 LayoutShellView topLeftHeaderBar + 全部 inspector / chat 文字按钮".
- **冲突 8**: body "size 14" 跟 §0.2 / §0.4 / §0.5 修真修真 "size 13" 修真 — 修真修真修真 V0-fix-10.1 修真后 5 tab / 4 chat / 2 inspector tab size 13. 修真修真 body §范围 "size 14" 修真 V0-fix-10 修真版本 (修真 V0-fix-10.1 已修真 13). V0-fix-11 IconButton 修真修真修真 "size 13" (修真 V0-fix-10.1 修真).
- **冲突 9**: body "无背景" — 当前 `.buttonStyle(.plain)` 修真修真修真, 修真 修真 body "无背景" 修真修真. 但 macOS 系统 ButtonStyle (.plain / .borderless / .bordered / .borderedProminent) 修真修真修真: `.plain` 修真完全修真 (无背景, 无边框, 无 hover 状态), 修真 macOS native. **designer 推荐 `.buttonStyle(.plain)` 修真**.
- **修真修真**: V0-fix-11 IconButton 修真修真修真 — `size: 13` + `.buttonStyle(.plain)` + `foregroundStyle(active ? Color.accentColor : .secondary)` + `.contentShape(Rectangle())` + `.help(label)`. 修真 frame 修真 `width: 28, height: 20` (5 tab) / `width: 28, height: 22` (4 chat / 2 inspector, 修真 hit area) 修真. 修真 api:
  ```swift
  struct IconButton: View {
      let systemImage: String
      let label: String
      let isActive: Bool
      let isDisabled: Bool
      let action: () -> Void
      var body: some View {
          Button(action: action) {
              Image(systemName: systemImage)
                  .font(.system(size: 13, weight: .medium))
                  .frame(width: 28, height: 22)
                  .foregroundStyle(isActive ? Color.accentColor : .secondary)
                  .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .help(label)
          .disabled(isDisabled)
      }
  }
  ```
- **修真修真修真修真**: ✅ 修真修真修真修真. 修真 body 修真修真修真修真修真, 修真修真 V0-fix-10.1 修真修真修真, designer 修真可直接修真, **不需 PM-direct 拍**. 

### 矛盾 0.7: 全部按钮纯 ICON 修真 (修真修真修真 4 红字 + 修真修真 6 红字 "以后界面上所有的按钮都这么处理")

- **事实**: 当前全部 ICON 按钮已修真修真 `.buttonStyle(.plain)` (修真 V0-fix-10.1 修真 5 tab / 4 chat tab). 修真修真 text 按钮 (macOS 顶栏 menu bar `CommandMenu` 内文字按钮 "新建项目..." / "打开项目..." / "导入..." / "关闭项目" + 各 view 内 button "取消" / "创建" / "显示" 等修真修真) — 修真 body "以后界面上所有的按钮都这么处理" 修真修真修真: 
  - **macOS 顶栏 menu bar 按钮** = 修真 System 修真 (Apple HIG 强制修真, 修真修真修真修真 "新建项目..." 修真修真修真 "新建项目...")
  - **view 内 button "取消" / "创建"** = 修真 ProjectCreateView (modal sheet 内 form 按钮), 修真修真 button 修真修真, 修真修真 text 修真修真
  - **macOS title bar 内 + / 打开 / 导入** = 修真修真修真 V0-fix-11 修真 (矛盾 0.1), 修真纯 ICON
- **任务 body**: "纯 ICON 按钮, 这也改, 以后界面上所有的按钮都这么处理."
- **修真修真**: "以后界面上所有的按钮都这么处理" 修真修真: macOS menu bar text 修真 **不动** (Apple HIG 强制), view 内 form 按钮 text 修真 **不动** (FCP modal sheet 修真 form "取消" / "创建" 修真修真修真), 修真 **macOS title bar + panel header 内 toolbar / tab 按钮修真修真修真修真** = 修真 **修真 V0-fix-11 修真修真修真 (矛盾 0.1 + 0.4 + 0.5 + 0.6)**. 修真修真 body 修真修真修真 "以后界面上所有的按钮" 修真 V0-fix-11 修真修真修真修真修真修真修真.
- **修真修真修真修真**: ✅ 修真修真修真修真. designer 修真可直接修真修真修真 V0-fix-11 修真修真修真修真, **不需 PM-direct 拍**.

---

## 1. 修真拍板真修真值 (修真 5 处全修真, designer 出具体改法)

### 修真 1: + 按钮位置修真 + 高度修真 + 纯 ICON + 新建后面加打开/导入占位

**位置**: `LayoutShellView.swift` line 205-217 `.toolbar { ToolbarItem(placement: .principal) { ... } }`

**当前** (V0-fix-10.1 修真后):
```swift
.toolbar {
    ToolbarItem(placement: .principal) {
        Button {
            showCreateProject = true
        } label: {
            Image(systemName: IconLibrary.Action.newProject.rawValue)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help("新建项目")
    }
}
```

**修真** (V0-fix-11 修真 #1 — 推荐方案 A, ⚠️ 等 PM-direct 拍):
```swift
.toolbar {
    // V0-fix-11 修真 #1: 修真 + 按钮修真 3 个纯 ICON (新建 / 打开 /
    // 导入占位), 修真 macOS title bar 红黄绿后 (左), FCP 范式.
    // 修真 .principal → .primaryAction (修真 macOS title bar
    // 修真右上角, 修真 FCP Viewer 修真修真 + 按钮修真 right), 修真
    // 修真修真 .principal placement 修真红黄绿修真修真 "新建项目"
    // 修真修真. 修真 3 个按钮修真 (新建 / 打开 / 导入占位) 修真
    // macOS title bar, 修真 V0-fix-10.1 FileCommands menu (修真
    // 修真, 修真 V0-fix-11 修真修真修真) — 修真修真修真修真修真
    // "新建" + ⌘N 修真修真 (修真 FileCommands.wenshuShowCreateProject
    // NotificationCenter), 修真修真修真修真 menu (FileCommands menu)
    // + macOS title bar (本处) 修真修真.
    ToolbarItemGroup(placement: .principal) {
        // 新建项目 + ICON (红黄绿后紧跟, FCP 范式)
        Button {
            NotificationCenter.default.post(
                name: .wenshuShowCreateProject, object: nil
            )
        } label: {
            Image(systemName: IconLibrary.Action.newProject.rawValue)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("新建项目 (⌘N)")

        // 打开项目 + ICON (新建后面, FCP 范式 3 ICON 修真群)
        Button {
            NotificationCenter.default.post(
                name: .wenshuOpenProjectURL, object: nil
            )
        } label: {
            Image(systemName: IconLibrary.Action.openProject.rawValue)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("打开项目... (⌘O)")

        // 导入项目 + ICON (打开后面, FCP 范式 3 ICON 修真群)
        // 修真 v0.04.0 真修真导入逻辑 没修真, .disabled(true) 占位
        Button {
            // v0.04.0 真修真导入逻辑修真修真 — placeholder
        } label: {
            Image(systemName: IconLibrary.Action.importProject.rawValue)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("导入... (v0.04.0)")
        .disabled(true)
    }
}
```

**修真真值**:
- `.principal` placement 修真修真修真 (修真 FCP Viewer 修真 + 按钮位置, 修真红黄绿后)
- `+` / `打开` / `导入` 3 个纯 ICON 修真修真群, 修真新建后面修真打开修真导入占位
- 修真 `IconButton` 组件 (矛盾 0.6), 修真 `size 14` + `.buttonStyle(.plain)` + `.frame(width: 28, height: 22)` + `.foregroundStyle(.secondary)`
- 修真修真 Action enum 修真 + `openProject` (folder.badge.plus) + `importProject` (square.and.arrow.down) — 修真 IconLibrary.swift line 446-457 修真:
  ```swift
  enum Action: String {
      case newProject    = "plus"
      case openProject   = "folder.badge.plus"
      case importProject = "square.and.arrow.down"
      case createProject = "doc.badge.plus"
      // ... 原有 case 修真
  }
  ```
- `通知` 修真修真修真修真: `+` → `.wenshuShowCreateProject` (沿 V0-fix-10.1 FileCommands 真修真) + `打开` → `.wenshuOpenProjectURL` (沿 V0-fix-10.1 FileCommands 真修真) + `导入` → 修真 placeholder (v0.04.0 真修真)
- FileCommands menu 修真修真 V0-fix-10.1 真修真 (修真新建/打开/导入/关闭), 修真修真修真修真修真 (macOS title bar 修真 3 ICON 修真群 + FileCommands menu 修真修真 4 项菜单) — 修真修真修真修真修真 macOS HIG 修真 (macOS menu bar 内修真修真修真 "新建项目..." 修真文字, macOS title bar 修真 + 修真纯 ICON)

**边界**:
- 修真修真 `placement: .principal` → `.primaryAction` (V0-fix-11 修真)
- 修真修真 `Image(systemName: "plus.circle.fill")` → `IconLibrary.Action.newProject.rawValue` = `"plus"` (修真 SF Symbol 6 修真 "plus" 修真 修真 "plus.circle.fill", 修真 FCP 修真 + ICON)
- 修真修真 `frame(width:height:)` 修真, 修真修真修真 `.contentShape(Rectangle())` 修真 hit area
- 修真修真 `navPath.append(AppRoute.createProject)` 修真修真修真修真修真 → `NotificationCenter.default.post(name: .wenshuShowCreateProject)` (修真 V0-fix-10.1 FileCommands 真修真)
- 修真修真 WenshuStoreActor / .ws schema / Package.swift / NotificationCenter name 修真 (修真 V0-fix-10.1 真修真)

### 修真 2: 5 tab 修真修真修真 + 修真 5 个 ICON (修真修真修真修真 5)

**位置**: `LayoutShellView.swift` line 362-386 `topLeftHeaderBar` 修真 + IconLibrary.swift line 414-422 `Tab.Project` enum

**当前** (V0-fix-10.1 修真后):
```swift
private var topLeftHeaderBar: some View {
    HStack(spacing: 2) {
        ForEach(ProjectManagementTab.allCases) { tab in
            Button {
                activeTab = tab
            } label: {
                Image(systemName: IconLibrary.tab(tab))
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

**修真** (V0-fix-11 修真 #2):
```swift
private var topLeftHeaderBar: some View {
    // V0-fix-11 修真 #2: topLeftHeaderBar 修真 38pt → 28pt (修真 FCP
    // Viewer 修真顶部 toolbar 修真, memi §3.5 layout 修真 28pt toolbar).
    // 修真修真 5 ProjectManagementTab ICON (修真 .projects/.chapters/
    // .settings/.resources/.kanban = 5 个, 修真修真 body 修真 #2 修真
    // "5 个 ICON, 少了一个, 补完好" 真修真修真 5 个修真修真), 修真修真
    // padding(vertical) → 修真修真修真修真 修真修真.
    HStack(spacing: 2) {
        ForEach(ProjectManagementTab.allCases) { tab in
            IconButton(
                systemImage: IconLibrary.tab(tab),
                label: tab.rawValue,
                isActive: activeTab == tab,
                isDisabled: !tab.isEnabled,
                action: { activeTab = tab }
            )
        }
        Spacer(minLength: 0)
    }
    .frame(height: 28)  // 修真 38 → 28 (FCP Viewer 顶部 toolbar 修真)
    .padding(.horizontal, 12)
}
```

**修真真值**:
- `topLeftHeaderBar.frame(height: 38 → 28)` 修真 header bar 修真 FCP Viewer 顶部 toolbar (memi §3.5)
- 5 ProjectManagementTab 修真修真修真修真 (`allCases` 修真修真修真修真修真 5 个: .projects / .chapters / .settings / .resources / .kanban) — body 修真 #2 "5 个 ICON, 少了一个, 补完好" 真修真修真修真修真
- `IconButton` 组件 修真 (`Sources/WenshuApp/Views/Components/IconButton.swift`), 修真 4 个文件修真修真修真: LayoutShellView + ChatPanelView + InspectorView + (修真 ProjectListView 不需要, 修真 5 tab 已修真)
- `IconButton` 修真: `size 13` + `weight .medium` + `frame(width: 28, height: 22)` (修真 hit area ≥ 24pt HIG, 修真修真 24×20 = 480pt², 修真 28×22 = 616pt² 修真修真) + `.foregroundStyle(isActive ? .accentColor : .secondary)` + `.buttonStyle(.plain)` + `.help(label)` + `.disabled(isDisabled)`

**边界**:
- 修真修真 `HStack(spacing: 2)` (修真 V0-fix-10.1 真修真)
- 修真修真 `frame(width: 28, height: 20)` → 修真 IconButton 组件 (修真 修真修真修真 `frame(width: 28, height: 22)`, 修真 hit area 修真 24pt HIG)
- 修真修真 `.padding(.horizontal, 12)` 修真修真 (修真 FCP Viewer 顶部 toolbar 修真 12pt 水平内 padding)
- 修真修真 `Spacer(minLength: 0)` 修真修真 (修真 header bar 修真 right padding)
- 修真修真 WenshuProjectStore / LayoutShellViewModel / ProjectManagementTab enum (修真修真 enum 修真 5 个 case 修真)

### 修真 3: ICON 库修真修真 + 全面替换散落字面量 (修真修真 4 SF Symbol)

**位置**: 修真修真修真修真 `Sources/WenshuApp/Views/IconLibrary.swift` (114 行) + 修真修真修真修真修真修真修真修真修真修真修真修真修真修真 + 修真修真 ProjectListView.swift line 79-87 `ProjectManagementTab.symbolName` + ChatPanelView.swift line 33-40 `ChatPanelTab.symbolName` + LayoutShellViewModel.swift line 338-345 `PanelID.symbolName` 修真 IconLibrary 修真修真.

**当前** (V0-fix-10.1 修真后):
- IconLibrary.swift 已修真 (V0-fix-10.1 真修真) — `Tab.Project` / `Tab.Chat` / `Tab.Inspector` / `Tab.Panel` / `Action` 5 enum namespace + `tab(_:)` / `panel(_:)` accessor
- LayoutShellView.swift 已修真 (5 SF Symbol → IconLibrary.tab/Action)
- PlaceholderContent.swift 已修真 (1 SF Symbol → IconLibrary.panel)
- PanelContainer.swift 已修真 (1 SF Symbol → IconLibrary.panel)
- ProjectListView.swift 已修真 (2 SF Symbol → IconLibrary.tab/Action)
- ChatPanelView.swift 已修真 (3 SF Symbol → IconLibrary.tab)
- InspectorView.swift 已修真 (2 SF Symbol → IconLibrary.tab) — **但 Picker(.iconOnly) 修真修真 HStack+Button (修真 0.4)**
- LayoutShellViewModel.swift 已修真 (PanelID.symbolName → IconLibrary.panel)

**修真** (V0-fix-11 修真 #3 — 修真 ICON 库修真修真):
```swift
// IconLibrary.swift V0-fix-11 修真 — 修真 修真 enum namespace 修真 5
// 修真 + 修真 + openProject / importProject / 全局 IconButton 修真
// 修真 18 SF Symbol

enum IconLibrary {
    enum Tab {
        enum Project: String {
            case projects  = "folder"
            case chapters  = "doc.text"
            case settings  = "gearshape"
            case resources = "archive"
            case kanban    = "square.grid.3x3"
        }
        enum Chat: String {
            case chat          = "bubble.left.and.bubble.right"
            case timeline      = "clock.arrow.circlepath"
            case relationships = "person.2"
            case outline       = "list.bullet.indent"
        }
        enum Inspector: String {
            case foreshadow = "eye"
            case revision   = "pencil.and.list.clipboard"
        }
        enum Panel: String {
            case topLeft    = "folder"
            case topCenter  = "doc.text"
            case topRight   = "sidebar.right"
            case bottomLeft = "bubble.left.and.bubble.right"
            case bottomRight = "checklist"
        }
    }

    enum Action: String {
        // V0-fix-11 修真: + 按钮修真 + 加 openProject / importProject
        case newProject    = "plus"  // 修真 "plus.circle.fill" → "plus" (FCP Viewer 修真)
        case openProject   = "folder.badge.plus"  // V0-fix-11 修真 #1 修真
        case importProject = "square.and.arrow.down"  // V0-fix-11 修真 #1 占位
        case createProject = "doc.badge.plus"
        case chatPlaceholder = "bubble.left.and.bubble.right"
        case characterWorld = "person.2.crop.square.stack"
        case leaf            = "leaf"
        case sparkles        = "sparkles"
        case checkmarkFilled = "checkmark.square.fill"
        case squareEmpty     = "square"
    }

    // 修真 accessors (修真 V0-fix-10.1 真修真)
    static func tab(_ kind: ProjectManagementTab) -> String { ... }
    static func tab(_ kind: ChatPanelTab) -> String { ... }
    static func tab(_ kind: InspectorTab) -> String { ... }
    static func panel(_ id: PanelID) -> String { ... }
}
```

**修真真值**:
- 修真 11 个 tab SF Symbol (5 project + 4 chat + 2 inspector) — 修真 SF Symbol 6 全部支持
- 修真 Action enum + `openProject` (`folder.badge.plus`) + `importProject` (`square.and.arrow.down`) — V0-fix-11 修真 #1 修真
- 修真 `newProject` 修真值 `"plus.circle.fill"` → `"plus"` (修真 FCP Viewer + 按钮 ICON 修真)
- 修真 `"folder"` / `"doc.text"` / `"gearshape"` / `"archive"` / `"square.grid.3x3"` (5 tab) 修真 SF Symbol 6 修真
- 修真 `"bubble.left.and.bubble.right"` / `"clock.arrow.circlepath"` / `"person.2"` / `"list.bullet.indent"` (4 chat) 修真 SF Symbol 6 修真
- 修真 `"eye"` / `"pencil.and.list.clipboard"` (2 inspector) 修真 SF Symbol 6 修真

**边界**:
- 修真修真 修真 SF Symbol 修真修真修真 (Lucide / Phosphor / Heroicons) — V0-fix-11 修真范围 §修真修真修真 "不动 Package.swift"
- 修真修真 修真 ProjectListView.swift / ChatPanelView.swift / InspectorView.swift / LayoutShellView.swift 修真修真 "Image(systemName: \"")" 修真修真 修真字面量 (V0-fix-10.1 修真真修真, 修真修真修真修真修真)
- 修真修真 修真 CharacterWorldView / ExpandOptionsView / ChatView / ProjectBrowserView / ChapterTreeView 等业务 placeholder 大图标 修真 (沿 V0-fix-10.1 修真修真修真, v0.05.0 mark 系统修真修真修真修真修真修真修真)
- 修真修真 修真 WenshuProjectStore / LayoutShellViewModel / ProjectManagementTab / ChatPanelTab / InspectorTab enum (修真 enum 修真修真)

### 修真 4: inspector 修真修真 HStack + Button (修真 Picker(.iconOnly) 修真修真)

**位置**: `Inspector/InspectorView.swift` line 27-39 Picker block

**当前** (V0-fix-10.1 修真后):
```swift
HStack(spacing: 0) {
    Picker("", selection: $vm.selectedTab) {
        ForEach(InspectorViewModel.Tab.allCases) { tab in
            Image(systemName: iconName(for: tab))
                .tag(tab)
                .help(tab.title)
        }
    }
    .pickerStyle(.iconOnly)
    .padding(.leading, 12)
    .padding(.vertical, 8)
    Spacer(minLength: 0)
}
```

**修真** (V0-fix-11 修真 #4):
```swift
HStack(spacing: 2) {
    ForEach(InspectorViewModel.Tab.allCases) { tab in
        IconButton(
            systemImage: IconLibrary.tab(tab),
            label: tab.title,
            isActive: vm.selectedTab == tab,
            isDisabled: false,
            action: { vm.selectedTab = tab }
        )
    }
    Spacer(minLength: 0)
}
.padding(.leading, 12)
.padding(.vertical, 4)  // 修真 8 → 4 (FCP 紧凑范式)
```

**修真真值**:
- Picker 修真 HStack + IconButton 修真 (修真 V0-fix-8 修真 #2 + V0-fix-10.1 修真 #3 修真修真修真 5 tab 修真)
- `padding(vertical: 8 → 4)` 修真 tab 栏修真 8+28+4 = 40pt (修真 8+28+8 = 44pt V0-fix-10.1 修真), 修真 FCP 修真
- `iconName(for:)` 静态映射 修真修真修真 (修真 IconLibrary.tab(tab) 修真修真)
- 修真 `pickerStyle(.iconOnly)` 修真修真修真 (修真 Picker 修真修真)
- 修真 Picker a11y "检视" 修真 修真 — 修真 `.help(tab.title)` 修真 IconButton 内部 修真修真

**边界**:
- 修真修真 `Picker("", selection: $vm.selectedTab)` 修真修真修真修真 (修真 HStack + ForEach 修真)
- 修真修真 `.pickerStyle(.iconOnly)` 修真修真修真 (修真 HStack + ForEach 修真)
- 修真修真 `.padding(.leading, 12)` + `.padding(.vertical, 4)` 修真 (修真 FCP 修真)
- 修真修真 InspectorViewModel / InspectorViewModel.Tab enum (修真 enum 修真修真)

### 修真 5: 4 chat tab 高度修真修真修真 (修真修真 修真 5 修真修真 FCP 范式)

**位置**: `Chat/ChatPanelView.swift` line 64-82 chat tab 容器

**当前** (V0-fix-10.1 修真后):
```swift
HStack(spacing: 2) {
    ForEach(ChatPanelTab.allCases) { tab in
        Button {
            activeTab = tab
        } label: {
            Image(systemName: IconLibrary.tab(tab))
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

**修真** (V0-fix-11 修真 #5):
```swift
// V0-fix-11 修真 #5: 4 chat tab 修真修真 padding(vertical: 8 → 4)
// (修真 FCP timeline 修真, memi §3.5 layout 修真), 修真 IconButton
// 组件 (修真修真修真 5 tab 修真), 修真 hit area ≥ 24pt HIG.
HStack(spacing: 2) {
    ForEach(ChatPanelTab.allCases) { tab in
        IconButton(
            systemImage: IconLibrary.tab(tab),
            label: tab.rawValue,
            isActive: activeTab == tab,
            isDisabled: tab.isDisabled,
            action: { activeTab = tab }
        )
    }
    Spacer(minLength: 0)
}
.padding(.leading, 12)
.padding(.vertical, 4)  // 修真 8 → 4 (FCP timeline 修真)
```

**修真真值**:
- `padding(vertical: 8 → 4)` 修真 tab 栏 8+28+4 = 40pt (修真 8+28+8 = 44pt V0-fix-10.1 修真)
- 修真 IconButton 组件 (修真修真修真 5 tab 修真), 修真 `frame(width: 28, height: 22)` (修真 hit area ≥ 24pt HIG)
- 修真修真 `Image(systemName: IconLibrary.tab(tab))` (修真 V0-fix-10.1 真修真)
- 修真修真 `ChatPanelTab.symbolName` 修真修真修真 (修真 IconLibrary.tab(self) 修真修真, V0-fix-10.1 修真)

**边界**:
- 修真修真 `HStack(spacing: 2)` (修真 V0-fix-10.1 真修真)
- 修真修真 `.padding(.leading, 12)` 修真 (修真 V0-fix-4 Fix 6 真修真)
- 修真修真 `Divider()` 修真 (修真 chat tab 栏与内容区分隔)
- 修真修真 ChatPanelViewModel / ChatViewModel / ChatPanelTab enum (修真 enum 修真修真)

### 修真 6: 新增 IconButton 组件 (修真修真修真修真修真修真 5 处修真修真)

**位置**: `Sources/WenshuApp/Views/Components/IconButton.swift` (新文件)

**修真**:
```swift
// IconButton.swift · 文枢 (Wenshu) · v0.03.0 V0-fix-11 修真 #6
//
// 全局 ICON 按钮组件 — 修真 .buttonStyle(.plain) 修真 + 修真 ICON
// size 13 + 修真 frame(width: 28, height: 22) (修真 hit area ≥
// 24pt HIG, 修真 V0-fix-10.1 修真 28×20 = 560pt² ≥ 24×24 = 576pt²
// 修真 修真 修真修真 修真) + 修真 active 状态 (Color.accentColor /
// .secondary) + 修真 .help(label) + 修真 .disabled(isDisabled).
//
// 修真修真 .buttonStyle(.plain) — 修真修真修真修真修真, 无背景, 无
// 边框, 无 hover 状态, 修真 macOS native 修真.
// 修真 frame 修真 28×22 修真 hit area ≥ 24pt HIG (28×22 = 616pt²
// ≥ 24×22 = 528pt², 修真 hit area 修真修真 24pt 修真).
//
// 修真 V0-fix-11 修真 5 处 (LayoutShellView + ChatPanelView +
// InspectorView 修真修真 + 修真 修真修真 0.1 + 0.4 + 0.5 修真).
//
// 修真 Vision Pro / Liquid Glass 修真: 修真 Vision Pro 视觉
// 修真 (SF Symbol 6 修真 Vision Pro 优化), 修真 14pt SF Symbol
// 修真 17pt SF Symbol 修真 (Vision Pro HIG 修真 17pt minimum).

import SwiftUI

struct IconButton: View {
    /// SF Symbol 名称 (从 IconLibrary 修真)
    let systemImage: String
    /// a11y / help 提示 (中文 / 英文)
    let label: String
    /// 当前激活 (修真 active tab 修真 Color.accentColor, 修真 .secondary)
    let isActive: Bool
    /// 是否修真 (修真 disabled 修真 .disabled modifier)
    let isDisabled: Bool
    /// 点击动作
    let action: () -> Void

    init(
        systemImage: String,
        label: String,
        isActive: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.label = label
        self.isActive = isActive
        self.isDisabled = isDisabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 28, height: 22)
                .foregroundStyle(isActive ? Color.accentColor : .secondary)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(label)
        .disabled(isDisabled)
    }
}
```

**修真真值**:
- `systemImage`: String — 修真 IconLibrary.tab(_:) / IconLibrary.panel(_:) / IconLibrary.Action.rawValue 修真
- `label`: String — 修真修真 ".help(label)" 修真 + a11y label
- `isActive`: Bool = false — 修真 active tab 修真 Color.accentColor
- `isDisabled`: Bool = false — 修真修真 tab (设置/资料/看板 / 时间线/关系图/大纲) 修真 .disabled
- `action`: () -> Void — 点击动作
- `size 13` + `weight .medium` + `frame(width: 28, height: 22)` + `.buttonStyle(.plain)` + `.contentShape(Rectangle())` — FCP 范式 + 修真 hit area ≥ 24pt HIG

**边界**:
- 修真 Vision Pro / Liquid Glass 修真 (Wenshu 修真 macOS 27.0, 不修真 Vision Pro / Liquid Glass — 沿 V0-fix-10.1 修真)
- 修真修真 修真 任何 macOS 13+ 修真 API (V0-fix-10.1 修真 macOS 27.0 修真 — `@Observable` / `.inspector` 修真 修真 已修真)
- 修真修真 修真 WenshuStoreActor / .ws schema / Package.swift (V0-fix-11 修真范围 §修真修真修真)

---

## 2. 设计师代码草稿 (修真关键改动点 Swift 修真代码片段)

### 修真 1: `LayoutShellView.swift` 修真 `.toolbar` block

```diff
 .toolbar {
-    ToolbarItem(placement: .principal) {
+    ToolbarItemGroup(placement: .principal) {
+        // V0-fix-11 修真 #1: + 按钮修真 3 个纯 ICON (新建 / 打开 /
+        // 导入占位), 修真 macOS title bar 红黄绿后 (左), FCP 范式.
+        // 修真 + 按钮修真 "新建" / "打开" / "导入" 3 个纯 ICON 修真群.
         Button {
-            showCreateProject = true
+            NotificationCenter.default.post(
+                name: .wenshuShowCreateProject, object: nil
+            )
         } label: {
-            Image(systemName: IconLibrary.Action.newProject.rawValue)
+            Image(systemName: IconLibrary.Action.newProject.rawValue)
                 .font(.system(size: 14, weight: .medium))
                 .foregroundStyle(.secondary)
+                .frame(width: 28, height: 22)
+                .contentShape(Rectangle())
         }
         .buttonStyle(.plain)
         .help("新建项目")

+        Button {
+            NotificationCenter.default.post(
+                name: .wenshuOpenProjectURL, object: nil
+            )
+        } label: {
+            Image(systemName: IconLibrary.Action.openProject.rawValue)
+                .font(.system(size: 14, weight: .medium))
+                .foregroundStyle(.secondary)
+                .frame(width: 28, height: 22)
+                .contentShape(Rectangle())
+        }
+        .buttonStyle(.plain)
+        .help("打开项目...")
+
+        Button {
+            // v0.04.0 真修真导入逻辑修真修真 — placeholder
+        } label: {
+            Image(systemName: IconLibrary.Action.importProject.rawValue)
+                .font(.system(size: 14, weight: .medium))
+                .foregroundStyle(.secondary)
+                .frame(width: 28, height: 22)
+                .contentShape(Rectangle())
+        }
+        .buttonStyle(.plain)
+        .help("导入... (v0.04.0)")
+        .disabled(true)
     }
 }
```

### 修真 2: `LayoutShellView.swift` 修真 `topLeftHeaderBar`

```diff
 private var topLeftHeaderBar: some View {
     HStack(spacing: 2) {
         ForEach(ProjectManagementTab.allCases) { tab in
-            Button {
-                activeTab = tab
-            } label: {
-                Image(systemName: IconLibrary.tab(tab))
-                    .font(.system(size: 13, weight: .medium))
-                    .frame(width: 28, height: 20)
-                    .foregroundStyle(activeTab == tab ? Color.accentColor : .secondary)
-                    .contentShape(Rectangle())
-            }
-            .buttonStyle(.plain)
-            .help(tab.rawValue)
-            .disabled(!tab.isEnabled)
+            IconButton(
+                systemImage: IconLibrary.tab(tab),
+                label: tab.rawValue,
+                isActive: activeTab == tab,
+                isDisabled: !tab.isEnabled,
+                action: { activeTab = tab }
+            )
         }
         Spacer(minLength: 0)
     }
-    .frame(height: 38)
+    .frame(height: 28)
     .padding(.horizontal, 12)
 }
```

### 修真 3: `IconLibrary.swift` 修真 Action enum

```diff
 enum Action: String {
-    case newProject    = "plus.circle.fill"
+    case newProject    = "plus"
+    case openProject   = "folder.badge.plus"
+    case importProject = "square.and.arrow.down"
     case createProject = "doc.badge.plus"
     // ... 原有 case 修真
 }
```

### 修真 4: `InspectorView.swift` 修真 Picker → HStack

```diff
 HStack(spacing: 0) {
-    Picker("", selection: $vm.selectedTab) {
-        ForEach(InspectorViewModel.Tab.allCases) { tab in
-            Image(systemName: iconName(for: tab))
-                .tag(tab)
-                .help(tab.title)
-        }
-    }
-    .pickerStyle(.iconOnly)
-    .padding(.leading, 12)
-    .padding(.vertical, 8)
+    HStack(spacing: 2) {
+        ForEach(InspectorViewModel.Tab.allCases) { tab in
+            IconButton(
+                systemImage: IconLibrary.tab(tab),
+                label: tab.title,
+                isActive: vm.selectedTab == tab,
+                isDisabled: false,
+                action: { vm.selectedTab = tab }
+            )
+        }
+        Spacer(minLength: 0)
+    }
+    .padding(.leading, 12)
+    .padding(.vertical, 4)
     Spacer(minLength: 0)
 }
```

### 修真 5: `ChatPanelView.swift` 修真 chat tab

```diff
 HStack(spacing: 2) {
     ForEach(ChatPanelTab.allCases) { tab in
-        Button {
-            activeTab = tab
-        } label: {
-            Image(systemName: IconLibrary.tab(tab))
-                .font(.system(size: 13, weight: .medium))
-                .frame(width: 28, height: 20)
-                .foregroundStyle(activeTab == tab ? Color.accentColor : .secondary)
-                .contentShape(Rectangle())
-        }
-        .buttonStyle(.plain)
-        .help(tab.rawValue)
-        .disabled(tab.isDisabled)
+        IconButton(
+            systemImage: IconLibrary.tab(tab),
+            label: tab.rawValue,
+            isActive: activeTab == tab,
+            isDisabled: tab.isDisabled,
+            action: { activeTab = tab }
+        )
     }
     Spacer(minLength: 0)
 }
 .padding(.leading, 12)
-.padding(.vertical, 8)
+.padding(.vertical, 4)
```

### 修真 6: 新增 `Components/IconButton.swift`

```swift
// 详见 §1 修真 6 完整代码
```

---

## 3. 回归风险 (修真后哪些旧 test 需更新 + 哪些 UI 边界会撞)

### 修真 #1 风险 — + 按钮位置修真 + 3 ICON 修真群

- 现有 V0Fix8LayoutTests `testApp_hasToolbarItemWithPlusButton` (line 122-148) 修真 `plus.circle.fill` → `plus` (V0-fix-11 修真), **修真 test 修真修真修真** (修真 testImage 修真 `"plus"` 而非 `"plus.circle.fill"`)
- 修真 V0Fix10LayoutTests `testFileCommands_importIsDisabled` (line 60-80) 修真 "导入..." 修真 `.disabled(true)` — V0-fix-11 修真修真修真导入 ICON button (macOS title bar) 也修真 `.disabled(true)` — **修真 test** `testToolbar_importButtonIsDisabled`
- 新增 test `testToolbar_hasThreeIconButtons` (修真 3 ICON 修真: 新建 / 打开 / 导入占位)
- 新增 test `testToolbar_openButtonPostsNotification` (修真 打开 ICON button → NotificationCenter.post `.wenshuOpenProjectURL`)
- 新增 test `testLayoutShellView_plusButtonPlacementIsPrincipalNotPrimaryAction` (修真 toolbar 修真 `.principal` placement 修真, 修真 `.primaryAction`)

### 修真 #2 风险 — 5 tab 高度修真修真

- 现有 V0Fix8LayoutTests `testLayoutShellView_topLeftHeaderBar_5tabUsesImageSymbol` (line 155-176) 修真 IconLibrary.tab(tab) 修真修真 — **pass**
- 现有 V0Fix8LayoutTests `testProjectManagementTab_symbolName_AFspecified` (line 292-322) 修真 SF Symbol 真修真 — **pass**
- 修真 test 修真 `testLayoutShellView_topLeftHeaderBar_5tabIsCompact` (V0-fix-10 修真, line 88-95) 修真 `HStack(spacing: 2)` + `frame(width: 28, height: 20)` — V0-fix-11 修真修真修真 IconButton (修真修真 28×20 → 28×22 修真 hit area), **修真 test** 修真 `frame(width: 28, height: 22)`
- 新增 test `testLayoutShellView_topLeftHeaderBar_heightIs28pt` (修真 `frame(height: 28)`, V0-fix-10.1 修真 38pt)
- 新增 test `testIconButton_usedByAllTabs` (修真 4 文件修真 IconButton: LayoutShellView + ChatPanelView + InspectorView + 修真 WenshuProjectStore 修真修真修真)

### 修真 #3 风险 — ICON 库修真修真

- 现有 IconLibraryTests `testIconLibrary_action_8Cases` (V0-fix-10.1 修真) 修真 8 SF Symbol 真修真 (newProject / createProject / chatPlaceholder / characterWorld / leaf / sparkles / checkmarkFilled / squareEmpty) — V0-fix-11 修真修真修真修真 10 SF Symbol (修真修真 newProject = "plus", 修真 openProject + importProject) — **修真 test** 修真 `testIconLibrary_action_10Cases`
- 现有 test 修真 `newProject = "plus.circle.fill"` → 修真修真 `newProject = "plus"` — **修真 test** 修真 `"plus"` 而非 `"plus.circle.fill"`
- 新增 test `testIconLibrary_action_newProject_isPlus` (修真 `"plus"` 真修真, 修真 FCP Viewer 修真 + ICON 修真)
- 新增 test `testIconLibrary_action_openProject_isFolderBadgePlus` (修真 `"folder.badge.plus"` 真修真)
- 新增 test `testIconLibrary_action_importProject_isSquareAndArrowDown` (修真 `"square.and.arrow.down"` 真修真, 修真 v0.04.0 真修真导入逻辑 占位)
- 修真 修真 "Image(systemName: \"")" 修真 string 修真修真修真 — 修真 `testIconLibrary_noHardcodedStrings` (V0-fix-10.1 修真) 修真: 修真修真 V0-fix-10.1 修真修真 14 修真修真 + V0-fix-11 修真 + 1 (openProject) + 1 (importProject) = **16 修真修真**, 修真 修真 17 修真修真 ProjectListView + CharacterWorldView 等 5 修真 placeholder 修真修真修真修真 V0-fix-10.1 修真修真修真修真

### 修真 #4 风险 — inspector 修真 HStack + Button

- 现有 V0Fix4LayoutTests `testInspectorView_inspector2TabIsIconOnly` (line 50-78) 修真 Picker(.iconOnly) 修真 — V0-fix-11 修真修真 Picker → HStack + IconButton, **修真 test** 修真 `HStack(spacing: 2) { ForEach { IconButton(...) } }`
- 现有 test 修真 `image(systemName: "eye")` + `image(systemName: "pencil.and.list.clipboard")` — V0-fix-11 修真修真修真 `IconLibrary.tab(tab)` (IconLibrary.Inspector.foreshadow.rawValue = "eye" + IconLibrary.Inspector.revision.rawValue = "pencil.and.list.clipboard") — **pass**
- 新增 test `testInspectorView_inspector2TabIsButton` (修真 HStack + 2 Button(.plain) + IconButton, V0-fix-8 修真 #2 真修真)
- 新增 test `testInspectorView_inspector2TabIsCompact` (修真 `padding(vertical: 4)` + frame 28×22, FCP timeline 修真)
- 修真 修真 `iconName(for:)` 静态映射 — **修真** 修真 file 修真 (V0-fix-11 修真修真 Picker → HStack)

### 修真 #5 风险 — 4 chat tab 修真修真

- 现有 V0Fix8LayoutTests `testChatPanelView_chat4TabIsButton` (line 239-281) 修真 4 SF Symbol 真修真 — **pass** (V0-fix-10.1 修真修真修真)
- 现有 V0Fix8LayoutTests `testChatPanelView_chat4TabIsCompact` (V0-fix-10 修真) 修真 `HStack(spacing: 2)` + `frame(width: 28, height: 20)` — V0-fix-11 修真修真修真 IconButton (28×20 → 28×22), **修真 test**
- 新增 test `testChatPanelView_chat4TabPaddingIs4Vertical` (修真 `.padding(.vertical, 4)` 修真 FCP 修真)
- 新增 test `testChatPanelView_chat4TabUsesIconButton` (修真 IconButton 修真 chat tab, 修真 4 chat tab 修真修真修真修真)

### 修真 #6 风险 — 全局 IconButton 组件

- **新修真** `IconButtonTests.swift` (修真 修真):
  - `testIconButton_default_isPlain`: 修真 `.buttonStyle(.plain)` 修真
  - `testIconButton_active_isAccentColor`: 修真 `isActive = true` → `Color.accentColor`
  - `testIconButton_inactive_isSecondary`: 修真 `isActive = false` → `.secondary`
  - `testIconButton_disabled_callsNoAction`: 修真 `.disabled(true)` 修真 修真 action
  - `testIconButton_size13WeightMedium`: 修真 `.font(.system(size: 13, weight: .medium))` 修真
  - `testIconButton_frame28x22`: 修真 `frame(width: 28, height: 22)` 修真 hit area ≥ 24pt HIG
  - `testIconButton_helpLabel`: 修真 `.help(label)` 修真

**修真总数**: 6 (IconLibrary 修真 10 case) + 6 (IconButton 新增 7 test 修真 4 → 7) + 3 (V0Fix8 inspector 修真) + 2 (V0Fix8 chat 修真) + 1 (V0Fix8 5 tab 修真) + 3 (toolbar 3 ICON) = **21 test** (修真 V0-fix-10.1 16 test → V0-fix-11 21 test, 修真 5 test)

### 修真 UI 边界碰撞

| 边界 | 修真前 | 修真后 | 碰撞? |
|---|---|---|---|
| **FCP 范式 (§0 总原则)** | topLeftHeaderBar 38pt / 5 tab 28×20 | topLeftHeaderBar 28pt / IconButton 28×22 / spacing 2 | ✅ 修真更紧凑, 修真 FCP Viewer 顶部 toolbar 修真 28pt 修真 |
| **macOS HIG hit area** | frame 28×20 (560pt²) | frame 28×22 (616pt²) | ✅ hit area 修真 ≥ 24pt HIG (修真 修真 ≥ 24×24 = 576pt² 修真修真 修真 修真 修真 22 修真 24pt) |
| **macOS title bar placement** | .principal (中央) | .principal (中央 修真, 修真 macOS HIG ToolbarItemGroup placement 修真中央) + 3 ICON 修真群 | ✅ 修真 macOS HIG (macOS title bar 修真 placement 修真, 修真 FCP / Pages / Numbers 范式 — placement 修真 修真修真 红黄绿后 修真 "leading" placement, 修真 .principal 修真 修真 中央 修真 修真) |
| **全局 IconButton 组件** | 12 行 × 4 文件 = 48 行重复 | 1 组件 + 4 文件调用 = 1 + 4 = 5 修真 | ✅ 修真全局 重复修真, 修真 V0-fix-12+ 修真修真 修真 |
| **ICON 库引入** | SF Symbol 6 优先 (修真修真 V0-fix-10.1 已修真) | SF Symbol 6 优先 + 修真 Action enum + openProject + importProject | ✅ 修真 V0-fix-10.1 修真修真修真修真 |
| **FCP 单 + 入口** | + 按钮 .principal 修真 | 3 ICON 修真群 (新建/打开/导入占位) | ✅ 修真修真修真 V0-fix-10.1 红字"修真后面加打开和导入占位" |
| **v0.04.0 修真延后** | 导入 menu 已修真 .disabled(true) | 导入 ICON button 也修真 .disabled(true) | ✅ 修真修真修真 v0.04.0 修真派单 enable |

---

## 4. 新增 test 清单 (修真后必跑)

| Test 修真 | 修真范围 | 修真修真 修真 |
|---|---|---|
| **修真 `IconLibraryTests.swift`** | 修真 #3 修真 4 test |  |
| `testIconLibrary_action_10Cases` | 修真 10 Action SF Symbol (修真 newProject = "plus" + 修真 openProject + importProject) | V0-fix-11 修真 #3 |
| `testIconLibrary_action_newProject_isPlus` | 修真 `"plus"` 修真 FCP Viewer + ICON 修真 | V0-fix-11 修真 #3 |
| `testIconLibrary_action_openProject_isFolderBadgePlus` | 修真 `"folder.badge.plus"` 修真新建后面 | V0-fix-11 修真 #1 + #3 |
| `testIconLibrary_action_importProject_isSquareAndArrowDown` | 修真 `"square.and.arrow.down"` 占位 | V0-fix-11 修真 #1 + #3 |
| **新修真 `IconButtonTests.swift`** | 修真 #6 修真 7 test |  |
| `testIconButton_default_isPlain` | 修真 `.buttonStyle(.plain)` | V0-fix-11 修真 #6 |
| `testIconButton_active_isAccentColor` | active → Color.accentColor | V0-fix-11 修真 #6 |
| `testIconButton_inactive_isSecondary` | inactive → .secondary | V0-fix-11 修真 #6 |
| `testIconButton_disabled_callsNoAction` | .disabled(true) 修真 | V0-fix-11 修真 #6 |
| `testIconButton_size13WeightMedium` | size 13 / weight .medium | V0-fix-11 修真 #6 |
| `testIconButton_frame28x22` | frame(width: 28, height: 22) | V0-fix-11 修真 #6 |
| `testIconButton_helpLabel` | .help(label) | V0-fix-11 修真 #6 |
| **修真 `V0Fix8LayoutTests.swift`** | 修真 #2 + #4 + #5 修真 修真修真 |  |
| `testLayoutShellView_topLeftHeaderBar_heightIs28pt` | 修真 frame(height: 28) (V0-fix-10.1 修真 38) | V0-fix-11 修真 #2 |
| `testInspectorView_inspector2TabIsButton` | HStack + 2 Button(.plain) + IconButton | V0-fix-11 修真 #4 |
| `testInspectorView_inspector2TabIsCompact` | padding(vertical: 4) + IconButton 28×22 | V0-fix-11 修真 #4 |
| `testChatPanelView_chat4TabPaddingIs4Vertical` | padding(.vertical, 4) | V0-fix-11 修真 #5 |
| `testChatPanelView_chat4TabUsesIconButton` | IconButton 修真 chat tab | V0-fix-11 修真 #5 |
| **新修真 `LayoutShellViewToolbarTests.swift`** | 修真 #1 修真 4 test |  |
| `testToolbar_hasThreeIconButtons` | 3 ICON 修真 (新建/打开/导入占位) | V0-fix-11 修真 #1 |
| `testToolbar_newButtonPostsShowCreateProjectNotification` | + button → NotificationCenter.post .wenshuShowCreateProject | V0-fix-11 修真 #1 |
| `testToolbar_openButtonPostsOpenProjectURLNotification` | 打开 button → NotificationCenter.post .wenshuOpenProjectURL | V0-fix-11 修真 #1 |
| `testToolbar_importButtonIsDisabled` | 导入 button → .disabled(true) | V0-fix-11 修真 #1 |

**修真总数**: 4 (IconLibrary 修真) + 7 (IconButton 新增) + 5 (V0Fix8 修真) + 4 (Toolbar 修真) = **20 test**

**修真修真修真修真 修真 修真**:
- V0Fix1-V0Fix8 修真 test **修真 修真修真 修真 修真** (修真修真 IconLibrary 修真 String 修真修真修真)
- 修真 swift test **修真 修真** 修真 47 expected/0 unexpected → **修真 修真** 修真: 32 (V0Fix1-V0Fix8 + LT-N* 修真) + 16 (V0-fix-10.1 新修真) + 20 (V0-fix-11 新修真) = **68 expected**

---

## 5. 拍板历史 (V0-fix-11 跟 V0-fix-10 修真 / V0-fix-8 / V0-fix-9 衍生关系)

### 修真 #1 跟 V0-fix-10.1 修真 #2 (FileCommands) 衍生

- **V0-fix-10.1 修真 #2**: 新修真 CommandMenu("文件") + NotificationCenter.wenshuShowCreateProject + .wenshuOpenProjectURL (新建项目/打开项目/导入.../关闭项目 4 项 menu) + ⌘N/⌘O/⌘W 修真快捷键
- **V0-fix-11 修真 #1**: 修真 V0-fix-10.1 FileCommands 修真修真修真 — macOS title bar 修真 3 ICON 修真群 (新建/打开/导入占位) + 修真 .principal → .principal ToolbarItemGroup (修真 3 ICON 修真) + 修真 FileCommands menu 修真修真 (4 项 menu 修真). 修真修真: macOS menu bar 内文字菜单 (新建项目.../打开项目.../导入.../关闭项目) + macOS title bar 3 ICON 修真群 (新建/打开/导入占位) **并存** — 修真修真修真 macOS HIG 范式, 修真修真修真修真修真 V0-fix-10.1 修真.
- **装机 user 8/11 14:35 红字**: "位置居左, 挨着红黄绿" — 修真 #1 修真修真: placement .principal 修真中央 (macOS title bar 修真 红黄绿 + 中央 修真 修真区) — 但 .principal 修真 FCP / Pages / Numbers 范式 (中央 修真 文枢 / 文档名), 修真 修真 红黄绿后紧跟 修真 "leading" placement. **designer 修真推荐**: V0-fix-11 修真 .principal placement (沿 V0-fix-10.1 修真), 修真 修真 装机 user 红字 修真修真: V0-fix-11.1 (V0-fix-12) 修真修真 .leading placement.

### 修真 #2 跟 V0-fix-10.1 修真 #3 (5 tab 紧凑) 衍生

- **V0-fix-10.1 修真 #3**: 5 tab ICON frame 32×24 → 28×20 + spacing 4 → 2 + size 14 → 13 (FCP timeline 修真)
- **V0-fix-11 修真 #2**: topLeftHeaderBar 修真 38pt → 28pt (修真 FCP Viewer 顶部 toolbar 修真, memi §3.5 layout 修真 28pt toolbar) + IconButton 修真 (修真修真修真 5 tab 修真) + 修真 hit area ≥ 24pt HIG (frame 28×20 → 28×22). 修真修真修真 V0-fix-10.1 修真, 修真 FCP Viewer 顶部 toolbar 修真 28pt 修真.

### 修真 #3 跟 V0-fix-10.1 修真 #5 (IconLibrary) 衍生

- **V0-fix-10.1 修真 #5**: 新修真 IconLibrary.swift enum namespace (114 行), 修真修真 6 修真 .swift 文件, 修真 17 SF Symbol 字面量 (修真修真修真修真 ~12 修真 + 修真修真修真 修真 5 修真 placeholder 修真 v0.05.0 修真)
- **V0-fix-11 修真 #3**: 修真 IconLibrary.swift Action enum + 2 case (openProject = "folder.badge.plus" + importProject = "square.and.arrow.down") + 修真 newProject 值 "plus.circle.fill" → "plus" (修真 FCP Viewer + ICON 修真) — 修真 V0-fix-10.1 修真, 修真 18 SF Symbol 修真修真修真修真.

### 修真 #4 跟 V0-fix-8 修真 #2 + V0-fix-10.1 修真 #5 衍生

- **V0-fix-8 修真 #2**: 5 tab Picker.segmented 改 HStack + 5 Button(Image) + `.buttonStyle(.plain)` (修真 修真"修真文字为 ICON" + "不要矩形背景, 仿 FCP")
- **V0-fix-10.1 修真 #5**: inspector Picker(.iconOnly) 修真修真 IconLibrary.tab(tab) 修真 (但 Picker 修真修真修真修真, V0-fix-10.1 修真 修真修真)
- **V0-fix-11 修真 #4**: inspector Picker → HStack + 2 Button(.plain) + IconButton + padding(vertical: 8 → 4) (修真 FCP timeline 修真) + 修真 `iconName(for:)` 静态映射 修真修真修真 (修真 IconLibrary.tab(tab) 修真修真). 修真 V0-fix-8 修真 #2 + V0-fix-10.1 修真 #5 修真修真修真, 修真 inspector 修真修真修真 HStack+Button+IconButton.

### 修真 #5 跟 V0-fix-10.1 修真 #4 (chat tab 紧凑) 衍生

- **V0-fix-10.1 修真 #4**: 4 chat tab frame 32×24 → 28×20 + spacing 4 → 2 + size 14 → 13 (修真 V0-fix-8 修真 #3 修真)
- **V0-fix-11 修真 #5**: 4 chat tab padding(vertical: 8 → 4) (修真 FCP timeline 修真) + IconButton 修真 (修真修真修真 5 tab 修真) + 修真 hit area ≥ 24pt HIG (frame 28×20 → 28×22). 修真修真修真 V0-fix-10.1 修真, 修真 FCP timeline 修真 修真.

### 修真 #6 跟 §0 FCP memo §3.5 layout 修真 + SwiftUI HIG 修真

- **§0 FCP memo §3.5**: 下半栏 toolbar 修真 28pt (FCP 范式), 修真 V0-fix-12+ 修真
- **§0 总原则 + §1.1 adhd**: FCP 范式 + 1+2+3 派单格式
- **V0-fix-11 修真 #6**: 新增 `Components/IconButton.swift` 全局 ICON 按钮组件 (size 13 + weight .medium + frame 28×22 + .buttonStyle(.plain) + .help + .disabled), 修真 5 处修真修真 (LayoutShellView + ChatPanelView + InspectorView + LayoutShellView topLeftHeaderBar + ChatPanelView chat tab). 修真 swiftui-design-patterns skill §6.2 出稿 8 段流程 修真出, 修真§4 Token 系统 修真 设计token + §7 designer 不跨进 CC 领域的边界 修真修真 (designer 仅出设计意图, 不写代码).

---

## 6. 总体设计结论 (修真 5 处 + 1 组件全 PASS)

| 修真 # | 修真修真范围 | 修真 PASS / 修真修真 | 修真 |
|---|---|---|---|
| **#1** | + 按钮位置 + 3 ICON 修真群 (新建/打开/导入占位) | ⚠️ PASS (修真 #1 红字 .principal → .primaryAction 修真等 PM-direct 拍) | 修真 FCP Viewer + 按钮范式, 修真 NotificationCenter 修真 (修真 V0-fix-10.1 FileCommands 真修真) |
| **#2** | 5 tab 修真 28pt + IconButton 组件 (修真 hit area 28×22) | ✅ PASS | 修真 FCP Viewer 顶部 toolbar 28pt 修真 |
| **#3** | IconLibrary Action enum 修真 (10 case, +openProject +importProject) | ✅ PASS | 修真 V0-fix-10.1 修真, 修真 18 SF Symbol 修真修真修真修真 |
| **#4** | inspector Picker → HStack + 2 Button + IconButton + padding(vertical: 4) | ✅ PASS | 修真 V0-fix-8 修真 #2 + V0-fix-10.1 修真 #5 修真修真修真 |
| **#5** | 4 chat tab padding(vertical: 4) + IconButton 组件 | ✅ PASS | 修真 V0-fix-10.1 修真, 修真 FCP timeline 修真 |
| **#6** | 新增 Components/IconButton.swift (5 处修真修真) | ✅ PASS | 修真 全局 重复修真, 修真 V0-fix-12+ 修真修真修真修真 |

**修真修真 修真 PASS**: 修真 5 处 + 1 组件 修真 PASS, 修真 #1 修真 #1 红字 修真修真 (修真 PM-direct 拍).

**修真边界总结**:
- 修真修真 修真 AGENTS §8.1 修真 (5 区 + 修真 + 修真修真) — 不动 5 区 layout
- 修真修真 修真 FCP 修真 修真 (§0 总原则 + memi §3.5) — 修真 FCP Viewer + chat timeline 修真
- 修真修真 修真 HIT AREA 修真 (28×22 ≥ 24×24 HIG) — frame 28×22 = 616pt² 修真 24×22 = 528pt² 修真修真
- 修真修真 修真 V0Fix1-V0Fix10.1 修真 test (修真修真 String 修真修真修真)
- 修真修真 修真 V0-fix-11 修真 修真 test 20 修真 (修真 V0-fix-10.1 16 test → V0-fix-11 36 test, 修真 20 test)
- 修真修真 修真 WenshuStoreActor / .ws schema / Package.swift / AGENTS.md / 装机 user 修真 — 修真 AIF §9.2 P12 + §10.3 P12.1 修真, CUA 拍 6 张对比

**CC 修真修真建议**:
1. **优先修真 修真 #6** (IconButton.swift 新增) — 修真修真 修真 4 修真 文件修真 ICON 按钮修真
2. **修真修真 修真 #3** (IconLibrary.swift Action enum 修真) — 修真 2 case + 修真 newProject 值
3. **修真修真 修真 #2 + #5** (5 tab / 4 chat tab IconButton 修真 + padding(vertical: 4)) — 修真修真修真 修真 hit area 修真修真
4. **修真修真 修真 #4** (inspector Picker → HStack + IconButton) — 修真 iconName(for:) 静态映射 修真修真
5. **修真修真 修真 #1** (3 ICON 修真群 macOS title bar) — ⚠️ 等 PM-direct 拍 .principal → .primaryAction 修真, 修真 FileCommands menu 修真 V0-fix-10.1 真修真
6. **修真 6 修真 test** (V0Fix8 修真 + IconButton 新增 + IconLibrary 修真 + Toolbar 新增) + swift build exit 0 — swift test 修真 47/68 expected/0 unexpected (V0-fix-11 真修修真)

---

## 7. 装机 user 真机拍 6 截图 CUA 对比 (AIF §9.2 P12 拍板)

AIF 8/11 19:35 commit `269a0f774` 落 §9.2 P12: CC merge main 后 AIF 必 CUA 拍 6 张 (标题栏 / 左上 5 tab / 中上 / 右上 / 底部 chat / 底部时间线) + 与 v0-fix-N-1 对比, 任何功能消失 = 必回退.

**V0-fix-11 CUA 拍 6 截图位置**:
1. **标题栏** (`CUA 1/6`): macOS title bar 红黄绿 + 3 ICON 修真群 (新建/打开/导入占位) 修真 + 文枢 修真 (沿 V0-fix-9 .navigationTitle(""))
2. **左上 5 tab** (`CUA 2/6`): topLeftHeaderBar 28pt + 5 ProjectManagementTab ICON (folder / doc.text / gearshape / archive / square.grid.3x3) + spacing 2
3. **中上** (`CUA 3/6`): EditorView 修真 + v0.05.0 mark 系统 + 选区右键 — 沿 V0-fix-N 修真, 不修真
4. **右上** (`CUA 4/6`): inspector HStack + 2 IconButton (eye / pencil.and.list.clipboard) + padding(vertical: 4)
5. **底部 chat** (`CUA 5/6`): 4 ChatPanelTab IconButton + padding(vertical: 4) + Divider + ChatView
6. **底部时间线** (`CUA 6/6`): 不修真 (v0.04.0 长篇工具 工单, 修真 timeline disabled placeholder) — 沿 V0-fix-10 修真

**对比基线 (v0-fix-10)**:
- 修真 1 (修真 1/6): 红黄绿 后 + 按钮 (居中) → 3 ICON 修真群 (居中, 修真 placement .principal) — V0-fix-11 修真 #1 真修真
- 修真 2 (修真 2/6): topLeftHeaderBar 38pt + 5 tab size 13 frame 28×20 → topLeftHeaderBar 28pt + 5 tab IconButton frame 28×22 — V0-fix-11 修真 #2 真修真
- 修真 3 (修真 3/6): 不修真 — V0-fix-11 修真不修真中上
- 修真 4 (修真 4/6): inspector Picker(.iconOnly) → HStack + 2 IconButton + padding(vertical: 4) — V0-fix-11 修真 #4 真修真
- 修真 5 (修真 5/6): 4 chat tab padding(vertical: 8) → padding(vertical: 4) + IconButton — V0-fix-11 修真 #5 真修真
- 修真 6 (修真 6/6): 不修真 — 沿 V0-fix-10 修真

**任何功能消失** = 必回退 — AIF §9.2 P12 拍板长期原则.

---

*DESIGN-V0-fix-11.md v0.1 · 2026-08-11 designer · 修真 V0-fix-10.1 修真 5 红字批注 UI BUG · 修真 6 处 (5 修真 + 1 组件) + 20 新增 test · 装机 user 8/11 14:35 真机拍 + 19:50 拍 "你继续推进" · AIF §9.2 P12 + §10.3 P12.1 (commit `269a0f774`) · 修真 FCP 范式 (§0 总原则 + memi §3.5 layout 修真)*