# 03: Fix EditorExpandShrinkTrailingButton to react to @AppStorage

**What to build:** Replace dead @State var editorMaximized: Bool with @AppStorage("wenshu.editorMaximized") reactive binding. Button action = toggle @AppStorage (not @State). Icon swap reactive on @AppStorage change (= ↘ ↔ ↖). Verify icon AND layout (= other 5 zones) update on click.

**Blocked by:** 01, 02

**Status:** ready-for-agent

## Acceptance criteria

- [ ] Sources/WenshuApp/Views/Workspace/EditorExpandShrinkTrailingButton.swift: no @State for editorMaximized (= replaced by @AppStorage)
- [ ] Button action toggles @AppStorage Bool (= not @State)
- [ ] Icon reactive on @AppStorage change (= SwiftUI redraws on AppStorage change)
- [ ] Clicking icon: 5 other zones collapse (= visible=false via NSSplitViewItem.animator), editor zone takes full window
- [ ] Clicking icon again: 5 zones restore to pre-expand visibility (= snapshot restore)
- [ ] swift build exit 0 + manual macOS verify with screencapture
- [ ] git commit: fix(wenshu): v0.34 -- repair EditorExpandShrinkTrailingButton click (= ticket 03 of 11, fixes Q33 bug)

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
