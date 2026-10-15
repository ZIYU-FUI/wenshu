---
name: wenshu-architecture-decision-record
description: ADR-0016 — A1g WenshuData extraction deferred. Probes 1-8 + final-attempt result.
version: 3.1.0
license: MIT
platforms: [macos]
metadata:
  hermes:
    tags: [wenshu, architecture, adr, persistence, decision-record]
    category: architecture
    note: "ADR-0016 update. Probes 1-5 + 7-8 = 6 boundary refactors landed (= write-domain-in / read-@Model-out pattern established). Probe 6/8 = WSPreference already clean (= no change needed). Final A1g WenshuData extraction attempted on 2026-10-15 = rolled back (= business-logic functions inside 2 of 8 Repositories depend on app-side types = domain type refactor deeper than 1 commit)."
---

# ADR-0016: WenshuData extraction — status 2026-10-15

Date: 2026-10-15 (v3.1 governance arc, A1 boundary probes).

## Context

Boss 2026-10-15 拍 = v3.1 governance restructure project: extract
`Sources/WenshuApp/Persistence/` (38 files = 22 @Model + Container + 8
Repository + ModelsSchema + TypedID + LibraryMigrationState) into a local
SwiftPM package `WenshuData/` (= Apple Backyard Birds canonical pattern, =
AGENTS.md §6.4).

## Decision (= scope re-baselined)

WenshuData extraction **does not ship** as 1 ticket. Per PO §8.5
(= P0 fix = build pass first), the final extraction commit (A1g) was
attempted + rolled back (= public modifier cascade across 38 files
plus 2 of 8 Repositories contain business-logic functions that depend
on app-side types = `summarizeIfNeeded(WenshuVerifier)` and
`loadSubAgentRuns / recordSubAgentRun(SubAgentRun)` in WSChatRepository;
= the function body calls the LLM via WenshuVerifier and constructs
SubAgentRun domain types, which are app-side concerns, not data-layer
concerns).

The 6 of 8 boundary refactors DO ship (= the A1 boundary work that
unblocks a future A1g). They establish the Apple-canonical layering
pattern (= write API = domain-in / read API = @Model-out) and fix the
caller-side `Sendable` boundary by converting inside `MainActor.run`
closures (PersistentModel is NOT Sendable across actor boundaries).

## Probes landed (8 commits on main)

| # | Commit | Repository | Status |
|---|--------|------------|--------|
| 1 | `13d1430e0` | WSBookmarkRepository | refactored: write domain in, read @Model out |
| 2 | `55e3419b3` | WSPreferenceRepository | already boundary clean (no app-domain refs) |
| 3 | `100d25f1d` | WSLinkRepository | refactored |
| 4 | `7b2a46c81` | WSTodoRepository | refactored |
| 5 | `7a02a21eb` | WSKanbanRepository | refactored |
| 6 | `1317b4ea5` | WSProviderKeyRepository | already boundary clean (AppleKeychain = spec comment, not type) |
| 7 | `0451c8dd6` | WSMemoryRepository | refactored |
| 8 | `1f312c5b8` | WSChatRepository | refactored (= except 3 business-logic functions deferred to app) |

## A1g arc — boundary-decouple phase (4 commits on main)

After the A1 probes (= which left the Repositories writing to /
returning app-side domain types) and the A1g.1 conversation-ops
relocate (= which only handled WSChatRepository), the write APIs
were still leaking app-side types in 4 of 8 Repositories. A1g.2
fixed them one at a time:

| # | Commit | Repository | Boundary fix |
|---|--------|------------|--------------|
| A1g.1 | `0a535be60` | WSChatRepository (3 funcs) | Relocated summarizeIfNeeded / loadSubAgentRuns / recordSubAgentRun to app-side `ConversationOps`. Data layer no longer owns LLM call or SubAgentRun construction. |
| A1g.2 1/3 | `db836356b` | WSBookmarkRepository | `add(_:Bookmark)` -> `add(id:title:docID:)`; Spotlight bootstrap moved to caller. |
| A1g.2 2/3 | `c52576859` | WSKanbanRepository | `add(...KanbanStatus)` -> `add(...String)`; `add()` returns String (id) instead of KanbanTask; `transition(...KanbanStatus)` -> `transition(...String)`; toDomain helper deleted. |
| A1g.2 3/3 | `96ea6aea0` | WSMemoryRepository + WSTodoRepository | MemoryID / Memory / TodoStatus / TodoPriority / TodoItem all stripped; = raw String + Int + @Model everywhere. toDomain helpers deleted. |

