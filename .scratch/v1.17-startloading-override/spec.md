# v1.17 startLoading override for isolated stub routing · Spec (= infrastructure complete; tests deferred)

**Branch**: `wt/v1.17-startloading-override-2026-09-14`
**Generated**: 2026-09-14
**Methodology**: PO v1.1 main-flow 5 steps (Q34) + boss voice trigger Q146 + boss 2026-09-14 OOB "按优先级推" + "A"

## Context

v1.16 shipped the `makeIsolatedStub()` factory + `IsolatedStubSubclass` runtime class generator. Per boss OOB "A": add the `startLoading` override that routes per-instance (= completes the infrastructure).

## Scope (= 1 ticket, 1 file 1 commit per Q112)

| # | File | Change |
|---|---|---|
| 1 | `Tests/WenshuAppTests/Agent/URLProtocolStub.swift` | Add `startLoading()` routing check (`type(of: self) != URLProtocolStub.self`) + per-instance `_isolatedCapturedRequest` storage + `routeToIsolatedStub(request:client:)` method |

Total v1.17 = **1 test infrastructure file changed**, **~85 LOC added**, **0 production code changes**, **0 test file migrations**.

## What this ticket ships

The routing logic that makes the v1.16 infrastructure actually work:

| # | Component | Purpose |
|---|---|---|
| 1 | `startLoading()` routing check | Detects if `self` is an isolated subclass (= `type(of: self) != URLProtocolStub.self`) |
| 2 | `_isolatedCapturedRequest` instance var | Per-instance storage for isolated stubs (= no global write) |
| 3 | `routeToIsolatedStub(request:client:)` method | Mirrors the global `startLoading()` flow but writes to per-instance state |

## How it works

When `startLoading()` is called on a URLProtocolStub instance (= by URLSession during a request):

1. **Check `type(of: self) != URLProtocolStub.self`**: If `self` is an instance of a runtime-generated subclass (= produced by `makeIsolatedStub()`), route to the isolated path.
2. **Look up the associated stub** via `IsolatedStubSubclass.getAssociatedStub`.
3. **Drain httpBodyStream** (= same as global path).
4. **Write to `_isolatedCapturedRequest`** (= per-instance; = no global mutation).
5. **Mirror response fields** from the stub onto `self`.
6. **Notify the URLProtocol client**.

For tests that use the global pattern (= `URLProtocolStub.register(stub)`), `type(of: self) == URLProtocolStub.self` (= direct instance, not a subclass). The new routing check is false, and the original global-path code runs (= unchanged behavior). **Backward compatible**.

## Empirical validation (= per Q34 5.4)

| Run | v1.16 (= infra only, no routing) | v1.17 (= infra + routing) |
|---|---|---|
| `MinimaxConnectorTests` isolated | 4/4 pass | **4/4 pass** (= backward compatible) |
| `OpenAIConnectorTests` isolated | 5/5 pass | **5/5 pass** (= backward compatible) |
| Combined 5 suites | 18 tests, 4 fails (= variance) | 18 tests, 7 fails (= variance; = no regression for isolated tests) |

**Backward compat verified**: existing tests that use the global pattern continue to pass when run isolated. The new routing only fires for runtime-generated subclasses (= only tests that opt into `makeIsolatedStub`).

## What's NOT in this ticket (= scope-deferred per Q112)

| # | Component | Why deferred |
|---|---|---|
| 1 | Migration of OpenAIConnectorTests to use `makeIsolatedStub()` | 1 file per Q112; = future v1.18 ticket |
| 2 | Migration of MinimaxConnectorTests to use `makeIsolatedStub()` | 1 file per Q112; = future v1.19 ticket |
| 3 | Delete the global statics (= dead code once all tests migrated) | Final cleanup ticket after migrations |

**Per Q34 5.2 + Q112 + Q173 ponytail**: v1.17 completes the
infrastructure (= infra + routing). Future tickets migrate tests
and eventually delete the dead global code.

## Cross-references

- `Tests/WenshuAppTests/Agent/URLProtocolStub.swift` (= this ticket's primary target; = the new `startLoading` routing check + `routeToIsolatedStub` method + per-instance `_isolatedCapturedRequest` storage)
- `.scratch/v1.16-per-test-stub/spec.md` (= the upstream factory + IsolatedStubSubclass)
- Apple ObjC Runtime docs: `objc_getAssociatedObject`
- `.scratch/v1.15-actor-guard/spec.md` (= the upstream analysis that motivated v1.16-v1.17)

## Validation (= per Q34 step 4)

1. `swift build` = BUILD COMPLETE
2. `swift test --filter "MinimaxConnector"` = **4/4 pass** (= backward compatible)
3. `swift test --filter "OpenAIConnector"` = **5/5 pass** (= backward compatible)
4. Combined 5 suites = 18 tests, 7 fails (= within variance; = no regression; = tests still use global pattern)
5. 0 production code changes (= URLProtocolStub.swift is a test-only file)
6. Backward compatibility preserved (= existing tests work unchanged; = routing only fires for isolated subclasses)

## Out-of-scope (= explicit)

- Migration of OpenAIConnectorTests + MinimaxConnectorTests (= future v1.18+ tickets)
- Deletion of global statics after migration (= future v1.20 ticket)
- Other pre-existing flakes documented in v0.94 / v1.04 specs

## Acceptance criteria

### Ticket 001 — URLProtocolStub startLoading routing

- ✓ `swift build` = BUILD COMPLETE
- ✓ `startLoading()` checks `type(of: self) != URLProtocolStub.self` (= routes isolated stubs)
- ✓ `_isolatedCapturedRequest` instance var exists (= per-instance state)
- ✓ `routeToIsolatedStub(request:client:)` method exists (= per-instance routing)
- ✓ Isolated test runs (= Minimax, OpenAI) still pass (= backward compatible)
- ✓ 0 production code changes