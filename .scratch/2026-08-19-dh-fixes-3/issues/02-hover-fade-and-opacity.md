# 02 — hover 蓝光松开消失 + 透明度 0.5 (老板 2026-08-19 拍)

**What to build:**
老板 2026-08-19 实测拖拽线 2 个细节:
1. hover 蓝光松开不消失 (mouseExited 没触发)
2. 蓝光太实, 想加透明度 (老板拍 A: 0.5 轻微透明)

改完:
- NSTrackingArea 加 .mouseMoved option + override mouseMoved 实时算 bounds.contains (不走 mouseEntered/Exited 不可靠路径)
- hover accent opacity 0.6 → 0.5
- hover shadow opacity 0.4 → 0.3
- 老板验收: hover 蓝光鼠标移开立刻消失 + 蓝光 0.5 透明度

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent → impl done → 等老板验

## Acceptance criteria

- [ ] SplitterHitArea 加 override mouseMoved: 实时算 bounds.contains(convert(event.locationInWindow, from: nil)), 设 onHoverChange(在Bounds)
- [ ] NSTrackingArea options 加 .mouseMoved
- [ ] hover 时 accent opacity 0.5 + shadow opacity 0.3 (老板 A 拍 0.5 轻微透明)
- [ ] 鼠标移开拖拽线 → 蓝光立刻消失 (走 mouseMoved 实时算, 不依赖 mouseExited)
- [ ] 静态线 2 PT 黑不变
- [ ] 6 PT hit area 不变
- [ ] D_h / D_v 5 竖拖拽线都生效
- [ ] macOS chrome / LayoutTokens / bandH / toolbar 宽度 全不动
- [ ] swift build exit 0
- [ ] 不引入新依赖 (SwiftUI + AppKit 内置)

## 实现层选项 (老板 review ticket 时拍)

- mouseMoved 实现方式 (Apple 真值已查: NSTrackingArea options + override mouseMoved)
- 透明度数值 (老板 Q13 拍 A: 0.5)