# Issue 01 — Reference card fixed format

## What (= scope)

A single canonical reference-card display format across wenshu (= every reference in `.scratch/reference-library/entities/<uuid>.md`). Every reference renders with: **title** + **1-sentence summary** (= from the MD's first paragraph / first sentence) + cover thumbnail (from Issue 02) + quoted MD body.

Reference Card-master's `cards.ts` `cardTitle()` / `cardDescription()` / `cardMedia()` / `cardAccent()` 4-derive pattern.

## Why (= rationale)

Boss 2026-09-02 OOB verbatim: '我想在聊天触发调研的时候,或者写MD文件的时候,除了 LLM WIKI 机制,还有一套生成固定卡片格式的机制,这样可以让卡片的样式同意.就像现在资料库卡片一样,有标题,有 一句话说明这个文件写了什么,很简洁的一句话,卡片只显示这句概论,引用MD的正式段落.这样 1 是看起来简洁,2 是一眼就能看出这个文件的内容'.

## Apple-API-first check

- Custom code: a hand-rolled 4-derive pattern in `Domain/Reference.swift` (or new `UI/ReferenceCard/` module).
- Apple HIG candidate: SwiftUI `Label` (= already adopted for sidebar in v0.30 commit `3f20a0efe`) + `Material` (= already in use).
- Apple coverage: full (= no behavior loss; the existing `ReferenceEditorSheet` and entity views get a unified derive).
- LOC delta: ~250.
- Risk: low (= no new dependencies; pure derive layer + minimal view binding).

## What to delete (= self-built helpers to retire)

None (= there is no previous reference-card display layer; this is a net-new derive).

## Files touched

- `Sources/WenshuApp/Domain/Reference.swift`: add `referenceCardTitle()` / `referenceCardDescription()` (= single source of truth derives).
- `Sources/WenshuApp/UI/ReferenceCard/ReferenceCardView.swift` (NEW): SwiftUI Label-based card view (= `referenceCardTitle` + `referenceCardDescription` + `cardMedia` from Issue 02).
- `Sources/WenshuApp/Views/Library/ReferenceEditorSheet.swift`: use the new derive (= replace any inline title/summary formatting).

## Acceptance criteria

- [ ] `Reference` domain has `referenceCardTitle()` and `referenceCardDescription()` derive functions (= single source of truth).
- [ ] `ReferenceCardView` shows: title + 1-sentence summary only in the card chrome; full MD body shown via `DisclosureGroup` or expandable section.
- [ ] Sidebar / preview pane / editor / settings all use the same `ReferenceCardView` (= no per-view title/summary formatting).
- [ ] macOS screenshot confirms uniform card appearance across the app.
- [ ] `git grep "Reference" -- '*.swift' | grep -i "inline"` returns 0 (= no inline title/summary formatting left).

## Implementation ticket chain (= Q29 1 commit per ticket)

1. Read existing `Reference` + `ReferenceEditorSheet` to understand current display layer.
2. Add the 2 derive functions on `Reference`.
3. Build `ReferenceCardView` (= SwiftUI Label + .regionContentBackground).
4. Wire all 4 existing call sites (= sidebar / preview pane / editor / settings).
5. Build + screenshot.

## Dependencies

None (= Issue 02 AI thumbnail integration is optional for this issue; the card displays title + summary even without a thumbnail).

## References

- Boss OOB 2026-09-02: '卡片只显示这句概论,引用MD的正式段落'
- Source: Card-master `src/features/userscript-deck/cards.ts` `cardTitle()` / `cardDescription()` pattern
- Spec: `.scratch/2026-09-02-card-master-port/spec.md` §3 item 1

First line: fact. Last line: fact.