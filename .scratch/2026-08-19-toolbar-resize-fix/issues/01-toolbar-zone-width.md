# 01 — Toolbar 宽度由 VStack stretch 撑 zone 实际宽度 (v0.16 ticket 01)

**What to build:**
老板 2026-08-19 拍 "区域模块组件实现的有问题, 顶栏/底栏放在区域模块内, 随区域模块尺寸变化"

改完: 顶栏 / 底栏不传 totalW 宽度, VStack 子 view 默认 stretch 全宽, 自动撑 zone 实际宽度

**Blocked by:** None

**Status:** done — commit ae5bbf82e (老板 8/19 验过 pass)

## Acceptance criteria

- [x] ZoneTopToolbar 删 totalW 参数
- [x] ZoneBottomToolbar 删 totalW 参数
- [x] 内部不 .frame(width:)
- [x] 高度 30 PT / ICON 18 PT / 占位文字 13 PT / 分割线 2 PT 全保持
- [x] 6 个 zone 都生效 (sidebar / preview / editor / tools / chat / dynamic)
- [x] swift build exit 0
- [x] 老板 8/19 实测验过 pass