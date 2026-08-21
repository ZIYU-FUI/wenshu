# 26 — 用 Apple DisclosureGroup 重构 providerApiTab (老板 2026-08-22 拍 + 授权按核心原则推进)

依赖: ticket 16 (bindingForExpanded) + ticket 17 (整条热区) + ticket 22 + 23 (.transition + .animation) + ticket 25 (brand "文枢" 恢复) + ticket 24 revert (.formStyle 恢复)

**What to build:**
用 Apple DisclosureGroup (Apple SwiftUI 11+ 标准手风琴 disclosure 控件) 重构 providerApiTab, 撤我之前自己写的 Button + if condition + .transition + .animation 范式

**Why:**
老板 2026-08-22 拍 "手风琴组件" + "Apple 的" + "组件都自带动画" + 老板授权"按核心原则推进" (= WenshuCommonSenseInteractionPrinciple 老板原话 "使用苹果的 API")

**Acceptance:**
- 老板 macOS 真验: Apple 标准手风琴展开 (DisclosureGroup 自带动画 + 自带 chevron) / 整条热区响应
- swift build exit 0
- swift test exit 0 (ProviderKeychain 5/5 pass)