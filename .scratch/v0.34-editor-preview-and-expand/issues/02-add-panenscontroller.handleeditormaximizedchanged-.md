# 02: Add PaneNSController.handleEditorMaximizedChanged handler

**What to build:** When NotificationCenter post .wenshuEditorMaximizedChanged arrives: snapshot current 6 zone visible + editor weight (= save to UserDefaults JSON BEFORE any layout change to avoid race). Then trigger 5 zoneToggle animator calls (= hide all 5 zones except editor). On reverse (= editorMaximized false): read snapshot JSON, restore 6 zones + editor weight. Reuse PaneNSController.handleToggleZone infrastructure from commit 125840d0f.

**Blocked by:** 01

**Status:** ready-for-agent

## Acceptance criteria

- [ ] Sources/WenshuApp/Views/Layout/PaneNSController.swift adds handleEditorMaximizedChanged(_:) method
- [ ] Snapshot saves 6 zone visible values + editor zone split weight (= full state per Q38 boss decision)
- [ ] Snapshot read on shrink returns the same 6 zone visible values (= roundtrip verified)
- [ ] 5 zoneToggle animator calls happen in correct order (= sidebar, preview, tools, chat, dynamic)
- [ ] swift build exit 0
- [ ] git commit: refactor(wenshu): v0.34 -- add PaneNSController.handleEditorMaximizedChanged (= ticket 02 of 11)

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
