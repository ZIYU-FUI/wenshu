# v0.30 Title Bar + Divider Transparency Spec

Boss 2026-09-01 OOB: title bar (= the 30 PT chrome at the top of each pane) is fully transparent and does not follow the Liquid Glass opacity slider. NSSplitView's default divider is also fully opaque (= no transparency at all).

Boss OOB goal: both the title bar AND the drag divider should follow the user's Liquid Glass opacity setting (= `wenshu.liquidGlassOpacity` AppStorage slider in Settings -> 通用).

## Background

### Current state (= v0.30 HEAD)

| Surface | Current visual | Source |
|---|---|---|
| Title bar (RegionTabBar) | `.background(.regularMaterial)` (= fixed) | `Sources/WenshuApp/UI/RegionTabBar.swift` L101 |
| Status bar (RegionStatusBar) | `.background(.regularMaterial)` (= fixed) | `Sources/WenshuApp/UI/RegionTabBar.swift` L142 |
| Pane content background | 4-step mapping (`Color.clear` / `.ultraThinMaterial` / `.regularMaterial` / `.thickMaterial`) | `Sources/WenshuApp/UI/RegionContentBackground.swift` L94-105 |
| NSSplitView divider | Default `.thin` (= opaque gray) | `Sources/WenshuApp/Views/Layout/PaneNSController.swift` (= never set, uses NSSplitView default) |

The pane content background already follows the slider (= committed in v0.28 followup Boss UX round 49). The title bar + status bar + divider do NOT.

### Boss OOB verbatim

> 标题栏现在完全透明，让标题栏跟谁设置中的，液态玻璃透明度的设置项。拖拽线现在也是完全透明，也让其跟随液态玻璃透明度的设置项试一下效果。

English paraphrase: the title bar (= 标题栏) is currently fully transparent. Make the title bar follow the Liquid Glass opacity slider in Settings. The drag divider (= 拖拽线) is also currently fully transparent. Make the divider also follow the Liquid Glass opacity slider (= try the effect).

## Acceptance criteria

