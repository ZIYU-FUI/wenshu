# 02 — 拖拽线 / 分割线视觉顶到头 (差 1 像素修法, 老板 2026-08-19 19:00 拍)

**What to build:**
老板 2026-08-19 19:00 反馈 "拖拽线没有顶到头, 看起来像是差 1 像素; 分割线也是一样, 一并处理".

改完:
- NativeSplitter body Rectangle frame 改成 hitAreaThickness (6 PT) 视觉占满 hit area
- 拖拽线 D_h 横跨整 window 宽, D_v 占满 zone 高度
- StaticDividerHorizontal / Vertical Rectangle frame 改成占满 split region

**Blocked by:** None

**Status:** ready-for-agent → impl done → 等老板验

## 已知真因

- NativeSplitter.swift L155-160: Rectangle `.fill(...) .frame(width: lineFrame.width, height: lineFrame.height)` — Rectangle frame 是 lineFrame (2 PT 静态 / 4 PT hover), 居中在 hit area (6 PT) 内
- hit area (6 PT) 透明 NSView overlay, 视觉 Rectangle (2/4 PT) 在内部居中, **上下/左右各有 1-2 PT 留白**
- 老板看 "差 1 像素" = 视觉 Rectangle 没有 100% 占 hit area 宽度, 上下/左右各有 1-2 PT 留白

## Sketch AF7B1C87 真值

- D_h (横拖拽线) 真值: x:0, y:517, w:1920, h:2 (横跨整 window 宽, 1920 PT 1:1)
- D_v (竖拖拽线) 真值: x:200/720/1244, y:52, w:2, h:465 (整 band 高, 2 PT 宽)
- 真值都 100% 占满 region, 差 0 像素

## 修法方向

老板拍 A:
- 选项 A: Rectangle frame 改成 hitAreaThickness (6 PT) 视觉占满 hit area, 拖拽线顶到头
- 选项 B: Rectangle frame 保持 2 PT 但 NSTrackingArea bounds 精确等于 Rectangle 视觉区域
- 选项 C: 1 PT 调整 (e.g. Rectangle frame +1 PT = 3 PT 视觉) 解决差 1 像素

按 Apple HIG 真值 + Sketch 1:1 真值 (D_h / D_v 100% 占 region) — 选项 A 最稳, 符合老板原意 "顶到头".

## Acceptance criteria

- [ ] NativeSplitter Rectangle frame 改成 hitAreaThickness (6 PT) 视觉占满 hit area
- [ ] D_h 拖拽线横跨整 window 宽 (1920 PT)
- [ ] D_v 5 竖拖拽线占满 zone 高度 (zone bandH)
- [ ] StaticDividerHorizontal Rectangle frame 占满 split region
- [ ] StaticDividerVertical Rectangle frame 占满 split region
- [ ] 拖拽线 / 分割线视觉 1:1 落 Sketch AF7B1C87 (差 0 像素)
- [ ] hover 蓝光 (Apple 系统亮色 .controlAccentColor.opacity(0.25)) 全保持
- [ ] 拖拽线 / 分割线 hover 4 PT 变粗保持
- [ ] 拖拽线拖动 / hit area / 6 PT hit area 不动
- [ ] macOS chrome 52 PT 不动
- [ ] LayoutTokens / bandH / toolbar 宽度 不动
- [ ] swift build exit 0

## 业务语言描述 (老板懂)

- 拖拽线视觉顶到头 (差 0 像素, 不像之前差 1 像素)
- 分割线也是一样 (横/竖都顶到头)
- 1:1 落 Sketch AF7B1C87 (老板 Sketch 真值)