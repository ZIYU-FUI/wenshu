# 17: B-17 strip 120 PT BacklinksPanel + DesignTokens padding

## Boss OOB context

Boss 2026-09-02 (= post-B-16 visual verify): '反链那 120 高度的空间还在, 不用在编辑器里占空间, 本来就空间不大'. Earlier B-14 revert missed the EditorPreviewContent inline 120 PT panel (= ticket 06 dead code).

## What to build

1. Delete inline 120 PT BacklinksPanel + Divider + `.task` loader from EditorPreviewContent
2. Delete `@State backlinksVM` from EditorPreviewContent (= orphan)
3. Replace inline `.padding(12)` with `DesignTokens.chromePaddingMedium`
4. Replace inline `.padding(16)` with `DesignTokens.chromePaddingLarge`

## Status

ready-for-agent (= implemented; visual verified)

## Acceptance criteria

- [x] EditorPreviewContent.body no longer contains 120 PT BacklinksPanel
- [x] EditorPreviewContent no @State backlinksVM
- [x] All padding uses DesignTokens (= Rule 6)
- [x] font stays .body (= Rule 2 standard text style)
- [x] swift build exit 0
- [x] macOS visual verify: 120 PT panel gone, body fills editor zone

## Iron rules applied

- Rule 6: no magic numbers (= DesignTokens)
- Rule 7: Apple HIG components only
- Rule 2: Apple 11 standard text styles only
