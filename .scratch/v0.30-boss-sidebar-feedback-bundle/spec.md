# Spec — v0.30 boss 8/31 sidebar feedback bundle (6 OOBs)

> Date: 2026-08-31 (boss in office, manual APP verify)
> Q34 status: step 1 (grill) + step 2 (spec) done; step 3 (tickets) in this commit

## Boss OOBs (= 6 items)

1. **Default shelf/book naming**: 1st-level "从这里开始" is a shelf (= the "书架" type in user's mental model). Inside it there's a default book (= "书" type). User wants the default book renamed from "从这里开始" to "帮助" (= to disambiguate from the shelf). User clarifies: shelf and book are TYPE-level concepts in the user's mental model; not literal display names. Code should treat them as shelf/book data structure; the user-facing names are flexible.

2. **Folder .md count + load (= OOB #3)**: The bottom status bar shows 书架: 0, 书: 0 — these are stale. Also the book "帮助" sub-folders (世界观 / 角色 / etc.) have .md files written (= per `Scripts/seed-test-entities.swift` etc.) but neither the count badge shows nor the preview pane renders them.

3. **Section spacing 30PT → 10PT**: shelf "从这里开始" and reference "资料库" are both top-level sections but visually ~30PT apart. Reduce to 10PT.

4. **Click sidebar → preview pane data unchanged (= never implemented)**: Tapping a sidebar row should change what the preview pane shows. Currently preview always shows all entities (= overview mode), regardless of selection.

5. **资料库 fallback category "其他"**: When an entity doesn't match any of the 22 中图法 categories (A-Z), it should auto-fall-back to a "其他" (= other) category. Currently no fallback; classifier returns nothing or crashes.

## Implementation plan

5 separate commits (= 1 ticket each per Q124):

| Ticket | Scope | Acceptance |
|---|---|---|
| 01-default-book-name | Rename default book from "从这里开始" to "帮助" | New default shelf has a book titled "帮助" |
| 02-status-bar-count | Status bar `书架: N / 书: N` reflects actual filesystem | Counts match `ls shelves/` + `ls shelves/*/books/` |
| 03-folder-count-load | Sub-folder row count badge + .md files load into preview pane | Tapping 世界观 / 角色 / 等 shows count + opens preview |
| 04-section-spacing | List section spacing 30PT → 10PT | Visual gap = 10PT |
| 05-selection-preview-binding | Click sidebar row → preview pane shows scoped data | Tapping category switches preview; tapping folder scopes to that folder's entities |
| 06-fallback-category | EntityCategory gains "其他" as catch-all (= replace Z 综合性图书 display name OR add new) | Unmatched entities auto-route to 其他 |

## Q34 8-step status (= per ticket, post-hoc chain)

| Step | Status |
|---|---|
| 1. grill-with-docs | done (this spec) |
| 2. to-spec | done (this spec) |
| 3. to-tickets | done (5 issues/*.md) |
| 4. implement | pending |
| 5. code-review 双轴 | pending |
| 6. hard violation 修法 | pending |
| 7. domain-modeling | pending |
| 8. Q22 真验证 | pending (= boss already in office, manual verify ready) |
