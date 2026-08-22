# Spec — 文枢 menu add "Settings..." menu item (Apple HIG macOS truth)

> Date: 2026-08-19
> Spec uses po `to-spec` skill 7-section template

## Problem Statement

老板 2026-08-19 reported: after launching wenshu app menu bar **doesn't have "Settings" menu**, but code already wrote `Settings` scene (L208-219) — 老板 can't find entry.

From 老板's perspective, macOS app standard practice = "文枢" top-level menu hangs "Settings..." item (Apple HIG, same as Pages / Numbers / Xcode), shortcut `⌘,`.

## Solution

In `.commands` add `CommandGroup(replacing: .appSettings)` to manually inject "Settings..." menu item under "文枢" top-level. SwiftUI `Settings` scene kept (user opens through menu click or `⌘,`).

### Business-language description (老板 understands)

- Menu bar "文枢" top-level add "Settings..." item (same as Pages / Numbers / Xcode)
- Shortcut `⌘,` (Apple standard)
- Click → popup existing settings dialog (appearance dark / light / follow system)

## User Stories

1. As 老板, I want menu bar "文枢" top-level to see "Settings..." menu item, so that can open settings dialog
2. As 老板, I want "Settings..." shortcut `⌘,`, so that same as Pages / Numbers / Xcode
3. As 老板, I want click "Settings..." to popup existing settings dialog (appearance dark / light / follow system)
4. As 老板, I want settings keep menu bar other items unchanged (文枢 / File / Edit / Show / View / Window / Help)
5. As 老板, I want `swift build` exit 0

## Implementation Decisions

- **In WenshuApp.body `.commands {}` add `CommandGroup(replacing: .appSettings)`**:
  ```swift
  CommandGroup(replacing: .appSettings) {
      SettingsLink {
          Text("Settings…")
      }
      .keyboardShortcut(",", modifiers: .command)
  }
  ```
- **`SettingsLink` is SwiftUI 4+ (macOS 14+) API**, pairs with Settings scene to auto-open
- Existing `Settings { Form { Picker("Appearance") } }` scene kept, as macOS HIG standard
- Don't touch existing menu (File / View / Restore Default Layout)

## Testing Decisions

- Only `swift build clean` (exit 0), 老板 self-launches app to verify
- Verify: menu bar "文枢" top-level can see "Settings..." item, shortcut `⌘,` works, click opens settings dialog

## Out of Scope

- Do not touch macOS chrome 52 PT
- Do not touch LayoutTokens / bandH / toolbar width
- Do not touch D_h / D_v 5 vertical splitters
- Do not touch cursor (backlog 02 todo)
- Do not implement settings persistence (already has `@AppStorage("appearanceMode")` persistence)
- Do not add other settings items (appearance already implemented, wait for backlog scheduling to add)

## Further Notes

- This is menu bar visual detail fix, independent from previous v0.16 ticket 01-06
- Apple HIG truth: macOS app under "文枢" top-level menu must have "Settings..." (same as Pages / Numbers / Xcode)
- SettingsLink SwiftUI 4+ API truth: https://developer.apple.com/documentation/swiftui/settingslink