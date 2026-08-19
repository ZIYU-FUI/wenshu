# 01 — D_h 横拖拽线 cursor 切 + 拖动响应 + 范围不限

**What to build:**
老板 2026-08-19 反馈 D_h 横拖拽线 2 个 bug:
1. cursor 不切 (鼠标移上去不变上下箭头)
2. 拖了没反应 (上下区域占比不变)

改完:
- D_h hover 时 cursor 切到上下箭头 (Apple HIG SwiftUI 4 macOS 27 API, 推翻 v0.15 ticket 023)
- D_h 按下拖动能改变上/下区域占比 (排查 v0.15 ticket 014 实测不工作的真因)
- D_h 拖动范围不限 (`bandOffset` 范围 [-1.0, +1.0], 为下个 "区域隐藏" 需求准备)
- D_v 5 根竖拖拽线行为不变 (Q20 已实现不要直接动)
- `swift build` exit 0

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

## Acceptance criteria

- [ ] D_h 横拖拽线 hover 时 cursor 切到上下箭头 (跟 D_v columnResize 对称)
- [ ] D_h 按下拖动, 上 /下区域占比实时变化 (60 fps 跟手不抖动)
- [ ] D_h 拖动范围不限 (bandOffset [-1.0, +1.0])
- [ ] D_v 5 根竖拖拽线行为不变
- [ ] D_h 视觉保持 (静态 2 PT 黑色 + hover 4 PT accent + shadow)
- [ ] D_h hit area 保持 6 PT
- [ ] `swift build` exit 0
- [ ] macOS chrome / LayoutTokens / bandH 比例算子 / D_v / toolbar 宽度算法 (v0.16 ticket 01) 全不动
- [ ] 不引入新组件
- [ ] 不跑 Q22 (Screen Recording TCC 未授权), 老板自己验

## 实现层选项 (老板 review ticket 时拍)

- cursor API: 推翻 `.onContinuousHover` + `NSCursor.push` (v0.15 ticket 023), 用其他 macOS 27 SwiftUI 4 API
- 拖动排查方向: `NativeSplitter(.horizontal)` 手势挂载位置 / `withTransaction` 影响 / `vm.bandOffset` mutate 触发 view 重渲染