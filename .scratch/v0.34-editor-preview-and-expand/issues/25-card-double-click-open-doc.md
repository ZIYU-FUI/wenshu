# 25: B-25 BUG1 fix — double-click card opens doc in editor (= multi-tab aware)

## Boss OOB context (= 2026-09-03)

Boss 9/3 macOS visual verify: 'BUG1, 双击卡片后, 不在能编辑器里打开文档' (= double-click on a preview card does nothing). Boss 9/2 spec already required this (= boss 8/31 OOB '点 sidebar row → 右边素材区显示该目录的文档', then boss 9/2 '双击预览区的文件卡片 → 编辑器区打开文档'). The B-13 commit wired EditorPlaceholder to the workspace but didn't wire PreviewPane's Card double-click callbacks (= the call site passes `onDoubleClick: {}` = empty closure = dead code).

## What to build

Wire the PreviewPane card double-click to actually open the document in the editor zone (= via the B-24 multi-tab data model). Flow:

  1. PreviewPane exposes `onCardDoubleClick: (CardSource) -> Void` (= unified
     callback for both .reference and .bookDoc card types). CardSource
     already exists as enum (= no rename needed).
  2. WorkspaceView receives this callback and handles it:
     - if current active tab is clean (= draft == originalBody):
       open the new doc in the SAME tab (= reuse + replace)
     - if current active tab is dirty:
       push a NEW tab onto AppState.openTabs (= Safari behavior;
       = preserve current tab's in-progress edits)
     - in both cases: switch AppState.activeTabId to the new tab
  3. The new EditorTab loads the doc's content (= from BookStore.readDoc
     or ReferenceStore.readReference; = see Q30-Q3 sub-decision below).
  4. Unsupported file types (= images, etc.): show .alert "不支持的文件类型".

## Sub-decisions (= Q30)

  - Q30a: fix BOTH Reference and BookDoc (= unify via CardSource enum).
    Reason: Reference callback was also never wired (= dead code).
  - Q30b: single commit (= unify callback signature + wire both).
  - Q30c: route via AppState.openTabs (= B-24 multi-tab = the natural
    extension point).
  - Q30d: unsupported file = .alert "不支持".

## Blocked by

None (= B-24 data model already supports multi-tab + activeTabId
switching).

## Status

ready-for-agent

## Acceptance criteria

  - [ ] PreviewPane exposes `onCardDoubleClick: (CardSource) -> Void`
  - [ ] WorkspaceView passes a real handler (= replaces the empty `{}`)
  - [ ] WorkspaceView handler routes to AppState.openTabs (= new tab if
    current is dirty; = reuse if current is clean)
  - [ ] New tab's content loaded from BookStore / ReferenceStore
  - [ ] Unsupported file type = .alert "不支持的文件类型"
  - [ ] Reference card double-click also works (= same callback, unified)
  - [ ] Build exit 0
  - [ ] macOS visual verify: double-click BookDoc card → editor opens
    with .md content; switch back to placeholder tab → still works

## Iron rules applied

- Rule 6: no magic numbers (= alert strings inline; = Apple HIG pattern)
- Rule 7: Card uses .onTapGesture(count: 2) (= already; = SwiftUI standard)
- Rule 11: AppState.openTabs + activeTabId = single source of truth
- wenshu-apple-api-first: SwiftUI standard .alert + .onTapGesture
- Boss 9/2 'git grep BEFORE patch' rule: applied (= grep'd all
  onDoubleClick / onEntityDoubleClick / onBookDocDoubleClick
  references before unifying = 2 callback sites, both dead).
- AGENTS.md hard rule: English-only commit body; 0 forbidden vocab

## Double-axis review

- Standards axis: AGENTS.md hard rules + 11 iron rules + ComponentIndex
- Spec axis: Safari tab reuse-if-clean behavior matches Apple HIG
