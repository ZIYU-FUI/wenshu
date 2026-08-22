# v0.19 front-end integration requirements merged list (老板 2026-08-19 evening)

> Date: 2026-08-19 evening
> Truth source:
> 1. 老板 2026-08-19 evening's other-session list (18 UI requirements, contains 4 high + 10 medium + 5 low, hermes replica 18 modules front-end integration)
> 2. My own v0.19 spec-ui-integration.md (19 UI requirements, Obsidian replica 12 modules front-end integration)
> 3. v0.18 ticket 09-31 commit truth (local backend modules all pushed)
> 4. v0.19 ticket 12-23 commit truth (Obsidian replica backend + standalone SwiftUI View)

## Merge principles

1. **Same module don't duplicate** (e.g. hermes Memory + Obsidian no intersection)
2. **Linkage points separately mark "🔗 Linked"** — 老板 when integrating should do together
3. **Priority preserve both lists'** — 老板's own priority, don't unilaterally change
4. **Conflict points separately mark "⚠️ Conflict"** — conflict with LayoutTokens dead principle / module boundary overlap

## Overview (老板 other-session 18 + my own 19 = 36, merge dedupe = 32)

| Priority | Count | Source |
|---|---|---|
| 🔥 High | 7 (includes 1 mine added) | 老板 4 + mine 3 |
| 🟡 Medium | 14 (includes 1 老板 newly added) | 老板 10 + mine 4 |
| 🟢 Low | 5 | 老板 5 |
| Don't connect | 8+ | Both lists intersection + excluded per wenshu positioning |

## 🔥 High (7)

| # | Requirement | Source | Module / ticket | Linkage / note |
|---|---|---|---|---|
| 1 | **Memory UI** | 老板 4-01 | MemoryStore (v0.18 ticket 01, commit `047b43cfa`) | SwiftUI `.onAppear` inject + Toolbar "Memory" button + Popover |
| 2 | **Skill UI** | 老板 4-02 | SkillRegistry (v0.18 ticket 02, commit `b5c219f3b`) | Settings scene (Settings commit `4c42fa79` already has) + Skills list |
| 3 | **MiniMax Agent UI** | 老板 4-03 | AgentProtocol + MiniMaxVerifier (v0.18 ticket 03 + 31) | Toolbar "Agent" button + chat sheet (integrated with LayoutShellView top bar) |
| 4 | **Word Count UI** | 老板 4-19 + my list #1 + #12 | WordCounter (v0.19 ticket 20, commit `2d3ede1b3`) | 老板 list: status bar word count; my list: top bar badge + editor top-right; **🔗 Merge: top bar right widget + real-time selection region word count** |
| 5 | **Backlinks UI** | my list #3 | BacklinksPanel (v0.19 ticket 12, commit `bc4cfd76b`) | 老板 list #15 LinkGraph UI contains Backlinks, do together with wikilink auto-complete |
| 6 | **Outline UI** | my list #2 | OutlinePanel (v0.19 ticket 21, commit `fd4708264`) | 老板 list #16 Outline contains, integrate with sidebar "Outline" tab |
| 7 | **Quick Switcher UI** | my list #5 + #16 | QuickSwitcherWindow (v0.19 ticket 19, commit `62f788ed4`) | ⌘O global shortcut (same Apple Spotlight pattern) |

## 🟡 Medium (14)

