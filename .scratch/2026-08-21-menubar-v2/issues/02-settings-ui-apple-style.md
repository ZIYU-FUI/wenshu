# 02 — Settings page UI rebuild (Apple macOS 27 standard paradigm)

**What to build:**
老板 8/21 20:50 macOS verification + ruling:
- ✅ Switching appearance is responsive (commit `d8146ca7d` `preferredColorScheme` `@AppStorage` truth is responsive)
- ✅ Settings sheet floating over original windows works (commit `3f4faf68f` self-created `NSWindow` is good)
- ❌ Settings sheet internal UI is dated (`Form` + 2 `Picker`s), not the Apple-official macOS 27 standard paradigm
- **New requirement: reference Apple-official software's settings pages (e.g. Pages / Notes system-settings paradigm); use macOS 27 components**

**Blocked by:** None.

**Status:** ready-for-agent

## Fix specification (satisfying principles 1 + 2 + 3, Apple macOS 27 official paradigm)

Execute the po main flow's 6 steps strictly (老板 8/21 ruled "execute the master full-chain strictly"):

1. **Keep `installMainMenu` installing 6 Chinese items** (commit `3f4faf68f`) — untouched
2. **Keep self-created `NSWindow` installing `SettingView`** (commit `3f4faf68f`) — untouched
3. **Keep `preferredColorScheme` `@AppStorage` responsive** (commit `d8146ca7d`) — untouched
4. **Rebuild `SettingView` UI**:
   - Use `TabView` + `Tab` API (SwiftUI 14+) — toolbar auto-shows tabs
   - 3 tabs: General / Model / Shortcuts
   - General tab: Appearance Picker (3: System / Light / Dark, Apple `radioGroup` truth)
   - Model tab: Model Picker (3: `MiniMax-M3` / `MiniMax-M2` / `MiniMax-Reasoning`, Apple menu truth, hide display after configuration)
   - Shortcuts tab: placeholder (added later)
   - Use `Form { }` to embed in `TabView` (Apple HIG)
   - macOS 27 components: `Picker`, `Toggle`, `Form`, `TabView` (Apple truth)

## Acceptance

- [ ] `swift build` exit 0
- [ ] `swift test` exit 0
- [ ] 老板 macOS verification:
  - Click "文枢" → "Settings…" opens a settings sheet floating over the original windows
  - Top toolbar tabs: General / Model / Shortcuts
  - General tab: Appearance Picker (3: System / Light / Dark), switching changes the window immediately
  - Model tab: Model Picker (3: `MiniMax-M3` / `MiniMax-M2` / `MiniMax-Reasoning`), hide display after configuration
  - Shortcuts tab: placeholder
  - Does not display which one is currently selected

## Out of scope (Q20 hard constraint)

- v0.20 tickets 04 + 05 (LOGO + menubar "文枢" — 老板 ruled: leave it for now)
- v0.21 chat streak tickets 02-06 (5 tickets committed + dual-axis code-review fixes aggregated; untouched)
- `installMainMenu` installs 6 Chinese items (commit `3f4faf68f` passed)
- Self-created `NSWindow` installs `SettingView` (commit `3f4faf68f` passed)
- `preferredColorScheme` `@AppStorage` truth is responsive (commit `d8146ca7d` passed)

## Apple HIG references

- https://developer.apple.com/design/human-interface-guidelines/macos
- https://developer.apple.com/documentation/swiftui/tabview
- https://developer.apple.com/documentation/swiftui/form
- https://developer.apple.com/documentation/swiftui/toggle
- Pages / Notes system settings (boss screenshot reference)

## References

- Depends on: none
- Required by: ticket 02 (LLM Keychain integration) — not a dependency, can run in parallel
