# 001 — Rename MiniMaxVerifier → WenshuVerifier + extract LLM types

> Parent spec: `.scratch/2026-08-22-pollution-mitigation/spec.md` (commit 1 of 4).
> Files touched:
> - `Sources/WenshuApp/Core/Agent/MiniMaxVerifier.swift` → `Sources/WenshuApp/Core/Agent/WenshuVerifier.swift` (rename + content)
> - `Sources/WenshuApp/Core/Agent/WenshuLLMTypes.swift` (new — extracted data types)
> - `Sources/WenshuApp/Core/Agent/MiniMaxModelFetcher.swift` → `Sources/WenshuApp/Core/Agent/WenshuLLMModelFetcher.swift` (rename + content)
> - All call sites that import / reference `MiniMax*` symbols.
> 1 commit. Pure rename, no behavior change.

## What to build

Rename all `MiniMax*` symbols in `Sources/` to `Wenshu*`:

| Old | New |
|-----|-----|
| `MiniMaxVerifier` | `WenshuVerifier` |
| `MiniMaxRequest` | `WenshuLLMRequest` |
| `MiniMaxResponse` | `WenshuLLMResponse` |
| `MiniMaxMessage` | `WenshuLLMMessage` |
| `MiniMaxError` | `WenshuLLMError` |
| `MiniMaxModelFetcher` | `WenshuLLMModelFetcher` |

Naming rationale: `WenshuVerifier` = verifies wenshu's LLM integration (provider-agnostic). `WenshuLLM*` prefix on data types = "LLM types owned by wenshu"; future provider swap keeps types stable.

## File layout

- `Sources/WenshuApp/Core/Agent/WenshuVerifier.swift` — verifier class only. Imports `WenshuLLMTypes`.
- `Sources/WenshuApp/Core/Agent/WenshuLLMTypes.swift` (new) — data types: `WenshuLLMRequest` / `WenshuLLMResponse` / `WenshuLLMMessage` / `WenshuLLMError`. Plus the `ModelCache` actor (currently inside `MiniMaxVerifier.swift`).
- `Sources/WenshuApp/Core/Agent/WenshuLLMModelFetcher.swift` — rename of `MiniMaxModelFetcher.swift`.

## Verification before commit

```bash
cd /Volumes/ANAN/Engineering/wenshu
# 1. grep for any remaining MiniMax reference
grep -rn 'MiniMax' Sources/ Tests/ Tools/

# 2. build
swift build

# 3. test
swift test
```

Both grep and swift build/test must return 0 hits / exit 0 before commit.

## Acceptance criteria

- [ ] All old `MiniMax*` symbols renamed to `Wenshu*` per table.
- [ ] `WenshuLLMTypes.swift` created with extracted data types.
- [ ] `ModelCache` actor moved to `WenshuLLMTypes.swift` (or kept in `WenshuVerifier.swift` — confirm during grill-with-docs).
- [ ] `WenshuLLMModelFetcher.swift` created from rename.
- [ ] No behavior change (verifier logic identical).
- [ ] grep -r 'MiniMax' Sources/ Tests/ Tools/ → 0 hits.
- [ ] swift build exit 0.
- [ ] swift test exit 0.
- [ ] swift run swiftlint exit 0.
- [ ] Code-review 2 axes: Standards (Swift API Design Guidelines + SwiftLint) + Spec (matches this ticket's contract).

## Out of Scope

- Pollution-defense system prompt (Ticket A, commit 2).
- OutputKind enum + stop sequences (Ticket B, commit 3).
- Pre-commit filter (Ticket C, commit 4).
- Any change to `LLMKeychain.swift` (grep first to confirm whether it references `MiniMax*`).

## Risks

- Call sites in tests / other source files reference old names. Mitigation: grep before commit + run swift build to surface any missing references.
- Public API change if any external module imports these symbols. Mitigation: wenshu is single-process; no external imports; safe.
- Renaming the file via `git mv` (preserves rename history). Mitigation: use `git mv` not delete + create.