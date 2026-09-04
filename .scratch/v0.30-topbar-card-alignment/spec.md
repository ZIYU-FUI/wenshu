# v0.30 boss 8/31 OOB: top bar unification + card style alignment + sort icon fix

Boss OOB (2026-08-31, after Q34 cycle for sort button):

> "截图上没有, 同时你把动态的 teb 图标改成居中了.
> 顶栏不是一个统一组件吗? 为啥每个区域都不一样.
>
> 资源库的卡片, 和书里的卡片的样式也没有拉齐啊, 你今天干的活多次
> 都属于, 你说你干完了, 结果都没实现."

## Context (= the Q34 chain broke: 4 issues still open after previous fix)

The previous sort-button commit (= adcab7c1b) claimed the PaneTabBar
inner HStack `.frame(maxWidth: .infinity)` fix made the sort icon render.
Boss's screenshot proves it didn't. **My previous commit failed visually**
even though it compiled + passed dual-axis review. Lesson per Q5.5: never
declare done without a screenshot-confirmed match. Adding a hard rule:
**no Q34 commit without Q22 screenshot diff proof in the commit body.**

## Issues (= what boss is asking)

### Issue 1: Sort icon does NOT render in preview pane top bar

**Symptom**: preview pane top bar shows only 2 tabs (book-open-check +
waypoints), right side is blank where sort icon should be.

**Visual confirmation**: latest screenshot (= 1456x983 capture,
.adcab7c1b build + 064e381ce forward-fix) shows preview pane top bar
truncated to left side. Sort icon (= list-ordered icon at right edge)
is MISSING.

**Possible root causes**:
1. The `.frame(maxWidth: .infinity)` fix to inner HStack didn't actually
   take effect (= build cache stale, or another layout layer below
   overrides it).
2. The `Spacer(minLength: 0) + trailing()` pattern in PaneTabBar.body
   is being eaten by a deeper HStack that's only intrinsic width.
