# v0.30 boss 8/31 OOB: sort button icon for preview pane top bar

Boss OOB (2026-08-31):

> "排序功能的 icon 没有实现, 其实就是和新建一样, 加在预览区的
> 顶栏里, 不是原创的逻辑了, 老代码学一下怎么实现的就好了. 你别接
> 到需求上来就硬写, 你按八步方法论, 方法里一定有明确要求, 同时加
> 载 ponytail 技能, 像大神一样思考"

## Context (= problem statement)

1. Sort functionality (= preview pane sorts entity cards by the current
   sort order = pinyin first letter / created at / modified at) already
   EXISTS in code. EntitySortOrder enum declared in PreviewPane.swift
   L108, `sortEntities(_:by:)` + `sortBookDocs(_:by:)` functions exist,
   `@State previewSortOrder` is held in WorkspaceView L56, PreviewPane
   observes via `@Binding previewSortOrder` (PreviewPane.swift L222).
2. UI affordance is MISSING. The sort button should be a clickable icon
   in the preview pane's top bar (trailing slot of ZoneContentView
   region tab bar), matching the sidebar's 新建 + 入驻 pattern
   (= NewButtonWithHover in NewLibraryOutlineView.zoneHeaderButtons).
3. **Root cause** (= discovered during debugging): PaneTabBar.body's
   inner HStack (Sources/WenshuApp/UI/PaneTabBar.swift L130-152) had
   only intrinsic width (= sum of children). The Spacer(minLength: 0)
   between tabs and `trailing()` had zero horizontal space to expand
   into (= Spacer collapsed), so trailing button rendered RIGHT AFTER
   the last tab (compressed against the tab bar's left side). The fix
   was one line: `.frame(maxWidth: .infinity)` on the inner HStack to
   give the Spacer something to fill.

## Scope (= what changes)

### Files touched
- `Sources/WenshuApp/UI/PaneTabBar.swift` — add `.frame(maxWidth: .infinity)`
  to the inner HStack in `PaneTabBar.body` (= lets trailing slot
  consume right-side space).
- `Sources/WenshuApp/Views/Workspace/WorkspaceView.swift` —
  - `PreviewSortMenuButton` (= sort button in preview pane trailing):
    replaced Menu + .menuStyle(.button) with plain Button + cycle-through
    sort order pattern (= mirrors NewButtonWithHover's plain Button +
    LucideIcon + .frame(width: 28, height: 28) + .onHover + .background
    tint pattern which DOES render correctly).
  - `EditorExpandShrinkTrailingButton` (= expand/shrink button in editor
    pane trailing): replaced Color.clear + .overlay(alignment: .center)
    icon with NewButtonWithHover-style plain Button + LucideIcon
    (= makes the button fully visible + adds hover tint).

### Files NOT touched
- `Sources/WenshuApp/Views/Dynamic/ZoneContentView.swift` — already had
  the `trailingButton: AnyView?` parameter and `PaneTabBar.trailing`
  closure wiring. The bug was downstream in PaneTabBar.body.
- `Sources/WenshuApp/UI/RegionTabBar.swift` — already had the
  `.frame(maxWidth: .infinity, alignment: .leading)` fix (per commit
  `35b373c8e`). The outer HStack was correctly full-width; the issue
  was the inner HStack in PaneTabBar.body not being full-width.

## Acceptance criteria

1. ✅ Preview pane top bar shows a sort icon at the RIGHT edge (= pushed
   there by Spacer consuming extra horizontal space).
2. ✅ Click on sort icon cycles through 3 sort orders:
   pinyinFirstLetter → createdAt → modifiedAt → pinyinFirstLetter.
3. ✅ Sort order change re-renders preview pane cards in new order
   (= `sortEntities` / `sortBookDocs` already consumed previewSortOrder).
4. ✅ Hover on sort icon shows accent color tint (= matches sidebar's
   NewButtonWithHover pattern).
5. ✅ Editor pane top bar shows expand/shrink icon at the right edge.
6. ✅ Build is clean (`swift build` exit 0).
7. ✅ Sort icon uses Lucide `list-ordered` (= matches Boss 8/30 OOB
   "list-ordered icon" — EntitySortOrder.menuIcon).

## Implementation approach (= Ponytail ladder applied)

- **Rung 1: Does this need to exist?** YES — boss explicit OOB.
- **Rung 2: Already in this codebase?** YES — `EntitySortOrder` enum +
  `sortEntities` + `sortBookDocs` + `@State previewSortOrder` + the
  trailing slot in `PaneTabBar` (`if !(Trailing.self == EmptyView.self) {
  Spacer(minLength: 0); trailing() }`). Boss said "老代码学一下怎么
  实现的就好了" — the impl existed, only the rendering was broken.
- **Rung 3: Stdlib does it?** N/A.
- **Rung 4: Native platform feature covers it?** SwiftUI Menu + Button
  are native. Both were tried; neither rendered until the layout fix.
- **Rung 5: Already-installed dependency solves it?** N/A — all SwiftUI.
- **Rung 6: Can it be one line?** The PaneTabBar fix IS one line
  (`.frame(maxWidth: .infinity)`). The PreviewSortMenuButton rewrite is
  ~20 lines (= replacing Menu + .menuStyle(.button) + .menuIndicator
  + .help + complex label HStack with simple Button + cycle switch +
  LucideIcon + .frame(width: 28, height: 28) + .onHover + .background).

## Hard rules honored

- AGENTS.md v0.07.4 §5-6 — English-only in code comments + commit
  messages + docs. Sort button's rawValue is `"首字母" / "创建时间 /
  "修改时间"` (Chinese per §6 UI string rule, Chinese-only in user-
  facing strings).
- AGENTS.md §11.1 third-party library policy — no new libraries added.
  All changes use Apple SwiftUI native (`Menu`, `Button`, `LucideIcon`,
  `RoundedRectangle`, etc.) which are already in the project.
- Q5.2 do-not-amend — single commit on top of `9d1f9bf82`. No amend.
- Q5.4 Q5.2 forward-fix — sub-agent dual-axis review after this commit
  (forward-fix any findings in separate commit).
- Q29 invariant — `.scratch/v0.30-preview-sort-button/spec.md` is
  committed in the same commit as the source changes (= `git add`
  includes both).

## Bug-pattern lessons (= write to SKILL.md after this commit)

1. **SwiftUI Spacer in conditional trailing slot needs parent full-width**:
   `Spacer(minLength: 0)` only consumes available horizontal space. If
   the parent HStack is only intrinsic width (= no slack), Spacer
   collapses to 0 and trailing button renders immediately after the
   preceding tab. Fix: `.frame(maxWidth: .infinity)` on the parent
   HStack (= gives Spacer real space).
2. **AnyView wrapping erases intrinsic size for Menu view**:
   `Menu { ... } label: { ... }` with `.menuStyle(.button)` doesn't
   render its label inside an `AnyView` wrapper (= common pattern in
   ZoneContentView's trailingButton slot). Workaround: use plain
   `Button + LucideIcon + .frame(width: 28, height: 28)` instead.
3. **Color.clear as Button label base = invisible hit area**:
   `Button { Color.clear.frame(width: w, height: h).overlay( { icon }) }`
   renders the icon overlay but the background is transparent (= no
   hover tint visible). Workaround: use Button label = icon directly +
   add `.background(Color.clear/Color.accentColor.opacity(0.12))` for
   hover tint.