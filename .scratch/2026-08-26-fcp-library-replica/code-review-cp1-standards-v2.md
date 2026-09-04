# CP1 v2 — Standards axis review (3 FAIL fixes)

Scope: re-review after the prior CP1 standards-axis verdict FAIL (F1 + F2 + F3) was addressed by 2 followup commits (`ca0d6ad26`, `ec44fea`). Verifies ONLY the 3 fixes plus 3 boss-policy / rule-set regressions. Full CP1 chain = 9 commits ending at HEAD = `ec44feab`.

Chain verified at HEAD:
```
ec44feab fix(wenshu): v0.26 ticket 024 commit-scope typo followup — correct 'wensch' to 'wenshu' in d83d3df8f
ca0d6ad26 fix(wenshu): v0.26 ticket 003 followup — ReferenceLayer case naming + trailing newline
a78cd87e5 feat(wenshu): v0.26 ticket 006 — Storage layer for Reference
1eb15cf30 feat(wenshu): v0.26 ticket 005 — Storage layer for Character
e28c25dc3 feat(wenshu): v0.26 ticket 004 — Storage layer for World
82f908539 feat(wenshu): v0.26 ticket 003 — Reference entity schema
50175660b fix(wenshu): v0.26 pre-existing build break
4ec28974b feat(wenshu): v0.26 ticket 002 — Character entity schema
b27b033a5 feat(wenshu): v0.26 ticket 001 — World-building entity schema
d83d3df8f feat(wensch): v0.26 ticket 024 — AGENTS.md §11 amendment + CONTEXT.md FCP library replica glossary
```

## FAIL

(empty)

## SUGGEST

(empty)

## PASS

### A. `swift build` clean at HEAD

`swift build` at `ec44feab` (with working-tree dirty only by `.scratch/` + `Tools/wenshu-devtool/tests/` + `Tools/wenshu-devtool/pollution_watchdog.py` untracked files, none of which are in any SwiftPM target) → `Build complete! (1.74 sec)` [terminal transcript]. Second run after grep checks → `Build complete! (4.32 sec)`. Zero warnings, zero errors. The pre-existing untracked-file notice (`1 file(s) which are unhandled`) refers to `Wenshu.entitlements` (a pre-existing project convention, not a regression — same notice would have appeared at `82f908539`).

### B1. F1 — ReferenceLayer uses prefixed names

`git show HEAD~1:Sources/WenshuApp/Domain/Reference.swift` (= content of `ca0d6ad26`, lines 26-29) declares:

```swift
enum ReferenceLayer: String, CaseIterable, Codable, Sendable {
    case layerRaw
    case layerEntities
    case layerAbstracts
    case layerIndexes
```

All 4 switch sites (`directoryName`, `displayName`, `isUserFacing`, `icon`) updated to the `layerX` form. `git grep -nE "\bReferenceLayer\.(raw|entities|abstracts|indexes)\b" -- 'Sources/**/*.swift'` → `no hits`. Storage layer (`FileSystemReferenceStore.swift`) was not modified (it never referenced the old names directly; it used the `directoryName` accessor which only changed its return values). Build-clean confirms no orphan references.

### B2. F2 — empty commit documents the `d83d3df8f` typo

`git show --stat ec44fea` shows zero file changes (commit body documents, file tree empty) — meets the empty-commit design choice. `git log -1 --format='%s' ec44fea` → `fix(wenshu): v0.26 ticket 024 commit-scope typo followup — correct 'wensch' to 'wenshu' in d83d3df8f` (= explicitly correct scope per conventional-commit). Commit body explains why no amend was possible (= `d83d3df8f` is the parent of 7 CP1 commits; amending would orphan them and violate the 1-file-per-commit rule for the typo-fix itself, which is 0-file). Historical `d83d3df8f` retains its `feat(wensch)` typo (= transparent archaeological trail).

### B3. F3 — Reference.swift ends with newline

`tail -c 1 Sources/WenshuApp/Domain/Reference.swift | xxd` → `00000000: 0a` (= ASCII LF, 0x0A). POSIX-compliant file terminator. Confirmed at HEAD (= same content as `HEAD~1` since `ec44fea` is empty).

### C. Boss 8/22 (1 file per followup) + 8/25 (English only, no forbidden vocab)

- `ca0d6ad26`: `1 file changed, 20 insertions(+), 20 deletions(-)` → only `Sources/WenshuApp/Domain/Reference.swift` (per `git show --name-only ca0d6ad26`). Subject + body English only. Zero hits of the 12-token family.
- `ec44fea`: 0 files (= the body justifies why; 1-file-per-commit is N/A for the typo fix in a parent commit; amend would have caused a multi-commit orphan + rebase, more invasive). Subject + body English only. Zero hits.

### D. AGENTS.md §11 + §12 forbidden vocab zero hits across all 9 commits

`python3 Tools/wenshu-devtool/commit_filter.py --hook=ci-scan` → no output (clean). `python3 Tools/wenshu-devtool/commit_filter.py --hook=pre-push` → no output (clean). Manual cross-check: for each of the 9 commits, bodies + non-allowlisted diffs scanned for the 12-token family (`修真|渡劫|筑基|返虚|结丹|金丹|元婴|飞升|天劫|雷劫|心魔|魔障`) → zero hits. `AGENTS.md` §9 (rule definition, allowlisted) and `CONTEXT.md` §113 (rule definition, allowlisted) are the only files in the whole repo that mention the family at all. §11 (project baseline, line 14+) and §12 (cross-role expression, line 36+) contain zero forbidden tokens — `awk` extraction confirms.

### E. CP1 implementation work (tickets 001-006) unchanged by followups

`git log -1 --format='%h %s' -- <file>` for each ticket's primary file:

- `Sources/WenshuApp/Domain/World.swift` → `b27b033a5` (ticket 001)
- `Sources/WenshuApp/Domain/Character.swift` → `4ec28974b` (ticket 002)
- `Sources/WenshuApp/Domain/Reference.swift` → `ca0d6ad26` (ticket 003 + F1+F3 followup)
- `Sources/WenshuApp/Storage/FileSystemWorldStore.swift` → `e28c25dc3` (ticket 004)
- `Sources/WenshuApp/Storage/FileSystemCharacterStore.swift` → `1eb15cf30` (ticket 005)
- `Sources/WenshuApp/Storage/FileSystemReferenceStore.swift` → `a78cd87e5` (ticket 006)

Only `Reference.swift` was touched by the followup. Diff scope (`git show ca0d6ad26 -- Sources/WenshuApp/Domain/Reference.swift`) is surgical: `ReferenceLayer` enum (5 sites: case declarations, directoryName, displayName, isUserFacing, icon) + trailing newline. `struct Reference` (= the per-entity metadata struct from ticket 003) is byte-identical between `82f908539` and `ca0d6ad26` apart from the trailing-newline append. Tickets 001, 002, 004, 005, 006 implementation work is byte-identical to its original commit (no followup touched those files).

## VERDICT

**PASS** — all 3 FAILs fixed, all 3 axes (build, boss-policy, rule-set) clean, CP1 implementation work preserved.
