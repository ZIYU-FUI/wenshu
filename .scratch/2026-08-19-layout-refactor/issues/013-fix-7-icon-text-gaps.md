# 013 修 v0.15 vs 老板 2026-08-19 Sketch 真值差异 7 项

> 老板 2026-08-19 拍板: 用 MCP 读 Sketch 真值, 1:1 像素实现
> 真值源: mcp__sketch__run_code (AF7B1C87-ADDD-41ED-8208-7CA5549070E2, page 文枢-组件化, Artboard 首页)

## 死原则

`52 (macOS chrome) + 465 (上 band) + 2 (D_h) + 465 (下 band) = 984 PT` ✓

## 当前实现 vs 老板 Sketch 真值 差异 7 项

| # | 项 | 老板 Sketch 真值 | 当前实现 | 修法 |
|---|---|---|---|---|
| 1 | 顶栏图标起点 y | **6 PT** | 垂直居中 (toolbarHeight/2 = 15) | ZoneTopToolbar.body HStack 加 .padding(.top, 6) |
| 2 | 顶栏图标间距 | **27 PT** (18→45→72, 差 27) | LayoutTokens.iconSpacingRatio = 18/1920 | 改 LayoutTokens.iconSpacingRatio = 27/1920 (或硬编码) |
| 3 | 顶栏占位文本 | **x=220, y=8** (52×16, fontSize 13) | 没画 | ZoneTopToolbar body 加 Text 占位文本, 右上角 |
| 4 | 顶栏分割线 | **y=28, h=2** (底部 2 PT) | h=1 (底部 1 PT) | 改 .frame(height: 2) |
| 5 | 底栏占位元素 | **2 个占位文本** (左 x=18 + 右 x=130, y=8) | 1 text + 1 icon | ZoneBottomToolbar.body 改: 左 Text + 右 Text, 删右 icon |
| 6 | 拖拽线 | **2 PT** (master "拖拽线-竖" frame = 2×2) | 1 PT (ticket 009 改 1, 错) | NativeSplitter.lineThickness 改回 2 |
| 7 | 底栏分割线 | **y=0, h=2** (顶部 2 PT) | h=1 | 改 .frame(height: 2) |

## 不动

- macOS chrome 1920×52 (老板 2026-08-19 拍 A 范式)
- 6 区 layout 区域 (200/520/794/400 上 band + 1518/400 下 band, ticket 012 已对)
- D_h y=517 ✓
- 顶栏/底栏 30 PT (ticket 008 已对)
- 编辑器 4 PT inset 双层 (ticket 005 已对)
- VSplitter / NativeSplitter(view) hover/drag 范式 (ticket 006 已对)

## 验收

- swift build clean
- swift run + Quartz screencapture -l 真截图
- 顶栏图标起点 y=6, 间距 27, 占位文本在右上 x=220
- 底栏左/右各占位文本, 距底边 6
- 顶/底分割线 2 PT
- 拖拽线 2 PT 静态 + 4 PT hover accent
- 整体跟 Sketch AF7B1C87 1:1 像素

## 风险

- 老板 2026-08-19 反复改决策: 之前拍 1 PT 拖拽线 (我改), 现在 Sketch master 显示 2 PT
  Q21 撤回 v0.15 ticket 009 "1 PT 拖拽线" 拍板
- 顶栏图标起点 y=6 vs 当前垂直居中, 改了后图标可能跟 toolbar 顶/底不对齐
- 顶栏占位文本跟底栏占位文本字号 13 PT (Apple HIG body), 跟底栏"占位文字"一致
