# 01 — Delete .preferredColorScheme(.dark) + add Settings dialog + @AppStorage three-state persistence

**What to build:**
v0.17 dark and light mode end-to-end. After change:
1. Delete `.preferredColorScheme(.dark)` in `App.swift`
2. Add SwiftUI `Settings` Scene (bound to cmd+,), containing `Picker("Appearance", selection: $appearanceMode)` three states (system / dark / light)
3. Use `@AppStorage("appearanceMode")` for persistence (Apple UserDefaults wrapper)
4. App top-level WindowGroup switch to `.preferredColorScheme(vm.colorScheme)`, vm reads from @AppStorage

All colors stay with existing Apple Semantic (`Color(nsColor: .systemFoo)`), no hard-coded RGB. After change `swift build` clean (exit 0), let 老板 self-launch app + switch system + switch Settings to verify.

**Blocked by:** None — can start immediately.
**Status:** ready-for-agent

## Acceptance criteria

- [ ] Delete `.preferredColorScheme(.dark)` force dark
- [ ] Add SwiftUI `Settings { ... }` Scene (Apple HIG standard, bound to cmd+,)
- [ ] Settings contains `Picker("Appearance", selection: $appearanceMode)` three states: follow system / dark / light
- [ ] Use `@AppStorage("appearanceMode")` for persistence (Apple UserDefaults wrapper)
- [ ] App top-level WindowGroup switch to `.preferredColorScheme(vm.colorScheme)` so @AppStorage decides
- [ ] Default "follow system" (system), no force dark
- [ ] All colors remain Apple Semantic Color (`Color(nsColor: ...)`), no hard-coded RGB
- [ ] No new design token file (no two color sets)
- [ ] `swift build` clean (exit 0)
- [ ] Do not touch 6-zone layout / splitters / toolbar / WenshuLibrary / Domain models
- [ ] Agent does not run Q22 screencapture -l (no Screen Recording TCC authorization)