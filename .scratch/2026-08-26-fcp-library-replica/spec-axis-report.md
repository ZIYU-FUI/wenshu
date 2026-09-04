# Spec-Axis Code Review — FCP Library Replica spec

**Spec under review:** `/Volumes/ANAN/Engineering/wenshu/.scratch/2026-08-26-fcp-library-replica/spec.md`
**Ground truth:** Boss 2026-08-26 OOB (11 items) + Boss decision record (13 Q&A items)
**Review date:** 2026-08-26
**Reviewer axis:** SPEC only (Standards axis deferred to its own review per ticket 025)

---

## A. Boss OOB Fidelity (11 OOB items)

### PASS

- **OOB #1 — Library holds books + world + character + reference.** Spec §"FCP concept → wenshu mapping" (lines 18-27) explicitly enumerates all four entity types in the Shelf row, plus the `books/` + `world/` + `characters/` (per book) + `shared/references/` paths in the layout diagram (lines 31-53). PASS.
- **OOB #2 — Book holds chapters + private world + private characters.** Spec lines 23-24 and 36-46 explicitly place `chapters/`, `world/`, `characters/` under `.ws/books/<book-uuid>/`. PASS.
- **OOB #3 — World-building and Characters private per Book.** Spec line 24 ("Event SQLite attribute | World (= 世界观, Book-private)") and line 23 ("Character (= 角色, Book-private)") plus Ticket 008-011 scope all world/character views to per-Book contexts. PASS.
- **OOB #4 — Reference library shared across all books in shelf.** Spec line 25 ("Reference (= 资料库, Shelf-shared) | .ws/shared/references/") + Ticket 012 (Reference view is "shelf-shared, top-level") correctly establishes shelf-level scope. PASS.
- **OOB #5 — Single-shelf model, onboarding one-time.** Spec §"Single-shelf model" (lines 62-67) plus Ticket 015 ("Confirm logic: if UserDefaults.wenshu.libraryPath is set AND the directory exists AND info.json is readable, skip onboarding entirely") directly implement this. PASS.
- **OOB #6 — Library Properties panel = FCP-style storage locations.** Spec §"Library Properties panel" (lines 69-77) + Ticket 014 deliver a modal sheet with path display, Finder reveal, disk usage, schema version, and move/reset actions — directly mirroring FCP's Inspector ⌃⌘J. PASS.
- **OOB #9 — .ws internal layout = three-layer FCP mirror (info.json + library.sqlite + books/ + shared/ + cache/).** Spec §"ws internal layout" (lines 30-54) shows all five layers in correct positions. PASS.
- **OOB #10 — Cross-references via @ syntax in markdown, parsed at load time, stored in Document.refIds.** Spec §"Cross-reference model" (lines 56-60) + Ticket 007 ("Document.refIds field + @-parser" — adds `charRefIds`, `worldRefIds`, `refIds`, helper `DocumentRefKind`, parses at load time via `loadDocument`). PASS.
- **OOB #11 — Chapter stays as .md files (NOT a domain entity).** Spec line 22 ("Chapter (= 章节, NOT a domain entity) | `.ws/books/<book-uuid>/chapters/*.md`") and Out-of-scope line 248 ("Chapter as independent domain entity (= boss Q3 = a: stay as .md files in chapters/)"). PASS.

### FAIL

- **OOB #8 — Migration = user moves .ws via Finder, NO zip export.** **FAIL.** Spec line 76 specifies `"导出整库为 zip" button` as a panel button. The line itself acknowledges "boss vetoed this in OOB: instead, user moves .ws via Finder" but still includes the button in the spec. The Out-of-scope list (line 249) correctly states the veto, so the spec contradicts itself. Remediation: delete the bullet at line 76 (keep only "在 Finder 中显示", disk usage, schema version, 移动仓库, 重置库).

### N/A (vacuously satisfied)

- **OOB #7 — "replicate FCP library management mechanism" — general mapping.** Spec lines 13-27 produce an explicit FCP → wenshu mapping table that exactly mirrors Library > Event > Project + cross-cutting tag layer. PASS.

---

## B. Boss Decision Record Fidelity (13 Q&A items)