1. Title bar (RegionTabBar) reads `\.liquidGlassOpacity` from environment and maps to 4 materials (matching RegionContentBackground's mapping).
2. Status bar (RegionStatusBar) reads `\.liquidGlassOpacity` and uses the same 4-step mapping.
3. NSSplitView divider renders with alpha = `liquidGlassOpacity` (= from AppStorage via the same slider).
4. All four liquidGlassOpacity ranges (0-0.24, 0.25-0.49, 0.50-0.74, 0.75-1.00) produce visibly different title bar / divider visual results.
5. No regression: title bar still 30 PT tall, status bar still 30 PT tall, divider still 1 PT wide, layout still 6-zone FCP default.

## Implementation plan

### Ticket 1: Title bar + status bar follow slider

File: `Sources/WenshuApp/UI/RegionTabBar.swift`

Change:
- RegionTabBar.body: read `@Environment(\.liquidGlassOpacity)`, replace `.background(.regularMaterial)` with a switch on `liquidGlassOpacity` using the same 4-material mapping as `RegionContentBackground`.
- RegionStatusBar.body: same change.
- Extract the 4-step mapping into a shared function (= dedupe with `RegionContentBackground`).

New helper:
- Add `static func regionChromeMaterial(opacity: Double) -> Material` to `LiquidGlassOpacity.swift` (= returns the Material for the given opacity). Use it in both `RegionContentBackground`, `RegionTabBar`, `RegionStatusBar`.

### Ticket 2: NSSplitView divider follows slider

File: `Sources/WenshuApp/Views/Layout/PaneNSController.swift`

Approach options:
- (A) Set `splitView.dividerStyle = .thin` (= Apple standard 1 PT) + override `effectiveRect(for:of:)` to widen the drag hit area (= already done). NOT custom paint. Use AppKit's built-in thin divider (= already semitransparent on macOS 27 = looks correct).
- (B) Set `splitView.dividerStyle = .none` (= invisible) + draw a custom 1 PT hairline at each divider position via `splitView.subviews` (= more work, more risk).

Decision: (A). Apple `.thin` divider on macOS 27 is already a semitransparent hairline that adapts to dark/light mode. We do NOT need to override its color.

For the opacity slider: pass `wenshu.liquidGlassOpacity` via a notification observer in `PaneNSController` (= set divider alpha or hide / show dividers based on slider).

Implementation:
- On `viewDidLayout`: set `splitView.dividerStyle = .thin` (= Apple canonical hairline).
- Observe `liquidGlassOpacityChanged` notification: read `wenshu.liquidGlassOpacity` from UserDefaults, apply divider alpha via a custom NSSplitView subclass OR set `dividerStyle = .none` at opacity 0 (= fully transparent divider).
- Use the same 4-step mapping: opacity 0 = `.none` (invisible), opacity 0.5 = `.thin` (canonical), opacity 1.0 = `.thin` (canonical, no need for thick).

### Ticket 3: Verify slider changes propagate live

- Settings panel: change slider, observe title bar + divider update in real time (no app restart).
- AppStorage-backed `wenshu.liquidGlassOpacity` already posts `liquidGlassOpacityChanged` notification on change (= committed in v0.28 followup round 49).
- PaneNSController observes the notification + RegionTabBar / RegionStatusBar read `@Environment` (= SwiftUI re-renders on env change automatically).

## Out of scope

- Window title bar (= the topmost OS-level title bar with the close/min/max buttons) — boss did NOT mention this, only the per-pane chrome (= 标题栏 here means the 30 PT per-pane tab bar, not the macOS window chrome).
- Sidebar / preview / editor / tools / chat / dynamic pane content — already covered by `RegionContentBackground`.

## Files modified (= this feature)

- `Sources/WenshuApp/UI/LiquidGlassOpacity.swift` — add `regionChromeMaterial(opacity:)` helper
- `Sources/WenshuApp/UI/RegionContentBackground.swift` — refactor to use the new helper
- `Sources/WenshuApp/UI/RegionTabBar.swift` — read env + use helper for title bar + status bar
- `Sources/WenshuApp/Views/Layout/PaneNSController.swift` — set `dividerStyle = .thin`, observe notification, hide at opacity 0

## Files NOT modified

- `Sources/WenshuApp/Views/Settings/...` — slider already exists, no UI changes
- `Sources/WenshuApp/Views/Workspace/...` — pane content uses `RegionContentBackground` already
- All other files

## Verification (= Q22 proof)

1. `swift build` exit 0
2. Launch with default `wenshu.liquidGlassOpacity = 0.5` (= existing default) — title bar / divider look as before
3. Set `defaults write com.wenshu.app wenshu.liquidGlassOpacity -float 0.0` — title bar / divider become invisible (boss OOB "完全透明")
4. Set to `1.0` — title bar / divider become full strength (`.thickMaterial` background / `.thick` divider)
5. Set back to `0.5` — title bar / divider look as before
6. Save screenshot at each setting (= 0.0 / 0.25 / 0.5 / 0.75 / 1.0) for boss review

## Risks

- Setting `dividerStyle = .thin` on macOS 27 = visually correct. On older macOS versions (= less than 27 = unlikely given `Platform = .v27`), `.thin` may render differently. Acceptable per `Platform = .v27`.
- `@Environment(\.liquidGlassOpacity)` is a custom key, not Apple-blessed. If a future SwiftUI version adds its own `.glassMaterialStrength` (= speculation), we may need to migrate. Acceptable for v0.30.

## Precedent (= v0.28 followup round 49)

The Liquid Glass opacity slider + environment key + 4-material mapping pattern is already established in v0.28 followup round 49 (= see `.scratch/v0.28-liquid-glass-opacity-slider/spec.md`). This feature extends that pattern to title bar + status bar + divider (= three surfaces that were missed in round 49).