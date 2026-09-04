# Issue 08 — ChatSnapshot + ChatStore.transact

## What (= scope)

An immutable `ChatSnapshot` (= conversations + active id + messages + draft + status). `ChatStore.transact(_ operation: (ChatSnapshot) -> Result)` = atomic update (= applies or rolls back as a unit). Crash safety: app kill -9 mid-write → next launch sees the previous snapshot (= no half-state).

Reference Card-master `AiConversationSnapshot` + `script-repository.ts` `transact()` (= atomic update of library state).

## Why (= rationale)

Wenshu's `ChatSessionStore` uses mutable `@State` for messages. Mid-write crash = message lost. Boss 9/2 OOB拍 'A 全做' includes this.

## Apple-API-first check

- Custom code: `ChatSnapshot` struct (= `let` everywhere) + `ChatStore.transact` (= read snapshot → mutate → write atomically via `URLSession.upload` or temp file swap).
- Apple HIG candidate: Swift `actor` (= macOS 13+; actor-isolated state gives serial access by default = simpler than manual lock).
- Apple coverage: partial (= actor gives serial access, but crash safety still needs atomic file swap).
- LOC delta: ~250.
- Risk: med (= atomic file swap = unlink + rename = race window).

## Files touched

- `Sources/WenshuApp/State/ChatSnapshot.swift` (NEW): immutable struct.
- `Sources/WenshuApp/State/ChatStore.swift` (REFACTOR): `actor` + `transact` API.
- `Sources/WenshuApp/Views/Chat/ChatView.swift`: read from `ChatStore.snapshot` (no longer @State).
- `Sources/WenshuApp/Storage/AtomicFileSwap.swift` (NEW): helper for atomic write (= write to `.tmp` then `rename`).

## Acceptance criteria

- [ ] `ChatSnapshot` is `struct` with `let` properties only.
- [ ] `ChatStore.transact` either applies or rolls back (= no half-state visible).
- [ ] Simulated crash mid-transact → next launch sees the previous snapshot.
- [ ] ChatView renders from `ChatStore.snapshot` (= no concurrent modification possible).
- [ ] Test file: `ChatStore.test.swift` covers: transact happy path, transact rollback, concurrent transact = serial.

## Dependencies

None.

## References

- Source: Card-master `src/features/userscript/application/script-repository.ts` `transact()`
- Spec: `.scratch/2026-09-02-card-master-port/spec.md` §3 item 8

First line: fact. Last line: fact.