### PASS

- **Q1 = c (full Library Properties panel).** Spec line 27 + line 183-184 ("Hooked into Settings menu (= per boss Q1=c: 用户体验最完整)") + line 69-77 implements a full panel. PASS (conditional on the zip-button removal from FAIL above).
- **Q2 = a (@ reference + Document.refIds).** Spec line 56 ("Cross-reference model (boss decision: Q2 = a)") + line 155-157 (Ticket 007). PASS.
- **Q2 (single-shelf).** Spec line 62 + line 188 ("No switch library button in Settings (= per boss Q2 = single-shelf)") + Out-of-scope line 246. PASS.
- **Q3 = a (Chapter stays as .md).** Spec line 22 + Out-of-scope line 248. PASS.
- **Q4 D1 (physical form = .ws bundle shipped).** Spec line 31 + Ticket 022 references "v0.24 ticket 015.005". PASS.
- **Q5 D1.1 (three-layer FCP mirror, option a).** Spec line 29 (.ws internal layout — three-layer FCP mirror) + 31-54 layout diagram. PASS.
- **Q6 D2 (mixed JSON sidecar + .md body).** Spec lines 41-46 (characters.json + *.md, world.json + *.md) + line 49-50 (references.json + *.md). PASS.
- **Q7 D3 (shelf dir = UUID unchanged).** Implied by spec line 36 ("`<book-uuid>/`") and the existing Bookshelf.swift convention documented at lines 19-20. PASS.
- **Q8 D4 (character storage = JSON sidecar + .md).** Spec line 41-43 + Ticket 005. PASS.
- **Q9 D5 (association via @ + Document.refIds).** Spec line 56-60. PASS.
- **Q10 D6 (shelf dir = UUID unchanged).** Same as Q7. PASS.
- **Q11 D7 (full panel — option c).** Same as Q1. PASS.
- **Q12 D8 (startup = single-shelf, onboarding one-time).** Spec lines 62-67 + Ticket 015. PASS.
- **Q13 (move location = direct Finder, no zip).** Spec §"Single-shelf model" + §"Library Properties panel" — BUT contradicted by line 76's zip button. Conditional PASS (depends on FAIL remediation).

---

## C. Cross-Cutting Consistency

### PASS

- **Shelf holds Book + World + Character + Reference (4 entities).** Spec line 6 + 18-25 mapping table. PASS.
- **World + Character are Book-private.** Spec line 23-24, Ticket 004-005 scopes store by bookId, Ticket 008-011 views scoped per-book. PASS.
- **Reference is shelf-shared.** Spec line 25 + Ticket 006 (no bookId parameter) + Ticket 012 (top-level view). PASS.
- **Chapter is NOT a domain entity.** Spec line 22 + Out-of-scope 248. PASS.
- **.ws layout = info.json + library.sqlite + books/ + shared/ + cache/.** Spec lines 31-54 (5-line summary shows all five). PASS.
- **Onboarding = one-time, skip thereafter.** Spec lines 62-67 + Ticket 015. PASS.

### FAIL

- **Library Properties panel = full panel, NOT just a "导出 zip" button.** Spec line 76 still lists a 导出整库为 zip button. Direct contradiction with boss OOB item 8 (boss vetoed zip export) and boss Q13. Remediation: delete the bullet on line 76.

---

## D. Internal Coherence (within spec)

### PASS

- **`.ws` layout diagram matches ticket creation.** Tickets 004-005 (FileSystemWorldStore / FileSystemCharacterStore) + Ticket 006 (FileSystemReferenceStore) operate on the directories shown in the diagram (lines 41-46, 48-52). PASS.
- **Ticket file paths match actual wenshu source.** Verified against `ls Sources/WenshuApp/`: `Domain/`, `Storage/`, `Views/Library/`, `Views/Onboarding/` already exist; `Views/Settings/` does not (Ticket 014 creates it). Tickets 001-006, 008-013, 015-018, 020-022 reference existing dirs. PASS.
- **Dependency order 001-025 consistent.** Order: Domain (001-003) → Storage (004-006) → Document patch (007) → Views (008-013) → Library Properties (014) → Onboarding enforcement (015) → Smart query (016-017) → LibraryInfo (018) → App wiring (019) → Cache + Bootstrap (020-021) → Migrator (022) → Tests (023) → Docs (024) → Review (025). Dependency chain is sound: stores depend on domain, views depend on stores, app wiring depends on all of the above. PASS.

