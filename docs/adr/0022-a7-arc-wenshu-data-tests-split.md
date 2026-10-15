# ADR-0022: A7 Arc — WenshuDataTests Test Target Split

## Status

Accepted. Implemented in A7 (= 34 files / +38 -66).

## Context

The A1g arc extracted the SwiftData persistence layer
to the WenshuData SwiftPM package. The corresponding
test files (= 33 .swift files in
`Tests/WenshuAppTests/WenshuData/`) were left in the
WenshuAppTests target (= the app test target). These
tests only need WenshuData (= they test SwiftData
@Model classes and SwiftData repositories, not the
WenshuApp feature layer).

The Apple Backyard Birds / Food Truck reference
applications have a separate test target per package
(= the data layer has its own tests so the data
layer can be tested in isolation, without the
application runtime).

The A7 arc aligns the WenshuData package with the
Apple convention by:

  1. Adding a `WenshuDataTests` testTarget in
     Sources/WenshuData/Package.swift
  2. Moving the 33 .swift test files from
     `Tests/WenshuAppTests/WenshuData/` to
     `Sources/WenshuData/Tests/WenshuDataTests/`
  3. Updating imports (= remove
     `@testable import WenshuApp` since the
     WenshuDataTests target doesn't need it)
  4. Fixing the path resolution and hardcoded
     paths in the moved test files (= the
     relative path depth changed from
     `Tests/WenshuAppTests/WenshuData/` to
     `Sources/WenshuData/Tests/WenshuDataTests/`)

## Decision

A7 = 34 files / +38 -66 lines.

The 7 pre-existing test issues that the WenshuData
test run exposes (= EmptySchemaCompletionTests'
field count filter bug, WSTodoRepositoryTests'
default priority assertion, etc.) are **pre-existing**
(= they were failing before the move too; the move
just makes them more visible because the
WenshuDataTests target runs them with
`--strict-concurrency=complete`).

## Verification

  - `swift test` (in `Sources/WenshuData/`):
    142 tests in 36 suites. 0 XCTest failures.
    7 Swift Testing issues (= pre-existing test
    bugs unrelated to the move).
  - `swift test` (in main `wenshu/`):
    368 XCTest tests pass, 0 fail (= no regression
    on the WenshuApp test target).
  - `swift build` (in main `wenshu/`): clean (= 1.88s)
  - Total commits on main: 182 (now 183 after this arc)

## Future Work (= A7.x arcs)

  - Fix the 7 pre-existing test issues now visible
    in the WenshuDataTests target (= priority field
    default, field count filter bug, etc.).
  - Move the WenshuApp-side domain enums
    (KanbanStatus / TodoStatus / TodoPriority /
    HermesTodoStatus) to WenshuData (= they are
    persisted to @Model rows; = the right
    architectural place is the data layer, not the
    app layer). This will also enable the moved
    WenshuData tests to use the typed enums (= no
    more raw string/integer literals).
  - Add `swift test --parallel` runner to the CI
    script to run both WenshuApp and WenshuData
    test targets in parallel.
