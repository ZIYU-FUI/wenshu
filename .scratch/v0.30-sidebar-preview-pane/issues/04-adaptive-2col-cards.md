# 04 — preview pane adaptive 2-column card flow

**What to build:**

Boss 2026-08-30 OOB '卡片好看不少, 但是需要卡片多列显示, 默认两列,
如果区域被拖拽宽度变窄, 不够两列, 自动适配成一列' = preview pane
cards need:
1. Default = 2 columns
2. Auto-collapse to 1 column when pane too narrow for 2

Pre-fix: `LazyVGrid(columns: [.adaptive(minimum: 220)])` (= variable
columns based on width). Boss wanted explicit 2-column default + 1-column
fallback.

**Blocked by:** None (= can start independently).

**Status:** ready-for-agent (= already committed as `d5a02d751`,
this ticket documents the commit after-the-fact per Q5.6 partial
commit 接管规范).

## Fix specification

### File: `Sources/WenshuApp/Views/Workspace/EntityPreviewPane.swift`

1. **Remove static `columns` array**.

2. **Add `adaptiveColumns(width: CGFloat) -> [GridItem]` helper**:
   ```swift
   private static let twoColumnBreakpoint: CGFloat = 280

   private func adaptiveColumns(width: CGFloat) -> [GridItem] {
       if width >= Self.twoColumnBreakpoint {
           return [
               GridItem(.flexible(), spacing: 16, alignment: .topLeading),
               GridItem(.flexible(), spacing: 16, alignment: .topLeading),
           ]
       } else {
           return [GridItem(.flexible(), spacing: 16, alignment: .topLeading)]
       }
   }
   ```

3. **Wrap LazyVGrid in GeometryReader** (= both overviewGrid and
   categoryGrid):
   ```swift
   GeometryReader { geometry in
       ScrollView {
           LazyVGrid(columns: adaptiveColumns(width: geometry.size.width),
                      spacing: 16) {
               ForEach(sorted) { entity in EntityCard(...) }
           }
           .padding(.vertical, 8)
       }
   }
   ```

## Acceptance

- [x] Default (= preview pane > 280 PT) = 2 columns
- [x] Narrow pane (< 280 PT) = 1 column
- [x] Threshold = 280 PT (= 2 cards × ~140 PT minimum + 16 PT spacing
  + 24 PT padding = ~280 PT)
- [x] Both overviewGrid + categoryGrid use the same helper (= consistent)
- [x] Build exit 0
- [x] Screenshot verified (= 2 cards side by side at default width)

## Threshold rationale

- 280 PT = 2 cards × ~140 PT min content + 16 PT gap + 24 PT padding
  - Card min content width = thumbnail (100 PT) + padding + text (title
    + summary + chip) = ~140 PT
- At default wenshu preview pane ratio = 20% of 1920 PT window = 384 PT
- 384 PT > 280 PT threshold → always defaults to 2 columns

## Out-of-scope

- 3-column mode (= boss specified 2-column default only)
- Card minimum/maximum width constraints (= Apple std flexible
  columns handle this naturally)
