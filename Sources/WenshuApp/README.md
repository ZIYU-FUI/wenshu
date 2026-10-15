# WenshuApp Package Structure

This document describes the current feature-first directory
layout of the `WenshuApp` Swift package. (See ADR-0018 for
the A4 arc plan that introduced this structure.)

## Top-level layout

```
Sources/WenshuApp/
├── App/                  (= main app entry: AppRootScene /
│                          WenshuAppDelegate)
├── App.swift             (= top-level @main)
├── DesignTokens.swift    (= v3.0 design system tokens)
├── Features/             (= feature-first directories)
│   ├── Chat/            (A4.1 = 31 files = the chat surface)
│   ├── Editor/          (A4.2 = 35 files = the editor surface)
│   ├── Library/         (A4.3 = 56 files = books / sidebar / references)
│   ├── Agent/           (A4.4 = 125 files = LLM / tools / sub-agents)
│   ├── Kanban/          (A4.5 = 7 files = kanban tickets)
│   └── Outline/         (A4.6 = 2 files = outline panel)
├── Shared/              (= cross-cutting code, A4.7 = 12 files)
├── Core/                (= cross-cutting domain / business logic)
├── UI/                  (= cross-cutting UI primitives + view shells)
├── Views/               (= screen-level views that span multiple features)
├── State/               (= @MainActor stores / view-models / state machines)
├── Services/            (= cross-cutting services / bridges / adapters)
├── Settings/            (= Settings feature = configures all other features)
└── Resources/           (= assets, .lproj, .xcstrings)
```

## Per-feature structure

Each `Features/<X>/` directory follows the Backyard Birds 1:1
pattern with internal organization:

```
Features/<X>/
├── Model/         (= domain types / value types / DTOs)
├── View/          (= SwiftUI views + sub-components)
├── Store/         (= @MainActor stores / view-models)
└── Service/       (= Repository bridges / service protocols /
                     cross-feature adapters)
```

The "out of scope" directories (= Core/ UI/ Views/ State/
Services/ Settings/) still contain code that has not been
classified into a feature yet (= the A4.7 + A4.8 ticket
documented this). Future arcs will gradually move these into
either Features/ or Shared/.

## Per-file naming

  - All types in WenshuApp use the prefix-less naming
    convention (e.g. `Book`, `EditorView`, `WenshuConductor`)
  - Only types in `WenshuData` (= the data layer package)
    use the `WS` prefix (e.g. `WSBook`, `WSBookmark`)
  - Domain enums in WenshuApp typically don't have a prefix
    (e.g. `KanbanStatus`, `TodoStatus`, `TodoPriority`)
  - Raw value String enums in `WenshuData` are typically
    named without prefix (e.g. `status`, `priority`)

## Cross-feature imports

Features import each other via Swift module-level imports
(= `WenshuData` for the data layer; = `WenshuApp` for
features within the same app). There are no separate
`Package.swift` targets per feature; = the entire `WenshuApp`
target is one module (= cross-feature calls are direct).

When a feature imports another feature:
  - `Features/Chat/Model/ChatMessage` can import
    `Features/Library/Model/Book` (because Chat needs Book
    for the chat-by-book context)
  - Cross-feature use is encouraged; = the per-feature
    directory just helps reasoning about ownership and
    locality

## Build target

WenshuApp is a single SwiftPM target (= `name: "WenshuApp"`).
It depends on:
  - `WenshuData` (= local SPM package; = A1g.4 data layer)
  - `ViewInspector` (= SwiftUI view test framework)
  - `SnapshotTesting` (= visual regression test framework)
  - `MarkdownEngineLatex` (= LaTeX rendering)

The `WenshuApp` target produces the `Wenshu.app` macOS
application.

## Tests

Tests are in `Tests/WenshuAppTests/` (= 1-to-1 with the
WenshuApp source). The test target is `WenshuAppTests` and
depends on `WenshuApp` (via `@testable import`) +
`WenshuData` + the test frameworks.

Per-feature test files are organized by feature:
  - `Tests/WenshuAppTests/Persistence/` = data layer tests
  - `Tests/WenshuAppTests/Agent/` = Agent feature tests
  - `Tests/WenshuAppTests/Chat/` = Chat feature tests
  - etc.

(A future A4 arc will reorganize the tests directory to
match the feature-first source layout.)
