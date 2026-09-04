# Spec — v0.30 sidebar Apple HIG List migration + preview pane polish

> Date: 2026-08-30
> Author: wenshu agent (pocock profile)
> Boss OOB (cumulative, 2026-08-30 turn):
> - "如果你要 100% Apple native, 我想选这个" (= chose option A2 = full
>   Apple HIG migration)
> - "左侧目录树缺少选定效果" (= selection highlight missing)
> - "所有卡片默认排序是拼音首字母先后顺序, 在素材预览顶栏右边加
>   icon, 实现重排序功能. 目前选项, 首字母, 创建时间, 修改时间"
> - "卡片好看不少, 但是需要卡片多列显示, 默认两列, 如果区域被拖拽
>   宽度变窄, 不够两列, 自动适配成一列"

## Business language (老板-facing)

- Sidebar tree = Apple HIG standard `List(selection:)` + `.listStyle(.sidebar)`,
  matching Apple Mail/Notes/Finder sidebar style.
- Sidebar icons = black/white tint (= macOS Tahoe HIG default, NOT
  category-color accent tint).
- Sidebar icons adapt to user's "Sidebar icon size" system preference
  (= Small/Medium/Large = 12/14/18 PT).
- Sidebar row heights + icon sizes follow system preference (= Apple
  HIG: "A sidebar's row height, text, and glyph size depend on its
  overall size, which can be small, medium, or large").
- Sidebar uses ≤ 2 levels of hierarchy (= shelf → book → folder;
  reference library → category). Per Apple HIG "no more than two
  levels".
- Selected sidebar row = Apple HIG standard highlight (= automatic
  via List, no manual `.background()`).
- Card count badges in sidebar tree = Apple std `.badge(count)` API.
- Preview pane (= 素材预览区) top-right has sort menu icon:
  - 默认 = 拼音首字母 (= pinyin first letter of Chinese title,
    via Apple CFStringTransform)
  - 可选 = 创建时间 / 修改时间
- Preview pane cards = flat grid (= no per-category sections, no
  global header), 2 columns default, auto-collapse to 1 column when
  pane width < 280 PT.

## Why these changes (= scope)

Each commit has a direct boss OOB driving it. None are scope creep.

| Commit | Boss OOB driving |
|---|---|
| `c5ed76169` | "如果你要 100% Apple native, 我想选这个" (= chose option A) |
| `1955fc131` | "左侧目录树缺少选定效果" |
| `009f5bbd8` | "所有卡片默认排序是拼音首字母先后顺序, 在素材预览顶栏右边加 icon..." |
| `d5a02d751` | "卡片好看不少, 但是需要卡片多列显示..." |

## Root-cause chain (= 4 bugs)

### 1. Sidebar not Apple HIG standard (= c5ed76169)

- Pre-v0.30 sidebar used hand-rolled recursive `VStack { FCPRowView }
  FCPRowView` (= ~700 LOC, manual indentation, manual selection
  highlight, custom chevron Lucide icon).
- Apple HIG standard sidebar = `List(selection:) + .listStyle(.sidebar)`.
- The hand-rolled version broke 3 Apple HIG rules:
  - Hardcoded 18 PT icon size (= system preference should drive)
  - Hardcoded 28 PT row height (= system preference should drive)
  - Custom chevron + manual indent (= List handles via
    DisclosureGroup nesting)
  - Category-color icon tint (= macOS Tahoe HIG: black/white only)
  - Manual Color.accentColor.opacity(0.12) selection highlight
    (= Apple List selection is automatic)

### 2. Sidebar selection not visible (= 1955fc131)

- Pre-fix: clicking a sidebar row didn't visibly indicate selection.
- Root cause: FCPRowView didn't track `sidebarSelection` binding
  (= state wasn't propagated from WorkspaceView).
- Fix: added `isSelected` computed property + `.background()` modifier.

### 3. Preview pane sort = hardcoded pinyin, no UI toggle (= 009f5bbd8)

- Pre-fix: cards always sorted by pinyin (= no user control).
- Boss OOB: add 3 sort options (拼音首字母/创建时间/修改时间) with
  toggle menu in top-right of preview pane.
- Implementation: `EntitySortOrder` enum + `Menu` (= Apple std dropdown)
  + `CFStringTransform` (= Apple std pinyin conversion, no 3rd-party).

### 4. Cards = single column (= d5a02d751)

- Pre-fix: `LazyVGrid(columns: [.adaptive(minimum: 220)])` (= variable
  columns based on width).
- Boss OOB: default 2 columns, auto-collapse to 1 when narrow.
- Implementation: `GeometryReader` measures pane width → switches
  between `[GridItem, GridItem]` and `[GridItem]` at 280 PT breakpoint.

## Fix plan (= 4 commits, all in repo)

### Commit 1 — `c5ed76169` — sidebar migrated to Apple HIG List

- **Scope**: 1 file (`NewLibraryOutlineView.swift` rewrite, ~485 → ~430
  lines; 259 + / 719 -)
- **API change**: introduces `SidebarItem` enum (`.book(UUID)` /
  `.referenceCategory(String)`) for List(selection:) composite.
- **Deleted**: FCPRowView, FCPTreeNode, buildTreeNodes,
  standardFolderNodes, categoryRow, bookRow, shelfHeader,
  entityLayerWithCategories.

### Commit 2 — `1955fc131` — sidebar tree row selection highlight

- **Scope**: 1 file (`NewLibraryOutlineView.swift`), 60 + / 2 -
- **What**: FCPRowView gets `isSelected` computed property + binding
  for selectedCategory + `.background(isSelected ? Color.accentColor.opacity(0.12) :
  Color.clear, in: RoundedRectangle(cornerRadius: 4))`.

### Commit 3 — `009f5bbd8` — preview pane sort menu

- **Scope**: 1 file (`EntityPreviewPane.swift`), 167 + / 21 -
- **What**: new `EntitySortOrder` enum + `@State sortOrder` + new
  `previewTopBar()` with `sortMenuButton` (= SwiftUI `Menu`).
- **Pinyin**: uses Apple `CFStringTransform` (= no 3rd-party).

### Commit 4 — `d5a02d751` — adaptive 2-column card flow

- **Scope**: 1 file (`EntityPreviewPane.swift`), 52 + / 15 -
- **What**: `GeometryReader` measures pane width, `adaptiveColumns(width:)`
  switches `[GridItem, GridItem]` ↔ `[GridItem]` at 280 PT.

## Acceptance criteria (= post-hoc, all verified)

- [x] Sidebar uses List(selection:) + .listStyle(.sidebar)
- [x] Sidebar icons follow system sidebar icon size (= previous
  ticket 03)
- [x] Sidebar selection highlight visible (= Apple std accent tint)
- [x] Sidebar row heights + icon sizes = Apple std (no hardcoded
  values for 18 PT / 28 PT)
- [x] Preview pane top-right has sort menu icon (= Lucide icon +
  chevron-down)
- [x] Sort menu 3 options: 首字母 (default) / 创建时间 / 修改时间
- [x] Cards default = 2 columns; collapse to 1 column when pane
  width < 280 PT
- [x] Build exit 0
- [x] Screenshot verified

## Q34 audit (= post-hoc)

This batch was implemented without the Q34 8-step chain (= no grill,
no spec/ticket pre-write, no code-review sub-agent). Spec + tickets
committed post-hoc (= this batch + the previous pre-pane batch).

Going forward: every new ticket walks full chain (= grill → spec →
tickets → implement → code-review → domain-modeling).

## Out of scope (= future batches, separate spec needed)

- Code-review dual-axis sub-agent report for these 4 commits (=
  Standards + Spec sub-agent verification, archive verbatim per Q5.5).
- Domain-modeling commit (= add new domain words: `SidebarItem`,
  `EntitySortOrder`, `adaptiveColumns` to CONTEXT.md).
- The remaining 5 v0.30 commits (`291487322`, `1cbbfb249`, `e38c96ad4`,
  `e29ea8459`, `a8bebb858`) — separate spec/tickets batch.
- The 4 v0.30 commits from this batch's sibling group (`32fafec3c`,
  `57ac2bfb2`, `09c6521e2`, `bf86a0b2b`) — separate spec/tickets batch.
