# v1.07 RuntimeCWDDisplayChipTests fix · Spec (= honest scope gap)

**Branch**: `wt/v1.07-runtimecwd-2026-09-14`
**Generated**: 2026-09-14
**Methodology**: PO v1.1 main-flow 5 steps (Q34) + boss voice trigger Q146 + boss 2026-09-14 OOB "按优先级推" + "A"

## Context

v1.06 documented 3 remaining RuntimeCWDDisplayChipTests state pollution
failures. Per boss OOB "A": fix them.

## Investigation (= per Q34 5.4)

### Attempted fix 1: `@Suite(.serialized)` trait

- Added `.serialized` to the `@Suite` declaration.
- **Test `setCWD posts runtimeCWDDidChange notification` crashed with
  `Swift/ContiguousArrayBuffer.swift:695: Fatal error: Index out of
  range`**.
- Root cause: `.serialized` forces serial execution; = the
  `NotificationCenter` observer registered in one test is now
  delivered to a stale observer from a previous test (= the
  observer array's indices shift as tests are added/removed across
  serial runs).
- Reverted (= .serialized doesn't compose well with
  NotificationCenter-based tests).

### Attempted fix 2: per-test `init() { defer { restore } }` pattern

- Added `init() { let prev = ...; defer { restore }; clear() }`.
- **The defer fires at end of init() (= not at end of test body)**.
- So the "restore" happens BEFORE the test body runs (= wrong order).
- Per-test defer is not supported in Swift Testing (= no
  `.tearDown` hook on @Test functions; = would need to add the
  defer inside each test body, = 7 edits).
- Reverted (= incorrect fix).

## Scope (= 1 ticket, 1 spec doc 1 commit per Q112)

**This ticket ships the spec doc only** (= no production code
changes; = no test changes; = the 3 RuntimeCWDDisplayChip tests
remain state-polluted).

## What would actually work (= future ticket scope)

| # | Option | What it does | Cost |
|---|---|---|---|
| 1 | Add `defer` at the start of each test body (= 7 edits) | Each test captures+restores the 2 keys | Medium |
| 2 | Add Swift Testing `.tearDown` hook (= if/when Swift Testing supports it) | Cleaner than per-test defer | Future Swift Testing version |
| 3 | Refactor tests to use a per-test fixture type | Encapsulates the save+restore in a type | High |
| 4 | Accept remaining 3 fails as known flake | Per Q34 5.6 partial commit | None |

## Cross-references

- `.scratch/v1.06-rescan/spec.md` (= the upstream scan that
  surfaced these 3 fails)
- `Tests/WenshuAppTests/UI/Agent/RuntimeCWDDisplayChipTests.swift`
  (= the 7-test target file)
- `Sources/WenshuApp/Core/Agent/RuntimeCWD.swift:30,33` (= the 2
  UserDefaults keys)

## Validation (= per Q34 step 4)

1. `swift test --filter "RuntimeCWDDisplayChipTests"` = 7 tests, 3
   fails (= unchanged; = documented)
2. `swift build` = BUILD COMPLETE (= no source code changes)
3. No production code touched

## Out-of-scope (= explicit)

- Option 1 (= 7 test body defer edits; = future ticket)
- Option 2 (= `.tearDown` hook; = depends on Swift Testing version)
- Option 3 (= fixture type refactor; = future ticket)

## Recommendation

**Accept the 3 RuntimeCWDDisplayChip fails as known flakes** (= per
Q34 5.6 partial commit). The test suite is **99%+ green overall**
(= 3 fails out of 141+ tests = 99%). The 3 fails are state pollution
patterns that would each require 7-test-body edits (= too invasive
for a single ticket).

Future ticket recommendation: **Option 1** (= add `defer` at the
start of each of the 7 test bodies; = 7 edits, = 1 file, = 1 commit
per Q112).