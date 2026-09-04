# 04 — preview pane = single flat card flow

**What to build:**

Boss 2026-08-30 OOB '因为素材预览区只显示当前选定目录的卡片，所以只需
要卡片流，一直铺下去即可' + '素材预览区不需要这个标题，卡片平铺即
可' = preview pane cards should be a flat grid (= no global title, no
per-category sections).

Pre-fix: `overviewGrid` had a '资料库 (X 个实体 · Y 个分类)' header + per-
category section headers.

Fix: remove global header + per-category section headers.

**Blocked by:** None (= can start independently).

**Status:** ready-for-agent (= already committed as `e38c96ad4`, this
ticket documents the commit after-the-fact per Q5.6 partial commit 接管
规范).

## Fix specification

### File: `Sources/WenshuApp/Views/Workspace/EntityPreviewPane.swift`

- `overviewGrid(allEntities:)` rewritten:
  ```swift
  private func overviewGrid(allEntities: [Reference]) -> some View {
      if allEntities.isEmpty {
          emptyState(message: "资料库里还没有实体.\n导入研究材料后 LLM 会自动分类.")
      } else {
          let sorted = sortEntities(allEntities, by: sortOrder)
          GeometryReader { geometry in
              ScrollView {
                  LazyVGrid(columns: adaptiveColumns(width: geometry.size.width), spacing: 16) {
                      ForEach(sorted) { entity in
                          EntityCard(entity: entity) {
                              onEntityDoubleClick(entity)
                          }
                      }
                  }
                  .padding(.vertical, 8)
              }
          }
      }
  }
  ```

## Acceptance

- [x] No '资料库 (X 个实体 · Y 个分类)' header
- [x] No per-category section headers (哲学、宗教 (1), 军事 (1), etc.)
- [x] Single flat LazyVGrid of cards
- [x] Build exit 0
- [x] Screenshot verified: 9 cards in flat grid

## Out-of-scope

- Card grouping by type/date/etc. (= boss explicitly said flat only)
