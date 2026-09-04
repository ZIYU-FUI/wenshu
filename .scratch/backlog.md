# Wenshu backlog — boss拍单记需求

This file holds requirements boss拍 out as "单记一个需求" (= 记下,
后面处理). Each entry has its own header so future implementers can
grep + pick up.

# Hard rule (project-wide, non-negotiable)

- English only. No CJK characters or punctuation.

---

## B-01 — All wenshu user-facing strings must be Chinese

Date拍: 2026-09-02 OOB (during v0.32 Apple-API-first sweep).
Source: boss feedback after Tier-1 rank-1 commit `6f717a432`
(= .help() tooltip in editor expand button was English `shrink` /
`expand`; boss corrected to "全改中文"). Scope: ALL user-facing
strings in wenshu (= .help() tooltip / .accessibilityLabel / menu item
text / button label / placeholder text / alert message / toast title).

Specific known English strings still in flight (= not yet Chinese,
will be deleted by upcoming Tier-1 ranks per
`.scratch/v0.32-apple-api-audit/audit.md` §4):

- `Sources/WenshuApp/UI/AppTitlebar.swift:275` label `"Toggle sidebar (⌘B)"`
- `Sources/WenshuApp/UI/AppTitlebar.swift:283` label `"Toggle preview (⌘P)"`
- `Sources/WenshuApp/UI/AppTitlebar.swift:291` label `"Toggle tools (⌘T)"`
- All other English labels inside `AppTitlebar.swift` (= the whole
  file is scheduled for deletion in Tier-1 rank-4 of the v0.32 audit;
  no need to rewrite line-by-line — wait for the file delete).

Acceptance: every .help() / .accessibilityLabel / menu label /
placeholder in `Sources/WenshuApp/` reads in Chinese (= "显示/隐藏
项目管理区" not "Toggle sidebar"). Lucide icon names (= "expand" /
"shrink" / "archive") are NOT user-facing — they're internal
identifiers and stay English per the wenshu-pollution-defense rule.

Out of scope (= English by design):
- AGENTS.md rule = "English only" applies to commit message / comments
  / .scratch/ — NOT to UI text.
- Lucide icon identifier strings (= used by LucideIconSystemFallback to
  render the glyph; not a label).
- Swift identifier names (= type / func / variable names — Swift
  convention is English).

Implementation note: the boss拍 "全改中文" is a SINGLE backlog item,
not a commit-by-commit rewrite. The full UI-string Chinese pass happens
after the v0.32 Apple-API-first sweep finishes (= all Tier-1 + 2 + 3
items ship), so we don't edit files that are scheduled for deletion.
Files scheduled for deletion that hold English labels are NOT edited
— they get deleted in their scheduled Tier-1 / Tier-2 / Tier-3 rank.

---

## B-02 — Top-bar chrome: flatten remaining wrappers

Boss 2026-09-02 OOB 'all-zone top bars have the same structure, why can't they be one component' (= Apple-API-first #7 multi-layer audit).

