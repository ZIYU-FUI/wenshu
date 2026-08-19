# 01 — 拖拽线取消圆头 + 改用 Apple 系统色 (老板 2026-08-19 拍)

**What to build:**
老板 2026-08-19 16:50 拍 "取消圆头" + 18:15 拍 "颜色用系统色" + 18:48 反馈 "你忘拍了, 现在补跑". 整合到 1 commit 跑.

改完:
- NativeSplitter Rectangle 删 .clipShape(.capsule) (取消圆头)
- Rectangle .fill 用 .separatorColor (静态) / .controlAccentColor (hover) (Apple 系统色)
- Rectangle .shadow 用 .controlAccentColor (同上)
- DesignColor.splitterLine 改 .separatorColor
- DesignColor.accentBlue 改 .controlAccentColor
- StaticDividerHorizontal / Vertical 改 .separatorColor

**Blocked by:** None

**Status:** ready-for-agent → impl done → 等老板验

## Acceptance criteria

- [ ] NativeSplitter Rectangle 删 .clipShape(.capsule) (取消圆头, 变矩形)
- [ ] 静态 2 PT 用 Color(nsColor: .separatorColor) (Apple HIG divider 色)
- [ ] hover 4 PT 用 Color(nsColor: .controlAccentColor).opacity(0.25) (Apple HIG 系统亮色)
- [ ] shadow 用 Color(nsColor: .controlAccentColor).opacity(0.15)
- [ ] DesignColor.splitterLine 改 .separatorColor
- [ ] DesignColor.accentBlue 改 .controlAccentColor
- [ ] StaticDividerHorizontal / Vertical .fill 改 .separatorColor
- [ ] D_h / D_v 5 竖拖拽线都生效 (1 组件改 1 处 = 6 根全改)
- [ ] 拖拽线视觉 (4 PT hover 变粗 / shadow / 透明度 0.25 / 0.15) 全保持
- [ ] 拖拽线拖动 / hit area / cursor 不动 (cursor backlog 02 待办)
- [ ] macOS chrome 52 PT 不动
- [ ] LayoutTokens / bandH / toolbar 宽度不动
- [ ] swift build exit 0

## 业务语言描述 (老板懂)

- 拖拽线变矩形 (不画圆角, 跟 macOS 系统 divider 一样)
- 静态 2 PT 用 Apple 系统色 (dark/light 自动适配, 不写死)
- hover 4 PT 用 Apple 系统亮色 (跟 macOS 强调色一致)