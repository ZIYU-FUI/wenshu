# v0.91 Pre-existing test flakes · Spec (= partial commit + future scope)

**Branch**: `wt/v0.91-pre-existing-flakes-2026-09-14`
**Generated**: 2026-09-14
**Methodology**: PO v1.1 main-flow 5 steps (Q34) + boss voice trigger Q146 + boss 2026-09-14 OOB "按优先级推" + "A"

## Context

Full `swift test` (= 544 tests in parallel) had pre-existing flakes
that v0.90's `.serialized` trait did NOT address:

1. **ChatViewModelDefaultModelTests** (= 3 issues; = this branch's
   ticket scope)
2. **LiquidGlassPolishTests** (= 5 issues; = boss 2026-08-24 polish
   ticket scope; = OUT OF SCOPE for v0.91)

Per boss OOB "按优先级推" + "A": pick one. v0.91 = ChatViewModel suite
fix (= the boss's v0.24 fix-tracking tickets). Liquid Glass polish
deferred.

## Scope (= 1 ticket, 1 test file 1 commit per Q112 + 1 prod file)

| # | Ticket | File(s) | Status |
|---|---|---|---|
| 1 | `001-keychain-ops-34018-handling` | `Sources/WenshuApp/Core/Provider/KeychainOps.swift` (= add `missingEntitlement(OSStatus)` case + `from(_:OSStatus)` bridge) | ✅ done |
| 2 | `001b-mapper-exhaustive-switch` | `Sources/WenshuApp/Core/Provider/ProviderKeychain.swift` + `Sources/WenshuApp/Core/Provider/SearchAPIKeychain.swift` (= exhaustive switch on new case) | ✅ done |
| 3 | `001c-test-source-path-from-cwd` | `Tests/WenshuAppTests/Views/Chat/ChatViewModelDefaultModelTests.swift` (= derive paths from currentDirectoryPath) | ✅ done |
| 4 | `001d-test-source-of-truth-redirect` | Same test file (= redirect ChatZoneView @AppStorage check to AppState.llmModel) | ✅ done |
| 5 | `001e-test-english-only-placeholder` | Same test file (= assert Chinese placeholder NOT present per AGENTS.md §11) | ✅ done |

Out of scope (= explicit):

- LiquidGlassPolishTests (= 5 issues; = needs 6 file changes to wire
  `.glassEffect(.regular)`; = separate ticket v0.92+)
- Test file rename (= `ChatViewModelDefaultModelTests` header
  mentions "App.swift" = pre-v0.40; = minor doc drift; = defer)
- `ChatView.swift ChatViewModel.currentModel default` / `send() fallback`
  (= already passing per the existing tests; = "NOT YET FIXED" suffix
  in test name is a doc-drift artifact; = defer cleanup)

## Per-ticket acceptance criteria

### Ticket 001 — ChatViewModelDefaultModelTests fix

- `swift test --filter "ChatViewModelDefaultModelTests"` = 9/9 pass
  (= previously 3 fail)

#### Specific fixes

1. **ChatZoneView.currentModel default**: previous test checked for
   `@AppStorage("wenshu.llm.model") private var currentModel: String = ""`
   in ChatZoneView.swift. After v0.40 apple-001 phase 3 ticket 4b, the
   property moved to `AppState.llmModel` (= the canonical source of
   truth). Test redirected to check `AppState.llmModel` (= with
   comment-stripping to avoid false positives from SettingView's
   historical reference comment).

2. **ChatZoneView menu text placeholder**: previous test checked for
   `currentModel.isEmpty ? "无模型可用"` (= Chinese placeholder; =
   also violates AGENTS.md §11 English-only). Current implementation
   branches on `if currentModel.isEmpty` (= the empty-state overlay).
   Test updated to assert (a) the empty-state branch exists, AND (b)
   the Chinese string is NOT present (= per AGENTS.md §11 invariant).

3. **Keychain -34018 graceful error**: previous test checked for
   `34018` in ProviderKeychain.swift. After v0.84 (= KeychainOps
   extraction), the canonical Security-glue lives in KeychainOps.swift.
   Production fix: added `KeychainOpsError.missingEntitlement(OSStatus
   = -34018)` case + `KeychainOpsError.from(_:OSStatus)` bridge so
   -34018 is recognized as `errSecMissingEntitlement` (= the boss's
   v0.24 graceful-error message). ProviderKeychain and SearchAPIKeychain
   `from(_:KeychainOpsError)` mappers updated to handle the new case
   (= exhaustive switch).

4. **Test path portability**: previous test hardcoded
   `/Volumes/ANAN/Engineering/wenshu/Sources/...` (= always pointed to
   the main checkout). When run from a worktree, the test verified the
   MAIN file (= not the worktree's). Fixed by deriving paths from
   `FileManager.default.currentDirectoryPath`.

## Cross-references

- `Tests/WenshuAppTests/UI/Polish/LiquidGlassPolishTests.swift` (= out
  of scope; = 5 fails; = separate ticket v0.92+)
- `Sources/WenshuApp/Core/Provider/KeychainOps.swift` (= this branch's
  primary prod change)
- `Sources/WenshuApp/Core/Provider/ProviderKeychain.swift` (= mapper)
- `Sources/WenshuApp/Core/Provider/SearchAPIKeychain.swift` (= mapper)
- `Tests/WenshuAppTests/Views/Chat/ChatViewModelDefaultModelTests.swift`
  (= this branch's test changes)
- `Sources/WenshuApp/State/AppState.swift` (= canonical llmModel
  source-of-truth per v0.40 apple-001 phase 3 ticket 4b)
- `.scratch/v0.89-test-flake-fix/spec.md` (= upstream cross-test
  pollution analysis)

## Validation (= per Q34 step 4)

1. `swift test --filter "ChatViewModelDefaultModelTests"` = **9/9 pass**
   (= previously 3 fail)
2. `swift build` = BUILD COMPLETE (= 7s)
3. Other flake suites (= LiquidGlassPolishTests = 5 fail; = out of
   scope; = pre-existing; = unchanged)