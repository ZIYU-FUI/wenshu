# Spec — 设置页 UI 重做 (Apple 官方 macOS 27 范式, 老板 2026-08-21 拍)

> Date: 2026-08-21
> 老板 2026-08-21 20:50 macOS 真验 + 拍板:
>1. 切外观响应式 work (commit d8146ca7d preferredColorScheme 改 @AppStorage 真值通过)
>2. 设置 sheet 浮在原 windows work (commit 3f4faf68f NSWindow 自创建通过)
>3. **新需求: 设置页 UI 重做, 参考苹果官方软件的设置页 (如 Pages/Notes 系统设置范式), 用 macOS 27 的组件**

## 业务语言 (老板懂)

老板 macOS 截图参考: Pages/Notes 系统设置 — 顶部 toolbar tab 切换 (通用/标尺/自动改正), 中间 Picker/Toggle/Slider 内容, 底部 Picker (如"文本大小")
- 设置 sheet 顶部 toolbar 有 3 个 tab: 通用 / 模型 / 快捷键 (老板拍)
- 每个 tab 显示一组 Picker/Toggle/Picker (用 Apple 标准组件)
- macOS 27 标准 SF Symbol + NSColor semantic + ToggleStyle
- 不显示当前选了哪个 (= "配完省略显示", 老板 8/21 ticket 04 拍)

## 真因链 (5 原则 1 + 3 真硬违反修复)

### commit 3f4faf68f + d8146ca7d 已修基础 (切外观响应式 + sheet 浮 windows)

- ✅ installMainMenu 装6 项中文
- ✅ 自创建 NSWindow 装 SettingView
- ✅ preferredColorScheme 改 @AppStorage 真值响应式
- ❌ SettingView 内部 UI 还用旧 Form + radioGroup Picker, 不是 Apple macOS 27 标准范式 (Pages/Notes 系统设置)

### commit 4ef3e2e77 抽 SettingView 但 UI 范式老旧

- 当前 SettingView Form + 2 个 Picker (外观 radioGroup + 模型 menu), 不是 Apple macOS 27 标准 UI
- 老板新需求: 改用 Apple 标准范式 TabView 分组 + toolbar tab 切换

## 修法 (按 po main flow 6 步严格执行)

### Step 1 grill (老板 20:50 已给)
- 真因真值: 当前 SettingView UI 老旧, 不是 Apple 官方范式

### Step 2 to-spec (本文件)

### Step 3 to-tickets
- 1 ticket 1 commit: 设置页 UI 重做, 用 Apple macOS 27 标准范式
  - SettingTabView: enum + TabView + toolbar
  - 通用 tab: 外观 Picker (3 个: 系统/亮/暗)
  - 模型 tab: 模型 Picker (3 个: MiniMax-M3/M2/Reasoning) + 配完省略显示 (当前真值已用 Picker 显示, 但视觉不真值省略)
  - 快捷键 tab: 老板 macOS 真实值, 暂留占位

### Step 4 implement (1 ticket 1 commit)
- 老板 macOS 真验后 commit
- 用 Apple macOS 27 标准组件: `Form { }` 嵌入 `TabView` + toolbar
- 不用装饰/花哨 UI, 跟 Pages/Notes 系统设置范式对齐

### Step 5 code-review (双轴)
- 派 Standards + Spec sub-agent 并行 (老板 8/21 纠错 Q34 我没走双轴)
- Q34.5 双轴循环 gate: re-run 直到 hard violation 0

### Step 6 domain-modeling
- 加 CONTEXT.md: SettingsTabView / TabView / Toolbar 真值 (新 domain word)

## 验收标准

- [ ] swift build exit 0
- [ ] swift test exit 0
- [ ] 老板 macOS 真验:
  - 点 "文枢" → "设置…" 弹 settings sheet 浮在原 windows
  - 顶部 toolbar tab 切换: 通用 / 模型 / 快捷键
  - 通用 tab: 外观 Picker (3 个: 系统/亮/暗), 选了立刻切窗口
  - 模型 tab: 模型 Picker (3 个: MiniMax-M3/M2/Reasoning), 配完省略显示
  - 快捷键 tab: 暂占位
  - 不显示当前选了哪个

## 不动 (Q20 硬约束)

- v0.20 ticket 04 + 05 (LOGO + 菜单栏"文枢" 老板拍先放着)
- v0.21 chat streak ticket 02-06 (5 ticket 已 commit + 双轴 code-review 修法聚合, 不动)
- installMainMenu 装6 项中文 (commit 3f4faf68f 已过)
- 自创建 NSWindow 装 SettingView (commit 3f4faf68f 已过)
- preferredColorScheme @AppStorage 真值响应式 (commit d8146ca7d 已过)

## Apple HIG 真值引用

- https://developer.apple.com/design/human-interface-guidelines/macos
- https://developer.apple.com/documentation/swiftui/tabview
- https://developer.apple.com/documentation/swiftui/form
- https://developer.apple.com/documentation/swiftui/toggle
- Pages/Notes 系统设置 (老板截图真值参考)

## 关联 commit

- v0.21 ticket 01 (重做 #1-#11) — 11 redo commit, ticket 01 (重做 #10 #11) 通过
- v0.21 ticket 04 (commit 984ea556b) — Settings 模型配置 Picker
- v0.21 code-review 修法聚合 1 (commit 0589141) — Standards H1+H2+H3
- v0.21 code-review 修法聚合 2 (commit fff05cd9d) — Spec S1+S2+S3+S4