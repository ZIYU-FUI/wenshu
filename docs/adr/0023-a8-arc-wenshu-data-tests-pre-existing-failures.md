# ADR-0023: A8 Arc — WenshuDataTests Pre-existing Failure Fixes

## Status

Accepted. Implemented in A8 (= 7 files / +31 -12).

## Context

The A7 arc split the WenshuData tests into their
own test target. This exposed 7 pre-existing test
issues that were hidden when the tests lived in
WenshuAppTests:

  1. **WSTodoRepository.list() sort direction bug**
     (= production bug): the sort was descending
     by priority (= highest numeric first = "low
     priority" first per the convention that 0 is
     highest). The test expected ascending (= 0
     first = urgent first).

  2. **WSTodoRepository.add() default priority
     mismatch** (= production bug): the add() default
     was 1 but WSTodo.init() default was 5. The
     canonical HermesTodo.TodoPriority.medium = 1.

  3. **WSManifest.init() createdAt + updatedAt
     precision** (= production bug): init() called
     `Date()` twice, producing two values that differ
     by a few nanoseconds. The test expected
     `createdAt == updatedAt`.

  4. **WSMemoryRepositoryTests update() assertion
     bug** (= test bug): the test compared
     `fetched.updatedAt > added.updatedAt`, but
     SwiftData's reference tracking means
     `added`, the in-memory model in `update()`,
     and the fetched model are all the same
     @Model instance. So both were the new
     value (after update), not old vs. new.

  5. **EmptySchemaCompletionTests field count
     filter** (= test bug): the test only counted
     lines starting with `var `, `let `, or
     `@Attribute` — missed `public var`, `public
     let`, `public @Attribute`, `private var`,
     `private let`.

  6. **EmptySchemaCompletionTests hasModelAttr
     pattern** (= test bug): the test only matched
     `@Model\nfinal class Name` — missed
     `@Model public final class Name`.

  7. **WSTodoRepositoryTests + WSTodoTests
     default priority assertion** (= test bug):
     after the production default priority
     alignment, both tests needed to expect
     `priority == 1` (= HermesTodo.medium).

## Decision

A8 = 7 files / +31 -12 lines.

  - 4 production fixes (= semantic bugs the tests
    caught: WSTodoRepository sort direction, default
    priority alignment, WSManifest Date precision,
    WSMemory identity tracking documented).
  - 3 test fixes (= test code bugs: field count
    filter, hasModelAttr pattern, default priority
    expectations).

## Implementation

```
0214b13d7  fix(wenshu): A8 = WenshuDataTests pre-existing test failure fixes
```

## Verification

  - `swift test` (in `Sources/WenshuData/`):
    **142 tests in 36 suites, 0 issues** (= 100% pass)
  - `swift test` (in main `wenshu/`):
    **368 XCTest tests pass, 0 fail** (= no regression
    on the WenshuApp test target)
  - `swift build` (in main `wenshu/`): clean (= 1.13s)
  - Total commits on main: 184 (now 185 after this
    arc)

## Future Work (= A8.x arcs)

  - The WenshuApp-side domain enums (KanbanStatus /
    TodoStatus / TodoPriority / HermesTodoStatus)
    should be moved to WenshuData (= they are
    persisted to @Model rows; = the right
    architectural place is the data layer, not the
    app layer). This is a deferred refactor from
    the A1g arc.
  - The pre-existing test that requires WSManifest
    init's `createdAt == updatedAt` is preserved;
    but the underlying WSMemory/WSManifest date
    precision behavior should be documented in
    AGENTS.md.
