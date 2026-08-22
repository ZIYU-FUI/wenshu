# 21 — Outline current note outline (老板 2026-08-19 evening 拍)

**What to build:**
Obsidian replica scope A item 10: Outline (current note H1-H6 outline panel).

**After change:**
- `Sources/WenshuApp/Core/Outline/OutlineExtractor.swift` (Markdown heading parsing: H1-H6)
- `Sources/WenshuApp/Core/Outline/OutlinePanel.swift` (SwiftUI View, right pane shows outline + click to jump)

**Blocked by:** None
**Status:** ready-for-agent → impl done → commit + push

## Acceptance criteria

- [ ] `Sources/WenshuApp/Core/Outline/OutlineExtractor.swift` H1-H6 parsing
- [ ] `Sources/WenshuApp/Core/Outline/OutlinePanel.swift` SwiftUI View
- [ ] `swift build` exit 0
- [ ] Unit tests: OutlineExtractorTests (H1-H6 + Chinese/English)
- [ ] Do not touch hermes app
- [ ] Do not touch LayoutTokens / LayoutShellView

## Business-language description (老板 understands)

- Writing app medium: chapter list already implemented (Book), outline is note internal H1-H6 outline
- Click outline to jump

## Truth references

- Obsidian Outline: https://obsidian.md/help/plugins/outline