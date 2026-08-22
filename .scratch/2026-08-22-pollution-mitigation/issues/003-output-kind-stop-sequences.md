# 003 — OutputKind enum + short-output stop sequences

> Parent spec: `.scratch/2026-08-22-pollution-mitigation/spec.md` (commit 3 of 4).
> Single file change: `Sources/WenshuApp/Core/Agent/WenshuVerifier.swift`. 1 commit.
> Depends on: issue 002 (system prompt constant exists + is injected).

## What to build

Add `OutputKind` enum + `WenshuVerifier.shortOutputStopSequences: [String]` constant. Modify `WenshuVerifier.send(_:)` signature to take `outputKind: OutputKind`. Branch on `outputKind` when building request body.

## Enum definition

```swift
enum OutputKind {
    case chat           // user chat reply, 100-2000 tokens
    case draft          // chapter / novel body, 500-10000 tokens (long-form)
    case shortText      // commit message / code comment / classification, <500 tokens
}
```

## Stop sequences constant

```swift
extension WenshuVerifier {
    /// Stop sequences injected for short-output calls. Triggers Anthropic-compatible protocol to terminate generation on any forbidden token match.
    /// DO NOT use for long-output calls (chapter drafts) — would terminate entire generation.
    static let shortOutputStopSequences: [String] = [
        "修真", "渡劫", "筑基", "返虚", "结丹", "金丹",
        "元婴", "飞升", "天劫", "雷劫", "心魔", "魔障",
    ]
}
```

## Implementation outline

In `WenshuVerifier.send(_:)`:

```swift
func send(request: WenshuLLMRequest, outputKind: OutputKind) async throws -> WenshuLLMResponse {
    // ... existing logic ...

    var body: [String: Any] = [
        "model": request.model,
        "max_tokens": request.max_tokens,
        "messages": request.messages,
        "system": [WenshuVerifier.systemPromptEnglishOnly] + callerSystem,
    ]

    if outputKind == .shortText {
        body["stop_sequences"] = WenshuVerifier.shortOutputStopSequences
    }

    // ... encode + send ...
}
```

For `complete(_:)` (used by Settings "Verify Key" button): it's a short classification call → use `.shortText`.

For the verifier-style "is key valid" probe: also `.shortText`.

## Why this scope

Anthropic protocol: `stop_sequences` terminates generation at the FIRST occurrence. For long-form novel writing (chapter draft), a single forbidden token mid-sentence = entire chapter lost = unacceptable. Short outputs (commit messages, code comments) are short enough that re-generation is cheap.

## Acceptance criteria

- [ ] `OutputKind` enum added (3 cases, no associated values).
- [ ] `WenshuVerifier.shortOutputStopSequences` constant defined with exactly the 12 tokens.
- [ ] `WenshuVerifier.send(_:)` signature takes `outputKind: OutputKind`.
- [ ] Request body includes `stop_sequences` when `outputKind == .shortText`.
- [ ] Request body does NOT include `stop_sequences` when `outputKind == .chat` or `.draft`.
- [ ] All call sites updated to pass `outputKind` (verify against grep for `WenshuVerifier.send(`).
- [ ] swift build exit 0.
- [ ] swift test exit 0.
- [ ] swift run swiftlint exit 0.
- [ ] Code-review 2 axes: Standards + Spec.

## Files touched

- `Sources/WenshuApp/Core/Agent/WenshuVerifier.swift` (only file)

## Out of Scope

- Rename (issue 001, done).
- System prompt constant (issue 002, done).
- Pre-commit hook (Ticket C, commit 4).

## Risks

- Forgetting to pass `outputKind` on a call site = no defense = silent failure. Mitigation: code-review 2 axes catches it. Consider Swift `assert` in dev builds.
- Anthropic API might cache `stop_sequences` per request — adding the param breaks cache. Mitigation: short-output calls are infrequent, cache benefit is small.