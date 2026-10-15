# ADR-0019: A5 Arc — Test Directory Feature-First Reorganization

## Status

Accepted. Implemented across 8 commits (A5 + A5.1 through A5.8).

## Context

The A4 arc moved the production code from a layer-based
organization (= Core/ + UI/ + Views/ + State/ + Services/
+ Settings/) to a feature-first organization (= Features/
+ Shared/ + App/ + Resources/). After A4, the production
code's top-level structure is purely:

  Sources/WenshuApp/
  ├── App/
  ├── Features/  (Agent, Chat, Editor, Kanban, Library,
  │              Outline, Settings, Shared)
  ├── Shared/  (Foundation, State, UI)
  └── Resources/

The test code (= Tests/WenshuAppTests/) was still organized
in the OLD layer-based structure (= Core/ + UI/ + Views/ +
State/ + Services/ + Settings/ + 30+ other top-level
sub-dirs). The test code mirrored the old production
organization, = the test code's directory structure did
not reflect the production code's feature organization.

This was a code governance problem:
  1. AI / new contributors had to learn TWO different
     directory organizations (= production = feature-first,
     test = layer-first).
  2. The "which test covers which production file" question
     required a 2-step lookup (= the test dir name like
     `Core/Agent/` did not match the production dir name
     `Features/Agent/Model/`).
  3. The test directory grew to 178+ files across 30+
     sub-dirs (= hard to navigate).

## Decision

Mirror the production code's feature-first organization
in the test code:

  Tests/WenshuAppTests/
  ├── Agent/  (Background, Composer, Connector, Context,
  │            Conversation, Cron, Goals, Import, Kanban,
  │            Librarian, LongForm, Memory, PortedFromHermes,
  │            Progress, Provider, Runtime, Service,
  │            Specialized, Todo, Tool, Tools, View, Web)
  ├── App/  (AppTests, AppRootScene, DesignTokens,
  │          UnusedSpmDepRemoval, UntestedFunctions,
  │          UserFacingErrorI18n,
  │          FileSystemLibraryStoreForceUnwrapFix,
  │          WenshuAppDelegateSubAgentDrainLoop,
  │          WenshuVerifier)
  ├── Chat/  (Model, View)
  ├── Core/  (cross-cutting: Integration, State)
  ├── E2E/  (live e2e: 8 files)
  ├── Editor/  (Canvas, Model, View, WordCount)
  ├── Integration/
  ├── Kanban/
  ├── Library/  (Graph, LinkGraph, Model, Search, Service,
  │              Templates, View)
  ├── Outline/
  ├── Resources/  (localization)
  ├── Settings/
  ├── Shared/  (Backup, Bases, Onboarding, State, UI)
  ├── UI/  (DesignSystem, EmptyState, Polish, StatusBar)
  ├── WenshuData/  (Container, TypedID, WSBook, WSTodo,
  │                 WSMemory, ...; Repositories/ for
  │                 WSBookmarkRepository etc.)
  └── Workspace/

The cross-cutting test sub-dirs that were kept at
top-level (vs. moved to features):

  - Core/Integration (2) — cross-feature integration tests
  - Core/State (1) — cross-cutting state tests
  - E2E/ (8) — live e2e tests
  - Integration/ (1) — cross-feature integration
  - Resources/ — localization
  - UI/DesignSystem — wenshu iron rules compliance tests
  - UI/EmptyState, UI/Polish, UI/StatusBar — cross-cutting

## Implementation

A5 + A5.1 through A5.8 = 8 commits / 318 file moves / net
0 lines.

```
f6b448937  A5   = Tests/Core/ sub-dirs → Features/* (66)
dfffb71f4  A5.1 = Tests/Views/ sub-dirs → Features/* (71)
6931b5ea4  A5.2 = Tests/UI/ + Services/ + Settings/ + State/ (52)
794947704  A5.3 = Tests/ top-level files → features (22)
0ddc5f893  A5.4 = Tests/Core/Agent/ sub-dirs → Agent/ (31)
4a03fce94  A5.5 = Tests/Persistence → WenshuData/ + Storage → Library/Service/ (49)
194a9fc50  A5.6 = Tests/UI/ top-level → UI/DesignSystem + features (27)
37e09cc75  A5.7 = remaining Tests/ dirs consolidated (32)
858b0042a  A5.8 = final Tests/ consolidation (88)
```

After A5: the test code's directory structure mirrors the
production code's directory structure 1:1. A test for a
production file at `Sources/WenshuApp/Features/Agent/
Service/X.swift` lives at `Tests/WenshuAppTests/Agent/
Service/XTests.swift` (= same `Features/Agent/Service/`
prefix).

## Consequences

Positive:
  1. AI / new contributors learn ONE directory organization
     (= feature-first) for both production and test code.
  2. The "which test covers which production file" question
     is answered by the directory path (= same prefix).
  3. The test code is now organized by feature (= each
     feature's tests are co-located under `Agent/`,
     `Chat/`, `Editor/`, `Kanban/`, `Library/`, `Outline/`,
     `Settings/`, `WenshuData/`, `Workspace/`).

Negative:
  1. Some long file paths (= `Tests/Agent/View/.../...`).
  2. The WenshuData/ sub-dir is a hint that those tests
     should ideally live in a separate WenshuDataTests
     target (= requires Package.swift changes — out of
     scope for A5).

## Out of Scope (= future arcs)

  - Split WenshuAppTests into WenshuDataTests + WenshuAppTests
    (= would let us properly test the WenshuData layer in
    isolation, but requires Package.swift changes).
  - Move tests that are still in the WenshuApp production
    code's `App/` or `Shared/` (= cross-cutting tests that
    should mirror those locations).
