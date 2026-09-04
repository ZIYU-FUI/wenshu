# 24: B-24 multi-tab editor (= Safari-style tab strip)

## Boss OOB context

Boss 2026-09-02 OOB (= `我想替换编辑区顶栏正中间的位置, 用 safari 的模式, 总可用宽度别挤到左边的 teb, 右边的按钮就行`). The current editor zone top toolbar = single row with doc-name-left + mode-toggle-center + save/expand/close-right. Boss wants to REPLACE the center slot with a Safari-style multi-tab strip (= each tab = one open document; = click to switch; = close button per tab; = the right-side save/expand/close buttons stay).

## What to build

Replace `EditorPlaceholder` top toolbar center slot (= currently = mode toggle) with a Safari-style tab strip. Layout:

  - LEFT slot (= preserved): doc basename (`preview-sample.md` text).
  - CENTER slot (= NEW): tab strip with all open documents.
    Each tab = a `PaneIconTab`-like component with:
      - Lucide icon (= file icon, or specific doc type icon)
      - Document basename (truncated middle = `…name.md`)
      - Unsaved indicator (• = dirty)
      - Close button (×) on hover
      - Selected state: accent underline + bold text
    Behavior:
      - Click tab = switch active document (= loads draft from that tab)
      - Click × = close tab (= if last tab = placeholder/sample body stays)
      - Tab overflow = horizontal scroll
      - Click tab's doc-name (not ×) = switch active
    Layout: scrollable horizontal HStack inside the toolbar (= max width
    = editor zone width - left basename slot - right buttons).
  - RIGHT slot (= preserved): save + expand + close buttons (= 现有).

## Data model

Replace:
```swift
@State private var documentPath: String? = nil
@State private var draft: String = EditorPlaceholder.samplePreviewBody
@State private var originalBody: String = EditorPlaceholder.samplePreviewBody
```

With:
```swift
@State private var openTabs: [EditorTab] = [.placeholder]
@State private var activeTabId: UUID = .placeholder

struct EditorTab: Identifiable, Equatable {
    let id: UUID
    var documentPath: String?    // nil = placeholder/sample body
    var draft: String
    var originalBody: String
    var mode: Mode   // .preview | .edit
}
```

For each tab:
  - Independent draft + originalBody (= per-tab dirty state)
  - Independent mode (= preview vs edit per tab)
  - Independent auto-save task (per-tab)
  - Per-tab file watcher (= B-23 stack)

## Blocked by

None (= B-23 file watcher is per-tab; = works once data model is per-tab).

## Status

ready-for-agent

## Acceptance criteria

- [ ] New `EditorTab` struct (= per-tab state)
- [ ] openTabs array on AppState (= single source of truth across views)
- [ ] Tab strip component (= `MultiTabBar`) shows all open tabs with selected/close buttons
- [ ] Click tab = switch active; click × = close tab
- [ ] Right-side save/expand/close buttons preserved
- [ ] Left doc-basename text preserved (or removed = tab shows it)
- [ ] Auto-save (B-22) works per tab (= independent dirty + autoSaveTask per tab)
- [ ] File watcher (B-23) works per tab (= independent DispatchSource per tab)
- [ ] macOS visual verify: open 2+ docs, switch tabs, close tabs, see state preserved

## Iron rules applied

- Rule 6: tab bar = 30 PT height (= Apple HIG standard toolbar)
- Rule 7: tab strip = SwiftUI HStack with PaneIconTab-like components
- Rule 8: no new NSWindow
- Rule 11: per-tab @State (= reactive per tab)
- wenshu-apple-api-first: SwiftUI standard tabs
- AGENTS.md hard rule: English-only commit body; 0 forbidden vocab

## Double-axis review

- [ ] Standards axis: AGENTS.md hard rules + 11 iron rules + ComponentIndex consistency
- [ ] Spec axis: Safari tab strip behavior matches (= close button, scroll overflow, selected state)
