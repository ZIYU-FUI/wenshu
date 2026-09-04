# Issue 06 — UserFacingError translation

## What (= scope)

Map every raw LLM / network / storage error to a Chinese user-facing message. Single source of truth = `UserFacingError.from(_ rawError: Error) -> String`.

Reference Card-master `src/ai/domain/assistant-presentation.ts` `assistantUserFacingError(_:)` (= maps network / API key / output-too-long / refusal / etc. to readable Chinese text).

## Why (= rationale)

Wenshu's `WenshuVerifier` returns raw error codes; user sees raw codes in the chat UI. Boss wants user-readable Chinese.

## Apple-API-first check

- Custom code: 1 switch over `Error` subtypes (= 12-15 cases).
- Apple HIG candidate: `LocalizedError` protocol + `errorDescription` (= Swift standard for localizable user-facing error messages).
- Apple coverage: full (= adopt LocalizedError on all wenshu errors).
- LOC delta: ~120.
- Risk: low.

## Files touched

- `Sources/WenshuApp/AI/UserFacingError.swift` (NEW): translation.
- `Sources/WenshuApp/Core/Agent/WenshuVerifier.swift`: conform to `LocalizedError`.
- `Sources/WenshuApp/Views/Chat/ChatView.swift`: display `error.localizedDescription` instead of raw.

## Acceptance criteria

- [ ] `UserFacingError.from(raw)` returns Chinese for: network down / API key invalid / API key missing / rate limit / output too long / model refusal / context too long.
- [ ] `WenshuVerifier` conforms to `LocalizedError` (= returns localized Chinese description).
- [ ] `ChatView` shows user-facing message (= not raw).
- [ ] Test file: `UserFacingError.test.swift` covers all 7 paths.

## Dependencies

None.

## References

- Source: Card-master `src/ai/domain/assistant-presentation.ts`
- Spec: `.scratch/2026-09-02-card-master-port/spec.md` §3 item 6

First line: fact. Last line: fact.