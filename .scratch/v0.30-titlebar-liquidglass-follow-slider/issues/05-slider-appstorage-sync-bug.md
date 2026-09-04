# Slider @AppStorage sync bug — fix

> Boss 2026-09-01 OOB "B" = fix the Slider / @AppStorage sync bug
> discovered during Step 6 verification of v0.30-titlebar-liquidglass-follow-slider.
> Bug: Slider UI does not actively re-read `UserDefaults` when external
> tools (or another Settings window) write to `wenshu.liquidGlassOpacity`.

## Boss's actual signal

Step 6 verification showed:
- `defaults write com.wenshu.app wenshu.liquidGlassOpacity=0` → launch APP
- Settings window Slider UI shows **50%** (the @AppStorage default
  value), NOT 0.
- Drag the slider to 100% → `defaults read=1` ✓ (write direction works)
- Kill APP, launch again → Slider still shows 100% (last view state
  wins; UserDefaults is NOT re-read).

Two scenarios:
1. **External write via `defaults` CLI**: macOS UserDefaults daemon
   should notify the running app via KVO / NSNotification, but
   SwiftUI's @AppStorage does NOT automatically subscribe to those
   notifications in a cross-process / cross-source-of-truth way.
   (Standard SwiftUI limitation.)
2. **App restart**: on first init of `@AppStorage`, the property
   wrapper reads from UserDefaults. If UserDefaults has `1.0` stored,
   the wrapper returns `1.0`. If UserDefaults has NO entry (just
   defaults-delete'd), the wrapper returns the init value (0.5).
   The wrapper does NOT re-read UserDefaults on subsequent inits of
   the same View (it's a @StateStorage, not @State).

## Root cause hypothesis (= most likely)

`@AppStorage("...") private var x: Double = 0.5` returns 0.5 as the
init value when UserDefaults has no entry for the key. After the user
drags the slider, view state writes 1.0 to UserDefaults. On subsequent
inits (e.g. switching Settings tabs, re-opening Settings window),
SwiftUI may or may not re-read UserDefaults depending on View identity.

The empirical observation that `defaults write=0` is ignored after a
fresh launch (= Slider shows 50%, not 0%) suggests the **init value
takes precedence** in some code path. Possible explanation: SwiftUI's
@AppStorage might be using a *cached* UserDefaults value (or the
View is being re-rendered from a cached state).

## Fix design

Replace the `@AppStorage` slider binding with an `@State` mirror that
explicitly reads UserDefaults on view init + onAppear + listens for
`UserDefaults.didChangeNotification`. The mirror writes back to
UserDefaults on slider drag and posts `.liquidGlassOpacityChanged`.

### Why this is the right fix

- @AppStorage's silent failure to re-read UserDefaults is a known
  SwiftUI limitation (= documented in Apple's developer forums; the
  property wrapper is optimized for "one View, one read, then
  write-back" — it is NOT a two-way sync).
- A 6-line manual @State + UserDefaults.didChange observer matches the
  existing `.liquidGlassOpacityChanged` notification pattern (= the
  non-SwiftUI AppKit consumers like WenshuSplitView already listen
  to that notification).
- No third-party library needed (= Apple Foundation + SwiftUI
  stdlib; matches AGENTS.md §11.1 "default = Apple stack exclusive").

## Acceptance criteria

1. **External write to UserDefaults propagates to Slider UI**:
   - `defaults write com.wenshu.app wenshu.liquidGlassOpacity=0`
   - Launch APP
   - Open Settings → 通用 → Liquid Glass slider shows **0%** (not 50%)
2. **Drag slider writes UserDefaults** (already works):
   - Drag slider to 50% → `defaults read=0.5` ✓
3. **Live preview during drag**:
   - During slider drag, AppStatusbar + RegionTabBar + RegionContentBackground
     immediately reflect the new opacity (already works via existing
     `\.liquidGlassOpacity` environment).
4. **Reactive to other writers**:
   - From a terminal, `defaults write com.wenshu.app wenshu.liquidGlassOpacity=1`
     while APP is running → Settings slider UI updates to 100% within 1 second.
5. **Restart preserves last value**:
   - Set slider to 75%, kill APP, relaunch → Slider shows 75%.
6. **No regression**: other @AppStorage keys (appearanceMode, llm.model,
   etc.) unchanged.

## Implementation plan (Q34 step 4 = 1 atomic commit)

### Ticket 01 — Manual @State mirror replaces @AppStorage for liquidGlassOpacity slider

Files touched: `Sources/WenshuApp/App.swift` only (= the
`SettingView.generalTab` Section("液态玻璃") block).

Change:
- Replace `@AppStorage("wenshu.liquidGlassOpacity") private var liquidGlassOpacity: Double = 0.5`
  with `@State private var liquidGlassOpacity: Double = UserDefaults.standard.double(forKey: "wenshu.liquidGlassOpacity")` (init from explicit UserDefaults read).
- Add `.onAppear { liquidGlassOpacity = UserDefaults.standard.double(forKey: "...") }` (handles the case where Settings window opens after external UserDefaults write).
- Add `UserDefaults.didChangeNotification` observer in `task` / `onAppear` that re-reads UserDefaults and updates `liquidGlassOpacity` (handles external writes during APP running).
- Slider binding `$liquidGlassOpacity` now writes back to UserDefaults via `.onChange(of: liquidGlassOpacity) { newValue in UserDefaults.standard.set(newValue, forKey: "..."); NotificationCenter.default.post(name: .liquidGlassOpacityChanged, object: nil) }`.
- Display "0% / 50% / 100%" labels continue to read `$liquidGlassOpacity`.

Rationale:
- The other root view (`@AppStorage("wenshu.liquidGlassOpacity")` in
  the main `WenshuApp` struct for environment injection) is kept
  unchanged (= it reads UserDefaults on its own init; downstream
  views like RegionTabBar read via `\.liquidGlassOpacity` env which
  is already reactive).
- This pattern matches the existing `.liquidGlassOpacityChanged`
  notification usage in `WenshuSplitView.drawDivider` (= AppKit
  non-SwiftUI consumers already listen).

### Ticket 02 — Domain-modeling commit (Q34 step 7)

Files touched: `CONTEXT.md` only.

Change: update the `LiquidGlassOpacitySlider` CONTEXT row to document
the sync pattern (= "Settings slider uses manual @State + UserDefaults
listener; other consumers (env-injected chrome) read the same key via
"@AppStorage property wrapper + `\.liquidGlassOpacity` environment
value").

### Ticket 03 — H-3 forward-fix commit (if needed)

If ticket 01's commit body contains CJK boss OOB quote (= likely yes,
since boss said "B" in CJK), follow H-3 forward-fix protocol.

## Pre-flight checklist (= before implementation)

- [ ] Verify `UserDefaults.didChangeNotification` API (= Apple Foundation
  standard notification; well-documented).
- [ ] Verify the root view's `\.liquidGlassOpacity` env injection still works
  after the Settings slider change (= the root view's @AppStorage is
  independent; should not be affected).
- [ ] Verify SwiftUI `Slider` with manual `@State` binding behaves the same
  as with `@AppStorage` (= standard Apple SwiftUI).

## Risks

- **Risk 1**: Two `@AppStorage("wenshu.liquidGlassOpacity")` instances now
  coexist (= root view's for env injection, plus the new @State mirror
  in SettingView). They both read from the same UserDefaults key, so
  no divergence — but if the env-injected value lags the slider by one
  frame, there's a brief flicker. Mitigation: the root view re-injects
  env whenever `wenshu.liquidGlassOpacityChanged` fires (= which we
  post on slider drag). The slider's local @State mirrors UserDefaults
  within the same runloop cycle, so the env injection fires immediately.
- **Risk 2**: UserDefaults.didChangeNotification fires for EVERY change
  to UserDefaults (= not just our key). Filter the callback to only
  re-read when our key changes. Simplest: just always re-read our key
  on every notification (= cheap, idempotent).

## Out of scope

- Other @AppStorage keys in SettingView (= appearanceMode, llm.model,
  etc.) — not reported as broken; do not touch.
- A general fix for SwiftUI @AppStorage sync (= outside this scope; if
  the same bug appears elsewhere, file a separate ticket).