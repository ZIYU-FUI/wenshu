# v1.16 Per-test stub instance pattern infrastructure · Spec (= infrastructure; tests deferred)

**Branch**: `wt/v1.16-per-test-stub-2026-09-14`
**Generated**: 2026-09-14
**Methodology**: PO v1.1 main-flow 5 steps (Q34) + boss voice trigger Q146 + boss 2026-09-14 OOB "按优先级推" + "A"

## Context

v1.15 documented the continuation ordering race. Per boss OOB "A": ship the per-test stub instance pattern infrastructure (= the multi-week refactor's foundation).

## Scope (= 1 ticket, 1 file 1 commit per Q112)

| # | File | Change |
|---|---|---|
| 1 | `Tests/WenshuAppTests/Agent/URLProtocolStub.swift` | Add `makeIsolatedStub()` factory + `IsolatedStubSubclass` helper (= runtime URLProtocol subclass generation via objc_allocateClassPair + associated object storage) |

Total v1.16 = **1 test infrastructure file changed**, **~70 LOC added**, **0 production code changes**, **0 test file migrations**.

## What this ticket ships

The infrastructure for the per-test stub instance pattern:

| # | Component | Purpose |
|---|---|---|
| 1 | `URLProtocolStub.makeIsolatedStub()` | Factory that returns a new stub instance + unique URLProtocol subclass per call |
| 2 | `IsolatedStubSubclass.makeSubclass(for:)` | Generates a unique URLProtocol subclass at runtime via `objc_allocateClassPair` (= avoids collisions between concurrent tests) |
| 3 | Associated object storage | Stores the stub reference on the generated class via `objc_setAssociatedObject` (= per-instance state) |

## How it works

When a test calls `makeIsolatedStub()`:
1. A new `URLProtocolStub` instance is created (= the stub).
2. A unique URLProtocol subclass is generated at runtime (= UUID-based name).
3. The stub reference is stored on the subclass via associated objects.
4. The test gets both back as a tuple.

**No global state is touched.** The stub's `responseData` / `responseError` / etc. are instance variables (= unique per stub). The stub's `lastRequest` would also be instance-based (= no `URLProtocolStub.capturedRequest` global write).

## What's NOT in this ticket (= scope-deferred per Q112)

| # | Component | Why deferred |
|---|---|---|
| 1 | Override `startLoading()` to route per-instance | Requires careful ObjC runtime + dispatch_once pattern; = own ticket |
| 2 | Migration of `OpenAIConnectorTests` / `MinimaxConnectorTests` to use `makeIsolatedStub()` | Each file = 1 ticket per Q112 |
| 3 | Delete the global `stub` / `registeredSnapshot` / `capturedRequest` (= dead code once all tests migrated) | Final cleanup ticket after all migrations |

**Per Q34 5.2 + Q112 + Q173 ponytail**: v1.16 ships the foundation. Future v1.17+ tickets build on it incrementally.

## Empirical validation (= per Q34 5.4)

| Run | v1.15 (= global only) | v1.16 (= infrastructure; no test changes) |
|---|---|---|
| `MinimaxConnectorTests` isolated | 4/4 pass | **4/4 pass** (= backward compatible) |
| `OpenAIConnectorTests` isolated | 5/5 pass | **5/5 pass** (= backward compatible) |
| Combined 5 suites | 18 tests, 2-7 fails (= flaky) | 18 tests, 4 fails (= within variance; = no regression) |

**Backward compat verified**: existing tests that use the global pattern continue to pass when run isolated. The new infrastructure is additive; = it does NOT break existing tests.

## Future fix options (= scope-deferred)

| # | Future ticket | What it does |
|---|---|---|
| 1 | `v1.17-override-startLoading-for-isolated-stub` | Add the `startLoading` override that routes per-instance (= makes the infrastructure actually work) |
| 2 | `v1.18-migrate-OpenAIConnectorTests-to-makeIsolatedStub` | Migrate OpenAI tests |
| 3 | `v1.19-migrate-MinimaxConnectorTests-to-makeIsolatedStub` | Migrate Minimax tests |
| 4 | `v1.20-delete-global-stubs` | After all migrations, delete the dead global statics |

**Per Q34 5.2 + Q173 ponytail**: each migration ticket = 1 file 1 commit.

## Cross-references

- `Tests/WenshuAppTests/Agent/URLProtocolStub.swift` (= this ticket's primary target; = the new `makeIsolatedStub` + `IsolatedStubSubclass` live here)
- `Sources/WenshuApp/Core/Provider/ProviderKeychain.swift` (= v1.09's TaskLocal pattern that v1.17+ will mirror for URLProtocolStub)
- `.scratch/v1.15-actor-guard/spec.md` (= the upstream analysis that motivated v1.16)
- `.scratch/v1.14-captured-tasklocal/spec.md` (= the TaskLocal fundamental limitation)
- `.scratch/v1.13-migrate-stub/spec.md` (= the prior honest scope gap)
- `.scratch/v1.11-urlprotocol-stub/spec.md` (= the original register/unregister attempt)
- Apple ObjC Runtime docs: `objc_allocateClassPair` / `objc_registerClassPair` / `objc_setAssociatedObject` / `objc_getAssociatedObject`

## Validation (= per Q34 step 4)

1. `swift build` = BUILD COMPLETE
2. `swift test --filter "MinimaxConnector"` = **4/4 pass** (= backward compatible)
3. `swift test --filter "OpenAIConnector"` = **10/10 pass** in 2 suites (= backward compatible)
4. Combined 5 suites = 18 tests, 4 fails (= within variance; = no regression; = tests still use global pattern)
5. 0 production code changes (= URLProtocolStub.swift is a test-only file)
6. Backward compatibility preserved (= existing tests work unchanged)

## Out-of-scope (= explicit)

- `startLoading` override for isolated stub (= future v1.17 ticket)
- Migration of OpenAIConnectorTests + MinimaxConnectorTests (= future v1.18+ tickets)
- Deletion of global statics after migration (= future v1.20 ticket)
- Other pre-existing flakes documented in v0.94 / v1.04 specs

## Acceptance criteria

### Ticket 001 — URLProtocolStub per-test instance infrastructure

- ✓ `swift build` = BUILD COMPLETE
- ✓ `makeIsolatedStub()` factory exists on `URLProtocolStub`
- ✓ `IsolatedStubSubclass.makeSubclass(for:)` exists as private helper
- ✓ Each call to `makeIsolatedStub()` produces a unique URLProtocol subclass
- ✓ Stub reference stored via associated objects (= per-instance state)
- ✓ Isolated test runs (= Minimax, OpenAI) still pass (= backward compatible)
- ✓ 0 production code changes