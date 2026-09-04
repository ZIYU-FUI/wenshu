# Title bar Liquid Glass = follow macOS, not the wenshu Settings slider

> Captured 2026-09-01 (= boss 2026-09-01 OOB "标题栏的液态玻璃透明度，
> 没有跟随设置中的，液态玻璃设置的设置参数" + clarification "那你可以
> 让标题栏跟随系统，不跟随设置" + clarification "现在设置面板里的设置，
> 影响除标题栏外，文枢的所有前端 UI").

## Boss's actual OOB (= the core insight)

1. Title bar's Liquid Glass opacity does NOT follow the wenshu Settings
   slider (= user changes the slider, title bar stays unchanged).
2. Boss's fix decision: **title bar follows macOS system**, not the wenshu
   slider (= `.windowToolbarStyle(.unified)` already does this; System
   Settings → Accessibility → Display → Reduce transparency is the
   system-level knob).
3. Scope clarification: **the wenshu Settings slider now affects
   EVERYTHING EXCEPT the title bar** (= per-pane content background +
   per-region tab/status bar + custom AppStatusbar).

## Why title bar cannot follow the wenshu slider (= root cause)

The title bar is macOS-native (`.windowToolbarStyle(.unified)` per
App.swift:524, shipped in v0.28 followup round 12 boss拍 "全面适配液态玻璃").
Apple's unified titlebar chrome is system-managed; SwiftUI does NOT
expose a per-app API to set its Liquid Glass tint strength (= the
"伪 apple 官方" decision). The only way to change its strength is via
macOS System Settings (= `Appearance → Reduce transparency`, or the
"Increase contrast" toggle in Accessibility).

Three possible fixes were rejected:
- **Drop the native titlebar + add a custom AppTitlebar**. Rejected by
  boss 8/29 round 9 (= "没有在 mac 自带的标题栏上, 你是独立写了一个
  实现的, 导致上半区看起来有两层顶栏" = double titlebar = bad UX).
- **Use `.toolbarBackground(.clear, for: .windowToolbar)` to fully
  override the unified glass**. Rejected by boss 8/29 round 12 (=
  "全面适配液态玻璃" = adopt Apple Liquid Glass design language fully).
- **Set slider 0 → `.toolbarBackground(.clear, for: .windowToolbar)`,
  slider 1 → `.toolbarBackground(.regularMaterial, for: .windowToolbar)`**.
  Rejected = the title bar should follow the system, NOT the wenshu
  slider. Mixing system + app control is worse than either alone.

Final design = **leave the title bar alone** + scope the slider.

## Current state of Liquid Glass consumers (verified 2026-09-01)

| Component | Reads `\.liquidGlassOpacity` env? | Slider affects it? |
|---|---|---|
| `Sources/WenshuApp/UI/AppTitlebar.swift` body L132-139 | **NO** (hardcoded `Color(nsColor: .windowBackgroundColor)`) | **NO** ← bug surface, not touched by this spec |
| macOS native titlebar (`.windowToolbarStyle(.unified)` App.swift:524) | **N/A** (system-managed) | **NO** (= correct, follows macOS) |
| `Sources/WenshuApp/UI/AppStatusbar.swift` body L172 | **NO** (hardcoded `.background(.regularMaterial)`) | **NO** ← bug, this spec fixes it |
| `Sources/WenshuApp/UI/RegionTabBar.swift` body L107 | YES | YES |
| `Sources/WenshuApp/UI/RegionStatusBar.swift` body L156 | YES | YES |
| `Sources/WenshuApp/UI/RegionContentBackground.swift` body L94 | YES | YES |

Two bugs surface from the audit:
- **Bug A (this spec fixes)**: `AppStatusbar.swift` hardcodes
  `.regularMaterial` even though the slider is supposed to control it
  (per LiquidGlassOpacity.swift:74-83 docstring "extend Liquid Glass opacity
  slider mapping ... to ALSO cover the per-pane title bar / status bar /
  divider" — title bar is now system, but status bar IS supposed to follow).
- **Bug B (out of scope, documented for future)**: `AppTitlebar.swift`
  hardcodes `Color(nsColor: .windowBackgroundColor)`. With title bar
  delegated to macOS system, AppTitlebar is now a dead component in the
  visual tree (WenshuChromeOverlay.swift:49-58 removed it). No users of
  AppTitlebar in the live path. Rule 1 deletion candidate in a future
  cleanup ticket — not this spec's scope.

## What boss拍 scope (= the slider's reach)

| Surface | In scope (= slider affects) |
|---|---|
| Per-pane content background (`RegionContentBackground`) | ✓ |
| Per-region tab bar (`RegionTabBar` = 30 PT top chrome of each pane) | ✓ |
| Per-region status bar (`RegionStatusBar` = 30 PT bottom chrome) | ✓ |
| App-wide bottom status bar (`AppStatusbar` = the 30 PT bottom strip with model + status + version) | ✓ (= Bug A) |
| macOS native title bar (`.windowToolbarStyle(.unified)`) | ✗ (follows macOS System Settings) |
| Custom `AppTitlebar` (not in live path; deleted by round 9) | ✗ (dead code; Rule 1 future) |

The slider's full name in Settings should reflect this scope (= either
rename the label or add a sub-label explaining the title bar follows
macOS). Boss拍: leave the slider name alone; the title bar already looks
correct (= it follows the system), the user never noticed the slider was
supposed to affect the title bar until they saw the visual disconnect.

## Acceptance criteria (= what boss will verify)

1. **Slider at 0%**: every pane content + tab bar + per-region status
   bar + bottom AppStatusbar = `.ultraThinMaterial` (almost see-through).
   Title bar = whatever macOS System Settings says (= unchanged).
2. **Slider at 100%**: every pane content + tab bar + per-region status
   bar + bottom AppStatusbar = `.thickMaterial` (strong tint).
   Title bar = whatever macOS System Settings says.
3. **Slider mid-range**: 4-step ladder from `.ultraThinMaterial` →
   `.ultraThinMaterial` → `.regularMaterial` → `.thickMaterial` (= the
   existing `Double.toLiquidGlassMaterial()` helper).
4. **Live update**: drag the slider in Settings, the change reflects
   immediately without app restart.
5. **Persistence**: slider value persists across launches via the
   existing `@AppStorage("wenshu.liquidGlassOpacity")`.
6. **Title bar unchanged**: macOS System Settings → Appearance →
   Reduce transparency still controls the title bar (= independent of
   the wenshu slider).
7. **No regression**: per-pane tab bar / status bar / content background
   continue to follow the slider (= verified by the existing v0.28
   followup acceptance criteria).

## Implementation plan (Q34 8-step)

Per Q34.5.4, this is a small change; we use 3 atomic commits:

### Ticket 01 — AppStatusbar reads the slider

Files touched: `Sources/WenshuApp/UI/AppStatusbar.swift` only.

Change: add `@Environment(\.liquidGlassOpacity) private var liquidGlassOpacity: Double`
to `AppStatusbar`, then replace the hardcoded
`.background(.regularMaterial)` (line 172) with
`.background(liquidGlassOpacity.toLiquidGlassMaterial())`.

Rationale: same pattern as `RegionTabBar` (= env-key + helper), single
source of truth via `Double.toLiquidGlassMaterial()`.

### Ticket 02 — Settings panel tooltip documents the scope

Files touched: `Sources/WenshuApp/App.swift` only (= the Settings scene,
around line 668 where `@AppStorage("wenshu.liquidGlassOpacity")` is
declared).

Change: add a small `.help(...)` (or sub-label) under the slider explaining
"影响除标题栏外的所有液态玻璃界面元素。标题栏跟随 macOS 系统设置
(系统设置 → 辅助功能 → 显示 → 减少透明度)".

Rationale: prevent user confusion next time (= boss found this bug
because there was no scope hint in the UI).

### Ticket 03 — Domain-modeling commit (Q34 step 7)

Files touched: `CONTEXT.md` only.

Change: update the Liquid Glass slider row to document the actual scope
(= per-pane content + per-region chrome + AppStatusbar; NOT title bar).

## Pre-flight checklist (= before implementation)

- [ ] Verify `Double.toLiquidGlassMaterial()` helper exists and is
  exported (yes, verified at `Sources/WenshuApp/UI/LiquidGlassOpacity.swift:74`).
- [ ] Verify `\.liquidGlassOpacity` env is injected by the root view
  (yes, App.swift:1284 `.liquidGlassOpacityEnvironment(liquidGlassOpacity)`).
- [ ] Verify `AppStatusbar` is in the environment scope (= sits inside
  `WenshuChromeOverlay` body which is inside the root view's modifier
  chain; YES verified at WenshuChromeOverlay.swift:66).
- [ ] Verify the Settings scene uses a SwiftUI standard slider pattern
  (`Slider` with a label) so `.help(...)` is the natural API.

## Risks

- **Risk 1**: AppStatusbar already hardcodes `.regularMaterial` (= the
  slider=0.5 default). After the fix, if a user already had slider=0.5
  set, the visual is unchanged. Users with slider=0 (fully transparent)
  see AppStatusbar become see-through (consistent with the rest of the
  pane chrome). This is the desired behavior per boss拍.
- **Risk 2**: The macOS native title bar IS Liquid Glass (= system
  managed). Users might still expect the wenshu slider to affect it.
  Mitigation: ticket 02 adds the help text.
- **Risk 3**: AppTitlebar is dead code in the live path but still in the
  codebase. Rule 1 deletion is deferred (= the file might be referenced
  from a test or from a commented-out import; a separate ticket is safer).

## What this spec does NOT solve (= deferred)

- AppTitlebar Rule 1 deletion (= file still in repo, no live callers in
  the live path, but worth a separate cleanup ticket to verify zero
  references).
- Liquid Glass tint color (= the slider only controls material strength,
  not tint hue). Out of scope per boss拍 "液态玻璃" (= generic material,
  not "colored glass").
- Per-pane individual opacity sliders (= one slider for the whole app).
  Out of scope (= boss拍 "现有已经实现的范围 0-100").