3. AnyView wrapping at ZoneContentTabBar's `trailing: { ... trailingButton
   }` closure erases intrinsic size to zero for `PreviewSortMenuButton`.
4. The trailing slot path is conditionally skipped by `Trailing.self ==
   EmptyView.self` check (but Trailing is `_ConditionalContent<AnyView,
   EmptyView>`, NOT `EmptyView`, so the check should pass).

**To verify**, write a debug marker (= Color.red frame) on the
PreviewSortMenuButton label HStack + .border(.red) on the entire
trailing button. Capture screenshot. Confirm position + visibility.

### Issue 2: Dynamic zone tab icon not centered

**Symptom**: in DynamicZoneTabBar (= Kanban zone), the 2 tabs (kanban +
list-tree icons for "看板" / "任务" / "进度" tabs) are LEFT-aligned in
their hot area instead of CENTERED.

**Root cause**: PaneIconTab's `.overlay(alignment: .center)` SHOULD
center the icon inside the 28 PT hot area. But the screenshot shows
tabs at the LEFT edge of the dynamic zone top bar. This suggests
either:
1. PaneIconTab hot area isn't being centered in the parent HStack (= the
   tabs sit at the beginning of the available space, no Spacer to push
   them center).
2. OR the icon overlay IS centered but the visible icon offset
   appears off due to a 28 PT hot area > 18 PT icon difference
   (= icon should be at center 5 PT in from each edge, but may
   visually appear left-of-center due to design).

**To verify**, add a `.background(.blue.opacity(0.2))` to the
PaneIconTab hot area + measure where the icon sits within it.

**Fix candidates**:
- Add `.frame(maxWidth: .infinity)` to each PaneIconTab (= makes each
  tab fill its assigned space, icon naturally centers).
- OR use HStack with Spacers between tabs (= pushes tabs apart, but
  won't center unless wrap with HStack { Spacer(); tabs; Spacer() }).
- OR change DynamicZoneTabBar's tab layout to VStack/HStack with
  center alignment instead of left-aligned HStack.

### Issue 3: Top bars "not unified" across zones

**Boss observation**: each zone's top bar LOOKS different even though
all 3 (`ZoneContentTabBar`, `ChatZoneTopChrome`, `DynamicZoneTabBar`)
delegate to `PaneTabBar`.

**Actual differences** (= from screenshot diff):
- Sidebar top bar: book-open icon, no label text visible (just
  `.help("书架")` tooltip), no underline.
- Preview top bar: book-open-check + waypoints icons, no label text,
  underline visible (= selected "预览" tab).
- Editor top bar: book-open-text + puzzle + link icons, no label text,
  underline visible.
- Tools top bar: git-fork + square-dashed icons, no label text.
- Chat top bar: bot icon + (right) inbox icon, no label text, no
  underline (= chat tab is always selected).
- Dynamic top bar: kanban + list-tree icons, no label text, underline
  visible.

**All 6 zones DO use PaneTabBar** (verified via grep). So the
unification is correct at the component level.

**Actual visual inconsistency**:
- Chat zone trailing button position is different (= `.padding(.trailing,
  DesignTokens.chromePaddingTrailing)` added in ChatZoneTopChrome
  but NOT in ZoneContentTabBar / DynamicZoneTabBar).
- No labels shown under icons in any zone (= boss might be expecting
  labels).
- Some zones have trailing button, others don't (= editor has expand,
  preview has sort, sidebar has new+import, chat has archive, tools /
  dynamic have nothing).

**Boss's "为啥每个区域都不一样" likely refers to**: the absence of
trailing button icons in some zones (visual asymmetry = some zones
have icon at right, others have nothing). And/or the position of
trailing button (= center-trailing vs edge-trailing).

**Fix**: ensure ALL zones have either a trailing icon OR no trailing
slot (= consistent visual pattern). Decide: should preview's sort icon,
editor's expand icon, chat's archive icon, sidebar's new+import icons
all live at the same x-position (= right edge, with consistent padding)?

### Issue 4: Card style inconsistent (resource library vs book folder)

**Boss observation**: 资料库卡片 (Reference cards via EntityCard)
and 书里卡片 (Book folder cards via BookDocCard) don't look the same.

**Actual differences** (verified via screenshot):
- EntityCard: iconSize = **64 PT** (= larger)
- BookDocCard: iconSize = **56 PT** (= smaller)
- Both use the same `Card` struct (= unified per boss 8/31 OOB
  "用书里的同一个组件, 没有必要实现两回一样的东西").
- Both have thumbnail (icon + accent gradient), title, summary,
  modifiedAt chip.

**Why different sizes** (per current code at PreviewPane.swift L707 vs
L860):
- EntityCard passes `iconSize: 64`
- BookDocCard passes `iconSize: 56`

The difference is **arbitrary** (= no documented reason for 64 vs 56).
Boss wants them equal.

**Fix**: standardize to a single icon size (= recommend **64 PT**
matching entity cards which are the canonical reference for
"reference library" content).

## Acceptance criteria

### Issue 1: Sort icon renders
1. Screenshot of preview pane top bar shows list-ordered icon at
   right edge (clearly visible, not collapsed).
2. Click on sort icon cycles through 3 sort orders (= preserved from
   previous commit adcab7c1b).
3. Sort change re-renders preview pane cards in new order.

### Issue 2: Dynamic tab icon centered
4. Dynamic zone top bar shows 2 tabs (kanban + list-tree for "看板" +
   "任务" / "进度") with icons CENTERED in their 28 PT hot areas.
5. Other zones' icons remain at the same positions (= no regression).

### Issue 3: Top bar unification
6. All 6 zones' top bars have **identical** visual structure:
   - Same height (30 PT)
   - Same background (.regularMaterial)
   - Same 1 PT bottom separator
   - Same left padding (18 PT)
   - Same right padding (18 PT) — including trailing button
   - Same tab icon size (18 PT) inside 28 PT hot area
   - Same selected-state underline (1 PT capsule shape)
7. Trailing buttons (= where present) sit at consistent right-edge
   position (= 18 PT from right edge) with same icon size (18 PT).

### Issue 4: Card style alignment
8. All preview cards (entity cards + book doc cards) have identical
   icon size (recommend **64 PT**).
9. Same thumbnail height (100 PT), same gradient, same corner radius.
10. Same metadata layout (typeLabel + date chip at top, title + summary
    at bottom).

## Implementation approach (= Ponytail ladder applied)

- **Rung 1 (YAGNI)**: 4 issues, but they're all **consistency fixes**
  on existing components. No new abstraction. No new dependencies. No
  new third-party code.
- **Rung 2 (already in this codebase)**: All the component code
  (PaneIconTab, PaneTabBar, Card, EntityCard, BookDocCard,
  ZoneContentTabBar, ChatZoneTopChrome, DynamicZoneTabBar) already
  exists. Issue 1-4 are about CORRECTLY USING what exists (= not
  re-implementing).
- **Rung 3-5 (stdlib/native/deps)**: N/A — pure Apple SwiftUI.
- **Rung 6 (one-liner)**: each fix is < 5 lines.

## Hard rules honored

- AGENTS.md v0.07.4 §5-6: English-only in code comments + commit
  messages + docs. All UI strings stay Chinese per §6 carve-out.
- AGENTS.md §11.1: no new third-party libraries. Apple SwiftUI native.
- Q5.4 do-not-amend: single commit per fix; forward-fix any review
  findings in new commits.
- Q29 invariant: `.scratch/v0.30-topbar-card-alignment/spec.md` is
  committed alongside source changes.
- Q5.5 (new): no Q34 commit without Q22 screenshot-diff proof in
  commit body (= boss caught us claiming "done" when not done).

## Bug-pattern lessons (= write to SKILL.md after this commit)

1. **Always verify with screenshot before claiming done.** Previous
   adcab7c1b claim "preview pane trailing button visible" was based
   on `swift build` exit 0 + grep + reasoning about layout — NOT
   on actual screenshot capture. Boss's screenshot proved otherwise.
   Fix: Q22 真验证 requires PNG screenshot at exact pixel area,
   not text "looks good" claim.
2. **Multiple-component consistency requires explicit visual diff**:
   boss can see 6 zones' top bars at a glance + notice asymmetry
   (= some have trailing, some don't). Code-level reasoning
   ("all 3 delegate to PaneTabBar") doesn't catch visual
   asymmetry. Fix: visual diff (= 6 screenshots side-by-side) is
   the source of truth for "unified" claims.
4. **Card icon size inconsistency is a smell**: 64 vs 56 PT in two
   adjacent CardContent adapters (= EntityCard vs BookDocCard) =
   no documented reason. Boss noticed. Fix: standardize to a
   single value (= 64 PT, the entity-card canonical).
5. **Tab icon centering**: PaneIconTab's `.overlay(alignment: .center)`
   centers the icon INSIDE the 28 PT hot area, but the hot area
   itself sits at the left of the parent HStack. Center alignment
   of the icon doesn't help if the hot area is at the left edge.
   Fix: HStack parent needs center alignment OR each tab needs
   `.frame(maxWidth: .infinity)` to fill its assigned space
   (= icon naturally centers within).