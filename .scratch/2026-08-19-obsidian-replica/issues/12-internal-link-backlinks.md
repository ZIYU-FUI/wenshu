# 12 — Internal Link + Backlinks bidirectional link (老板 2026-08-19 evening 拍 Obsidian replica scope A)

**What to build:**
Obsidian replica scope A item 1: bidirectional link (Internal Link + Backlinks). Markdown `[[name]]` parsing + reverse-link panel.

老板 2026-08-19 evening 拍: 'replica-built backend services, frontend can't verify now, frontend needs doing but not connecting to core project first'.

**After change (split backend / frontend):**

**Backend (this ticket's main, 老板 verifies first):**
- `Sources/WenshuApp/Core/LinkGraph/LinkIndex.swift` (actor SQLite-backed, table schema = source_doc_id / target_ref / target_doc_id / line / offset / created_at)
- `Sources/WenshuApp/Core/LinkGraph/BacklinkResolver.swift` (async resolve all note internal links + bidirectional index)
- `Sources/WenshuApp/Core/LinkGraph/InternalLinkParser.swift` (Markdown `[[name]]` static parsing, same paradigm as v0.18 ticket 05 KanbanStore's SQLite actor)
- Markdown parsing `parseInternalLinks(content) -> [(text, target, line, offset)]` connects to `LibraryStoring.loadDocumentContent`
- Unit tests (LinkIndexTests add / search / resolve, BacklinkResolverTests, InternalLinkTests Chinese / nested / escaped)

**Frontend (done but not connected, kept standalone SwiftUI View awaiting 老板 verify on macOS):**
- `Sources/WenshuApp/Core/LinkGraph/BacklinksPanel.swift` (SwiftUI View, right pane shows current note backlinks)
- Unit tests (BacklinksPanelTests ViewModel rendering logic, doesn't render actual view)
- **Not connected to core project**: not connected to LayoutShellView, not to BookEditorSheet, not to LibraryOutlineView, kept standalone module

**Blocked by:** None
**Status:** ready-for-agent → impl done → commit + push (老板 8/19 evening 'no verification needed' + self-decision authorization)

## Acceptance criteria

**Backend (老板 verifies):**
- [ ] `Sources/WenshuApp/Core/LinkGraph/LinkIndex.swift` actor SQLite-backed
- [ ] `Sources/WenshuApp/Core/LinkGraph/BacklinkResolver.swift` bidirectional index
- [ ] `Sources/WenshuApp/Core/LinkGraph/InternalLinkParser.swift` Markdown `[[name]]` parsing
- [ ] Markdown `parseInternalLinks(content)` connects to `LibraryStoring` (optional integration)
- [ ] `swift build` exit 0
- [ ] `swift test` exit 0 (new tests + old 137)
- [ ] Unit tests: LinkIndexTests + BacklinkResolverTests + InternalLinkParserTests

**Frontend (done but not connected):**
- [ ] `Sources/WenshuApp/Core/LinkGraph/BacklinksPanel.swift` SwiftUI View
- [ ] BacklinksPanelTests ViewModel rendering logic (not connected to LayoutShellView)

**Untouched:**
- [ ] hermes app / `~/.hermes/profiles/pocock/`
- [ ] wenshu current SwiftUI UI / business logic (LayoutTokens / LayoutShellView / NativeSplitter)
- [ ] BacklinksPanel **not connected to core project** (kept standalone awaiting 老板 macOS verify)

## Business-language description (老板 understands)

- Writing app strong requirement: characters / chapters / settings can cross-reference + when writing current chapter can see all settings referencing it
- Backend first (actor + SQLite + parsing + tests), 老板 `swift build` + `swift test` verify
- Frontend View done but not connected, awaiting 老板 macOS verify
- Engineering management authorized by 老板, no verification needed

## Truth references

- Obsidian Backlinks plugin: https://obsidian.md/help/plugins/backlinks
- Apple HIG SQLite truth: https://developer.apple.com/documentation/sqlite
- v0.18 ticket 01 MemoryStore actor SQLite paradigm: commit `047b43cfa` (老板 8/19 拍)
- SilverBullet page ref `[[name]]` same syntax (bidirectional compatible with Obsidian / SilverBullet)