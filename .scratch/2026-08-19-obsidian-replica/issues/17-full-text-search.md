# 17 — Full Text Search full-text search + highlight (老板 2026-08-19 evening 拍)

**What to build:**
Obsidian replica scope A item 6: full-text search (cross-vault full-text + highlight).

**After change:**
- `Sources/WenshuApp/Core/Search/FullTextSearch.swift` (actor SQLite FTS5 full-text index)
- `Sources/WenshuApp/Core/Search/SearchPanel.swift` (SwiftUI View, real-time search + highlight)

**Blocked by:** None
**Status:** ready-for-agent → impl done → commit + push

## Acceptance criteria

- [ ] `Sources/WenshuApp/Core/Search/FullTextSearch.swift` SQLite FTS5 actor
- [ ] `Sources/WenshuApp/Core/Search/SearchPanel.swift` SwiftUI View + highlight
- [ ] `swift build` exit 0
- [ ] Unit tests: FullTextSearchTests (index / search / highlight)
- [ ] Do not touch hermes app
- [ ] Do not touch LayoutTokens / LayoutShellView

## Business-language description (老板 understands)

- Writing app strong requirement: cross-bookshelf search chapter content
- ⌘F / Spotlight paradigm

## Truth references

- Obsidian Search: https://obsidian.md/help/plugins/search
- Apple HIG SQLite FTS5: https://www.sqlite.org/fts5.html (SQLite builtin)