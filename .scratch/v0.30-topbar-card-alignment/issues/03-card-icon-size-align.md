# Ticket 3: Standardize card icon size (64 PT for both EntityCard + BookDocCard)

## Goal
Make 资料库卡片 (EntityCard) and 书里卡片 (BookDocCard) have the
same icon size (recommend **64 PT**) so they look visually identical.

## Root cause
- `EntityCard` (`PreviewPane.swift:705-710`) passes
  `iconSize: 64` to `Card.CardContent`.
- `BookDocCard` (`PreviewPane.swift:859-864`) passes
  `iconSize: 56` to `Card.CardContent`.
- The 64 vs 56 difference is arbitrary (= no documented reason).
- Both use the shared `Card` struct (per boss 8/31 OOB
  "用书里的同一个组件, 没有必要实现两回一样的东西"), but the
  iconSize passed in differs.

## Fix
Standardize to **64 PT** (= the larger one, which matches the
canonical entity card design and is more visually prominent). Update
`BookDocCard` adapter to pass `iconSize: 64`.

## Acceptance criteria
1. Both EntityCard and BookDocCard render with 64 PT icon size.
2. Screenshot of preview pane with book doc selected shows the
   same thumbnail icon size as when entity is selected.
3. No regression in card layout (= thumbnail height, gradient,
   corner radius all unchanged).

## Files touched
- `Sources/WenshuApp/Views/Workspace/PreviewPane.swift` —
  `BookDocCard` adapter (~1 line change: `iconSize: 56` →
  `iconSize: 64`).

## Verification commands
```bash
cd /Volumes/ANAN/Engineering/wenshu
swift build 2>&1 | tail -3
# Launch + click 帮助 book to see book docs
# Click 资料库 category to see entity cards
# Visually compare icon sizes (= should be identical)
```