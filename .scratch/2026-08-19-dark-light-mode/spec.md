# Spec — v0.17 Dark / Light Mode overall support (老板 2026-08-19 拍)

> Branch: `v0.17-dark-light-mode`
> Truth source: Apple HIG Color (developer.apple.com/design/human-interface-guidelines/color)
> Use po `to-spec` 7-section template

## Problem Statement

wenshu currently forces dark mode via `.preferredColorScheme(.dark)` in `App.swift`. 老板 2026-08-19 拍: **implement dark and light mode end-to-end**. Meaning:
1. By default, respect the macOS system setting (auto-switch with system dark / light)
2. 老板 can manually override inside the App (force dark / force light / follow system)
3. Override option persists (restored on next launch)

From 老板's perspective: regardless of whether macOS system is dark or light, wenshu must render correctly, must not break Apple HIG color semantics, must not hard-code RGB.

## Solution

- **Delete** `.preferredColorScheme(.dark)` force-dark
- **Add** Settings dialog (cmd+,) menu item — 老板 can switch among "follow system / dark / light" three states
- **Persist** — write to UserDefaults, read back on launch
- **Colors** — keep all existing Apple Semantic Color (`Color(nsColor: .windowBackgroundColor / .controlBackgroundColor / .separatorColor / .controlAccentColor)` etc.), dark / light auto-adapts, no new hard-coded colors
- **WenshuLibrary / LayoutShellViewModel** — untouched (unrelated to appearance)

## User Stories

1. As 老板, I want wenshu to follow the macOS system dark/light setting by default, so that switching the system switches wenshu
2. As 老板, I want wenshu to not force dark mode (currently `.preferredColorScheme(.dark)`), so that when the system is in light mode, wenshu is also light
3. As 老板, I want the Settings dialog (cmd+,) to have an Appearance option (follow system / dark / light three states), so that I can override the system inside the App
4. As 老板, I want my appearance option to persist (UserDefaults), so that restarting wenshu restores my choice
5. As 老板, I want the dark/light switch to not affect the 6-zone layout / splitters / zone modules / top-bottom toolbar functions, so that switching appearance does not break the layout
6. As 老板, I want all colors to remain Apple Semantic (`Color(nsColor: ...)` bridge), so that dark/light auto-adapts without writing two sets of design tokens
7. As 老板, I want `swift build` clean (exit 0), so that I can launch the app myself to verify

## Implementation Decisions

- **Appearance state machine**: 3 states (`system` / `dark` / `light`), persisted with SwiftUI `@AppStorage` (Apple-recommended UserDefaults wrapper, auto dark/light sync)
- **Settings dialog**: Use SwiftUI `Settings` Scene (Apple HIG standard, auto-binds cmd+,), containing `Picker("Appearance", selection: ...)` three-way
- **App top level**: No longer use `.preferredColorScheme(.dark)`. Switch to `.preferredColorScheme(vm.colorScheme)` decided by `@AppStorage`
- **Colors**: All `Color(nsColor: .systemFoo)`, already compliant, unchanged
- **Testing**: Only `swift build` clean + 老板 self-launches app to verify (Q5 老板 拍 not run Q22)
- **No new components**: prefer built-in SwiftUI `Settings` scene + `@AppStorage` + `Picker`

## Testing Decisions

- **Test scope**: Only build clean (exit 0). No unit tests (this ticket is UI / system integration layer)
- **Truth verification**: 老板 self-launches app + switches system dark/light + switches Settings dialog "follow system / dark / light" to verify
- **Acceptance criteria**:
  - `swift build` exit 0
  - Delete `.preferredColorScheme(.dark)`, replace with `.preferredColorScheme(vm.colorScheme)`
  - Settings dialog cmd+, opens
  - Picker three states switchable + restored on restart
## Out of Scope

- **Do not** change 6-zone layout / splitters / toolbar / WenshuLibrary / Domain models (this ticket only touches appearance state + App top level)
- **Do not** change v0.16 ticket 01 (toolbar width) + 02 (splitter rounded caps) — they live on main branch, this branch is independent
- **Do not** add new design token file (no two color sets, all go through Apple Semantic)
- **Do not** add appearance switch animation (Apple HIG defaults to instant switch, no animation needed)
- **Do not** run Q22 screencapture -l (no Screen Recording TCC authorization)

## Further Notes

- **Branch**: `v0.17-dark-light-mode` independent from v0.16 toolbar / splitter fixes on main
- **State machine**: 3 states `system` / `dark` / `light`, default `system`
- **Dependency**: macOS 13+ (Ventura) `Settings` Scene (Apple HIG)
- **Persistence**: SwiftUI `@AppStorage("appearanceMode")` auto UserDefaults
- 老板 has finished Q9-Q13, frontier cleared, can go straight to to-tickets → implement