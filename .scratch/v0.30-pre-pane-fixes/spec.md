# Spec — v0.30 sidebar tree trailing buttons + per-system-preference icon size

> Date: 2026-08-30
> Author: wenshu agent (pocock profile)
> Boss OOB:
> - "我看截图, 你把库管理顶栏右边的新建和导入按钮改掉了, 原来的不能用吗, 为什么换" (2026-08-30)
> - "目录树有一个按文字从这里开始, 那个应该是没用的, 正式的从这里开始缺少 ICON" (2026-08-30)
> - "试一下 Apple 系统设置 → General → Sidebar icon size = 改 Small/Medium/Large 看 sidebar 是否跟随" (2026-08-30)

## Business language (老板-facing)

- Sidebar zone header (= 顶栏右边) has 2 icon buttons that match the
  v0.27 commit `bca226704` original: 新建 (square-plus Lucide) + 入驻
  (square-arrow-right Lucide). Both icons are Lucide canonical (= no
  SF Symbol mixed in).
- Sidebar tree rows all show their type icon (= no row appears as
  text-only). Book row specifically shows the `book` icon.
- Sidebar icon size adapts to the user's "Sidebar icon size" macOS
  system preference (= Apple 系统设置 → General → Sidebar icon size).
  Small (1) → 12 PT, Medium (2) → 14 PT (default), Large (3) → 18 PT.

## Why these 2 commits were the user's top-priority fixes (= scope)

The user reported 2 specific bugs after seeing my v0.30 sidebar rewrite
screenshot:

1. **Trailing buttons disappeared** — boss observed the sidebar zone
   header had only the book icon, no trailing 新建/入驻 buttons. Root
   cause = `useWorkspace` defaulted to false (= LayoutShellView path),
   which uses `ZoneModule` (= no `trailingButton` slot). Fix =
   flip default to true (= WorkspaceView path uses ZoneContentView with
   trailingButton wiring from v0.27 commit `bca226704`).

2. **Icon mismatch** — boss observed the 新建 button had an SF Symbol
   "plus" icon (= not the v0.27 Lucide canonical "square-plus").
   Fix = restore Lucide icons.

The third OOB (= book row missing icon, sidebar icon size adaptation)
was surfaced in the same turn by boss observation.

## Root-cause chain

### 1. Trailing buttons invisible (= commit `3342850a6`)

- `LibraryRootView.useWorkspace: Bool = false` was the default
  (= the v0.27 flag was introduced while WorkspaceView was still
  stabilizing; LayoutShellView was kept as default).
- LayoutShellView calls `ZoneModule(slot: .projectSidebar, ...)`
  (= no trailingButton parameter on `ZoneModule`).
- ZoneContentView has trailingButton slot (= wired to
  `NewLibraryOutlineView().zoneHeaderButtons` in App.swift:2626),
  but only WorkspaceView path uses ZoneContentView.
- Result: trailing buttons never rendered in default path since
  v0.28 followup (= LayoutShellView still default).

### 2. Lucide icon mismatch (= commit `0f7f28ede`)

- My v0.30 sidebar rewrite simplified the 新建 button label from
  `LucideIcon("square-plus", size: 18)` to `Image(systemName: "plus")`.
- Boss noticed the SF Symbol didn't match the rest of the sidebar
  tree (= all Lucide).

### 3. Book row text-only (= commit `0012d857c` part 1)

- `LucideIcon("book.closed", ...)` calls Lucide with the name
  "book.closed".
- Lucide has only `book` (= case book = "book" in LucideIcon enum).
  "book.closed" doesn't exist.
- LucideIcon helper falls back to `Color.clear` when name not found
  (= invisible icon).

### 4. Sidebar icon size hardcoded (= commit `0012d857c` part 2)

- My v0.30 rewrite used `LucideIcon(name, size: 14)` (= hardcoded 14 PT).
- Apple HIG Sidebars: "A sidebar's row height, text, and glyph size
  depend on its overall size, which can be small, medium, or large."
- SF Symbols auto-adapt via Label intrinsic sizing, but custom Lucide
  icons need manual `NSTableViewDefaultSizeMode` read.
- macOS stores sidebar icon size preference in
  `NSGlobalDomain NSTableViewDefaultSizeMode` (= 1/2/3 for
  Small/Medium/Large).

## Fix plan (3 commits)

### Commit 1 — `3342850a6` — flip useWorkspace default to true

- **Scope**: 1 file (`LibraryRootView.swift`), 1 variable.
- **Why needed**: trailing buttons visible = WorkspaceView path
  required.
- **Trade-off**: WorkspaceView path is newer (= v0.28 followup),
  more features. Boss can flip back to false via UserDefaults
  if needed.

### Commit 2 — `0f7f28ede` — restore Lucide square-plus + square-arrow-right

- **Scope**: 1 file (`NewLibraryOutlineView.swift`), 2 icon names.
- **Why needed**: match v0.27 commit `bca226704` visual style.
- **No trade-off**: just restore.

### Commit 3 — `0012d857c` — sidebar icons follow system sidebar icon size

- **Scope**: 2 files (`LucideIcon.swift` helper + `NewLibraryOutlineView.swift`
  call sites). New helper `LucideIconSidebar(_:)` reads
  `NSTableViewDefaultSizeMode` and maps to PT size.
- **Why needed**: Apple HIG mandates sidebar icons adapt to system
  preference.

## Acceptance criteria

- [ ] Sidebar zone header trailing area shows 2 Lucide icon buttons:
  新建 (square-plus) + 入驻 (square-arrow-right). NOT SF Symbol.
- [ ] Sidebar tree shows 3 row types all with icons: shelf section
  header (square-dashed-mouse-pointer), book row (book icon),
  reference library (square-library).
- [ ] When user changes Apple 系统设置 → General → Sidebar icon size
  = Small: icons visibly smaller (= 12 PT). Medium: default (= 14 PT).
  Large: visibly larger (= 18 PT).
- [ ] No layout regression: cards in preview pane, sort menu in
  top-right, etc. all still work.
- [ ] All 3 commits have build exit 0 + boss screenshot verified.

## Out of scope (= future tickets, not in this batch)

These were ALSO committed in this session but are separate
functionality (= boss did not directly demand in this turn):
- Sidebar migration to Apple HIG `List(selection:)` (commit `c5ed76169`)
- Card thumbnail + flat flow + adaptive 2-column (commits `e29ea8459`,
  `e38c96ad4`, `d5a02d751`)
- EntityType enum schema (commit `32fafec3c`)
- Type badge full Chinese names (commit `57ac2bfb2`)
- Sort menu (commit `009f5bbd8`)
- Selection highlight (commit `1955fc131`)
- Sidebar padding 18 PT (commit `a8bebb858`)
- Sidebar tree = only categories (commit `1cbbfb249`)
- Folder count badges (commit `09c6521e2`)

These are tracked separately; user explicitly demanded only the
3 fixes in this batch.

## Q34 audit (post-hoc)

This batch is being audited AFTER the commits landed (= Q34 8-step
chain was not followed in real time). Going forward, every new
ticket will walk the full chain (grill → spec → tickets → implement
→ code-review → domain-modeling).