## Final A1g attempt (rolled back)

Tried the actual mv of all 38 files to `Sources/WenshuData/`, mark all
top-level types `public`, add the local SPM package declaration, wire
up root `Package.swift`. Build failed with these remaining app-domain
leaks (not isolated by A1 probe 1-8 work):

1. `WSBookmarkRepository.add(_:Bookmark)` — write API used `Bookmark`
   domain type. Removed in final attempt (changed to raw `id/title/docID`
   fields), but the corresponding caller code (`BookmarkOps.swift`,
   `ArchivistStorage.swift`) was not yet adapted (= caller now passes
   `Bookmark` to a function that takes 3 separate fields). This is a
   caller-side adapter that needs its own sub-ticket.

2. `WSMemoryRepository.add(userId:content:) throws -> Memory` —
   write API used `Memory` domain type. Removed in final attempt
   (changed to return `WSMemory` = raw @Model), but caller code
   (`MemoryManager.swift`, `WSMemoryProvider.swift`, `MemoryAdapter.swift`)
   was not yet adapted to consume the new return type.

3. `WSBookmarkRepository` Spotlight bootstrap (`CSSearchableIndexSearch.shared.index/remove`)
   inside `add` and `remove` is app-side infrastructure. Final attempt
   stripped these out, but caller-side Spotlight bootstrap must now be
   re-added at the BookmarkOps / ArchivistStorage call sites.

4. `WSChatRepository` has 3 business-logic functions (= `summarizeIfNeeded`,
   `loadSubAgentRuns`, `recordSubAgentRun`) that the data layer should
   not own (= LLM call via WenshuVerifier, SubAgentRun domain construction).
   These should be relocated to a `ChatStorageOps` or `ConversationOps`
   app-side file before A1g can land.

5. `WSBookmarkRepository.add` write API change + `WSTodoRepository.add`
   return type change + `WSKanbanRepository.add` parameter type change
   = a wave of caller-side adapter changes that need their own atomic
   sub-tickets (= Q112 = 1 commit per ticket, = 6-10 more sub-tickets
   to fully decouple the boundary).

## Revised plan

| # | Scope | LOC estimate | Risk |
|---|-------|--------------|------|
| **A1g.1** | relocate 3 WSChatRepository business-logic functions to app-side `ConversationOps` (= summarizeIfNeeded, loadSubAgentRuns, recordSubAgentRun) | ~150 LOC | low (= pure move + delegate calls) |
| **A1g.2** | caller-side adapter:  BookmarkOps + ArchivistStorage + MemoryManager + WSMemoryProvider + MemoryAdapter for new raw-field write APIs | ~300 LOC | medium (= many call sites) |
| **A1g.3** | caller-side adapter: KanbanTools + SubAgentProgressView + TodoStoreTool for new raw-field write APIs | ~250 LOC | medium |
| **A1g.4** | `Sources/WenshuData/` mv 38 files + `public` modifier cascade + `import WenshuData` in 30+ call sites | ~500 LOC churn | high (= each access modifier addition risks cascade failures) |
| A1g.5 | delete `Sources/WenshuApp/Persistence/` (= empty after A1g.4) | trivial | 0 |

Per AGENTS.md §1.10 (= 1 ticket = 1 commit): each row above splits to
1 commit. A1g = at least 5 sequential commits (= the wave of caller-side
adapter work is the bottleneck).

## Value delivered (= 8 boundary commits)

The 8 boundary probes are independently valuable. They:
- establish the Apple-canonical write-domain-in/read-@Model-out pattern
- fix the Swift 6 strict-concurrency `Sendable` boundary issues that
  would have surfaced during any future WenshuData extraction
- give every future contributor a reference for how to write a
  Repository that survives a future refactor (= the WenshuData pattern)

When a future ticket picks up A1g.1-A1g.5, the work is purely
mechanical (= the boundary is already understood and proven = no more
discovery probes needed).

## References

- AGENTS.md §6.4 (Apple Backyard Birds target structure)
- AGENTS.md §6.5 (file suffix naming rules)
- persistence-boundary-catalog.md (initial A1a probe)
- wenshu-swift-standards.md §6 (SwiftData canonical rules)
- Backyard Birds sample (apple/sample-backyard-birds)
