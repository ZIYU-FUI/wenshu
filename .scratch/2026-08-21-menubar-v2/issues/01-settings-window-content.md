# 01 — 菜单栏 + 设置弹窗工作 (老板 2026-08-21 拍 "按大神全链路严格执行")

**What to build:**
老板 8/21 20:30 macOS 真验: 菜单弹窗有了 (浮在原 windows), 但弹窗里面功能失效, 没有切系统外观 (= SettingView 没装进 SwiftUI 默认接管的标准 settings window).

**Blocked by:** None.

**Status:** ready-for-agent

## 修法真值 (3 步, 5 原则1 + 3 + 4 + 5 满足)

按 po main flow 6 步严格执行 (老板 8/19 evening 拍 streak + 8/21 拍 "昨天走大神全链路效率很高"):

1. **grill**: 老板 macOS 8/21 20:30 反馈真值 = 设置 sheet 空白 (SettingView 渲染失败)
2. **to-spec**: `.scratch/2026-08-21-menubar-v2/spec.md` 落地
3. **to-tickets**: 本文件
4. **implement (1 ticket 1 commit)**: 修真因
   - 跑 build 真值 SettingView 装进 Settings { } Scene 验证
   - 老板 macOS 真验 SettingView 渲染 (外观 + 模型 Picker 显示)
5. **code-review (双轴)**: 派 Standards + Spec sub-agent 并行 (老板 8/21 纠错 Q34 我没走双轴)
6. **domain-modeling**: 加 CONTEXT.md SettingsView / NSMenuInstallationPattern / SettingsScene domain words

## implement 修法真值 (按 commit 9cb2ad0f0 撤回 NSMenu 装后真因重判)

- 当前 working tree: commit 9cb2ad0f0 (撤回 NSMenu 装) + commit 4ef3e2e77 (抽 SettingView 共享) + commit 984ea556b (Settings 模型 Picker ticket 04)
- WenshuApp body `Settings { SettingView() }` Scene 仍在 App body
- 老板截图: 设置 sheet 浮在原 windows 但 SettingView 内容空白
- **真因诊断 (3 候选,需要老板验证才能定)**:
   - (a) SettingView @AppStorage 读 UserDefaults 时, 在 SwiftUI 默认 settings sheet 内**不响应** (UserDefaults scope 问题)
   - (b) `Settings { SettingView() }` Scene 跟 SwiftUI 默认 settings sheet 冲突, SwiftUI 用自己的 settings 不装我们 SettingView
   - (c) SettingView 引用 MiniMaxModel / AppearanceMode enum 在 SwiftUI 默认 settings scope 找不到 (linker issue)

## Acceptance

- [ ] swift build exit 0
- [ ] swift test exit 0
- [ ] 老板 macOS 真验:
  - 菜单栏 7 项 (Apple / 文枢 / 文件 / 编辑 / 显示 / 窗口 / 帮助)
  - 点 "文枢" → "设置…" 弹 settings sheet 浮在原 windows
  - 设置 sheet 里有外观 Picker (3 个: 系统/亮/暗), 选了立刻切
  - 设置 sheet 里有模型 Picker (3 个: MiniMax-M3/M2/Reasoning), 选了存
  - 不显示当前选了哪个

## 不动 (Q20 硬约束)

- v0.20 ticket 04 + 05 (LOGO + 菜单栏"文枢" 老板拍先放着)
- v0.21 chat streak ticket 02-06 (5 ticket 已 commit + 双轴 code-review 修法聚合, 不动)
- App.swift `Settings { }` Scene 已有的 Form + Picker (commit 4ef3e2e77 SettingView)
- AppIcon.icon/ (老板拍先放着)

## Apple HIG 真值引用

- https://developer.apple.com/documentation/swiftui/settings
- https://developer.apple.com/documentation/swiftui/settingslink
- https://developer.apple.com/documentation/foundation/adding-a-settings-interface-to-your-app
- VibeMeter/NSApplication+openSettings.swift (open-source 真值)

## 关联

- 依赖: 无
- 被依赖: ticket 02 (LLM Keychain 集成) + ticket 03 (真 verify) — 不依赖, 可并行