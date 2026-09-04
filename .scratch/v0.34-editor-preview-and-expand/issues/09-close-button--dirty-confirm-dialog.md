# 09: Close button + dirty confirm dialog

**What to build:** Close button = PaneTrailingIconButton with xmark icon (placeheld in ticket 08). Action: if dirty (= draft != originalBody) → show .alert confirm discard; on discard = restore placeholder + clear draft + clear originalBody + reset mode to .preview.

**Blocked by:** 08

**Status:** ready-for-agent

## Acceptance criteria

- [ ] Close button action wired in editor top bar (= placeholder from ticket 08)
- [ ] If dirty: .alert "未保存的更改将丢失" with .destructive Button("放弃编辑") + .cancel Button("继续编辑")
- [ ] On discard: @State draft = "", originalBody = "", mode = .preview, documentPath = nil (= back to placeholder)
- [ ] If clean: immediate close (= no confirm dialog)
- [ ] swift build exit 0 + manual verify: type dirty text, click close, confirm dialog appears, click discard, back to placeholder
- [ ] git commit: feat(wenshu): v0.34 -- close button + dirty confirm dialog (= ticket 09 of 11)

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
