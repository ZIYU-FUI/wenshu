# v0.19 Obsidian replica modules → front-end integration requirements list

> 老板 2026-08-19 evening 拍: 'organize currently-implemented modules, organize a requirements list, plan where to use on the front end'
> Date: 2026-08-19 evening
> Truth source: v0.19 ticket 12-23 backend modules + standalone SwiftUI View implementations

## Overview (12 modules + 19 UI integration requirements)

| # | Module | ticket | Backend truth | Standalone View already implemented | Pending front-end integration location |
|---|---|---|---|---|---|
| 1 | Internal Link + Backlinks | 12 | LinkIndex (SQLite) + InternalLinkParser + BacklinkResolver | BacklinksPanel | Upper band editor right pane (follows current doc) |
| 2 | Canvas + JSON Canvas | 13 | JSONCanvasCodec (Codable 1:1) | CanvasView | Upper band new independent zone (whiteboard outline / character relationship graph) |
| 3 | Graph view | 14 | GraphBuilder (build + layout + local) | GraphView | New independent tab or independent window (full vault relationship graph) |
| 4 | Templates | 15 | TemplateEngine (date/time/title/author/custom tokens) | TemplatePicker | File menu → New note (select template) |
| 5 | Note Composer | 16 | NoteComposer (rename/merge/split) | ComposerPanel | File menu → Merge / Split / Rename note |
| 6 | Full Text Search | 17 | FullTextSearch (SQLite FTS5 trigram) | SearchPanel | Editor top-right ⌘F (search box + highlight) |
| 7 | Bases database view | 18 | BaseParser (.base YAML) | BaseView | Upper band new independent zone (character table / chapter progress table) |
| 8 | Quick Switcher | 19 | QuickSwitcherIndex (fuzzy match) | QuickSwitcherWindow | ⌘O popup window (cross-bookshelf quick jump) |
| 9 | Word count | 20 | WordCounter (Chinese-English mixed) | WordCountBadge | Top bar right (consistent with macOS standard word count) |
| 10 | Outline | 21 | OutlineExtractor (H1-H6 + tree) | OutlinePanel | Editor right pane (follows current note H1-H6 jump) |
| 11 | Bookmarks | 22 | BookmarkStore (actor SQLite) | BookmarkPanel | Upper band editor right pane + ⌘⇧B popup |
| 12 | Integration + cross-tool compatibility | 23 | ObsidianFixturesTests (round-trip) | — | (no front end, integration test) |

## Detailed integration requirements (by wenshu 6-zone layout distribution)

### Top bar (titleBar) — 1 requirement

| # | Requirement | Source | Integration location | 老板 8/18 拍板 |
|---|---|---|---|---|
| 1 | Top bar right show current note word count + chapter switch dropdown | ticket 20 Word count + ticket 8 Outline | Top bar right (consistent with macOS Pages / Numbers) | "Overall dark/light mode implementation" already has top bar layout, add word count + chapter switch |

### Upper band (4 zones, 200/520/794/400 PT) — 6 requirements

| # | Requirement | Source | Integration location | Note |
|---|---|---|---|---|
| 2 | Editor right pane: Outline (H1-H6 jump) | ticket 21 Outline | Upper band column 3 (794 PT editor) right side new right pane (400 PT reduction) | Share right pane logic with first 3 Backlinks / Canvas / Bases / Search |
| 3 | Editor right pane: Backlinks panel (reverse links) | ticket 12 Internal Link | Upper band editor right pane (switch with Outline tab) | When writing current chapter show all settings / chapters referencing it |
| 4 | Editor right: Quick Switcher trigger button (or ⌘O global) | ticket 19 Quick Switcher | Top bar right icon + ⌘O global shortcut | Apple Spotlight same pattern |
| 5 | Editor top-right: Search trigger icon (or ⌘F) | ticket 17 Full Text Search | Editor right pane top + ⌘F global shortcut | Cross-bookshelf search chapter content |
| 6 | Canvas / whiteboard outline independent zone (new 1 zone) | ticket 13 Canvas + JSON Canvas | Upper band new column 5 (independent Canvas tab) | wenshu 6-zone layout adjustment: upper 4 + lower 2 → upper 5 + lower 2 (new Canvas zone) |
| 7 | Bases database view independent zone (new 1 zone) | ticket 18 Bases | Upper band new column 6 (independent Bases tab) | wenshu 6-zone layout adjustment: upper 5 + lower 2 → upper 6 + lower 2 (new Bases zone) |

### Lower band (2 zones, AI chat 1518 / AI dynamic 400 PT) — 0 requirements

(AI chat / AI dynamic unrelated to Obsidian replica, keep existing implementation)

### Editor main area — 5 requirements

| # | Requirement | Source | Integration location | Note |
|---|---|---|---|---|
| 8 | Markdown editor parses `[[name]]` display as internal link (blue underline, ⌘+click jump) | ticket 12 Internal Link Parser | Editor main area text rendering layer | Consistent with Obsidian wikilink rendering |
| 9 | Editor auto rewrite `[[old_name]]` → `[[new_name]]` (when renaming note) | ticket 16 Note Composer.rename | Editor main area + BacklinkResolver linkage | Note Composer rename triggers auto scan all content |
| 10 | Editor auto merge multiple note contents (when merging) | ticket 16 Note Composer.merge | Editor main area + Note Composer linkage | merge simplified: concatenate content, middle blank line |
| 11 | Editor insert template (when creating new note) | ticket 15 Templates | File menu → New → select template → auto insert `{{date}}` etc tokens | Consistent with Obsidian Templates behavior |
| 12 | Editor real-time word count (top-right badge) | ticket 20 Word count | Editor main area top-right badge | Real-time update, writer daily word count |

