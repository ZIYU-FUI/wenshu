# CP1 Standards-axis review — v0.26 FCP library replica (tickets 024 + 001-003)

Reviewer: code-review sub-agent. Date: 2026-08-26. Spec: `.scratch/2026-08-26-fcp-library-replica/spec.md` (v5, dual-axis PASS).

CP1 commits on `wt/multi-agent-dispatch`:

- `d83d3df8f` — feat(wensch): v0.26 ticket 024 — AGENTS.md §11 amendment + CONTEXT.md FCP library replica glossary
- `b27b033a5` — feat(wenshu): v0.26 ticket 001 — World-building entity schema (= WorldEntry)
- `4ec28974b` — feat(wenshu): v0.26 ticket 002 — Character entity schema (= Character + CharacterRole)
- `50175660b` — fix(wenshu): v0.26 pre-existing build break — Character type shadow by WenshuApp.Character
- `82f908539` — feat(wenshu): v0.26 ticket 003 — Reference entity schema (= Reference + ReferenceLayer)

Task description named the final commit `d7b718b47`; actual hash on this branch is `82f908539`. Reviewed against on-disk commits.

---

## FAIL

### F1. `swift build` FAILS at the CP1 tip (`82f908539`)

Verified by `swift build` after `git stash` (reverting uncommitted working-tree mods): two errors at `Sources/WenshuApp/Domain/Reference.swift:56:20` and `57:26` — `enum case 'entities' cannot be used as an instance member` / `enum case 'indexes' cannot be used as an instance member`. This is the EXACT Collection-protocol property shadow the commit body claims it fixed. The commit message says cases are prefixed `layerRaw/layerEntities/layerAbstracts/layerIndexes`, but `git show 82f908539:Sources/WenshuApp/Domain/Reference.swift` L24-28 reads `case raw / case entities / case abstracts / case indexes` — the un-prefixed names the narrative says were REJECTED. The fix exists only in the working tree (uncommitted). Build only passes because of uncommitted modifications. CP1 cannot pass while `82f908539` stands. Same doc-drift pattern as v0.24 ticket 015.004.

### F2. Commit-msg scope typo on `d83d3df8f`

`git log --format="%s" -1 d83d3df8f` → `feat(wensch): v0.26 ticket 024 ...`. Every other CP1 commit correctly uses `feat(wenshu)`. Scope typo breaks the conventional-commit convention. Fix: amend with `feat(wenshu): ...` before any push.

### F3. `Reference.swift` missing trailing newline

`tail -c 20 Sources/WenshuApp/Domain/Reference.swift | xxd` ends with `7d 0a 7d` (no final `\n`); `git show 82f908539` flags `No newline at end of file`. World.swift and Character.swift both end with `7d 0a 7d 0a` — proper POSIX. AGENTS.md hard rule "Last line = fact" implies a final newline. Fix: append a single `\n` (auto-fixed when F1 is committed).

---

## SUGGEST

- **S1.** `ReferenceLayer.directoryName` getter maps both spellings to identical `raw/entities/abstracts/indexes` strings, so spec L100-103 references hold either way. If F1 is resolved by committing the rename, no further action; otherwise the commit message is the only false artifact.
- **S2.** `Character` adds `icon` (SF Symbol) beyond the spec contract (`displayName + colorHex`). Consistent with `WorldEntryType` and the boss 8/26 FCP Role pattern. Slightly exceeds spec; not a defect.
- **S3.** CONTEXT.md L8-20 glossary table uses the same `| Term | Definition |` two-column layout as existing entries below. English body + Chinese term column = AGENTS.md §11 carve-out correctly applied. AGENTS.md L43 footer `v0.07.3 · 2026-08-26` matches commit-body version bump.

---

## PASS

### A. swift build = clean (with working-tree fix applied)

Verified at CP1 tip with the uncommitted `ReferenceLayer` rename applied: `swift build` returns `Build complete!`. Without the rename (F1), the build fails. The build IS achievable; it just hasn't been committed.

### B. World.swift (ticket 001) matches spec contract

`Sources/WenshuApp/Domain/World.swift` L69-119 defines `struct WorldEntry: Identifiable, Hashable, Codable, Sendable` with fields `id / bookId / type / name / summary / characterRefIds / createdAt / updatedAt` — exactly matching the spec contract. `WorldEntryType` (L28) has 5 cases (geography / lore / event / object / other) with `displayName` (Chinese) + `icon` (SF Symbol). `filename = "<uuid>.md"` (id == filename, Apple HIG). `onDiskPath(under:)` returns `bookDirectory/world/<filename>` matching spec path `books/<id>/world/<uuid>.md`. Manual `==` / `hash(into:)` on `id` only. One file, 148 insertions (boss 8/22 satisfied). English-only comments + commit message. No forbidden vocab.

### C. Character.swift (ticket 002) matches spec contract

`Sources/WenshuApp/Domain/Character.swift` L78-141 defines `struct Character: Identifiable, Hashable, Codable, Sendable` with fields `id / bookId / name / age? / role / arc? / summary / worldRefIds / characterRefIds / referenceRefIds / createdAt / updatedAt` — exactly matching spec ticket 002 L166-176. Three typed `refIds` fields implement the spec's "refIds to world entries + other characters + references" precisely. `CharacterRole` (L25) = 5 cases with `displayName` (Chinese) + `colorHex` (Apple system colors) + `icon` (SF Symbol). One file, 167 insertions (boss 8/22 satisfied). English-only commit message + comments.

### D. Reference.swift (ticket 003) matches spec contract (modulo F1 build break)

