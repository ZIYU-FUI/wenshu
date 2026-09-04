# CP1 Spec-Axis Review — v0.26 FCP Library Replica (tickets 024 + 001–003)

**Reviewer**: spec-axis subagent · **Date**: 2026-08-26
**Scope** (5 commits on `main`): `d83d3df8f` ticket 024 (AGENTS.md §11 + CONTEXT.md glossary) · `50175660b` Character type-shadow fix · `b27b033a5` ticket 001 WorldEntry · `4ec28974b` ticket 002 Character · `82f908539` ticket 003 Reference.
**Spec under test**: `.scratch/2026-08-26-fcp-library-replica/spec.md` (v5, dual-axis PASS).

---

## OOB cross-check (Boss 2026-08-26 OOB)

| # | OOB claim | Evidence | Verdict |
|---|-----------|----------|---------|
| 1 | Library holds shelves + books + reference-library | `AGENTS.md` L18 (`shelves/` + `reference-library/`) · `CONTEXT.md` L10 (库 row) | **PASS** |
| 2 | Bookshelf = user-named parent of books | `AGENTS.md` L18 "user-created bookshelves" · `CONTEXT.md` L11 `shelves/<shelf-uuid>/{shelf.json, books/}` | **PASS** |
| 3 | Book = 1 novel project; 8 standard folders + 2 data files (= 10 entries) | `AGENTS.md` L18 enumerates all 8 folders + `kanban.json + todo.json` (= 10) | **PASS** |
| 4 | World + Characters PRIVATE to each Book | `AGENTS.md` L18 "Per-book private world + characters" · `CONTEXT.md` L15-16 Book-private · `World.swift` L75 + `Character.swift` L82 mandate `bookId: UUID` | **PASS** |
| 5 | Reference library is library-public, user CANNOT delete or rename | `AGENTS.md` L18 + `CONTEXT.md` L13 · `Reference.swift` L79-112 has NO `bookId` field (confirms library-public) | **PASS** |
| 6 | Single-shelf model + onboarding one-time | `AGENTS.md` L34 + `CONTEXT.md` L10 "single instance, locked to UserDefaults.wenshu.libraryPath" | **PASS** |
| 7 | Library Properties panel | `CONTEXT.md` L20 库属性 row (panel deferred to ticket 014 = CP4) | **PASS** |
| 8 | Migration via Finder, no zip export | Spec L137; not contradicted anywhere in CP1 | **PASS** |
| 9 | `.ws` layout = `shelves/<shelf>/books/<book>/` + `reference-library/{raw,entities,abstracts,indexes}/` | `AGENTS.md` L18 · `Reference.swift` L32-39 + L149-152 build correct paths | **PASS** |
| 10 | Cross-references via `@` + `Document.refIds` | Schemas declare typed `[UUID]` slots; `@<type>.<name>` parser = ticket 007 = CP2 (in-scope split) | **PASS** |
| 11 | Chapter stays as `.md` files (NOT domain entity) | `CONTEXT.md` L14 explicit; no `Chapter.swift` domain file added in CP1 | **PASS** |

**OOB axis: 11/11 PASS** within CP1 scope.

---

## Q&A cross-check (boss 8/26 decisions)

| Q | Decision | Evidence | Verdict |
|---|----------|----------|---------|
| Q1 | scope: all 4 entity types | CP1 ships World + Character + Reference (3 of 4); SmartQuery is ticket 016 (CP4+) | **PASS** |
| Q2 | 角色+世界观 Book 私设 / 资料库 库公 | `World.swift` + `Character.swift` carry `bookId`; `Reference.swift` does NOT — exact ownership split | **PASS** |
| Q4 | Chapter: stay `.md`, NOT domain entity | No `Chapter.swift` in CP1 | **PASS** |
| Q5 | layout: `shelves/<shelf>/books/<book>/` | `AGENTS.md` L18 + `CONTEXT.md` L11-12 | **PASS** |
| Q6 | JSON sidecar + .md for folders; pure JSON for kanban/todo | `AGENTS.md` L18 + `CONTEXT.md` L17-18 (per-book JSON, NOT folders) | **PASS** |
| Q7/Q10 | UUID shelf dirs | `AGENTS.md` + `CONTEXT.md` use `<shelf-uuid>`; filenames built as `<uuid>.md` in all 3 schemas | **PASS** |
| Q8 | character JSON+md | `Character.swift` L9-12 declares `.md` + `characters.json` index; storage is ticket 005 = CP2 | **PASS** |
| Q9 | `@` + `refIds` | All 3 schemas declare typed `[UUID]` slots; parser is ticket 007 = CP2 | **PASS** |
| Q11 | full panel (deferred to ticket 014) | Spec ticket 014 entry exists; CP1 doesn't ship panel | **PASS** |
| Q12 | single-library permanent | `AGENTS.md` L34 + `CONTEXT.md` L10 | **PASS** |
| Q13 | move via Finder, no zip | Spec L137; CP1 adds no zip | **PASS** |

