# 01 — 文枢 menu add "Settings..." menu item (Apple HIG macOS truth)

**What to build:**
老板 2026-08-19 reported: after launching wenshu app menu bar "文枢" top-level can't find "Settings..." menu item. Code already wrote Settings scene but menu bar has no entry.

After change:
- WenshuApp.body `.commands {}` add `CommandGroup(replacing: .appSettings)`
- Use `SettingsLink` to open existing Settings scene
- Shortcut `⌘,` (Apple standard)
- Existing `Settings { Form { Picker("Appearance") } }` kept

**Blocked by:** None
**Status:** ready-for-agent → impl done → waiting for 老板 verify

## Acceptance criteria

- [ ] `.commands {}` add `CommandGroup(replacing: .appSettings)` inject "Settings..." menu item
- [ ] Menu item shortcut `⌘,` (Apple HIG standard)
- [ ] Click menu item / press `⌘,` → open existing Settings dialog (appearance dark / light / follow system)
- [ ] Menu bar other items unchanged (文枢 / File / Edit / Show / View / Window / Help)
- [ ] `swift build` exit 0
- [ ] No new dependencies (built-in SwiftUI `SettingsLink`, macOS 14+)
- [ ] macOS chrome 52 PT unchanged
- [ ] D_h / D_v 5 vertical splitters unchanged
- [ ] Cursor unchanged (backlog 02 todo)
- [ ] Settings scene content unchanged (appearance Picker)

## Business-language description (老板 understands)

- Menu bar "文枢" top-level add "Settings..." (same as Pages / Numbers / Xcode)
- Shortcut `⌘,`
- Click opens existing settings dialog (appearance dark / light / follow system)