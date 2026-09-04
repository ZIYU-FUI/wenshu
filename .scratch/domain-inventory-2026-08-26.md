# Wenshu Domain Model Inventory — 2026-08-26

Scope: `Sources/WenshuApp/Domain/`, `Sources/WenshuApp/Storage/`, `Sources/WenshuApp/Views/Library/`. Read-only inventory against the current tree.

---

## 1. `Sources/WenshuApp/Domain/` — file inventory

Exactly three `.swift` files exist. No `.xcdatamodeld` bundle, no entity definitions for World / Character / Asset / Reference.

| File | Lines | What it defines |
|---|---|---|
| `/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Domain/Bookshelf.swift` | 60 | `struct Bookshelf` — a named container of books. `id: UUID`, `name: String`, `createdAt`, `updatedAt`. Identity = UUID; directory name = `id.uuidString`. v0.02.0. |
| `/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Domain/Book.swift` | 148 | `struct Book` + `enum BookLength`. Properties: `id: UUID`, `title: String`, `author: String`, `shelfId: UUID`, `length: BookLength` (`.short`/`.medium`/`.long`), `idea: String?`, `createdAt`, `updatedAt`. `BookLength.displayName` is Chinese. Codable back-compat for v52. |
| `/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Domain/Document.swift` | 156 | `struct Document` + `enum BookCategory`. Properties: `id: UUID`, `bookId: UUID`, `category: BookCategory`, `title`, `byteSize: Int`, `summary: String`, `createdAt`, `updatedAt`. The `.md` file IS the source of truth; `Document` is metadata derived at load time. |

`BookCategory` (Document.swift:45) is the only place the words "设定" and "资料库" appear as enum cases. Three cases: `.chapter` → `chapters/`, `.setting` → `settings/`, `.research` → `research/`. `BookCategory` is a category of MD files inside a Book, NOT a top-level domain entity.

**No `.xcdatamodeld` files exist.** No `CoreData`, `NSPersistentContainer`, `NSManagedObject`, or `NSEntityDescription` references anywhere under `Sources/`. AGENTS.md §11 mentions CoreData + single `.ws` file, but the actual code today is filesystem JSON + `.md` — CoreData is not wired up yet.

---

## 2. `Sources/WenshuApp/Storage/` — file inventory

Three `.swift` files. No `.ws` file format code (the `.ws` extension is referenced only as a future target in AGENTS.md §11).

| File | Lines | What it defines |
|---|---|---|
| `/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Storage/LibraryRoot.swift` | 37 | `enum LibraryRoot` — `defaultURL = ~/Documents/wenshu`. Single hard-coded location for v0.02.0; `ensureDefault()` creates the dir on first launch. |
| `/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Storage/LibraryStoring.swift` | 196 | `protocol LibraryStoring` + `struct LibraryStoringError` + `struct SearchHit`. The contract every backend must satisfy. Operations: `loadShelves` / `saveShelf` / `deleteShelf` / `search` / `loadBooks` / `saveBook` / `deleteBook` / `loadBook(id:)` / `loadDocuments(bookId:category:)` / `loadDocumentContent` / `saveDocument` / `deleteDocument`. |
| `/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Storage/FileSystemLibraryStore.swift` | 592 | The sole `LibraryStoring` implementation. JSON-on-disk + `.md` files. Atomic writes via tmp + `replaceItemAt`. Title/summary auto-extracted from `.md` body at read time (no separate metadata sidecar). |

No attachment storage code. Documents are plain `.md` files; binary attachments are not modeled.

---

## 3. `Sources/WenshuApp/Views/Library/` — file inventory

Four `.swift` files. All SwiftUI.

| File | Lines | What it defines |
|---|---|---|
| `/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Library/LibraryOutlineView.swift` | ~16k chars | `struct LibraryOutlineView` — the left-column `List + DisclosureGroup`. Shelve = parent (collapsible), Book = child (selectable). FCP Browser pattern: `Library > Event > ...`. Toolbar `+` opens the new-shelf sheet; context menu = rename / Finder / delete. |
| `/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Library/BookshelfEditorSheet.swift` | ~2.7k chars | `struct BookshelfEditorSheet` — modal for New Shelf / Rename Shelf (mode enum: `.create` / `.rename(String)`). Single name field, Cancel + OK. |
| `/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Library/BookEditorSheet.swift` | ~6.3k chars | `struct BookEditorSheet` — New Book / Rename Book wizard (v52). Three fields: 书名 (TextField, autofocus), 篇幅 (Picker `.segmented` over `BookLength`), 创意点 (TextField, optional). Single-step Form, not NavigationStack wizard. |
| `/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Library/BookOutlineView.swift` | ~7.4k chars | `struct BookOutlineView` — the second-column card grid (v53). Three sections (章节 / 设定 / 资料库), each a grid of `Document` cards with SF Symbol + title + summary + byteSize. Click → `selectedDocumentId`. |

---

## 4. Current data model — full read of `Book.swift` + `Document.swift`

