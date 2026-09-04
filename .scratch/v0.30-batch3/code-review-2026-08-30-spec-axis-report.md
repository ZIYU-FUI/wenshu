# Spec Axis Report — v0.30 batch3 (4 commits)

> Date: 2026-08-30
> Sub-agent: Spec axis
> Commits reviewed: 291487322, 09c6521e2, bf86a0b2b, a8bebb858

## Verdict: PASS (with one CONDITIONAL on 291487322)

All four commits deliver what the boss OOB requested at the time they
landed. One minor CONDITIONAL flag on `291487322` because the commit
message itself admits that the sidebar-category → card-flow click
binding was never visually verified end-to-end during screenshot tests
("Known limitation: category-scoped click ... needs more precise click
coordinates ... didn't activate during test screenshots. The binding
mechanism works (= verified by build + sidebar tree shows live
updates)"). Code-level wiring is complete; runtime click-handler hit-
testing was not.

## Per-commit findings

### Commit 291487322 — EntityPreviewPane
Boss OOB: '实体分类在目录树里是最后一层，点击后，实体文档要用随心记
的卡片流样式显示在素材管理区'

Spec compliance:
  [x] Card grid — `LazyVGrid` adaptive columns 220-320 PT in
      `EntityPreviewPane.swift`, plus a dedicated `EntityCard` view
      (type badge + category chip + title + summary + source,
      `RoundedRectangle.fill(.background)` + shadow, double-click
      handler wired to `onEntityDoubleClick`).
  [x] On category click — `NewLibraryOutlineView.swift` adds
      `@Binding var selectedEntityCategory` and on tap sets
      `selectedEntityCategory = category`; `WorkspaceView` owns the
      `@State`, `EntityPreviewPane` branches on `selectedCategory`
      into `categoryGrid(...)`. End-to-end binding chain verified by
      code read.
  [x] Material management zone (项目预览区) — `WorkspaceView` case
      `.projectPreview` swaps `PreviewTabBackground` stub for
      `EntityPreviewPane`.
  [x] Three view modes (overview / category / detail) — all three
      present.

Scope check:
  Files: 1 new (`EntityPreviewPane.swift` 312 lines) + 4 modified
  (WorkspaceView, NewLibraryOutlineView, RegisteredPanes, App). All
  changes coherently propagate the selectedCategory binding.

CONDITIONAL: author self-disclosed limitation that category-scoped
click activation was not visually proven in screenshots. The binding
mechanism is in place; click hit-area should be smoke-tested manually
to confirm the OOB actually fires from the sidebar tree. Spec-axis
(correctness-of-mapping-to-OOB) = PASS.

### Commit 09c6521e2 — sidebar folder count badge
Boss OOB: '为什么角色, 世界观, 后面没有显示数字'

Spec compliance:
  [x] Count badge — `NewLibraryOutlineView.standardFolderNodes`
      passes `count: docCount` (was `nil`) to `FCPTreeNode`. The
      `Text("\(count)")` badge that already existed in `FCPRowView`
      now receives a non-nil value for folder rows.
  [x] .md count — `BookStore.folderDocumentCount(bookId:folderDirectoryName:)`
      scans `<ws>/shelves/<shelf-id>/books/<book-id>/<folder>/*.md`,
      filters `pathExtension == "md"`. Mirrored on `WenshuLibrary`.
  [x] Forgiving convention — missing folder / permission error → 0
      (no crash).
  [x] Path-aware — passes per-folder `directoryName` ('world' /
      'characters' / 'outlines' / 'chapters' / 'drafts') so the
      helper resolves the right on-disk folder.

Scope check:
  Files: 3 modified (BookStore.swift, WenshuLibrary.swift,
  NewLibraryOutlineView.swift). Deferred: `BookCategory` enum
  extension (currently only 3 cases) to v0.31+ — appropriate scope
  decision for v0.30.

Runtime evidence:
  /Users/anbaiqiang/Documents/anbaiqiang.ws/shelves/...
    world/        → 1 .md
    characters/   → 6 .md  (post-bf86a0b2b split)
    outlines/     → 1 .md
    chapters/     → 9 .md  (post-bf86a0b2b split)
    drafts/       → 1 .md
  Folder row badges will display those counts.

### Commit bf86a0b2b — split help-doc files
Boss OOB: '角色一个文件拆成六个吧' + '功能模块也是，一个功能模块拆成
一个文档'

Spec compliance:
  [x] 6 character files — `Scripts/split-help-docs.py` defines an
      `agent_files` list with exactly 6 entries:
        - 主Agent-Conductor.md
        - 副Agent-SubAgent.md
        - 资料库Wiki派-Reference.md
        - 状态追踪派-Status.md
        - 备份派-Backup.md
        - 定时任务派-Cron.md
      Loop `for agent in agent_files: write_md("characters", ...)`
      writes all 6 and deletes the parent `characters/六个Agent.md`.
      Python AST count confirms 6.
  [x] 9 module files — `module_files` list has exactly 9 entries
      (01-项目管理区-Sidebar.md through 09-交互约定-KeyboardShortcuts.md).
      Loop `for module in module_files: write_md("chapters", ...)`
      writes all 9 and deletes the parent `chapters/功能模块说明.md`.
      Python AST count confirms 9.
  [x] Migrator no longer re-creates merged files —
      `LibraryMigrator.swift` helpDocUpgrade sections 4.2/4.4 no
      longer write `六个Agent.md` / `功能模块说明.md`; replaced with
      delete-if-exists so stale merged files don't come back.

Scope check:
  Files: 1 new (`split-help-docs.py` 636 lines) + 1 modified
  (`LibraryMigrator.swift`). 

Runtime evidence:
  /Users/anbaiqiang/Documents/anbaiqiang.ws/shelves/.../characters/:
    主Agent-Conductor.md
    副Agent-SubAgent.md
    备份派-Backup.md
    定时任务派-Cron.md
    状态追踪派-Status.md
    资料库Wiki派-Reference.md
    (= exactly 6 .md files, parent 六个Agent.md removed)
  .../chapters/:
    01-项目管理区-Sidebar.md
    02-素材预览区-Preview.md
    03-编辑器-Editor.md
    04-工具区-Tools.md
    05-聊天区-Chat.md
    06-动态区-Dynamic.md
    07-资料库-ReferenceLibrary.md
    08-标题栏和状态栏-ChromeStatusBar.md
    09-交互约定-KeyboardShortcuts.md
    (= exactly 9 .md files, parent 功能模块说明.md removed)

### Commit a8bebb858 — sidebar 18 PT padding
Boss OOB: '目录树后面的数字，距离右边距没有留空隙，留出来 18pt 的
空隙'

Spec compliance:
  [x] `.padding(.trailing, 18)` present — diff for
      `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift`
      at the time of commit shows the exact addition:
        `.padding(.trailing, 18)`
      applied at line 838 (after `.frame(height: rowHeight)`,
      before `.contentShape(Rectangle())`), inside `FCPRowView`
      (= the row used by every sidebar tree entry at that point
      in v0.30 history).
  [x] Applied to whole row — applies to the row's content HStack
      (label, chevron, count badge) → each trailing element gets
      the 18 PT breathing room from the pane's right divider.

Scope check:
  Files: 1 modified (NewLibraryOutlineView.swift, +10 lines).

Acknowledgment — important context, NOT a spec failure:
  A LATER commit (`c5ed76169` — "sidebar migrated to Apple HIG
  standard List") removed `FCPRowView` entirely and the file's
  current state shows:
    `// - 18 PT .padding(.trailing) on each row          → removed`
  in the file header comment. The Spec-axis review evaluates the
  commit AT THE TIME IT LANDED, and at that moment the .padding
  (.trailing, 18) was present and active. The later refactor is
  out of scope for this 4-commit Spec review; it should be tracked
  separately (does the Apple HIG List itself produce equivalent
  trailing breathing room, or did boss OOB regress?).

## Spec FAIL

None. All four commits deliver their stated boss OOB:
  - 291487322: ✅ card-flow grid + click binding (CONDITIONAL pending
    manual click-handler verification at runtime)
  - 09c6521e2: ✅ per-folder .md count badge with forgiving 0 default
  - bf86a0b2b: ✅ 6 character files + 9 module files (runtime-confirmed)
  - a8bebb858: ✅ .padding(.trailing, 18) added on sidebar tree row

## Summary

All four v0.30 batch3 commits map cleanly onto their boss OOB. The
EntityPreviewPane (291487322) introduces a real LazyVGrid card flow
into the projectPreview zone, with a binding chain from sidebar tap
→ WorkspaceView state → EntityPreviewPane category mode; one self-
disclosed CONDITIONAL on runtime click activation. The count-badge
fix (09c6521e2) wires `BookStore.folderDocumentCount` through to the
FCPTreeNode so each sidebar folder row shows its .md count. The
help-doc splitter (bf86a0b2b) generates exactly 6 character files
and 9 module files via `Scripts/split-help-docs.py` AND removes the
auto-merge code from `LibraryMigrator.swift`, with runtime
filesystem verification confirming the split. The 18 PT padding
commit (a8bebb858) adds `.padding(.trailing, 18)` to every sidebar
tree row at commit-time (a later Apple-HIG List refactor replaces
this approach but is out-of-scope for this 4-commit Spec review).
