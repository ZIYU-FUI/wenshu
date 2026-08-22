# 文枢 product feature requirements list — 老板 2026-08-19 evening 拍

> Date: 2026-08-19 evening
> Perspective: business language (product features 老板 understands, not technical list)
> Truth source:
> 1. hermes replica 14 modules (v0.18 ticket 01-31, commit `047b43cfa`..`c3b8a035e`)
> 2. Obsidian replica 11 modules (v0.19 ticket 12-23, commit `bc4cfd76b`..`a85226c66`)
> 3. wenshu existing framework: 6-zone layout / Book+Bookshelf+Document 3 types / Library / LibraryOutlineView
> 4. wenshu goal: Apple stack long-form fiction novel AI creation platform, macOS-only, self-built lightweight AI kernel

## One, Core narrative — what 文枢 can do

**文枢 = "full-featured workbench" for long-form novel authors, merging hermes's AI capabilities + Obsidian's note-taking capabilities + Apple native macOS experience, all into the novel-writing workflow.**

One-line positioning: "Inside 文枢, you don't need to switch out to open a browser / memos / writing software — everything you need to write a novel is in this one window."

老板 (the novel writer) can do these things in 文枢:
1. Write novels (main battleground: editor + outline + characters + chapters)
2. Manage settings (character relationships / faction maps / timeline / locations)
3. Look up information (web fetch / OCR screenshot / local files / historical material)
4. Collaborate with AI (chat / have AI edit drafts / have AI look up history / dispatch other AI agents)
5. Manage progress (word count / deadlines / chapter kanban / writing calendar)
6. Backup / restore / cross-bookshelf switch

## Two, User journey — 老板's day

| Phase | What 老板 does | Which 文枢 modules help |
|---|---|---|
| 1. Turn on computer in morning | Open 文枢, see where stopped last night + today's word count + deadlines | WordCount (word count) + Todo (today's todo) + MiniMax Agent (chat with AI good morning / reminder) + Bookmarks (last favorites) |
| 2. List today's writing outline | See Outline tree + browse Bases character table | Outline (chapter tree) + Bases (character table) + Graph (character relationship graph) |
| 3. Start writing chapter | Editor main area, while writing insert [[Lin Daiyu]] auto-complete | Wikilink editor rendering + Backlinks (reverse link, see where [[Lin Daiyu]] appeared) + Search (search "Chuangzao ji" etc settings) |
| 4. Stuck | Chat with AI, have AI help continue writing | MiniMax Agent (chat sheet) + Skill (call continue-writing skill) + Multi-Agent (dispatch to editing agent) |
| 5. Look up information | Search materials, fetch web pages, OCR screenshots | Web Fetch (right-click Insert URL) + Vision (right-click OCR image) + File Tools (local file import) |
| 6. Finish one chapter | Run word count + mark complete | WordCount (top-right real-time) + Bases (chapter progress table) + Kanban (chapter kanban) |
| 7. Evening archive | Change chapter name / merge chapters / auto-backup | Note Composer (rename / merge / split, auto rewrite links) + Backup (Toolbar backup button) |
| 8. Writing whiteboard | Draw character relationship graph / plot lines | Canvas (Toolbar Canvas button, popup JSON Canvas view, Obsidian-compatible) |
| 9. Listen to chapter | TTS read aloud to check rhythm | TTS (Toolbar read-aloud button) |
| 10. Scheduled task | Set timed auto-save / auto-backup | Cron (Settings scheduled tasks) |
| 11. Cross-bookshelf | Write another book, switch | Quick Switcher (⌘O popup, cross-bookshelf fuzzy search) |
| 12. Writing history | Look up "what 文枢 has written" | Memory (Toolbar memory button + Popover, replica hermes mem0) |

## Three, Requirements list — by module (business language)

### A. Novel-writing main battleground (P0, must connect)

| # | Business requirement | Module | Source | Connection location |
|---|---|---|---|---|
| A1 | Open 文枢, directly continue from last night | Existing Library + LibraryOutlineView | wenshu existing | Already implemented, don't touch |
| A2 | Editor main area write chapter, as smooth as Pages | Existing BookEditorSheet | wenshu existing | Already implemented, don't touch |
| A3 | Write `[[Lin Daiyu]]` in chapter auto becomes blue underlined link, ⌘+click to jump | InternalLink Parser + Wikilink editor rendering | v0.19 ticket 12 | Editor main area text rendering layer |
| A4 | Top bar right real-time show current chapter word count | WordCount | v0.19 ticket 20 | Top bar right widget |
| A5 | Editor right pane show current chapter reverse links (which other chapters reference it) | BacklinksPanel | v0.19 ticket 12 | Editor right pane panel tab |
| A6 | Editor right pane show current chapter outline (H1-H6 jump) | OutlinePanel | v0.19 ticket 21 | Editor right pane panel tab (coexists with Backlinks) |
| A7 | Editor right pane full-text search chapter content | SearchPanel | v0.19 ticket 17 | Editor right pane panel tab |
| A8 | ⌘O popup, fuzzy search all bookshelf notes / chapters, quick jump | QuickSwitcher | v0.19 ticket 19 | Global shortcut ⌘O (same Apple Spotlight pattern) |

