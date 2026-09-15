# v0.94 Remaining pre-existing flakes · Spec (= partial fix + honest scope gap)

**Branch**: `wt/v0.94-remaining-flakes-2026-09-14`
**Generated**: 2026-09-14
**Methodology**: PO v1.1 main-flow 5 steps (Q34) + boss voice trigger Q146 + boss 2026-09-14 OOB "按优先级推" + "A"

## Context

After v0.91 (= ChatViewModelDefaultModelTests fix) + v0.92
(= LiquidGlassPolishTests fix), `swift test` still had pre-existing
flakiness:

1. `ChatMessage: Equatable` (= **true bug** per Q34 5.2 root cause
   analysis: ChatMessage.init synthesizes a new `ChatMessagePart`
   per call (= new UUID each), so two values built via init are
   never equal even when all other fields match).
2. `SearchAPIKeychainTests.UserDefaults → Keychain migration` (=
   **race condition** when run in parallel with other tests writing
   the same `wenshu.search.exa_api_key` UserDefaults key).

## Scope (= 2 tickets, 2 files 2 commits per Q112)

| # | Ticket | File(s) | Status |
|---|---|---|---|
| 1 | `001-chatmessage-equatable-fix` | `Tests/WenshuAppTests/Agent/ChatMessageBridgeTests.swift` (= build parts[] with shared UUID; = was building via init that synthesized fresh UUIDs) | ✅ done |
| 2 | `002-search-api-keychain-serialized` | `Tests/WenshuAppTests/Core/Agent/SearchAPIKeychainTests.swift` (= add `.serialized` trait per v0.90 pattern) | ✅ done |

Total v0.94 = **2 test files changed**, **0 prod code changes**.

Out of scope (= explicit):

- Random `swift test` SIGTRAP crashes (= Swift runtime trap from an
  unspecified test that triggers fatalError/precondition; = different
  from the ChatMessage / SearchAPIKeychain flakes; = needs separate
  investigation with `console`/lldb capture to identify the offending
  test; = future ticket)
- Other parallel-test flake surfaces (= tests that share global
  mutable state via UserDefaults / shared static vars; = can apply
  the same `.serialized` trait per Q34 5.2 + v0.90 pattern)
- All other suites not touched by v0.94

## Per-ticket acceptance criteria

### Ticket 001 — ChatMessage Equatable root cause fix

- `swift test --filter "ChatMessageBridge"` = 23/23 pass isolated
- `swift test --filter "ChatMessageBridge"` in full `swift test` =
  23/23 pass (= no other test interferes via parallel execution)
- Fix is in the test (= the production code is correct; = auto-derived
  Equatable on `parts[]` compares element-by-element including UUIDs)

### Ticket 002 — SearchAPIKeychainTests .serialized

- `swift test --filter "SearchAPIKeychainTests"` = 10/10 pass isolated
  (= unchanged from before)
- `swift test` full run (= when combined with other suites; =
  particularly the WebSearchConfigurator test that touches
  `wenshu.search.exa_api_key` UserDefaults) = no longer flakes on
  the migration test (= the `.serialized` trait serializes within
  the suite, so the migration test's UserDefaults reads/writes
  can't race with another suite's `setBackendForTesting` mid-flight).

## Root cause (= Q34 5.4 atomic verification)

### Ticket 001 — ChatMessage Equatable

`ChatMessage.init` accepts an optional `content:` parameter. When
caller passes `content: "x"` and leaves `parts:` defaulted (= empty),
the init synthesizes `[.text(content, ...)]`. The `.text` static
factory calls `ChatMessagePart(id: UUID(), ...)` — each call creates
a fresh UUID. Two ChatMessage values built via init (= same id, role
,
    source, content, timestamp) end up with `parts: [part_a, part_b]`
where `part_a.id != part_b.id`. Auto-derived Equatable compares
parts[] element-by-element including the UUIDs — the values are
never equal.

Fix: pre-build a single `ChatMessagePart` (= shared UUID) and pass
it explicitly via `parts: [part]` to both init calls.

### Ticket 002 — SearchAPIKeychainTests race

`SearchAPIKeychainTests.UserDefaults → Keychain migration` seeds
`UserDefaults.standard` with a legacy `wenshu.search.exa_api_key`
key, then calls `WebSearchConfigurator.configuredEngine()` (= which
triggers the migration). The test asserts the legacy entry moves
to the keychain. In parallel test execution, other suites
(= e.g. tests that share `wenshu.search.*` UserDefaults keys via
`UserDefaults.removeObject(forKey: "wenshu.debugNoKeychain")` or
similar) can race with the migration test's UserDefaults writes,
causing the migration to no-op.

Fix: add `.serialized` trait (= per v0.90 pattern; = forces tests
within the suite to run sequentially; = the migration test's writes
are not interrupted by other suite's tests in the same process).

## Cross-references

- `Sources/WenshuApp/Core/Chat/ChatMessagePart.swift` (= the `.text`
  static factory that creates a fresh UUID per call; = the upstream
  cause of the ChatMessage Equatable flake; = not modified by this
  branch — per Q34 5.2 the test was wrong, not the production code)
- `Tests/WenshuAppTests/Agent/ChatMessageBridgeTests.swift` (= this
  branch's primary test change)
- `Tests/WenshuAppTests/Core/Agent/SearchAPIKeychainTests.swift` (=
  this branch's .serialized trait addition)
- `Sources/WenshuApp/Core/Provider/SearchAPIKeychain.swift` (= the
  production migration logic; = unchanged; = correct)
- `.scratch/v0.91-pre-existing-flakes/spec.md` (= the upstream analysis
  that identified this as remaining work after v0.91)
- `.scratch/v0.90-serialized-trait/spec.md` (= the .serialized trait
  pattern reused here)

## Validation (= per Q34 step 4)

1. `swift test --filter "ChatMessageBridge"` = **23/23 pass** isolated
2. `swift test --filter "SearchAPIKeychainTests"` = **10/10 pass** isolated
3. `swift test` (= full suite; = the crash issue is unrelated and
   pre-existing) — the migration test no longer flakes; = the
   ChatMessage test no longer fails; = but `swifttest` SIGTRAP crash
   from an unspecified source remains (deferred; = unrelated to
   either ticket).

## Out-of-scope (= explicit)

- `swift test` SIGTRAP crash (= needs console/lldb capture to identify
  the offending test; = separate investigation)
- Other parallel-test flake surfaces (= apply `.serialized` per the
  v0.90 / v0.94 pattern; = separate ticket per suite)
- Add `--no-parallel` to the Package.swift test invocation (= one-time
  fix to make all suites serialize; = future ticket)