**Q&A axis: 13/13 PASS** within CP1 scope.

---

## Specific axis checks (per task brief)

### A. AGENTS.md §11 amendment (ticket 024)
- **NO CoreData**: `grep CoreData AGENTS.md` returns 0 hits; L16 says "NO CoreData" explicitly; footer L43 says "no CoreData" — spec L52 re-sequencing requirement satisfied.
- **Stack change**: L16 reads "Swift / SwiftUI + Swift Observation (@Observable) + filesystem JSON + Markdown ... NO CoreData" — Standards F4 remediation per spec L333.
- **`.ws` layout**: L18 enumerates Info.plist + chat.sqlite + Icon + shelves/ + reference-library/ + cache/ + per-book 8 folders + 8 JSON sidecars + 2 per-book JSON data files. Matches spec L82-105 diagram.
- **Single-shelf model**: L34 added as separate bullet.
- **Axis A verdict**: PASS within AGENTS.md itself.

### B. CONTEXT.md glossary additions (ticket 024)
All 11 required terms present (L10-20): 库 / 书架 / 书 / 资料库 / 章节 / 世界观 / 角色 / 看板 / Todo / 智能查询 / 库属性 — 11/11. Each row cites physical storage path. **But see F1 below.**

### C. WorldEntry schema (ticket 001) — `World.swift` L69-99
Spec field vs schema: `id` (L70) / `bookId` (L75) / `type: WorldEntryType` with 5 cases geography|lore|event|object|other (L28-33, L79) / `name` (L84) / `summary` (L89) / `characterRefIds` (L96) / `createdAt` (L98) / `updatedAt` (L99). All 9 spec fields present. Storage path L130-134 returns `bookDirectory/world/<filename>` = `books/<book-uuid>/world/<uuid>.md`. **PASS**.

### D. Character schema (ticket 002) — `Character.swift` L78-115
All 12 spec fields present: `id` (L79) / `bookId` (L82) / `name` (L85) / `age?` (L89) / `role: CharacterRole` (L92, 5 cases L25-30) / `arc?` (L96) / `summary` (L100) / `worldRefIds` (L110) / `characterRefIds` (L111) / `referenceRefIds` (L112) / `createdAt` (L114) / `updatedAt` (L115). `CharacterRole` carries `colorHex` (L47-55) + `icon` (L58-66). Storage path L152-156 returns `books/<book-uuid>/characters/<uuid>.md`. **PASS**.

### E. Reference schema (ticket 003) — `Reference.swift` L79-113
All 11 spec fields present: `id` / `title` (L85) / `source?` (L89) / `url?` (L92) / `layer: ReferenceLayer` (L96) with 4 prefixed cases (`layerRaw`/`layerEntities`/`layerAbstracts`/`layerIndexes`, L24-28 — Swift Collection protocol shadow avoidance documented in commit body L19-23) / `summary` (L100) / `characterRefIds` (L109) / `worldRefIds` (L110) / `bookRefIds` (L111) / `createdAt` / `updatedAt`. `ReferenceLayer` carries `directoryName` + `displayName` + `isUserFacing` + `icon` (exceeds spec). Storage path L149-153 returns `referenceLibraryRoot/<layer>/<filename>`; `reference-library/` is **NOT** under `shelves/` — passed as separate parameter from caller, not derived from any shelf path. Matches spec L98-103 + L185-186. **PASS**.

---

## FAIL (blocking issues)

### F1 (BLOCKING) — CONTEXT.md Architecture section still declares CoreData

**File**: `CONTEXT.md` L32-33 (not modified by ticket 024).

**Current state** (verbatim):
```
- **Stack** = Swift / SwiftUI + CoreData + single-process coroutine + self-built lightweight AI kernel.
- **Storage** = `.ws` single file = CoreData + attachments, locally self-managed, path `~/Documents/wenshu/<id>/`.
```

