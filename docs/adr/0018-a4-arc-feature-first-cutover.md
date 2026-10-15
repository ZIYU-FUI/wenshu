# ADR-0018: A4 arc = feature-first 切包 (WenshuApp)

**Status**: Accepted
**Date**: 2026-10-15
**Author**: wenshu (boss directive 2026-10-15 "文件目录结构你一并做了吗")
**Replaces**: Layer-first organization (= Core/ / UI/ / Views/ / Services/ / State/ / Storage/ / Domain/ = 16 top-level dirs in WenshuApp/)

## Context

The WenshuApp Swift package currently uses **Layer-first** organization:
419 swift files spread across 16 top-level directories (AI, App, Chat, Core,
Domain, Editor, Services, Settings, State, Storage, UI, Views, etc.) + 50+
sub-directories. The Core/ directory has 21 sub-features mixed together
(Agent / Auth / Backup / Bookmarks / Chat / Composer / etc.). The UI/ and
Views/ directories have 11 + 18 sub-areas each.

The pain: a feature change to "Chat" requires touching 4+ directories:
  - `Sources/WenshuApp/Core/Chat/` (the model + store)
  - `Sources/WenshuApp/UI/Chat/` (the UI primitives)
  - `Sources/WenshuApp/Views/Chat/` (the screen-level views)
  - `Sources/WenshuApp/Services/Chat/` (the service layer)
  - `Sources/WenshuApp/State/Chat/` (the state layer)
  - `Sources/WenshuApp/Tests/.../Chat/` (the tests)

This is the "wide tree" anti-pattern: every feature is sliced across many
directories, so reasoning about a feature requires 4-5 directory jumps.
AI agents (and new team members) waste time finding which file owns a
given feature.

## Decision

A4 arc = reorganize WenshuApp from **Layer-first** to **Feature-first**,
following the Apple Backyard Birds 1:1 pattern (= `Sources/Bird/`,
`Sources/Plant/`, `Sources/Shop/` = each feature in 1 directory with
internal `Model/ + View/ + Store/ + Tests/`).

Each ticket = 1 commit (= per AGENTS.md §1.10).

### Target structure

```
Sources/WenshuApp/
├── App/                        (= main app entry + window group)
├── Features/
│   ├── Chat/                   (= A4.1)
│   │   ├── Model/             (WSChatMessage, ChatMessageView, etc.)
│   │   ├── View/              (ChatZoneView, ChatMessageView, etc.)
│   │   ├── Store/             (ChatSessionViewModel, etc.)
│   │   └── Service/           (LiveChatRepository bridge, etc.)
│   ├── Editor/                 (= A4.2)
│   │   ├── Model/
│   │   ├── View/              (EditorView, EditorPaperCanvas, etc.)
│   │   ├── Store/             (EditorPersistence, etc.)
│   │   └── Service/           (EditorActions, etc.)
│   ├── Library/                (= A4.3)
│   │   ├── Model/             (Book, Document, Reference, etc.)
│   │   ├── View/              (LibraryRoot, AppleSidebar, etc.)
│   │   └── Store/             (WenshuLibrary, BookStore, etc.)
│   ├── Agent/                  (= A4.4)
│   │   ├── Model/             (WenshuConductor, ConversationLoop, etc.)
│   │   ├── View/              (AgentPanel, etc.)
│   │   ├── Store/             (WenshuConductorImportRouter, etc.)
│   │   └── Service/           (Librarian tools, etc.)
│   ├── Kanban/                 (= A4.5)
│   │   ├── Model/             (WSKanbanTask, KanbanStatus, etc.)
│   │   ├── View/              (KanbanView, etc.)
│   │   └── Store/             (WSKanbanRepository, etc.)
│   └── Outline/                (= A4.6)
│       ├── Model/
│       ├── View/
│       └── Store/
├── Shared/                     (= A4.7: cross-feature code)
│   ├── UI/                    (= SFIcon, DesignTokens, IconStyles, etc.)
│   ├── Domain/                (= domain types used across features)
│   └── Foundation/            (= cross-cutting helpers)
├── Resources/                  (= unchanged: assets, .lproj)
└── Persistence/                (= already gone: moved to WenshuData)
```

### Per-ticket scope (1 commit each)

