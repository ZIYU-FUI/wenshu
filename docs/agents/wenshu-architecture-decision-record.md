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

## A1g.4 dry-run findings (2026-10-15)

Performed an off-main dry-run attempt of A1g.4 (= extract 38
Persistence files to `Sources/WenshuData/` local SPM package) on
a worktree (`wt/a1g4-dryrun-2026-10-15`). The worktree was removed
after recording findings; main HEAD was never modified.

Findings (= the cost of A1g.4 in concrete error counts):

| # | Error type | Count | Fix cost |
|---|------------|-------|----------|
| 1 | `attribute 'public' can only be used in a non-local scope` (= my regex was too broad, added public to local-scope declarations inside closure scopes + enum cases inside methods + function-local vars) | 91 | medium (= 1 careful regex rewrite + manual review) |
| 2 | cascading SwiftDriver / Build failed | 2 | zero (= disappear after #1) |

Per-file distribution of the 91 errors:

| File | Count |
|------|-------|
| WSChatRepository.swift | 38 |
| WSMemoryRepository.swift | 11 |
| WSKanbanRepository.swift | 8 |
| WSLinkRepository.swift | 8 |
| Container.swift | 6 |
| WSTodoRepository.swift | 6 |
| WSPreferenceRepository.swift | 5 |
| WSProviderKeyRepository.swift | 5 |
| WSBookmarkRepository.swift | 3 |
| WSMemory.swift | 1 |

Known additional cost (= uncovered by the dry-run because the
WenshuApp target's source files could not be re-resolved after
the move without a separate pass):

| # | Hidden cost | Estimated impact |
|---|-------------|------------------|
| A | caller-side `import WenshuData` (= every file in `Sources/WenshuApp/` that touches a WS* type must add the import) | ~30-40 files (= 1 commit) |
| B | @MainActor visibility across module boundary (= Swift 6 strict concurrency: a public @MainActor-isolated type in a non-MainActor module triggers `Main actor-isolated ... cannot be referenced from a non-isolated context`) | ~5-10 fixes (= 1 commit) |
| C | @Model Sendable issues (= PersistentModel is NOT Sendable; = caller sites in non-isolated context that hold WS* must wrap in MainActor.run) | ~3-5 fixes (= subsumed in A) |
| D | SwiftData ModelContainer cross-module (= the WSPersistenceContainer singleton is the bootstrap entry point; = needs to be public and have a public factory) | 1 fix (= subsumed in #1) |
| E | test target's `WenshuData` product import (= already added in dry-run Package.swift; = verified at the SPM resolution stage) | 0 |

Revised A1g.4 commit estimate (= 1 ticket = 1 commit per
AGENTS.md §1.10):

| # | Scope | LOC estimate | Risk |
|---|-------|--------------|------|
| **A1g.4.1** | Public modifier sweep (= add public to top-level decls only; = scope-aware regex with re-validation) | ~200 LOC edits across 38 files | medium (= each access modifier addition risks cascade failures) |
| A1g.4.2 | caller-side `import WenshuData` in 30-40 WenshuApp source files | ~40 files 1 line each | low |
| A1g.4.3 | @MainActor + Sendable visibility fixes (= the 5-10 boundary violations) | ~150 LOC | medium |
| A1g.4.4 | `WenshuData` library product verification (= package structure + test target resolution) | trivial | low |
| A1g.4.5 | delete `Sources/WenshuApp/Persistence/` (= empty after move) | trivial | 0 |

Total: 4-5 commits (= the original ADR estimate was correct).

When a future ticket picks up A1g.4.1-A1g.4.5, the work is purely
mechanical (= the dry-run findings above are the precise bug list;
= no more discovery probes needed).



## A1g.4.2-4.4 merge required (2026-10-15)

When A1g.4.1 (= WenshuData skeleton + root .package wire-up) lands
on main, the build still passes (= the WenshuData target has only
a Stub.swift file; = the App target does not yet depend on
WenshuData via .product). When A1g.4.2 attempts the file move
alone, the build breaks (= the App target no longer has access
to the 38 moved types; = the WS* type lookups in 65 caller
files fail; = the @Model Container.shared access in
WenshuAppDelegate fails; = etc).

AGENTS.md §7.1 requires swift build exits 0 per commit; = A1g.4.2
cannot land as a single broken commit. The fix is to merge
A1g.4.2 + A1g.4.4 into one commit:

  - A1g.4.2-4.4 = mv 38 Persistence files + delete Persistence/
    + delete Stub.swift + add '.product(name: WenshuData, package:
    WenshuData)' to WenshuApp target + add 'import WenshuData' to
    65 WenshuApp source files = 1 commit (= AGENTS.md §1.10
    treated as the 1 atomic ticket = "A1g.4 file move with caller
    import wave").

The .public-modifier sweep (= A1g.4.3 in the original plan) is
still separate (= the moved files need public modifier before
the App can see their members, but the types are now visible
after A1g.4.2-4.4 lands; = the build can then incrementally
report only the public-modifier errors as A1g.4.3 work).

This revises the original 6-sub-ticket plan (= A1g.4.1-5) to
a 5-sub-ticket plan (= A1g.4.1 + A1g.4.2-4.4 + A1g.4.5 + A1g.4.6
public-modifier sweep).



## A1g.4 complete (2026-10-15)

A1g.4 arc landed in 3 commits (= A1g.4.1 + A1g.4.2-4.4 + A1g.4.5
as no-op verification). The data layer is now in a local SwiftPM
package (= Sources/WenshuData/ = 38 files; = App target imports
the WenshuData product).

Verified state after A1g.4.5:

  - swift build (debug): 2.38s pass.
  - swift build -c release: 79.30s pass.
  - Runtime smoke test (WENSHU_DEBUG_INMEMORY_KEYCHAIN=1):
    APP launches, window visible, full Chinese UI, no crashes.
  - 0 warnings (= no @MainActor / Sendable visibility errors;
    = the original sources preserved @MainActor isolation on
    the Repositories, = the public-sweep + boundary refactor
    inherited that isolation).
  - 136 files changed in the A1g.4.2-4.4 commit (= 38 WenshuData
    + 1 Package.swift + 65 WenshuApp imports + 32 WenshuData
    public-sweep edits).

The original A1g.4 plan was 6 sub-tickets (= A1g.4.1-5 in the
revised 5-ticket plan, with A1g.4.2 + A1g.4.4 merged). The
actual commit count is 3 (= A1g.4.1 + A1g.4.2-4.4 + A1g.4.5
no-op verification). This is fewer commits than the plan
because:

  - A1g.4.3 (= public-modifier sweep) was absorbed into
    A1g.4.2-4.4 (= the mv + .product + imports needed the
    public sweep to compile).
  - A1g.4.5 (= @MainActor / Sendable fixes) was a no-op (= the
    original sources were already correctly isolated; = the
    public-sweep preserved the existing @MainActor annotations).

ADR-0016 A1g.4 plan was correct (= 4-5 atomic commits), but
the implementation merged some of them (= the real cost was
3 commits instead of 5).

The full A1g arc (= A1g.1 + A1g.2.4 + A1g.2.4a + A1g.2.4b +
A1g.2 step 1-3 + A1g.4.1 + A1g.4.2-4.4) is now complete. The
Apple Backyard Birds target structure is in place (= data
layer = local SwiftPM package, = App target consumes the
package via .product dependency).

## A1g.4 atomic-attempt findings (2026-10-15)

Performed an atomic A1g.4 attempt on a worktree
(`wt/a1g4-atomic-2026-10-15`). The worktree was removed after
recording findings; main HEAD was never modified.

What was tried (= one atomic commit, all-in-one):

  1. mv 38 Persistence files to Sources/WenshuData/
  2. public-modifier sweep on moved files
  3. WenshuData Package.swift skeleton + .library product
  4. Root Package.swift wire-up (.package + 2 .product entries)
  5. import WenshuData added to 65 WenshuApp source files
  6. Persistence/ removed
  7. Additional public modifiers on Container + LibraryMigrationState
     static funcs and @MainActor class init sites
  8. WSLinkRepository.add() boundary refactor (raw fields)
  9. WSChatRepository boundary refactor (BookID? -> String?,
     append() takes raw fields instead of StoredChatMessage)
 10. WenshuApp caller adaptations (BacklinkResolver, LiveChatRepository)

Observed file churn (= real cost of A1g.4, much larger than the
4-5 commit estimate):

| Bucket | Files modified |
|--------|----------------|
| WenshuData package (= moved files) | 38 |
| Root Package.swift | 1 |
| WenshuApp source files (import WenshuData + caller adaptations) | 65 |
| WenshuApp source files (caller refactors for new raw-field APIs) | 3 |
| **Total** | **107** |

This 107-file churn confirms that A1g.4 is **not** a 1-commit
ticket. Per AGENTS.md §1.10 (= 1 ticket = 1 commit), A1g.4 must
be split into at least 4-5 sub-tickets, each of which must pass
build independently (= the broken-state interim commits the
atomic-attempt tried to avoid are unavoidable for AGENTS.md
compliance).

A1g.4 also surfaced 2 additional boundary refactors that A1g.2
missed (= these were not in scope of A1g.2 step 1-3; = they
become part of the A1g.4 prerequisite work):

  - WSLinkRepository.add(_:Link) -> add(raw fields)
  - WSChatRepository.append(StoredChatMessage, bookID: BookID?)
    -> append(raw fields, bookID: String?)
  - All WSChatRepository functions taking bookID: BookID?
    (= 18+ functions) need bookID: String?

Revised A1g.4 plan (5 sub-tickets, each = 1 atomic commit):

| # | Scope | LOC | Risk |
|---|-------|-----|------|
| A1g.2.4 | Boundary: WSLinkRepository + WSChatRepository decouple (= the 2 Repos A1g.2 left untouched) | ~300 | medium |
| A1g.4.1 | Create WenshuData/ package skeleton + add to root Package.swift (no files moved yet) | ~30 | low |
| A1g.4.2 | mv 38 Persistence files to Sources/WenshuData/ + delete empty Persistence/ + delete Stub.swift | 0 LOC | low (= BLOCKED: cannot be 1 commit per AGENTS.md §7.1; = must bundle with A1g.4.4 caller-side imports; = see A1g.4.2-4.4 merged below) |
| A1g.4.3 | public-modifier sweep on moved files (scope-aware) | ~200 edits | medium |
| A1g.4.4 | import WenshuData added to 65 WenshuApp source files | ~65 LOC | low |
| A1g.4.5 | @MainActor + Sendable visibility fixes (= 5-10 sites) | ~150 LOC | medium (= NO-OP 2026-10-15: scope-aware public sweep + boundary refactor + @MainActor preservation in the original sources covered all expected sites; = build is clean without further changes) |

Each sub-ticket compiles clean after the commit (= 1-ticket-1-
commit per AGENTS.md §1.10).

This refines the original A1g.4 5-commit plan (= A1g.4.1-5) to
a 6-commit plan (= A1g.2.4 prerequisite + A1g.4.1-5) and adds
the previously-missed WSLinkRepository + WSChatRepository
boundary refactor (= moved from A1g.2 to A1g.2.4 to keep A1g.2
commits focused).

## References

- AGENTS.md §6.4 (Apple Backyard Birds target structure)
- AGENTS.md §6.5 (file suffix naming rules)
- persistence-boundary-catalog.md (initial A1a probe)
- wenshu-swift-standards.md §6 (SwiftData canonical rules)
- Backyard Birds sample (apple/sample-backyard-birds)