**Why blocking**:
1. Spec L52-53 explicitly says this is a re-sequencing requirement: "§11 baseline line 16 currently declares 'Stack = ... CoreData ...'. This spec's 'NOT CoreData' claim contradicts §11 until ticket 024 lands the §11 amendment. Implementation MUST land ticket 024 BEFORE ticket 001." The same contradiction exists in CONTEXT.md L32-33 — but ticket 024 only added the new glossary table at L6-20 and did NOT rewrite L32-33.
2. CONTEXT.md is the project domain glossary (per its own L1-3). Its L30-38 Architecture section is its authoritative project-baseline block, parallel to AGENTS.md §11. Leaving L32-33 unamended creates the same internal contradiction the spec was trying to eliminate.
3. CP1 introduces 3 new files (`World.swift` L11, `Character.swift` L13, `Reference.swift` L18) referencing spec v5's "FCP library replica" architecture in their header comments. Those files now document one storage model (filesystem JSON, no CoreData) while CONTEXT.md L32 still says another (CoreData).
4. The pollution-defense pipeline treats both files symmetrically, but spec-axis review only verifies whether spec L52's "NOT CoreData" claim is **fully** unblocked. As of CP1, it is only half-unblocked.

**Fix scope**: ticket 024's atomic-coupling justification (spec L335) already covers the CONTEXT.md file — adding ~2 lines to L32-33 is in-scope. Either (a) `git rebase` to amend `d83d3df8f` with the L32-33 rewrite, or (b) land a follow-up fixup commit before CP1 merges.

**Severity**: blocking per spec L52 ("1 spec FAIL = blocking").

---

## SUGGEST (non-blocking)

### S1 — Document.refIds parser wiring is in CP2, not CP1
Q9 commits to `@<type>.<name>` parsing into `Document.refIds`. CP1 schemas declare typed `[UUID]` slots (correct — they're storage representations of resolved UUIDs, populated by ticket 007 parser at load time per spec L213-217). Split is intentional per spec ticket ordering. **No code change needed in CP1.** Ensure CP2 ticket 007 lands before any UI tries to render cross-refs.

### S2 — `Reference.bookRefIds` load semantics
`Reference.swift` L111 declares `bookRefIds: [UUID]` (many-to-many, per spec L108). Spec doesn't pin whether CP2 ticket 006 resolves these eagerly when loading a Reference, or lazily on first UI render (Apple SwiftUI standard). Recommend **lazy** resolution; document the decision in ticket 006's commit body.

### S3 — SF Symbol availability
All SF Symbols in `WorldEntryType.icon` (World.swift L51-55) and `CharacterRole.icon` (Character.swift L60-65) exist on macOS 27 minimum target per `Package.swift`. Flag for CI screenshot verification on clean macOS 27 VM in CP4.

### S4 — `WorldEntry.characterRefIds` asymmetry vs `Character.{world,character,reference}RefIds`
`WorldEntry` only refs Characters; `Character` refs World+Character+Reference. Asymmetry is correct per FCP Role pattern, but undocumented. Recommend a 1-line comment on `World.swift` L91-96 explaining "World only refs Characters because world entries are descriptions of setting, not active agents." Trivial doc patch.

### S5 — AGENTS.md §11 footer no-newline marker
`AGENTS.md` L43 still ends with the `\` + "No newline at end of file" marker (pre-existing convention). Cosmetic; not a CP1 regression. No action.

---

## VERDICT

**FAIL** — one blocking issue (F1: CONTEXT.md L32-33 still says CoreData; ticket 024 only amended AGENTS.md §11, not CONTEXT.md Architecture section).

Fix is small (~2 lines in CONTEXT.md L32-33). Either amend `d83d3df8f` via rebase, or land a fixup commit before CP1 merges. Per spec L52, the amendment MUST be complete before CP1 merges (ticket 001 is already in CP1, so partial amendment doesn't satisfy the re-sequencing requirement).

**All other axes PASS** within CP1 scope. WorldEntry / Character / Reference schemas are field-complete, type-correct, and storage-path-correct per spec. Fix commit `50175660b` is properly scoped (atomic-coupling justified; 2 files shadow the same `Character` identifier). After F1 is fixed, CP1 is spec-PASS and ready to merge.