| # | Ticket | Files | Scope |
|---|--------|-------|-------|
| 1 | A4.0 = ADR-0018 + plan | 1 ADR | docs only |
| 2 | A4.1 = Chat feature | ~30 files | `Core/Chat/ + UI/Chat/ + Views/Chat/ + State/ + Services/ → Features/Chat/` |
| 3 | A4.2 = Editor feature | ~40 files | `Editor/ + UI/Editor/ + Core/Composer/ → Features/Editor/` |
| 4 | A4.3 = Library feature | ~50 files | `Domain/ + Storage/ + Views/Library/ + Core/Storage/ + Core/Bookmarks/ → Features/Library/` |
| 5 | A4.4 = Agent feature | ~60 files | `Core/Agent/ + UI/Agent/ + Services/ → Features/Agent/` |
| 6 | A4.5 = Kanban feature | ~30 files | `Core/Kanban/ + Views/Kanban/ → Features/Kanban/` |
| 7 | A4.6 = Outline feature | ~20 files | `Core/Outline/ + Views/Outline/ → Features/Outline/` |
| 8 | A4.7 = Shared/ formalize | ~30 files | `Core/Foundation/ + UI/Chrome/ + UI/Component/ + DesignTokens → Shared/` |
| 9 | A4.8 = delete empty layer dirs | 0 files | `rmdir Core/ UI/ Views/ Storage/ Domain/ Services/ State/` |
| 10 | A4.9 = docs | 1 README | update WenshuApp package structure doc |

### Ticket order rationale

  - A4.0 first (= plan)
  - A4.1-A4.6 in dependency order (= Chat is the most central feature; =
    Library owns Books (= the entity that Chat can attach to); = Agent
    consumes both)
  - A4.7 last (= Shared/ is everything that doesn't fit in a feature)
  - A4.8 after Shared/ (= when everything is moved, the old layer dirs
    are empty)
  - A4.9 docs at the end (= the structure is final)

### Risks

  - **Risk 1**: cross-feature imports (= Chat needs Library's Book;
    = Agent needs Chat + Library). The fix = explicit `import` (= each
    feature's `Package.swift` target is `WenshuApp`; = cross-feature
    use = `Features/Library/...` from `Features/Chat/...` is allowed).
  - **Risk 2**: tests need to follow the feature (= `Tests/WenshuAppTests
    /Features/Chat/`). The existing tests are in `Persistence/`,
    `Core/`, `UI/`, `Views/`, `Agent/`, etc. = per-test re-import path
    update. Some tests test multiple features (= harder to move; =
    either leave them at top-level or split).
  - **Risk 3**: Settings = a cross-cutting feature (it configures every
    other feature). The fix = leave Settings at top-level (= `App/
    Settings/` or just `Settings/`) since it imports from everywhere.

### Per-ticket verification (1 commit per ticket)

Each A4.* commit MUST:
  1. `swift build` (debug) passes
  2. `swift build -c release` passes
  3. Runtime smoke test: wenshu APP launches, all 4 zones render, no crash
  4. `git diff --stat` is small (= ~30-60 file moves, not 200 random changes)
  5. `Tests/WenshuAppTests` are not broken (= the file moves preserve
     test imports)

### Migration tool

The standard `git mv` (= preserves file history) is used for file
moves. After moving:
  - All `import` statements referencing the old paths are updated
  - All callers are re-resolved by the compiler
  - `swift build` will surface any missed references (= exact diff)

## Consequences

### Achieved
  - **6 features in 6 directories** = Chat/Editor/Library/Agent/Kanban/Outline
  - **Cross-cutting code in Shared/** = the rest
  - **1 file = 1 feature** = file location = feature ownership
  - **1 ticket = 1 commit** = auditable history
  - **No production code changes** = pure directory + import path rewrite

### Out of scope

  - A1g.5i = Swift 6 Sendable / ModelActor fixes for WSMemory (test code
    semantic fixes; = scheduled for A1g.5i after A4 arc closes)
  - A3.20 = the remaining 234 v.X.Y comment references (= the
    A3 arc has been deferred per boss directive "注释治理先放一放")
  - A2 / A5 / A6 = other code governance arcs (= not yet scoped)
  - Any production code behavior changes (= pure structure)

## References

- AGENTS.md §1.10 (one commit per ticket)
- AGENTS.md §6.4 (Apple Backyard Birds 1:1 data layer pattern)
- Apple Backyard Birds sample code (Apple's reference for feature-first
  organization in a macOS app)
- ADR-0016 (A1g arc = data layer package)
- ADR-0017 (A3 arc = comment policy sweep closure)
- Boss directive 2026-10-15: "文件目录结构你一并做了吗"
- Boss directive 2026-10-15: "按顺序做完"
