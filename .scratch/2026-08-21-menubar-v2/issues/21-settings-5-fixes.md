# 21 — 设置弹窗 5 项修真因真硬 (item 1+2+3 修真因 + item 4 状态统一 + item 5 展开动画)

依赖: ticket 17 commit `227859117` + CONTEXT.md `9b0f0250b`

**What to build:**
5 项修真因真硬 (老板 2026-08-22 06:29 拍):
1. SecureField + 保存按钮同行 (修真因 1)
2. Info.plist CFBundleName 改 "设置" (修真因 2)
3. tab segmented picker 仿 Pages + ICON (修真因 3, 已修真因部分真硬, 修真因真硬生效)
4. providerApiRow 状态统一中文 ("待配置" / 灰度前 8 位 已配置) (修真因 4)
5. 展开动画 Apple 默认 (.animation(.default, value:)) (修真因 5, 新增)

**Why:**
ticket 17 commit `227859117` 老板 macOS 验发现 5 项修真因真硬真值. Q32 真因链 = 修真因 5 项修真因 + 1 项新增.

**Acceptance:**
- 老板 macOS 真验: 设置弹窗标题 "设置 Settings" / 提供方 API tab 仿 Pages + ICON / 整条点 → 展开动画 / SecureField + 保存按钮同行 / 未设 "待配置" / 已配置 灰度前 8 位
- swift build exit 0
- swift test exit 0 (ProviderKeychain 5/5 pass 不回归)
- 双轴 code-review 报告 verbatim 进 commit body
- Q40 + Q45: 真 key 走 Apple Keychain 不入文件/log/commit, 灰度字仅 UI 显示前 8 位