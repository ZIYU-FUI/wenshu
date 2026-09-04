# CP3 spec-axis review — v0.26 tickets 008-013 (6 view commits)

Reviewer: pocock single-agent · 2026-08-26 · spec axis only
Scope: commits `a7b7d5c43` (008) → `aa3555432` (009) → `ac4302c8f` (010) → `4fb27dd55` (011) → `95f789c29` (012) → `2497c2c88` (013)
Spec: `.scratch/2026-08-26-fcp-library-replica/spec.md` (v5, dual-axis PASS)

## OOB cross-check

Boss 2026-08-26 OOB items mapped to CP3 surface.

| # | OOB claim | Evidence | Verdict |
|---|---|---|---|
| 1 | Library = `.ws` | `World.swift:130-134` + `Reference.swift:149-153` build paths composing to `.ws` root via ticket 004/005/006 storage. | **PASS** |
| 2 | Bookshelf = parent of books; user-named | No CP3 surface touches Bookshelf; views are per-book (`WorldOutlineView:27`, `CharacterOutlineView:22`) or library-level (`ReferenceLibraryOutlineView:18`). | **PASS** |
| 3 | Book = 10 standard entries (8 folders + 2 data) | `World.swift:89` writes to `world/`; `Character.swift:153` writes to `characters/`. Views read only from these subfolders; no view renders kanban.json / todo.json (= ticket 026 deferred). | **PASS** |
| 4 | World + Characters PRIVATE to each Book | `WorldOutlineView:27` carries `bookId`; `WorldEntryCard` (L162-190) renders only entries from `store.loadWorld()` (= bookId-scoped). `CharacterOutlineView:22` mirrors. Cross-book leak impossible. | **PASS** |
| 5 | ReferenceLibrary library-public; LLM Wiki 4-layer | `ReferenceLibraryOutlineView:18` takes `ReferenceStoring` only — no `bookId` (library-scoped by absence). `Reference.swift:54-59` defines `isUserFacing` = true only for `.layerRaw` + `.layerEntities`. View filters tabs at L40. | **PASS** |
| 6 | Single-shelf model | No CP3 commit modifies onboarding (`LibraryRootView.swift`); `BookOutlineView.swift` + `LibraryOutlineView.swift` untouched per `git diff --stat d83d3df8f..HEAD` (zero diff). | **PASS** (preserved) |
| 7 | Library Properties panel | Out of scope for 008-013 (= ticket 014, commit `10f2a37fc`); CP3 correctly does not land this. | **PASS** (deferred) |

## Q&A cross-check

Each boss 2026-08-26 Q&A decision, verified against the 6 view commits.

| Q | Decision | Evidence | Verdict |
|---|---|---|---|
| Q1 | Scope covers all 4 entity types (World, Character, Reference, plus Book) | `WorldOutlineView` + `WorldEntryEditorSheet` + `CharacterOutlineView` + `CharacterEditorSheet` + `ReferenceLibraryOutlineView` + `ReferenceEditorSheet` = 6 view files for 3 new entity types (Book views already shipped). | **PASS** |
| Q2 | 角色+世界观 Book 私设 / 资料库 库公 | `WorldOutlineView:27` carries `bookId`; `CharacterOutlineView:22` carries `bookId`; `ReferenceLibraryOutlineView:18` does NOT carry `bookId` (= library-scoped). Ownership split implemented. | **PASS** |
| Q4 | Chapter = `.md`, NOT domain entity | No view treats Chapter as a domain entity. `CharacterEditorSheet:108-113` uses `referenceRefIds` for cross-ref (NOT chapter); `WorldEntryEditorSheet:113` preserves `characterRefIds`. No Chapter domain file added. | **PASS** |
| Q5 | Layout = `shelves/<shelf>/books/<book>/` + `reference-library/{raw,entities,abstracts,indexes}/` | `World.swift:130-134` builds `bookDirectory/world/<filename>.md` (= `bookDirectory` = `<.ws>/shelves/<shelf>/books/<book>/` per `FileSystemWorldStore.swift:85`); `Reference.swift:149-153` builds `referenceLibraryRoot/<layer>/<filename>.md` where `<layer>` ∈ `raw|entities|abstracts|indexes` (L32-39). `ReferenceLibraryOutlineView:140-147` calls `store.loadReferences(layer:)` per selected tab. | **PASS** |
| Q6 | JSON sidecar + .md for folders | `WorldOutlineView:121` calls `store.loadWorld()` (= reads `world.json` index per spec ticket 004); `WorldEntryEditorSheet:62-70` calls `store.saveEntry(_, bodyMarkdown:)` per the protocol at `FileSystemWorldStore.swift:44` (writes both .md + index atomically). Same for Character. | **PASS** |
| Q7/Q10 | UUID shelf dirs | Filenames = `<uuid>.md` per `World.swift:122-124`, `Character.swift:147-149`, `Reference.swift:144-146`. Stable across renames. | **PASS** |
| Q8 | Character = JSON + md | `CharacterOutlineView:102` calls `store.loadCharacters()`; `CharacterEditorSheet:84-126` produces a `Character` Codable struct. JSON sidecar via storage layer (ticket 005). | **PASS** |
| Q9 | `@<type>.<name>` cross-refs | `Character` carries `worldRefIds` + `characterRefIds` + `referenceRefIds` (L110-112); `WorldEntry` carries `characterRefIds` (L96); `Reference` carries `characterRefIds` + `worldRefIds` + `bookRefIds` (L109-111). Editor sheets preserve these fields on edit (CharacterEditorSheet:108-112, WorldEntryEditorSheet:113, ReferenceEditorSheet:108-110). @-parser wiring = ticket 007 (already merged). | **PASS** |
| Q12 | Single-library permanent | No CP3 commit adds a "switch library" UI; no commit references any userDefaults key for multiple libraries. | **PASS** (preserved) |

