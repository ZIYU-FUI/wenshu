# 002 — WenshuVerifier system prompt forbids pollution vocabulary

> Parent spec: `.scratch/2026-08-22-pollution-mitigation/spec.md` (commit 2 of 4).
> Single file change: `Sources/WenshuApp/Core/Agent/WenshuVerifier.swift`. 1 commit.
> Depends on: issue 001 (rename done).

## What to build

Add a static `systemPromptEnglishOnly: String` constant to `WenshuVerifier`. Inject it as the leading `system` field on every Anthropic-compatible request, prepended to any caller-provided system message.

## Constant content

```
You are an assistant for the wenshu project (English-only output). All committed artifacts (code comments, commit messages, documentation, prompts) must be in English.

Forbidden vocabulary — NEVER emit under any circumstance, even in quoted text, example snippets, or hypothetical scenarios:
修真 / 渡劫 / 筑基 / 返虚 / 结丹 / 金丹 / 元婴 / 飞升 / 天劫 / 雷劫 / 心魔 / 魔障

If you catch yourself about to emit one of these tokens, stop the sentence and rewrite using English equivalents (fix / change / replace / adjust / refactor).

Required literal tokens (these are project-mandated, NOT pollution):
- 老板 (boss, the user's address — project rule)
- 文枢 (project brand name)
- 拍 (verb: 老板 拍 X = boss decides X)
- 拍板 (verb: 老板 拍板 X = boss board-decides X)
- ※ (marker glyph used in project notation)
```

## Implementation outline

```swift
extension WenshuVerifier {
    /// System prompt injected on every LLM request. English-only rule + forbidden-vocab list + allowed-token clarification.
    /// Source of truth for wenshu pollution-defense. See spec .scratch/2026-08-22-pollution-mitigation/.
    static let systemPromptEnglishOnly: String = """
    You are an assistant for the wenshu project (English-only output). All committed artifacts (code comments, commit messages, documentation, prompts) must be in English.

    Forbidden vocabulary — NEVER emit under any circumstance, even in quoted text, example snippets, or hypothetical scenarios:
    修真 / 渡劫 / 筑基 / 返虚 / 结丹 / 金丹 / 元婴 / 飞升 / 天劫 / 雷劫 / 心魔 / 魔障

    If you catch yourself about to emit one of these tokens, stop the sentence and rewrite using English equivalents (fix / change / replace / adjust / refactor).

    Required literal tokens (these are project-mandated, NOT pollution):
    - 老板 (boss, the user's address — project rule)
    - 文枢 (project brand name)
    - 拍 (verb: 老板 拍 X = boss decides X)
    - 拍板 (verb: 老板 拍板 X = boss board-decides X)
    - ※ (marker glyph used in project notation)
    """
}
```

In the request-building code path (where `WenshuLLMRequest` is assembled in `send(_:)` and `complete(_:)`), prepend `systemPromptEnglishOnly` as the first `system` message, followed by any caller-supplied system message.

## Acceptance criteria

- [ ] `WenshuVerifier.systemPromptEnglishOnly` constant defined and contains the exact text above.
- [ ] Every request method (`send(_:)`, `complete(_:)`) prepends this constant to the system message array.
- [ ] No caller-supplied system message is dropped or overwritten.
- [ ] swift build exit 0.
- [ ] swift test exit 0.
- [ ] swift run swiftlint exit 0.
- [ ] Code-review 2 axes: Standards + Spec.

## Files touched

- `Sources/WenshuApp/Core/Agent/WenshuVerifier.swift` (only file)

## Out of Scope

- OutputKind enum / stop_sequences (Ticket B, commit 3).
- Pre-commit hook (Ticket C, commit 4).

## Risks

- If caller passes system message that conflicts with English-only rule, behavior is undefined (system messages concatenate). Mitigation: order = constant first, caller second (most prompts add narrow context after the broad English-only rule).
- Prompt cache miss: prepend breaks Anthropic prompt caching if the constant is treated as cache-disrupting. Mitigation: keep constant text byte-stable (any edit = new cache key, expected).
- Current `WenshuVerifier` is the verifier only. Real chat draft generation is future work. The constant + injection pattern here ports 1:1 when more call sites land.