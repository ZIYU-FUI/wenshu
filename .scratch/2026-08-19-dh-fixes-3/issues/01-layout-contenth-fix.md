# 01 — LayoutShellView contentH 重复扣 chrome (老板 2026-08-19 拍)

**What to build:**
修 LayoutShellView VStack 内 GeometryReader proxy.size.height 重复扣 macOS chrome 52 PT 真因 — proxy 已返回 contentRect (932, 不含 chrome), 旧代码 contentH - 52 多扣一次, 导致 bandH 总 882, windows 底部留 50 PT 空白.

改完:
- LayoutShellView 改 contentH - 52 → contentH - 2 (contentH 已扣 chrome, -2 留给 D_h 拖拽线)
- 历史 commit 注释 (v0.15 ticket 021) "984 不含 chrome" 错 (984 含 chrome, 932 才是 contentRect), 同步修正

**Blocked by:** None — can start immediately.

**Status:** done — commit b4f2021 (老板 8/19 验过 pass)

## Acceptance criteria

- [x] LayoutShellView VStack 内 bandH 计算: contentH - 52 → contentH - 2
- [x] vm.adjustBandSplit(delta: dy, totalHeight: contentH - 2) (跟 bandH 同步)
- [x] windows 底部无空白 (上半:下半 = 50:50)
- [x] macOS chrome 52 PT 不动 (.windowStyle(.titleBar))
- [x] D_h 拖拽线 2 PT 不动
- [x] swift build exit 0
- [x] 注释 "984 不含 chrome" → "932 (chrome 在外)"

## 验真 (老板 8/19 拍 "过" 表示 pass)