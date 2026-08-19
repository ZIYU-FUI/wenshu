# 22 — Bookmarks 收藏夹 (老板 2026-08-19 evening 拍)

**What to build:**
Obsidian 复刻范围 A 第 11 件: Bookmarks (跨 note 收藏夹 / 锚点)。

**改完:**
- `Sources/WenshuApp/Core/Bookmarks/BookmarkStore.swift` (actor SQLite-backed, 表 schema = id / doc_id / label / created_at)
- `Sources/WenshuApp/Core/Bookmarks/BookmarkPanel.swift` (SwiftUI View, 左栏显示所有 bookmark)

**Blocked by:** None

**Status:** ready-for-agent → impl done → commit + push

## Acceptance criteria
- [ ] Sources/WenshuApp/Core/Bookmarks/BookmarkStore.swift actor SQLite
- [ ] Sources/WenshuApp/Core/Bookmarks/BookmarkPanel.swift SwiftUI View
- [ ] swift build exit 0
- [ ] 单元测试: BookmarkStoreTests add / remove / list
- [ ] 不动 hermes app
- [ ] 不动 LayoutTokens / LayoutShellView

## 业务语言描述 (老板懂)
- 写作 app 中等: 收藏章节 / 设定片段
- 工程管理老板授权

## 真值引用
- Obsidian Bookmarks: https://obsidian.md/help/plugins/bookmarks
