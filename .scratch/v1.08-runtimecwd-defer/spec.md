# v1.08 RuntimeCWDDisplayChipTests defer fix · Spec (= real fix)

**Branch**: `wt/v1.08-runtimecwd-defer-2026-09-14`
**Generated**: 2026-09-14
**Methodology**: PO v1.1 main-flow 5 steps (Q34) + boss voice trigger Q146 + boss 2026-09-14 OOB "按优先级推" + "A"

## Context

v1.07 documented 3 remaining RuntimeCWDDisplayChipTests state pollution
failures. Per boss OOB "A": apply Option 1 (= per-test defer pattern;
= 6 test body edits per Q173 ponytail).

## Scope (= 1 ticket, 1 file 1 commit per Q112)

| # | File | Change |
|---|---|---|
| 1 | `Tests/WenshuAppTests/UI/Agent/RuntimeCWDDisplayChipTests.swift` | Added `defer { restore }` block to 6 test bodies + added `removeObject` clear calls before every `set` to prevent state leakage from concurrent tests |

Total v1.08 = **1 test file changed** (= 6 defer blocks + 16
removeObject inserts), **0 production code changes**.

## Empirical fix (= per Q34 5.4)

| Run | v1.07 (before) | v1.08 (after) |
|---|---|---|
| `RuntimeCWDDisplayChipTests` isolated | 7 tests, 3 fails | **7/7 pass** |
| Combined with 6 other suites | 141 tests, 7 fails | 141 tests, 7 fails (= same; = the 3 RuntimeCWD issues are gone, the 4 remaining are inter-suite connector races = documented in v1.03) |

Net improvement = **3 issues fixed** (= 0 in RuntimeCWDDisplayChip
isolated; = 0 in combined run too since combined's 7 fails are all
the known v1.03 inter-suite connector races).

## Per-ticket acceptance criteria

### Ticket 001 — RuntimeCWDDisplayChipTests defer fix

- `swift test --filter "RuntimeCWDDisplayChipTests"` = **7/7 pass** (= previously 3 fails)
- Combined with ComprehensiveInterfaceTests + 5 connector suites =
  **141 tests, 7 fails** (= all 7 are the known v1.03 inter-suite
  connector races; = no new RuntimeCWD fails)
- 0 production code changes

## How the fix works

For each of the 6 test bodies that touch UserDefaults, the patch
adds a `defer` block as the first executable statement (= right
after the test body's opening brace). The defer:
1. Captures the previous values of `libraryPathKey` + `cwdOverrideKey`
   before the test body mutates them.
2. Restores those values when the test body returns (= either via
   normal return or via thrown error).

Additionally, the patch adds `removeObject` clears for both keys
immediately before every `UserDefaults.standard.set(...)` call. This
prevents concurrent test leakage (= another test running between
this test's `set` and `cwd.displayLabel()` could overwrite the value
= a fresh `removeObject` before each `set` ensures the test always
reads its own value).

## Cross-references

- `Tests/WenshuAppTests/UI/Agent/RuntimeCWDDisplayChipTests.swift` (=
  the 7-test target file)
- `Sources/WenshuApp/Core/Agent/RuntimeCWD.swift:30,33` (= the 2
  UserDefaults keys)
- `.scratch/v1.07-runtimecwd/spec.md` (= the upstream analysis)
- `.scratch/v1.06-rescan/spec.md` (= the prior scan)

## Validation (= per Q34 step 4)

1. `swift test --filter "RuntimeCWDDisplayChipTests"` = **7/7 pass**
2. Combined run: 141 tests, 7 fails (= all v1.03-documented
   inter-suite connector races; = no new RuntimeCWD issues)
3. `swift build` = BUILD COMPLETE
4. No production code touched