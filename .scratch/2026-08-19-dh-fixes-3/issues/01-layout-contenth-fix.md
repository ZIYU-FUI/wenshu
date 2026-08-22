# 01 — LayoutShellView contentH double-deducts chrome (老板 2026-08-19 拍)

**What to build:**
Fix LayoutShellView VStack's GeometryReader `proxy.size.height` double-deducting macOS chrome 52 PT root cause — proxy already returns contentRect (932, not including chrome); the old code `contentH - 52` deducted one extra time, causing bandH total 882, leaving 50 PT blank at window bottom.

After change:
- LayoutShellView change `contentH - 52` → `contentH - 2` (contentH already deducts chrome, -2 reserved for D_h splitter)
- Historical commit comment (v0.15 ticket 021) "984 not including chrome" was wrong (984 includes chrome, 932 is contentRect), correct synchronously

**Blocked by:** None — can start immediately.
**Status:** done — commit `b4f2021` (老板 8/19 verified pass)

## Acceptance criteria

- [x] LayoutShellView VStack bandH calculation: `contentH - 52` → `contentH - 2`
- [x] `vm.adjustBandSplit(delta: dy, totalHeight: contentH - 2)` (in sync with bandH)
- [x] No blank at window bottom (upper:lower = 50:50)
- [x] macOS chrome 52 PT unchanged (`.windowStyle(.titleBar)`)
- [x] D_h splitter 2 PT unchanged
- [x] `swift build` exit 0
- [x] Comment "984 not including chrome" → "932 (chrome outside)"

## Truth verification (老板 8/19 拍 "过" means pass)