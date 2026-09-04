# 08: Editor top bar toolbar layout (left name + center mode + right save/expand/close)

**What to build:** Compose editor top bar = HStack { doc basename Text (left) Spacer() mode toggle (center) Spacer() save + expand + close (right) }. Use DesignTokens.paneTabHotArea = 28 PT height (= Rule 6 no magic numbers). Verify toolbar layout consistent across 6-zone + expanded modes.

**Blocked by:** 03, 04, 07

**Status:** ready-for-agent

## Acceptance criteria

- [ ] Editor top bar HStack composition: left (doc basename) + center (mode toggle) + right (save + expand + close)
- [ ] 28 PT height (= DesignTokens.paneTabHotArea, matches existing pane tab bars)
- [ ] Close button (PaneTrailingIconButton with xmark icon) placeheld for ticket 09 (= no action yet)
- [ ] Save button placeheld for ticket 07 (= reads dirty state from ticket 07)
- [ ] Expand button placeheld for ticket 03 (= reads @AppStorage from ticket 03)
- [ ] Mode toggle placeheld for ticket 04 (= reads mode state from ticket 04)
- [ ] swift build exit 0 + manual verify: doc basename shows, mode toggle works, save highlights when dirty, expand/shrink works, close placeheld
- [ ] git commit: refactor(wenshu): v0.34 -- editor top bar toolbar layout (= ticket 08 of 11)

## Iron rules applied (= check before commit)

- [ ] Rule 6: layout/spacing uses DesignTokens (= no magic numbers)
- [ ] Rule 7: Button + system buttonStyle (= no custom-drawn icons, Lucide only)
- [ ] Rule 8: stays inside WindowGroup scene tree (= no new NSWindow)
- [ ] Rule 11: state persistence via @AppStorage / @SceneStorage (= Rule 11 + Apple HIG standard)
- [ ] wenshu-apple-api-first: grep Apple HIG first, write ZERO custom code if built-in covers it
- [ ] AGENTS.md §11.1: use pinned deps (swift-markdown 0.4.0) — NO add new deps
- [ ] AGENTS.md hard rule: English-only commit body + new comments; "老板" sole address

## Double-axis review (= per Q37 streak rule)

- [ ] Standards axis = sub-agent reviews AGENTS.md hard rules + 11 iron rules + ComponentIndex consistency
- [ ] Spec axis = sub-agent reviews spec user stories + implementation decisions vs actual code
