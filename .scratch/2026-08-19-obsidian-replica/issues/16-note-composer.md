# 16 — Note Composer 合并 / 拆分 / 重命名 + 自动跟随链接 (老板 2026-08-19 evening 拍)

**What to build:**
Obsidian 复刻范围 A 第 5 件: Note Composer (合并 / 拆分 / 重命名 note, 自动重写所有 `[[name]]` 链接)。

**改完:**
- `Sources/WenshuApp/Core/Composer/NoteMerger.swift` (合并 N 个 note → 1 个 + 重写 backlink)
- `Sources/WenshuApp/Core/Composer/NoteSplitter.swift` (拆分 note → N 个 + 重写 backlink)
- `Sources/WenshuApp/Core/Composer/NoteRenamer.swift` (重命名 + 重写所有 `[[old_name]]` → `[[new_name]]`)
- 复用 LinkIndex (ticket 12) 反向重写

**Blocked by:** ticket 12 (LinkIndex)

**Status:** ready-for-agent → impl done → commit + push

## Acceptance criteria
- [ ] Sources/WenshuApp/Core/Composer/NoteMerger.swift 合并 + 自动重写
- [ ] Sources/WenshuApp/Core/Composer/NoteSplitter.swift 拆分 + 自动重写
- [ ] Sources/WenshuApp/Core/Composer/NoteRenamer.swift 重命名 + 自动重写
- [ ] swift build exit 0
- [ ] 单元测试: NoteMergerTests + NoteSplitterTests + NoteRenamerTests
- [ ] 不动 hermes app
- [ ] 不动 LayoutTokens / LayoutShellView

## 业务语言描述 (老板懂)
- 写作 app 强需求: 章节合并 / 拆分 / 重命名时链接不坏
- 工程管理老板授权

## 真值引用
- Obsidian Note Composer: https://obsidian.md/help/plugins/note-composer
- 复用 LinkIndex (ticket 12) actor SQLite-backed