| # | Requirement | Source | Module / ticket | Linkage / note |
|---|---|---|---|---|
| 8 | **Kanban UI** | 老板 4-04 | KanbanStore (v0.18 ticket 05, commit `2172c421c`) | Sidebar NavigationSplitView "Projects" tab |
| 9 | **Todo UI** | 老板 4-05 | TodoStore (v0.18 ticket 06, commit `4551ce0af`) | Sidebar "Today" tab (simple GTD) |
| 10 | **File Tools UI** | 老板 4-06 | FileTools (v0.18 ticket 07, commit `a48a0904d`) | Editor right-click menu + Toolbar open/save buttons (NSOpenPanel + NSSavePanel) |
| 11 | **Web Fetch UI** | 老板 4-08 | WebTools (v0.18 ticket 09, commit `c082e5c07`) | Editor right-click "Insert URL" → fetch + extract + insert markdown |
| 12 | **Vision UI** | 老板 4-09 | VisionTools (v0.18 ticket 10, commit `c231d9d21`) | Editor right-click "OCR image" → recognizeText → insert text |
| 13 | **Multi-Agent UI** | 老板 4-13 | AgentRuntime (v0.18 ticket 04, commit `a1b12d810`) | Settings "Agents" tab + delegate button |
| 14 | **Canvas UI** | 老板 4-14 + my list #6 | JSONCanvasCodec + CanvasView (v0.19 ticket 13, commit `265f68ec0`) | **⚠️ Conflict: upper band 4 zones → 5 zones, conflicts with LayoutTokens dead principle, needs 老板 拍** or use panel tabs to avoid |
| 15 | **LinkGraph UI** | 老板 4-15 | BacklinksPanel + QuickSwitcher (v0.19 ticket 12) | **🔗 Linked: merge with #5 Backlinks UI, editor `[[wikilink]]` auto-complete + Backlinks panel** |
| 16 | **Outline UI (sidebar)** | 老板 4-16 | OutlinePanel (v0.19 ticket 21) | **🔗 Linked: merge with #6, same module same integration location** |
| 17 | **Search UI** | 老板 4-17 + my list #5 | SearchPanel (v0.19 ticket 17, commit `211bfc960`) | ⌘⇧F (老板 version) / ⌘F (my version) — **🔗 Merge: ⌘F global (consistent with Obsidian), ⌘⇧F into advanced** |
| 18 | **Bases UI** | my list #7 | BaseView (v0.19 ticket 18, commit `3119ef559`) | **⚠️ Conflict: same as Canvas, layout conflict, use panel tabs to avoid** |
| 19 | **Note Composer UI** | my list #9 / #10 / #14 | ComposerPanel (v0.19 ticket 16, commit `a2932eeb7`) | File menu → Composer submenu (rename / merge / split) |
| 20 | **Templates UI (file menu)** | 老板 4-18 + my list #11 | TemplatePicker (v0.19 ticket 15, commit `1edc9a7b8`) | 老板 list: "New" button → template selection sheet; my list: File menu → select template — **🔗 Merge: Toolbar "New" + file menu** |
| 21 | **Wikilink editor rendering** | my list #8 / #9 | InternalLinkParser + BacklinkResolver (v0.19 ticket 12) | **🔗 Linked: do together with #5 / #15 LinkGraph UI** |

## 🟢 Low (5)

| # | Requirement | Source | Module / ticket | Linkage / note |
|---|---|---|---|---|
| 22 | **Process UI** | 老板 4-07 | ProcessTools (v0.18 ticket 08, commit `a4f251692`) | Toolbar "Run" button + NSTextField input |
| 23 | **TTS UI** | 老板 4-10 | AVMediaTools (v0.18 ticket 11, commit `9fb1d5257`) | Toolbar "Read" button (AVSpeechSynthesizer) |
| 24 | **Cron UI** | 老板 4-11 | Cronjob (v0.18 ticket 21, commit `ce851abda`) | Settings "Scheduled tasks" list |
| 25 | **Backup UI** | 老板 4-12 | Backup (v0.18 ticket 26, commit `e6b970b03`) | Toolbar "Backup" button + sheet |
| 26 | **Bookmarks UI** | my list #17 / #18 / #19 | BookmarkPanel (v0.19 ticket 22, commit `569ebe1d6`) | ⌘⇧B (老板 version) / editor right pane + Toolbar (my version) — **🔗 Merge: Toolbar + ⌘⇧B popup + editor right pane tab** |

## 🔗 Linked groups (when integrating 老板 should do together)

| Linked group | Contains requirements | Reason |
|---|---|---|
| **LinkGraph linked** | #5 Backlinks + #15 LinkGraph + #21 Wikilink | Same module (LinkIndex) three integrations: editor rendering / Backlinks panel / `[[wikilink]]` auto-complete |
| **Outline linked** | #6 + #16 | Same module (OutlineExtractor), I do right pane / 老板 does sidebar — **🔗 Merge: same integration location (right pane / sidebar either-or, 老板 拍)** |
| **Search linked** | #17 (two shortcuts) | Same module (FullTextSearch), ⌘F main / ⌘⇧F advanced — **🔗 Merge: same sheet, ⌘F into basic, ⌘⇧F into advanced** |
| **Templates linked** | #20 (two integration points) | Same module (TemplatePicker), Toolbar + file menu — **🔗 Merge: Toolbar entry + file menu submenu entry** |
| **Bookmarks linked** | #26 (three integration points) | Same module (BookmarkPanel), Toolbar + ⌘⇧B popup + editor right pane — **🔗 Merge: Toolbar add + ⌘⇧B popup list + editor right pane** |
| **Composer linked** | #19 (rename / merge / split) | Same module (NoteComposer), file menu submenu — linked with #5 Backlinks (rename triggers auto rewrite) |

## ⚠️ Conflict points (only 老板 拍 can move)

