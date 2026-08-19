# Spec — 拖拽线取消圆头 + 改用 Apple 系统色 (老板 2026-08-19 拍)

> Date: 2026-08-19
> Spec 走 po `to-spec` skill 7 段模板

## Problem Statement

老板 2026-08-19 拍 2 个修法:

1. **16:50 拍**: "取消早期实的拖拽线, 分割先圆头的要求" — Rectangle `.clipShape(.capsule)` 去掉
2. **18:15 拍**: "颜色用系统色" — `Color.black` 改用 Apple 系统 semantic color

老板 8/19 18:48 反馈: ".scratch/2026-08-19-toolbar-resize-fix/issues/02-splitter-no-capsule-system-color.md 写好了但没跑, 你忘拍了, 现在补跑"

从老板视角, 拖拽线应该是:
- 矩形不圆角 (Apple HIG 标准 divider 风格)
- 静态色 = 系统 divider 色 (dark/light 自动适配)
- hover 色 = 系统亮色 (跟 macOS 强调色一致)

## Solution

修 `NativeSplitter` (Sources/WenshuApp/Views/Layout/NativeSplitter.swift):

1. **删圆头** — Rectangle 后 `.clipShape(.capsule)` 去掉
2. **静态色改系统色** — `Color.black` → `Color(nsColor: .separatorColor)` (Apple HIG divider 色, dark/light 自适应)
3. **hover 改系统亮色** — `Color.accentColor.opacity(0.25)` → `Color(nsColor: .controlAccentColor).opacity(0.25)` (Apple HIG 系统亮色, dark/light 自适应)
4. **shadow 改** — `Color.accentColor.opacity(0.15)` → `Color(nsColor: .controlAccentColor).opacity(0.15)` (同上)

### 业务语言描述 (老板懂)

- 拖拽线不画圆角 = 矩形 (跟 macOS 系统 divider 一样)
- 静态 2 PT 颜色 = Apple 系统色 (dark/light 自动适配, 不写死)
- hover 4 PT 颜色 = Apple 系统亮色 (跟 macOS 强调色一致, dark/light 自动适配)

## User Stories

1. As 老板, I want 拖拽线不画圆头 (矩形), so that 跟 macOS 系统 divider 风格一致 (Apple HIG 真值)
2. As 老板, I want 拖拽线静态色用 Apple 系统 divider 色, so that dark/light mode 自动适配
3. As 老板, I want 拖拽线 hover 色用 Apple 系统亮色, so that 跟 macOS 强调色一致
4. As 老板, I want D_h / D_v 5 竖拖拽线都生效 (1 组件 NativeSplitter 改 1 处 = 6 根全改)
5. As 老板, I want `swift build` exit 0
6. As 老板, I want 拖拽线视觉 (4 PT hover 变粗 / 圆头矩形 / shadow) 全保持

## Implementation Decisions

- **NativeSplitter body Rectangle 链**:
  - 删 `.clipShape(.capsule)`
  - `.fill(isHovered ? Color(nsColor: .controlAccentColor).opacity(0.25) : Color(nsColor: .separatorColor))`
  - `.shadow(color: isHovered ? Color(nsColor: .controlAccentColor).opacity(0.15) : .clear, ...)`
- **DesignColor 改**:
  - L43 `DesignColor.splitterLine: Color = Color(nsColor: .black)` → 改 `Color(nsColor: .separatorColor)` (跟 NativeSplitter 静态一致)
  - L42 `DesignColor.accentBlue: Color = .accentColor` → 改 `Color(nsColor: .controlAccentColor)` (跟 NativeSplitter hover 一致)
- **StaticDividerHorizontal / StaticDividerVertical** (Sources/WenshuApp/Views/Layout/NativeSplitter.swift) — 同样改静态色 `Color.black` → `Color(nsColor: .separatorColor)`
- **不动**: toolbar 30 PT / 6 PT hit area / drag 逻辑 / D_h / D_v 5 范围 / cursor (backlog 02 待办)
- **不退化**: hover 4 PT 变粗 / shadow / 透明度 0.25 / 0.15

## Testing Decisions

- 仅 `swift build clean` (exit 0), 老板自己启 app 验
- 验证: 拖拽线不圆头 + 静态系统色 + hover 系统亮色

## Out of Scope

- 不动 macOS chrome 52 PT
- 不动 LayoutTokens / bandH / toolbar 宽度
- 不动 D_h / D_v 5 竖拖拽线拖动逻辑
- 不动 cursor (backlog 02 待办)
- 不重写 SplitterHitArea NSView
- 不动 macOS chrome / 系统设置 (颜色由 macOS 控制)

## Further Notes

- 老板 8/19 16:50 拍 "取消圆头" + 8/19 18:15 拍 "颜色用系统色" — 这两个修法一起跑 (一 commit)
- 老板 8/19 18:48 反馈 "你忘拍了" — 之前 .scratch/2026-08-19-toolbar-resize-fix/issues/02-splitter-no-capsule-system-color.md 写好了但没 commit, 老板看不到
- 跟 v0.16 ticket 06 cursor (backlog 02) / v0.16 ticket 07 设置菜单 是独立的 ticket
- 跟 backlog 03 / 04 (.scratch/2026-08-19-dh-fixes-3/backlog.md) 重复 — 这次直接实现, backlog 03 / 04 删除
- Apple HIG 真值 URL: https://developer.apple.com/documentation/appkit/nscolor/separatorcolor
- Apple HIG 真值 URL: https://developer.apple.com/documentation/appkit/nscolor/controlaccentcolor