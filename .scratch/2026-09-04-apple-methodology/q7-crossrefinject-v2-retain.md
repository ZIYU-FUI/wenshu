# Wenshu Apple-API-First Audit — Q7 Decision: CrossRefInject_v2 Retain

## Decision

Q7 boss拍 = **RETAIN** `Sources/WenshuApp/Domain/CrossRefInject_v2.swift` (= keep both v1 and v2 on disk, leave to a follow-up wenshu-project decision whether to flip from v1 to v2).

## Evidence (= 5-stage dead-code grep)

- **Stage 1** (= self-definition): `Sources/WenshuApp/Domain/CrossRefInject_v2.swift:59:struct CrossRefInject_v2: Sendable {` confirmed.
- **Stage 2** (= 15 lines — 12 self-def + 3 imports / docs / M5-14 ticket comment).
- **Stage 3** (= render chain `App.swift` / `WorkspaceView.swift` / `TabContentDispatcher.swift`): **0 lines** = v2 is unreachable from the SwiftUI render chain.
- **Stage 4** (= test suite): `Tests/WenshuAppTests/Domain/CrossRefInject_v2Tests.swift` is an active suite (= 169 LOC, 8 tests).
- **Stage 5** (= `CONTEXT.md` reference): `CONTEXT.md:225` entry `CrossRefInject_v2 (hermes verbatim port) (M5-14)` documents v2 as the planned replacement for v1.

## What this means

- v2 IS unreachable from the production render chain (= the third-party tool's narrow SwiftUI grep was right about that).
- v2 IS actively tested (= the third-party tool's claim of "dead" was wrong about that).
- Real situation = **v2 = the planned replacement for v1, never flipped on**. v1 (`CrossRefInject.swift`, 151 LOC) is the only impl currently active in the render chain.

## Why retain (rather than delete)

Per AGENTS.md §11.1 Apple canonical authority: Apple samples don't keep v1 + v2 of the same type in parallel. The Apple-correct action would be to delete one. But:

1. v2's behavior (= token-cap FIFO drop when references exceed budget) is documented as the planned improvement over v1 (= v1 has rule-based but no token-cap enforcement).
2. The flip decision is **wenshu-project scoped** (= does the new behavior match the boss's cross-reference injection rule?). That decision cannot be resolved from a 5-stage grep alone (= needs product intent).
3. v2 ships with an active test suite (= 8 tests) that documents the new behavior contract. Deleting v2 = losing the test coverage even if the implementation isn't used yet.
4. v2 is a verbatim port from `hermes-agent/agent/context_references.py` (= the original hermes behavior). Deleting it = losing the hermes-source-of-truth contract for the project.

## Apple-canonical follow-up

Two options when the wenshu-project decides:

- **Option A** (replace v1 with v2): delete `CrossRefInject.swift` (= 0 production callers per the dead-code grep), promote `CrossRefInject_v2.swift` to `CrossRefInject.swift` (= single canonical name, no parallel versions), update tests / docs / `CONTEXT.md` entry.
- **Option B** (keep v1 as the impl): delete `CrossRefInject_v2.swift` + `CrossRefInject_v2Tests.swift` (= 169 LOC test gone but v1 behavior preserved), update `CONTEXT.md` entry to drop the "(M5-14) planned replacement" note.

Both options are valid; the boss / wenshu-project picks based on whether the token-cap FIFO drop (= v2's improvement over v1) is desired. Until that decision is made, the file stays.

## Verification

- `swift build` PASS
- `swift test --disable-xctest --no-parallel` (with `WENSHU_DEBUG_INMEMORY_KEYCHAIN=1`): 1878 tests / 269 suites / 0 issues / EXIT 0
- File counts: `Sources/WenshuApp/Domain/CrossRefInject.swift` = 151 LOC; `Sources/WenshuApp/Domain/CrossRefInject_v2.swift` = 190 LOC; `Tests/WenshuAppTests/Domain/CrossRefInject_v2Tests.swift` = 169 LOC / 8 tests.

## Reference

- Full 5-stage grep report: `wt/apple-001/structure-audit/.scratch/2026-09-04-apple-methodology/apple-self-check.md` §1 row D1 + §3 row D1.
- Boss Q&A answer key: `wt/apple-001/structure-audit/.scratch/2026-09-04-apple-methodology/spec.md` §5 Q7 (= original spec, before this decision was applied).
- Apple-API-first authority rule: `wenshu-apple-api-first` SKILL.md §"Apple authority hierarchy" + §"5-stage dead-code grep".
