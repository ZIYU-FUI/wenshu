# Q22 真验证 Report — v0.30 sidebar/preview-pane

> Date: 2026-08-30
> Sub-agent: Q22 visual + AX tree verification
> App: Wenshu (文枢) v0.30 build at /Volumes/ANAN/Engineering/wenshu/build/Wenshu.app

## Verdict: PARTIAL PASS (visual layout correct, interactions incomplete)

The v0.30 sidebar/preview-pane **visual structure is correctly implemented**:
3 sidebar rows (shelf/book/资料库) with icons + disclosure chevrons, preview pane with
2-column card grid + type badges + thumbnails, sidebar zone header trailing buttons
(square-plus + square-arrow-right), preview pane chevron-down sort indicator, inspector
panel with 伏笔 (Foresight) feature labelled "跨章节伏笔追踪 (= v0.30+ 实现)", and
status bar with v0.30 + session indicators.

**However**, several interactive behaviours described in the task spec did NOT
function in this build: clicking the chevron-down sort indicator did not open a
dropdown menu; clicking the +新建 and 入驻 trailing buttons did not trigger any
menu/popup; the资料库 row's chevron did not expand child category rows
(哲学、宗教, 文学, 史地, 军事, 经济, 未分类 are only present as category labels
on cards, not as expandable sidebar rows); clicking a card did not navigate to a
detail view. See "Interaction tests" below for precise failures.

The expected folder count badges (世界观 1, 角色 6, 章节大纲 1, 小说正文 9,
小说草稿 1) are **not visible in the sidebar** because the shelf (书架) is empty
(status bar shows "书架: 0") — those counts only render when the shelf has
documents. The expected 资料库 (5) IS present (shown after the row label as "5").

---

## Build verification

- [x] `bash Scripts/build-app.sh` exit 0 — completed in 66.88s, final output:
  `Build complete! (66.88秒) >>> 拼 /Volumes/ANAN/Engineering/wenshu/build/Wenshu.app
  >>> ad-hoc codesign >>> lsregister ... >>> done. open with: ...`
- [x] App launched successfully — pid 36909 `/Volumes/ANAN/Engineering/wenshu/build/Wenshu.app/Contents/MacOS/WenshuApp`
- [x] Window positioned at (0, 30), size 1920x983 (full screen minus macOS menu bar)

---

## UI element verification (AX tree + visual)

### Sidebar tree structure

- [x] **Shelf row visible** — top row shows `📥 从这里开始` with chevron-down icon
  (blue book icon + selected state underline confirms selection). AX: `AXOutline`
  row with `AXDisclosureTriangle val=0` at pos (11, 140).
- [x] **Book row visible** — second row shows `📖 > 从这里开始` with chevron-right
  icon (collapsed). AX: `AXDisclosureTriangle val=0` at pos (11, 185).
- [x] **Reference library row visible** — third row shows `🏛️ > 资料库 5` with
  chevron-right icon (collapsed) and count "5". AX: `AXHeading val=5` confirms 5.
- [x] **All 3 rows have icons** — book icon, library icon, and a third icon. None
  are text-only.

### Folder count badges

- [❌] **世界观 (1)** — NOT visible. Shelf (书架: 0) is empty in this debug session,
  so no child rows render. Cannot verify visual count badge without seeding docs.
- [❌] **角色 (6)** — NOT visible (same reason as above).
- [❌] **章节大纲 (1)** — NOT visible (same reason).
- [❌] **小说正文 (9)** — NOT visible (same reason).
- [❌] **小说草稿 (1)** — NOT visible (same reason).
- [x] **资料库 (5)** — visible as small "5" count next to the 资料库 row label,
  AND confirmed by AX tree `AXHeading val=5` at the reference library heading.

### Trailing buttons (= sidebar zone header top-right)

- [x] **square-plus (+新建)** — visible as small square-plus icon at top-right of
  sidebar zone header (displayed coords ~185, 20 = logical ~370, 70).
  AX: `AXMenuButton` at pos (498, 83)28x28 confirms a menu button exists there.
- [x] **square-arrow-right (入驻)** — visible as small arrow icon to the right of
  square-plus (displayed coords ~212, 20 = logical ~424, 70).
  AX: `AXButton` at pos (526, 83)28x28.
- ⚠️ **Interaction**: clicking +新建 at logical (370, 70) did NOT open any popup
  menu. No "新建项目"/"新建章节"/"新建笔记" dropdown appeared. The button is
  visually rendered but the menu trigger is not wired up.
