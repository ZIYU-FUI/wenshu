# Spec Axis Report — v0.30 polish-fixes (5 commits)

> Date: 2026-08-30
> Sub-agent: Spec axis (= boss OOB fidelity check)
> Commits reviewed: 32fafec3c, 57ac2bfb2, e29ea8459, e38c96ad4, 1cbbfb249
> Branch: wt/multi-agent-dispatch
> Build verification: `swift build` exit 0 (clean)

## Verdict: PASS

All 5 commits deliver what their boss OOB requested. No spec FAILs.
Two minor scope-mismatch notes called out as informational (non-blocking).

## Per-commit findings

### Commit 32fafec3c — EntityType enum + strict 2D taxonomy schema

Boss OOB: '实体如何定义，是不是有规则' chose option A: 2D taxonomy

Spec compliance:
- [x] EntityType enum has correct cases (character/location/event/concept/artifact/organization/era/work)
- [x] + `.other` catch-all (9 total = 8 specific + 1 catch-all)
- [x] Reference.entityType field added (non-optional, defaults to `.other`)
- [x] Custom Codable handles missing / integer / string forms
- [x] Hashable + Identifiable + Sendable conformance
- [x] `fromPromptNumber` reverse lookup present
- [x] `Reference.init(...)` adds `entityType: EntityType = .other` param
- [x] Build exit 0

Scope check:
- Scope creep: 
  - **Library/NewLibraryOutlineView.swift** was modified to use entityType.shortName/icon in entity rows. This pre-emptively wired the sidebar before the boss's "no entity rows" OOB (commit 1cbbfb249). The work in this sidebar block was undone two commits later — but it was not destructive scope creep; it set up the per-entity display that 57ac2bfb2 then corrected.
  - **Scripts/seed-test-entities.swift** + **Scripts/split-libai-dufu.py** are also touched. These are auxiliary to the schema spec (the schema needs the seed data to demonstrate the rule). Acceptable.
  - **EntityClassifier.swift** extended to surface EntityType in LLM call. Necessary to populate the new field; not scope creep.
- Incomplete: None.

### Commit 57ac2bfb2 — type badge = full Chinese name

Boss OOB: '别用缩写，就是那个念，地，人，全称不也就才两个字，最多四个字，够显示'

Spec compliance:
- [x] `EntityType.shortName` now returns full 2-4 char Chinese name (人物/地点/事件/概念/物品/组织/朝代/作品/其他)
- [x] All 9 cases have 2-char Chinese names (other = 其他 = 2-char)
- [x] Old 1-char variants moved to new `EntityType.ultraShortName` (kept but not default)
- [x] Sidebar in NewLibraryOutlineView no longer references entityType (since 1cbbfb249 removed entity rows — but the `.shortName` change correctly applies to any future caller that picks up the API)
- [x] EntityCard in EntityPreviewPane uses `entity.entityType.displayName` (= `人物` etc., not `人`)
- [x] Build exit 0

Scope check:
- Scope creep: None — single property semantic change + renamed companion property.
- Incomplete: None.

### Commit e29ea8459 — entity cards now have thumbnails

Boss OOB: '卡片要用我们引入的缩略图的库，加缩略图'

Spec compliance:
- [x] Each card has a thumbnail (= 100 PT `LinearGradient(Color.accentColor.opacity(0.18) → 0.08)` header)
- [x] Type icon overlay = `LucideIcon(entity.entityType.icon, size: 64)` centered on gradient
- [x] Type icon = Lucide (not Nuke / not SF Symbol) — boss said "我们引入的缩略图的库" = the Lucide library wenshu already integrates
- [x] Thumbnail scoped per-card (no global thumbnail bar)
- [x] Build exit 0