### B. Manage settings (P0-P1, strong requirement)

| # | Business requirement | Module | Source | Connection location |
|---|---|---|---|---|
| B1 | Character table: show all characters (name / age / relationship / appearing chapters) | Bases database view | v0.19 ticket 18 | Upper band new 1 zone / or right pane panel tab |
| B2 | Character relationship graph: nodes = characters, edges = relationships | Graph view | v0.19 ticket 14 | Upper band new 1 zone / or independent tab |
| B3 | Faction / dynasty / magic weapon / location tables | Bases (reuse) | v0.19 ticket 18 | Same as B1 |
| B4 | Writing whiteboard: draw plot lines / relationship graph (Obsidian Canvas compatible) | Canvas + JSON Canvas 1:1 | v0.19 ticket 13 | Toolbar Canvas button / or independent tab |
| B5 | When writing chapter outline, auto-apply template (chapter / short story / note) | Templates | v0.19 ticket 15 | Toolbar "New" button → template selection sheet |
| B6 | Timeline / chapter progress table | Bases (reuse) | v0.19 ticket 18 | Same as B1 |

### C. AI collaboration (P0-P1, strong requirement)

| # | Business requirement | Module | Source | Connection location |
|---|---|---|---|---|
| C1 | Chat with AI, have AI continue writing / edit drafts | MiniMax Agent | v0.18 ticket 03+31 (MiniMaxVerifier) | Toolbar "Agent" button → chat sheet |
| C2 | 老板 can manually invoke 35 skills (continue writing / translate / proofread / style conversion) | Skill UI (replica hermes skills_hub) | v0.18 ticket 02 | Settings → Skills list |
| C3 | Dispatch tasks to other agents (editing agent / proofreading agent / translation agent) | Multi-Agent UI | v0.18 ticket 04 | Settings → Agents list |
| C4 | Look up "what 文枢 has written before" (long-term memory) | Memory UI | v0.18 ticket 01 | Toolbar "Memory" button + Popover |

### D. Information lookup / text processing (P1)

| # | Business requirement | Module | Source | Connection location |
|---|---|---|---|---|
| D1 | Fetch web content into 文枢 (look up info) | Web Fetch | v0.18 ticket 09 | Editor right-click "Insert URL" |
| D2 | OCR screenshot, insert text from image into chapter | Vision | v0.18 ticket 10 | Editor right-click "OCR image" |
| D3 | Import local text files / export chapter as file | File Tools | v0.18 ticket 07 | Editor right-click menu + Toolbar open/save |
| D4 | TTS read current chapter aloud (listen to rhythm) | TTS / AVMedia | v0.18 ticket 11 | Toolbar "Read" button |
| D5 | Run shell scripts inside 文枢 (batch processing) | Process | v0.18 ticket 08 | Toolbar "Run" button + NSTextField input |

### E. Manage progress / time (P1)

| # | Business requirement | Module | Source | Connection location |
|---|---|---|---|---|
| E1 | Chapter kanban: backlog / in-progress / done | Kanban UI | v0.18 ticket 05 | Sidebar "Projects" tab |
| E2 | Today's todo (simple GTD) | Todo UI | v0.18 ticket 06 | Sidebar "Today" tab |
| E3 | Scheduled tasks (auto-save / auto-backup) | Cron UI | v0.18 ticket 21 | Settings "Scheduled tasks" list |

### F. Document management / editing tools (P1-P2)

