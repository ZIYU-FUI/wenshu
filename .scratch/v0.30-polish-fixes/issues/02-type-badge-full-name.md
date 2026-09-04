# 02 — type badge = full Chinese name

**What to build:**

Boss 2026-08-30 OOB '别用缩写，就是那个念，地，人，全称不也就才两个字，
最多四个字，够显示' = type badge should be full Chinese name, NOT
1-char abbreviation. Pre-fix: type badge = `[人]` / `[地]` / `[念]`.

Fix: changed `EntityType.shortName` (1 char) → use `EntityType.displayName`
(2 chars = 人物 / 地点 / 事件 / 概念).

**Blocked by:** None (= can start independently).

**Status:** ready-for-agent (= already committed as `57ac2bfb2`, this
ticket documents the commit after-the-fact per Q5.6 partial commit 接管
规范).

## Fix specification

### File: `Sources/WenshuApp/Domain/EntityType.swift`

- Kept `shortName` (= 1 char) as `ultraShortName` per boss 8/30 caveat
  ('最多四个字' = up to 4 chars OK; the 1-char shortName was extracted to a
  new field marked NOT the default)
- Updated default `displayName` for each case:
  - `.character` → "人物"
  - `.location` → "地点"
  - `.event` → "事件"
  - `.concept` → "概念"
  - `.artifact` → "物品"
  - `.organization` → "组织"
  - `.era` → "朝代"
  - `.work` → "作品"
  - `.other` → "其他"

### Modified: `Sources/WenshuApp/Views/Workspace/EntityPreviewPane.swift`

- Card renders badge using `entityType.displayName` (= 2 chars, not 1 char)
- `Label { Text("[\\(\entity.entityType.displayName)]") }` instead of
  `Label { Text("[\\(\entity.entityType.shortName)]") }`

## Acceptance

- [x] Type badge shows full Chinese name (= 人物, 地点, etc.)
- [x] ultraShortName (= 1 char) preserved for future tight-UI use cases
- [x] Build exit 0
- [x] Screenshot verified: badges show [人物] / [地点] etc. (NOT [人] / [地])

## Out-of-scope

- Custom badge colors (= all use `.tint` currently; per-type tint could
  be added in v0.31+ if boss requests)
