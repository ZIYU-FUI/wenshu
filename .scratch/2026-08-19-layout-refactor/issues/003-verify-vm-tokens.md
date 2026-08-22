# 003 Verify LayoutShellViewModel.adjustBandSplit + LayoutTokens consistency

> 老板 2026-08-19 拍板: D_h horizontal splitter draggable (revert previous 50/50 lock)
> Dependency: 002

## Scope

`Sources/WenshuApp/LayoutShellViewModel.swift`:
- Verify `adjustBandSplit(delta:totalHeight:)` method exists
- Verify 5 vertical `adjustSidebarPreview / adjustPreviewEditor / adjustEditorTools / adjustChatDynamic` all exist
- Verify D_h = bandOffset accumulation + upperBandH / lowerBandH opposite direction conservation

`Sources/WenshuApp/App.swift LayoutTokens`:
- titleBarHeight = 0 or delete (老板 new order don't write custom title bar)
- bandRatio / toolbarRatio / editorInsetRatio preserve (ratio operator)
- iconLeadingRatio / iconSizeRatio / iconSpacingRatio preserve (Sketch truth)

## Acceptance

- `swift build` clean
- Drag D_h truly moves (vs previously inert lock)