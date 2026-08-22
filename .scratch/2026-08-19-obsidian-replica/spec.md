# Spec — Obsidian replica capability inventory + wenshu writing app adaptation (老板 2026-08-19 evening 拍)

> Date: 2026-08-19 evening
> Spec uses po `to-spec` skill 7-section template
> Truth source: Obsidian public docs (https://obsidian.md/help + https://jsoncanvas.org + https://github.com/obsidianmd/jsoncanvas + https://github.com/obsidianmd/obsidian-api)

## Problem Statement

老板 2026-08-19 evening 拍:
> "Don't accept (ticket 21 Cronjob), I'll go talk to that one, continue, you investigate in current session how to, OB capabilities we want to replica, list them clearly, see if we can replica, you can git a copy of ob's code, take a good look"

**Business-language description (老板 understands)**:
- Previously v0.18 hermes replica scope A ran 9 tools (MemoryStore / SkillRegistry / AgentProtocol / AgentRuntime / KanbanStore / TodoStore / FileTools / ProcessTools / WebTools)
- 老板 now wants wenshu to also replica Obsidian (Markdown notes app) capabilities, compare with writing app positioning to see which can be localized
- 老板 拍 "git a copy of ob's code" = git clone Obsidian public repo + read official docs

## Obsidian capability inventory (per truth)

### A. Core data model (4 items)

1. **Vault** = local Markdown folder + subfolder structure, all data stored locally
2. **Note** = pure Markdown files (.md), frontmatter optional (YAML)
3. **Internal Link** = `[[note name]]` bidirectional link (wiki-style)
4. **Property** = YAML frontmatter (status / tags / author / custom), Bases strongly depends on

### B. Core plugins (16) + scoring

Per wenshu writing app positioning (long-form fiction novel AI creation) determine what to replica:

| # | Plugin | Obsidian functionality | wenshu adaptation | Priority |
|---|---|---|---|---|
| 1 | **Backlinks** | Right pane shows current note all reverse links, bidirectional graph key | Already implemented `Domain.Document` 3 types, but **no reverse link / bidirectional graph**, writing app strong requirement | 🟢 High |
| 2 | **Graph view** | Full vault node relationship graph, Local graph follows current note | Writing app strong requirement (character relationship graph / outline graph / plot graph), Canvas already implemented but **not graph** | 🟢 High |
| 3 | **Canvas** | Infinite canvas + JSON Canvas file format (open spec MIT) + node cards | wenshu LayoutShellView 6 zones already uses SwiftUI Canvas to draw layout, **not JSON Canvas**, need to replica JSON Canvas file format + node editing | 🟢 High |
| 4 | **Daily Notes** | Auto-create note per date + template (date tokens) | Writing app not very needed (but writing calendar / word count can use) | 🟡 Medium |
| 5 | **Templates** | Template file + variable insertion | Writing app strong requirement (outline template / character template / chapter template) | 🟢 High |
| 6 | **Outline** | Current note outline (H1-H6) | wenshu `Book` + `Document` already categorized, but **no outline panel** | 🟡 Medium |
| 7 | **Bookmarks** | Favorites / cross-note anchors | Writing app usable (favorite chapters / setting fragments) | 🟡 Medium |
| 8 | **Note Composer** | Merge / split / rename note, auto-rewrite links | Writing app strong requirement (chapter merge / split / rename with link auto-follow) | 🟢 High |
| 9 | **Search** | Full-text search + regex + file filter | wenshu already has `WenshuLibrary.loadDocumentContent`, but **no full-text search panel** | 🟢 High |
| 10 | **Bases** | Database view (table / card / kanban / map) + YAML syntax + formulas | Writing app strong requirement (character table / chapter progress / setting table), partial overlap with v0.18 ticket 05 KanbanStore | 🟢 High |
| 11 | **File Recovery** | Snapshot + delete recovery | wenshu already has FileManager + Library, but **no snapshot** | 🟡 Medium |
| 12 | **Quick Switcher** | ⌘O global search note | Writing app strong requirement (cross-bookshelf switch) | 🟢 High |
| 13 | **Command Palette** | ⌘⇧P command palette | wenshu already has SwiftUI `.commands` (CommandMenu), but **not fuzzy command palette** | 🟡 Medium |
| 14 | **Slash commands** | Editor `/` trigger commands | Writing app strong requirement (quick insert chapter marker / character reference) | 🟡 Medium |
| 15 | **Web viewer** | vault inline webpage iframe | Writing app not very needed | ❌ Skip |
| 16 | **Word count** | Current note / vault word count | Writing app strong requirement (writer must-have) | 🟢 High |

### C. File format (3 items, all open-source MIT)

| Format | URL | Content |
|---|---|---|
| **JSON Canvas** | https://jsoncanvas.org/spec/1.0 | `nodes[]` (id / type / x / y / width / height / file\|text) + `edges[]` (id / fromNode / toNode / fromSide / toSide / fromEnd / toEnd / label / color) |
| **Markdown** | CommonMark + GFM | wenshu already has |
| **.base** (YAML) | Obsidian own | views[] + filters{} + formulas{} + properties{} + summaries{} |

### D. Plugin API (public, TypeScript types)

`https://github.com/obsidianmd/obsidian-api` — `manifest.json` + `Plugin` class + `Workspace` / `Vault` / `Editor` / `MarkdownView` etc interfaces. **wenshu doesn't need plugin API**, because wenshu is single-app compiled-in-one, no dynamic loading needed.

### E. Cross-platform

- Desktop: macOS / Windows / Linux (Electron)
- Mobile: iOS / Android
- Sync: Obsidian Sync (paid, closed-source, **not** replica)

## Solution (per wenshu positioning)

老板 8/19 evening 拍 wenshu positioning = **SwiftUI desktop writing app (macOS-only)**, not general-purpose notes app.

**Replica decision matrix** (per wenshu writing app positioning, not general PKM):

| Obsidian capability | Replica | Not replica | Reason |
|---|---|---|---|
| Vault folder structure | ✅ | | wenshu `LibraryRoot` already implemented |
| Note Markdown file | ✅ | | wenshu `Document` already implemented |
| Internal Link `[[name]]` | ✅ | | **Writing app strong requirement** (character / setting / chapter cross-ref) |
| Backlinks reverse link | ✅ | | **Writing app strong requirement** (character relationship graph) |
| Property frontmatter | ✅ | | wenshu `Book` already has length / idea fields, extend frontmatter |
| Graph view | ✅ | | **Writing app strong requirement** (character relationship graph / plot graph) |
| Canvas (infinite canvas) | ✅ | | **Writing app strong requirement** (whiteboard outline / character relationship) |
| JSON Canvas file format | ✅ | | open MIT, must 1:1 implement (cross-tool compatible) |
| Daily Notes | | ❌ | Writing app not very needed |
| Templates | ✅ | | **Writing app strong requirement** (outline template / chapter template) |
| Outline | ✅ | | Writing app medium (chapter list already implemented) |
| Bookmarks | ✅ | | Writing app medium |
| Note Composer | ✅ | | **Writing app strong requirement** (chapter merge / rename follow) |
| Search (full-text) | ✅ | | **Writing app strong requirement** |
| Bases (database view) | ✅ | | **Writing app strong requirement** (character table / chapter progress), overlap with KanbanStore |
| File Recovery (snapshot) | | ❌ | Backup uses macOS Time Machine + wenshu own backup ticket 26 |
| Quick Switcher | ✅ | | **Writing app strong requirement** |
| Command Palette | | ❌ | wenshu `.commands` top-level menu enough |
| Slash commands | | ❌ | Writing app not very needed |
| Web viewer | | ❌ | Writing app not needed |
| Word count | ✅ | | **Writing app strong requirement** (writer must-have) |
| Plugin API | | ❌ | wenshu single-app compiled, no dynamic loading needed |
| Obsidian Sync (paid) | | ❌ | Closed-source, don't replica |
| Obsidian Publish (paid) | | ❌ | Closed-source, don't replica |
| Mobile (iOS/Android) | | ❌ | wenshu macOS-only (老板 8/18 拍) |

**Replica total**: 13 / 24 = 54%

## User Stories

1. As 老板, I want wenshu to support Internal Link `[[name]]` bidirectional links, so that characters / chapters / settings can cross-reference
2. As 老板, I want wenshu to support Backlinks reverse-link panel, so that when writing current chapter can see all settings referencing it
3. As 老板, I want wenshu to support Canvas infinite canvas + JSON Canvas file format (1:1 compatible with Obsidian), so that whiteboard outline / character relationship graph can cross tools
4. As 老板, I want wenshu to support Graph view global relationship graph, so that when writing novel can see character relationships / plot lines
5. As 老板, I want wenshu to support Templates template system, so that outline / character / chapter templates can be reused
6. As 老板, I want wenshu to support Note Composer merge / split / rename + auto-follow links, so that when refactoring chapters links don't break
7. As 老板, I want wenshu to support full-text Search, so that cross-bookshelf search chapter content
8. As 老板, I want wenshu to support Bases database view, so that character table / chapter progress / setting table can be tabulated
9. As 老板, I want wenshu to support Quick Switcher ⌘O, so that cross-bookshelf quick switch
10. As 老板, I want wenshu to support Word count statistics, so that writer knows daily word count

## Implementation Decisions

Per 老板 8/19 拍 "large workload but stable" + 4 principles (Apple official paradigm / effect first / business language):

**Plan 1 (Internal Link + Backlinks + Property)**:
- Markdown parsing: on `LibraryStoring.loadDocumentContent` basis add `parseInternalLinks(content)` → `[(text, target)]`
- Bidirectional graph: new `Sources/WenshuApp/Core/LinkGraph/` directory
  - `LinkIndex.swift` — actor SQLite-backed, table schema = source_doc_id / target_ref / target_doc_id / line / offset
  - `BacklinkResolver.swift` — async resolve all note internal links, bidirectional index
  - `BacklinksPanel.swift` — SwiftUI View, right pane shows current note all backlinks
- Property (YAML frontmatter): new `Sources/WenshuApp/Core/Properties/`
  - `FrontmatterParser.swift` — parse YAML (Apple Yams or Foundation PropertyListSerialization, Apple official first)
  - `PropertyEditor.swift` — SwiftUI View, edit frontmatter fields

**Plan 2 (Canvas + JSON Canvas)**:
- File format 1:1 implementation: `Sources/WenshuApp/Core/Canvas/`
  - `JSONCanvasCodec.swift` — Codable parse .canvas files (nodes[] + edges[])
  - `CanvasView.swift` — SwiftUI Canvas draw nodes + edges (TimelineView 60 fps, same paradigm as LayoutShellView)
  - `CanvasEditor.swift` — node drag / edit / connect (Apple HIG mouse interaction)
- Compatible with Obsidian JSON Canvas 1.0 spec, cross-tool mutual read

**Plan 3 (Graph view)**:
- `Sources/WenshuApp/Core/Graph/`
  - `GraphView.swift` — SwiftUI Canvas full vault node relationship graph
  - `LocalGraph.swift` — follows current note's 1-hop / 2-hop sub-graph
  - Force-directed layout (Apple HIG, Apple Physics framework or self-write simple force-directed)

**Plan 4 (Templates)**:
- `Sources/WenshuApp/Core/Templates/`
  - `TemplateEngine.swift` — template file + date tokens (`{{date}}` / `{{time}}` / `{{title}}`)
  - `TemplatePicker.swift` — SwiftUI View choose template to create new note

**Plan 5 (Note Composer)**:
- `Sources/WenshuApp/Core/Composer/`
  - `NoteMerger.swift` — merge N notes → 1 note + rewrite all backlinks
  - `NoteSplitter.swift` — split note → N notes + rewrite backlinks
  - `NoteRenamer.swift` — rename + rewrite all `[[old_name]]` → `[[new_name]]`

**Plan 6 (Search)**:
- `Sources/WenshuApp/Core/Search/`
  - `FullTextSearch.swift` — actor SQLite FTS5 full-text index (Apple HIG, FTS5 SQLite built-in)
  - `SearchPanel.swift` — SwiftUI View, real-time search + highlight

**Plan 7 (Bases database view)**:
- `Sources/WenshuApp/Core/Bases/`
  - `BaseParser.swift` — YAML .base file parsing (reuse with FrontmatterParser)
  - `BaseView.swift` — table / card / kanban view
  - Integrate with v0.18 ticket 05 KanbanStore (Kanban is one Bases view)

**Plan 8 (Quick Switcher)**:
- `Sources/WenshuApp/Core/QuickSwitcher/`
  - `QuickSwitcher.swift` — ⌘O fuzzy search all notes + chapters
  - `QuickSwitcherWindow.swift` — SwiftUI Window popup (same paradigm as Apple Spotlight)

**Plan 9 (Word count)**:
- `Sources/WenshuApp/Core/WordCount/`
  - `WordCounter.swift` — `String.enumerateSubstrings(.word)` count (Apple HIG)
  - `WordCountBadge.swift` — SwiftUI View, top bar shows current note word count

**Untouched**:
- hermes app (老板 8/11 拍 'hermes don't touch')
- Any file under `/Volumes/ANAN/.hermes/`
- wenshu current SwiftUI UI / business logic (LayoutTokens / LayoutShellView / NativeSplitter / DesignTokens don't touch)
- Mobile (iOS/Android) — wenshu macOS-only

## Testing Decisions

- `swift build` exit 0
- Each new module add unit tests (LinkIndex / JSONCanvasCodec / TemplateEngine / FullTextSearch / BaseParser)
- Cross-tool compatibility test: Obsidian .canvas file → wenshu parse → wenshu .canvas file → Obsidian parse (1:1 round-trip)
- 老板 8/19 evening 拍 "no verification needed" — no screenshot evidence submission

## Out of Scope

- Do not replica Plugin API (wenshu single app, no dynamic loading)
- Do not replica Obsidian Sync (closed-source)
- Do not replica Obsidian Publish (closed-source)
- Do not replica Mobile (iOS/Android) (老板 8/18 拍 macOS-only)
- Do not replica Web viewer / Daily Notes / Command Palette / Slash commands (wenshu writing app doesn't need)
- Do not replica all Obsidian 24 capabilities, only replica 13 that wenshu writing app truly uses

## Further Notes

- 老板 8/19 evening 拍 "git a copy of ob's code" — web SSL failed (LibreSSL), switch to web_search + web_extract pull official docs + public repo README
- Truth source priority: official docs (obsidian.md/help) > JSON Canvas spec (jsoncanvas.org) > obsidian-api GitHub > third-party intros (Reddit / Medium / YouTube)
- Obsidian main repo (Electron) closed-source, replica can only be based on public docs + public API + JSON Canvas open format
- Replica scope 13/24 capabilities = 54%, strictly filtered per wenshu writing app positioning
- Subsequent ticket scheduling (per large workload but stable + high priority):
  - 🟢 High 7 tickets: Internal Link + Backlinks + Graph view + Canvas + Templates + Note Composer + Search
  - 🟡 Medium 3 tickets: Outline + Bookmarks + Bases
  - 🟢 High 2 tickets: Quick Switcher + Word count
  - Total 12 tickets (same magnitude as v0.18 hermes replica 9 tickets)
- 老板 8/19 evening 拍 "no verification needed" = ANAN runs po main flow + commit + push by themselves

## Truth references (Obsidian public resources)

- Official docs: https://obsidian.md/help (web_extract blocked, switch to web_search)
- Core plugins list: https://obsidian.md/help/plugins (15 core, +1 Bases later is 16)
- Canvas file format: https://jsoncanvas.org/spec/1.0 (open MIT)
- JSON Canvas GitHub: https://github.com/obsidianmd/jsoncanvas
- Plugin API TypeScript: https://github.com/obsidianmd/obsidian-api
- Third-party Core 30 plugins tier list: https://practicalpkm.com/obsidian-core-plugins-tier-list/ (30, verified above 16 list)
- Bases syntax: https://obsidian.md/help/bases/syntax (YAML schema fetched)
- Apple HIG truth references:
  - FTS5 full-text search: SQLite builtin
  - PropertyListSerialization / Yams YAML parse
  - SwiftUI Canvas 60 fps TimelineView
  - Spotlight paradigm (⌘O quick switcher)

## MIT reference comparison: SilverBullet (老板 2026-08-19 evening 拍 'we are replica, not copying code, looking at code is for better replica')

老板 拍: "Replica is not copying code, looking at code is for better replica". SilverBullet (MIT pure protocol) is a same-class pure-open-source truth reference to Obsidian, **doesn't replace Obsidian, is complementary reference** — helps us see how "double-link / reverse-link / outliner / extension mechanism" are implemented under MIT protocol.

### SilverBullet truth (per LWN 2025-07-31 review + GitHub README)

- **License**: ✅ MIT pure protocol (LWN 2025-07-31 explicitly "MIT-licensed note-taking application")
- **GitHub**: https://github.com/silverbulletmd/silverbullet
- **Stack**: Deno server + TypeScript frontend + Space Lua extension
- **Storage**: markdown files (.md), same as Obsidian local folder = "Space"
- **Core capabilities**:
  - Page collection (= Obsidian Vault / wenshu Library)
  - Outliner tools (= Obsidian outliner plugin / same dimension as wenshu Book outline)
  - Tasks (= Obsidian Tasks plugin / wenshu writing outline)
  - Query tables / tags / pages (= Obsidian Bases / wenshu Bases replica)
  - Templates
  - Block-based editing
  - Space Lua extension (= Obsidian plugin API / wenshu doesn't need, single-app compiled-in-one)

### Why SilverBullet is a good reference

1. **True MIT** — not MIT + EE dual protocol (AFFiNE), not AGPL viral (AppFlowy dependency). True open-source protocol reveals complete implementation
2. **markdown files** — same as Obsidian local .md files, consistent with wenshu Document truth
3. **Deno + TypeScript** — not Electron closed-source (Obsidian), can see complete server-side code (index / sync / full-text search implementation)
4. **Space Lua extension** — similar to Obsidian plugin API but lighter, see how "extension mechanism" is designed under MIT protocol
5. **PWA + macOS wrapper** — community has MacOS app wrapper (community.silverbullet.md/t/macos-app-really/750), but not SwiftUI native. **wenshu uses Swift/SwiftUI native, doesn't copy wrapper**

### Replica comparison matrix (Obsidian vs SilverBullet vs wenshu replica)

| Capability | Obsidian | SilverBullet | wenshu replica ticket |
|---|---|---|---|
| Local markdown files | ✅ | ✅ | Already implemented `Document` |
| Bidirectional link `[[name]]` | ✅ | ✅ (page ref) | ticket 12 |
| Backlinks reverse link | ✅ | ✅ (page backlinks) | ticket 12 |
| Outliner | ✅ (Outline plugin) | ✅ (Outlining tools) | ticket 21 |
| Templates | ✅ | ✅ (templating plug) | ticket 15 |
| Search full-text | ✅ | ✅ (server-side index) | ticket 17 |
| Database view (Bases) | ✅ (.base YAML) | ✅ (Query tables) | ticket 18 |
| Canvas | ✅ (JSON Canvas 1.0) | ❌ | ticket 13 |
| Graph view | ✅ | ❌ | ticket 14 |
| Note Composer | ✅ | ✅ (rename / merge) | ticket 16 |
| Quick Switcher ⌘O | ✅ | ✅ (page picker) | ticket 19 |
| Word count | ✅ | ✅ (status bar) | ticket 20 |
| Bookmarks | ✅ | ❌ | ticket 22 |
| Extension mechanism | ✅ (Plugin API, public) | ✅ (Space Lua) | ❌ (wenshu single app, not needed) |
| Plugin store / community | ✅ (large ecosystem) | ❌ (niche) | ❌ |
| macOS native | ✅ (Electron) | ❌ (PWA + community wrapper) | ✅ (SwiftUI, wenshu truth) |
| **License** | **Closed-source (Electron closed)** | **MIT pure protocol** | MIT (wenshu own) |

### Key insights (SilverBullet inspiration for wenshu)

1. **markdown index** — SilverBullet server-side uses SQLite to index all .md files' page / heading / block ref. **wenshu replica ticket 17 (Full Text Search) can reference SilverBullet's SQLite FTS5 index structure**, but doesn't copy code
2. **page ref double-link** — SilverBullet uses `[[page name]]` exactly like Obsidian, wenshu uses same syntax directly (bidirectional compatible with Obsidian / SilverBullet)
3. **Space Lua extension** — SilverBullet sinks extension logic to Lua sandbox, not TS code. **wenshu doesn't need extension mechanism** (single-app compiled-in-one), but **template (ticket 15) can borrow Space Lua's "variable + template" design idea**
4. **PWA offline-first** — SilverBullet PWA completely offline after first load. **wenshu desktop app is already offline, no PWA mode needed**, but "local self-management" principle consistent
5. **Community macOS wrapper** — SilverBullet community used WebView to wrap .app, but experience is far from SwiftUI native. **wenshu uses SwiftUI native is true value advantage**, not wrapper

### Truth source

- SilverBullet GitHub: https://github.com/silverbulletmd/silverbullet (MIT)
- SilverBullet official site: https://silverbullet.md/
- LWN review 2025-07-31: https://lwn.net/Articles/1030941/ (MIT truth)
- Apple HIG truth references (same as Obsidian section):
  - SQLite FTS5 builtin
  - SwiftUI Canvas 60 fps TimelineView
  - Spotlight paradigm (⌘O quick switcher)

### Don't touch SilverBullet code

- 老板 拍 "we are replica, not copying code" = look at SilverBullet idea, implement with Swift/SwiftUI yourself, don't copy TS / Deno / Lua
- Don't fork SilverBullet, don't pull request, don't use Space Lua
- SilverBullet is only "same-class under MIT protocol" complementary reference, complementary to Obsidian

## Subsequent tickets (by priority)

See `.scratch/2026-08-19-obsidian-replica/issues/` (subsequent tickets 12-23 total 12 tickets)