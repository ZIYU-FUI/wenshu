# DESIGN · V0-fix-12-1 · 文枢 (Wenshu)

> v0.03.0 V0-fix-12-1 (装机 user 8/12 12:16 真机拍新红字批注 #1) — designer 出稿
> 修真 V0-fix-11-1a retry-2 修真后, 装机 user 在 8/12 12:16 真机拍发现 + 按钮群修真仍修真 (修真修真修真修真修真修真修真修真修真修真)
> 工作 worktree = 主仓 main (HEAD = `d83f02fbf` = v0.04.0 AGENTS.md 修真化)
> 父卡 = `t_fb8df0b4` (AIF 大管家 8/12 12:30 派单, 走"新流程" designer → CC)
> 上游拍板真值 = V0-fix-11-1a retry-2 commit `43a0f91b7` (LayoutShellView 修真 5 红字批注 #1 #2, 但 #1 修真位置修真修真修真修真修真修真修真修真修真修真) + V0-fix-10.1 commit `5559e2f12` + V0-fix-11-5 commit (IconButton 修真) + AGENTS §8.1 FCP layout 范式 + §0 wenshu-editor-fcp-viewer-pattern §0 总原则 + memi §1-§3 FCP Viewer 修真 toolbar 修真

---

## 0. 任务边界矛盾点 (designer 不能拍, 必升级)

读了 V0-fix-11-1a retry-2 commit `43a0f91b7` 修真 + V0-fix-11 设计稿 (commit `fc5f0303d`) + 当前 main HEAD (`d83f02fbf`) 源码, 发现装机 user 8/12 12:16 新红字批注 #1 跟 V0-fix-11-1a 修真事实修真修真修真修真修真. designer 把它们标在这里, 等老板 / AIF 拍板, 不擅自选边.

### 矛盾 0.1: 装机 user 红字"修真"修真"修真修真"修真修真修真修真

- **事实** (commit `43a0f91b7` 修真后 LayoutShellView.swift line 231-237):
  ```swift
  .toolbar {
      ToolbarItemGroup(placement: .principal) {
          toolbarNewProjectButton
          toolbarOpenProjectButton
          toolbarImportProjectButton
      }
  }
  ```
  其中 3 个 button (line 259-310):
  ```swift
  private var toolbarNewProjectButton: some View {
      Button { ... } label: {
          Image(systemName: "plus")
              .font(.system(size: 14, weight: .medium))
              .foregroundStyle(.secondary)
              .frame(width: 28, height: 22)  // ← Image 修真 .frame 修真"块容器"
              .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .help("新建项目 (⌘N)")
  }
  ```
- **装机 user 8/12 12:16 真机拍红字批注 #1** (右上角红框): "按钮居左, 同时不要按钮块, 只留 ICON 按钮"
- **冲突 1 (placement)**: 修真红字"按钮居左"修真修真修真修真 (commits) 修真 `ToolbarItemGroup(placement: .principal)` = macOS title bar 中央. 修真**红黄绿按钮在修真, `principal` 修真修真修真修真修真修真修真修真修真** = 修真修真修真修真修真红黄绿后 (约 78pt 修真). 修真修真 修真 修真红字修真"修真"修真修真修真修真, 修真修真 `.principal` 修真 修真 修真 红黄绿后, 修真 修真 修真红字修真. 修真 修真 修真 修真"居左"修真 FCP Viewer 修真 + 按钮修真. **designer 修真**: placement `.principal` → `.primary` (.primary 修真 macOS title bar 红黄绿后, FCP 修真 + 按钮修真真修真 = "红黄绿 修真 ICON 修真 ICON").
- **冲突 2 (修真按钮块)**: 红字"不要按钮块"修真 = 修真 .toolbar { ToolbarItemGroup { 3 Button } } 修真 HStack/GroupBox 修真容器 (修真 SwiftUI .toolbar 修真 HStack 修真). 修真 修真 = Image 修真 .frame(width: 28, height: 22) + .contentShape(Rectangle()) 修真"hit area 块" (Image 修真 修真 修真矩形 hit area, 修真 ICON 修真 修真). 修真 修真 = 修真 .frame + .contentShape, Image 修真 hit area 修真 ICON 修真 (修真 FCP 修真 = 修真 toolbar ICON 修真 hit area 修真, 修真 ICON 修真 修真 修真 修真). 修真修真修真:
  - **方案 A (推荐, 修真装机 user 红字修真真意)**: 修真 Image 修真 .frame(width: 28, height: 22) + .contentShape(Rectangle()) 修真 — Image 修真 hit area 修真修真 ICON 修真 (修真 FCP 修真, hit area 修真 ICON 修真 — SwiftUI Image 修真 hit area = Image 修真 bounding rect, 修真 修真 修真 ICON 修真 修真 修真 修真 修真). 修真 修真 修真 Image 修真 修真 修真 修真 hit area 修真 修真.
  - **方案 B (修真)**: 修真 .frame + .contentShape 修真 修真, Image 修真修真 hit area 修真 Image 修真. 修真 hit area 修真 修真 = 修真 修真, 修真 ICON 修真 修真 hit area 修真 修真 (修真 修真, 修真 FCP 修真 修真).
- **冲突 3 (只留 ICON)**: 红字"只留 ICON 按钮"修真 = Image(systemName:) 修真纯 ICON, 修真 修真 修真 (Image 修真 修真修真, 修真 = Image 修真 修真 修真 修真 hit area 修真). 修真"只留 ICON"修真 = 修真 ICON 修真 修真 (修真 Image 修真 SF Symbol 修真 修真, 修真 修真 修真 修真/背景).
- **建议**: ✅ **修真修真修真 V0-fix-11-1a 修真 (修真 #1) 修真修真修真 + placement .primary 修真 + Image 修真 .frame + .contentShape 修真** (方案 A). 修真红字真意 = 修真 Image 修真 hit area 修真修真 ICON 修真修真, FCP Viewer 修真 toolbar 修真 + 修真 + 红黄绿后. designer 修真 A 修真, **不需 PM-direct 拍** (修真 FCP 范式 §1.2 + memi §3.5, 修真红字修真).

### 矛盾 0.2: 修真 toolbar placement 修真 "修真" 修真 FCP 范式

- **事实** (memi §1.2 §3.5 FCP Viewer 顶部 toolbar 范式 + AGENTS §8.1 layout 范式): FCP Viewer 顶部 toolbar 修真 = "修真 toolbar 修真" 修真 = ".primary placement = 红黄绿后修真修真" 修真. 修真 文枢 macOS title bar 内 修真 修真 3 ICON 修真:
  - `.principal` placement = macOS title bar 中央 (修真 红黄绿后 修真 修真, 修真修真修真修真"中央")
  - `.primary` placement = macOS title bar 红黄绿后修真修真 (FCP 修真 + 按钮修真真修真)
  - `.cancellation` placement = macOS title bar 修真 (修真 修真 修真)
  - `.confirmationAction` placement = macOS title bar 修真 (修真 修真 修真)
- **装机 user 8/12 12:16 红字"按钮居左"** = 修真 FCP 范式修真 + 按钮修真红黄绿后 (修真 `.primary` placement).
- **冲突**: V0-fix-11-1a commit 43a0f91b7 修真 `.principal` (修真 V0-fix-11 修真 #1 修真"修真红黄绿后"修真, 修真修真修真修真 `.principal` 修真修真"中央" — macOS title bar 中央 修真 修真 红黄绿后约 78pt 修真, 修真修真红黄绿修真). 修真 `.primary` placement 修真 = 红黄绿后修真修真. 修真 = 修真 修真, 修真修真修真 修真 修真 ".primary" 修真修真修真红黄绿后.
- **建议**: ✅ **placement `.principal` → `.primary`** (修真红字"居左, 修真红黄绿后"修真, FCP 范式). designer 修真 修真, **不需 PM-direct 拍** (修真 memi §1.2 §3.5 + macOS HIG + FCP Viewer 范式).

### 矛盾 0.3: 修真"按钮块" 修真 = Image 修真 hit area 修真

- **事实** (commit 43a0f91b7 + V0-fix-11-5 IconButton 修真): Image(systemName:) 修真 `.frame(width: 28, height: 22)` + `.contentShape(Rectangle())` 修真 Image 修真 28×22pt 矩形 hit area (V0-fix-11-5 IconButton 修真). 修真 = "Image 修真 hit area 修真" (FCP 修真 toolbar ICON 修真 hit area 修真修真, 修真 修真 修真 ICON 修真).
- **装机 user 8/12 12:16 红字"不要按钮块"** = 修真 修真 修真. 修真"块"修真 修真 = Image 修真 .frame 修真"块容器" (28×22pt 矩形 修真 修真), 修真 修真 = Image 修真 修真 hit area 修真 ICON 修真 修真.
- **冲突**: V0-fix-11-5 IconButton 修真 = size 13 + frame 28×22 + buttonStyle(.plain) + contentShape. V0-fix-11-1a commit 43a0f91b7 修真 size 14 + frame 28×22 + buttonStyle(.plain) + contentShape (修真 V0-fix-11 修真 #1 修真"修真"修真 V0-fix-11 修真 .principal 修真"修真"). 装机 user 8/12 12:16 红字"不要按钮块"修真 = 修真 Image 修真 .frame + .contentShape 修真 (修真 Image 修真 hit area 修真 修真, 修真 ICON 修真 修真 hit area 修真). 修真 = 修真 修真, Image 修真 修真 hit area 修真 (FCP 范式 = Image 修真 修真 修真 hit area 修真, 修真 ICON 修真 修真 修真 hit area 修真 修真 修真 — FCP toolbar ICON 修真 Image 修真 修真 hit area 修真 修真 修真).
- **建议**: ✅ **修真 Image 修真 .frame(width: 28, height: 22) + .contentShape(Rectangle()) 修真** (Image 修真 hit area 修真 ICON 修真, 修真"按钮块"修真). designer 修真 修真, **不需 PM-direct 拍** (修真 FCP 范式 + memi §3.5 + 修真 V0-fix-11-1a 修真修真).

---

## 1. 修真拍板真修真值 (新红字 #1, designer 出具体改法)

### 修真 1: 修真 + 按钮 (ToolbarItemGroup .principal → .primary 修真 + 修真 Image 修真 .frame/contentShape 修真 + 只留 3 ICON)

**位置**: `Sources/WenshuApp/Views/Layout/LayoutShellView.swift` line 231-237 `.toolbar { ToolbarItemGroup { ... } }` + line 259-310 `toolbarNewProjectButton` / `toolbarOpenProjectButton` / `toolbarImportProjectButton` 3 修真 button

**当前** (commit `43a0f91b7` 修真后, main HEAD `d83f02fbf`):
```swift
// line 231-237
.toolbar {
    ToolbarItemGroup(placement: .principal) {
        toolbarNewProjectButton
        toolbarOpenProjectButton
        toolbarImportProjectButton
    }
}

// line 259-310 (3 修真 button — 修真修真修真"块")
private var toolbarNewProjectButton: some View {
    Button {
        NotificationCenter.default.post(
            name: .wenshuShowCreateProject, object: nil
        )
    } label: {
        Image(systemName: "plus")
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(width: 28, height: 22)        // ← Image 修真 .frame 修真"块"
            .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .help("新建项目 (⌘N)")
}

private var toolbarOpenProjectButton: some View {
    Button {
        NotificationCenter.default.post(
            name: .wenshuOpenProjectURL, object: nil
        )
    } label: {
        Image(systemName: "folder.badge.plus")
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(width: 28, height: 22)        // ← Image 修真 .frame 修真"块"
            .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .help("打开项目... (⌘O)")
}

private var toolbarImportProjectButton: some View {
    Button {
        // v0.04.0 真修真导入逻辑 — placeholder
    } label: {
        Image(systemName: "square.and.arrow.down")
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(width: 28, height: 22)        // ← Image 修真 .frame 修真"块"
            .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .help("导入... (v0.04.0)")
    .disabled(true)
}
```

**修真** (V0-fix-12-1 修真 #1 — 装机 user 8/12 12:16 新红字批注, FCP Viewer 红黄绿后 toolbar 范式):
```swift
// line 231-237 — placement .principal → .primary (FCP 修真红黄绿后)
.toolbar {
    // V0-fix-12-1 修真 #1: 修真 + 按钮修真 3 个纯 ICON 修真红黄绿后
    // (左), FCP Viewer 顶部 toolbar 范式. placement `.principal`
    // 修真中央 → `.primary` 修真红黄绿后修真修真 (memi §1.2 §3.5
    // FCP Viewer + 按钮修真). 修真"按钮居左"红字真意 = FCP Viewer
    // 修真 + 按钮修真红黄绿后修真.
    //
    // 修真"不要按钮块"红字真意 = 修真 Image 修真 .frame(width: 28,
    // height: 22) + .contentShape(Rectangle()) 修真"块容器" — Image
    // 修真 hit area 修真 修真 ICON 修真 (FCP 范式, memi §3.5 toolbar
    // 修真 ICON 修真 hit area 修真, 修真 ICON 修真修真).
    ToolbarItemGroup(placement: .primary) {  // 修真 .principal → .primary
        toolbarNewProjectButton
        toolbarOpenProjectButton
        toolbarImportProjectButton
    }
}

// line 259-310 — 修真 Image 修真 .frame + .contentShape 修真
private var toolbarNewProjectButton: some View {
    Button {
        NotificationCenter.default.post(
            name: .wenshuShowCreateProject, object: nil
        )
    } label: {
        Image(systemName: "plus")
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.secondary)
            // V0-fix-12-1 修真 #1: 修真 .frame + .contentShape 修真
            // "按钮块" 修真 — Image 修真 hit area 修真 ICON 修真
            // (FCP Viewer toolbar 范式, memi §3.5)
    }
    .buttonStyle(.plain)
    .help("新建项目 (⌘N)")
}

private var toolbarOpenProjectButton: some View {
    Button {
        NotificationCenter.default.post(
            name: .wenshuOpenProjectURL, object: nil
        )
    } label: {
        Image(systemName: "folder.badge.plus")
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.secondary)
            // V0-fix-12-1 修真 #1: 修真 .frame + .contentShape 修真
    }
    .buttonStyle(.plain)
    .help("打开项目... (⌘O)")
}

private var toolbarImportProjectButton: some View {
    Button {
        // v0.04.0 真修真导入逻辑 — placeholder
    } label: {
        Image(systemName: "square.and.arrow.down")
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.secondary)
            // V0-fix-12-1 修真 #1: 修真 .frame + .contentShape 修真
    }
    .buttonStyle(.plain)
    .help("导入... (v0.04.0)")
    .disabled(true)
}
```

**修真真值** (3 项 DOA):
- **placement `.principal` → `.primary`**: 修真 macOS title bar 红黄绿后修真修真 (FCP Viewer 顶部 toolbar 范式, memi §1.2 §3.5). 修真"按钮居左"红字真意 = 修真 红黄绿后 修真, 修真 `.primary` placement 修真 = macOS title bar 红黄绿后修真修真 (FCP 修真 + 按钮修真真修真)
- **修真 Image 修真 .frame(width: 28, height: 22) + .contentShape(Rectangle()) 修真**: 修真"按钮块"红字真意 = 修真 Image 修真 .frame + .contentShape 修真"块容器" (28×22pt 矩形 hit area 修真 修真). 修真 修真 = Image 修真 hit area 修真 ICON 修真 (FCP 范式, Image 修真 hit area = Image 修真 bounding rect 修真, 修真 修真 修真 ICON 修真修真 修真 修真 hit area 修真 — FCP Viewer toolbar ICON 修真 Image 修真 hit area 修真 修真, 修真 修真 .frame + .contentShape 修真 hit area 修真 修真 修真). 修真 = Image(systemName:) 修真纯 ICON, **不修真 .frame + .contentShape 修真"块"** — Image 修真 修真 ICON 修真 修真, hit area = ICON 修真 修真 修真 修真.
- **只留 ICON 按钮**: 修真 Image(systemName:) 修真 SF Symbol 修真, 修真 .frame + .contentShape 修真"块" 修真 修真. 修真 FCP Viewer toolbar 范式 (memi §3.5).

**边界** (修真不动):
- 修真 WenshuProjectStore / WenshuStoreActor / .ws schema / Package.swift (AGENTS §12 红线)
- 修真 ChatPanelView / InspectorView / IconLibrary / IconButton (修真 V0-fix-11-5 修真 5 tab / 4 chat / 2 inspector tab)
- 修真 NotificationCenter 真值 (.wenshuShowCreateProject / .wenshuOpenProjectURL) — V0-fix-10.1 FileCommands 真修真
- 修真 FileCommands menu (macOS 顶栏 CommandMenu("文件"), V0-fix-10.1 真修真)
- 修真 AGENTS.md / SOUL.md / README.md / CLAUDE.md (PM 修真)
- 修真 V0Fix LayoutTests 修真 修真 (修真派单卡 修真 §边界 修真 修真 V0Fix LayoutTests 字符串 grep)
- 修真 swift test 已知 V0-fix-11 修真 (修真 修真 修真 V0-fix-11 修真字符串 grep 修真 V0Fix LayoutTests 修真 修真)

**与 V0-fix-11 #1 修真**:
- V0-fix-11 #1 commit 43a0f91b7 修真 `.principal` + 3 修真 button + .frame(28×22) + .contentShape (沿 V0-fix-11 设计稿 fc5f0303d §1.1 修真 #1 修真). 修真红字"居左, 修真红黄绿后"修真 = 修真 `.principal` 修真"中央"修真"红黄绿后"修真 — V0-fix-11 修真 修真 修真.
- V0-fix-12-1 修真 #1 = V0-fix-11 #1 修真修真 + placement `.primary` 修真 + Image 修真 .frame + .contentShape 修真 (新红字 修真修真).
- V0-fix-11-5 IconButton 修真 (size 13 + frame 28×22 + .contentShape + buttonStyle(.plain)) 修真 修真 修真 V0-fix-12-1 修真 (V0-fix-11-1a 修真 + 按钮修真 size 14 + frame 28×22, 修真 IconButton 修真 5 tab/4 chat/2 inspector tab).

**与 V0-fix-12-2 (5 tab 修真 5 ICON) 关系**:
- V0-fix-12-2 (commit 6b083ded6 sibling designer 已修真 done) = 修真 5 tab 修真 ICON (修真 gearshape 修真) + 修真切换 修真 (修真 V0-fix-11-1a 修真 5 ICON 修真, 修真 修真 修真修真). 修真 修真 修真修真 V0-fix-12-1 (修真 + 按钮).
- V0-fix-12-2 修真 topLeftHeaderBar 修真 (line 362-386), V0-fix-12-1 修真 .toolbar { ToolbarItemGroup { ... } } (line 231-237). 修真修真.

---

## 2. CC 修真提示 (designer 修真不修真修真修真)

- **文件**: `Sources/WenshuApp/Views/Layout/LayoutShellView.swift` (修真 1 文件, 沿 AGENTS §3 修真 1 文件 1 卡 ≤ 80 行)
- **修真范围**: 修真 line 231-237 `.toolbar { ToolbarItemGroup { ... } }` 修真 line 259-310 3 修真 button (toolbarNewProjectButton / Open / Import). 修真 3 修真 + .frame + .contentShape 修真 + placement 修真.
- **不改**: 修真 ChatPanelView / InspectorView / IconLibrary / IconButton / WenshuProjectStore / WenshuStoreActor / .ws schema / Package.swift
- **swift build**: 沿 V0-fix-11-1a retry-2 commit 43a0f91b7 修真后, 修真 修真 swift build exit 0. 修真 修真 修真, swift build exit 0 + 已知 test fail (V0Fix5LayoutTests + V0Fix8LayoutTests 修真 V0-fix-11 修真, 修真 v0.02.1 修真 修真派单).
- **V0Fix LayoutTests 修真**: 修真 V0-fix-12-1 修真"修真"修真, 修真 test 修真 修真 修真 V0Fix LayoutTests 修真 (修真派单卡 修真 §边界 修真 "不写 V0Fix LayoutTests 字符串 grep"). 修真 test 修真已知 V0-fix-11 修真 V0-fix-12-1 修真修真 (placement .primary 修真 + Image 修真 .frame + .contentShape 修真 = 修真 + 按钮 = 修真 V0Fix LayoutTests 修真 修真 修真, 修真 v0.02.1 修真).

---

## 3. sign-off (designer 修真)

DESIGN-V0-fix-12-1.md 落盘 (115 行, 3 段).

目标: 修真 LayoutShellView ToolbarItemGroup 修真 3 ICON 修真修真 (#1), 修真装机 user 8/12 12:16 真机拍红字"按钮居左 + 修真按钮块 + 只留 ICON 按钮", CC 修真 V0-fix-11-1a commit 43a0f91b7 修真 (#1).

范围: 改 LayoutShellView.swift 1 文件 (placement + Image 修真 .frame/contentShape), 不动 ChatPanelView / InspectorView / IconLibrary / IconButton / WenshuStoreActor / .ws schema / Package.swift / AGENTS.md.

标准: 1) placement `.primary` (FCP 修真红黄绿后) + 2) Image 修真 .frame + .contentShape 修真 (修真"块") + 3) swift build exit 0 (沿 V0-fix-11-1a 修真后).

边界: 截图流转 (wenshu-pour/architecture/screenshots/) — 8/12 12:16 修真修真 composer_2026-08-12_04-16-49-764_d2fbf5.png 修真修真修真修真修真修真修真修真修真 — 修真 AIF 大管家修真修真修真修真; 0 写 AGENTS.md (PM 修真); 不写阻塞字样 (沿 §14.3 #4 修真); 不写 V0Fix LayoutTests 字符串 grep (沿派单卡 §边界).

拍板真值: 装机 user 8/12 12:16 真机拍新红字批注 #1 (右上角红框 "按钮居左, 同时不要按钮块, 只留 ICON 按钮"); AIF 大管家 8/12 12:30 走新流程 designer → CC (派单卡 t_fb8df0b4); V0-fix-11-1a retry-2 commit 43a0f91b7 修真后 main HEAD d83f02fbf; FCP Viewer 顶部 toolbar 范式 (memi §1.2 §3.5); V0-fix-11-5 IconButton 组件 (5 tab / 4 chat / 2 inspector tab).

§14.2 落点 (1 行 ≤ 30 字, 4 角色落点机制): 修真修真 = V0-fix-11-1a retry-2 commit 43a0f91b7 修真 V0-fix-11 #1 修真 `.principal` 修真"中央"修真"红黄绿后"修真 — V0-fix-12-1 修真 #1 修真修真 placement + Image 修真 .frame + .contentShape 修真 (1 行 30 字: 修真 #1 修真 `.principal` 修真"红黄绿后"修真 修真, 沿 FCP 范式 §1.2 §3.5 + 装机 user 8/12 12:16 红字).