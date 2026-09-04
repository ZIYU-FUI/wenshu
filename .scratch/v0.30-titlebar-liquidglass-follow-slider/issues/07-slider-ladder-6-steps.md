# Liquid Glass slider — 6-step ladder (Apple API complete set)

> Boss 2026-09-01 OOB: "现状 4 阶梯视觉差异不明显" + "slider 0-100 但实际只有 4 档 → UI 与映射错配" + "拖拽线没有适配" + "按 APPLE API 规则改" + "不和 Apple 冲突不考虑自定义".

## Boss's actual signal

1. **Visual difference between slider values is hard to perceive**.
   Current 4-step ladder (.ultraThin/.ultraThin/.regular/.thick) maps
   0.00-0.25 to the same .ultraThinMaterial (= 50% of slider range is
   visually identical). 0.75-1.00 maps to .thickMaterial (= 25% more
   range, visually identical). Effectively 2 distinct visuals, not 4.
2. **Slider 0-100 is mislabeled**. Settings shows 0-100% (= 21 step
   options at 5% granularity) but the underlying mapping has only 4
   distinct values. The slider UI implies 21 choices; the code has 4.
3. **Divider line does not adapt** to the slider. PaneNSController's
   WenshuSplitView.drawDivider reads the raw opacity value and maps
   it to NSColor.separatorColor alpha manually (= a 4th code path
   that bypasses the helper).

## Root cause

`Double.toLiquidGlassMaterial()` in `LiquidGlassOpacity.swift:74-83`
implements a CUSTOM 4-step ladder that:

- Reuses .ultraThinMaterial for two adjacent ranges (= loses visual
  resolution at 0.00-0.50)
- Caps at .thickMaterial (= no .ultraThickMaterial, which IS Apple
  API on macOS 27)
- Drops .thinMaterial entirely (= Apple documents 6 Materials)
- Drops .barMaterial entirely (= Apple documents it for matching
  system toolbar look; not needed for wenshu chrome but the omission
  suggests the helper was hand-rolled without checking Apple docs)

The 4-step custom ladder does not match either:
- Apple Material API completeness (6 materials available)
- The slider's 0-100 UX (slider UI implies 21 distinct options)

## Apple Material API completeness (Apple docs verification)

Per `developer.apple.com/documentation/swiftui/material`:
- `ultraThinMaterial` — A mostly translucent material
- `thinMaterial` — A material that's more translucent than opaque
- `regularMaterial` — A material that's somewhat translucent
- `thickMaterial` — A material that's more opaque than translucent
- `ultraThickMaterial` — A mostly opaque material
- `barMaterial` — A material matching the system toolbar style

6 distinct Materials on macOS 27 Tahoe. wenshu should use all 6.

## Fix design (= 4 atomic commits)

### Ticket 01 — LiquidGlassOpacity.swift: 6-step ladder (Apple API complete set)

Files touched: `Sources/WenshuApp/UI/LiquidGlassOpacity.swift` only.

Change: replace the 4-step custom ladder in `toLiquidGlassMaterial()`
with the canonical 6-step ladder (= Apple's 6 official Materials,
6 equal-width ranges):

```
[0.000, 0.166) → .ultraThinMaterial
[0.166, 0.333) → .thinMaterial
[0.333, 0.500) → .regularMaterial
[0.500, 0.666) → .thickMaterial
[0.666, 0.833) → .ultraThickMaterial
[0.833, 1.000] → .barMaterial
```

Rationale:
- Uses Apple API complete set (= 6 official Materials, all of
  `developer.apple.com/documentation/swiftui/material`). No custom
  Material introduced (= boss拍 "不和 Apple 标准冲突不考虑自定义").
- 6 equal-width ranges (= 1/6 each; minimal custom logic, the
  mapping is the Apple API enumeration).
- Each step is now a visually distinct Material (= no two adjacent
  ranges share a Material; previously 0.00-0.49 was collapsed to
  .ultraThinMaterial).
- Apple does NOT provide a programmatic "Material-for-fraction"
  helper; this ladder is the canonical workaround.

### Ticket 02 — App.swift Settings slider: step value + label

Files touched: `Sources/WenshuApp/App.swift` only.

Change:
- `Slider(value: $liquidGlassOpacity, in: 0.0...1.0, step: 0.05)` →
  `Slider(value: $liquidGlassOpacity, in: 0.0...1.0, step: 1.0/6.0)`
  (= 6 distinct positions: 0, 1/6, 2/6, 3/6, 4/6, 5/6, 1.0)
