# 23 — Remove "文枢" from the title + apply container-level animations

Depends on: ticket 21 commit `173b719bb` + ticket 22 commit `8b1b48a64`

**What to build:**
2 hard-truth fixes (老板 2026-08-22 06:50 ruled):
1. `Info.plist` `CFBundleDisplayName` fixed to "Settings" (ticket 21 item 2 didn't take effect because `CFBundleDisplayName` follows the fallback-priority order)
2. `App.swift` `providerApiEditor` updated: remove element-level `.transition` (L441 / L447 / L453 each) → `HStack` whole container-level `.transition` (boss verbatim "it's not the two elements that need animation; it's the row that those elements live on that needs animation")
3. `App.swift` `SettingView` body `Group` updated: remove `switch` case `.transition` (L274-276; `switch` case isn't an `if` condition, so `.transition` doesn't take effect)

**Why:**
After tickets 21 + 22 took effect, 老板's macOS verification found 2 hard-truth violations. 老板's addendum "container-level transition" = Apple SwiftUI authoritative hard correction.

**Acceptance:**
- 老板 macOS verification: title "Settings Settings" (no "文枢") / expanding text-field container-level Apple default animation / tab-switch Apple default animation
- `swift build` exit 0
- `swift test` exit 0 (`ProviderKeychain` 5/5 pass)
- Dual-axis code-review verbatim into commit body
- Q40 + Q45: real key goes through Apple Keychain; UI display is first 12 chars only, not in files / log / commit
