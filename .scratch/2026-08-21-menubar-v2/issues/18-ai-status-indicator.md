# 18 — AI 回复状态指示器 (Apple ProgressView + Text + SF Symbol symbolEffect pulse)

依赖: ticket 13 + 14 (ChatBottomBar 18 PT inset) + ticket 22 + 23 (.transition + .animation 苹果默认) + ticket 28 (Button 范式) + ticket 29 (撤下边距)

**What to build:**
ChatView ChatBottomBar 加 status indicator:
- 仅 isResponding == true 时显示
- HStack: SF Symbol `brain` + `.symbolEffect(.pulse, options: .repeating)` + "AI 思考中…" Text + ProgressView 圆形 indeterminate
- 整 HStack .transition(.opacity) + .animation(.default, value: chatViewModel.isResponding)

**Why:**
老板 2026-08-22 06:18 拍 "聊天时，AI 在回复时，我看不到任何状态" + "参考 hermes, 实现动态显示" + 2026-08-22 拍推进 "A" = 方案 A = Apple HIG 范式

**Acceptance:**
- 老板 macOS 真验: 发消息 → AI 回复时 status indicator 出现 / AI 回复完成 → 消失
- swift build exit 0
- swift test exit 0 (ProviderKeychain 5/5 pass)
- 双轴 code-review verbatim 进 commit body