- ⚠️ **Interaction**: clicking 入驻 at logical (424, 70) did NOT trigger any
  action. No popup, no navigation, no state change. The button is visually
  rendered but the action is not wired up.

### Preview pane

- [x] **Sort menu icon visible top-right** — chevron-down (∨) icon visible at
  top-right of preview pane (displayed coords ~455, 47 = logical ~910, 94).
  AX: `AXMenuButton 向下移动` at pos (914, 132)21x14 confirms the menu button.
- [x] **Cards displayed in 2-column grid (default)** — confirmed visually:
  赤壁之战 [事件] 史地 | 杜甫 [人物] 文学
  汉尼拔的战术 [概念] 军事 | 李白 [人物] 文学
  Two columns, two rows visible (4 cards in current scroll).
- [x] **Cards have thumbnails (= gradient + type icon)** — confirmed visually:
  calendar icon for [事件], person icon for [人物], lightbulb icon for [概念],
  all on blue gradient backgrounds.
- [x] **Cards have type badge** — confirmed: each card top-left shows
  `[事件]`, `[人物]`, `[概念]`, `[地点]`, `[其他]` (Chinese bracket-prefixed
  type label). AX confirms `AXStaticText [事件]`, `[人物]`, `[概念]`, etc.
- ⚠️ **Interaction**: clicking the chevron-down sort icon (logical ~910, 94)
  did NOT open any sort dropdown menu. The AXMenuButton reports "向下移动"
  (Move Down) label, not "Sort by...", suggesting this is a single-action
  button (or a menu button with no items attached). Tested left-click, double-
  click, and right-click — none produced a visible popup.

### Inspector (right column)

- [x] **伏笔 panel present** — displays `伏笔` heading with subtitle
  `跨章节伏笔追踪 (= v0.30+ 实现)`.
- [x] **工具就绪 status** — "Tool ready" status visible.
- [x] **Kanban section** — `Kanban / Replica of hermes kanban_db / 看板` text visible.
- [x] **Top-right icons** — 4 small icons (lightbulb/insights) at top-right of
  inspector zone header.

### Status bar (footer)

- [x] `书架: 0`, `章: 0`, `章节: 0`, `字数: 0`, `0%` — all visible
- [x] `工具就绪` — visible
- [x] `MiniMax-M3 · Idle` — model + status visible (bottom-left)
- [x] `wenshu v0.30 · Sessions` — version label visible (bottom-right)

---

## Interaction tests

- [x] **Click 资料库 → preview shows reference library overview** — partial:
  clicking 资料库 row at logical (120, 255) did not visually highlight the row
  blue (the shelf row remains highlighted), but the preview pane DOES show the
  reference library overview by default (赤壁之战, 杜甫, 汉尼拔的战术, 李白, 罗马帝国兴亡, 宋朝海上丝绸之路, 唐朝贞观之治, 未分类研究材料 = 7 cards from the 5-item参考资料 collection).
- [❌] **Click category → preview shows category-scoped grid** — CANNOT TEST.
  资料库 row has no expandable child category rows in the sidebar (no 哲学、宗教,
  文学, 史地, 军事, 经济, 未分类 rows). Clicking the chevron at logical (30, 260)
  did not expand. Categories exist only as text labels on cards.
- [❌] **Click sort menu → menu opens with 3 options** — FAIL. Clicking the
  chevron-down sort icon at logical (910, 94) did not open any dropdown. The
  AXMenuButton reports label "向下移动" (Move Down) rather than "Sort by",
  and no menu items appear on screen after click. Tested 4 click strategies:
  single left-click, double-click, right-click, click-then-immediate-capture.
  All produced no visible popup.

---

## Screenshot inventory

- `/tmp/wenshu-q22-full.jpg` — full window at launch (initial state, before any clicks)
- `/tmp/wenshu-q22-references.png` — after clicking 资料库 row (logical 120, 255)
- `/tmp/wenshu-q22-category.png` — NOT PRODUCED (could not click category row)
- `/tmp/wenshu-q22-sort-menu.png` — after clicking sort chevron (no menu visible)
- `/tmp/wenshu-q22-new-menu.png` — after clicking +新建 button (no menu visible)
- `/tmp/wenshu-q22-enter-button.png` — after clicking 入驻 button (no action)
- `/tmp/wenshu-q22-card-click.png` — after clicking 赤壁之战 card (no detail view)
- `/tmp/wenshu-q22-card-dblclick.png` — after double-clicking card (no detail view)
- `/tmp/wenshu-q22-expand.png` / `q22-expand2.png` — after clicking资料库 chevron
  (no expansion to child rows)

