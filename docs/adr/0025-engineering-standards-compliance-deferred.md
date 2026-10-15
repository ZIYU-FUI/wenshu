# ADR-0025: Engineering Standards Compliance — §6.2 + §6.6 Deferred

## Status

Accepted. This ADR documents the wenshu engineering
standards compliance state after the 8 governance
arcs (A1g.5 through A8) closed, and the items that
remain deferred (= outside this session's scope per
boss 2026-10-15 OOB "本会话的待办, 不是文枢的待办").

## Context

Per AGENTS.md §1-§10 (= project SSOT), wenshu
has 11 sections of project standards. The 2026-10-15
governance arc verified 9/11 sections PASS and 2
sections DEFERRED:

  - **§6.2 Per-feature 5 slots** (= Views/ / ViewModels/
    / UseCases/ / Repositories/ / Models/): DEFERRED
  - **§6.6 600 LOC per .swift file**: DEFERRED

This ADR documents the deferred items, the scope of
fix needed, and the recommended A10-A18 arc plan to
address them.

## §6.2 — Per-feature 5 slots

### Current state (deferred)

Every feature in `Sources/WenshuApp/Features/` has 4
of the 5 slots (= Model/ / Service/ / Store/ / View/).
The `UseCases/` slot (= the Apple Backyard Birds
"interactor" layer that mediates between View and
Repository) is missing everywhere.

```
Features/Agent   = Model/ + Service/ + Store/ + View/
Features/Chat    = Model/ + Service/ + Store/ + View/
Features/Editor  = Model/ + Service/ + Store/ + View/
Features/Kanban  = Model/ + Service/ + View/  (no Store/)
Features/Library = Model/ + Service/ + Store/ + View/
Features/Outline = Model/ + View/  (no Service/, no Store/)
Features/Settings = (flat files, no folder structure)
Features/Shared  = (flat files, no folder structure)
```

### Scope of fix

  - For each feature, add `UseCases/` slot (= extract
    the "what to do" (= business logic) from View
    Models and Service into pure-async UseCase types).
  - For Kanban + Outline + Settings + Shared: also
    add the missing slots (= currently they don't
    have the 4-slot minimum).

### Why deferred (= out of this session's scope)

The §6.2 fix is a **multi-week arc** (= 8 features ×
~1 week per feature = 8+ weeks). It requires:

  - Designing the UseCase protocol (= the canonical
    Swift `protocol XxxUseCase { func execute(...) async
    throws -> Result }` shape per Apple Backyard
    Birds)
  - Refactoring each Feature's View Models to call
    UseCases (= not Services directly)
  - Refactoring each Feature's Services to expose
    repository hooks (= not direct WenshuData calls)
  - Adding the missing slots for Kanban / Outline /
    Settings / Shared

This is **NOT 1 commit per feature** (= per
AGENTS.md §1.10). It's **1 arc = 8+ tickets**.

## §6.6 — 600 LOC per .swift file

### Current state (deferred)

9 files exceed 600 LOC (= §6.6 cap):

```
3645  Sources/WenshuApp/Features/Agent/Service/ImportService.swift
3233  Sources/WenshuApp/Features/Editor/View/PreviewPane.swift
2961  Sources/WenshuApp/Features/Agent/View/ImportSheet.swift
2232  Sources/WenshuApp/Features/Agent/Service/WenshuConductorImportRouter.swift
1438  Sources/WenshuApp/Features/Chat/View/ChatView.swift
1412  Sources/WenshuApp/Features/Agent/Service/BookChapterTool.swift
1225  Sources/WenshuApp/Features/Agent/Store/WenshuConductor.swift
1218  Sources/WenshuApp/Features/Editor/View/EditorView.swift
1210  Sources/WenshuApp/Features/Agent/Service/ImportDocumentTemplates.swift
```

### Scope of fix

Per AGENTS.md §6.6 + wenshu-humanizer-voice reference
("god-class-field-drain-recipe or split"), each
exceeding file must be split into multiple files of
≤ 600 LOC each.

### Recommended A10-A18 arc plan (= 9 tickets, 1
commit per ticket per §1.10)

