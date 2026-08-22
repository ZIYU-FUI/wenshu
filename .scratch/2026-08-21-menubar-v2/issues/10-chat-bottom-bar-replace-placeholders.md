# 10 — Chat-zone bottom bar placeholder replacement (sub-component `ChatZoneView`, 老板 2026-08-21 23:35 ruled)

**What to build:**
老板 8/21 23:35 ruled:
1. 'I was misunderstood — my requirement is to replace the two placeholder strings in the chat zone's bottom bar, implementing model selection and context usage, but the replacement must not affect the placeholder strings in other zones.'
2. 'Don't write placeholders or decisions between you and me into the UI; the UI doesn't display those explanations. The UI is for the user, not for feature management.'

= Parent component `ZoneModule` `.aiChat` case updates `ChatZoneView` sub-component (= `ChatView` + `ChatBottomToolbar`)
= The other 5 zone cases are unchanged (= `ZoneBottomToolbar` parent keeps the "placeholder strings" display)
= UI does not show development notes (= 老板 8/21 23:35 ruled "the UI is for the user, not for feature management")

**Blocked by:** None.

**Status:** ready-for-agent

## Fix specification (3 steps, satisfying principles 1 + 4, Q32 hard-violation fix)

1. **Revert ticket 09 commit `f423e4678`** (= `git revert --no-edit f423e4678` = `404bef105` Revert — parent component `ZoneModule` `.aiChat` case updated to `VStack` violated principle 1, revert)
2. **Restore chat-zone `ChatBottomToolbar` but via the sub-component `ChatZoneView`** (= 老板 8/21 23:35 ruled "don't touch the parent; inside the chat zone, attach to the parent, generate a sub-component")
   - `ZoneModule` `.aiChat` case updated to `ChatZoneView(conductor:store:)` (= parent **untouched**, only the `.aiChat` case content swapped)
   - `ChatZoneView = VStack { ChatView + ChatBottomToolbar }` (= sub-component contains `ChatView` + `ChatBottomToolbar`)
   - The other 5 zone cases are unchanged (= `ZoneBottomToolbar` parent keeps the "placeholder strings" display)
3. **UI does not display development notes** (= 老板 8/21 23:35 ruled "the UI is for the user, not for feature management")
   - `ChatZoneView` removes all development-note comments
   - `ChatBottomToolbar` removes all "(= 老板 8/21 ruled)" style history comments (= Q8 hard constraint)
   - Commit body / spec / issue do not write "fix-cause" style development-management notes (= rewrite as "fix" / "implement" / "install")

## Dual-axis code-review (Q34: 老板 corrected "execute the PO full chain"; this round must run)

## Acceptance

- [ ] ticket 09 commit `f423e4678` reverted (= `git revert` runs)
- [ ] `ZoneModule` `.aiChat` case updated to `ChatZoneView` sub-component (= parent `ZoneModule` doesn't touch other 5 zones)
- [ ] `ChatZoneView = VStack { ChatView + ChatBottomToolbar }` (= replaces the chat-zone bottom-bar "placeholder string" slot)
- [ ] Other 5 zone cases are unchanged (= `ZoneBottomToolbar` parent keeps "placeholder strings")
- [ ] UI does not show development notes (= 老板 8/21 23:35 ruled "the UI is for the user, not for feature management")
- [ ] Comments don't write "(= 老板 8/21 ruled)" style history (= Q8 hard constraint)
- [ ] Commit body doesn't write "fix-cause" style development-management notes
- [ ] `swift build` exit 0
- [ ] `swift test` exit 0
- [ ] 老板 macOS verification: chat-zone bottom bar = model picker + context usage (replacing "placeholder string"), other 5 zones' bottom bar = "placeholder string", UI is clean with no development notes
- [ ] **Dual-axis code-review report** (Standards + Spec in parallel; 老板 8/21 ruled "execute the PO full chain")

## Out of scope (Q20 hard constraint)

- v0.20 LOGO + menubar
- v0.21 chat-streak tickets 02-06
- `Provider` / `ProviderKeychain` / `ProviderFetcher` / `ProviderCatalog`
- `ProviderKeyPrompt`
- `MiniMaxModelFetcher`
- `ZoneModule` parent component (other 5 zone cases untouched)
- `ZoneBottomToolbar` parent component (5 zones' bottom bars keep "placeholder strings")
- `SettingView` (commits `6a3d93f5d` + `1f086051a` kept; Pages paradigm)
- `AppIcon.icon/`

## Apple HIG references

- https://developer.apple.com/documentation/swiftui/viewbuilder
- https://developer.apple.com/documentation/swiftui/menu
- https://developer.apple.com/documentation/swiftui/progressview

## References

- Depends on: none
- Required by: none