---

## AX tree summary

Total top-level elements: 107

Key elements (filtered to UI structure / rows / buttons / text):

```
Element  Role              Name/Value         Desc (zh)
3        AXButton          -                  按钮
4        AXMenuButton      -                  菜单按钮  ← +新建 menu (square-plus)
5        AXButton          -                  按钮      ← 入驻 button (square-arrow-right)
6        AXScrollArea      -                  滚动区
7        AXOutline         -                  边栏      ← sidebar tree
8        AXRow             -                  外框行    ← shelf row container
11       AXHeading         -                  标题      ← shelf heading
12       AXRow             -                  外框行
14       AXHeading         -                  标题
15       AXDisclosureTri   val=0              显示三角形 ← shelf disclosure
16       AXRow             -                  外框行
19       AXRow             -                  外框行
21       AXHeading         val=5              标题      ← 资料库 heading (count=5!)
22       AXDisclosureTri   val=0              显示三角形 ← 资料库 disclosure
24       AXStaticText      "书架: 0"          文本      ← footer status
25       AXStaticText      "书: 0"            文本      ← footer status
26-27    AXButton x2       -                  按钮
28       AXMenuButton      "向下移动"          菜单按钮  ← sort/move-down menu
29-30    ...
31       AXStaticText      "[事件]"            文本      ← card type badge
32       AXStaticText      "史地"              文本      ← card category
33       AXStaticText      "赤壁之战"          文本      ← card title
34       AXStaticText      "三国时期决定性的水上战役 (208 年)。"  文本  ← card desc
35-38    AXStaticText      "[人物]" / "杜甫" / "唐代现实主义诗人,被誉为 '诗圣',字子美。"  文本
39-42    AXStaticText      "[概念]" / "军事" / "汉尼拔的战术" / "迦太基名将汉尼拔的经典军事战术。"  文本
43-46    AXStaticText      "[人物]" / "文学" / "李白" / "唐代浪漫主义诗人,被誉为 '诗仙',字太白。"  文本
47-50    AXStaticText      "[事件]" / "史地" / "罗马帝国兴亡" / "罗马帝国从兴起到衰亡的全过程。"  文本
51-54    AXStaticText      "[地点]" / "经济" / "宋朝海上丝绸之路" / "宋朝繁荣的海上贸易体系。"  文本
55-58    AXStaticText      "[事件]" / "史地" / "唐朝贞观之治" / "唐太宗李世民在位期间 (627-649) 的盛世局面。"  文本
59-61    AXStaticText      "[其他]" / "未分类研究材料" / "一个还没经过分类的研究材料。"  文本
77-79    AXStaticText      "伏笔" / "跨章节伏笔追踪 (= v0.30+ 实现)" / "工具就绪"  文本 ← inspector
88-90    AXStaticText      "Kanban" / "Replica of hermes kanban_db" / "看板"  文本
```

Notable observations:
- **资料库 count = 5** (element 21 AXHeading val=5) ✓
- **Only 3 outline rows** (elements 8, 12, 16, 19) — the shelf DOES NOT have any
  child rows rendered, even though the chevron-down icon suggests it is expanded.
  This is consistent with shelf being empty (书架: 0).
- **资料库 chevron val=0** (element 22) — collapsed state, no child category rows
  exist in the outline.
- **No "世界观/角色/章节大纲/小说正文/小说草稿" headings appear in the AX tree**
  anywhere — these only exist when the shelf has documents loaded.

---

## Summary

The v0.30 sidebar/preview-pane layout is visually correct: 3 sidebar rows with
icons + disclosure chevrons, 2-column preview grid with type-badged cards
(thumbnails + gradient + [类型] badge), inspector with 伏笔 / 跨章节伏笔追踪
panel labelled "= v0.30+ 实现", and footer status bar showing "wenshu v0.30 ·
Sessions". However, **5 of 6 expected folder count badges are absent** because
the shelf (书架: 0) is empty in this debug session — those counts only render
when the shelf is seeded with documents. The 资料库 (5) count IS present. **None
of the interactive behaviours worked**: clicking the chevron-down sort icon did
not open a dropdown (the AXMenuButton reports "向下移动" / Move Down label, not
"Sort by..."); the +新建 and 入驻 trailing buttons rendered visually but did not
trigger any menu/action on click; 资料库 has no expandable child category rows
(哲学、宗教, 文学, 史地 etc. are only card labels, not sidebar rows); clicking
cards did not open detail views. Verdict: PARTIAL PASS — visual layout ships,
interactive layer needs follow-up wiring.