```
A10  = ImportService.swift 3645 → 4 files
        (ImportRouter + ImportTypes + ImportTargets
        + ImportService actor)
A11  = PreviewPane.swift 3233 → 6 files
        (preview layout + scroll sync + selection +
        search + zoom + toolbar)
A12  = ImportSheet.swift 2961 → 5 files
        (4-zone UI + activity log + progress strip)
A13  = WenshuConductorImportRouter.swift 2232 → 4 files
        (routing strategy + fallback + metrics)
A14  = ChatView.swift 1438 → 3 files
        (input + message list + actions)
A15  = BookChapterTool.swift 1412 → 3 files
        (read + write + diff)
A16  = WenshuConductor.swift 1225 → 3 files
        (orchestrator + tools + dispatch)
A17  = EditorView.swift 1218 → 3 files
        (body + toolbar + sidebar)
A18  = ImportDocumentTemplates.swift 1210 → 3 files
        (templates + helpers + body)
```

Total = 9 tickets × ~1 commit each = 9 commits.
Estimated scope = **2-3 sessions of focused work**
(= 1-2 hours per session, 5-10 commits per session).

### Why deferred (= out of this session's scope)

  - Per AGENTS.md §1.10, "1 ticket = 1 commit" with
    "1 atomic verification". Splitting a 3645-LOC
    actor with cross-extension private state access
    (= Swift 5.5+ feature) is a **multi-commit**
    operation (= 1 commit = 1 type moved, 1 commit
    = 1 extension split, etc.).
  - Each commit must pass `swift build` AND
    `swift test` (= 1 atomic verification). For
    actor splits, the test pass is the only safe
    signal (= 6 ImportServiceTests cover the
    critical-path behavior).
  - Boss OOB 2026-10-15: "本会话的待办, 不是文枢
    的待办" (= this session's scope = the queued
    code governance tickets, NOT the project
    long-term roadmap).

## Compliance Status (final, after 8 governance arcs)

| AGENTS.md SSOT section | State |
| ---------------------- | ----- |
| §1.1 English-only in code | PASS (= 0 CJK in production) |
| §1.2 Sole address = 老板 | PASS (verified by boss OOB) |
| §1.3 Forbidden hedges | PASS (= A3 sweep) |
| §1.4 Forbidden xianxia | PASS (= A3 sweep) |
| §1.5 Comment policy | PASS (= A3 sweep) |
| §1.6 OOB references in code | PASS (= A3 sweep) |
| §1.7 First/last line = fact | PASS (= AGENTS.md) |
| §1.8 High info density | PASS |
| §1.9 Auto-load wenshu-pocock-workflow | PASS |
| §1.10 One ticket = one commit | PASS (= 60+ commits, all 1:1) |
| §2.2 Apple stack exclusive | PASS |
| §2.4 Swift 6 strict concurrency | PASS (= 0 warnings) |
| §2.8 Tests Swift Testing | PASS (= 510 tests, 0 fail) |
| **§6.2 Per-feature 5 slots** | **DEFERRED** (= UseCase layer missing) |
| **§6.6 600 LOC per .swift file** | **DEFERRED** (= 9 files exceed) |
| §7.1 swift build exits 0 | PASS |
| §7.2 swift test exits 0 | PASS |
| §7.3 9-grep sweep | PASS (= 0 magic literals) |
| §7.5 CJK comment audit | PASS |
| §7.8 Commit hygiene | PASS |

**Compliance rate = 9/11 sections PASS, 2/11 DEFERRED**.

## Future Sessions

The next session (= if boss gives OOB) should pick
up either:

  - **§6.2 UseCase layer arc** (= 8 features × ~1
    ticket per feature = 8+ tickets)
  - **§6.6 god-class split arc** (= 9 files × 1
    ticket each = 9 tickets, A10-A18)

Both arcs follow AGENTS.md §1.10 + §8 PO methodology
(= 1 ticket = 1 commit + 1 atomic verification).

Per boss 2026-10-15 OOB, this ADR's scope is the
**deferred items document** (= not a roadmap). The
next session should pick its own OOB-driven scope.
