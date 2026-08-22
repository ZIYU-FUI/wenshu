# 22 — Bookmarks favorites (老板 2026-08-19 evening 拍)

**What to build:**
Obsidian replica scope A item 11: Bookmarks (cross-note favorites / anchors).

**After change:**
- `Sources/WenshuApp/Core/Bookmarks/BookmarkStore.swift` (actor SQLite-backed, table schema = id / doc_id / label / created_at)
- `Sources/WenshuApp/Core/Bookmarks/BookmarkPanel.swift` (SwiftUI View, left pane shows all bookmarks)

**Blocked by:** None
**Status:** ready-for-agent → impl done → commit + push

## Acceptance criteria

- [ ] `Sources/WenshuApp/Core/Bookmarks/BookmarkStore.swift` actor SQLite
- [ ] `Sources/WenshuApp/Core/Bookmarks/BookmarkPanel.swift` SwiftUI View
- [ ] `swift build` exit 0
- [ ] Unit tests: BookmarkStoreTests add / remove / list
- [ ] Do not touch hermes app
- [ ] Do not touch LayoutTokens / LayoutShellView

## Business-language description (老板 understands)

- Writing app medium: favorite chapter / setting fragment
- Engineering management authorized by 老板

## Truth references

- Obsidian Bookmarks: https://obsidian.md/help/plugins/bookmarks