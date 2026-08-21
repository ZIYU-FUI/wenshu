# 22 — 优化: key 12 位 + 文本框动画 + tab 切换动画 + Apple 默认动画原则

依赖: ticket 21 commit `173b719bb`

**What to build:**
5 项修真因 + 1 新 domain word (老板 2026-08-22 06:46 拍):
1. keyPrefix8 → keyPrefix12 函数修真因 (12 位回显)
2. SecureField + Button + apiError Text 加 .transition(.opacity) (出现/退出 Apple 默认动画)
3. SettingView body Group 修真因: 3 个 tab 加 .transition(.opacity) + .animation(.default, value: selectedTab)
4. CONTEXT.md 新 domain word **WenshuInteractionAnimationPrinciple** (老板原话 "交互动画使用 Apple 标准 API, 持续优雅")
5. 扩展审计: 凡 Apple SwiftUI 标准 API 支持动画的组件, 全加 Apple 默认动画

**Why:**
ticket 21 commit `173b719bb` 老板 macOS 验视觉 OK, 但修真因 5 项优化项. 老板拍原话 "能加动画的, 都要加" = 全修真因 Apple 默认动画.

**Acceptance:**
- 老板 macOS 真验: 已设 key 显 12 位灰度字 / 整条点 → 文本框出现退出 Apple 默认动画 / 切 tab Apple 默认动画 / 持续优雅
- swift build exit 0
- swift test exit 0 (ProviderKeychain 5/5 pass)
- 双轴 code-review verbatim 进 commit body
- Q40 + Q45: 真 key 走 Apple Keychain 不入文件/log/commit, 灰度字仅 UI 显示前 12 位