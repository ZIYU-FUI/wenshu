# Ticket 01 — AppStatusbar reads Liquid Glass opacity slider

> Component of: v0.30-titlebar-liquidglass-follow-slider (= boss 2026-09-01
> OOB "标题栏的液态玻璃透明度没有跟随设置中的参数" + clarification "让标题栏
> 跟随系统，不跟随设置" + clarification "现在设置面板里的设置，影响除标题栏
> 外，文枢的所有前端 UI").

## Scope (= this file only)

`Sources/WenshuApp/UI/AppStatusbar.swift`.

## Change (= 2 hunks in the same file)

1. **Add env read** (in `AppStatusbar` body, top):
   ```swift
   @Environment(\.liquidGlassOpacity) private var liquidGlassOpacity: Double
   ```
   Same pattern as `RegionTabBar.swift:79` / `RegionStatusBar.swift:145`.

2. **Replace hardcoded material** (line 172 in current file):
   - Before: `.background(.regularMaterial)`
   - After:  `.background(liquidGlassOpacity.toLiquidGlassMaterial())`

## Why this is the right fix

Boss's scope clarification: "现在设置面板里的设置，影响除标题栏外，文枢的
所有前端 UI" (= the slider controls every wenshu UI surface except the title
bar). `AppStatusbar` (= the bottom strip with model + status + version) is a
wenshu frontend UI surface (= NOT a macOS native chrome), so it must follow
the slider. The existing `Double.toLiquidGlassMaterial()` helper already
exists in `LiquidGlassOpacity.swift:74-83` and is used by RegionTabBar +
RegionStatusBar + RegionContentBackground (= single source of truth).

The title bar (.windowToolbarStyle(.unified)) is intentionally NOT touched
by this ticket (= follows macOS System Settings, per boss clarification
"让标题栏跟随系统，不跟随设置").

## Acceptance criteria

- [ ] `swift build` exit 0
- [ ] `swift test` exit 0 (no regressions)
- [ ] Slider at 0% → AppStatusbar visually becomes near-see-through
  (= .ultraThinMaterial)
- [ ] Slider at 100% → AppStatusbar visually becomes strong tint
  (= .thickMaterial)
- [ ] Slider mid-range → AppStatusbar follows the same 4-step ladder as
  RegionTabBar + RegionStatusBar
- [ ] Title bar (.unified) is NOT affected by the slider (= unchanged
  regardless of slider value)
- [ ] Live update: dragging the slider in Settings updates AppStatusbar
  in real time without app restart

## Out of scope (= other tickets)

- AppTitlebar cleanup (= dead code in live path; Rule 1 future cleanup)
- Settings panel tooltip (= ticket 02)
- CONTEXT.md update (= ticket 03)

## Risk

- **Risk**: `AppStatusbar.swift:172` currently uses `.regularMaterial`
  (= slider=0.5 default). For users whose stored slider value is NOT
  0.5, the visual changes immediately on next launch. This is the
  desired behavior per boss拍 scope clarification.