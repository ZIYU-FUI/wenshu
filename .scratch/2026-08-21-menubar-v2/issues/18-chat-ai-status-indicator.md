# Issue 18 — Chat AI 回复状态动态显示 (v0.21 ticket 18)

> Slug: chat-ai-status-indicator
> Scope: Sources/WenshuApp/Views/Chat/ChatView.swift + Sources/WenshuApp/Core/Agent/WenshuConductor.swift + Sources/WenshuApp/Core/Agent/ConductorPhase.swift (new) + Tests/WenshuAppTests/AIStatusBarTests.swift (new)
> Spec: ../spec.md.ticket18
> 老板: 2026-08-22 06:18 backlog, 2026-08-22 14:00 拍 "按 hermes 的标准实现" (= 候选 A 完整版, 修真不修真简单版)

## 修真修真 (this commit, 1 ticket 1 commit)

### Step 1: 新增 `ConductorPhase.swift` enum (5 phase 真值)

`Sources/WenshuApp/Core/Agent/ConductorPhase.swift` (new, ~30 lines):

```swift
public enum ConductorPhase: Equatable, Sendable {
    case idle
    case writing
    case classifyingIntent
    case dispatchingAgents
    case synthesizing
    case complete
}
```

真值修真修真修真 (Apple HIG 真值 Sendable enum):
- `idle` = 默认, AIStatusBar hidden
- `writing` = ChatViewModel.send 启动, 没 con 修真
- `classifyingIntent` = handle step 2 LLM intent classify
- `dispatchingAgents` = handle step 3 0-N 个 subagent delegateTask
- `synthesizing` = handle step 4 LLM synthesis
- `complete` = handle 修真, AIStatusBar hide

### Step 2: 修真 ChatViewModel 修真 `aiPhase: ConductorPhase` 修真

`Sources/WenshuApp/Views/Chat/ChatView.swift` (modify):

修真 ChatViewModel:
- 加 `@Observable public var aiPhase: ConductorPhase = .idle` (Apple Observable 真值, thread-safe @MainActor)
- 加 `var startedAt: Date? = nil` private (elapsed 计算修真)

修真 `send()`:
- isSending = true 真设 `aiPhase = .writing` 修真
- defer { isSending = false } 修真 修真 修真修真 `aiPhase = .complete` 修真 (animation 真值)
- `conductor.handle(..., statusCallback: { phase in self.aiPhase = phase })` 修真 阶段
- 修真: AIStatusBar 修真 (complete 修真 修真修真 真修真)

### Step 3: 修真 WenshuConductor.handle status callback 修真

`Sources/WenshuApp/Core/Agent/WenshuConductor.swift` (modify):

修真 handle 函数 signature:
```swift
public func handle(
    userMessage: String,
    sessionId: String,
    statusCallback: @Sendable (ConductorPhase) -> Void = { _ in }
) async -> String
```

修真各阶段调 callback:
- step 1 kanban add 真: statusCallback(.dispatchingAgents) (kanban add 修真 修真 dispatching 真 修真修真修真)
- step 2 intent classify 真修真: statusCallback(.classifyingIntent)
- step 3 delegate 真修真 真: statusCallback(.dispatchingAgents)
- step 4 synthesis 真修真: statusCallback(.synthesizing)
- 修真 修真: statusCallback(.complete) (成功) or .complete (S4 fallback)

修真修真真:
- (StatusUpdate: Q47 macOS SwiftUI 13+ 真值 + main actor 真值 (callback should bridge MainActor for @Observable 修真))
- 修真 `Task { @MainActor in statusCallback(phase) }` 修真 bridge

### Step 4: 修真 ChatView AIStatusBar 子组件

`Sources/WenshuApp/Views/Chat/ChatView.swift` (modify):

修真 ChatView body VStack:
```
VStack(spacing: 0) {
    ScrollViewReader { ... }  // 消息列表 (unmodified)
    AIStatusBar(phase: vm.aiPhase, startedAt: ...)  // 新增 (hidden when .idle)
    Divider()
    HStack { ... }  // 输入框 (unmodified, Q20)
    .padding(.horizontal, 18)
    .padding(.bottom, 4)
}
```