### Global commands / menus — 5 requirements

| # | Requirement | Source | Integration location | Note |
|---|---|---|---|---|
| 13 | File menu: New note (select template) | ticket 15 Templates | Menu "File" → "New" → popup template selection (ticket 15 TemplatePicker) | Apple HIG standard "New Project" |
| 14 | File menu: Rename / Merge / Split note | ticket 16 Note Composer | Menu "File" → "Composer" submenu | Consistent with ticket 13 ticket 11 existing menu layout |
| 15 | View menu: Outline / Backlinks / Search / Canvas / Bases panel switch | ticket 12/13/17/18/21 | Menu "View" → existing "Restore Default Layout", new 5 panel switches | Consistent with ticket 14 ticket 09 "View" top-level menu pattern |
| 16 | ⌘O global: Quick Switcher popup | ticket 19 Quick Switcher | Top bar menu / global shortcut | Apple Spotlight same pattern (⌘+Space) |
| 17 | ⌘⇧B global: Bookmarks popup | ticket 22 Bookmarks | Top bar menu / global shortcut | Cross-note favorites |

### Bookmarks / Quick Actions — 2 requirements

| # | Requirement | Source | Integration location | Note |
|---|---|---|---|---|
| 18 | Right pane Bookmarks tab (coexists with Outline / Backlinks) | ticket 22 Bookmarks | Editor right pane new Bookmarks tab | Switch with ticket 12 / 21 panel tabs |
| 19 | Editor top-right Bookmark button (add current note to favorites) | ticket 22 Bookmarks | Editor main area top-right + top bar right | ⌘+D shortcut |

## Priority matrix

| Priority | Requirement | Source | Effort estimate |
|---|---|---|---|
| 🟢 P0 (writing app strong requirement) | 2 Outline right pane, 3 Backlinks right pane, 5 Search full-text, 9 Rename auto rewrite links, 12 Word count badge, 8 wikilink rendering, 16 ⌘O Quick Switcher | ticket 12/17/19/20/21 | 2-3 weeks |
| 🟡 P1 (core enhancement) | 6 Canvas independent zone, 13 New template, 15 View menu, 18 Bookmarks tab | ticket 13/15/22 | 2-3 weeks |
| 🟢 P2 (writing experience enhancement) | 1 Top bar chapter switch, 10 Merge note, 11 Split note, 14 Composer submenu, 4 Quick Switcher button, 17 ⌘⇧B Bookmarks, 19 Bookmark add button, 7 Bases independent zone | ticket 12/13/15/16/18/19/20/22 | 3-4 weeks |

## UI changes impact on LayoutTokens

| Requirement | Change | Conflict with ticket 14 dead principle? |
|---|---|---|
| 2/3/5/18 right pane panel tabs | Upper band editor right pane width ratio (794 PT → reduction) + new panel tab switch | ❌ No conflict (internal sub-tabs) |
| 6 Canvas independent zone | Upper band 4 zones → 5 zones (new 1 zone, ratio redivided) | ❌ Conflict (LayoutTokens is dead principle, ratio already 1:1 PT locked) — needs 老板 拍 |
| 7 Bases independent zone | Same as above | ❌ Same |

**Key decision point:** Requirements 6/7 Canvas + Bases independent zones conflict with ticket 14 LayoutTokens dead principle (1920×984 PT 1:1 locked, 6-zone layout), needs 老板 拍 to change. Or use **panel tabs switch** (right pane multi-tab switch) to avoid layout changes.

## Integration order suggestion (by large workload but stable + dependency relationship)

**Phase 1 (P0 strong requirement, 1-2 weeks)**
1. ticket 12 Backlinks right pane (backend already complete, front-end standalone View directly connects)
2. ticket 21 Outline right pane (shares right pane tab switch with Backlinks)
3. ticket 17 Search ⌘F (shares right pane tab switch with Backlinks)
4. ticket 20 Word count top bar badge (independent small widget, smallest change)
5. ticket 19 Quick Switcher ⌘O (independent popup, doesn't affect layout)

**Phase 2 (P1 core enhancement, 2-3 weeks)**
6. ticket 13 Canvas (use panel tabs switch to avoid layout change)
7. ticket 18 Bases (same)
8. ticket 15 Templates menu integration
9. ticket 22 Bookmarks right pane

**Phase 3 (P2 writing experience enhancement, 3-4 weeks)**
10. ticket 16 Note Composer menu + auto rewrite
11. ticket 12 wikilink editor rendering (blue underline + ⌘+click jump)
12. Top bar chapter switch dropdown

## Don't-connect list (per wenshu positioning)

| Module | Reason for not connecting |
|---|---|
| Sync with Obsidian (Obsidian Sync) | Closed-source paid, wenshu local self-management |
| Sync with Obsidian Publish | Closed-source paid, wenshu writing doesn't need public publishing |
| Plugin API (dynamic loading) | wenshu single-app compiled, doesn't need extension mechanism |
| Mobile (iOS/Android) | wenshu macOS-only (老板 8/18 拍) |
| Web viewer (iframe) | Writing app doesn't need |
| Daily Notes (calendar auto create) | Writing app doesn't need |
| Command Palette (⌘⇧P) | wenshu `.commands` top-level menu enough |
| Slash commands (in editor /) | Writing app doesn't need |

## Subsequent tickets (per wenshu positioning)

- Integrate UI connection ticket: ticket 24 (right pane panel tabs framework) + ticket 25 (Quick Switcher ⌘O) + ticket 26 (top bar word count badge) + ...
- Connection order: Phase 1 → Phase 2 → Phase 3, each ticket 1 commit
- After 老板 macOS verifies, start front-end integration (currently 12 standalone SwiftUI Views await 老板 verification)