- Replace label "0% = 完全透明 · 50% = 默认 · 100% = 强烈玻璃" with
  "6 档阶梯（Apple Liquid Glass Material 完整集）· 0% = 最透 · 100% = 最不透明".
- Replace label "影响除标题栏外的所有液态玻璃界面元素..." unchanged.

Rationale: matches the helper's 6-step granularity. Slider step
`1.0/6.0 ≈ 0.1667` is the smallest fraction that lands on every
Material boundary; the percentage display shows "0/17/33/50/67/83/100"
when the user drags.

### Ticket 03 — PaneNSController divider line: use toLiquidGlassDividerAlpha helper

Files touched: `Sources/WenshuApp/Views/Layout/PaneNSController.swift`
+ `Sources/WenshuApp/UI/LiquidGlassOpacity.swift` (= atomic coupling:
helper + call site land together).

Current state (PaneNSController.swift L115-121): the divider reads
opacity directly via `UserDefaults.standard.double(forKey:
"wenshu.liquidGlassOpacity")` and maps it to `NSColor.separatorColor`
alpha with a single hand-rolled scale `0.5 * opacity` (= no Apple Material
mapping; the divider line is AppKit `NSColor`, not SwiftUI Material).

Change (PaneNSController side): replace the hand-rolled alpha scale
with `opacity.toLiquidGlassDividerAlpha()`.

Change (LiquidGlassOpacity side): add the helper to map the same 6
ranges to alpha values (kept consistent with the divider's visual
identity = hairline, not background):

```
[0.000, 0.166) → 0.5   (ultraThin)
[0.166, 0.333) → 0.6   (thin)
[0.333, 0.500) → 0.7   (regular)
[0.500, 0.666) → 0.85  (thick)
[0.666, 0.833) → 1.0   (ultraThick)
[0.833, 1.000] → 1.0   (bar)
```

Why 2 outputs from one ladder: AppKit divider line is `NSColor`
(not SwiftUI Material). Returning `CGFloat` lets the divider use
`NSColor.separatorColor.withAlphaComponent(alpha)`. The 6-step
ladder is the single source of truth (= Material + alpha are
both derived from it).

Why this lands in 1 commit: helper and call site are atomic-coupled
per boss 8/22 protocol (= if the helper lands without the call site,
the call site won't compile; if the call site lands without the
helper, the call site won't link).

### Ticket 04 — CONTEXT.md: document the 6-step ladder

Files touched: `CONTEXT.md` only.

Change: update the `LiquidGlassOpacitySlider` row's "4-step ladder"
description to "6-step ladder matching Apple Material API complete set".
List the 6 Material-to-range mapping.

## Acceptance criteria

1. Slider has 6 distinct positions (= 0, 17, 33, 50, 67, 83, 100%);
   no two adjacent positions produce the same Material.
2. AppStatusbar + RegionTabBar + RegionStatusBar + RegionContentBackground
   visibly transition across the 6 slider positions (Material
   changes at each step).
3. PaneNSController's divider line alpha follows the same 6-step
   ladder (visually consistent with the chrome around it).
4. Title bar still NOT affected (scope unchanged from prior PR).
5. No regression: persistence, live update, restart behavior unchanged.

## Out of scope (boss specified)

- Tint colors (= slider controls material, not tint; tint is a
  separate Material variant, see `.glassEffect(.regular.tint(...))`
  which is not the same as Material).
- Slider position labels beyond 6 distinct values (= each step
  IS visible; finer granularity would not add visible difference).

## Risks

- **Risk 1**: `.barMaterial` may visually differ from the expected
  Liquid Glass chrome (= bar material is system-toolbar-tuned; could
  look out of place on wenshu chrome). Mitigation: keep the bar
  mapping but visually verify in office; if .barMaterial looks wrong,
  remap the 0.84-1.00 range to .ultraThickMaterial (= effectively 5
  steps; document why we skip .bar).
- **Risk 2**: Existing users with stored slider value at a non-step
  boundary (= e.g. 0.5 default) continue to land on .regularMaterial
  (= unchanged). Stored values outside the new step boundaries (=
  e.g. user dragged to 0.6 before this fix) snap to .thickMaterial on
  next launch. Acceptable (= the slider UI itself did not snap).