### `Bookshelf` (Bookshelf.swift:24)
- `let id: UUID`
- `var name: String`
- `let createdAt: Date`
- `var updatedAt: Date`
- No relationships encoded as fields (children = books on disk under `<shelf-id>/books/`, discovered by scan).
- No enums on the type itself.

### `Book` (Book.swift:56) and `BookLength` (Book.swift:38)
- `let id: UUID`
- `var title: String`
- `var author: String` (default `""`)
- `let shelfId: UUID` — required at init (orphan-prevention)
- `var length: BookLength` (default `.medium`); enum cases `.short` / `.medium` / `.long` with Chinese displayName
- `var idea: String?` (v52; optional)
- `let createdAt: Date`
- `var updatedAt: Date`
- Relationships: only `shelfId` (UUID reference, not a collection).
- No `chapters`, `documents`, `characters`, `world`, or `synopsis` field.

### `Document` (Document.swift:85) and `BookCategory` (Document.swift:45)
- `let id: UUID`
- `let bookId: UUID` — required at init
- `var category: BookCategory`; enum cases `.chapter` / `.setting` / `.research`; each maps to a filesystem dir (`chapters/` / `settings/` / `research/`) and a displayName + SF Symbol
- `var title: String` (auto-extracted from `.md` H1 or filename)
- `var byteSize: Int` (read from file attrs)
- `var summary: String` (auto-extracted first ~100 chars of body)
- `let createdAt`, `var updatedAt`
- No `characterRefs`, `worldRefs`, `tags`, or `linkedFrom` fields.

### Filesystem layout (Book.swift:18-28, Document.swift:20-26, FileSystemLibraryStore.swift:11-26)
```
~/Documents/wenshu/                                   LibraryRoot.swift:22
  <shelf-id-uuid>/
    shelf.json                                        encoded Bookshelf
    books/
      <book-id-uuid>/
        book.json                                     encoded Book
        chapters/<doc-id-uuid>.md                    BookCategory.chapter
        settings/<doc-id-uuid>.md                    BookCategory.setting
        research/<doc-id-uuid>.md                    BookCategory.research
```
No `world.json`, `characters.json`, `references.json`, or `attachments/` directory.

---

## 5. Gap analysis vs the boss's request

| Concept requested | Exists? | Where / evidence |
|---|---|---|
| 世界观 (World / worldbuilding) | **MISSING** | No `World` struct, no `world.json` schema, no `Book.worldId` field, no enum case in `BookCategory`. Searched `Sources/WenshuApp/Domain/` — only `Bookshelf.swift`, `Book.swift`, `Document.swift` exist. |
| 角色 (Character) | **MISSING** | No `Character` struct, no character model, no character-sheet MD folder, no character list anywhere in `Domain/`. `BookCategory.research` is the closest bucket (cards in BookOutlineView), but it is a generic MD category, not a typed character entity. |
| 资料库 (reference / clippings library) | **PARTIAL** | The Chinese word 资料库 appears exactly once: as `BookCategory.research.displayName` in Document.swift:67. MD files under `research/` are the storage bucket. There is no typed `Reference` / `Clipping` entity, no source URL field, no citation metadata — only generic `Document` metadata (title / summary / byteSize). |
| Hierarchical Library > Book > Chapter > Scene | **MISSING** | Current model is flat: `Library` (filesystem root) > `Bookshelf` > `Book` > `Document`. There is no `Chapter` entity (chapters are just `.md` files under `chapters/`, indistinguishable from settings/research MDs except by category enum). No `Scene` entity. No `Outline` is modeled on the domain layer — `Core/Outline/OutlineExtractor.swift` extracts an outline from MD body at view time. |

**Structural shape today**: `Bookshelf → Book → Document(category) → .md on disk`. No worldbuilding, no characters, no typed references, no chapter entity beyond filesystem convention.

---

## 6. AGENTS.md cross-check (§11 / §12)

`/Volumes/ANAN/Engineering/wenshu/AGENTS.md` is 42 lines total.

- **§11 Project baseline** (lines 14-34): states "Stack = Swift / SwiftUI + CoreData + single-process coroutine + self-built lightweight AI kernel" and "`.ws` single file = CoreData + attachments, locally self-managed." This is **not reflected in the current code** — `Sources/` contains no `.xcdatamodeld`, no `NSManagedObject`, no `.ws` file format. The library today uses filesystem JSON + `.md` via `FileSystemLibraryStore`. If the boss's request implies migrating to the `.ws` / CoreData model, that work has not started.
- **§12 Cross-role expression hard constraint** (lines 36-39): addresses the "老板" honorific only. **No data-model constraints here.**

Net: AGENTS.md §11 declares an aspirational CoreData + `.ws` architecture, but the working code is JSON-on-disk. Any work to add World / Character / Reference entities needs to decide whether they live as new files in `Domain/` (filesystem JSON, matching current shape) or as `NSManagedObject` subclasses (matching §11's stated architecture).
