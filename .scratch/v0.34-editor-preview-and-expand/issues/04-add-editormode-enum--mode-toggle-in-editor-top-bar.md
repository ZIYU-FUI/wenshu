# 04: Add EditorMode enum + mode toggle in editor top bar

**What to build:** EditorMode enum { .preview, .edit }. @State private var mode = .preview in editor view. Add PaneTrailingIconButton (= use helper from B-04 dcde7cff5) with eye ↔ pencil icons in editor top bar. Toggle action = mode.toggled(). Verify icon swap on click. (Independent of expand work; can parallel with 01.)

**Blocked by:** None (can start immediately, parallel with 01)

**Status:** ready-for-agent

## Acceptance criteria

- [ ] New file or new enum in existing editor view: EditorMode { .preview, .edit }
- [ ] @State private var mode = .preview in editor view body
- [ ] PaneTrailingIconButton with eye/pencil icon (= eye in .preview mode, pencil in .edit mode)
- [ ] Button action = mode.toggled() (= SwiftUI reactive update)
- [ ] swift build exit 0 + manual macOS verify (= icon swap on click)
- [ ] git commit: refactor(wenshu): v0.34 -- add EditorMode enum + mode toggle (= ticket 04 of 11)

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
