# 22 — Polish: key 12 chars + text-field animation + tab-switch animation + Apple default animation principle

Depends on: ticket 21 commit `173b719bb`

**What to build:**
5 fixes + 1 new domain word (老板 2026-08-22 06:46 ruled):
1. `keyPrefix8` → `keyPrefix12` function (12-char display)
2. `SecureField` + `Button` + `apiError` `Text` get `.transition(.opacity)` (Apple default appear/exit animation)
3. `SettingView` body `Group` updated: 3 tabs get `.transition(.opacity)` + `.animation(.default, value: selectedTab)`
4. `CONTEXT.md` new domain word **WenshuInteractionAnimationPrinciple** (boss verbatim "interaction animations use Apple standard APIs, persistently elegant")
5. Extended audit: any component Apple SwiftUI standard API supports animation on — add Apple default animation

**Why:**
After ticket 21 commit `173b719bb`, 老板's macOS verification was visually OK but had 5 polish items. 老板's verbatim: "anything that can have an animation, add it" = add Apple default animation throughout.

**Acceptance:**
- 老板 macOS verification: already-set key shows 12 grayed chars / tap whole row → text-field Apple default appear/exit animation / tab-switch Apple default animation / persistently elegant
- `swift build` exit 0
- `swift test` exit 0 (`ProviderKeychain` 5/5 pass)
- Dual-axis code-review verbatim into commit body
- Q40 + Q45: real key goes through Apple Keychain, not into files / log / commit; grayed text only shows the first 12 chars in UI
