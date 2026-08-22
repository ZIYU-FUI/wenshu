# 20 — Word count word count statistics (老板 2026-08-19 evening 拍)

**What to build:**
Obsidian replica scope A item 9: Word count (current note / vault word count, writer must-have).

**After change:**
- `Sources/WenshuApp/Core/WordCount/WordCounter.swift` (`String.enumerateSubstrings(.word)` Apple HIG count)
- `Sources/WenshuApp/Core/WordCount/WordCountBadge.swift` (SwiftUI View, top bar shows current note word count)

**Blocked by:** None
**Status:** ready-for-agent → impl done → commit + push

## Acceptance criteria

- [ ] `Sources/WenshuApp/Core/WordCount/WordCounter.swift` Apple HIG
- [ ] `Sources/WenshuApp/Core/WordCount/WordCountBadge.swift` top bar View
- [ ] `swift build` exit 0
- [ ] Unit tests: WordCounterTests (English / Chinese / mixed)
- [ ] Do not touch hermes app
- [ ] Do not touch LayoutTokens / LayoutShellView

## Business-language description (老板 understands)

- Writing app strong requirement: writer must-have, daily word count / total word count / chapter word count
- Chinese counts by character, English counts by word

## Truth references

- Obsidian Word count: https://obsidian.md/help/plugins/word-count
- Apple HIG: `String.enumerateSubstrings(.word)`