### FAIL

- **Typo: `Sources/WanshuApp/Views/Library/WorldEntryEditorSheet.swift` (Ticket 009, line 166).** Module name is `WanshuApp` (missing 'e') — actual module is `WenshuApp` (confirmed by all 22 other tickets). This would create the file in the wrong directory and the package would not compile. Remediation: change line 166 to `Sources/WenshuApp/Views/Library/WorldEntryEditorSheet.swift`.

---

## E. Completeness vs OOB

All 11 OOB items have at least one corresponding spec section. No OOB requirement is missing — but the FAIL on OOB #8 (zip button) is a mis-implementation rather than an omission.

---

## F. Scope Creep (additions beyond OOB)

- **Smart query UI (Tickets 016-017).** OOB item 6 mentions Library Properties but not smart query UI. Smart query schema is FCP's "Smart Collection" — defensible as a natural extension of the FCP mapping table (line 26), but worth noting as +1 scope. NOT blocking.
- **Migration shim (Ticket 022).** OOB item 8 says "moving .ws = user moves directory directly in Finder" but doesn't explicitly mandate a v0.x → v0.26 migrator. Ticket 022 is reasonable engineering hygiene for existing user `anbaiqiang.ws`. NOT blocking.
- **Cache directory + thumbnails (Ticket 020).** Not in OOB. OOB doesn't mention thumbnails. Defensible as implementation detail but technically scope creep. NOT blocking.

---

## G. Naming Consistency

### PASS

- **Shelf vs Bookshelf vs Library:** Spec uses "Shelf" as canonical (line 6, 19-26, 62). **However:** existing wenshu codebase uses `Bookshelf` as the struct name (`Sources/WenshuApp/Domain/Bookshelf.swift`). The spec's "Shelf" terminology is a forward-looking rename not yet reflected in code. Tickets 001-022 will need to either rename `Bookshelf` → `Shelf` or accept dual names. This is a **scope-coordination gap** — the spec assumes a rename that is not part of any ticket. Remediation: add an explicit "rename Bookshelf → Shelf" ticket OR document that the spec uses "Shelf" as the product name while `Bookshelf` is retained in code until a future cleanup.
- **Book vs Event:** "Book" canonical (lines 7, 21). PASS.
- **WorldEntry vs World:** "WorldEntry" canonical for entity, "World" for collection/folder (lines 24, 45-46, 85). Consistent. PASS.
- **Character vs Role:** "Character" canonical (line 23, 106). PASS.
- **Reference vs Citation vs Keyword:** "Reference" canonical (line 25, 49-50, 128). PASS.
- **SmartQuery vs SavedSearch:** "SmartQuery" canonical (line 26, 193). PASS.

---

## VERDICT

**CONDITIONAL PASS** — 2 blocking FAILs require fix before implementation begins:

1. **FAIL-A (line 76):** Delete the `"导出整库为 zip" button` bullet. The boss vetoed zip export (OOB #8, Q13); spec contradicts itself by including the button at line 76 while noting the veto in the Out-of-scope list (line 249).
2. **FAIL-B (line 166):** Fix typo `Sources/WanshuApp/...` → `Sources/WenshuApp/...` in Ticket 009. Current text creates the file in a non-existent module directory and breaks compile.

**1 coordination gap** (non-blocking but should be resolved):

3. **SUGGEST-1:** Add explicit ticket for `Bookshelf` → `Shelf` rename, OR document that the spec uses product name "Shelf" while code retains `Bookshelf` until future cleanup. Otherwise ticket implementers will be confused about whether to rename struct/folder/file throughout.

**Minor:** Smart query UI, migration shim, and cache dir are scope additions beyond the OOB but are defensible extensions and not blocking.

**Recommendation:** Apply FAIL-A and FAIL-B fixes in the spec, then proceed to implementation. Standards-axis review (ticket 025) is orthogonal and should run separately.