# Spec — Splitter remove rounded caps + use Apple system color (老板 2026-08-19 拍)

> Date: 2026-08-19
> Spec uses po `to-spec` skill 7-section template

## Problem Statement

老板 2026-08-19 拍 2 fixes:
1. **16:50 拍**: "remove earlier-implemented splitter, divider first rounded caps requirement" — Rectangle `.clipShape(.capsule)` removed
2. **18:15 拍**: "color use system color" — `Color.black` change to Apple system semantic color

老板 8/19 18:48 feedback: ".scratch/2026-08-19-toolbar-resize-fix/issues/02-splitter-no-capsule-system-color.md written but not run, you forgot 拍, now patch"

From 老板's perspective,  splitter should be:
- Rectangle not rounded (Apple HIG standard divider style)
- Static color = system divider color (dark/light auto-adapt)
- Hover color = system bright color (consistent with macOS accent color)

## Solution

Fix `NativeSplitter` (Sources/WenshuApp/Views/Layout/NativeSplitter.swift):
1. **Remove rounded caps** — Rectangle after `.clipShape(.capsule)` removed
2. **Static color change to system color** — `Color.black` → `Color(nsColor: .separatorColor)` (Apple HIG divider color, dark/light auto-adapt)
3. **Hover change to system bright color** — `Color.accentColor.opacity(0.25)` → `Color(nsColor: .controlAccentColor).opacity(0.25)` (Apple HIG system bright color, dark/light auto-adapt)
4. **Shadow change** — `Color.accentColor.opacity(0.15)` → `Color(nsColor: .controlAccentColor).opacity(0.15)` (same)

### Business-language description (老板 understands)

- Splitter not draw rounded corners = rectangle (same as macOS system divider)
- Static 2 PT color = Apple system color (dark/light auto-adapt, no hard-code)
- Hover 4 PT color = Apple system bright color (consistent with macOS accent color, dark/light auto-adapt)

## User Stories

1. As 老板, I want splitter not draw rounded caps (rectangle), so that consistent with macOS system divider style (Apple HIG truth)
2. As 老板, I want splitter static color use Apple system divider color, so that dark/light mode auto-adapt
3. As 老板, I want splitter hover color use Apple system bright color, so that consistent with macOS accent color
4. As 老板, I want D_h / D_v 5 vertical splitters all effective (1 component NativeSplitter change 1 place = 6 all change)
5. As 老板, I want `swift build` exit 0
6. As 老板, I want splitter visual (4 PT hover thicker / rounded rectangle / shadow) all preserved

## Implementation Decisions

- **NativeSplitter body Rectangle chain**:
  - Remove `.clipShape(.capsule)`
  - `.fill(isHovered ? Color(nsColor: .controlAccentColor).opacity(0.25) : Color(nsColor: .separatorColor))`
  - `.shadow(color: isHovered ? Color(nsColor: .controlAccentColor).opacity(0.15) : .clear, ...)`
- **DesignColor change**:
  - L43 `DesignColor.splitterLine: Color = Color(nsColor: .black)` → change to `Color(nsColor: .separatorColor)` (consistent with NativeSplitter static)
  - L42 `DesignColor.accentBlue: Color = .accentColor` → change to `Color(nsColor: .controlAccentColor)` (consistent with NativeSplitter hover)
- **StaticDividerHorizontal / StaticDividerVertical** (Sources/WenshuApp/Views/Layout/NativeSplitter.swift) — same change static color `Color.black` → `Color(nsColor: .separatorColor)`
- **Untouched**: toolbar 30 PT / 6 PT hit area / drag logic / D_h / D_v 5 range / cursor (backlog 02 todo)
- **Don't regress**: hover 4 PT thicker / shadow / opacity 0.25 / 0.15

## Testing Decisions

- Only `swift build clean` (exit 0), 老板 self-launches app to verify
- Verify: splitter not rounded caps + static system color + hover system bright color

## Out of Scope

- Do not touch macOS chrome 52 PT
- Do not touch LayoutTokens / bandH / toolbar width
- Do not touch D_h / D_v 5 vertical splitter drag logic
- Do not touch cursor (backlog 02 todo)
- Do not rewrite SplitterHitArea NSView
- Do not touch macOS chrome / system settings (color controlled by macOS)

## Further Notes

- 老板 8/19 16:50 拍 "remove rounded caps" + 8/19 18:15 拍 "color use system color" — these two fixes run together (one commit)
- 老板 8/19 18:48 feedback "you forgot 拍" — previously .scratch/2026-08-19-toolbar-resize-fix/issues/02-splitter-no-capsule-system-color.md written but not committed, 老板 can't see
- Independent from v0.16 ticket 06 cursor (backlog 02) / v0.16 ticket 07 settings menu
- Duplicate with backlog 03 / 04 (.scratch/2026-08-19-dh-fixes-3/backlog.md) — this time directly implement, backlog 03 / 04 delete
- Apple HIG truth URL: https://developer.apple.com/documentation/appkit/nscolor/separatorcolor
- Apple HIG truth URL: https://developer.apple.com/documentation/appkit/nscolor/controlaccentcolor