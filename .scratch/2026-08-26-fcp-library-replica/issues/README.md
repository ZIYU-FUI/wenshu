# Issues (= per-ticket spec files, one per ticket)

Each ticket gets its own issue file at `issues/<ticket-id>.md` containing:
- Boss spec citation (= from spec.md Boss OOB block)
- 1-file scope (= per boss 8/22 protocol)
- Acceptance criteria (= checklist)
- Verification steps (= swift build + swift test + manual)

## Tickets (= 26 tickets, 1 zone 1 ticket 1 commit)

| ID | Title | File | New/Modify |
|---|---|---|---|
| 001 | Schema layer for World entity | Domain/World.swift | New |
| 002 | Schema layer for Character entity | Domain/Character.swift | New |
| 003 | Schema layer for Reference entity | Domain/Reference.swift | New |
| 004 | Storage layer for World | Storage/FileSystemWorldStore.swift | New |
| 005 | Storage layer for Character | Storage/FileSystemCharacterStore.swift | New |
| 006 | Storage layer for Reference (= ReferenceLibrary, 4 LLM Wiki layers) | Storage/FileSystemReferenceStore.swift | New |
| 007 | Document.refIds field + @-parser | Domain/Document.swift | Modify |
| 008 | World view (= one of 8 Book-private folders; sidebar under book node) | Views/Library/WorldOutlineView.swift | New |
| 009 | World entry editor sheet | Views/Library/WorldEntryEditorSheet.swift | New |
| 010 | Character view (= one of 8 Book-private folders) | Views/Library/CharacterOutlineView.swift | New |
| 011 | Character editor sheet | Views/Library/CharacterEditorSheet.swift | New |
| 012 | ReferenceLibrary view (= sidebar sibling to shelves/, non-deletable) | Views/Library/ReferenceLibraryOutlineView.swift | New |
| 013 | Reference entity editor sheet (= edits LLM Wiki `entities/` layer) | Views/Library/ReferenceEditorSheet.swift | New |
| 014 | Library Properties panel | Views/Settings/LibraryPropertiesView.swift | New |
| 015 | Onboarding single-shelf enforcement | Views/Onboarding/LibraryRootView.swift | Modify |
| 016 | Smart query schema + storage (= v0.27+ deferred) | Domain/SmartQuery.swift | New (= placeholder) |
| 017 | Smart query UI (= v0.27+ deferred) | Views/Library/SmartQueryView.swift | New (= placeholder) |
| 018 | Info.plist WSSchemaVersion reading | Storage/LibraryInfo.swift | New |
| 019 | BookStore singleton + SwiftUI environment injection (= Apple standard @Observable) | App.swift | Modify |
| 020 | Cache directory + thumbnail generation | Storage/CacheManager.swift | New |
| 021 | .ws self-heal at launch (= creates 10 Book subdirs + 2 data files per book) | Storage/LibraryBootstrapper.swift | New |
| 022 | Migration shim: existing anbaiqiang.ws → v0.26 layout (= moves books/ → shelves/<default>/books/) | Storage/LibraryMigrator.swift | New |
| 023 | Tests for new stores (3 files) | Tests/Storage/*StoringContractTests.swift | New |
| 024 | AGENTS.md §11 update + CONTEXT.md glossary | AGENTS.md, CONTEXT.md | Modify |
| 024b | Bookshelf → Shelf rename (= 3 options; boss-decision required) | Sources/ + Tests/ (= up to 12 files) | Modify (= SKIPPED if boss picks option c) |
| 025 | Dual-axis code-review batch | .scratch/reviews/* | New |
| 026 | Per-book JSON store for Kanban + Todo (= ticket 026; 2 NEW files) | Storage/BookKanbanStore.swift + Storage/BookTodoStore.swift | New |

## Implementation order (= boss 8/22 dependency chain + re-sequence per ticket 024 ⚠️)

```
024 (AGENTS.md §11 amendment MUST land first per L15 re-sequence)
↓
024b (if boss picks option a or b; SKIP if c)
↓
001 → 002 → 003 → 004 → 005 → 006 → 007
↓
008 → 009 → 010 → 011 → 012 → 013
↓
014 → 015
↓
016 → 017 → 018
↓
019 (BookStore singleton injection; depends on tickets 001-013 + 018)
↓
020 → 021 → 022 → 026 (per-book kanban/todo JSON wiring into BookStore)
↓
023 (contract tests for tickets 004/005/006)
↓
025 (dual-axis code-review of the cumulative commit set)
```

Key changes from v3:
- `shelves/<shelf-uuid>/books/<book-uuid>/` is the canonical book path (was `books/<book-uuid>/` at .ws root)
- `reference-library/{raw,entities,abstracts,indexes}/` is the new ReferenceLibrary home (was `shared/references/` + `shared/smart/`)
- 8 Book-private folders (world/characters/outlines/chapters/drafts/sessions/foreshadowing/placeholders) + 2 per-book JSON files (kanban.json, todo.json) = 10 standard entries per book
- Ticket 019 single BookStore @Observable + SwiftUI environment (Apple standard; was "load 4 stores at launch")
- Ticket 026 new = per-book JSON store for kanban + todo (was app-level SQLite; existing KanbanStore.swift + TodoStore.swift get refactored)
- Ticket 012 = ReferenceLibrary independent container (was "shelf-shared top-level view")
- Existing files at `Sources/WenshuApp/Core/Kanban/KanbanStore.swift` (345 lines) and `Sources/WenshuApp/Core/Todo/TodoStore.swift` (241 lines) are refactored, not deleted