# Wenshu Library Replica — FCP-style Library Management spec

## Terminology (boss 2026-08-26 final vocabulary)

| Term | English | Meaning | Physical location |
|---|---|---|---|
| **库 (Library)** | `.ws` | The entire repo selected via NSOpenPanel onboarding | `~/Documents/<name>.ws/` directory; single instance, locked to UserDefaults.wenshu.libraryPath |
| **书架 (Bookshelf)** | Bookshelf | Parent container of books; user-named | `<.ws>/shelves/<shelf-uuid>/` (= multiple; user creates / renames / deletes) |
| **书 (Book / Project)** | Book | One novel project; all the records related to this book | `<.ws>/shelves/<shelf-uuid>/books/<book-uuid>/`; carries 8 standard folders + 2 data files (= 10 entries; see §Book structure below) |
| **资料库 (Reference Library)** | ReferenceLibrary | The default bookshelf that ships with the library. User CANNOT delete or rename it. It is a fixed container at the library root. | `<.ws>/reference-library/` (= independent of shelves/, ships with the library) |

**Bookshelf** vs **ReferenceLibrary**: they are sibling types at the library root. `Bookshelf` is user-created (multiple instances), `ReferenceLibrary` is exactly one, system-managed, cannot be deleted. Different types so future "publish/export" logic can branch cleanly.

**Library** is the only "data source switch" boundary: switching books = reloading data scoped to that book. Switching shelves within one library = no data switch (the book owns its data). Switching libraries = different UserDefaults.wenshu.libraryPath (boss 8/26 Q12 = single-shelf permanent, so this is a rare / config-only event).

## Book structure (8 standard folders + 2 data files = 10 entries)

Every book directory contains these standard subdirectories (= wenshu-fixed, NOT user-customizable at the physical layer):

| Folder / file | Chinese UI label | Contents | Storage type |
|---|---|---|---|
| `world/` | 世界观 | World-building .md files | Markdown + JSON sidecar |
| `characters/` | 角色设定 | Character cards .md files | Markdown + JSON sidecar |
| `outlines/` | 章节大纲 | Chapter outline .md files | Markdown + JSON sidecar |
| `chapters/` | 小说正文 | Published chapters .md files (= existing BookCategory.chapter) | Markdown + JSON sidecar |
| `drafts/` | 小说草稿 | Drafts .md files (v0.25.x empty; future home of unfinished work) | Markdown + JSON sidecar |
| `sessions/` | LLM 会话记录 | LLM chat history per chapter (= future; v0.25.x has global chat.sqlite outside book) | Markdown (per-session export) + JSON sidecar |
| `foreshadowing/` | 伏笔 | Foreshadowing tracker .md files | Markdown + JSON sidecar |
| `placeholders/` | 占位符 | Placeholder management .md files | Markdown + JSON sidecar |
| `kanban.json` | 看板 | Structured kanban data per book (= per-book JSON, NOT folder) | Per-book JSON file |
| `todo.json` | todo | Structured todo data per book (= per-book JSON, NOT folder) | Per-book JSON file |

**Why some are folders (md) and some are JSON files (data)**:
- Folders hold **human-readable** content (= markdown text the user writes or reads). User edits via editor sheet.
- JSON files hold **structured data** (= kanban tickets, todo items, foreshadowing graph edges, placeholder substitution tables). User edits via specialized UI.
- Both are per-book and reload on book switch. Future folders / data files can be added by extending `BookManifest` schema (see ticket 026).

**Virtual folders (UI-level, post-v0.27)**: the user-facing UI may eventually let users create "virtual folders" that symlink / alias content across the 8 standard folders (= e.g. "张三的视角" virtual folder = chapters/张三 POV + characters/张三 + foreshadowing/张三相关). The spec does NOT implement virtual folders in v0.26, but the physical structure MUST remain flexible enough to support them later (= each folder has its own metadata sidecar; refs can cross folders).

## Boss 2026-08-26 OOB
Replicate FCP (Final Cut Pro) library management mechanism into wenshu, customized for a writing app:

