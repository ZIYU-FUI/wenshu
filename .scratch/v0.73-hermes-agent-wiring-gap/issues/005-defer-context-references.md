# Issue 005 · Defer ContextReferences (= keep file, mark as over-implementation)

**Ticket**: 005-defer-context-references
**Scope**: 1 file (= source comment update only)
**Methodology**: Q112 (1 ticket 1 commit 1 file) + boss OOB 9/13 "单 shelf model" (§11 baseline)

## Problem

`Sources/WenshuApp/Core/Agent/Conversation/ContextReferences.swift` (= ~300 LOC, HERMES-PARTIAL-014 port) defines:
- On-disk persistence (= `ContextReferences.persistencePath`)
- Cross-session graph (= `ContextReferences.bySession`, `byFileToSession`)
- `parseContextReferences(...)` (= extracts `[[name]]` markers)

**Production usage is zero.** `ContextEngine.swift` (= the only consumer in the agent loop) does NOT call `ContextReferences.parseContextReferences(...)` or any `by*` accessor. Per HERMES-PARTIAL-013 commit msg: "ContextEngine bundle assembly + token state + compression gates" is wired; the cross-file graph is NOT used.

## Decision (per spec.md §Acceptance)

**Defer.** Per `AGENTS.md §11` baseline "single-shelf model":
- wenshu has exactly ONE library
- books live under `shelves/<shelf-uuid>/books/<book-uuid>/`
- cross-file / cross-session references are over-implementation for v0.73
- Today's `BacklinkResolver` (= `WSLinkRepository.shared`) handles [[name]] resolution correctly within a book

## Plan

### 1. Update file: `Sources/WenshuApp/Core/Agent/Conversation/ContextReferences.swift`

Add a doc-comment header at the top:

```
//
//  DEFERRED (v0.73 spec decision):
//  This 1:1 port of hermes context_references.py (HERMES-PARTIAL-014, 598 LOC)
//  is intentionally NOT wired into ContextEngine (= grep returns zero callers).
//  Per AGENTS.md §11 single-shelf model + wenshu's existing BacklinkResolver
//  (= WSLinkRepository.shared), cross-file / cross-session graph is
//  over-implementation for v0.73.
//  Future ticket (= v0.74+) may wire it IF user requests cross-book reference UI.
//
//
```

No code change. No tests.

## Files changed

- `Sources/WenshuApp/Core/Agent/Conversation/ContextReferences.swift` (+9 lines doc-comment)

## Commit message template

```
docs(wenshu): mark ContextReferences as deferred per v0.73 spec

- Per .scratch/v0.73-hermes-agent-wiring-gap/spec.md §Acceptance
- Wenshu single-shelf model per AGENTS.md §11 (= over-implementation)
- Existing BacklinkResolver handles [[name]] correctly within a book
- File remains as documented future work (= NOT deleted per Q57)

Refs: .scratch/v0.73-hermes-agent-wiring-gap/spec.md
Ticket: 005-defer-context-references
```

## Acceptance

- [ ] `swift build` = BUILD COMPLETE (no code change)
- [ ] Doc-comment header present + verbatim matches template above
- [ ] Code-review 双轴 = Standards pass + Spec pass (= doc-only ticket)

## Out-of-scope

- Deletion (= NEVER per Q57)
- Wiring into ContextEngine (= explicitly deferred per spec)
- BacklinkResolver refactor (= separate ticket, future work)