| # | Business requirement | Module | Source | Connection location |
|---|---|---|---|---|
| F1 | Rename chapter, auto rewrite all `[[old_name]]` → `[[new_name]]` | Note Composer (rename) | v0.19 ticket 16 | File menu → Rename (linked with #5 Backlinks) |
| F2 | Merge two chapters → auto rewrite links | Note Composer (merge) | v0.19 ticket 16 | File menu → Merge |
| F3 | Split one chapter → auto rewrite links | Note Composer (split) | v0.19 ticket 16 | File menu → Split |
| F4 | Favorite important chapters / setting fragments (cross-bookshelf) | Bookmarks UI | v0.19 ticket 22 | Toolbar add button + ⌘⇧B popup + editor right pane tab |

### G. Data security / automation (P2)

| # | Business requirement | Module | Source | Connection location |
|---|---|---|---|---|
| G1 | One-click backup entire project, cross-bookshelf | Backup UI | v0.18 ticket 26 | Toolbar "Backup" button |
| G2 | Scheduled auto-backup | Cron + Backup linkage | v0.18 ticket 21+26 | Settings scheduled tasks |

## Four, Module relationship (module dependency graph)

```
[wenshu existing framework]
  Library / LibraryOutlineView / Book / Bookshelf / Document / FileSystemLibraryStore
     ↑
     │
[Obsidian replica (write novel)]
     │
     ├─ LinkGraph (LinkIndex + InternalLinkParser + BacklinkResolver)
     │   └─ Dependency: existing Document
     │
     ├─ Search (FullTextSearch SQLite FTS5)
     │   └─ Dependency: existing Document content
     │
     ├─ Outline (OutlineExtractor)
     │   └─ Dependency: existing Document content
     │
     ├─ WordCount (WordCounter)
     │   └─ Dependency: existing Document content
     │
     ├─ Canvas / Graph / Bases / Templates / Composer
     │   └─ Dependency: existing Document + LinkIndex (Composer linked with Backlinks)
     │
     ├─ QuickSwitcher (fuzzy search)
     │   └─ Dependency: existing Library (cross-bookshelf)
     │
     └─ Bookmarks (BookmarkStore)
         └─ Dependency: existing Library / Document
     ↑
     │
[hermes replica (AI + tools)]
     │
     ├─ Memory (MemoryStore SQLite, replica hermes mem0)
     │   └─ Independent, related to existing Document (Memory content can come from Document)
     │
     ├─ Skill (SkillRegistry, replica hermes skills_hub)
     │   └─ Independent, invoke through Skill UI
     │
     ├─ Agent (AgentProtocol + AgentRuntime + MiniMaxVerifier)
     │   └─ Dependency: SkillRegistry (agent calls skill) + Memory (agent queries memory)
     │
     ├─ Kanban / Todo (project progress + GTD)
     │   └─ Related to existing Document (chapter = kanban task)
     │
     ├─ File / Process / Web / Vision / AV (tool set)
     │   └─ Independent, connected through editor right-click menu / Toolbar
     │
     └─ Cron / Backup (automation + backup)
         └─ Independent, connected through Settings / Toolbar
```

**Key linkages (do together when connecting):**
1. **LinkGraph linkage**: Wikilink editor rendering + Backlinks panel + `[[wikilink]]` auto-complete — same LinkIndex three connection points
2. **Outline linkage**: 老板's list (sidebar) + my list (right pane) — same OutlineExtractor either-or connection
3. **Composer + Backlinks linkage**: rename triggers auto rewrite → must connect Composer together with Backlinks
4. **Memory + Document linkage**: Memory content extracted from Document, 老板 queries "what's been written"
5. **Agent + Skill linkage**: Agent calls Skill, chat sheet selects skill
6. **Cron + Backup linkage**: scheduled auto-backup

## Five, Priority + connection order (business value sort)

### 🔥 P0 must connect (1-2 weeks, core novel-writing experience)

| # | Business requirement | What 老板 can immediately do after connection |
|---|---|---|
| A3 | Wikilink editor rendering | Write `[[Lin Daiyu]]` in chapter auto link, one click jump |
| A4 | Top bar word count badge | Real-time know how many words written today |
| A5 | Backlinks panel | When writing current chapter see all settings referencing it |
| A6 | Outline panel | Editor right pane see outline, click jump chapter |
| A7 | Search full-text search | ⌘F search "Chuangzao ji" etc setting fragments |
| A8 | Quick Switcher ⌘O | Cross-bookshelf quick jump |
| C1 | MiniMax Agent chat | Chat with AI to continue writing |
| C2 | Skill UI | Manually invoke 35 skills |
| C4 | Memory UI | Query "what 文枢 has written" |

### 🟡 P1 core enhancement (2-3 weeks, make 文枢 more valuable than plain editor)

| # | Business requirement | What 老板 can do after connection |
|---|---|---|
| B1-B6 | Bases / Graph / Canvas / Templates (B series) | Character table / relationship graph / whiteboard / templates, complete writing workflow |
| D1-D5 | Tool set (D series, Web / Vision / File / TTS / Process) | Editor right-click menu / Toolbar one-key lookup |
| E1-E3 | Kanban / Todo / Cron (E series) | Progress management + scheduled tasks |
| F1-F4 | Composer / Bookmarks (F series) | Rename chapter auto rewrite links + favorites |

### 🟢 P2 wrap-up (3-4 weeks, icing on cake)

| # | Business requirement | What 老板 can do after connection |
|---|---|---|
| C3 | Multi-Agent UI | Dispatch tasks to multiple AI agents |
| D5 | Process / TTS | Run scripts + listen to chapters |
| G1-G2 | Backup + Cron linkage | Scheduled auto-backup |

## Six, Final implemented features (after 老板 macOS verifies, what 文枢 can do)

### 老板's novel-writing day (after all connected)

```
07:00  Open 文枢 → see which chapter stopped last night + today's todo + AI reminder (Memory / Todo / MiniMax)
07:10  See outline, browse character table, see character relationship graph (Outline / Bases / Graph)
07:30  Start writing chapter → while writing insert [[Lin Daiyu]] auto jump (Wikilink / Backlinks)
08:00  Stuck → chat with AI continue writing / invoke skill (MiniMax Agent / Skill)
08:30  Look up information → fetch web / OCR screenshot (Web Fetch / Vision)
09:00  Finish one chapter → run word count / mark complete / add to kanban (WordCount / Kanban)
12:00  Lunch break → listen to chapter written last night (TTS)
18:00  Evening writing → draw plot whiteboard (Canvas)
19:00  Change chapter name → auto rewrite all links (Composer + Backlinks linkage)
20:00  Favorite important fragments → ⌘⇧B popup (Bookmarks)
22:00  Archive → one-key backup / scheduled auto-backup (Backup / Cron)
23:00  Cross-bookshelf write another → ⌘O quick jump (Quick Switcher)
```

### 文枢 final capabilities (all 26 business requirements connected)

| Dimension | Capability |
|---|---|
| Writing | Editor main area + real-time word count + reverse links + outline jump + full-text search + wikilink rendering |
| Settings | Character table + relationship graph + faction graph + writing whiteboard (Obsidian Canvas compatible) + templates |
| AI | Chat with AI + invoke 35 skills + dispatch to other agents + query long-term memory |
| Information | Web fetch + OCR screenshot + import local file + read aloud + run scripts |
| Progress | Chapter kanban + today's todo + scheduled tasks |
| Editing | Rename chapter + auto rewrite links + merge + split |
| Security | One-key backup + scheduled auto-backup |

**文枢 = Apple stack long-form novel AI creation platform = everything you need to write a novel is in one window.**

## Seven, Conflict with LayoutTokens dead principles (needs 老板 拍)

| Requirement | Conflict | Alternative |
|---|---|---|
| B1 Bases independent zone | Upper band 4 → 5 zones, conflicts with ticket 14 dead principle | Use panel tabs (editor right pane multiple tabs, Bases shares with Outline/Backlinks/Search) |
| B2 Graph independent zone | Same as Bases | Same |
| B4 Canvas independent zone | Same as Bases | Same |

**Suggestion**: Bases / Graph / Canvas all use panel tabs, don't touch LayoutTokens dead principles.

## Eight, Integration with existing 6-zone layout

```
Top bar (titleBar)
├─ A4 word count badge (right)
├─ A8 Quick Switcher entry (right icon)
├─ C1 Agent entry (right icon)
├─ C2 Skill entry (right icon)
├─ C4 Memory entry (right icon)
├─ D3 File open/save (right)
├─ D4 TTS read aloud (right)
├─ D5 Process run (right)
├─ F4 Bookmark add (right)
└─ G1 Backup (right)

Upper band (4 zones)
├─ Zone 1 (200 PT project sidebar): E1 Kanban / E2 Todo (NavigationSplitView sidebar overlay)
├─ Zone 2 (520 PT project preview): existing
├─ Zone 3 (794 PT editor): A2 existing editor main area + A3 wikilink rendering
│   └─ Editor right pane (panel tabs): A5 Backlinks / A6 Outline / A7 Search / F4 Bookmarks (4 tab switch)
└─ Zone 4 (400 PT tools): existing

Lower band (2 zones)
├─ Zone 1 (1518 PT AI chat): existing + C1 MiniMax Agent chat (integrated)
└─ Zone 2 (400 PT AI dynamic): existing
```

**Don't touch LayoutTokens dead principles (1920×984 PT 1:1 locked)** — all new UI through top bar / toolbar / sidebar / editor right pane panel tabs.

## Nine, Todo (老板 拍)

1. 拍 P0 start work (9 business requirements, 1-2 weeks)
2. 拍 Bases / Graph / Canvas through panel tabs (avoid LayoutTokens dead principles)
3. 拍 Outline through right pane or sidebar (老板 another session's list + my list conflict)
4. 拍 subsequent ticket scheduling: ticket 24 (panel tabs framework) + ticket 25+ (per Phase order)