1. Library (= Shelf = "书架") holds books, world-building, characters, reference library.
2. Book (= FCP Event) is a single long-form writing unit; each book holds chapters + private world + private characters.
3. World-building (= "世界观") and Characters (= "角色") are private to each Book (= per-Book).
4. Reference library (= "资料库") is shared across all books in the library (= Library-level cross-cutting; the ReferenceLibrary is the library's default shelf, sibling to user-created shelves/, per terminology table).
5. Single-shelf model: user has exactly one .ws library; onboarding is a one-time event.
6. Library Properties panel (FCP-style storage locations) is the canonical UX for managing the .ws library.

Constraint: the architectural shape mirrors FCP (Library > Event > Project + cross-cutting tag layer) but the internal layout is wenshu-specific (filesystem JSON + .md, NOT CoreData).

**⚠️ RE-SEQUENCE HARD REQUIREMENT ⚠️**: §11 baseline line 16 currently declares "Stack = ... CoreData ...". This spec's "NOT CoreData" claim contradicts §11 until ticket 024 lands the §11 amendment. Implementation MUST land ticket 024 BEFORE ticket 001 (re-sequence dependency). If ticket 024 is not yet merged, the spec body L13 must be read as forward-looking. CI may enforce this by refusing to merge tickets 001-023 against the unamended §11 baseline. See "Out of scope" and "Ticket 024" for the atomic-coupling justification.

NOTE on CJK in this spec: AGENTS.md §11 standard = "English only" + the Boss OOB / UI label / CONTEXT.md-glossary carve-outs. Chinese characters in this spec fall into 3 explicit categories:
1. **Boss OOB quotations** (= L43-48 Boss 2026-08-26 OOB block + any direct boss quote elsewhere, e.g. "用户体验最完整" L252, "双轴每次都跑" L357/L412, "在书架漏出" L237, "用户不能删除，不能重命名" L243, "切书=切数据源" L368, "最少代码 + Apple 标准" L385, "kanban/todo功能没实装" L384): REQUIRED, preserves boss's verbatim words.
2. **UI label references** (= parenthetical mentions of button labels and Chinese form of cross-reference syntax; concrete CJK-bearing lines verifiable via `grep -nE '[一-龥]' spec.md`, e.g. L74-79 [="@角色.张三" and Chinese type names], L117/L120/L130/L132/L135/L136/L217/L238/L243/L251/L258 [= button labels 库属性 / 在 Finder 中显示 / 移动仓库 / 重置库 / 默认书架 + Chinese cross-ref labels]): REQUIRED, because the Swift source code WILL contain these Chinese strings per Boss 8/25 'UI 全中文' carve-out. Each mention is parenthetical, framed as "Chinese label X", and the parenthesized English description conveys the spec's intent.
3. **FCP mapping table + cross-reference model + Book structure + glossary entries** (= L22-30 Book structure table + L66-79 FCP mapping table + L116-120 cross-reference model + L334 CONTEXT.md glossary additions): REQUIRED, because the project domain entities (Library / Bookshelf / Book / ReferenceLibrary / World / Character / Reference / Smart Query / Library Properties) have Chinese names (= 库 / 书架 / 书 / 资料库 / 世界观 / 角色 / 资料 / 智能查询 / 库属性) per the Boss 2026-08-26 OOB. CONTEXT.md glossary is itself §11-exempt.

Categories 1-3 are exempted by project convention. Any CJK that does NOT fall into 1-3 above = bug. For live verification, run `grep -nE '[一-龥]' .scratch/2026-08-26-fcp-library-replica/spec.md` and check each line against the 3 categories above (= if the line carries CJK and is NOT in the Boss OOB block / NOT a parenthetical UI label / NOT a Book-structure / FCP-mapping / glossary row, it is a violation).

## Design (= FCP mapping + wenshu customization)

### FCP concept → wenshu mapping (final, v4)
| FCP concept | FCP on-disk | wenshu mapping | wenshu on-disk |
|---|---|---|---|
| Library | `.fcpbundle/` | **Library** (= 库, single instance per user; = boss 8/26 Q12 single-shelf model) | `.ws/` (already shipped in v0.24 ticket 015.005) |
| Event | `Events/<date>.fcpevent/` | **Bookshelf** (= 书架; user-named parent of books) | `.ws/shelves/<shelf-uuid>/{shelf.json, books/}` |
| Project (= timeline) | inside Event SQLite | **Book** (= 书 / 项目; one novel project) | `.ws/shelves/<shelf>/books/<book-uuid>/{book.json, 8 standard folders, 8 JSON sidecars, kanban.json, todo.json}` |
| Project clip (= timeline entry) | inside Event SQLite | **Chapter** (= 章节, NOT a domain entity; stays as `.md` files) | `.ws/shelves/<shelf>/books/<book-uuid>/chapters/*.md` |
| Role (metadata on clip) | Event SQLite attribute | **Character** (= 角色, Book-private; one of 8 Book-private folders) | `.ws/.../books/<book-uuid>/characters/{characters.json, *.md}` |
| Event metadata | Event SQLite attribute | **World** (= 世界观, Book-private; one of 8 Book-private folders) | `.ws/.../books/<book-uuid>/world/{world.json, *.md}` |
| Foreshadowing | not in FCP | **Foreshadowing** (= 伏笔, Book-private; new concept for wenshu) | `.ws/.../books/<book-uuid>/foreshadowing/{foreshadowing.json, *.md}` |
| Placeholder | not in FCP | **Placeholder** (= 占位符, Book-private; new concept for wenshu) | `.ws/.../books/<book-uuid>/placeholders/{placeholders.json, *.md}` |
| Kanban | not in FCP | **Kanban** (= 看板, per-Book JSON; new for v0.26) | `.ws/.../books/<book-uuid>/kanban.json` |
| Todo | not in FCP | **Todo** (= todo, per-Book JSON; new for v0.26) | `.ws/.../books/<book-uuid>/todo.json` |
| Library Keyword Collection | Library SQLite | **Reference** (= 资料库; = the library's default ReferenceLibrary; LLM Wiki 4-layer) | `.ws/reference-library/{raw/, entities/, abstracts/, indexes/}` |
| Library Smart Collection | Library SQLite | **Smart query** (= saved search; v0.27+; deferred) | `.ws/reference-library/indexes/saved-searches/*.json` (= future) |
| Library Properties (UI) | Inspector Ctrl-Cmd-J | **Library Properties panel** | Settings menu (per boss Q1=c) |
| Bookshelf sub-events | not in FCP | **Outlines / Drafts / Sessions** (= 章节大纲 / 草稿 / LLM 会话记录; Book-private folders for workflow stages) | `.ws/.../books/<book-uuid>/{outlines/, drafts/, sessions/}/` |

### .ws internal layout (FINAL — boss 2026-08-26 decision, three-layer FCP mirror + ReferenceLibrary sibling)
```
<warehouse>.ws/                                  <- user-selected via NSOpenPanel onboarding (single instance, locked to UserDefaults)
|-- Info.plist                                   <- Library metadata (Apple HIG bundle pattern; CFBundlePackageType=WSPC + WSSchemaVersion); already shipped by LibraryRootView.swift:296-309
|-- chat.sqlite                                  <- Active chat history (45 KB at v0.24 ship; PRESERVED in place, no migration)
|-- Icon\r                                       <- macOS Finder icon metadata (already shipped)
|-- shelves/                                     <- Bookshelf collection (= FCP Events container; user creates/renames/deletes via Settings)
|   `-- <shelf-uuid>/                            <- per-Shelf directory
|       |-- shelf.json                           <- Shelf metadata (id, name, createdAt, updatedAt)
|       `-- books/                               <- Books within this shelf
|           `-- <book-uuid>/                     <- per-Book directory (see §Book structure above)
|               |-- book.json                    <- Book metadata
|               |-- world/  characters/  outlines/  chapters/  drafts/  sessions/  foreshadowing/  placeholders/   <- 8 standard folders (md)
|               |   `-- <doc-uuid>.md            <- file body
|               |-- world.json  characters.json  outlines.json  chapters.json  drafts.json  sessions.json  foreshadowing.json  placeholders.json   <- 8 JSON sidecars (per-folder index)
|               |-- kanban.json                  <- per-Book structured kanban data (= ticket 026)
|               `-- todo.json                    <- per-Book structured todo data (= ticket 026)
|-- reference-library/                            <- ReferenceLibrary (= system-managed default shelf; user CANNOT delete or rename)
|   |-- library.json                             <- ReferenceLibrary metadata (id, schemaVersion, createdAt)
|   |-- raw/                                     <- LLM Wiki raw layer (= user-imported source materials; .md)
|   |-- entities/                                <- LLM Wiki entities layer (= USER-FACING; .md cards in second column)
|   |-- abstracts/                               <- LLM Wiki abstractions layer (= LLM-derived; HIDDEN from user; .md)
|   `-- indexes/                                 <- LLM Wiki indexes layer (= LLM-derived; HIDDEN from user; .md)
`-- cache/                                       <- thumbnails, search index, export temp
```

Layout decisions:
- `Info.plist` is kept (not renamed to `info.json`). Apple HIG bundle pattern requires it; LibraryRootView.swift:296-309 already writes it with CFBundlePackageType=WSPC. Schema version goes inside Info.plist as a custom key `WSSchemaVersion`. This matches Standards SUGGEST-5 from v1.
- `chat.sqlite` is kept at .ws root and NOT merged into any per-book database. The v0.21+ chat module already owns this file; chat history is currently global (= shared across all books in the library). v0.27+ may migrate chat per-book per ticket 026 follow-up.
- Empty `assets/` + `backups/` directories from v0.24 are preserved. They were created by the v0.24 onboarding flow and may hold future user data; dropping them silently would break any user who started using them.
- The empty `chapters/` + `books/` + `shelves/` directories at .ws root (created by an early onboarding iteration but never used) are removed by LibraryBootstrapper on first launch after this spec lands. All three are v0.25.x empty orphans; v0.26 introduces a real `shelves/` (= canonical book container = `shelves/<shelf-uuid>/books/<book-uuid>/`) which the bootstrapper CREATES (= not deleted).
- `shelves/` (with subdirs containing shelf.json + books/) is the canonical book container. Existing code at `Sources/WenshuApp/Domain/Bookshelf.swift` uses `shelves/<id>/books/<id>/book.json` layout — kept consistent.
- `reference-library/` is **independent** of `shelves/` (= not nested under any bookshelf). The ReferenceLibrary is the library's default shelf, a sibling to user-created `shelves/`. The LLM Wiki 4-layer substructure (`raw/`, `entities/`, `abstracts/`, `indexes/`) is laid out per Karpathy LLM Wiki pattern; v0.26 ships the static skeleton, v0.27+ implements LLM-driven entity extraction from chat.

### Cross-reference model (boss decision: Q2 = a)
- References in markdown bodies use `@` syntax: `<type>.<name>` where type = `character` / `world` / `reference` (= the three Boss OOB Chinese type names: 角色 / 世界观 / 资料库)
- Markdown body example (Chinese labels per OOB item 10): the writer types `@character.zhangsan` (= Chinese UI form: `@角色.张三`); the parser normalizes at load time
- Parsed at load time into Document.refIds (= [UUID])
- Supports 3 reference types: character (Book-private), world (Book-private), reference (Library-shared, via ReferenceLibrary entities)
- refIds stored in Document metadata (NOT just in markdown), enables query "all chapters mentioning entity X" where X = a character name like `zhangsan` (= Chinese UI form: 张三)

### Single-shelf model (boss decision: Q2 = single-shelf)
- User has exactly one .ws library
- Onboarding is one-time: first launch shows LibraryOnboardingView (already shipped); user picks a directory; UserDefaults.wenshu.libraryPath is set
- On subsequent launches: skip onboarding, load the locked .ws
- No "recent libraries" list, no "switch library" UI
- If user wants a different library, they clear UserDefaults + re-onboard (= a documented escape hatch)

- Library Properties panel (boss decision: Q1 = c)
- Settings menu item: "Library Properties..." (= Chinese menu label: 库属性, FCP-style)
- Opens a modal sheet containing:
  - Current .ws path (= readonly display + "Reveal in Finder" button; Chinese label 在 Finder 中显示)
  - Disk usage (= recursive size of .ws)
  - Schema version (= from Info.plist)
  - "Move Warehouse..." button (= Chinese label 移动仓库; opens NSOpenPanel, uses FileManager.moveItem, atomic update of UserDefaults.wenshu.libraryPath, rollback on failure)
  - "Reset Library" button (= Chinese label 重置库; reset UserDefaults + return to onboarding; does NOT delete the .ws folder)
- Note: there is NO zip export button. Boss vetoed per OOB item 8 and Q13; user moves the .ws directory via Finder if they want it elsewhere.

## Tickets (= 1 zone 1 ticket 1 commit per boss 8/22 protocol; 1 file per commit unless atomic coupling)

### Ticket 001 — Schema layer for World entity (= 1 file)
- File: `Sources/WenshuApp/Domain/World.swift` (new)
- Define:
  ```swift
  struct WorldEntry: Identifiable, Codable, Hashable {
      let id: UUID
      var name: String
      var type: WorldEntryType  // .geography | .lore | .event | .object | .other
      var summary: String       // auto-extracted from .md body
      var refIds: [UUID]        // references to other entities
      let createdAt: Date
      var updatedAt: Date
  }
  enum WorldEntryType: String, Codable, CaseIterable {
      case geography, lore, event, object, other
      var displayName: String { ... }  // Chinese displayNames
      var sfSymbol: String { ... }
  }
  ```
- Per boss: file written English-only; Chinese displayNames live in `displayName` getter (matches BookLength pattern).

### Ticket 002 — Schema layer for Character entity (= 1 file)
- File: `Sources/WenshuApp/Domain/Character.swift` (new)
- Define:
  ```swift
  struct Character: Identifiable, Codable, Hashable {
      let id: UUID
      var name: String
      var age: Int?
      var arc: String?           // narrative arc summary
      var role: CharacterRole    // .protagonist | .antagonist | .supporting | .narrator | .other
      var summary: String        // auto-extracted from .md body
      var refIds: [UUID]         // references to world entries + other characters + references
      let createdAt: Date
      var updatedAt: Date
  }
  enum CharacterRole: String, Codable, CaseIterable {
      case protagonist, antagonist, supporting, narrator, other
      var displayName: String { ... }
      var colorHex: String { ... }  // FCP Role-style color coding
  }
  ```

### Ticket 003 — Schema layer for Reference entity (= 1 file)
- File: `Sources/WenshuApp/Domain/Reference.swift` (new)
- Define:
  ```swift
  struct Reference: Identifiable, Codable, Hashable {
      let id: UUID
      var title: String
      var source: String?        // e.g. a bibliography entry like "Smith 2020" or a Chinese book title (the comment in this struct documents English-only per AGENTS.md §11; the actual Chinese title goes in the .md body, not the comment)
      var url: String?           // optional URL
      var summary: String        // auto-extracted from .md body
      var refIds: [UUID]         // references to other entities
      let createdAt: Date
      var updatedAt: Date
  }
  ```

### Ticket 004 — Storage layer for World (= 1 file)
- File: `Sources/WenshuApp/Storage/FileSystemWorldStore.swift` (new)
- Protocol `WorldStoring` (per LibraryStoring pattern): loadWorld(bookId) / saveWorld / deleteWorld / loadEntry / saveEntry / deleteEntry
- Implementation: filesystem JSON + .md, atomic writes via tmp + replaceItemAt (= FileSystemLibraryStore canonical pattern)

### Ticket 005 — Storage layer for Character (= 1 file)
- File: `Sources/WenshuApp/Storage/FileSystemCharacterStore.swift` (new)
- Protocol `CharacterStoring` (same pattern)

### Ticket 006 — Storage layer for Reference (= 1 file)
- File: `Sources/WenshuApp/Storage/FileSystemReferenceStore.swift` (new)
- Protocol `ReferenceStoring`

### Ticket 007 — Document.refIds field + @-parser (= 1 file)
- File: `Sources/WenshuApp/Domain/Document.swift` (modify)
- Add `var charRefIds: [UUID]`, `var worldRefIds: [UUID]`, `var refIds: [UUID]` (= references to library-shared Reference entities in the ReferenceLibrary)
- Add helper enum `DocumentRefKind { case character, world, reference }`
- Update `loadDocument` to parse `@<type>.<name>` from .md body (where type = `character` / `world` / `reference`, the English counterparts of the Chinese UI labels 角色 / 世界观 / 资料库) and resolve to UUIDs by lookup in character/world/reference indexes (= resolves at load time, cached)

### Ticket 008 — World view (sidebar) (= 1 file)
- File: `Sources/WenshuApp/Views/Library/WorldOutlineView.swift` (new)
- SwiftUI list of WorldEntry cards within a Book; FCP Browser style collapsible
- Click → opens world entry editor sheet
- Toolbar `+` for new entry

### Ticket 009 — World entry editor sheet (= 1 file)
- File: `Sources/WenshuApp/Views/Library/WorldEntryEditorSheet.swift` (new)

### Ticket 010 — Character view (sidebar) (= 1 file)
- File: `Sources/WenshuApp/Views/Library/CharacterOutlineView.swift` (new)

### Ticket 011 — Character editor sheet (= 1 file)
- File: `Sources/WenshuApp/Views/Library/CharacterEditorSheet.swift` (new)

### Ticket 012 — ReferenceLibrary view (= 1 file)
- File: `Sources/WenshuApp/Views/Library/ReferenceLibraryOutlineView.swift` (new)
- Sidebar entry at the library root (= sibling to user-created `shelves/`); shown as a special non-deletable, non-renamable leaf node
- When selected (= = boss 8/26 Q3 "在书架漏出，与所有用户建的书评级"): second column renders the 4-layer LLM Wiki structure:
  - `raw/` — user-imported source materials (.md); grid view like无边记 2-col cards
  - `entities/` — USER-FACING; the only layer visible by default
  - `abstracts/` + `indexes/` — HIDDEN from user; LLM-derived (v0.27+)
- Layer navigation: top of column shows 4 tabs (= the 4 layers). v0.26 ships only the `raw/` + `entities/` tabs functional (= empty placeholder UI for abstracts + indexes); v0.27+ implements LLM-driven extraction
- Icon: 📚 books.vertical.fill (= existing research icon)
- Cannot be deleted or renamed (= boss 8/26 OOB: "用户不能删除，不能重命名，就是一个固定的书架")

### Ticket 013 — Reference entity editor sheet (= 1 file)
- File: `Sources/WenshuApp/Views/Library/ReferenceEditorSheet.swift` (new)
- For editing entities in the ReferenceLibrary `entities/` folder (= LLM Wiki entity layer; the user-facing layer)

### Ticket 014 — Library Properties panel (= 1 file, per boss 8/22 protocol)
- File: `Sources/WenshuApp/Views/Settings/LibraryPropertiesView.swift` (new)
- Modal sheet with: path display + Finder reveal + disk usage + schema version + Move Warehouse button + Reset Library button (= Chinese button labels per Boss 8/25 'UI 全中文' carve-out: 移动仓库 / 重置库)
- Hooked into Settings menu (= per boss Q1=c, boss's words: "用户体验最完整" = "the user experience must be most complete")

### Ticket 015 — Onboarding single-shelf enforcement (= 1 file)
- File: `Sources/WenshuApp/Views/Onboarding/LibraryRootView.swift` (modify)
- Confirm logic: if `UserDefaults.wenshu.libraryPath` is set AND the directory exists AND `Info.plist` is readable (with WSSchemaVersion = current), skip onboarding entirely
- No "switch library" button in Settings (= per boss Q2 = single-shelf)
- Escape hatch: Settings → Library Properties → Reset Library button (= Chinese label 重置库) → clears UserDefaults → returns to onboarding on next launch

### Ticket 016 — Smart query schema + storage (= 1 file)
- File: `Sources/WenshuApp/Domain/SmartQuery.swift` (new)
- `struct SmartQuery { let id: UUID; var name: String; var queryJSON: String; let createdAt: Date }`
- Storage: `.ws/reference-library/indexes/saved-searches/<query-uuid>.json`

### Ticket 017 — Smart query UI (= 1 file)
- File: `Sources/WenshuApp/Views/Library/SmartQueryView.swift` (new)

### Ticket 018 — Info.plist WSSchemaVersion reading (= 1 file)
- File: `Sources/WenshuApp/Storage/LibraryInfo.swift` (new)
- Read `WSSchemaVersion` from `Info.plist` at .ws root (NOT a separate info.json file)
- Implementation:
  ```swift
  struct LibraryInfo {
      let schemaVersion: Int
      let createdAt: Date?
      static func read(from wsRoot: URL) throws -> LibraryInfo { ... }
  }
  ```
- Reads `Info.plist` via `Bundle(url: wsRoot.appendingPathComponent("Info.plist"))`; if bundle is nil (rare: user moved .ws without Info.plist), throw `LibraryInfoError.missingInfoPlist`.
- Compares `schemaVersion` against the constant `CURRENT_SCHEMA_VERSION = 1` (= this spec's version). On mismatch, prompt: "This .ws uses schema v<N>, wenshu expects v<CURRENT_SCHEMA_VERSION>. Migrate now?" (= MIGRATE = run LibraryMigrator ticket 022).
- NOTE: replaces the original ticket 018's `info.json` approach. Rationale: matches Apple HIG bundle pattern + reuses existing `LibraryRootView.swift:296-309` Info.plist writer. This resolves Standards F3 (Info.plist rename risk) and adopts Standards SUGGEST-5.

### Ticket 019 — BookStore singleton + SwiftUI environment injection (= 1 file)
- File: `Sources/WenshuApp/App.swift` (modify)
- Replace v3's "load 4 stores at launch" with: **single `BookStore` (@Observable) instance, observed for `selectedBookId` changes**
- BookStore holds:
  - `var shelves: [Bookshelf]` (= loaded once at app launch, edits in-memory, save on change)
  - `var selectedBookId: UUID?` (= drives which book data to load)
  - `var currentBook: BookBundle?` (= per-book data: book metadata + 8 folder indexes + kanban/todo JSON; auto-reloads when selectedBookId changes via SwiftUI `onChange(of:)`)
  - `var referenceLibrary: ReferenceLibrary` (= library-level data, NOT per-book; loaded once)
- Inject via SwiftUI `@Environment(BookStore.self)` (= Apple standard @Observation pattern)
- Switching books triggers `BookStore.reload(bookId:)` which reads `books/<book-id>/book.json + 8 JSON sidecars + kanban.json + todo.json` into in-memory state; previous book's state is dropped (= Apple standard "data source switch" pattern)
- NOTE: NOT a separate Store instance per book (= would require manual lifecycle management; Apple standard = single store, observation-driven reload)

### Ticket 020 — Cache directory + thumbnail generation (= 1 file)
- File: `Sources/WenshuApp/Storage/CacheManager.swift` (new)
- Manages `.ws/cache/`: thumbnails for chapter covers, search index for full-text, export temp

### Ticket 021 — .ws self-heal at launch (= 1 file)
- File: `Sources/WenshuApp/Storage/LibraryBootstrapper.swift` (new)
- On first launch with a new .ws (= missing `shelves/`, `reference-library/`, `cache/`): create them
- On missing `Info.plist`: create with defaults (defensive — LibraryRootView normally creates it at onboarding, but if a user dragged a folder in without Info.plist, this recovers)
- Remove the empty `chapters/` + `books/` directories at .ws root IF they exist and are empty (= orphan from early onboarding iteration; safe to remove since FileSystemLibraryStore never wrote to them). NOTE: do NOT touch `shelves/` at .ws root here — see ticket 022 for that cleanup.
- For each book discovered under `shelves/<shelf>/books/<book-id>/`, verify all 8 standard folders + 2 data files exist; create missing ones (= defensive for books created before v0.26 or by external tools)
- Never deletes user data (chapters/*.md, settings/*.md, characters/, world/, references/, chat.sqlite, attachments)

### Ticket 022 — Migration shim: existing anbaiqiang.ws → v0.26 layout (= 1 file)
- File: `Sources/WenshuApp/Storage/LibraryMigrator.swift` (new)
- Detects v0.x .ws (= has `books/` at .ws root, OR no `WSSchemaVersion` key in Info.plist) and migrates to v0.26 layout
- Migration path:
  - PRESERVE: `Info.plist`, `chat.sqlite`, `Icon\r`, `assets/`, `backups/`, `books/` (= legacy books/ at .ws root, move to shelves/)
  - **Note on `books/` at .ws root**: PRE-v0.26 had `books/<id>/` directly at .ws root (= no shelves/ parent). Migrator moves each `books/<id>/` into a default shelf `shelves/<auto-generated-shelf-id>/books/<id>/`. The auto-generated shelf is named "Default Shelf" (= Chinese label 默认书架, fallback if user hasn't created any shelf yet).
  - DROP (only if empty): `chapters/` at .ws root, `books/` at .ws root, `shelves/` at .ws root (all three are orphans from early onboarding iteration; safe to remove since FileSystemLibraryStore never wrote to them). NOTE: `shelves/` at .ws root in v0.25.x was an empty placeholder dir; v0.26 introduces a real `shelves/` (= canonical book container) which the migrator creates below.
  - CREATE: `reference-library/{raw, entities, abstracts, indexes}/`, `cache/`
  - WRITE: `WSSchemaVersion = 1` to existing `Info.plist` (via mutable Info.plist read + write)
  - For each migrated book: create the 8 standard folders + 2 JSON data files IF they do not exist (= defensive; user might have books with old `chapters/` and `settings/` only)
- Runs once; sets `WSSchemaVersion = 1` to mark complete
- **CRITICAL**: does NOT touch `chat.sqlite` (active chat history, 45 KB at v0.24 ship). Does NOT touch `Info.plist` if `WSSchemaVersion` key already exists (= idempotent). Does NOT touch user `.md` content under migrated books
- After migrator runs, ticket 021 bootstrapper handles subsequent launches

### Ticket 023 — Tests for new stores (= 3 files, atomic-coupling justified)
- Files: `Tests/WenshuAppTests/Storage/WorldStoringContractTests.swift` + `CharacterStoringContractTests.swift` + `ReferenceStoringContractTests.swift` (= 3 NEW files)
- **Atomic-coupling justification**: All 3 contract test files import the corresponding `*Storing` protocol from tickets 004/005/006. They MUST land in the same commit because:
  1. The 3 Storing protocols are added in tickets 004/005/006 (the implementation files are added in their respective single-file tickets).
  2. But the project's CI runs `swift test` against the whole package. If only `WorldStoring` lands without its contract test, `swift test` still passes — but the protocol is not actually verified.
  3. Therefore ticket 023 is a single "verification commit" for tickets 004+005+006, not three independent commits.
- Alternative considered: 3 separate ticket 023a/023b/023c. Rejected because each one would test only one of three newly-added protocols in isolation, which matches the per-ticket philosophy but loses the parallel-release property (= if 023a lands but 023b/023c are delayed, the user has 1 verified protocol and 2 unverified ones, which is the same risk we're avoiding).
- Each file is 1 test file (per boss 8/22 rule that test files count as 1 file). The commit as a whole = 3 files because 3 protocols are tested in 1 commit.
- Mirror existing `LibraryStoringContractTests.swift` pattern

### Ticket 024 — AGENTS.md §11 update + CONTEXT.md glossary (= 2 files, atomic-coupling justified)
- **Atomic-coupling justification**: AGENTS.md §11 baseline defines the project architecture; CONTEXT.md glossary defines the project domain vocabulary. The new entities (World, Character, Reference, SmartQuery, Shelf, Bookshelf→Shelf rename) need BOTH:
  1. AGENTS.md §11 amendment: replace aspirational CoreData + .ws single file wording with the new .ws internal layout spec (= Standards F4 remediation)
  2. CONTEXT.md glossary additions: 书架 / 书 / 世界观 / 角色 / 资料库 / 库属性 / 智能查询 (= boss 2026-08-26 OOB domain entities)
  - If only AGENTS.md lands: spec body L13's "NOT CoreData" claim is now backed by §11, but CONTEXT.md readers see the new entities without glossary entries = mystery.
  - If only CONTEXT.md lands: glossary entries exist, but AGENTS.md still claims CoreData = contradiction.
- Therefore the commit must contain both files or the spec is internally inconsistent. The boss 8/22 rule's "1 file unless atomic coupling" exception applies here.
- 2 modified files (NOT 2 new files): no rename required, no new module, no new module dependency. The diff in each file is small (AGENTS.md: ~10 lines, CONTEXT.md: ~7 glossary lines).

### Ticket 024b — Bookshelf → Shelf rename (= SKIPPED, option option-c chosen)
- **Status**: SKIPPED per boss 2026-08-26 OOB decision ("按推荐" = boss picked option (c) at the end of the 拷问 session, "全推荐 + 直接干").
- **Rationale (option (c) chosen)**: boss decided NOT to rename the `Bookshelf` Swift type to `Shelf`. The spec canonically uses "Shelf" (= 书架) as the product name, but the existing wenshu codebase type name `Bookshelf` stays. The terminology gap (Shelf = product name, Bookshelf = existing type name) is purely documentation and accepted as-is. Renaming can be done in a future mega-commit with proper boss拍. No implementation work in v0.26.
- **Future rename ticket (deferred to v0.27+)**: if boss拍 a future rename, the rename would touch 12 files with 104 references. Recommendation at that time = single mega-commit with strong atomic-coupling justification (Boss 8/22 exception). Per Apple HIG, type names are user-facing = rename is a UI rename too (= every call site + every comment).

### Ticket 025 — Dual-axis code-review batch (= per boss 8/25 protocol)
- **No code change.** Produces 2 review report files: `.scratch/2026-08-26-fcp-library-replica/standards-axis-report.md` + `spec-axis-report.md`
- **Atomic-coupling justification**: the 2 reports must land in the same commit (= batch review) per boss 8/25 standing instruction: "双轴每次都跑". A single-axis report is non-compliant with the boss protocol.
- 2 files but 0 source code files modified. This ticket is meta (= review artifact, not feature code).

### Ticket 026 — Per-book JSON store for Kanban + Todo + structured data (= 1 file per data type, 2 files)
- **Background** (boss 8/26 OOB clarification): "切换书 = 切换数据源". Every book has its own kanban.json + todo.json (= per-Book JSON, NOT folders). Existing v0.25.x KanbanStore.swift + TodoStore.swift use app-level SQLite; they need to be rewritten as per-book JSON readers/writers.
- **Files** (2 NEW files):
  - `Sources/WenshuApp/Storage/BookKanbanStore.swift` (new)
  - `Sources/WenshuApp/Storage/BookTodoStore.swift` (new)
- **Each store API**:
  ```swift
  protocol BookDataStoring {
      associatedtype Data: Codable
      var bookId: UUID { get }
      var data: Data { get set }
      func load() throws
      func save() throws
  }
  ```
- **Storage**: `books/<book-id>/kanban.json` (= array of `KanbanTicket` per existing `KanbanStore.swift` model) + `books/<book-id>/todo.json` (= array of `TodoItem` per existing `TodoStore.swift` model).
- **Implementation note**: reuse the existing `KanbanTicket` + `TodoItem` Codable structs from v0.25.x; only the load/save plumbing changes from SQLite to JSON.
- **Migration** (= part of ticket 022): existing app-level `kanban.db` is NOT migrated (= boss 8/26 clarification: kanban/todo功能没实装，没有现成数据要迁移). v0.26 starts with empty per-book JSON files.
- **Why not per-book SQLite**: kanban + todo are small structured data with simple schemas. JSON + `Codable` is Apple-standard, requires zero schema migration, and the boss 8/26 ask was "最少代码 + Apple 标准". SQLite adds schema management burden without proportional benefit at this scale.
- **When to upgrade to SQLite**: if per-book structured data grows beyond ~1000 records or needs cross-record transactions (= foreshadowing graph edges, placeholder substitution tables) — defer to v0.27+ redesign.
- **Boss 8/22 atomic-coupling justification**: the 2 stores are independent (= kanban and todo are different data types with different UI surfaces). They DO land in the same commit because both are part of the "data source switch" feature; split commits would leave BookStore with partial per-book data wiring.

## Files to modify (= ~28 new files + ~4 modified)
- New Domain/: World.swift, Character.swift, Reference.swift, SmartQuery.swift, LibraryInfo.swift
- New Storage/: FileSystemWorldStore.swift, FileSystemCharacterStore.swift, FileSystemReferenceStore.swift, CacheManager.swift, LibraryBootstrapper.swift, LibraryMigrator.swift
- New Views/Library/: WorldOutlineView.swift, WorldEntryEditorSheet.swift, CharacterOutlineView.swift, CharacterEditorSheet.swift, ReferenceLibraryOutlineView.swift, ReferenceEditorSheet.swift, SmartQueryView.swift
- New Views/Settings/: LibraryPropertiesView.swift
- New Tests/Storage/: 3 contract test files
- Modify: Document.swift (add refIds + @-parser), LibraryRootView.swift (single-shelf enforcement), App.swift (store injection), AGENTS.md (§11 spec update), CONTEXT.md (glossary)

## Out of scope (= explicitly deferred per boss 2026-08-26 decisions)
- Multi-shelf model (= boss Q2 = single-shelf)
- CoreData migration (= boss: keep filesystem JSON + .md)
- Chapter as independent domain entity (= boss Q3 = a: stay as .md files in chapters/)
- Library export to zip (= boss vetoed: user moves via Finder)
- Smart query auto-suggest (= basic UI only; no ML)

## Verification (= per boss 8/22 protocol)
1. swift build: clean (= 0 errors, 0 warnings except existing ones)
2. swift test: all tests pass (= existing 584 + new ~120 = ~700)
3. Manual: create new .ws via onboarding → verify directory layout matches spec
4. Manual: migrate existing anbaiqiang.ws → verify books/ preserved, WSSchemaVersion=1 written to Info.plist, chat.sqlite untouched
5. Manual: open Library Properties → verify all fields populate + Move Warehouse + Reset Library buttons work (= Chinese labels 移动仓库 / 重置库)
6. Manual: create world entry + character in Book A → verify they appear in Book A only (NOT Book B)
7. Manual: create a reference in `reference-library/raw/` → verify it appears in the ReferenceLibrary `entities/` layer (= user-facing); abstracts + indexes layers are HIDDEN in v0.26
8. Dual-axis code-review PASS (= boss 8/25 protocol, boss's words: "双轴每次都跑" = "dual-axis review every time"; 1 standards FAIL = blocking; 1 spec FAIL = blocking)
