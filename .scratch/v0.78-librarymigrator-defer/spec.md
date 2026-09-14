# v0.78 LibraryMigrator shotgun surgery · Defer + Inventory

**Branch**: `wt/v0.78-librarymigrator-defer-2026-09-14`
**Generated**: 2026-09-14
**Methodology**: PO v1.1 main-flow 5 steps (Q34) + boss voice trigger Q146

## Context

Per v0.73 repowise inventory, `Storage/LibraryMigrator.swift` had `co_change_scatter` warning (= co-changes with 25 distinct files) with weighted deficit 933.

After 30 min of investigation, the warning is a **false alarm** (= matches Q57: 3rd-party verdict ≠ authority).

## Why this ticket is inventory + defer (no code)

`LibraryMigrator` is a **759-LOC one-time v0.x → v0.26 .ws layout migration** that:
- Ships in v0.26 (= long-since stable)
- Is `idempotent` (= checks `WSSchemaVersion` key, = no-op if already migrated)
- Has no callers in production code paths (= only called during app launch)

The "25 distinct files" co-change pattern comes from:
- v0.26 launch week when multiple files got modified together (= typical launch burst)
- Subsequent v0.40-v0.73 era when hermes-port + phase 5 tickets co-touched the Storage directory

This is **historical correlation, not current shotgun surgery**. The file's actual co-change rate today is normal.

## Decision = **defer + design-doc only**

Per Q34 step 5 ("don't guess API" = Q38 lesson) + Q46 (stop scope-creep), I won't refactor this file's co-change pattern because:
1. The file is already shipped and stable
2. There's no functional bug (= shotgun surgery is a smell, not a defect)
3. Refactoring a stable migration tool risks breaking the one-time migration (= high blast radius)
4. The "co_change_scatter" repowise signal is a historical artifact (= not a current fault pattern)

## Future ticket priority (= shotgun surgery is real but not urgent)

If a future ticket needs to touch `LibraryMigrator.swift`, follow this order:

1. **v0.78a** (this ticket): document the deferral = ✅ done
2. **v0.79** (future): if `LibraryMigrator` needs a v0.x → v0.79 migration step,
   add it as a new method (= `migrateV0xToV079()`) — preserves idempotency
3. **v0.80** (future): if the file needs new sub-scenarios (= e.g. multi-shelf
   migration), split into a `LibraryMigratorV0x26` (= existing) +
   `LibraryMigratorV079` (= new) — but only if a real migration is needed
4. **DO NOT** extract the file's helpers into sub-files unless they exceed
   1000 LOC (= ponytail per Q173 — over-engineering prevention)

## v0.78 deliverables (= this inventory ticket)

- This `spec.md`
- A deferred-header on `LibraryMigrator.swift` (= documents the
  investigation + the reason for not refactoring)

## Acceptance

- [ ] `swift build` = BUILD COMPLETE (no code change in LibraryMigrator)
- [ ] Design doc = present + readable
- [ ] Deferred-header = present + links to this spec
- [ ] Code-review 双轴 = Standards pass + Spec pass (= doc-only ticket)

## Out-of-scope (= explicit)

- Refactoring LibraryMigrator (= the file is stable)
- Adding new migration steps (= no v0.79 migration needed at this time)
- Splitting the file (= over-engineering per Q173)
- Touching any of the 25 co-change files (= no functional reason)