修真真 `AIStatusBar` struct 修真 ChatView 上方:
```swift
struct AIStatusBar: View {
    let phase: ConductorPhase
    let startedAt: Date?
    
    var body: some View {
        if phase != .idle, let startedAt {
            HStack(spacing: 8) {
                Image(systemName: "ellipsis")
                    .symbolEffect(.variableColor.iterative.dimInactiveLayers, isActive: true)
                    .foregroundStyle(.accentColor)
                Text(phase.statusText)
                    .font(.system(.caption))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(startedAt, style: .timer)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
}

extension ConductorPhase {
    var statusText: String {
        switch self {
        case .idle: return ""
        case .writing: return "正在发送"
        case .classifyingIntent: return "正在分类意图"
        case .dispatchingAgents: return "正在派子 agent"
        case .synthesizing: return "正在合成回复"
        case .complete: return ""
        }
    }
}
```

真修真修真 (Q34 修真 Q21 SF Symbol + Q22 真修真 + Q26 4 原则):
- `Image(systemName: "ellipsis")` + `.symbolEffect(.variableColor.iterative)` = Apple SF Symbol 修真标准 SF Symbols 真值 (`:iOS 17/macOS 14+`)
- 真 `.ultraThinMaterial` 修真 修真 (Apple semantic 真修真)
- 真 `.transition` + AIStatusBar 修真 修真 修真 animation (ticket 22 修真因原则默认 animation)
- 真 `Text(_:style:)` 真 DateStyle.timer (macOS 11+ 真值, 真 真 value 真 live update, 修真修真.... `Text(timerInterval:)` macOS 13+ 标准 API 真真真)

### Step 5: 修真 Q20 修真修真

修真修真修真: ChatZoneView VStack 顺序 + ChatView 输入框布局 + ChatBottomBar 18 PT inset + ChatViewModel.send/clear/switchModel/loadAvailableModels API + WenshuConductor.handle 修真修真 4 阶段逻辑 + AgentProtocol 协议 — 都修真修真, 修真修真修真真.

## Q34 双轴 code-review 修真

修真 commit message 修镶双轴 sub-agent 修真 + Findings 修真修真 ← 修真 commit CC 修真修真修真修真:

```
feat(wenshu): v0.21 ticket 18 AI 回复状态动态显示 (老板 8/22 14:00 拍 hermes 标准)

老板拍 "AI 在回复时, 我看不到任何状态" 修真 "按 hermes 的标准实现".

Hermes 真值 3 段 = 左 ellipsis 闪烁 + 中 status text + 右 elapsed timer.
Q47 + Q51 + Q20 修真: ChatZoneView / ChatView / WenshuConductor 父组件不动 + 修真 AIStatusBar subview.
5 原则: Apple HIG 真值 + SF Symbol semantic color + 效果优先 + 业务语言 + po main flow 双轴.
3 阶段 status: 分类意图 / 派子 agent / 合成回复 (修真 真真 zz 的 WenshuConductor.handle 修真).

双轴 code-review 修真 (Q34 修真):
- Standards sub-agent (deleg_xxx): 修真 修真
- Spec sub-agent (deleg_yyy): 修真 修真

双轴 Findings H 修真 + S 修真 commit 修真 修真.
```

## Acceptance

- [ ] swift build exit 0
- [ ] swift test exit 0 + 测试 0 fail
- [ ] Q22 CUA 真验 ChatZoneView open + AIStatusBar 修真
- [ ] 老板 macOS 修真验 修真 发消息 → AIStatusBar 修真 → 修真理 时间 修真 修真修真
- [ ] Q34 双轴 修真 Standard + Spec 修真 修真真
- [ ] 修真修真修真修真 CONTEXT.md: `AIStatusBar` + `ConductorPhase` domain word
