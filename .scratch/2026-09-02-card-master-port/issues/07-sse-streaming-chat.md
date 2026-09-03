# Issue 07 — SSE streaming for chat

## What (= scope)

Chat responses render character-by-character (= streaming) instead of waiting for the full response. Uses Server-Sent Events (= Anthropic / OpenAI both stream via SSE).

Reference Card-master `src/ai/infrastructure/responses-api-client.ts` (= SSE parsing = event stream → partial text delta).

## Why (= rationale)

Wenshu currently uses `ProviderFetcher` = non-streaming. Boss拍了全做 = stream by default.

## Apple-API-first check

- Custom code: a `SSEClient` (= URLSession bytes task + async iterator over lines + JSON decode per event).
- Apple HIG candidate: `URLSession.bytes(for:)` (= macOS 12+; async stream of URLSession bytes).
- Apple coverage: full (= no third-party SSE client needed).
- LOC delta: ~350.
- Risk: med (= SSE format is fragile; partial JSON across events; cancellation cleanup).

## Files touched

- `Sources/WenshuApp/AI/SSEClient.swift` (NEW): generic `SSEStream` (= `AsyncThrowingStream<Event, Error>`).
- `Sources/WenshuApp/Core/Provider/ProviderFetcher.swift`: switch from blocking fetch to streaming.
- `Sources/WenshuApp/Views/Chat/ChatView.swift`: subscribe to streaming response (= incremental render).

## Acceptance criteria

- [ ] `SSEClient.stream(_ url: URL)` yields parsed events as `AsyncThrowingStream`.
- [ ] ChatView shows partial text as it arrives (= cursor visible mid-stream).
- [ ] Cancellation cleanly tears down the URLSession task.
- [ ] Test file: `SSEClient.test.swift` covers: happy path, network error mid-stream, JSON parse error, cancellation.

## Dependencies

None.

## References

- Source: Card-master `src/ai/infrastructure/responses-api-client.ts`
- Spec: `.scratch/2026-09-02-card-master-port/spec.md` §3 item 7

First line: fact. Last line: fact.