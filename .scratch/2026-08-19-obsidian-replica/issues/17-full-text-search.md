# 17 — Full Text Search 全文搜索 + 高亮 (老板 2026-08-19 evening 拍)

**What to build:**
Obsidian 复刻范围 A 第 6 件: 全文搜索 (跨 vault 全文 + 高亮)。

**改完:**
- `Sources/WenshuApp/Core/Search/FullTextSearch.swift` (actor SQLite FTS5 全文索引)
- `Sources/WenshuApp/Core/Search/SearchPanel.swift` (SwiftUI View, 实时搜索 + 高亮)

**Blocked by:** None

**Status:** ready-for-agent → impl done → commit + push

## Acceptance criteria
- [ ] Sources/WenshuApp/Core/Search/FullTextSearch.swift SQLite FTS5 actor
- [ ] Sources/WenshuApp/Core/Search/SearchPanel.swift SwiftUI View + 高亮
- [ ] swift build exit 0
- [ ] 单元测试: FullTextSearchTests (index / search / highlight)
- [ ] 不动 hermes app
- [ ] 不动 LayoutTokens / LayoutShellView

## 业务语言描述 (老板懂)
- 写作 app 强需求: 跨书架搜索章节内容
- ⌘F / Spotlight 范式

## 真值引用
- Obsidian Search: https://obsidian.md/help/plugins/search
- Apple HIG SQLite FTS5: https://www.sqlite.org/fts5.html (SQLite builtin)
