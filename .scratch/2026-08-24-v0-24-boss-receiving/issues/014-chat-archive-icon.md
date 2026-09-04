# Ticket 015.014 — Chat zone archive icon (top-right 18 PT) + alert + session archive flow

Boss 2026-08-25 fourth OOB: '聊天区的顶栏居右 18PT 处, 加一个归档 ICON. 点击弹出
是否归档本次会话和上下文. 点击确认, 回档现有会话和上下文. 起一个全新的会话.
上下文重新加载'.

Boss image: composer-images/composer_2026-08-25_02-03-55-434_120cf9.png
shows chat zone top-right area as empty (= red box highlighting missing
archive icon position).

## 现状
- Chat zone top toolbar (per ticket 10 commit f1fe8e64c) shows: model
  picker + context usage ('0 / 1M').
- Top-right area is empty (= boss拍 archive icon goes here).
- Session management: sessionId hardcoded to 'default' (= no archive /
  new-session flow).

## Fix (1 commit per boss 8/22)
- Add archive icon (SF Symbol 'archivebox' or 'tray.full') at chat zone
  top-right, 18 PT from edge (= per Boss image 红框 position).
- Click → SwiftUI alert '是否归档本次会话和上下文' (yes / cancel).
- Confirm → archive current session + context (= save to chat_archives
  table with timestamp + summary), then create new session (= new
  sessionId = UUID or timestamp-based).
- New session: empty messages, fresh contextMax tracking, fresh
  contextUsed tracking.

## Per-ticket spec
- Chat zone top-right HStack add archive button (SF Symbol 'archivebox').
- Tap action: present confirmation alert with 2 buttons (Cancel / Archive
  + Start New).
- On confirm:
  1. Store current session summary + message count to chat_archives table
     (id, session_id, archived_at, summary, message_count).
  2. Generate new sessionId (= UUID().uuidString or timestamp-based).
  3. Clear vm.messages = [].
  4. Reset vm.contextUsed = 0.
  5. Persist vm.sessionId to chat_messages writes (= new session).
  6. NSLog audit trail.

## Out of scope
- Per-book project files (= ticket 015.015).
- Project sidebar selection sync (= ticket 015.016).
- Long-form 剧情依赖延续 (= ticket 015.017).

## Done criterion
- Archive icon visible at chat zone top-right (18 PT right padding).
- Click triggers alert with Chinese text.
- Confirm creates new sessionId, archives old session to chat_archives.
- UI shows empty chat + reset context counter.
- 双轴 code-review PASS (per Boss 8/25 '双轴每次都跑' protocol).