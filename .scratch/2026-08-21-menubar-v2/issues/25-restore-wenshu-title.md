# 25 — Settings menu title restored to "文枢" + keep the fade-in/fade-out animation

Depends on: ticket 24 revert commit `654bac679`

**What to build:**
- Keep the fade-in/fade-out animation (`providerApiEditor` L436-454 already updated; ticket 22 + 23 landed untouched)
- `Info.plist` `CFBundleDisplayName` + `CFBundleName` revert to "文枢" (revert ticket 21 + 23 truth; brand restored)

**Why:**
老板 2026-08-22 07:22 ruled "restore to '文枢' Settings" + accept the fade-in/fade-out animation. Brand "文枢" restored + macOS 14+ SwiftUI `Settings` Scene API doesn't support custom title (Q44 swiftinterface verified).

**Acceptance:**
- 老板 macOS verification: popup title = "文枢 Settings" (brand restored) / edit-box 3 elements Apple default fade-in/fade-out animation
- `swift build` exit 0
- `swift test` exit 0 (`ProviderKeychain` 5/5 pass)
- Dual-axis code-review verbatim into commit body