`Sources/WenshuApp/Domain/Reference.swift` L79-153 defines `struct Reference: Identifiable, Hashable, Codable, Sendable` with fields `id / title / source? / url? / layer / summary / characterRefIds / worldRefIds / bookRefIds / createdAt / updatedAt` — satisfies spec ticket 003 L187-198. `ReferenceLayer` (L24) = 4 cases covering spec's L100-103 LLM Wiki 4-layer requirement; `directoryName` getter maps to correct subdirectory strings; `displayName` is Chinese; `isUserFacing` flag drives v0.26 active/inactive split; `icon` is SF Symbol. `onDiskPath(under:)` returns `referenceLibraryRoot/<layer>/<filename>` matching spec path `reference-library/<layer>/<uuid>.md`. One file, 163 insertions (boss 8/22 satisfied).

### E. ProcessTools.swift + CronPromptScanner.swift fix is minimal and correct

`Sources/WenshuApp/Core/Tools/ProcessTools.swift` L72 + `Sources/WenshuApp/Core/Cron/CronPromptScanner.swift` L35 + L63 use fully-qualified `Swift.Character` to disambiguate from the new `WenshuApp.Character` (= Domain.Character ticket 002). Without the fix (verified by `git stash` test), `swift build` fails with the exact shadow errors the commit body documents. Fix is minimal: 1 type annotation + 2 lines of comment per file; no source behaviour change. Atomic-coupling justified (both files shadow the same identifier; splitting leaves 1 broken file at each intermediate state).

### F. AGENTS.md §11 amendment lands the "NO CoreData" / `@Observable` / filesystem JSON / Apple HIG / single-shelf model

`AGENTS.md` L16 reads "Stack = Swift / SwiftUI + Swift Observation (@Observable) + filesystem JSON + Markdown (per-book private content) + Apple HIG (.fcpbundle-style directory, single-process, no third-party SDK). NO CoreData. NO external AI platform calls (any code file)." Spec v5 L52 warning (§11 baseline formerly declared CoreData) is resolved. L18 lays out the new `.ws` layout. L34 records the single-shelf model. All matches spec v5 § Terminology + § FCP mapping.

### G. CONTEXT.md glossary additions land 11 new terms

CONTEXT.md L8-20 (new "FCP Library Replica domain words (v0.26 — boss 2026-08-26 OOB)" section) defines: 库 / 书架 / 书 / 资料库 / 章节 / 世界观 / 角色 / 看板 / Todo / 智能查询 / 库属性. Each entry cites the physical storage path per spec v5. English body in Definition column; Chinese only in Term column (AGENTS.md §11 carve-out). 1 commit, 2 files (AGENTS.md + CONTEXT.md) — atomic-coupling justified (CONTEXT.md glossary references new §11 entities; splitting leaves glossary entries pointing to non-existent §11 spec).

### H. AGENTS.md §11 + 12 hard rules verified across CP1 surfaces

No 12 forbidden xianxia terms appear in any of the 5 commit messages or in `World.swift` / `Character.swift` / `Reference.swift` / `ProcessTools.swift` / `CronPromptScanner.swift` source bodies (verified by `grep -nE`). No 14 forbidden neutral words appear either — confirmed by grep. Address for the user is consistently `老板` only (no honorific forms in CP1 surface). The only place these forbidden terms appear is the rule-definition carve-out (`AGENTS.md` L8-9 + `CONTEXT.md` L113/L117), which is on the pollution-defense allowlist.

### I. Apple HIG compliance — Identifiable / Hashable / Codable / Sendable / id == filename

All 3 new structs (`WorldEntry` L69, `Character` L78, `Reference` L79) declare the full protocol set `Identifiable, Hashable, Codable, Sendable`. All have manual `==` + `hash(into:)` based on `id` only (Apple HIG id-based identity). All derive `filename = "<uuid>.md"` (id == filename convention per `Document.swift` L131-127 precedent). `onDiskPath(under:)` helpers return `<dir>/<subdir>/<filename>` exactly matching the spec contract paths. All 3 new enums are `String, CaseIterable, Codable, Sendable` with Chinese `displayName` (AGENTS.md §11 carve-out). `CharacterRole` adds Apple-system `colorHex` + SF Symbol `icon` per FCP Role pattern (boss 8/26 OOB).

### J. Spec v5 terminology consistency

`Library` / `Bookshelf` / `Book` / `ReferenceLibrary` glossary entries match the on-disk Domain types. LLM Wiki 4-layer pattern (`raw / entities / abstracts / indexes`) consistently named across AGENTS.md L18, CONTEXT.md L13, `Reference.swift` L9-12, and the commit body. Per-book 8 standard folders + 8 JSON sidecars + 2 JSON data files enumeration matches across AGENTS.md L18, CONTEXT.md L12-13, and spec v5 § Book structure L20-31. Single-shelf model is consistently declared in AGENTS.md L34 + CONTEXT.md L10 + spec v5 L122-127.

---

## VERDICT

**FAIL** (3 blocking issues must be resolved before CP1 can pass standards-axis review)

1. **F1** — `82f908539` does not build; the `ReferenceLayer` rename described in the commit body exists only in the working tree. Resolution: commit the working-tree rename (or amend `82f908539` to include it with a message that matches what was actually delivered).
2. **F2** — `d83d3df8f` has commit-scope typo `wensch` → must be `wenshu`. Resolution: amend before any push.
3. **F3** — `Reference.swift` is missing trailing newline. Resolution: append a single `\n` (auto-fixed when F1 is committed).

On resolution of F1-F3, all remaining axes (A-J) are PASS. Standards-axis review of CP1 can then advance from FAIL to PASS with no further changes.

---

*Reviewer: code-review sub-agent. All claims file:line cited. English only. The only forbidden vocab in this report is in the §11 rule enumeration list (H + AGENTS.md carve-out).*