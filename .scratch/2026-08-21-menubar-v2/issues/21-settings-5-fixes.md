# 21 — Settings popup: fix 5 hard-violation items (items 1+2+3 fix + item 4 status unification + item 5 expand animation)

Depends on: ticket 17 commit `227859117` + `CONTEXT.md` `9b0f0250b`

**What to build:**
5 fix items (老板 2026-08-22 06:29 ruled):
1. `SecureField` + Save button on the same row (fix 1)
2. `Info.plist` `CFBundleName` change to "Settings" (fix 2)
3. Tab segmented picker imitating Pages + ICON (fix 3, partially fixed already; full fix takes effect)
4. `providerApiRow` status unified to English ("Awaiting config" / grayed first-8-chars "Configured") (fix 4)
5. Expand animation uses Apple default (`.animation(.default, value:)`) (fix 5, new)

**Why:**
After ticket 17 commit `227859117`, 老板's macOS verification found 5 hard-violation items. Q32 root-cause chain = 5 fix items + 1 new item.

**Acceptance:**
- 老板 macOS verification: settings popup title "Settings Settings" / Provider API tab imitates Pages + ICON / tap a whole row → expand animation / `SecureField` + Save button on the same row / un-set shows "Awaiting config" / set shows grayed first-8-chars
- `swift build` exit 0
- `swift test` exit 0 (`ProviderKeychain` 5/5 pass; no regressions)
- Dual-axis code-review report verbatim into commit body
- Q40 + Q45: real key goes through Apple Keychain, not into files / log / commit; grayed text only shows the first 8 chars in UI
