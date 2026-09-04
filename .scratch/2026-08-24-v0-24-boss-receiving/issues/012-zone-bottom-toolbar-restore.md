# Ticket 015.012 — Re-add ZoneBottomToolbar for all 6 zones (per-zone status info)

Boss 2026-08-25 third OOB: '六个区现在只有聊天区有底栏了. 其它五区的底栏
不知道什么时候都丢了'. Boss plan A: 恢复所有 5 zones 用 ZoneBottomToolbar,
每 zone 自己的 status info.

## 现状
- `ZoneBottomToolbar` struct exists at `Sources/WenshuApp/App.swift:1184`
  (30 PT high, placeholder text + splitter).
- `ZoneModule.body` comment at `App.swift:1242`: 'v0.24 boss验收fix:
  6-zone unified pattern — no outer ZoneTopToolbar / ZoneBottomToolbar'.
- 5 zones (projectSidebar, projectPreview, editor, specializedTools,
  aiDynamic) = no bottom toolbar (= dead `ZoneBottomToolbar` struct).
- Chat zone = has in-child `ChatBottomToolbar` (model picker + context
  usage) per ticket 10 (commit f1fe8e64c).

## Fix (1 commit per boss 8/22 "1 zone 1 ticket 1 commit")
- Modify `ZoneModule.body` to include `ZoneBottomToolbar` for all slots
  EXCEPT `.aiChat` (= chat keeps in-child ChatBottomToolbar per spec).
- New `ZoneStatus` SwiftUI view (per-zone content): displays the
  per-zone status info (= word count, chapter count, etc.).
- Per-zone status passed via ViewModifier or per-slot computed property.

## Per-zone status info (Boss plan A)
- `.projectSidebar`: 书架数 (= `WenshuLibrary.shelves.count`).
- `.projectPreview`: 章节数 + 当前章节号 (= `book.chapters.count` +
  `chapterIndex`).
- `.editor`: 字数 + 进度 % (= `wordCount` of current chapter + progress bar).
- `.specializedTools`: placeholder '工具就绪' (= future ticket wires real state).
- `.aiDynamic`: keep inner tab bar only (Kanban view already has progress).
- `.aiChat`: skip (= in-child `ChatBottomToolbar` already renders).

## Out of scope
- Real-time data wiring for per-zone status (= ticket 015.013).
- Top toolbar restore (= per boss 8/24 OOB 'per-zone title bar 不需要').

## Done criterion
- All 5 zones (projectSidebar, projectPreview, editor, specializedTools,
  aiDynamic) display ZoneBottomToolbar at bottom.
- Chat zone retains its custom in-child ChatBottomToolbar (= no duplicate).
- Per-zone status info shows real data per Boss plan A.
- Zone bottom toolbar visual style matches chat zone's bottom toolbar (=
  30 PT height, splitter top, consistent typography).
- 双轴 code-review PASS (per Boss 8/25 OOB '双轴每次都跑' protocol).