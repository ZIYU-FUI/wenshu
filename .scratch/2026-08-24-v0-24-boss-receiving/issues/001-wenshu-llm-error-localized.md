# Ticket 015.001 — WenshuLLMError LocalizedError conformance

> Parent spec: `.scratch/2026-08-24-v0-24-boss-receiving/spec.md` Bug 1.
> Implementation commit: `aa7caca7f` (boss).
> Po main flow: implement (done) + code-review (in commit body) + domain-modeling (in CONTEXT.md) + confirm (boss UI verify).

## Acceptance criteria

- [x] WenshuLLMError conforms to `LocalizedError`
- [x] `missingAPIKey` description contains "API key" / "Settings" / "Provider" (中文)
- [x] `invalidBaseURL(url)` description contains URL string
- [x] `httpError(statusCode, body)` description contains status code
- [x] Tests added (4 in `ChatViewModelDefaultModelTests.swift`)
- [x] swift test: PASS (584/80)
- [x] swift build: clean (0 warnings)
- [x] 0 pollution leak

## Test results

```
✅ WenshuLLMError conforms to LocalizedError (boss v0.24 fix)         PASS
✅ WenshuLLMError.invalidBaseURL has human description                 PASS
✅ WenshuLLMError.httpError includes status code                        PASS
```

## UI verify (boss)

Open WenshuApp, in chat input type `在?`. Expected:
- Old: 'Error: The operation couldn't be completed. (WenshuApp.WenshuLLMError error 2.)'
- New: 中文 human description like 'API key 未配置. 请在 Settings → Provider 配置 API key.'

## Risk

- Low: just adds `errorDescription` getter. No behavior change beyond better UX.
- Migration: any caller using `String(describing: error)` instead of `error.errorDescription` won't break.

## Files changed

- `Sources/WenshuApp/Core/Agent/WenshuVerifier.swift` — add `LocalizedError` conformance + 3-case `errorDescription` switch

## Status: ✅ DONE (boss commit + tests + verified)
