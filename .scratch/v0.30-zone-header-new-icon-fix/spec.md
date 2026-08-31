# Spec — v0.30 zone header 新建 icon fix

> Date: 2026-08-31 (boss in office)
> Boss OOB: '顶栏右边的新建 ICON 没有了'

## Problem

Zone-header trailing slot (= rightmost area in the projectSidebar
ZoneContentTabBar) shows only ONE icon button (= 入驻 =
square-arrow-right). The 新建 icon (= square-plus) is missing.

## Root cause

The trailing slot instantiates a SEPARATE `NewLibraryOutlineView()`
(= not the same instance as the sidebar body). Inside this standalone
instance, the 新建 `Menu` is constructed with:
  .menuStyle(.borderlessButton)
  .menuIndicator(.hidden)

These modifiers collapse the Menu's visible label inside the
ZoneContentTabBar trailing slot. Only the 入驻 plain Button survives
rendering (= plain Button uses .buttonStyle(.plain) which DOES
render in the trailing slot).

## Fix (= commit c24c2f3a1)

Replaced the nested Menu with a simple plain Button pattern that
mirrors the 入驻 Button. Tapping the 新建 icon opens an intermediate
sheet (NewChoiceSheet) showing the "新建书 / 新建书架" two-button
choice picker. Tap '新建书' opens showNewBookSheet, tap '新建书架'
opens showNewShelfSheet.

## Files modified

- Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift
  - L92-93: added @State private var showNewChoiceSheet: Bool = false
  - L338-381: zoneHeaderButtons replaced Menu with plain Button +
    sheet modifier
  - L565-611: added NewChoiceSheet struct (= two-button picker UI)

## Acceptance criteria

1. swift build exit 0
2. Zone header trailing slot shows 2 icons (= square-plus 新建 +
   square-arrow-right 入驻)
3. Tapping 新建 opens NewChoiceSheet (= 2 buttons: 新建书 / 新建书架)
4. Tapping 入驻 opens macOS NSOpenPanel (unchanged)
5. Domain word: NewChoiceSheet added to CONTEXT.md (Q34 step 7)

## Boss verifications (= pending Q22 visual)

- Boss manually opens APP after build
- Tap zone header 新建 icon → expect NewChoiceSheet appears
- Tap 新建书 / 新建书架 button → expect existing sheet opens
- Tap 入驻 icon → expect NSOpenPanel (= unchanged behavior)
