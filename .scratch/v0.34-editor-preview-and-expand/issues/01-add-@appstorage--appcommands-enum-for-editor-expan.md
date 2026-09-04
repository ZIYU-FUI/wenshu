# 01: Add @AppStorage + AppCommands enum for editor expand state

**What to build:** Wire @AppStorage("wenshu.editorMaximized") + @AppStorage("wenshu.editorExpand.snapshot") into EditorExpandShrinkTrailingButton. Add AppCommands.editorMaximizedChanged enum case (= boss 9/2 B-04 pattern from commit 95a2d96ba). Backward-compat accessor = Notification.Name.wenshuEditorMaximizedChanged. Verify swift build exit 0.

**Blocked by:** None (can start immediately)

**Status:** ready-for-agent

## Acceptance criteria

- [ ] Sources/WenshuApp/Views/Workspace/EditorExpandShrinkTrailingButton.swift gets @AppStorage reactive binding
- [ ] Sources/WenshuApp/Core/Notifications/AppNotifications.swift adds AppCommands.editorMaximizedChanged enum case (= consistent with existing AppCommands pattern from B-04 commit)
- [ ] Backward-compat accessor Notification.Name.wenshuEditorMaximizedChanged exists at AppNotifications.swift (matches .wenshuProviderKeychainChanged pattern)
- [ ] swift build exit 0
- [ ] git commit: refactor(wenshu): v0.34 -- wire @AppStorage for editor expand state (= ticket 01 of 11)

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
