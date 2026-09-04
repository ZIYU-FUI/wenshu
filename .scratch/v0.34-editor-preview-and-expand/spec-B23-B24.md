# v0.34 B-23 + B-24 spec (= auto-reload + multi-tab)

## Boss OOB context (= 2026-09-02)

1. **Agent 正在编辑的文档, 实时显示文字** = "我希望是实时的出现文字, 看着很酷"
2. **双击另一文档时, 当前文档如何处理** = "如果 agent 真在编辑当前文件, 这时候我双击了其他的文档卡片, 当前文件会如何"

**Clarification trail (= boss 9/2):**
- Q25: 不用接 LLM stream (= 不做真 SSE 接 LLM token 流)。 **文件自动刷新就够**。
- Q26: 多文档策略走推荐 A(= multi-tab, Safari style, top center)。
- Q27: 文件变化时的脏数据策略走 D(= save user edits to .local-wenshu-conflict-xxx.md, then overwrite + notify)。
- Q28: tab bar 替换 editor zone 顶 toolbar 中间位置, 左 doc basename 保留, 右 existing buttons (save/expand/close) 保留。

## What to build (= 2 tickets)

### B-23: File auto-reload on external writes

`DispatchSource.makeFileSystemObjectSource` on `documentPath`. When the file changes (= agent wrote via wenshu internal API, terminal `echo`, git pull, another app):

  - **Clean state** (= `draft == originalBody`): silent reload. No notification.
  - **Dirty state** (= `draft != originalBody`): save current draft to `<file>.local-wenshu-conflict-<unix-timestamp>.md`, then reload + post notification.

### B-24: Multi-tab editor (= Safari-style)

Replace `EditorPlaceholder` top toolbar center slot with a tab strip. Each tab = one open document (= independent draft, mode, auto-save task, file watcher). Tab strip behavior matches Safari (= click to switch, × to close, scrollable overflow, selected underline).

## Data model change

```swift
// Before:
@State private var documentPath: String? = nil
@State private var draft: String = EditorPlaceholder.samplePreviewBody
@State private var originalBody: String = EditorPlaceholder.samplePreviewBody
@State private var mode: Mode = .preview
@State private var autoSaveTask: Task<Void, Never>?

// After:
struct EditorTab: Identifiable, Equatable {
    let id: UUID
    var documentPath: String?
    var draft: String
    var originalBody: String
    var mode: Mode
    var autoSaveTask: Task<Void, Never>?
}

@State private var openTabs: [EditorTab] = [.placeholder]
@State private var activeTabId: UUID = EditorTab.placeholderId
```

`AppState.openTabs: [EditorTab]` (= single source of truth across views; = future cross-zone ref).

## Acceptance criteria

B-23 (= file auto-reload):
- [ ] DispatchSource watcher on `documentPath`
- [ ] Clean-state silent reload
- [ ] Dirty-state save-then-reload + notify
- [ ] Tear-down on documentPath change + onDisappear

B-24 (= multi-tab):
- [ ] EditorTab struct + AppState.openTabs + activeTabId
- [ ] Tab strip component (= Safari style)
- [ ] Per-tab dirty / mode / auto-save / file-watcher
- [ ] Click tab = switch; click × = close
- [ ] Existing toolbar slots preserved (= doc name left + save/expand/close right)

## Iron rules applied

- Rule 6: DesignTokens (= tab bar = 30 PT, = Apple HIG standard)
- Rule 7: PaneIconTab-style components (= reuse existing helper)
- Rule 8: no new NSWindow
- Rule 11: per-tab @State + AppState cross-view state
- wenshu-apple-api-first: DispatchSource = Apple Foundation standard; Safari-style tabs = SwiftUI standard
- AGENTS.md hard rule: English-only commit body; 0 forbidden vocab

## Double-axis review

- Standards axis: AGENTS.md hard rules + 11 iron rules + ComponentIndex
- Spec axis: Apple TextEdit auto-reload + Safari tab strip behavior matches

Last line: fact.