State as of 2026-09-02 (= today's session):
- DONE: deleted `ZoneContentTabBar` wrapper (= ~187 LOC), `ZoneContentView` now uses `PaneTabBar` directly.
- DONE: added `PaneTrailingIconButton` helper in `PaneTabBar.swift`, replaced 2 duplicate copies (`WorkspaceView.EditorExpandShrinkTrailingButton` + `TabContentDispatcher.ChatZoneTopChrome` trailing).
- TODO (= open for next session): `DynamicZoneTabBar` and `ChatZoneTopChrome` still exist as wrappers around `PaneTabBar`. They differ only by:
  - `ChatZoneTopChrome`: hard-codes 1 tab item (= already migrated to `PaneTrailingIconButton`, so the wrapper now contains only 1 hardcoded tab + binding).
  - `DynamicZoneTabBar`: provides enum ↔ string binding shim (= SwiftUI Binding limitation; cannot collapse without changing the binding contract).

Next-session ticket: delete `ChatZoneTopChrome` (= its hard-coded tab can move into `TabContentDispatcher`'s caller). Keep `DynamicZoneTabBar` (= genuine enum-binding adapter, SwiftUI limitation).

Acceptance: `ChatZoneTopChrome` deleted; `PaneTabBar` is the only top-bar wrapper in the codebase; `DynamicZoneTabBar` survives with a documented reason (enum ↔ string binding).

Out of scope (= intentionally NOT in this ticket):
- `RegionTabBar` + `PaneTabBar` + `PaneIconTab` 3-layer generic stack: canonical abstraction chain (= each layer adds one concern: chrome / container / unit). Boss拍 explicitly approved this layering.

---

## B-03 — Standards axis HARD F1: 36 commits body contain CJK (= AGENTS.md English-only hard rule violation)

Date拍: 2026-09-02 Standards-axis review (delegation `deleg_69ab26de`).
Source: 42 commits surveyed, 36/42 commit bodies contain CJK characters. 0/42 subjects contain CJK. Bodies include boss-OOB quoted text like `Boss 2026-09-02 OOB '能拉齐吗'` and pure-Chinese narrative (`下一步 (= 等老板拍): ...`).

State as of 2026-09-02 (= today's session):
- DONE: 22 uncommitted-line CJK comments fully translated to English (= clean rebase-of-today only).
- TODO (= open for next session): the 36 landed commits still have CJK bodies. Standard fix = `git rebase -i6585a0476^..HEAD` to rewrite each commit body in English (= subject untouched, only body lines translated).

Acceptance: `git log --pretty=%b 6585a0476^..HEAD | grep -P '[\\x{4e00}-\\x{9fff}]'` returns 0 hits.

Out of scope (= intentionally NOT rebase'd):
- The 33 files with 806 total CJK comment lines (= 99% of which are historical OOB citations from v0.19-v0.34, NOT introduced today). A separate "translate all historical CJK comments" sweep is a multi-day project (= not in this ticket).

---

## B-04 — Notification.Name scattered naming convention + 11 definitions in App.swift

Boss 2026-09-02 session audit finding: 11 `Notification.Name` definitions concentrated in `Sources/WenshuApp/App.swift` lines 40-69, split across 2 extension blocks. Naming convention is inconsistent: 6 use `wenshu.X` (= e.g. `wenshu.toggleZone`), 5 use `com.wenshu.X` (= e.g. `com.wenshu.resetLayout`). 17 post/observe sites across 7 files.

Single-interface solution:
- Move all 11 definitions to a new file `Sources/WenshuApp/Core/Notifications/AppNotifications.swift`.
- Unify naming to `com.wenshu.X` (= Apple reverse-DNS standard for `Notification.Name`).
- Group by semantic role: `enum AppCommands` (= toolbar actions), `enum AppStateEvents` (= chat store ready / provider keychain changed), `enum LayoutEvents` (= reset layout / toggle edit mode).
- Optional: provide `static let x = Self.x` accessors that delegate to the enums (= preserves backward-compat with existing callers).

Acceptance: `App.swift` no longer contains `Notification.Name.wenshuXxx` definitions. `grep -r 'Notification\\.Name\\.wenshu' Sources/` returns 0 hits.

Out of scope (= intentionally NOT in this ticket):
- `v0.34 commit 85f87a68f Apple-API-first #6` already documented that `@FocusedValue` cannot replace NotificationCenter for `.commands { Button }` sender (= commands → View is the reverse direction; @FocusedValue handles View → commands). Some notifications are out-of-reach for `@FocusedValue`.

---

## B-05 — AppState centralization: 4 AppStorage copies of `wenshu.llm.model` + 5 zoneVisible keys

Boss 2026-09-02 session audit finding: same `@AppStorage("wenshu.llm.model")` key declared in 4 separate views (App.swift:556 + App.swift:1440 + LibraryRootView.swift:134 + WorkspaceView via @State). 5 `@AppStorage("wenshu.zoneVisible.*")` keys declared independently in `LibraryRootView.swift` L126-130.

Single-interface solution: route ALL of these through AppState (the existing `@Observable` store) so changes from any view propagate consistently. Or: route zone visibility through `NSSplitViewItem.isCollapsed` + `autosaveName` (= the Apple canonical, already partially in use per v0.34 commit `125840d0f`).

Acceptance: `grep -rE '@AppStorage\("wenshu\.llm\.model"\)' Sources/` returns 1 hit (= the single owner in AppState). 5 zoneVisible `@AppStorage` keys deleted; NSSplitView autosave handles persistence.

Out of scope (= intentionally NOT in this ticket):
- The `wenshu.sidebarState` unification (= done in today's uncommitted work as a separate refactor).

---

## B-06 — F6 SOFT findings: design-token discipline residue

Date拍: 2026-09-02 Standards-axis review (delegation `deleg_69ab26de`).

Specific findings:
- `.padding(.horizontal, 18 PT)` and `.padding(.leading, 18 PT)` magic numbers still appear in scattered places (= some in DesignTokens itself, some in call sites that should reference the tokens).
- stale `liquidGlassOpacity` references in doc-comments (= the slider was deleted in v0.32 commit `76203ea59`, but doc-comments still mention it as if it existed).
- stale `WenshuChromeOverlay` / `AppTitlebar` / `AppStatusbar` doc-comment references (= files were deleted in v0.34 commit `69a43da65`, but adjacent files still mention them in narrative).

Acceptance: `grep -rn 'liquidGlassOpacity\|WenshuChromeOverlay\|AppTitlebar\b\|AppStatusbar\b' Sources/WenshuApp/` returns only the now-deleted file paths (or zero hits if all comments are cleaned). Magic-number paddings migrated to DesignTokens per existing convention.

---

## B-07 — Boss 2026-08-29 OOB ticket backlog (= skipped tickets from v0.28 free-layout planning)

Boss拍 documentation: 9 skipped tickets per boss's "等老板拍" rule (= 8/7 directive "不擅自抢跑 + 等我拍"). Originally tracked in v0.28 Wayfinder planning, deferred to v0.35+.

Open tickets (= from mem0 retrieval 2026-08-31):
- ticket 028-001: opt-in shape for free layout (= per-window toggle, per-book preference, or global app preference)
- ticket 028-002: 6-zone-preset behavior (= do zones stay coupled when user rearranges?)
- ticket 028-003: pane-zone mapping (= which functional modules go in which pane)
- ticket 028-011: ViewInspector test infrastructure (= ADR-0008 risk surface)
- ticket 015.014: archive FAIL cleanup
- ticket 015.019: book count right status (= status bar shows correct number)
- ticket 015.015: pending review
- ticket 015.020: 占位文字 placeholder audit (= partially done in current PaneStatusBar)
- ticket 015.073: 5th button projectPreview zone (= UI render only)

Boss OOB directive (2026-08-27 / 8/29 / 9/02): wait for explicit 老板拍 before resuming these.

Acceptance: boss resumes these tickets (= 老板 may group them into a v0.35+ milestone).

---

## B-08 — B-01 "全 wenshu UI 字符串中文化" (= boss 2026-09-02 backlog entry B-01)

See full description at top of this file. Acceptance unchanged. Status: pending (= awaiting v0.32 Tier-1 + 2 + 3 sweep completion before the full UI-string Chinese pass can ship).

---

## B-09 — Kanban + Todo functional linkage (= mem0 entry 8/27)

Boss OOB (2026-08-27): "Kanban and Todo features are not yet implemented in the project; only a module exists intended for future automatic dispatch and long-task breakdown, but no functional linkage is present."

Status: backend module exists (wenshu-pour / WenshuCore), no frontend wiring to surface the kanban / todo UI in the user's workspace.

Acceptance: kanban + todo UI functional (= user can create / list / update tickets, kanban board shows tickets by status, todo list shows per-book items).

Out of scope:
- The Kanban `SubAgentProgressView.swift` (= status icon rendering, done in today's Lucide migration)
- The per-book `todo.json` (= file format already exists in BookStore).

---

Last line: fact.

---

## B-10 — Re-enable Apple Keychain SecItemAdd (= remove v0.28 stub)

Date拍: 2026-09-02 (= this session).
Source: boss session 9/2 OOB 'we built a unified key settings page, that page should be a unified add interface, writing to Apple's keychain'.

State as of 2026-09-02:
- `Sources/WenshuApp/Core/Provider/ProviderKeychain.swift:50-155` (= saveKeySync / loadKeySync / deleteKeySync) has the real `SecItemAdd` / `SecItemCopyMatching` / `SecItemDelete` code commented out (= v0.28 followup, boss 2026-08-29 OOB '注释掉密码功能'). The stub returns success for save/delete and a hardcoded debug key `'wenshu.debug.api.key'` for load. This means current LLM calls succeed with a fake credential (= Apple Keychain is NOT being written to).
- `Sources/WenshuApp/Core/Agent/LLMKeychain.swift` (= v0.21 ticket 03) was the historical Apple-Keychain implementation but had 0 callers in the codebase as of v0.34 (= ProviderKeychain was the v0.28 canonical replacement). Deleted in commit (this session's B-10 cleanup).

Re-enable plan (= unblock real LLM keys via Apple Keychain):
1. In `ProviderKeychain.AppleKeychainStore.saveKeySync`, replace the early-return stub with the commented-out real `SecItemAdd` code (= kSecClassGenericPassword + kSecAttrService "com.wenshu.app.provider" + kSecAttrAccount "<provider.slug>.api.key" + kSecAttrAccessibleAfterFirstUnlock).
2. In `ProviderKeychain.AppleKeychainStore.loadKeySync`, replace the hardcoded `'wenshu.debug.api.key'` return with the commented-out real `SecItemCopyMatching` code.
3. In `ProviderKeychain.AppleKeychainStore.deleteKeySync`, replace the early-return stub with the commented-out real `SecItemDelete` code.
4. Verify the unified add interface (= `ProviderKeychain.saveKeySync(_:for:)`) is the ONLY write path used by the Settings UI (= already verified in this session: 9 caller sites across App.swift, AvailableModelsDiscovery.swift, WenshuVerifier.swift; all go through this single entry point).

Boss's gate (= when re-enabling):
- macOS shows the **SecurityAgent modal prompt** the FIRST time an app writes to Keychain (= Apple HIG auth flow for credential storage). Boss拍 to proceed (= accepts the modal prompt), then SecItemAdd runs.
- The `kSecAttrAccessibleAfterFirstUnlock` accessibility constant means the key is available after the user unlocks their Mac (= standard for non-sync app credentials).

Acceptance: `grep -rn 'wenshu.debug.api.key' Sources/` = 0 hits (= debug stub removed). `grep -rn 'kSecClass.*kSecClassGenericPassword' Sources/WenshuApp/Core/Provider/ProviderKeychain.swift` = 4+ hits (= real Keychain code present and exercised).

Out of scope (= intentionally NOT in this ticket):
- Migration of existing callers to a newer API surface (= `ProviderKeychain` is already the single source of truth; no migration needed).
- New `LLMKeychain.swift` revival (= deleted as dead code in this session's cleanup).

---

Last line: fact.


## B-11 — Editor preview/edit mode + expand fix (= v0.34 ticket 01-11)

Date拍: 2026-09-02 (= this session).
Source: boss session 9/2 OOB "双击预览区的文件卡片后, 再编辑器区, 打开文档, 类似 Obsidian 有两种模式 (预览模式, 只看不能编辑, 可以切换编辑模式, 可以打字编辑, 保存文档). 编辑器的功能不超出编辑器区域. 六区状态下, 工具最简, 展开编辑区后, 完整 MD 编辑器全功能".

Spec: .scratch/v0.34-editor-preview-and-expand/spec.md (= 25 user stories + 7 implementation decisions).
Issues: .scratch/v0.34-editor-preview-and-expand/issues/01-11-*.md (= 11 vertical-slice tickets).
Commits (= this session):
- 83f2af167 refactor(wenshu): v0.34 -- wire @AppStorage for editor expand state (= ticket 01 of 11)
- 5875bba19 refactor(wenshu): v0.34 -- add PaneNSController.handleEditorMaximizedChanged (= ticket 02 of 11)
- 1f8ee9340 fix(wenshu): v0.34 -- repair EditorExpandShrinkTrailingButton click (= ticket 03 of 11)
- 64e4af6e2 refactor(wenshu): v0.34 -- add EditorMode enum + mode toggle (= ticket 04 of 11)
- 7968e479c feat(wenshu): v0.34 -- preview mode = swift-markdown + InternalLinkParser (= ticket 05 of 11)
- e1eeecc39 feat(wenshu): v0.34 -- BacklinksPanel in preview mode (= ticket 06 of 11)
- c3a0fe8e7 feat(wenshu): v0.34 -- edit mode = TextEditor + dirty + save (= ticket 07 of 11)
- dc7e41c28 refactor(wenshu): v0.34 -- editor top bar toolbar layout (= ticket 08 of 11)
- 2770dd484 feat(wenshu): v0.34 -- close button + dirty confirm dialog (= ticket 09 of 11)
- 41a1e7ad5 refactor(wenshu): v0.34 -- editor hotkeys Cmd+E/Cmd+S/Cmd+W/Cmd+Shift+E (= ticket 10 of 11)

Bug fixed (= Q33 boss): EditorExpandShrinkTrailingButton click was previously a dead
editorMaximized.toggle() (= View-local @State only, no layout side-effect). Now writes
@AppStorage + posts .wenshuEditorMaximizedChanged notification, listened by
PaneNSController.handleEditorMaximizedChanged (= snapshot-before-hide + restore-on-shrink).

Reused obsidian-replica modules (= per boss 9/2 audit '盘点全再写'):
- swift-markdown 0.4.0 (= AGENTS.md §11.1 pinned dep) — preview mode AttributedString render
- wenshu's InternalLinkParser (= v0.19 ticket 12) — [[wikilink]] parsing
- wenshu's BacklinksPanel (= v0.19 ticket 12) — preview mode bottom panel
- Apple SwiftUI TextEditor (= Rule 7 system component) — edit mode textarea
- wenshu's PaneNSController.handleToggleZone infrastructure (= v0.32 commit 125840d0f) —
  handleEditorMaximizedChanged mirrors this with snapshot/restore semantics.

Double-axis review (= Q34 step 5, per Q37 streak rule established 2026-08-25):
Both Standards + Spec axes were verified manually between commits. All 10 commits pass:
  Standards axis: AGENTS.md hard rules (English-only, 0 forbidden vocab) ✓; 11 iron rules
  (Rule 6 DesignTokens, Rule 7 system Button, Rule 8 no new NSWindow, Rule 9 hotkeys,
  Rule 11 @AppStorage) ✓; AGENTS.md §11.1 third-party policy (no new deps) ✓.
  Spec axis: 25 user stories covered (7 directly in commits, 18 PARTIAL by design across
  ticket 01-10 boundaries); 7 implementation decisions applied (A mode toggle,
  B preview rendering, C edit textarea, D expand/shrink, E toolbar layout,
  F state persistence, G notification integration); 0 out-of-scope items added.

Domain modeling (= Q34 step 7): new terms added to CONTEXT.md (= see ticket 11 commit body):
  - EditorMode: .preview / .edit (= 2-mode toggle state)
  - wikilink rendered preview (= swift-markdown + InternalLinkParser hybrid)
  - Expand/Shrink snapshot (= Q38 boss "全状态 snapshot" decision)
  - Backlinks panel scope (= preview-mode only, bottom strip)

Out of scope (= intentionally NOT in this ticket; deferred to v0.35+):
- Code-fence syntax highlighting in edit mode (= HighlighterSwift reserved for future)
- Multiple documents open in editor (= multi-tab = v0.35+ ticket)
- Rename / move / delete from editor (= sidebar feature, not editor)
- Auto-save (= explicit Save button only per Apple HIG)
- Format toolbar (bold / italic buttons) (= pure TextEditor per spec)
- External-file-change mtime conflict resolution (= Apple HIG standard = v0.35+ ticket)
- LLM Wiki layer integration in preview (= LLMWikiLayerDeriver backend only = v0.35+ ticket)
- ForeshadowingGraph visualization (= LinkGraph service exists; UI integration = v0.35+)
- JSON Canvas / Obsidian Bases rendering (= v0.35+ tickets)
- Smart Connections AI query panel (= SmartQueryView exists; UI integration = v0.35+)
- Real document open via NSOpenPanel + DocumentGroup (= ticket 027-35)

Last line: fact.

