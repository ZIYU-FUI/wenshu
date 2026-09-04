# 02 — sidebar tree row selection highlight

**What to build:**

Boss 2026-08-30 OOB '左侧目录树缺少选定效果' = sidebar tree rows
need selection highlight (= Apple HIG standard tint when an item is
the currently selected one).

Pre-fix: FCPRowView didn't track sidebarSelection binding. Clicking a
sidebar row didn't visibly indicate selection.

Fix: add `isSelected` computed property to FCPRowView + `.background()`
modifier.

**Blocked by:** None (= can start independently, but logically follows
01 since both modify FCPRowView).

**Status:** ready-for-agent (= already committed as `1955fc131`,
this ticket documents the commit after-the-fact per Q5.6 partial
commit 接管规范).

## Fix specification

### File: `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift`

In `FCPRowView`:

1. Add `@Binding var selectedCategory: EntityCategory?` (= state from
   parent).

2. Add computed property:
   ```swift
   private var isSelected: Bool {
       switch node.payloadKind {
       case .book:
           return bookStore.selectedBookId == node.id
       case .referenceCategory:
           return selectedCategory?.displayName == node.label
       default:
           return false
       }
   }
   ```

3. Add `.background()` modifier to row HStack:
   ```swift
   .background(
       isSelected
           ? Color.accentColor.opacity(0.12)
           : Color.clear,
       in: RoundedRectangle(cornerRadius: 4, style: .continuous)
   )
   ```

4. Update onTapGesture to also handle `.referenceCategory` (= sets
   `selectedCategory` from node label).

## Acceptance

- [x] Clicking a book row → highlight visible (= accent tint at 0.12
  opacity)
- [x] Clicking a category row → highlight visible
- [x] Highlight matches Apple HIG sidebar style
- [x] Build exit 0
- [x] Screenshot verified

## Note on Apple HIG List migration (= superseded)

This fix used `Color.accentColor.opacity(0.12)` (= manual background).
After commit `c5ed76169` migrated sidebar to `List(.sidebar)`, Apple
provides automatic selection highlight (= List's intrinsic selection
rendering). The manual `.background()` was kept for the legacy
`FCPRowView` path but the production path now uses Apple std.

This means the fix from `1955fc131` is partially superseded by
`c5ed76169`. Both commits are kept in git history per Q5.4 do-not-amend
(= no rebase/amend; the fix evolution is preserved as audit trail).
