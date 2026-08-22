# Issue 18 — Chat AI reply status dynamic display (v0.21 ticket 18)

> Slug: chat-ai-status-indicator
> Scope: `Sources/WenshuApp/Views/Chat/ChatView.swift` + `Sources/WenshuApp/Core/Agent/WenshuConductor.swift` + `Sources/WenshuApp/Core/Agent/ConductorPhase.swift` (new) + `Tests/WenshuAppTests/AIStatusBarTests.swift` (new)
> Spec: `../spec.md.ticket18`
> 老板: 2026-08-22 06:18 backlog, 2026-08-22 14:00 ruled "implement to hermes standard" (= Option A full version, not the simple version)

## Implementation (this commit, 1 ticket 1 commit)

### Step 1: Add `ConductorPhase.swift` enum (5-phase truth)

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

Truth: Apple HIG-truth `Sendable` enum.
- `idle` = default; `AIStatusBar` hidden
- `writing` = `ChatViewModel.send` started, no conductor yet
- `classifyingIntent` = `handle` step 2 LLM intent classify
- `dispatchingAgents` = `handle` step 3 — 0 to N sub-agents `delegateTask`
- `synthesizing` = `handle` step 4 LLM synthesis
- `complete` = `handle` finished; `AIStatusBar` hides

### Step 2: Update `ChatViewModel` — add `aiPhase: ConductorPhase`

`Sources/WenshuApp/Views/Chat/ChatView.swift` (modify):

Modify `ChatViewModel`:
- Add `@Observable public var aiPhase: ConductorPhase = .idle` (Apple Observable truth, thread-safe `@MainActor`)
- Add `private var startedAt: Date? = nil` (for elapsed-time calculation)

Modify `send()`:
- `isSending = true` — also set `aiPhase = .writing`
- `defer { isSending = false }` — also set `aiPhase = .complete` (animation truth)
- `conductor.handle(..., statusCallback: { phase in self.aiPhase = phase })` — relay each phase
- Update: `AIStatusBar` modified accordingly (`complete` triggers the hide)

### Step 3: Update `WenshuConductor.handle` — status callback

`Sources/WenshuApp/Core/Agent/WenshuConductor.swift` (modify):

Update `handle` function signature:
```swift
public func handle(
    userMessage: String,
    sessionId: String,
    statusCallback: @Sendable (ConductorPhase) -> Void = { _ in }
) async -> String
```

Each phase calls the callback:
- Step 1 kanban add — `statusCallback(.dispatchingAgents)` (kanban add triggers the dispatching truth)
- Step 2 intent classify — `statusCallback(.classifyingIntent)`
- Step 3 delegate — `statusCallback(.dispatchingAgents)`
- Step 4 synthesis — `statusCallback(.synthesizing)`
- Final: `statusCallback(.complete)` (success) or `.complete` (S4 fallback)

Truth:
- (StatusUpdate: Q47 macOS SwiftUI 13+ truth + main-actor truth (the callback should bridge MainActor for `@Observable` updates))
- Update wraps the call with `Task { @MainActor in statusCallback(phase) }` for bridging

### Step 4: Add `ChatView` `AIStatusBar` sub-component

`Sources/WenshuApp/Views/Chat/ChatView.swift` (modify):

Modify `ChatView` body `VStack`:
```
VStack(spacing: 0) {
    ScrollViewReader { ... }  // message list (unmodified)
    AIStatusBar(phase: vm.aiPhase, startedAt: ...)  // new (hidden when .idle)
    Divider()
    HStack { ... }  // input field (unmodified, Q20)
    .padding(.horizontal, 18)
    .padding(.bottom, 4)
}
```

Add the `AIStatusBar` struct above `ChatView`:
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
        case .writing: return "Sending…"
        case .classifyingIntent: return "Classifying intent…"
        case .dispatchingAgents: return "Dispatching sub-agents…"
        case .synthesizing: return "Synthesizing reply…"
        case .complete: return ""
        }
    }
}
```

Truth (Q34 principles Q21 SF Symbol + Q22 truth + Q26 4 principles):
- `Image(systemName: "ellipsis")` + `.symbolEffect(.variableColor.iterative)` = Apple SF Symbol standard SF Symbols truth (`:iOS 17 / macOS 14+`)
- Use `.ultraThinMaterial` (Apple semantic truth)
- Use `.transition` + `AIStatusBar` animated transitions (ticket 22's default animation principle)
- Use `Text(_:style:)` with `DateStyle.timer` (macOS 11+ truth, live-updating value, or `Text(timerInterval:)` macOS 13+ standard API)

### Step 5: Lock Q20 hard constraints

Untouched: `ChatZoneView` `VStack` ordering + `ChatView` input-field layout + `ChatBottomBar` 18 PT inset + `ChatViewModel.send / clear / switchModel / loadAvailableModels` API + `WenshuConductor.handle` 4-phase logic + `AgentProtocol` protocol — all locked.

## Q34 dual-axis code-review

The commit message aggregates fixes from dual-axis sub-agent review + Findings verbatim → commit CC:

```
feat(wenshu): v0.21 ticket 18 AI reply status dynamic display (老板 8/22 14:00 ruled hermes standard)

老板 ruled "while AI is replying, I can't see any status" + "implement to hermes standard".

Hermes truth: 3 sections = left ellipsis pulse + middle status text + right elapsed timer.
Q47 + Q51 + Q20 locked: ChatZoneView / ChatView / WenshuConductor parents untouched + new AIStatusBar subview.
5 principles: Apple HIG truth + SF Symbol semantic color + effect-first + business language + po main flow dual-axis.
3 status phases: classifying intent / dispatching sub-agents / synthesizing reply (WenshuConductor.handle).
```

## Acceptance

- [ ] `swift build` exit 0
- [ ] `swift test` exit 0 + 0 test failures
- [ ] Q22 CUA verification: open `ChatZoneView` + `AIStatusBar` appears
- [ ] 老板 macOS verification: send a message → `AIStatusBar` shows → on completion hides with elapsed time
- [ ] Q34 dual-axis Standards + Spec review
- [ ] Add to `CONTEXT.md`: `AIStatusBar` + `ConductorPhase` domain words