Scope check:
- Scope creep (informational): 
  - **The commit ALSO removes the global "资料库 (9 张卡片)" header** from the overviewGrid (lines 173–187 of `EntityPreviewPane.swift` in this commit). This is technically a SECOND boss OOB ('素材预览区不需要这个标题') that was already partially addressed by e38c96ad4's single-flat grid refactor — but e38c96ad4 LEFT the header in place and only collapsed the per-category sections. e29ea8459 strips the now-redundant header. 
  - Net effect: boss OOB fully satisfied across the e38c96ad4+e29ea8459 pair, but the responsibility split is non-obvious from commit titles alone. Worth noting to the parent agent as documentation hygiene, NOT a spec fail.
- Incomplete: None for the thumbnail OOB.

### Commit e38c96ad4 — preview pane = single flat card flow

Boss OOB: '因为素材预览区只显示当前选定目录的卡片，所以只需要卡片流，一直铺下去即可' + '素材预览区不需要这个标题，卡片平铺即可'

Spec compliance:
- [x] `categorySection(category:entities:)` private function removed from `EntityPreviewPane`
- [x] `ForEach(EntityCategory.allCases) { category in ... }` outer loop removed
- [x] Single `LazyVGrid(columns:columns, spacing:16)` now spans ALL entities
- [x] Cards sort by category rawValue → title (stable visual order)
- [x] Per-card category chip still rendered (top-right) — info preserved
- [x] Type badge `[人物]`/`[概念]` etc. still rendered per card
- [x] NO per-category section breaks (`哲学`, `军事`, `经济`, `文学`, `历史` headers gone)
- [x] Build exit 0

Scope check:
- Scope creep: None.
- Incomplete: 
  - **Global header "资料库 (9 张卡片)" is still present in this commit** — e29ea8459 removes it. Strictly speaking, this commit only handles the per-category sections OOB; the "no global title" OOB is satisfied by the LATER commit. Boss OOB was delivered across the pair (not within this single commit). Calling this out as a commit-title/commit-content mismatch, NOT a spec fail — the work landed, just in two commits instead of one.

### Commit 1cbbfb249 — sidebar tree = only categories

Boss OOB: '目录树只显示到最后一层的目录，文档不显示在树里。文档在目录被点击选择后，显示在素材预览区'

Spec compliance:
- [x] Sidebar `categoryChildren` builder no longer maps `entitiesInCategory.map { ref -> FCPTreeNode in ... }`
- [x] Category node constructed with `children: []` (no entity children)
- [x] Count badge preserved: `count: entitiesInCategory.count` (e.g. `文学 (2)`) so user still sees how many docs each category contains
- [x] `payloadKind: .referenceCategory` (was `.reference` for the removed entity leaves)
- [x] Single-click on category → preview pane shows that category's entities as cards (already wired by EntityPreviewPane, not in this commit)
- [x] Build exit 0

Scope check:
- Scope creep: None — purely a tree-trimming change.
- Incomplete: None.

## Spec FAIL (= hard failures)

(none)

## Summary

All 5 commits deliver what their corresponding boss OOB requested, verified
against the actual diffs (not just commit messages). The EntityType schema
(32fafec3c) is correctly shaped (9 cases with displayName/shortName/icon/
promptNumber), the type badge fix (57ac2bfb2) correctly moves 1-char
abbreviations out of the default path, the thumbnail (e29ea8459) and flat
card flow (e38c96ad4) combine to satisfy "卡片平铺即可 + 卡片要加缩略图",
and the sidebar trim (1cbbfb249) correctly removes entity children while
keeping count badges. Build is clean (`swift build` exit 0). Two minor
informational notes: (a) e29ea8459 bundles the "no global title" OOB that
the boss had partially addressed in e38c96ad4's grid refactor — the work
landed but across two commits rather than one; (b) 32fafec3c touched the
sidebar entity row format using `.shortName` (1-char) which was the very
abbreviation the boss objected to, but 57ac2bfb2 then re-pointed `.shortName`
at the full Chinese name, and 1cbbfb249 removed the sidebar entity rows
entirely — so the late-arriving boss OOB was honored without a regression
in the final tree state.

Report file: `/Volumes/ANAN/Engineering/wenshu/.scratch/v0.30-polish-fixes/code-review-2026-08-30-spec-axis-report.md`
Verdict: **PASS**
