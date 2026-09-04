# 07: Edit mode = Apple TextEditor + dirty detection + save button

**What to build:** Replace editor placeholder (= when mode=.edit) with TextEditor(text: $draft) (= HIG standard). Add @State private var originalBody = loadDoc(doc.path). Dirty detection = draft != originalBody (= character-level diff per Q22 boss decision). Save button = PaneTrailingIconButton(highlighted .tint when dirty, gray otherwise). Cmd+S hotkey via .keyboardShortcut. Save action = try? body.write(toFile: docPath, atomically: true, encoding: .utf8).

**Blocked by:** 04

**Status:** ready-for-agent

## Acceptance criteria

- [ ] import SwiftUI (= Apple HIG TextEditor)
- [ ] @State private var draft = "" + @State private var originalBody = "" in editor view (= both initialized on document load)
- [ ] Mode = .edit → TextEditor(text: $draft) replaces preview view
- [ ] Save button (PaneTrailingIconButton with disk icon) highlighted .tint when draft != originalBody; gray when clean
- [ ] Cmd+S hotkey triggers save (= .keyboardShortcut("s", modifiers: .command))
- [ ] Save action writes draft to doc.path atomically (= didSet originalBody = draft after successful write)
- [ ] swift build exit 0 + manual verify: type, see save highlight, Cmd+S, save highlight clears
- [ ] git commit: feat(wenshu): v0.34 -- edit mode = TextEditor + dirty + save (= ticket 07 of 11)

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
