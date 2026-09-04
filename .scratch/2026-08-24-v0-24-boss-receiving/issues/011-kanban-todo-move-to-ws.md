# Ticket 015.011 — Move kanban.db + todo.db to anbaiqiang.ws/ (warehouse)

Boss 2026-08-25 OOB: '用户的聊天数据, 也应该是库文件的一部分' (= all app data,
not just chat, should be inside user-chosen warehouse).

## 现状
- `KanbanStore.init()` opens `~/Library/Application Support/wenshu/kanban.db`
  (= hardcoded path).
- `TodoStore.init()` opens `~/Library/Application Support/wenshu/todo.db`
  (= hardcoded path).
- All 3 db files (chat/kanban/todo) currently in legacy location.

## Fix
- `KanbanStore.init()` accepts custom path (verify).
- `TodoStore.init()` accepts custom path (verify).
- `LibraryRoot` reads `wenshu.libraryPath` UserDefaults and passes to both.
- kanban.db location = `<wenshu.libraryPath>/kanban.db`.
- todo.db location = `<wenshu.libraryPath>/todo.db`.

## Migration
- Same pattern as ticket 015.005: auto-migrate old → new on first launch
  with new path.

## Out of scope
- chat.sqlite move (= ticket 015.005).
- Context compression (= ticket 015.010).
- Per-store backup / restore (= separate ticket if needed).