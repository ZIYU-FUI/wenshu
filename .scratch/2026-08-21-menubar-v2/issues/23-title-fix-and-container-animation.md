# 23 — 标题去"文枢"修真因 + 动画 container-level 修真因

依赖: ticket 21 commit `173b719bb` + ticket 22 commit `8b1b48a64`

**What to build:**
2 项修真因真硬真值 (老板 2026-08-22 06:50 拍):
1. Info.plist CFBundleDisplayName 修真因为 "设置" (修真因 ticket 21 item 2 没生效, 因为 CFBundleDisplayName 走 fallback 优先级最高)
2. App.swift providerApiEditor 修真因: 撤 element-level .transition (L441/447/453 各自) → HStack 整块 container-level .transition (老板原话 "不是这两个元素加动画, 是这两个元素所在的那一条需要加动画")
3. App.swift SettingView body Group 修真因: 撤 switch case .transition (L274-276, switch case 不是 if condition, transition 不生效)

**Why:**
ticket 21 + 22 修真因落地后老板 macOS 验发现 2 项修真因真硬违反. 老板补 "container-level transition" = Apple SwiftUI 真值真硬修正.

**Acceptance:**
- 老板 macOS 真验: 标题 "设置 Settings" (去"文枢") / 展开文本框容器层 Apple 默认动画 / tab 切换 Apple 默认动画
- swift build exit 0
- swift test exit 0 (ProviderKeychain 5/5 pass)
- 双轴 code-review verbatim 进 commit body
- Q40 + Q45: 真 key 走 Apple Keychain, UI 显示仅前 12 位, 不入文件/log/commit