# 003 验 LayoutShellViewModel.adjustBandSplit + LayoutTokens 一致

> 老板 2026-08-19 拍板: D_h 横拖拽线可拖 (撤销之前 50/50 锁定)
> 依赖: 002

## 范围

`Sources/WenshuApp/LayoutShellViewModel.swift`:
- 验 `adjustBandSplit(delta:totalHeight:)` 方法存在
- 验 5 竖 `adjustSidebarPreview / adjustPreviewEditor / adjustEditorTools / adjustChatDynamic` 全存在
- 验 D_h = bandOffset 累加 + upperBandH / lowerBandH 反方向守恒

`Sources/WenshuApp/App.swift LayoutTokens`:
- titleBarHeight = 0 或删(老板新令不写自定义标题栏)
- bandRatio / toolbarRatio / editorInsetRatio 保留(算比例算子)
- iconLeadingRatio / iconSizeRatio / iconSpacingRatio 保留(Sketch 真值)

## 验收

- swift build clean
- 拖 D_h 真动 (vs 之前 inert 锁死)
