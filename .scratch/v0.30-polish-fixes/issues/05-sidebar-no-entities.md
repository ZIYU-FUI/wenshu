# 05 — sidebar tree = only categories, no entity nodes

**What to build:**

Boss 2026-08-30 OOB '目录树只显示到最后一层的目录，文档不显示在树里。
文档在目录被点击选择后，显示在素材预览区' = sidebar tree stops at the
last folder level; documents inside folders are not shown in the tree.
Documents appear in the preview pane when a folder/category is selected.

Pre-fix: sidebar tree for reference library showed category → entity →
entity.md nodes (= 3 levels, violating Apple HIG 'no more than two levels').

Fix: sidebar tree stops at category level; entities appear in the preview pane
when category is selected (= the existing binding flow).

**Blocked by:** None (= can start independently).

**Status:** ready-for-agent (= already committed as `1cbbfb249`, this
ticket documents the commit after-the-fact per Q5.6 partial commit 接管
规范).

## Fix specification

### File: `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift`

- In `categoryChildren` (the pre-v0.30 FCPTreeNode builder), removed
  `entityChildren`:
  ```swift
  // v0.30: children = [] (= no entity nodes in tree).
  // Entities are shown in the preview pane after sidebar click,
  // NOT here.
  return FCPTreeNode(
      id: ...,
      label: cat.displayName,
      icon: cat.icon,
      count: entitiesInCategory.count,
      children: [],  // v0.30: empty (= no entity nodes)
      payloadKind: .referenceCategory
  )
  ```

- Existing binding flow (category tap → `selectedEntityCategory = cat`
  → preview pane re-renders to show category-scoped grid) handles the
  user-facing requirement (= docs in preview pane after category click).

## Acceptance

- [x] Sidebar tree shows category nodes only (= no entity children)
- [x] Clicking a category in sidebar → preview pane shows category-scoped
  card grid
- [x] Apple HIG 'no more than two levels' satisfied
- [x] Build exit 0
- [x] Screenshot verified: 资料库 tree = 1 row (no entity children)

## Out-of-scope

- Open document in editor (= boss Ticket 3 future ticket; current is
  preview-only)
