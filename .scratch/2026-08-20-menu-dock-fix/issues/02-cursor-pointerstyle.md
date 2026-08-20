# 02 — cursor 切 ↕/↔ (老板 2026-08-20 拍)

**What to build:**
老板 2026-08-20 拍 "鼠标还是没有变形". 修法 ticket 02.

改完:
- 删 commit f65bb3292 挂在 ZStack 父级的 .pointerStyle (位置错, NSViewRepresentable 桥接 SplitterHitAreaRepresentable 不能传 SwiftUI cursor 系统)
- 改挂到 NativeSplitter body 的 Rectangle 视觉上 (SwiftUI view tree 内层)
- SwiftUI `.pointerStyle` 修饰符穿透 NSViewRepresentable 桥接到 SwiftUI view tree, NSHostingView 接管 cursor event → SwiftUI PointerStyle 系统 work

**Blockers:** ticket 01 修完 (同 priority).

**Acceptance:**
- swift build exit 0
- 老板鼠标 hover D_h 拖拽线 → cursor 切 ↕ 上下箭头
- 老板鼠标 hover D_v 5 竖拖拽线 → cursor 切 ↔ 左右箭头
- 老板鼠标离开 → cursor 还原
- 不动: hermes / 6 区 layout 框架 / 拖拽线视觉 (1 PT fill / 3 PT hover / 1 PT hit area / 系统色 / 不圆头) / WenshuCore 14 真值模块 / ChatView
