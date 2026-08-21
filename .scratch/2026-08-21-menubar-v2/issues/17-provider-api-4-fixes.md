# 17 — 提供方 tab 删 + 整条热区响应 + 已设 key 显前 8 位 + 设置弹窗改 "设置"

依赖: ticket 16 commit `1c531223f`

**What to build:**
修真因 4 项老板 2026-08-22 06:12 拍的真硬违反:
1. SettingsTab 撤 .provider case + body switch 撤 .provider 路由 (老板拍 "提供方 tab 可以删掉了，保留提供方 API tab")
2. providerApiTab 用 List + onTapGesture 替代 DisclosureGroup (老板拍 "删掉每条前面的 >，整条热区响应展开关闭")
3. providerApiEditor 已设 key 展开时 apiDraftKey 预填 "前 8 位 + ********" (老板拍 "已经配置过的，再次展开，文本框里不要为空，显示前 8 位真值 + **** 补位")
4. Settings Scene 弹窗 title 改 "设置" (老板拍 "设置弹窗就叫设置，不用多次一举叫文枢设置") — 修真因真因待 Q28 查文档真值

**Why:**
当前实现 4 项真硬违反: providerTab 重复 / DisclosureGroup 自带 chevron / SecureField 永远空 / Settings Scene title "WenshuApp Settings"

**Acceptance:**
- 老板 macOS 真验: 提供方 tab 没了 → 整条点 → 展开 inline 编辑 → 已设 key 显示前 8 位 + 补位 → 设置弹窗 title = "设置"
- swift build exit 0
- swift test exit 0 (ProviderKeychain 5/5 pass 不回归)
- 双轴 code-review 报告 verbatim 进 commit body
- Q40: SecureField 显示 = 前 8 位 + 补位 ≠ 真 key, 真 key 仍走 Apple Keychain 不入文件/log/commit