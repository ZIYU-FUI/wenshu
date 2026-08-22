# 01 — Menubar + Settings popup working (老板 2026-08-21 ruled "execute the full master chain strictly")

**What to build:**
老板 8/21 20:30 macOS verification: the settings popup exists (floating over the original windows), but the popup's contents are non-functional — there's no system-appearance switching (= `SettingView` was not installed into the SwiftUI-default-managed standard settings window).

**Blocked by:** None.

**Status:** ready-for-agent

## Fix specification (3 steps, satisfying principles 1 + 3 + 4 + 5)

Execute the po main flow's 6 steps strictly (老板 8/19 evening ruled streak + 8/21 ruled "yesterday's master full-chain execution was very efficient"):

1. **grill**: 老板's macOS 8/21 20:30 feedback = settings sheet is blank (`SettingView` fails to render)
2. **to-spec**: `.scratch/2026-08-21-menubar-v2/spec.md` landed
3. **to-tickets**: this file
4. **implement (1 ticket 1 commit)**: fix the root cause
   - Run build to verify `SettingView` installed into `Settings { }` Scene
   - 老板 macOS verification of `SettingView` rendering (Appearance + Model Picker display)
5. **code-review (dual-axis)**: dispatch Standards + Spec sub-agents in parallel (老板 8/21 corrected Q34, I hadn't run dual-axis)
6. **domain-modeling**: add `SettingView` / `NSMenuInstallationPattern` / `SettingsScene` to `CONTEXT.md`

## implement fix specification (per revert of commit `9cb2ad0f0` after NSMenu install, root-cause re-judgment)

- Current working tree: commit `9cb2ad0f0` (revert NSMenu install) + commit `4ef3e2e77` (extract shared `SettingView`) + commit `984ea556b` (Settings Model Picker ticket 04)
- `WenshuApp` body `Settings { SettingView() }` Scene still in App body
- 老板's screenshot: settings sheet floats over the original windows but the `SettingView` content is blank
- **Root-cause diagnosis (3 candidates — needs 老板 verification to lock)**:
  - (a) `SettingView` `@AppStorage` reads `UserDefaults` but does not respond inside the SwiftUI-default settings sheet (UserDefaults scope issue)
  - (b) `Settings { SettingView() }` Scene conflicts with the SwiftUI-default settings sheet; SwiftUI uses its own settings and does not install our `SettingView`
  - (c) `SettingView` references `MiniMaxModel` / `AppearanceMode` enums that can't be resolved in the SwiftUI-default settings scope (linker issue)

## Acceptance

- [ ] `swift build` exit 0
- [ ] `swift test` exit 0
- [ ] 老板 macOS verification:
  - Menubar 7 items (`Apple / 文枢` + the 5 localized Chinese menu items)
  - Click "文枢" → "Settings…" opens a settings sheet floating over the original windows
  - Settings sheet contains the Appearance Picker (3: System / Light / Dark), switching takes effect immediately
  - Settings sheet contains the Model Picker (3: `MiniMax-M3` / `MiniMax-M2` / `MiniMax-Reasoning`), selection is persisted
  - Does not display which one is currently selected

## Out of scope (Q20 hard constraint)

- v0.20 tickets 04 + 05 (LOGO + menubar "文枢" — 老板 ruled: leave it for now)
- v0.21 chat streak tickets 02-06 (5 tickets committed + dual-axis code-review fixes aggregated; untouched)
- `App.swift` `Settings { }` Scene existing Form + Picker (commit `4ef3e2e77` SettingView)
- `AppIcon.icon/` (老板 ruled: leave it for now)

## Apple HIG references

- https://developer.apple.com/documentation/swiftui/settings
- https://developer.apple.com/documentation/swiftui/settingslink
- https://developer.apple.com/documentation/foundation/adding-a-settings-interface-to-your-app
- VibeMeter/NSApplication+openSettings.swift (open-source reference)

## References

- Depends on: none
- Required by: ticket 02 (LLM Keychain integration) + ticket 03 (real verify) — not dependencies, can run in parallel
