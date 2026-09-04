# Issue 09 — WorkspaceStore.replaceAll

## What (= scope)

`WorkspaceStore.replaceAll(_ newWorkspace: Workspace) throws` = atomic whole-library write (= unlink + rename swap pattern). Used for: workspace reset, library import, library migration.

Reference Card-master `script-repository.ts` `replaceAll(scripts:)` (= atomic library swap).

## Why (= rationale)

Wenshu currently updates `WorkspaceStore.workspace` in place. Library-wide operations (= reset = "恢复默认布局" already works in v0.31) need atomic semantics.

## Apple-API-first check

- Custom code: `replaceAll` method + atomic file swap helper.
- Apple HIG candidate: Foundation `FileManager.replaceItem(at:withItemAt:backupItemName:options:)` (= macOS 10.6+; atomic file replacement).
- Apple coverage: full (= Apple canonical API for atomic file swap).
- LOC delta: ~150.
- Risk: low.

## Files touched

- `Sources/WenshuApp/State/WorkspaceStore.swift`: add `replaceAll(_:)` method.
- `Sources/WenshuApp/Storage/AtomicFileSwap.swift` (NEW OR shared with Issue 08): `FileManager.replaceItem(...)` wrapper.

## Acceptance criteria

- [ ] `WorkspaceStore.replaceAll(_:)` either fully replaces workspace or fails (= no half-state).
- [ ] Crash mid-replace → next launch sees either old or new workspace (= not partial).
- [ ] Test file: `WorkspaceStore.test.swift` covers: replaceAll happy path, crash mid-replace simulation, failure rollback.

## Dependencies

- Issue 08 atomic file swap helper (= share between `ChatStore` and `WorkspaceStore`).

## References

- Source: Card-master `script-repository.ts` `replaceAll()`
- Spec: `.scratch/2026-09-02-card-master-port/spec.md` §3 item 9

First line: fact. Last line: fact.