## Per-ticket acceptance

**008 WorldOutlineView** — PASS
Cards = type icon + label + name + summary (L167-183). Functional-injection: `WorldStoring` (L24) + `bookId` (L27) as View params; no `WenshuLibrary` ref; ready for @Environment in ticket 019. Book-private by construction. 1 new file (191 lines).

**009 WorldEntryEditorSheet** — PASS
Fields match `WorldEntry` (ticket 001): name required + validated L93, type picker 5 cases L63-69, summary L81. `.other` exposes new-type input L70-78. 1 new file (127 lines).

**010 CharacterOutlineView** — PASS
Cards = role icon + label + name + optional age + optional arc + summary (L114-142). Color coding via `CharacterRole.colorHex` (Apple system `#FF3B30/FF9500/34C759/8E8E93/5856D6` per `Character.swift:48-54`). Stroke overlay L150-153. Book-private. 1 new file (186 lines).

**011 CharacterEditorSheet** — PASS
Fields match `Character` (ticket 002): name required + validated L86, age optional L56, role picker 5 cases L59-66, arc optional L69, summary L74. 1 new file (127 lines).

**012 ReferenceLibraryOutlineView** — PASS
LLM Wiki 4-layer per spec v5 L100-103 + boss 8/26 '用户只关注实体'. Tabs filter `ReferenceLayer.allCases.filter { $0.isUserFacing }` L40. Default selected `.layerEntities` L20. Cards: layer icon + label + source + title + summary + URL (L154-186). Library-public — no `bookId`. 1 new file (194 lines).

**013 ReferenceEditorSheet** — PASS
Fields match `Reference` (ticket 003): title required + validated L87, source optional L53, url optional L55, layer picker filtered by `isUserFacing` L60-66, summary L75. `defaultLayer = .layerRaw` param L26. 1 new file (125 lines).

## Cross-cutting verification

**G — ReferenceLibrary at library root (spec L234-247; boss Q3 '在书架漏出')** — PASS
`ReferenceLibraryOutlineView` declares no `bookId`; takes only `ReferenceStoring`. Wiring into the library's sidebar (LibraryOutlineView) is ticket 019 followup — out of scope for 008-013 per boss 8/22 protocol. The view itself is library-level by construction.

**H — Decoupled from existing BookOutlineView / LibraryOutlineView** — PASS
`git diff --stat 9b9fbccba..HEAD -- Sources/WenshuApp/Views/Library/BookOutlineView.swift Sources/WenshuApp/Views/Library/LibraryOutlineView.swift` returns zero changes. Functional-injection pattern (store + bookId as View parameters) = clean BookStore singleton integration in ticket 019.

**I — UI 全中文 carve-out (boss 8/25)** — PASS
All 6 files carry CJK only in: (a) header comment lines (boss OOB block quoted verbatim); (b) UI displayName strings (button labels, section headers, form labels, empty-state messages). No CJK in code identifiers or code comments outside the documented boss-OOB quotes. `AGENTS.md §11` English-only standard preserved.

**Build status** — PASS
`swift build` complete in 2.02s, zero errors, zero new warnings. Existing entitlements warning pre-dates CP3.

## FAIL

None.

## SUGGEST

1. **Ticket 008 `WorldOutlineView.swift:41`** — `@State private var newEntryName: String = ""` declared but unused. Dead state — remove in a followup.

2. **Ticket 012 `ReferenceLibraryOutlineView.swift:105`** — Empty-state subtitle describes the raw layer for both tabs. Consider switching the hint per selectedLayer for clarity.

3. **Tickets 009/011/013** — Form sheets use a consistent `VStack { header; Divider; Form; Divider; buttons }` shell. Consider extracting an `EditorSheetShell` view in v0.27+ to dedupe the chrome if a 4th editor lands.

4. **Ticket 010 `CharacterOutlineView.swift:150-153`** — Role-color stroke overlay (`.opacity(0.4)`) is a nice Apple HIG semantic cue. Recommend the same treatment for `WorldEntryCard` in a v0.27+ polish pass (currently flat `.tint`).

## VERDICT

**PASS** — all 6 view commits implement the v5 spec UI contract for tickets 008-013. Spec axes A-I (OOB cross-check, Q&A cross-check, per-ticket form-field parity, file scope, library-root placement, decoupling, CJK carve-out) verified by direct file reads + git diff + swift build. Zero FAIL. Four non-blocking SUGGESTs noted for v0.27+ polish.