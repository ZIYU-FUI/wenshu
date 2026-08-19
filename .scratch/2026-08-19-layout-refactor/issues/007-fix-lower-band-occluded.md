# 007 修 LayoutShellView 下 band 被遮 + 拖拽线看不到

> 老板 2026-08-19 拍板: 修
> 死原则: 52 (macOS chrome) + 上半 + 拖拽线 + 下半 = 984 PT, 不动

## 现状(commit 65611e7 真渲染)

- 标题栏 macOS chrome 单层 52 PT ✅
- 上 band 4 列 + 顶栏 3 SF Symbol ✅
- 编辑器 4 PT inset 双层 + 左右 flush ✅
- **下 band 2 区顶栏/底栏"占位文字"可见, 但中间大片空白**
- **D_h 横拖拽线 (y=519) 看不到**
- **D_v5 拖拽线 (x=1519) 看不到**

老板反馈: "下半区好像被一个什么东西遮挡了, 看不到拖拽线"

## 死原则

`52 (macOS chrome) + 上半 + 拖拽线 + 下半 = 984 PT` — 不动

## 修法方向(不动死原则)

1. **验证 NSWindow.contentLayoutRect 真实尺寸** — LayoutShellView GeometryReader 应该拿到的是 NSWindow content view 全高(已扣 macOS chrome), 不是全 window frame
2. **看 contentH 实际算出多少** — 算 LayoutShellView VStack 撑超过 view frame 会导致下 band 被截
3. **不动 LayoutTokens.bandRatio = 465/984 = 0.4726**(老板 8/18 拍)
4. **不动 .windowStyle(.titleBar)**(老板 2026-08-19 拍 macOS 官方)
5. **不动 LayoutShellView VStack 结构**(TitleBarZone 不在 VStack 内, 走 macOS chrome)

## 范围(最小改动)

LayoutShellView.body 几何计算:
- `let totalW = proxy.size.width`
- `let contentH = proxy.size.height`  ← 验证是否 = 932 (984 - 52 macOS chrome)
- `let bandH = contentH * LayoutTokens.bandRatio`  ← 算 932 × 0.4726 = 440 PT

VStack: UpperBandZone + D_h + LowerBandZone (总 880 + 1 = 881)
52 chrome + 881 = 933 ≈ 932 ✓

如果 LayoutShellView GeometryReader 报 984 而不是 932, VStack 撑 984 + chrome 52 = 1036 > 984 window, 下 band 撑到 window 外被截

## 验收

- swift build clean
- swift run + screencapture -l 真截图
- 下 band 中间能看见 AI 聊天 / AI 动态
- D_h 横拖拽线 (y=519) 清楚可见
- D_v5 拖拽线 (x=1519) 清楚可见
- 死原则数对 52+465+2+465=984 ✓

## 风险

- 如果 macOS chrome 实际不是 52 PT(我误判)→ 改 LayoutTokens.titleBarHeight 不算改死原则
- 如果 LayoutShellView VStack 内部算错 → 修几何不算改死原则

## 不动

- LayoutTokens.bandRatio / toolbarRatio / editorVerticalInsetRatio (老板 8/18 拍)
- .windowStyle(.titleBar) (老板 2026-08-19 拍)
- LayoutShellView VStack 结构 (Upper + D_h + Lower)
- ZoneModule / ZoneTopToolbar / ZoneBottomToolbar / NativeSplitter / VSplitter
- ADR-0007 + spec §5.2 S1
