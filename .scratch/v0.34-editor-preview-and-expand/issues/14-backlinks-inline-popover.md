# 14: B-14 backlinks inline label + popover

## Boss OOB context

Boss 2026-09-02 (= visual verification post B-13 fix): '反链不需要占空间, 放在编辑器区的底栏右边, 替换现有占位文字, 点击可以弹出弹窗, 展示所有反链'.

## What to build

Delete ticket 06's inline 120 PT BacklinksPanel from EditorPreviewContent. Lift BacklinksViewModel to EditorPlaceholder (= single source of truth). Add bottom-bar inline label with popover.

## Blocked by

None (= B-13 fix already merged; = direct follow-up).

## Status

ready-for-agent (= implemented; needs visual re-verify)

## Acceptance criteria

- [x] EditorPlaceholder has @State backlinksVM + @State showBacklinksPopover
- [x] .safeAreaInset(edge: .bottom) shows right-aligned "反链 N" label with Lucide "link" icon
- [x] Click label → .popover shows BacklinksPanel (320x280 PT)
- [x] .onAppear triggers backlinksVM.load on editor zone mount
- [x] Inline panel removed from EditorPreviewContent
- [x] swift build exit 0
- [ ] macOS foreground-mode cua capture confirms bottom bar + popover

## Iron rules applied

- Rule 6: DesignTokens (= no magic numbers)
- Rule 7: Button + system buttonStyle + Lucide
- Rule 11: @State on host (= persistent across re-render)
- wenshu-apple-api-first: SwiftUI .popover + reuses BacklinksPanel verbatim

## Double-axis review

- [ ] Standards axis: English-only body, 0 forbidden vocab
- [ ] Spec axis: popover position + size + non-modal behavior matches Apple HIG
