# 10: Cmd+E / Cmd+W / Cmd+Shift+E hotkeys

**What to build:** Cmd+E hotkey → toggle EditorMode (.preview ↔ .edit). Cmd+W hotkey → trigger close (= ticket 09 confirm dialog if dirty). Cmd+Shift+E hotkey → toggle @AppStorage("wenshu.editorMaximized") (= expand/shrink). All hotkeys work regardless of editor zone focus state.

**Blocked by:** 08

**Status:** ready-for-agent

## Acceptance criteria

- [ ] .keyboardShortcut("e", modifiers: .command) on mode toggle button
- [ ] .keyboardShortcut("w", modifiers: .command) on close button
- [ ] .keyboardShortcut("e", modifiers: [.command, .shift]) on expand button
- [ ] Hotkeys work even when editor zone is not focused (= SwiftUI standard keyboardShortcut behavior)
- [ ] swift build exit 0 + manual verify: all 3 hotkeys work
- [ ] git commit: refactor(wenshu): v0.34 -- editor hotkeys Cmd+E/Cmd+W/Cmd+Shift+E (= ticket 10 of 11)

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
