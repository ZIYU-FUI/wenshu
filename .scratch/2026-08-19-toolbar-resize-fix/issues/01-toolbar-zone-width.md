# 01 — 区域模块顶/底栏用 zone 实际宽度 + 高度 30 PT 写死

**What to build:**
老板 2026-08-19 反馈: Sketch 区域模块 6 个 instance 的顶/底栏画穿了 splitter 溢出到隔壁 zone。改完应该是 — 顶/底栏用 zone 自己的真实宽度(不是父 band 总宽),高度保持 30 PT 写死,toolbar 内的 ICON 18 PT / 占位文字 13 PT / 分割线 2 PT 全保持 1:1 硬编码。改完 `swift build` clean(exit 0),让老板自己 `swift run WenshuApp` 验。

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

## Acceptance criteria

- [ ] ZoneModule 内部顶/底栏宽度用 zone 自己的真实宽度(不是父 band `totalW`)
- [ ] ZoneTopToolbar / ZoneBottomToolbar 高度保持 30 PT 写死(不推翻 v0.15 ticket 008 死原则)
- [ ] toolbar 内 ICON 18 PT / 占位文字 13 PT / 分割线 2 PT 全 1:1 硬编码保持不变
- [ ] 6 个区域模块 instance 各自 toolbar 独立渲染,不画穿 splitter
- [ ] `swift build` clean (exit 0)
- [ ] macOS chrome 52 PT / LayoutTokens 设计基准 1600×980 / bandH 比例算子 / D_v + D_h 拖拽线 全保持不动
- [ ] 不引入新组件(复用 ZoneModule / ZoneTopToolbar / ZoneBottomToolbar)
- [ ] agent 不跑 Q22 screencapture -l(无 Screen Recording TCC 授权),只跑 build clean + code-review 两轴

## 实现层选项(老板 ticket review 时拍)

- A: SwiftUI GeometryReader 拿 zone.frame.width,传给 ZoneTopToolbar / ZoneBottomToolbar
- B: 改 `.frame(width: totalW, height: 30)` → `.frame(maxWidth: .infinity, height: 30)`,让 SwiftUI 自动撑 zone 宽度(Apple HIG)
- C: 改上 / 下 band HStack,显式算 zone 实际宽度传进 ZoneModule