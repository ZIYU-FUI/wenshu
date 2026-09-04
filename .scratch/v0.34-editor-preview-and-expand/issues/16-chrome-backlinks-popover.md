# 16: B-16 chrome bottom right = clickable backlinks popover

## Boss OOB context

Boss 2026-09-02 (= visual verification post B-15): '反链占的区域还是要去掉的, 然后右下的反链 0, 点击可以弹窗'.

## What to build

1. Delete the 3rd '反链' tab in editor zone (= ticket 06's inline BacklinksPanel).
2. PaneStatusBar gains `rightOnTap` parameter; renders right text as Button when non-nil.
3. ZoneBottomStatus passes `rightOnTap` through; TabContentDispatcher.editor case wires popover state.

## Blocked by

None (= B-15 chrome already in place).

## Status

ready-for-agent (= implemented; visual verified)

## Acceptance criteria

- [x] Editor zone tabs = [编辑, 大纲] only (= no 反链 tab)
- [x] PaneStatusBar renders right text as Button when rightOnTap is non-nil
- [x] ZoneBottomStatus supports rightOnTap: (@Sendable () -> Void)?
- [x] TabContentDispatcher.editor case injects rightOnTap + popover binding
- [x] swift build exit 0
- [x] macOS AX tree: '反链 0' = AXButton (clickable, not plain Text)
- [ ] User manual verify: click 反链 0 → BacklinksPanel popover renders

## Iron rules applied

- Rule 6: no magic numbers
- Rule 7: PaneStatusBar canonical; Button path internal
- Rule 11: @State popover binding reactive
- wenshu-apple-api-first: .popover = SwiftUI standard, reuses BacklinksPanel

## Double-axis review

- [ ] Standards axis: English-only body, 0 forbidden vocab
- [ ] Spec axis: popover = 320x280 inspector footprint, anchored to chrome bottom-right
