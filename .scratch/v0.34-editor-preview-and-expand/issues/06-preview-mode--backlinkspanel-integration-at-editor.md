# 06: Preview mode = BacklinksPanel integration at editor bottom

**What to build:** Mount wenshu's existing BacklinksPanel (= Core/LinkGraph/BacklinksPanel.swift) at the bottom of editor zone in preview mode (= below rendered MD). Uses existing BacklinksPanel API (= takes docId, renders backlinks list). Verify backlinks load for current document.

**Blocked by:** 05

**Status:** ready-for-agent

## Acceptance criteria

- [ ] Sources/WenshuApp/Core/LinkGraph/BacklinksPanel.swift (= already exists from obsidian-replica work, reused as-is)
- [ ] Editor preview mode renders BacklinksPanel below the rendered MD (= VStack)
- [ ] Backlinks panel data flows: docId → BacklinksPanel model → existing backlinks resolver
- [ ] swift build exit 0 + manual verify with document that has backlinks
- [ ] git commit: feat(wenshu): v0.34 -- BacklinksPanel in preview mode (= ticket 06 of 11)

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
