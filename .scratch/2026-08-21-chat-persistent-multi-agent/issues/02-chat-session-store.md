# 02 — ChatSessionStore SQLite persistence

**What to build:**
老板 2026-08-21 ruled: "after closing and reopening the app, the previous chat continues." `ChatSessionStore` = actor + SQLite, mirroring the `TodoStore` / `MemoryStore` / `KanbanStore` pattern. `ChatViewModel.init()` loads history; `send()` appends to SQLite. Two-table schema: `chat_messages` + `chat_summaries`.

**Blocked by:** ticket 01 (the `source` field must exist on `ChatMessage` before storing).

**Status:** ready-for-agent

## Fix specification

1. Create `Sources/WenshuApp/Core/Chat/ChatSessionStore.swift` (actor + SQLite, same pattern as `Sources/WenshuApp/Core/Todo/TodoStore.swift`).
2. SQLite schema:
   ```sql
   CREATE TABLE IF NOT EXISTS chat_messages (
     id TEXT PRIMARY KEY,
     session_id TEXT NOT NULL DEFAULT 'default',
     source TEXT NOT NULL,
     content TEXT NOT NULL,
     timestamp REAL NOT NULL
   );
   CREATE INDEX IF NOT EXISTS idx_chat_messages_session ON chat_messages(session_id, timestamp);

   CREATE TABLE IF NOT EXISTS chat_summaries (
     session_id TEXT PRIMARY KEY,
     summary TEXT NOT NULL,
     updated_at REAL NOT NULL,
     last_message_id TEXT
   );
   ```
3. Path: `~/Library/Application Support/com.wenshu.app/chat.sqlite` (matches the wenshu project baseline).
4. API (actor methods):
   - `loadMessages(sessionId: String) async throws -> [ChatMessage]`
   - `append(_ message: ChatMessage, sessionId: String) async throws`
   - `clear(sessionId: String) async throws`
   - `loadSummary(sessionId: String) async throws -> String?`
   - `saveSummary(_ summary: String, sessionId: String, lastMessageId: UUID) async throws`
5. Add `Codable` conformance to `ChatMessage` (id / source / content / timestamp; `sessionId` lives at the DB layer, not the struct).
6. In `ChatMessage.swift` (sibling to `ChatView.swift`) add `Codable` + `ChatSource: Codable` conformance.

## Acceptance

- [ ] `ChatSessionStore` actor + SQLite file landed
- [ ] Two-table schema correct (`chat_messages` + `chat_summaries`)
- [ ] `loadMessages` returns rows sorted by `timestamp`
- [ ] `append` writes to SQLite asynchronously without blocking the `ChatView` UI
- [ ] `clear` empties messages but preserves summary
- [ ] `swift build` exit 0
- [ ] `swift test` exit 0
- [ ] New tests: `testChatSessionStoreAppendLoad` / `testClear` / `testSessionIsolation` (multiple `session_id` values do not collide)

## Out of scope

- `ChatView` UI
- `ChatViewModel` main flow (this ticket only writes the store, not the view-model calls)
- Chat session summary generation logic (ticket 05)

## References

- Depends on: ticket 01
- Required by: ticket 05 (summary uses the `chat_summaries` table) / ticket 06 (`ChatViewModel` integration)
