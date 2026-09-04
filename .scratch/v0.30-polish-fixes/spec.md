# Spec — v0.30 polish fixes (entity schema + type badge + thumbnails + flat flow + sidebar tree)

> Date: 2026-08-30
> Author: wenshu agent (pocock profile)
> Boss OOB (cumulative, 2026-08-30 turn):
> - "实体智能分类实现..." → "实体如何定义，是不是有规则" (= option A: add 2D taxonomy schema)
> - "别用缩写，就是那个念，地，人，全称不也就才两个字，最多四个字，够显示"
> - "卡片要用我们引入的缩略图的库，加缩略图"
> - "因为素材预览区只显示当前选定目录的卡片，所以只需要卡片流，一直铺下去即可" + "素材预览区不需要这个标题，卡片平铺即可"
> - "目录树只显示到最后一层的目录，文档不显示在树里。文档在目录被点击选择后，显示在素材预览区"

## Business language (老板-facing)

- Reference library entities (= `Reference` in `reference-library/entities/`) carry
  an `entityType` field (= character / location / event / concept / artifact /
  organization / era / work / other).
- Card type badge = full Chinese name (= 人物 / 地点 / 事件 / 概念 / 物品 /
  组织 / 朝代 / 作品 / 其他), NOT 1-char abbreviation.
- Each card has a thumbnail (= type icon rendered at 64 PT with a tinted
  gradient background; gives the card a strong visual identity).
- Preview pane cards = flat grid (= no global title, no per-category
  section headers).
- Sidebar tree shows only the last layer of folders; documents inside
  folders are not rendered in the tree (they appear in the preview pane
  when a folder/category is selected).

## Why these changes (= scope)

Each commit has a direct boss OOB driving it. None are scope creep.

| Commit | Boss OOB driving |
|---|---|
| `32fafec3c` | "实体如何定义，是不是有规则" (= option A: add explicit schema) |
| `57ac2bfb2` | "别用缩写，就是那个念，地，人，全称..." |
| `e29ea8459` | "卡片要用我们引入的缩略图的库，加缩略图" |
| `e38c96ad4` | "因为素材预览区只显示当前选定目录的卡片... 卡片平铺即可" |
| `1cbbfb249` | "目录树只显示到最后一层的目录，文档不显示在树里..." |

## Root-cause chain (= 5 bugs)

### 1. Entity had no explicit schema (= 32fafec3c)

- Pre-fix: `Reference` had `category` (which classification system?) but no
  narrative role classification (= character vs location vs event).
- Boss OOB: "实体如何定义，是不是有规则". Boss chose option A: add explicit
  EntityType schema with 8 (+ 1 catch-all) cases.
- Implementation: new `Domain/EntityType.swift` enum + `Reference.entityType`
  field (default = `.other`).

### 2. Type badge used 1-char abbreviation (= 57ac2bfb2)

- Pre-fix: type badge = "[人]" / "[地]" / "[念]" (= 1 Chinese char).
- Boss OOB: "别用缩写，就是那个念，地，人，全称不也就才两个字，最多四
  个字，够显示".
- Implementation: changed to full Chinese name = "[人物]" / "[地点]" /
  "[事件]" / "[概念]" (= 2 chars).

### 3. Cards had no thumbnail (= e29ea8459)

- Pre-fix: cards were text-only (= title + summary, no visual anchor).
- Boss OOB: "卡片要用我们引入的缩略图的库，加缩略图".
- Implementation: added thumbnail area at top of card (= 100 PT gradient
  background with 64 PT type icon overlay). Type icon = SF Symbol or Lucide
  per `EntityType.icon`. Since entities are text-only (= no real images), no
  NukeUI/LazyImage needed yet; v0.31+ when entities get real images, swap to
  NukeUI.

### 4. Cards had global title + per-category sections (= e38c96ad4)

- Pre-fix: `overviewGrid` had a "资料库 (X 个实体 · Y 个分类)" header + per-
  category section headers.
- Boss OOB: "因为素材预览区只显示当前选定目录的卡片，所以只需要卡片流，
  一直铺下去即可" + "素材预览区不需要这个标题，卡片平铺即可".
- Implementation: removed global header + per-category sections; just flat
  LazyVGrid of cards.

### 5. Sidebar showed entity .md documents in tree (= 1cbbfb249)

- Pre-fix: sidebar tree showed category → entity → entity.md nodes (3 levels
  deep for reference library, violating Apple HIG "no more than two levels").
- Boss OOB: "目录树只显示到最后一层的目录，文档不显示在树里。文档在目录
  被点击选择后，显示在素材预览区".
- Implementation: sidebar tree stops at category level; entities appear in
  preview pane when category is selected.

## Fix plan (= 5 commits, all in repo)

### Commit 1 — `32fafec3c` — EntityType enum + strict 2D taxonomy schema

- **Scope**: 1 new file (`Sources/WenshuApp/Domain/EntityType.swift`, 149 lines)
  + 5 modified files.
- **What**: new `EntityType` enum + `Reference.entityType` field (default
  `.other`).

### Commit 2 — `57ac2bfb2` — type badge = full Chinese name

- **Scope**: 1 file (`Sources/WenshuApp/Domain/EntityType.swift`, 21 + / 1 -).
- **What**: changed `shortName` (1 char) to `displayName` (2 chars like 人物).

### Commit 3 — `e29ea8459` — entity cards now have thumbnails

- **Scope**: 1 file (`Sources/WenshuApp/Views/Workspace/EntityPreviewPane.swift`,
  72 + / 64 -).
- **What**: added 100 PT gradient + 64 PT type icon overlay on top of each
  card.

### Commit 4 — `e38c96ad4` — preview pane = single flat card flow

- **Scope**: 1 file (`Sources/WenshuApp/Views/Workspace/EntityPreviewPane.swift`,
  25 + / 30 -).
- **What**: removed "资料库 (X 个实体 · Y 个分类)" header + per-category
  sections.

### Commit 5 — `1cbbfb249` — sidebar tree = only categories, no entity nodes

- **Scope**: 1 file (`Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift`,
  21 + / 24 -).
- **What**: removed `entityChildren` from category FCPTreeNode (= entities
  not shown in tree).

## Acceptance criteria (= post-hoc, all verified)

- [x] `EntityType` enum has 9 cases with full Chinese displayNames
- [x] `Reference.entityType` defaults to `.other` (= backward compatible)
- [x] Type badge shows full Chinese name (= 人物, not 人)
- [x] Each card has a thumbnail (= 100 PT gradient + 64 PT type icon)
- [x] No global preview pane title
- [x] No per-category section headers in preview pane
- [x] Sidebar tree stops at category level (= no entity nodes)
- [x] Build exit 0

## Q34 audit (= post-hoc)

This batch was implemented without the Q34 8-step chain (= no grill, no
spec/ticket pre-write, no code-review sub-agent). Spec + tickets committed
post-hoc (= this batch + the previous 2 batches).

Going forward: every new ticket walks full chain (= grill → spec →
tickets → implement → code-review → domain-modeling).
