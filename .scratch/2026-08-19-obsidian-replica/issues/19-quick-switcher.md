# 19 — Quick Switcher ⌘O fuzzy search (老板 2026-08-19 evening 拍)

**What to build:**
Obsidian replica scope A item 8: Quick Switcher (⌘O fuzzy search all notes + chapters).

**After change:**
- `Sources/WenshuApp/Core/QuickSwitcher/QuickSwitcher.swift` (fuzzy search notes + chapters)
- `Sources/WenshuApp/Core/QuickSwitcher/QuickSwitcherWindow.swift` (SwiftUI Window popup, same Apple Spotlight pattern)
- ⌘O shortcut connects to SwiftUI `.commands`

**Blocked by:** None
**Status:** ready-for-agent → impl done → commit + push

## Acceptance criteria

- [ ] `Sources/WenshuApp/Core/QuickSwitcher/QuickSwitcher.swift` fuzzy search
- [ ] `Sources/WenshuApp/Core/QuickSwitcher/QuickSwitcherWindow.swift` Spotlight paradigm
- [ ] ⌘O shortcut connects to SwiftUI `.commands`
- [ ] `swift build` exit 0
- [ ] Unit tests: QuickSwitcherTests (fuzzy matching)
- [ ] Do not touch hermes app
- [ ] Do not touch LayoutTokens / LayoutShellView

## Business-language description (老板 understands)

- Writing app strong requirement: cross-bookshelf quick switch note / chapter
- Same Apple Spotlight paradigm (top-center popup)

## Truth references

- Obsidian Quick Switcher: https://obsidian.md/help/plugins/quick-switcher
- Apple Spotlight paradigm (macOS 14+ SwiftUI Window)