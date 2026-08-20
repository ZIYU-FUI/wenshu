# 01 — 设置页 UI 重做 (Apple macOS 27 标准范式)

**What to build:**
老板 8/21 20:50 macOS 真验 + 拍板:
- ✅ 切外观响应式 work (commit d8146ca7d preferredColorScheme @AppStorage 真值响应式通过)
- ✅ 设置 sheet 浮在原 windows work (commit 3f4faf68f NSWindow 自创建通过)
- ❌ 设置 sheet 内部 UI 老旧 (Form + 2 个 Picker), 不是 Apple 官方 macOS 27 标准范式
- **新需求: 参考苹果官方软件的设置页 (如 Pages/Notes 系统设置范式), 用 macOS 27 的组件**

**Blocked by:** None.

**Status:** ready-for-agent

## 修法真值 (5 原则1 + 2 + 3 满足, Apple macOS 27 官方范式)

按 po main flow 6 步严格执行 (老板 8/21 拍 "按大神全链路严格执行"):

1. **保持 installMainMenu 装6 项中文** (commit 3f4faf68f) — 不动
2. **保持自创建 NSWindow 装 SettingView** (commit 3f4faf68f) — 不动
3. **保持 preferredColorScheme @AppStorage 响应式** (commit d8146ca7d) — 不动
4. **SettingView 重写 UI**:
   - 用 `TabView` + `Tab` API (SwiftUI 14+) — toolbar 自动显示 tab
   - 3 个 tab: 通用 / 模型 / 快捷键
   - 通用 tab: 外观 Picker (3 个: 系统/亮/暗, Apple radioGroup 真值)
   - 模型 tab: 模型 Picker (3 个: MiniMax-M3/M2/Reasoning, Apple menu 真值, 配完省略显示)
   - 快捷键 tab: 占位 (后续添加)
   - 用 `Form { }` 嵌入 TabView (Apple HIG)
   - macOS 27 组件: Picker, Toggle, Form, TabView (Apple 真值)

## Acceptance

- [ ] swift build exit 0
- [ ] swift test exit 0
- [ ] 老板 macOS 真验:
  - 点 "文枢" → "设置…" 弹 settings sheet 浮在原 windows
  - 顶部 toolbar tab 切换: 通用 / 模型 / 快捷键
  - 通用 tab: 外观 Picker (3 个: 系统/亮/暗), 选了立刻切窗口
  - 模型 tab: 模型 Picker (3 个: MiniMax-M3/M2/Reasoning), 配完省略显示
  - 快捷键 tab: 占位
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

## 关联

- 依赖: 无
- 被依赖: ticket 02 (LLM Keychain 集成) — 不依赖, 可并行