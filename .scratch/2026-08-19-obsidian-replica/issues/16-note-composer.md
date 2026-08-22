# 16 — Note Composer merge / split / rename + auto-follow links (老板 2026-08-19 evening 拍)

**What to build:**
Obsidian replica scope A item 5: Note Composer (merge / split / rename note, auto-rewrite all `[[name]]` links).

**After change:**
- `Sources/WenshuApp/Core/Composer/NoteMerger.swift` (merge N notes → 1 + rewrite backlinks)
- `Sources/WenshuApp/Core/Composer/NoteSplitter.swift` (split note → N + rewrite backlinks)
- `Sources/WenshuApp/Core/Composer/NoteRenamer.swift` (rename + rewrite all `[[old_name]]` → `[[new_name]]`)
- Reuse LinkIndex (ticket 12) for reverse rewrite

**Blocked by:** ticket 12 (LinkIndex)
**Status:** ready-for-agent → impl done → commit + push

## Acceptance criteria

- [ ] `Sources/WenshuApp/Core/Composer/NoteMerger.swift` merge + auto rewrite
- [ ] `Sources/WenshuApp/Core/Composer/NoteSplitter.swift` split + auto rewrite
- [ ] `Sources/WenshuApp/Core/Composer/NoteRenamer.swift` rename + auto rewrite
- [ ] `swift build` exit 0
- [ ] Unit tests: NoteMergerTests + NoteSplitterTests + NoteRenamerTests
- [ ] Do not touch hermes app
- [ ] Do not touch LayoutTokens / LayoutShellView

## Business-language description (老板 understands)

- Writing app strong requirement: when chapter merge / split / rename links don't break
- Engineering management authorized by 老板

## Truth references

- Obsidian Note Composer: https://obsidian.md/help/plugins/note-composer
- Reuse LinkIndex (ticket 12) actor SQLite-backed