# Ticket 015.005 — Move chat.sqlite to anbaiqiang.ws/ (wenshu warehouse)

Boss 2026-08-25 OOB: '你的会话记录是存在 .ws 文件里吗' + '用户的聊天数据,
也应该是库文件的一部分, 这样客户在打包库文件到另一台电脑后, 就可以直接
接续'.

## 现状
- `ChatSessionStore.init()` opens `~/Library/Application Support/wenshu/chat.sqlite`
  (= hardcoded path in `LibraryRoot`).
- UserDefaults `wenshu.libraryPath` = boss's selected warehouse path
  (= e.g. `/Users/anbaiqiang/Documents/anbaiqiang.ws/`).
- anbaiqiang.ws/ currently has only Icon + Info.plist (= empty, no chat data).

## Fix
- `ChatSessionStore.init()` accepts custom path (already supported per init
  signature `init(path: String? = nil)`).
- `LibraryRoot` (or `WenshuAppDelegate`) reads `wenshu.libraryPath` UserDefaults
  and passes to ChatSessionStore.
- chat.sqlite location = `<wenshu.libraryPath>/chat.sqlite` (= inside warehouse).
- On warehouse change (= user picks new .ws folder via onboarding), copy
  existing chat.sqlite to new location OR start fresh.

## Migration
- New chat.sqlite path = `<user-selected>.ws/chat.sqlite`.
- Old chat.sqlite (legacy `~/Library/Application Support/wenshu/chat.sqlite`)
  either:
  - (a) Auto-migrate: first launch with new path, copy old → new if exists.
  - (b) Start fresh (= user loses old chat history, but warehouse is new).
- Decision: (a) auto-migrate (= lower user friction, no data loss).

## Out of scope
- kanban.db move (= ticket 015.011).
- todo.db move (= ticket 015.011).
- Auto context compression (= ticket 015.010).