| Conflict | Impact | Alternative |
|---|---|---|
| **Canvas independent zone** (#14) | Upper band 4 zones → 5 zones, conflicts with ticket 14 LayoutTokens dead principle (1920×984 PT 1:1 locked) | Use panel tabs switch (right pane multi-tab, Canvas shares with Outline / Backlinks) — don't touch layout |
| **Bases independent zone** (#18) | Same as Canvas | Same, panel tabs switch |

## Don't-connect list (both lists intersection + excluded per wenshu positioning)

| Module | Don't-connect reason | Source |
|---|---|---|
| Obsidian Sync | Closed-source paid, wenshu local self-management | my list |
| Obsidian Publish | Closed-source paid | my list |
| Plugin API (dynamic loading) | wenshu single-app compiled | my list |
| Mobile (iOS/Android) | wenshu macOS-only (老板 8/18 拍) | my list |
| Web viewer (iframe) | Writing app doesn't need | my list |
| Daily Notes | Writing app doesn't need | my list |
| Command Palette (⌘⇧P) | wenshu `.commands` top-level menu enough | my list |
| Slash commands | Writing app doesn't need | my list |
| A2A protocol (v0.18 ticket 03) | Backend replica completed, front-end doesn't need separate UI, integrates through MiniMax Agent UI | Implicit |

## Integration order suggestion (by large workload but stable + dependency relationship)

### Phase 1 P0 strong requirement (1-2 weeks)

1. **#1 Memory UI** (backend already complete, Toolbar simple widget)
2. **#2 Skill UI** (Settings list, integrates with existing Settings scene)
3. **#3 MiniMax Agent UI** (Toolbar + chat sheet, integrates with top bar)
4. **#4 Word Count UI** (top bar right badge, smallest change)
5. **#5 Backlinks UI** (editor right pane panel tabs framework build first)
6. **#6 Outline UI** (switches with #5 same right pane tab)
7. **#7 Quick Switcher UI** (⌘O popup, independent no conflict)

### Phase 2 P1 core enhancement (2-3 weeks)

8. **#8 Kanban UI** (sidebar NavigationSplitView, larger change)
9. **#9 Todo UI** (sidebar)
10. **#10 File Tools UI** (right-click menu + NSOpenPanel)
11. **#17 Search UI** (⌘F + ⌘⇧F sheet)
12. **#11 Web Fetch UI** (right-click menu)
13. **#12 Vision UI** (right-click menu OCR)
14. **#19 Note Composer UI** (file menu submenu, linked with #5)
15. **#20 Templates UI** (Toolbar + file menu)

### Phase 3 P2 writing experience enhancement (3-4 weeks)

16. **#21 Wikilink editor rendering** (editor text rendering layer)
17. **#13 Multi-Agent UI** (Settings)
18. **#14 Canvas UI** (use panel tabs to avoid layout)
19. **#18 Bases UI** (use panel tabs to avoid layout)
20. **#26 Bookmarks UI** (Toolbar + ⌘⇧B + right pane tab)
21. **#15 LinkGraph UI** (do together with #5)
22. **#16 Outline sidebar** (either-or with #6)
23. **#22 Process UI** (Toolbar "Run" button)
24. **#23 TTS UI** (Toolbar "Read" button)
25. **#24 Cron UI** (Settings scheduled tasks list)
26. **#25 Backup UI** (Toolbar "Backup" button)

## LayoutTokens dead principle decision points

| Item | Relationship with LayoutTokens | Needs 老板 拍? |
|---|---|---|
| #5/#6/#15/#16/#26 editor right pane panel tabs | Share right pane width, don't touch layout ratio | ❌ No conflict |
| #7/#17 Quick Switcher / Search popup | Independent popup, doesn't affect layout | ❌ No conflict |
| #8/#9 sidebar NavigationSplitView | Upper band unchanged, add left sidebar | ❌ No conflict (left sidebar and LayoutTokens upper band are different layers) |
| #14 Canvas independent zone | Upper band 4 → 5 zones, change LayoutTokens | ⚠️ Needs 老板 拍 |
| #18 Bases independent zone | Same as Canvas | ⚠️ Needs 老板 拍 |
| #1/#2/#3/#4/#13/#22/#23/#24/#25 Toolbar buttons | Top bar / toolbar, doesn't affect upper band | ❌ No conflict |

## Todo (老板 拍 next step)

- Confirm Phase 1 start work (7 P0)
- Confirm Canvas / Bases through panel tabs to avoid layout (or insist on independent zones, change LayoutTokens)
- Confirm merged list coverage completeness
- Subsequent ticket scheduling: ticket 24 (panel tabs framework) + ticket 25+ (per order integration)